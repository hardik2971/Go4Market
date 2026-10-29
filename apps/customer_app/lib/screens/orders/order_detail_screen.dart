import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:g4m_core/g4m_core.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/addons.dart';
import '../../core/data.dart';
import '../../core/nav.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/ui.dart';
import '../product/product_detail_screen.dart' show ReviewSheet;
import '../profile/help_screen.dart';

const _transit = {OrderStatus.assigned, OrderStatus.pickedUp, OrderStatus.outForDelivery};

class OrderDetailScreen extends StatelessWidget {
  const OrderDetailScreen({super.key, required this.orderId, this.initial});
  final String orderId;
  final ShopOrder? initial;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return StreamBuilder<ShopOrder?>(
      stream: ShopperRepo.instance.order(orderId),
      initialData: initial,
      builder: (context, snap) {
        final o = snap.data;
        if (snap.hasError && o == null) {
          return Scaffold(appBar: AppBar(), body: ErrorView(error: snap.error!));
        }
        if (o == null) {
          return Scaffold(
            appBar: AppBar(),
            body: snap.connectionState == ConnectionState.waiting
                ? const ListSkeleton(count: 4, height: 120)
                : const EmptyState(icon: Icons.receipt_long_outlined, title: 'Order not found'),
          );
        }
        final showMap = o.deliveryType == 'home' && o.deliveryPartnerId.isNotEmpty && _transit.contains(o.status);
        return Scaffold(
          appBar: AppBar(
            title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Order #${o.orderNo}'),
              Text(Fmt.dateTime(o.createdAt), style: context.text.bodySmall),
            ]),
            actions: [
              IconButton(
                tooltip: 'Copy order number',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: o.orderNo));
                  context.toast('Order number copied');
                },
                icon: const Icon(Icons.copy_rounded),
              ),
            ],
          ),
          body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [
            _HeaderCard(order: o).stagger(0),
            if (o.isActive && (o.speed == 'quick15' || o.speed == 'quick30') && o.status != OrderStatus.pending) ...[
              const SizedBox(height: 12),
              ArrivalCountdown(order: o).stagger(1),
            ],
            if (showMap) ...[
              const SizedBox(height: 12),
              LiveRiderMap(order: o).stagger(2),
            ],
            if (o.deliveryOtp.isNotEmpty && o.isActive && o.status != OrderStatus.pending) ...[
              const SizedBox(height: 12),
              _OtpCard(otp: o.deliveryOtp, label: l.deliveryOtp, pickup: o.deliveryType == 'pickup').stagger(3),
            ],
            const SizedBox(height: 12),
            _Stepper(order: o).stagger(4),
            const SizedBox(height: 12),
            _ItemsCard(order: o).stagger(5),
            const SizedBox(height: 12),
            _BillCard(order: o).stagger(6),
            const SizedBox(height: 12),
            if (o.deliveryType == 'home' && o.address.isNotEmpty) _AddressCard(order: o).stagger(7),
            const SizedBox(height: 16),
            _Actions(order: o).stagger(8),
          ]),
        );
      },
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.order});
  final ShopOrder order;
  @override
  Widget build(BuildContext context) {
    final o = order;
    final c = statusColor(o.status);
    final subtitle = switch (o.status) {
      OrderStatus.pending => 'Waiting for payment confirmation',
      OrderStatus.placed => 'The store will confirm shortly',
      OrderStatus.confirmed => 'Your order is being prepared',
      OrderStatus.packed => o.deliveryType == 'pickup' ? 'Almost ready for pickup' : 'Packed, finding a rider',
      OrderStatus.assigned => '${o.deliveryPartnerName.isEmpty ? 'A rider' : o.deliveryPartnerName} is heading to the store',
      OrderStatus.pickedUp => 'Picked up, on the way',
      OrderStatus.outForDelivery => 'Out for delivery, arriving soon',
      OrderStatus.readyForPickup => 'Ready! Show the OTP at the store',
      OrderStatus.delivered => 'Delivered. Enjoy!',
      OrderStatus.cancelled => o.cancelReason.isNotEmpty ? 'Cancelled: ${o.cancelReason}' : 'This order was cancelled',
      OrderStatus.returned => 'Returned',
      _ => '',
    };
    return AppCard(
      color: c.withValues(alpha: context.isDark ? .16 : .08),
      child: Row(children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(16)),
          child: Icon(_statusIcon(o.status), color: Colors.white),
        ).animate(onPlay: (ctl) => o.isActive ? ctl.repeat(reverse: true) : null).scaleXY(end: o.isActive ? 1.06 : 1, duration: 900.ms),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(OrderStatus.label(o.status), style: context.text.titleLarge?.copyWith(color: c)),
            Text(subtitle, style: context.text.bodyMedium),
          ]),
        ),
      ]),
    );
  }
}

