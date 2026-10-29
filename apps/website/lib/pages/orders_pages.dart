import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:g4m_core/g4m_core.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/data.dart';
import '../core/shop.dart';
import '../core/web_bridge.dart';
import '../l10n/l10n.dart';
import '../ui/gate.dart';
import '../ui/kit.dart';
import '../ui/maps.dart';
import '../ui/shell.dart';

// ------------------------------------------------------------------ list

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});
  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  bool _active = true;
  @override
  Widget build(BuildContext context) {
    final t = context.l.orders;
    return SeoMeta(
      title: t.myOrders,
      child: PageScroll(children: [
        Contained(
          vertical: 24,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Heading(t.myOrders),
            const SizedBox(height: 16),
            SignedInGate(
              next: '/orders',
              icon: Icons.receipt_long_outlined,
              title: t.signInTitle,
              message: t.signInMessage,
              builder: (context) => StreamBuilder<List<ShopOrder>>(
                stream: live('orders_${Shop.instance.user!.uid}', Data.myOrders),
                builder: (context, s) => asyncView(s, (all) {
                  final l = all.where((o) => o.isActive == _active).toList();
                  return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Row(children: [
                      ChoiceChip(label: Text(t.activeTab(all.where((o) => o.isActive).length)), selected: _active, onSelected: (_) => setState(() => _active = true)),
                      const SizedBox(width: 8),
                      ChoiceChip(label: Text(t.pastTab(all.where((o) => !o.isActive).length)), selected: !_active, onSelected: (_) => setState(() => _active = false)),
                    ]),
                    const SizedBox(height: 18),
                    if (l.isEmpty)
                      EmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: _active ? t.noActive : t.noPast,
                        message: t.emptyMessage,
                        action: FilledButton(onPressed: () => context.go('/'), child: Text(t.startShopping)),
                      )
                    else
                      for (var i = 0; i < l.length; i++) Padding(padding: const EdgeInsets.only(bottom: 12), child: Reveal(index: i % 6, child: _OrderCard(order: l[i]))),
                  ]);
                }, loading: const Column(children: [Skeleton(height: 120, radius: 20), SizedBox(height: 12), Skeleton(height: 120, radius: 20)])),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});
  final ShopOrder order;
  @override
  Widget build(BuildContext context) {
    final o = order;
    final l = context.l;
    final t = l.orders;
    return AppLink(
      to: '/orders/${o.id}',
      label: t.orderCardLabel(o.orderNo, t.status(o.status)),
      child: HoverLift(
        radius: 20,
        lift: 3,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(t.orderNo(o.orderNo), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  Text('${l.dateTime(o.createdAt)} · ${t.items(o.itemCount)}', style: const TextStyle(color: G4MColors.inkMuted, fontSize: 13)),
                ]),
              ),
              StatusChip(o.status, label: t.status(o.status)),
            ]),
            const SizedBox(height: 14),
            Row(children: [
              for (final it in o.items.take(5))
                Container(
                  width: 52,
                  height: 52,
                  margin: const EdgeInsetsDirectional.only(end: 8),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: const Color(0xFFF4F8F5), borderRadius: BorderRadius.circular(12)),
                  child: NetImage(it.image, fit: BoxFit.contain, semanticLabel: it.name),
                ),
              if (o.items.length > 5) Text('+${l.number(o.items.length - 5)}', style: const TextStyle(fontWeight: FontWeight.w800, color: G4MColors.inkMuted)),
              const Spacer(),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(l.money(o.total), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                Text(o.isActive ? t.trackOrderArrow : t.viewDetailsArrow, style: const TextStyle(color: G4MColors.primary, fontWeight: FontWeight.w800, fontSize: 13)),
              ]),
            ]),
          ]),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ detail

