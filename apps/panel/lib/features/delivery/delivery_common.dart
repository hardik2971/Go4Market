import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:g4m_core/g4m_core.dart' hide Fmt;

import '../../core/doc.dart';
import '../../core/live.dart';
import '../../core/session.dart';
import '../../core/web_utils.dart';
import '../../ui/kit.dart';
import 'package:panel/l10n/overrides.dart';

/// Keeps the partner's location fresh while online. Lives for the whole app session,
/// so navigating between pages does not stop tracking.
class LocationBeacon extends ChangeNotifier {
  LocationBeacon._();
  static final instance = LocationBeacon._();

  bool online = false;
  bool busy = false;
  double? lat, lng;
  DateTime? lastFix;
  String? error;
  Timer? _timer;
  bool _resumed = false;

  /// Resume tracking if the profile says we were online (called by delivery pages).
  void resumeIfNeeded() {
    if (_resumed) return;
    _resumed = true;
    final p = session.profile;
    if (p != null && p.b('online')) {
      online = true;
      if (p['lat'] != null) {
        lat = p.n('lat');
        lng = p.n('lng');
      }
      _startTimer();
      unawaited(_tick());
      notifyListeners();
    }
  }

  Future<bool> setOnline(bool v) async {
    if (busy) return online;
    busy = true;
    error = null;
    notifyListeners();
    try {
      if (v) {
        final (la, ln) = await currentPosition();
        lat = la;
        lng = ln;
        lastFix = DateTime.now();
        await Fs.deliveryPartners.doc(session.uid).update({
          'online': true,
          'lat': la,
          'lng': ln,
          'locationUpdatedAt': FieldValue.serverTimestamp(),
        });
        online = true;
        _startTimer();
        toast("You're online — new orders near you will appear in the pool");
      } else {
        _timer?.cancel();
        online = false;
        await Fs.deliveryPartners.doc(session.uid).update({'online': false, 'locationUpdatedAt': FieldValue.serverTimestamp()});
        toast("You're offline", kind: ToastKind.info);
      }
    } catch (e) {
      error = e is String ? e : friendlyError(e);
      if (v) {
        online = false;
        _timer?.cancel();
      }
      toast(v ? 'Could not go online: $error. Allow location access in your browser.' : 'Could not update status: $error', kind: ToastKind.error);
    } finally {
      busy = false;
      notifyListeners();
    }
    return online;
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _tick());
  }

  Future<void> _tick() async {
    if (!online || session.uid.isEmpty) return;
    try {
      final (la, ln) = await currentPosition();
      lat = la;
      lng = ln;
      lastFix = DateTime.now();
      error = null;
      await Fs.deliveryPartners.doc(session.uid).update({
        'online': true,
        'lat': la,
        'lng': ln,
        'locationUpdatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      error = e is String ? e : friendlyError(e);
    }
    notifyListeners();
  }

  Future<void> refreshNow() => _tick();
}

/// Statuses where the order is in the partner's hands.
const activeDeliveryStatuses = [OrderStatus.assigned, OrderStatus.pickedUp, OrderStatus.outForDelivery];

/// Next status in the rider flow, or null when nothing to do.
String? nextRiderStatus(String status) => switch (status) {
      OrderStatus.assigned => OrderStatus.pickedUp,
      OrderStatus.pickedUp => OrderStatus.outForDelivery,
      OrderStatus.outForDelivery => OrderStatus.delivered,
      _ => null,
    };

String nextActionLabel(String next) => switch (next) {
      OrderStatus.pickedUp => 'Mark picked up',
      OrderStatus.outForDelivery => 'Start delivery',
      OrderStatus.delivered => 'Complete delivery',
      _ => Fmt.titleCase(next),
    };

IconData nextActionIcon(String next) => switch (next) {
      OrderStatus.pickedUp => Icons.inventory_rounded,
      OrderStatus.outForDelivery => Icons.two_wheeler_rounded,
      _ => Icons.task_alt_rounded,
    };

bool isCod(Doc o) => o.s('paymentMethod', 'cod') == 'cod' && o.s('paymentStatus', 'pending') != 'paid';

/// Advances an order one step; asks for OTP + cash on delivery.
Future<bool> advanceDelivery(BuildContext context, Doc order) async {
  final next = nextRiderStatus(order.s('status'));
  if (next == null) return false;
  if (next != OrderStatus.delivered) {
    if (!await confirm(context, '${nextActionLabel(next)}?', message: 'Order ${order.s('orderNo')}', confirmLabel: nextActionLabel(next))) return false;
    return runToast(() => G4MApi.instance.updateOrderStatus(order.id, next), success: '${OrderStatus.label(next)} · ${order.s('orderNo')}');
  }
  final res = await showDialog<(String, double?)>(context: context, builder: (_) => _DeliverDialog(order: order));
  if (res == null) return false;
  return runToast(
    () => G4MApi.instance.updateOrderStatus(order.id, OrderStatus.delivered, otp: res.$1, cashCollected: res.$2),
    success: 'Delivered · ${order.s('orderNo')}',
  );
}

class _DeliverDialog extends StatefulWidget {
  const _DeliverDialog({required this.order});
  final Doc order;
  @override
  State<_DeliverDialog> createState() => _DeliverDialogState();
}

class _DeliverDialogState extends State<_DeliverDialog> {
  final _key = GlobalKey<FormState>();
  final _otp = TextEditingController();
  late final _cash = TextEditingController(text: isCod(widget.order) ? widget.order.n('payable', widget.order.n('total')).toStringAsFixed(0) : '0');

  @override
  Widget build(BuildContext context) {
    final cod = isCod(widget.order);
    final due = widget.order.n('payable', widget.order.n('total'));
    return AlertDialog(
      title: Text(tr('Complete delivery')),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _key,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: (cod ? G4MColors.accent : G4MColors.success).withValues(alpha: .1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                Icon(cod ? Icons.payments_rounded : Icons.verified_rounded, color: cod ? G4MColors.accent : G4MColors.success),
                const SizedBox(width: 10),
                Expanded(child: Text(cod ? 'Collect cash from customer' : 'Prepaid order — no cash to collect', style: const TextStyle(fontWeight: FontWeight.w700))),
                if (cod) Text(Fmt.money(due), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
              ]),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _otp,
              autofocus: true,
              maxLength: 6,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(fontSize: 22, letterSpacing: 8, fontWeight: FontWeight.w800),
              decoration: const InputDecoration(labelText: 'Delivery OTP from customer', counterText: ''),
              validator: (v) => (v ?? '').length < 4 ? 'Enter the OTP' : null,
            ),
            if (cod) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _cash,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                decoration: const InputDecoration(labelText: 'Cash collected', prefixText: '₹ '),
                validator: (v) => double.tryParse(v ?? '') == null ? 'Enter the amount' : null,
              ),
            ],
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('Cancel'))),
        FilledButton.icon(
          onPressed: () {
            if (!_key.currentState!.validate()) return;
            Navigator.pop(context, (_otp.text.trim(), cod ? double.parse(_cash.text) : null));
          },
          icon: const Icon(Icons.task_alt_rounded, size: 18),
          label: Text(tr('Mark delivered')),
        ),
      ],
    );
  }
}