IconData _statusIcon(String s) => switch (s) {
      OrderStatus.pending => Icons.hourglass_top_rounded,
      OrderStatus.placed => Icons.receipt_long_rounded,
      OrderStatus.confirmed => Icons.thumb_up_alt_rounded,
      OrderStatus.packed => Icons.inventory_2_rounded,
      OrderStatus.assigned => Icons.person_pin_circle_rounded,
      OrderStatus.pickedUp => Icons.shopping_bag_rounded,
      OrderStatus.outForDelivery => Icons.delivery_dining_rounded,
      OrderStatus.readyForPickup => Icons.storefront_rounded,
      OrderStatus.delivered => Icons.check_circle_rounded,
      OrderStatus.cancelled => Icons.cancel_rounded,
      OrderStatus.returned => Icons.assignment_return_rounded,
      _ => Icons.circle_outlined,
    };

// ---------------------------------------------------------------- countdown (#28)

class ArrivalCountdown extends StatefulWidget {
  const ArrivalCountdown({super.key, required this.order});
  final ShopOrder order;
  @override
  State<ArrivalCountdown> createState() => _ArrivalCountdownState();
}

class _ArrivalCountdownState extends State<ArrivalCountdown> {
  Timer? _t;
  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    final window = Duration(minutes: o.speed == 'quick15' ? 15 : 30);
    final start = o.createdAt ?? DateTime.now();
    final eta = o.etaAt ?? start.add(window);
    final total = eta.difference(start).inSeconds.clamp(1, 1 << 30);
    final left = eta.difference(DateTime.now());
    final late = left.isNegative;
    final frac = late ? 1.0 : 1 - left.inSeconds / total;
    final mm = left.inMinutes.abs().toString().padLeft(2, '0');
    final ss = (left.inSeconds.abs() % 60).toString().padLeft(2, '0');
    final color = late ? G4MColors.warning : G4MColors.accent;
    return AppCard(
      color: context.softAccent,
      child: Row(children: [
        SizedBox(
          width: 92,
          height: 92,
          child: Stack(alignment: Alignment.center, children: [
            SizedBox.expand(
              child: CircularProgressIndicator(
                value: frac.clamp(0, 1),
                strokeWidth: 8,
                strokeCap: StrokeCap.round,
                color: color,
                backgroundColor: color.withValues(alpha: .15),
              ),
            ),
            Column(mainAxisSize: MainAxisSize.min, children: [
              Text('$mm:$ss', style: context.text.titleLarge?.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
              Text(late ? 'late' : 'min', style: context.text.bodySmall),
            ]),
          ]),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.bolt_rounded, color: G4MColors.accent),
              Text(o.speed == 'quick15' ? ' 15-min delivery' : ' 30-min delivery', style: context.text.titleSmall),
            ]),
            const SizedBox(height: 4),
            Text(
              late ? 'Running a little late, your rider is almost there.' : 'Arriving by ${Fmt.time(eta)}',
              style: context.text.bodyMedium,
            ),
          ]),
        ),
      ]),
    );
  }
}

// ---------------------------------------------------------------- live map (#06)

class LatLngTween extends Tween<LatLng> {
  LatLngTween({required LatLng begin, required LatLng end}) : super(begin: begin, end: end);
  @override
  LatLng lerp(double t) => LatLng(begin!.latitude + (end!.latitude - begin!.latitude) * t, begin!.longitude + (end!.longitude - begin!.longitude) * t);
}

class LiveRiderMap extends StatefulWidget {
  const LiveRiderMap({super.key, required this.order});
  final ShopOrder order;
  @override
  State<LiveRiderMap> createState() => _LiveRiderMapState();
}

class _LiveRiderMapState extends State<LiveRiderMap> {
  final _map = MapController();
  LatLng? _last;
  bool _fitted = false;
  Stream<DeliveryPartner?>? _stream;
  String? _pid;
  Stream<DeliveryPartner?> get _partner {
    final id = widget.order.deliveryPartnerId;
    if (_stream == null || _pid != id) {
      _pid = id;
      _stream = Fs.deliveryPartners.doc(id).snapshots().map((d) => d.exists ? DeliveryPartner.fromDoc(d) : null);
    }
    return _stream!;
  }