class OrderDetailPage extends StatelessWidget {
  const OrderDetailPage({super.key, required this.orderId});
  final String orderId;
  @override
  Widget build(BuildContext context) {
    final placed = GoRouterState.of(context).uri.queryParameters['placed'] == '1';
    final t = context.l.orders;
    return SeoMeta(
      title: t.orderDetails,
      child: PageScroll(children: [
        Contained(
          vertical: 24,
          child: SignedInGate(
            next: '/orders/$orderId',
            title: t.signInTrackTitle,
            message: t.signInTrackMessage,
            builder: (context) => StreamBuilder<ShopOrder?>(
              stream: live('order_$orderId', () => ShopperRepo.instance.order(orderId)),
              builder: (context, s) => asyncView(s, (o) {
                if (o == null) return EmptyState(icon: Icons.search_off_rounded, title: t.notFound);
                return _OrderView(order: o, justPlaced: placed);
              }),
            ),
          ),
        ),
      ]),
    );
  }
}

class _OrderView extends StatelessWidget {
  const _OrderView({required this.order, required this.justPlaced});
  final ShopOrder order;
  final bool justPlaced;

  static const _riderStates = {OrderStatus.assigned, OrderStatus.pickedUp, OrderStatus.outForDelivery};

  @override
  Widget build(BuildContext context) {
    final o = order;
    final l = context.l;
    final t = l.orders;
    final desktop = context.isDesktop;
    final tracking = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (o.isActive && o.etaAt != null && o.deliveryType == 'home') ...[_Countdown(order: o), const SizedBox(height: 16)],
      Panel(child: _StatusStepper(order: o)),
      if (o.deliveryType == 'home' && _riderStates.contains(o.status)) ...[const SizedBox(height: 16), _RiderTracker(order: o)],
      if (o.deliveryOtp.isNotEmpty && o.isActive && o.deliveryType == 'home') ...[
        const SizedBox(height: 16),
        Panel(
          color: G4MColors.accentSoft,
          child: Row(children: [
            const Icon(Icons.pin_outlined, color: kAccentInk, size: 30),
            const SizedBox(width: 14),
            Expanded(child: Text(t.shareOtp, style: const TextStyle(fontWeight: FontWeight.w700))),
            Text(o.deliveryOtp, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: 6, color: G4MColors.ink)),
          ]),
        ),
      ],
      const SizedBox(height: 16),
      _Items(order: o),
    ]);
    final side = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _Bill(order: o),
      const SizedBox(height: 16),
      _Delivery(order: o),
      const SizedBox(height: 16),
      _Actions(order: o),
    ]);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (justPlaced && o.status != OrderStatus.pending)
        Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Reveal(
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(gradient: G4MColors.heroGradient, borderRadius: BorderRadius.circular(24)),
              child: Row(children: [
                const Icon(Icons.celebration_rounded, color: G4MColors.accent, size: 40),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(t.orderPlaced, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 22)),
                    Text(t.thanks, style: const TextStyle(color: Color(0xFFD6EADF))),
                  ]),
                ),
              ]),
            ),
          ),
        ),
      Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            TextLink(t.allOrdersBack, to: '/orders', style: const TextStyle(color: G4MColors.inkMuted, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Heading(t.orderNo(o.orderNo), style: TextStyle(fontSize: context.isPhone ? 24 : 30)),
            Text(t.placedOn(l.dateTime(o.createdAt), t.channel(o.channel)), style: const TextStyle(color: G4MColors.inkMuted)),
          ]),
        ),
        StatusChip(o.status, label: t.status(o.status)),
      ]),
      const SizedBox(height: 20),
      if (desktop)
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: tracking), const SizedBox(width: 24), SizedBox(width: 400, child: side)])
      else ...[tracking, const SizedBox(height: 16), side],
    ]);
  }
}

