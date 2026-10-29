import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:g4m_core/g4m_core.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../core/l10n.dart';
import '../../core/live.dart';
import '../../core/location_service.dart';

/// Data access for the delivery role. All reads degrade gracefully; all order
/// status changes go through `updateOrderStatus` / `acceptDelivery`.
abstract final class DeliveryData {
  static Stream<DeliveryPartner?> me() =>
      Fs.deliveryPartners.doc(myUid).snapshots().map((d) => d.exists ? DeliveryPartner.fromDoc(d) : null);

  static Stream<double> balance() => me().map((p) => p?.balance ?? 0).distinct();

  /// Every order assigned to me (active and finished), newest first.
  static Stream<List<ShopOrder>> myOrders() => resilientQuery<ShopOrder>(
        [
          () => Fs.orders.where('deliveryPartnerId', isEqualTo: myUid).orderBy('createdAt', descending: true).limit(300),
          () => Fs.orders.where('deliveryPartnerId', isEqualTo: myUid).limit(300),
        ],
        ShopOrder.fromDoc,
        sort: (a, b) => newestFirst(a.createdAt, b.createdAt),
      );

  /// Assignable orders: packed, home delivery, nobody assigned yet.
  /// Must mirror the orders read rule exactly; it is only readable while the rider is approved and online.
  static Stream<List<ShopOrder>> pool() => Fs.orders.where('deliveryPartnerId', isNull: true).where('deliveryType', isEqualTo: 'home').where('status', whereIn: [OrderStatus.confirmed, OrderStatus.packed])
      .limit(50)
      .snapshots()
      .map((s) => s.docs
          .map(ShopOrder.fromDoc)
          .where((o) => o.deliveryType == 'home' && o.deliveryPartnerId.isEmpty)
          .toList());

  static Stream<ShopOrder?> order(String id) =>
      Fs.orders.doc(id).snapshots().map((d) => d.exists ? ShopOrder.fromDoc(d) : null);

  static Future<Seller?> seller(String id) async {
    if (id.isEmpty) return null;
    try {
      final d = await Fs.sellers.doc(id).get();
      return d.exists ? Seller.fromDoc(d) : null;
    } catch (_) {
      return null;
    }
  }

  static Stream<List<Json>> cashCollections() => resilientQuery<Json>(
        [
          () => Fs.cashCollections.where('deliveryPartnerId', isEqualTo: myUid).orderBy('createdAt', descending: true).limit(200),
          () => Fs.cashCollections.where('deliveryPartnerId', isEqualTo: myUid).limit(200),
        ],
        (d) => {'id': d.id, ...?d.data()},
        sort: (a, b) => newestFirst(asDate(a['createdAt']), asDate(b['createdAt'])),
      );

  static Stream<List<WalletTxn>> walletTxns() => resilientQuery<WalletTxn>(
        [
          () => Fs.walletTransactions.where('userId', isEqualTo: myUid).orderBy('createdAt', descending: true).limit(50),
          () => Fs.walletTransactions.where('userId', isEqualTo: myUid).limit(50),
        ],
        WalletTxn.fromDoc,
        sort: (a, b) => newestFirst(a.createdAt, b.createdAt),
      );

  static Stream<Json> userDoc() => Fs.user(myUid).snapshots().map((d) => d.data() ?? <String, dynamic>{});
}

DateTime? asDate(dynamic v) => switch (v) {
      Timestamp t => t.toDate(),
      DateTime d => d,
      int ms => DateTime.fromMillisecondsSinceEpoch(ms),
      String s => DateTime.tryParse(s),
      _ => null,
    };

double asNum(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;

/// When the order reached [status] according to its timeline (falls back to createdAt).
DateTime? statusAt(ShopOrder o, String status) {
  for (final t in o.timeline.reversed) {
    if (t.status == status && t.at != null) return t.at;
  }
  return null;
}

DateTime? deliveredAt(ShopOrder o) => statusAt(o, OrderStatus.delivered) ?? asDate(o.data['updatedAt']) ?? o.createdAt;

/// Partner earning for one delivered order: an explicit per-order field if the
/// backend writes one, else the per-order salary amount.
double orderEarning(ShopOrder o, DeliveryPartner? p) {
  for (final k in const ['deliveryEarning', 'partnerEarning', 'riderEarning']) {
    final v = o.data[k];
    if (v is num) return v.toDouble();
  }
  final salary = p?.data['salary'];
  if (salary is Map && salary['type'] == 'per_order') return asNum(salary['amount']);
  return 0;
}

bool isPerOrder(DeliveryPartner? p) {
  final s = p?.data['salary'];
  return s is Map && s['type'] == 'per_order';
}

LatLng? orderLatLng(ShopOrder o) {
  final a = o.address;
  if (a['lat'] is num && a['lng'] is num) return LatLng((a['lat'] as num).toDouble(), (a['lng'] as num).toDouble());
  return null;
}

LatLng? sellerLatLng(Seller? s) {
  if (s == null) return null;
  final la = s.data['lat'], ln = s.data['lng'];
  if (la is num && ln is num) return LatLng(la.toDouble(), ln.toDouble());
  return null;
}

LatLng? myLatLng() {
  final p = LocationService.instance.last;
  return p == null ? null : LatLng(p.latitude, p.longitude);
}

double? kmBetween(LatLng? a, LatLng? b) {
  if (a == null || b == null) return null;
  return Geolocator.distanceBetween(a.latitude, a.longitude, b.latitude, b.longitude) / 1000;
}

String addressLine(Json a) => [a['line1'], a['line2'], a['landmark'], a['city'], a['pincode']]
    .where((e) => e != null && '$e'.trim().isNotEmpty)
    .join(', ');

bool isCodDue(ShopOrder o) => o.paymentMethod == 'cod' && o.paymentStatus != 'paid';

/// Quick-delivery deadline (15/30 min) if this order is a quick one.
DateTime? quickDeadline(ShopOrder o) {
  final mins = switch (o.speed) {
    'quick15' => 15,
    'quick30' => 30,
    _ => 0,
  };
  if (mins == 0) return null;
  return o.etaAt ?? o.createdAt?.add(Duration(minutes: mins));
}

String speedLabel(BuildContext context, String speed) => switch (speed) {
      'quick15' => context.tr('15-min', '15 मिनट'),
      'quick30' => context.tr('30-min', '30 मिनट'),
      'scheduled' => context.tr('Scheduled', 'निर्धारित'),
      _ => context.tr('Standard', 'सामान्य'),
    };

const activeDeliveryStatuses = {OrderStatus.assigned, OrderStatus.pickedUp, OrderStatus.outForDelivery};

String vehicleLabel(BuildContext context, String v) => switch (v) {
      'bike' => context.tr('Bike', 'बाइक'),
      'scooter' => context.tr('Scooter', 'स्कूटर'),
      'bicycle' => context.tr('Bicycle', 'साइकिल'),
      'car' => context.tr('Car', 'कार'),
      'van' => context.tr('Van', 'वैन'),
      _ => Fmt.titleCase(v),
    };

IconData vehicleIcon(String v) => switch (v) {
      'bicycle' => Icons.pedal_bike_rounded,
      'scooter' => Icons.electric_scooter_rounded,
      'car' => Icons.directions_car_rounded,
      'van' => Icons.airport_shuttle_rounded,
      _ => Icons.two_wheeler_rounded,
    };