  LatLng? get _dest {
    final a = widget.order.address;
    final lat = a['lat'], lng = a['lng'];
    return lat is num && lng is num ? LatLng(lat.toDouble(), lng.toDouble()) : null;
  }

  /// Some backends mirror the rider position on the order; accept that too.
  LatLng? _fromOrder() {
    final d = widget.order.data;
    final r = d['riderLocation'] ?? d['deliveryLocation'];
    if (r is Map && r['lat'] is num && r['lng'] is num) return LatLng((r['lat'] as num).toDouble(), (r['lng'] as num).toDouble());
    return null;
  }

  void _fit(LatLng rider) {
    final dest = _dest;
    try {
      if (dest == null) {
        _map.move(rider, 15);
      } else {
        _map.fitCamera(CameraFit.coordinates(coordinates: [rider, dest], padding: const EdgeInsets.all(48), maxZoom: 16));
      }
      _fitted = true;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    return StreamBuilder<DeliveryPartner?>(
      stream: _partner,
      builder: (context, snap) {
        final dp = snap.data;
        LatLng? rider = dp?.lat != null && dp?.lng != null ? LatLng(dp!.lat!, dp.lng!) : _fromOrder();
        final dest = _dest;
        final phone = dp?.phone.isNotEmpty == true ? dp!.phone : '${o.data['deliveryPartnerPhone'] ?? ''}';
        final name = dp?.name.isNotEmpty == true ? dp!.name : (o.deliveryPartnerName.isEmpty ? 'Your rider' : o.deliveryPartnerName);
        if (rider != null && !_fitted) WidgetsBinding.instance.addPostFrameCallback((_) => _fit(rider));
        final from = _last ?? rider;
        if (rider != null) _last = rider;
        return AppCard(
          padding: EdgeInsets.zero,
          child: Column(children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: SizedBox(
                height: 230,
                child: rider == null && dest == null
                    ? Container(
                        color: context.cardAlt,
                        alignment: Alignment.center,
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          snap.hasError ? 'Live location is not shared for this order yet.' : 'Waiting for your rider\'s location…',
                          textAlign: TextAlign.center,
                          style: context.text.bodyMedium,
                        ),
                      )
                    : Stack(children: [
                        FlutterMap(
                          mapController: _map,
                          options: MapOptions(
                            initialCenter: rider ?? dest!,
                            initialZoom: 14,
                            interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
                          ),
                          children: [
                            TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.go4market.customer'),
                            if (rider != null && dest != null)
                              PolylineLayer(polylines: [
                                Polyline(points: [rider, dest], color: G4MColors.primary.withValues(alpha: .7), strokeWidth: 4, pattern: StrokePattern.dashed(segments: const [10, 8])),
                              ]),
                            MarkerLayer(markers: [
                              if (dest != null)
                                Marker(
                                  point: dest,
                                  width: 44,
                                  height: 44,
                                  alignment: Alignment.topCenter,
                                  child: const Icon(Icons.home_rounded, color: G4MColors.primaryDeep, size: 36),
                                ),
                            ]),
                            if (rider != null)
                              TweenAnimationBuilder<LatLng>(
                                tween: LatLngTween(begin: from!, end: rider),
                                duration: const Duration(milliseconds: 1800),
                                curve: Curves.easeInOutCubic,
                                builder: (_, p, _) => MarkerLayer(markers: [
                                  Marker(point: p, width: 64, height: 64, child: const _RiderPin()),
                                ]),
                              ),
                            const RichAttributionWidget(attributions: [TextSourceAttribution('OpenStreetMap contributors')]),
                          ],
                        ),
                        Positioned(
                          right: 10,
                          top: 10,
                          child: IconButton.filledTonal(
                            onPressed: rider == null ? null : () => _fit(rider),
                            icon: const Icon(Icons.center_focus_strong_rounded),
                          ),
                        ),
                        if (rider != null && dest != null)
                          Positioned(
                            left: 10,
                            top: 10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(color: context.card, borderRadius: BorderRadius.circular(20), boxShadow: context.softShadow),
                              child: Text('${haversineKm(rider.latitude, rider.longitude, dest.latitude, dest.longitude).toStringAsFixed(1)} km away',
                                  style: context.text.labelLarge),
                            ),
                          ),
                      ]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: context.softPrimary,
                  backgroundImage: dp?.photoUrl.isNotEmpty == true ? NetworkImage(dp!.photoUrl) : null,
                  child: dp?.photoUrl.isNotEmpty == true ? null : const Icon(Icons.delivery_dining_rounded, color: G4MColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(name, style: context.text.titleSmall),
                    Text(
                      [
                        if (dp != null) Fmt.titleCase(dp.vehicleType),
                        if (dp?.vehicleNo.isNotEmpty == true) dp!.vehicleNo,
                        if ((dp?.rating ?? 0) > 0) '★ ${dp!.rating.toStringAsFixed(1)}',
                        if (dp?.locationUpdatedAt != null) 'updated ${Fmt.ago(dp!.locationUpdatedAt)}',
                      ].join(' · '),
                      style: context.text.bodySmall,
                    ),
                  ]),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 42)),
                  onPressed: phone.isEmpty ? null : () => launchUrl(Uri(scheme: 'tel', path: phone)),
                  icon: const Icon(Icons.call_rounded, size: 18),
                  label: Text(AppLocalizations.of(context).callRider),
                ),
              ]),
            ),
          ]),
        );
      },
    );
  }
}