class _StatusStepper extends StatelessWidget {
  const _StatusStepper({required this.order});
  final ShopOrder order;
  @override
  Widget build(BuildContext context) {
    final o = order;
    final l = context.l;
    final t = l.orders;
    if (o.status == OrderStatus.cancelled || o.status == OrderStatus.returned) {
      return Row(children: [
        Icon(o.status == OrderStatus.cancelled ? Icons.cancel_rounded : Icons.assignment_return_rounded, color: statusColor(o.status), size: 36),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t.status(o.status), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            if (o.cancelReason.isNotEmpty) Text(o.cancelReason, style: const TextStyle(color: G4MColors.inkMuted)),
            if (o.paymentStatus == 'refunded') Text(t.refundProcessed, style: const TextStyle(color: kDiscountInk, fontWeight: FontWeight.w700)),
          ]),
        ),
      ]);
    }
    final flow = o.deliveryType == 'pickup' ? OrderStatus.pickupFlow : OrderStatus.homeFlow;
    final cur = o.status == OrderStatus.pending ? -1 : flow.indexOf(o.status);
    final times = {for (final e in o.timeline) e.status: e.at};
    final icons = {
      OrderStatus.placed: Icons.receipt_long_rounded,
      OrderStatus.confirmed: Icons.thumb_up_alt_outlined,
      OrderStatus.packed: Icons.inventory_2_outlined,
      OrderStatus.assigned: Icons.person_pin_circle_outlined,
      OrderStatus.pickedUp: Icons.shopping_bag_outlined,
      OrderStatus.outForDelivery: Icons.delivery_dining_rounded,
      OrderStatus.readyForPickup: Icons.storefront_outlined,
      OrderStatus.delivered: Icons.home_rounded,
    };
    final phone = context.isPhone;
    final steps = [
      for (var i = 0; i < flow.length; i++)
        (
          flow[i],
          i <= cur,
          i == cur,
          times[flow[i]],
        ),
    ];
    Widget dot(bool done, bool now, IconData ic) => TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: done ? 1 : 0),
          duration: G4MMotion.slow,
          builder: (_, v, _) => Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Color.lerp(G4MColors.surfaceAlt, G4MColors.primary, v),
              shape: BoxShape.circle,
              boxShadow: now ? [BoxShadow(color: G4MColors.primary.withValues(alpha: .35), blurRadius: 16, spreadRadius: 2)] : null,
            ),
            child: Icon(ic, size: 20, color: Color.lerp(G4MColors.inkMuted, Colors.white, v)),
          ),
        );
    final header = Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(children: [
        Expanded(child: Text(t.orderStatus, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18))),
        if (o.status == OrderStatus.pending) Pill(t.awaitingPayment, icon: Icons.hourglass_top_rounded),
      ]),
    );
    if (phone) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        header,
        for (var i = 0; i < steps.length; i++)
          IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Column(children: [
                dot(steps[i].$2, steps[i].$3, icons[steps[i].$1] ?? Icons.circle),
                if (i < steps.length - 1) Expanded(child: Container(width: 3, color: steps[i + 1].$2 ? G4MColors.primary : G4MColors.line)),
              ]),
              const SizedBox(width: 14),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 18),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(t.status(steps[i].$1), style: TextStyle(fontWeight: FontWeight.w800, color: steps[i].$2 ? G4MColors.ink : G4MColors.inkMuted)),
                    if (steps[i].$4 != null) Text(l.dateTime(steps[i].$4), style: const TextStyle(fontSize: 12.5, color: G4MColors.inkMuted)),
                  ]),
                ),
              ),
            ]),
          ),
      ]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      header,
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (var i = 0; i < steps.length; i++)
          Expanded(
            child: Column(children: [
              Row(children: [
                Expanded(child: Container(height: 3, color: i == 0 ? Colors.transparent : (steps[i].$2 ? G4MColors.primary : G4MColors.line))),
                dot(steps[i].$2, steps[i].$3, icons[steps[i].$1] ?? Icons.circle),
                Expanded(child: Container(height: 3, color: i == steps.length - 1 ? Colors.transparent : (steps[i + 1].$2 ? G4MColors.primary : G4MColors.line))),
              ]),
              const SizedBox(height: 8),
              Text(t.status(steps[i].$1), textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: steps[i].$2 ? G4MColors.ink : G4MColors.inkMuted)),
              if (steps[i].$4 != null) Text(l.time(steps[i].$4), style: const TextStyle(fontSize: 11.5, color: G4MColors.inkMuted)),
            ]),
          ),
      ]),
    ]);
  }
}

/// Live countdown to the ETA (feature 28: quick delivery arrival countdown).
class _Countdown extends StatefulWidget {
  const _Countdown({required this.order});
  final ShopOrder order;
  @override
  State<_Countdown> createState() => _CountdownState();
}