/// My orders (as delivery partner) with index fallback.
Stream<List<Doc>> myDeliveries({int limit = 200}) => liveDocs(
      Fs.orders.where('deliveryPartnerId', isEqualTo: session.uid).orderBy('createdAt', descending: true).limit(limit),
      fallback: Fs.orders.where('deliveryPartnerId', isEqualTo: session.uid).limit(limit),
      label: 'orders(deliveryPartnerId, createdAt desc)',
    );

/// Haversine distance in km.
double distanceKm(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371.0;
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(lat2 - lat1), dLng = rad(lng2 - lng1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) + math.cos(rad(lat1)) * math.cos(rad(lat2)) * math.sin(dLng / 2) * math.sin(dLng / 2);
  return 2 * r * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

/// Estimated rider earning for one delivered order based on profile salary config.
double estEarning(Doc? profile, Doc order) {
  final type = profile?.s('salary.type', 'per_order') ?? 'per_order';
  if (type != 'per_order') return 0;
  final amt = profile?.n('salary.amount') ?? 0;
  if (amt > 0) return amt;
  return order.n('deliveryEarning', order.n('deliveryFee'));
}

String addressLine(Doc o) {
  final a = o['address'];
  if (a is! Map) return o.s('deliveryType') == 'pickup' ? 'Self pickup' : '';
  return [a['line1'], a['line2'], a['landmark'], a['city'], a['pincode']].where((e) => e != null && '$e'.isNotEmpty).join(', ');
}

/// Order card with next-step action used on dashboard / my deliveries / pool.
class DeliveryOrderCard extends StatelessWidget {
  const DeliveryOrderCard({super.key, required this.order, this.onOpen, this.trailing, this.distance});
  final Doc order;
  final VoidCallback? onOpen;
  final Widget? trailing;
  final double? distance;

  @override
  Widget build(BuildContext context) {
    final o = order;
    final next = nextRiderStatus(o.s('status'));
    final items = o['items'] is List ? (o['items'] as List).length : 0;
    final cod = isCod(o);
    return Pressable(
      onTap: onOpen,
      scale: .99,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.pal.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.pal.line),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(o.s('orderNo', o.id.substring(0, 6)), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(width: 8),
            statusPill(o.s('status')),
            const Spacer(),
            if (o.s('speed') == 'quick15' || o.s('speed') == 'quick30') Tag(o.s('speed') == 'quick15' ? '15 min' : '30 min', color: G4MColors.accent, icon: Icons.bolt_rounded),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Icon(Icons.person_outline_rounded, size: 16, color: context.pal.muted),
            const SizedBox(width: 6),
            Expanded(child: Text('${o.s('customer.name', 'Customer')}  ·  ${o.s('customer.phone')}', maxLines: 1, overflow: TextOverflow.ellipsis)),
          ]),
          const SizedBox(height: 4),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.place_outlined, size: 16, color: context.pal.muted),
            const SizedBox(width: 6),
            Expanded(child: Text(addressLine(o), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.pal.muted, fontSize: 13))),
          ]),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Tag('$items item${items == 1 ? '' : 's'}', icon: Icons.shopping_bag_outlined),
            Tag(cod ? 'COD ${Fmt.money(o.n('payable', o.n('total')))}' : 'Prepaid', color: cod ? G4MColors.accent : G4MColors.success, icon: cod ? Icons.payments_outlined : Icons.verified_outlined),
            if (distance != null) Tag('${distance!.toStringAsFixed(1)} km away', color: G4MColors.info, icon: Icons.near_me_outlined),
            if (o.n('distanceKm') > 0) Tag('${o.n('distanceKm').toStringAsFixed(1)} km trip', icon: Icons.route_outlined),
            Text(Fmt.ago(o.createdAt), style: TextStyle(fontSize: 12, color: context.pal.faint)),
          ]),
          if (trailing != null || next != null) ...[
            const SizedBox(height: 12),
            Row(children: [
              if (o.s('customer.phone').isNotEmpty)
                IconButton.outlined(
                  tooltip: 'Call customer',
                  onPressed: () => openUrl('tel:${o.s('customer.phone')}'),
                  icon: const Icon(Icons.call_rounded, size: 18),
                ),
              const SizedBox(width: 8),
              if (o['address'] is Map && (o['address'] as Map)['lat'] != null)
                IconButton.outlined(
                  tooltip: 'Directions',
                  onPressed: () => openUrl('https://www.google.com/maps/dir/?api=1&destination=${o['address']['lat']},${o['address']['lng']}'),
                  icon: const Icon(Icons.directions_rounded, size: 18),
                ),
              const Spacer(),
              if (trailing != null)
                trailing!
              else if (next != null)
                AsyncButton(
                  label: nextActionLabel(next),
                  icon: nextActionIcon(next),
                  color: next == OrderStatus.delivered ? G4MColors.success : null,
                  onPressed: () async => advanceDelivery(context, o),
                ),
            ]),
          ],
        ]),
      ),
    );
  }
}