class _RiderPin extends StatelessWidget {
  const _RiderPin();
  @override
  Widget build(BuildContext context) => Stack(alignment: Alignment.center, children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(shape: BoxShape.circle, color: G4MColors.accent.withValues(alpha: .2)),
        ).animate(onPlay: (c) => c.repeat()).scaleXY(begin: .5, end: 1.1, duration: 1400.ms).fadeOut(duration: 1400.ms),
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: G4MColors.accent,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: G4MShadows.glowAccent,
          ),
          child: const Icon(Icons.delivery_dining_rounded, color: Colors.white, size: 20),
        ),
      ]);
}

// ---------------------------------------------------------------- otp

class _OtpCard extends StatelessWidget {
  const _OtpCard({required this.otp, required this.label, required this.pickup});
  final String otp, label;
  final bool pickup;
  @override
  Widget build(BuildContext context) => AppCard(
        child: Row(children: [
          const Icon(Icons.lock_rounded, color: G4MColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: context.text.titleSmall),
              Text(pickup ? 'Share at the store counter' : 'Share with your rider at the door', style: context.text.bodySmall),
            ]),
          ),
          Row(children: [
            for (final (i, ch) in otp.split('').indexed)
              Container(
                margin: const EdgeInsets.only(left: 4),
                width: 30,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: context.softPrimary, borderRadius: BorderRadius.circular(8)),
                child: Text(ch, style: context.text.titleLarge?.copyWith(color: G4MColors.primaryDeep)),
              ).animate(delay: (i * 80).ms).fadeIn().slideY(begin: .5),
          ]),
        ]),
      );
}

// ---------------------------------------------------------------- stepper (#07)