class _CountdownState extends State<_Countdown> {
  Timer? _t;
  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) => mounted ? setState(() {}) : null);
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    final l = context.l;
    final t = l.orders;
    final quick = o.speed == 'quick15' || o.speed == 'quick30';
    final left = o.etaAt!.difference(DateTime.now());
    final total = Duration(minutes: o.speed == 'quick15' ? 15 : (o.speed == 'quick30' ? 30 : 60));
    final frac = (1 - left.inSeconds / total.inSeconds).clamp(0.0, 1.0);
    final mm = left.inMinutes.clamp(0, 9999).toString().padLeft(2, '0');
    final ss = (left.inSeconds % 60).clamp(0, 59).toString().padLeft(2, '0');
    final scheduled = o.speed == 'scheduled' && o.scheduledSlot.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(gradient: G4MColors.heroGradient, borderRadius: BorderRadius.circular(24)),
      child: Row(children: [
        SizedBox(
          width: 86,
          height: 86,
          child: Stack(fit: StackFit.expand, children: [
            CircularProgressIndicator(value: quick ? frac : null, strokeWidth: 7, color: G4MColors.accent, backgroundColor: Colors.white24),
            Center(child: Icon(quick ? Icons.bolt_rounded : Icons.schedule_rounded, color: Colors.white, size: 36)),
          ]),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              scheduled ? t.scheduledDelivery : (quick ? t.minuteDelivery(o.speed == 'quick15' ? 15 : 30) : t.estimatedArrival),
              style: const TextStyle(color: Color(0xFFD6EADF), fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            if (scheduled)
              Text('${o.scheduledSlot['date']} · ${o.scheduledSlot['from']}–${o.scheduledSlot['to']}', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800))
            else if (left.isNegative)
              Text(t.arrivingAnyMoment, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800))
            else
              Semantics(
                liveRegion: false,
                label: t.arrivingIn(left.inMinutes),
                child: ExcludeSemantics(
                  // Clock digits stay LTR (mm:ss) in every language.
                  child: Text('$mm:$ss',
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w800, letterSpacing: 2, fontFeatures: [FontFeature.tabularFigures()])),
                ),
              ),
            Text('${t.eta(l.time(o.etaAt))}${o.distanceKm > 0 ? ' · ${t.kmAway(o.distanceKm.toStringAsFixed(1))}' : ''}', style: const TextStyle(color: Color(0xFFD6EADF))),
          ]),
        ),
      ]),
    );
  }
}

/// Rider's live position (features 6, 7, 33). Customers cannot read `deliveryPartners/*`, so the backend
/// mirrors the partner's GPS into `orders.riderLocation`; the live order stream drives this map.
class _RiderTracker extends StatelessWidget {
  const _RiderTracker({required this.order});
  final ShopOrder order;
  @override
  Widget build(BuildContext context) {
    final o = order;
    final l = context.l;
    final t = l.orders;
    double? d(Object? v) => v is num ? v.toDouble() : null;
    final aLat = d(o.address['lat']), aLng = d(o.address['lng']);
    final home = aLat == null || aLng == null ? null : LatLng(aLat, aLng);
    final rl = o.data['riderLocation'] is Map ? Map<String, dynamic>.from(o.data['riderLocation'] as Map) : const <String, dynamic>{};
    final rLat = d(rl['lat']), rLng = d(rl['lng']);
    final rider = rLat == null || rLng == null ? null : LatLng(rLat, rLng);
    final at = rl['at'] is Timestamp ? (rl['at'] as Timestamp).toDate() : null;
    final pts = [?rider, ?home];
    final name = o.deliveryPartnerName.isEmpty ? t.yourRider : o.deliveryPartnerName;
    final phone = '${o.data['deliveryPartnerPhone'] ?? ''}';
    return Panel(
      padding: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (pts.isNotEmpty)
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(G4MRadius.lg)),
            child: SizedBox(height: context.isPhone ? 260 : 360, child: _LiveMap(rider: rider, home: home)),
          )
        else
          Container(
            height: 120,
            alignment: Alignment.center,
            color: G4MColors.surfaceAlt,
            child: Text(t.waitingLocation, style: const TextStyle(color: G4MColors.inkMuted)),
          ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            const CircleAvatar(radius: 24, backgroundColor: G4MColors.primarySoft, child: Icon(Icons.delivery_dining_rounded, color: G4MColors.primaryDeep)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                Text(
                  rider == null ? t.locationAppears : '${t.liveLocation}${at == null ? '' : ' · ${t.updatedAgo(l.ago(at))}'}',
                  style: const TextStyle(color: G4MColors.inkMuted, fontSize: 13),
                ),
              ]),
            ),
            if (phone.isNotEmpty) IconButton.filled(tooltip: t.callRider, onPressed: () => launchUrl(Uri.parse('tel:$phone')), icon: const Icon(Icons.call_rounded)),
          ]),
        ),
      ]),
    );
  }
}

/// Map that follows the rider: re-fits the camera whenever the rider moves.
class _LiveMap extends StatefulWidget {
  const _LiveMap({required this.rider, required this.home});
  final LatLng? rider, home;
  @override
  State<_LiveMap> createState() => _LiveMapState();
}

class _LiveMapState extends State<_LiveMap> {
  final _map = MapController();
  bool _ready = false;

  List<LatLng> get _pts => [?widget.rider, ?widget.home];

  void _fit() {
    if (!_ready || _pts.isEmpty) return;
    try {
      if (_pts.length == 1) {
        _map.move(_pts.first, 15);
      } else {
        _map.fitCamera(CameraFit.coordinates(coordinates: _pts, padding: const EdgeInsets.all(70), maxZoom: 17));
      }
    } catch (_) {}
  }

  @override
  void didUpdateWidget(_LiveMap old) {
    super.didUpdateWidget(old);
    if (old.rider != widget.rider) _fit();
  }

  @override
  Widget build(BuildContext context) {
    final rider = widget.rider, home = widget.home;
    return FlutterMap(
      mapController: _map,
      options: MapOptions(
        initialCenter: _pts.first,
        initialZoom: 15,
        onMapReady: () {
          _ready = true;
          _fit();
        },
      ),
      children: [
        ...osmBase().take(1),
        if (rider != null && home != null)
          PolylineLayer(polylines: [Polyline(points: [rider, home], color: G4MColors.primary, strokeWidth: 4, pattern: StrokePattern.dashed(segments: const [10, 8]))]),
        MarkerLayer(markers: [
          if (home != null) Marker(point: home, width: 48, height: 60, alignment: Alignment.topCenter, child: const MapPin(icon: Icons.home_rounded, color: G4MColors.primaryDeep)),
          if (rider != null) Marker(point: rider, width: 52, height: 64, alignment: Alignment.topCenter, child: const _RiderPulse()),
        ]),
        ...osmBase().skip(1),
      ],
    );
  }
}

class _RiderPulse extends StatefulWidget {
  const _RiderPulse();
  @override
  State<_RiderPulse> createState() => _RiderPulseState();
}

class _RiderPulseState extends State<_RiderPulse> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(alignment: Alignment.topCenter, clipBehavior: Clip.none, children: [
        if (!context.reduceMotion)
          Positioned(
            top: -6,
            child: AnimatedBuilder(
              animation: _c,
              builder: (_, _) => Container(
                width: 44 + _c.value * 24,
                height: 44 + _c.value * 24,
                transform: Matrix4.translationValues(0, -_c.value * 12 + 6, 0),
                decoration: BoxDecoration(shape: BoxShape.circle, color: G4MColors.accent.withValues(alpha: (1 - _c.value) * .35)),
              ),
            ),
          ),
        const MapPin(icon: Icons.delivery_dining_rounded, color: G4MColors.accent),
      ]);
}