class _Stepper extends StatelessWidget {
  const _Stepper({required this.order});
  final ShopOrder order;
  @override
  Widget build(BuildContext context) {
    final o = order;
    final flow = [...(o.deliveryType == 'pickup' ? OrderStatus.pickupFlow : OrderStatus.homeFlow)];
    if (o.status == OrderStatus.pending) flow.insert(0, OrderStatus.pending);
    final terminalSide = o.status == OrderStatus.cancelled || o.status == OrderStatus.returned;
    final times = <String, DateTime?>{for (final t in o.timeline) t.status: t.at};
    times.putIfAbsent(OrderStatus.placed, () => o.createdAt);
    var cur = flow.indexOf(o.status);
    if (terminalSide) {
      // Show how far it got, then the side exit.
      cur = -1;
      for (var i = 0; i < flow.length; i++) {
        if (times[flow[i]] != null) cur = i;
      }
      flow
        ..removeRange(cur + 1, flow.length)
        ..add(o.status);
      cur = flow.length - 1;
    }
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Order journey', style: context.text.titleSmall),
        const SizedBox(height: 12),
        for (var i = 0; i < flow.length; i++)
          _StepRow(
            label: OrderStatus.label(flow[i]),
            time: times[flow[i]],
            done: i <= cur,
            current: i == cur,
            last: i == flow.length - 1,
            color: i == cur && terminalSide ? statusColor(o.status) : G4MColors.primary,
            note: o.timeline.where((t) => t.status == flow[i] && t.note.isNotEmpty).map((t) => t.note).firstOrNull,
            index: i,
          ),
      ]),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.label,
    required this.time,
    required this.done,
    required this.current,
    required this.last,
    required this.color,
    required this.index,
    this.note,
  });
  final String label;
  final DateTime? time;
  final bool done, current, last;
  final Color color;
  final int index;
  final String? note;
  @override
  Widget build(BuildContext context) {
    final dot = AnimatedContainer(
      duration: G4MMotion.emphasized,
      width: current ? 22 : 16,
      height: current ? 22 : 16,
      decoration: BoxDecoration(
        color: done ? color : context.card,
        shape: BoxShape.circle,
        border: Border.all(color: done ? color : context.line, width: 2),
        boxShadow: current ? [BoxShadow(color: color.withValues(alpha: .4), blurRadius: 10)] : null,
      ),
      child: done ? Icon(Icons.check_rounded, size: current ? 14 : 10, color: Colors.white) : null,
    );
    // The connector is a Positioned line under the dot rather than an Expanded child inside
    // IntrinsicHeight: an expanding child has infinite intrinsic height, which broke layout.
    final dotSize = current ? 22.0 : 16.0;
    return Stack(children: [
      if (!last)
        Positioned(
          left: 13 - 1.25,
          top: dotSize + 2,
          bottom: 2,
          width: 2.5,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: done && !current ? 1 : 0),
            duration: Duration(milliseconds: 400 + index * 120),
            curve: G4MMotion.curve,
            builder: (_, v, _) => Stack(fit: StackFit.expand, children: [
              ColoredBox(color: context.line),
              Align(
                alignment: Alignment.topCenter,
                child: FractionallySizedBox(heightFactor: v, widthFactor: 1, child: ColoredBox(color: color)),
              ),
            ]),
          ),
        ),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 26,
          child: Center(
            child: current ? dot.animate(onPlay: (c) => c.repeat(reverse: true)).scaleXY(end: 1.12, duration: 800.ms) : dot,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: last ? 0 : 18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  style: context.text.bodyMedium?.copyWith(
                    fontWeight: current ? FontWeight.w800 : FontWeight.w600,
                    color: done ? context.ink : context.muted,
                  )),
              if (time != null && done) Text(Fmt.dateTime(time), style: context.text.bodySmall),
              if (note != null) Text(note!, style: context.text.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
            ]),
          ),
        ),
      ]),
    ]);
  }
}

// ---------------------------------------------------------------- items / bill / address

class _ItemsCard extends StatelessWidget {
  const _ItemsCard({required this.order});
  final ShopOrder order;
  @override
  Widget build(BuildContext context) {
    final delivered = order.status == OrderStatus.delivered;
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${order.itemCount} items', style: context.text.titleSmall),
        const SizedBox(height: 8),
        for (final it in order.items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              Img(it.image, width: 52, height: 52, radius: 10, iconSize: 18),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(it.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                  Text([if (it.variantName.isNotEmpty) it.variantName, '${it.qty} × ${Fmt.money(it.price)}', if (it.sellerName.isNotEmpty) it.sellerName].join(' · '),
                      style: context.text.bodySmall),
                  if (it.addons.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        it.addons.map((a) => '+ ${a.name}${a.price > 0 ? ' (${Fmt.money(a.price)})' : ''}').join('  '),
                        style: context.text.bodySmall?.copyWith(color: G4MColors.primary, fontWeight: FontWeight.w700),
                      ),
                    ),
                  if (delivered)
                    TextButton.icon(
                      style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 30), visualDensity: VisualDensity.compact),
                      onPressed: () => showAppSheet(context, builder: (_) => ReviewSheet(productId: it.productId, productName: it.name)),
                      icon: const Icon(Icons.star_outline_rounded, size: 16),
                      label: const Text('Rate this product'),
                    ),
                ]),
              ),
              Text(Fmt.money(it.lineTotal), style: context.text.titleSmall),
            ]),
          ),
      ]),
    );
  }
}

class _BillCard extends StatelessWidget {
  const _BillCard({required this.order});
  final ShopOrder order;
  @override
  Widget build(BuildContext context) {
    final o = order;
    Widget row(String k, String v, {bool bold = false, Color? color}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [
            Expanded(child: Text(k, style: bold ? context.text.titleSmall : context.text.bodyMedium)),
            Text(v, style: (bold ? context.text.titleSmall : context.text.bodyMedium)?.copyWith(color: color, fontWeight: bold ? FontWeight.w800 : null)),
          ]),
        );
    return AppCard(
      child: Column(children: [
        row('Item total', Fmt.money(o.subtotal)),
        row('Delivery', o.deliveryFee == 0 ? 'FREE' : Fmt.money(o.deliveryFee), color: o.deliveryFee == 0 ? G4MColors.success : null),
        if (o.discount > 0) row('Discount${o.couponCode.isNotEmpty ? ' (${o.couponCode})' : ''}', '−${Fmt.money(o.discount)}', color: G4MColors.success),
        if (o.tax > 0) row('Taxes', Fmt.money(o.tax)),
        if (o.walletUsed > 0) row('Wallet', '−${Fmt.money(o.walletUsed)}', color: G4MColors.success),
        Divider(color: context.line, height: 18),
        row('Paid / to pay', Fmt.money(o.payable), bold: true),
        const SizedBox(height: 6),
        Row(children: [
          Icon(o.paymentMethod == 'cod' ? Icons.payments_outlined : Icons.credit_card_rounded, size: 16, color: context.muted),
          const SizedBox(width: 6),
          Text(o.paymentMethod == 'cod' ? 'Cash on delivery' : Fmt.titleCase(o.paymentMethod), style: context.text.bodySmall),
          const Spacer(),
          StatusChip(o.paymentStatus),
        ]),
        if (o.speed == 'scheduled' && o.scheduledSlot.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.event_rounded, size: 16, color: G4MColors.primary),
            const SizedBox(width: 6),
            Text('Slot ${o.scheduledSlot['date']} · ${o.scheduledSlot['from']}–${o.scheduledSlot['to']}', style: context.text.bodySmall),
          ]),
        ],
      ]),
    );
  }
}

class _AddressCard extends StatelessWidget {
  const _AddressCard({required this.order});
  final ShopOrder order;
  @override
  Widget build(BuildContext context) {
    final a = Address('x', order.address);
    return AppCard(
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.location_on_outlined, color: G4MColors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${a.label} · ${a.name.isNotEmpty ? a.name : order.customerName}', style: context.text.titleSmall),
            Text(a.oneLine, style: context.text.bodySmall),
            if (order.distanceKm > 0) Text('${order.distanceKm.toStringAsFixed(1)} km from store', style: context.text.bodySmall),
          ]),
        ),
      ]),
    );
  }
}

// ---------------------------------------------------------------- actions

class _Actions extends StatelessWidget {
  const _Actions({required this.order});
  final ShopOrder order;

  bool get _canCancel => {OrderStatus.pending, OrderStatus.placed, OrderStatus.confirmed}.contains(order.status);

  bool get _canReturn {
    if (order.status != OrderStatus.delivered) return false;
    final at = order.timeline.where((t) => t.status == OrderStatus.delivered).map((t) => t.at).firstOrNull ?? order.createdAt;
    return at == null || DateTime.now().difference(at).inDays <= 7;
  }

  Future<void> _cancel(BuildContext context) async {
    final reason = await showAppSheet<String>(
      context,
      builder: (_) => const _ReasonSheet(
        title: 'Why are you cancelling?',
        reasons: ['Ordered by mistake', 'Delivery is taking too long', 'Want to change items', 'Found a better price', 'Other'],
        cta: 'Cancel order',
        danger: true,
      ),
    );
    if (reason == null || !context.mounted) return;
    try {
      await G4MApi.instance.updateOrderStatus(order.id, OrderStatus.cancelled, note: reason);
      if (context.mounted) context.toast('Order cancelled');
    } catch (e) {
      if (context.mounted) context.toast(friendlyError(e), error: true);
    }
  }

  Future<void> _return(BuildContext context) async {
    final reason = await showAppSheet<String>(
      context,
      builder: (_) => const _ReasonSheet(
        title: 'Return items',
        reasons: ['Damaged or defective', 'Wrong item delivered', 'Expired / near expiry', 'Missing parts', 'Not as described', 'Other'],
        cta: 'Request return',
        withItems: true,
      ),
    );
    if (reason == null || !context.mounted) return;
    try {
      await G4MApi.instance.requestReturn({
        'orderId': order.id,
        'reason': reason,
        'items': [
          for (final it in order.items) {'productId': it.productId, 'variantId': it.variantId, 'qty': it.qty, 'name': it.name, 'price': it.price},
        ],
        'images': const [],
        'refundTo': 'wallet',
      });
      if (context.mounted) context.toast('Return requested. We will update you soon.');
    } catch (e) {
      if (context.mounted) context.toast(isMissingFunction(e) ? 'Returns are not available yet.' : friendlyError(e), error: true);
    }
  }