class _Items extends StatelessWidget {
  const _Items({required this.order});
  final ShopOrder order;
  @override
  Widget build(BuildContext context) {
    final l = context.l;
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(l.orders.itemsHeading(order.itemCount), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        const SizedBox(height: 10),
        for (final it in order.items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(children: [
              Container(
                width: 56,
                height: 56,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: const Color(0xFFF4F8F5), borderRadius: BorderRadius.circular(12)),
                child: NetImage(it.image, fit: BoxFit.contain, semanticLabel: it.name),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  TextLink(it.name, to: '/p/${it.productId}', style: const TextStyle(fontWeight: FontWeight.w700, color: G4MColors.ink)),
                  Text([if (it.variantName.isNotEmpty) it.variantName, '${l.number(it.qty)} × ${l.money(it.price)}', if (it.sellerName.isNotEmpty) it.sellerName].join(' · '),
                      style: const TextStyle(color: G4MColors.inkMuted, fontSize: 13)),
                ]),
              ),
              Text(l.money(it.lineTotal), style: const TextStyle(fontWeight: FontWeight.w800)),
            ]),
          ),
      ]),
    );
  }
}

class _Bill extends StatelessWidget {
  const _Bill({required this.order});
  final ShopOrder order;
  @override
  Widget build(BuildContext context) {
    final o = order;
    final l = context.l;
    final t = l.orders;
    Widget row(String k, String v, {Color? c, bool bold = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            Expanded(child: Text(k, style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w500))),
            Text(v, style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w700, color: c, fontSize: bold ? 17 : 14.5)),
          ]),
        );
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(t.paymentSummary, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        const SizedBox(height: 10),
        row(t.itemsTotal, l.money(o.subtotal)),
        row(t.deliveryFee, o.deliveryFee == 0 ? t.free : l.money(o.deliveryFee), c: o.deliveryFee == 0 ? kDiscountInk : null),
        if (o.discount > 0) row(o.couponCode.isEmpty ? t.discount : t.discountWithCode(o.couponCode), '− ${l.money(o.discount)}', c: kDiscountInk),
        if (o.tax > 0) row(t.taxes, l.money(o.tax)),
        if (o.walletUsed > 0) row(t.paidFromWallet, '− ${l.money(o.walletUsed)}', c: kDiscountInk),
        const Divider(height: 20),
        row(t.total, l.money(o.total), bold: true),
        const SizedBox(height: 8),
        Row(children: [
          Text(t.paymentMethod(o.paymentMethod), style: const TextStyle(color: G4MColors.inkMuted, fontWeight: FontWeight.w600)),
          const Spacer(),
          StatusChip(o.paymentStatus, label: t.paymentStatus(o.paymentStatus)),
        ]),
      ]),
    );
  }
}