  Future<void> _reorder(BuildContext context) async {
    final ids = order.items.map((e) => e.productId).toSet();
    final m = await Session.instance.ensureProducts(ids, refresh: true);
    var added = 0, droppedAddons = 0;
    for (final it in order.items) {
      final p = m[it.productId];
      if (p == null || !p.inStock) continue;
      // Re-create the same customisation; add-ons the kitchen no longer offers are dropped.
      final wanted = it.addons.map((a) => a.id).where((id) => id.isNotEmpty).toList();
      final still = selectedAddons(p, wanted).map((a) => a.id).toList();
      droppedAddons += wanted.length - still.length;
      await Session.instance.addLine(p, it.variantId, still, qty: it.qty);
      added++;
    }
    if (!context.mounted) return;
    if (added == 0) {
      context.toast('These items are out of stock right now');
    } else {
      context.toast('Added $added items to your cart${droppedAddons > 0 ? ' ($droppedAddons add-on${droppedAddons == 1 ? ' is' : 's are'} no longer available)' : ''}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (order.status == OrderStatus.delivered)
        StreamBuilder<List<Json>>(
          stream: MyData.returnsFor(order.id),
          builder: (context, snap) {
            final r = snap.data ?? const <Json>[];
            if (r.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AppCard(
                child: Row(children: [
                  const Icon(Icons.assignment_return_outlined),
                  const SizedBox(width: 10),
                  Expanded(child: Text('Return ${Fmt.titleCase('${r.first['status'] ?? 'requested'}')}', style: context.text.titleSmall)),
                  StatusChip('${r.first['status'] ?? 'requested'}'),
                ]),
              ),
            );
          },
        ),
      if (_canCancel)
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(foregroundColor: G4MColors.danger, side: BorderSide(color: G4MColors.danger.withValues(alpha: .4))),
          onPressed: () => _cancel(context),
          icon: const Icon(Icons.cancel_outlined),
          label: Text(l.cancelOrder),
        ),
      if (_canReturn) ...[
        OutlinedButton.icon(onPressed: () => _return(context), icon: const Icon(Icons.assignment_return_outlined), label: Text(l.requestReturn)),
      ],
      if (!order.isActive) ...[
        const SizedBox(height: 10),
        FilledButton.icon(onPressed: () => _reorder(context), icon: const Icon(Icons.replay_rounded), label: const Text('Order again')),
      ],
      const SizedBox(height: 10),
      TextButton.icon(
        onPressed: () => context.push(HelpScreen(orderNo: order.orderNo)),
        icon: const Icon(Icons.support_agent_rounded),
        label: const Text('Need help with this order?'),
      ),
    ]);
  }
}

class _ReasonSheet extends StatefulWidget {
  const _ReasonSheet({required this.title, required this.reasons, required this.cta, this.danger = false, this.withItems = false});
  final String title, cta;
  final List<String> reasons;
  final bool danger, withItems;
  @override
  State<_ReasonSheet> createState() => _ReasonSheetState();
}

class _ReasonSheetState extends State<_ReasonSheet> {
  String? _r;
  final _other = TextEditingController();
  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(widget.title, style: context.text.titleLarge),
            const SizedBox(height: 8),
            RadioGroup<String>(
              groupValue: _r,
              onChanged: (v) => setState(() => _r = v),
              child: Column(children: [
                for (final r in widget.reasons) RadioListTile<String>(value: r, title: Text(r), contentPadding: EdgeInsets.zero, dense: true),
              ]),
            ),
            if (_r == 'Other') TextField(controller: _other, decoration: const InputDecoration(hintText: 'Tell us more')),
            const SizedBox(height: 14),
            FilledButton(
              style: widget.danger ? FilledButton.styleFrom(backgroundColor: G4MColors.danger) : null,
              onPressed: _r == null ? null : () => Navigator.of(context).pop(_r == 'Other' && _other.text.trim().isNotEmpty ? _other.text.trim() : _r),
              child: Text(widget.cta),
            ),
          ]),
        ),
      );
}