class _Delivery extends StatelessWidget {
  const _Delivery({required this.order});
  final ShopOrder order;
  @override
  Widget build(BuildContext context) {
    final o = order;
    final a = Address('x', o.address);
    final t = context.l.orders;
    final sep = context.l.rtl ? '، ' : ', ';
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(o.deliveryType == 'pickup' ? t.selfPickup : t.deliveryAddress, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        const SizedBox(height: 8),
        if (o.deliveryType == 'pickup')
          Text(t.collectFrom(o.items.map((e) => e.sellerName).where((e) => e.isNotEmpty).toSet().join(sep)), style: const TextStyle(height: 1.5))
        else ...[
          Text('${a.name}${a.phone.isEmpty ? '' : ' · ${a.phone}'}', style: const TextStyle(fontWeight: FontWeight.w700)),
          Text(a.oneLine, style: const TextStyle(color: G4MColors.inkMuted, height: 1.5)),
        ],
        const SizedBox(height: 8),
        Text(
          switch (o.speed) {
            'quick15' => t.quick15,
            'quick30' => t.quick30,
            'scheduled' => t.scheduledAt('${o.scheduledSlot['date'] ?? ''} ${o.scheduledSlot['from'] ?? ''}–${o.scheduledSlot['to'] ?? ''}'),
            _ => t.standardDelivery,
          },
          style: const TextStyle(fontWeight: FontWeight.w700, color: G4MColors.primaryDeep),
        ),
      ]),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.order});
  final ShopOrder order;

  Future<void> _cancel(BuildContext context) async {
    final ctl = TextEditingController();
    final t = context.l.orders;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.cancelTitle),
        content: TextField(controller: ctl, decoration: InputDecoration(labelText: t.reasonOptional)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t.keepOrder)),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: G4MColors.danger), onPressed: () => Navigator.pop(ctx, true), child: Text(t.cancelOrder)),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await G4MApi.instance.updateOrderStatus(order.id, OrderStatus.cancelled, note: ctl.text.trim().isEmpty ? t.cancelledByCustomer : ctl.text.trim());
      if (context.mounted) toast(context, t.orderCancelled);
    } catch (e) {
      if (context.mounted) toast(context, friendlyError(e), error: true);
    }
  }

  Future<void> _return(BuildContext context) async {
    final picked = <int>{for (var i = 0; i < order.items.length; i++) i};
    final reason = TextEditingController();
    final l = context.l;
    final t = l.orders;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: Text(t.requestReturn),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t.whichItems, style: const TextStyle(fontWeight: FontWeight.w800)),
                for (var i = 0; i < order.items.length; i++)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: picked.contains(i),
                    onChanged: (v) => set(() => v == true ? picked.add(i) : picked.remove(i)),
                    title: Text('${order.items[i].name} × ${l.number(order.items[i].qty)}'),
                  ),
                const SizedBox(height: 8),
                TextField(controller: reason, maxLines: 3, decoration: InputDecoration(labelText: t.whatWentWrong)),
                const SizedBox(height: 8),
                Text(t.refundToWallet, style: const TextStyle(color: G4MColors.inkMuted, fontSize: 13)),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.common.cancel)),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(t.submitRequest)),
          ],
        ),
      ),
    );
    if (ok != true || picked.isEmpty) return;
    if (reason.text.trim().isEmpty) {
      if (context.mounted) toast(context, t.tellReason, error: true);
      return;
    }
    try {
      await G4MApi.instance.requestReturn({
        'orderId': order.id,
        'items': [for (final i in picked) {'productId': order.items[i].productId, 'variantId': order.items[i].variantId, 'qty': order.items[i].qty}],
        'reason': reason.text.trim(),
        'refundTo': 'wallet',
      });
      if (context.mounted) toast(context, t.returnRequested);
    } catch (e) {
      if (context.mounted) toast(context, friendlyError(e), error: true);
    }
  }

  Future<void> _reorder(BuildContext context) async {
    final t = context.l.orders;
    try {
      final ps = await CatalogRepo.instance.productsByIds(order.items.map((e) => e.productId).toSet().toList());
      var n = 0;
      for (final it in order.items) {
        final p = ps.where((e) => e.id == it.productId).firstOrNull;
        if (p == null || !p.inStock) continue;
        await Shop.instance.setQty(p, it.qty, variantId: it.variantId);
        n++;
      }
      if (context.mounted) {
        toast(context, n == 0 ? t.outOfStock : t.addedToCart(n), actionLabel: n == 0 ? null : t.viewCart, onAction: () => context.go('/cart'));
      }
    } catch (e) {
      if (context.mounted) toast(context, friendlyError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = order;
    final t = context.l.orders;
    final canCancel = {OrderStatus.pending, OrderStatus.placed, OrderStatus.confirmed}.contains(o.status);
    final canReturn = o.status == OrderStatus.delivered;
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        FilledButton.icon(onPressed: () => _reorder(context), icon: const Icon(Icons.replay_rounded), label: Text(t.orderAgain)),
        if (canReturn) ...[const SizedBox(height: 8), OutlinedButton.icon(onPressed: () => _return(context), icon: const Icon(Icons.assignment_return_outlined), label: Text(t.returnItems))],
        if (canCancel) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _cancel(context),
            style: OutlinedButton.styleFrom(foregroundColor: G4MColors.danger),
            icon: const Icon(Icons.cancel_outlined),
            label: Text(t.cancelOrder),
          ),
        ],
        const SizedBox(height: 8),
        TextButton.icon(onPressed: WebBridge.print, icon: const Icon(Icons.print_outlined), label: Text(t.printReceipt)),
        TextButton.icon(onPressed: () => context.go('/faq'), icon: const Icon(Icons.help_outline_rounded), label: Text(t.needHelp)),
      ]),
    );
  }
}
