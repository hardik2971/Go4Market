import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:g4m_core/g4m_core.dart';
import 'package:latlong2/latlong.dart';

import '../../core/device.dart';
import '../../core/l10n.dart';
import '../../core/live.dart';
import '../../core/location_service.dart';
import '../../core/partner_theme.dart';
import '../../core/ui.dart';
import 'delivery_data.dart';
import '../../core/motion.dart';
import 'delivery_widgets.dart';

/// Live delivery: map (store, customer, me), navigation, calls, quick-delivery
/// countdown and swipe-to-confirm status steps. For orders that are not
/// assigned to me (or are finished) it is a read-only detail.
class ActiveDeliveryScreen extends StatefulWidget {
  const ActiveDeliveryScreen({super.key, required this.orderId});
  final String orderId;
  @override
  State<ActiveDeliveryScreen> createState() => _ActiveDeliveryScreenState();
}

class _ActiveDeliveryScreenState extends State<ActiveDeliveryScreen> {
  late final Stream<ShopOrder?> _order = DeliveryData.order(widget.orderId);
  final _map = MapController();
  Future<Seller?>? _seller;
  String? _sellerId;
  bool _celebrating = false;

  Future<Seller?> _sellerFor(ShopOrder o) {
    final id = o.sellerIds.isNotEmpty ? o.sellerIds.first : (o.items.isNotEmpty ? o.items.first.sellerId : '');
    if (_seller == null || _sellerId != id) {
      _sellerId = id;
      _seller = DeliveryData.seller(id);
    }
    return _seller!;
  }

  Future<bool> _advance(ShopOrder o, String next) async {
    try {
      await G4MApi.instance.updateOrderStatus(o.id, next);
      HapticFeedback.mediumImpact();
      if (mounted) toast(context, OrderStatus.label(next), icon: Icons.check_circle_rounded);
      return true;
    } catch (e) {
      if (mounted) toast(context, describeError(e), error: true);
      return false;
    }
  }

  Future<bool> _deliver(ShopOrder o) async {
    final r = await showModalBottomSheet<_DeliverResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => DeliverSheet(order: o),
    );
    if (r == null) return false;
    try {
      await G4MApi.instance.updateOrderStatus(
        o.id,
        OrderStatus.delivered,
        otp: r.otp.isEmpty ? null : r.otp,
        cashCollected: isCodDue(o) ? o.payable : null,
      );
    } catch (e) {
      if (mounted) toast(context, describeError(e), error: true);
      return false;
    }
    _celebrating = true;
    Future.microtask(() async {
      if (!mounted) return;
      await showSuccess(
        context,
        title: context.tr('Delivered!', 'डिलीवर हो गया!'),
        subtitle: isCodDue(o)
            ? '${context.tr('Cash collected', 'नकद प्राप्त')}: ${Fmt.money(o.payable)}'
            : context.tr('Great job. On to the next one!', 'शानदार! अगले की ओर!'),
        color: G4MColors.success,
      );
      if (mounted) Navigator.of(context).maybePop();
    });
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ShopOrder?>(
      stream: _order,
      builder: (context, snap) {
        if (snap.hasError) return Scaffold(appBar: AppBar(), body: ErrorView(snap.error!));
        if (!snap.hasData && snap.connectionState == ConnectionState.waiting) {
          return Scaffold(appBar: AppBar(), body: const SkeletonList(count: 4, itemHeight: 110));
        }
        final o = snap.data;
        if (o == null) {
          return Scaffold(
            appBar: AppBar(),
            body: AppEmpty(icon: Icons.search_off_rounded, title: context.tr('Order not found', 'ऑर्डर नहीं मिला')),
          );
        }
        final mine = o.deliveryPartnerId == myUid;
        final actionable = mine && activeDeliveryStatuses.contains(o.status) && !_celebrating;
        final inPool = o.status == OrderStatus.packed && o.deliveryPartnerId.isEmpty && o.deliveryType == 'home';
        return FutureBuilder<Seller?>(
          future: _sellerFor(o),
          builder: (context, sSnap) {
            final seller = sSnap.data;
            return Scaffold(
              body: Stack(children: [
                Positioned.fill(bottom: MediaQuery.of(context).size.height * .45, child: _mapView(o, seller)),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(children: [
                      _roundBtn(Icons.arrow_back_rounded, () => Navigator.maybePop(context)),
                      const Spacer(),
                      if (quickDeadline(o) != null && o.isActive) _countdownChip(o),
                    ]),
                  ),
                ),
                DraggableScrollableSheet(
                  initialChildSize: .58,
                  minChildSize: .42,
                  maxChildSize: .92,
                  builder: (context, scroll) => Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(G4MRadius.lg)),
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 24)],
                    ),
                    child: ListView(controller: scroll, padding: const EdgeInsets.fromLTRB(16, 10, 16, 24), children: [
                      Center(
                        child: Container(width: 40, height: 4, decoration: BoxDecoration(color: context.rc.line, borderRadius: BorderRadius.circular(2))),
                      ),
                      const SizedBox(height: 14),
                      _header(o).stagger(0),
                      if (o.deliveryType == 'home' && (activeDeliveryStatuses.contains(o.status) || o.status == OrderStatus.delivered)) ...[
                        const SizedBox(height: 18),
                        DeliveryStepper(status: o.status).stagger(1),
                      ],
                      const SizedBox(height: 18),
                      _place(
                        icon: Icons.storefront_rounded,
                        color: G4MColors.primaryDeep,
                        title: seller?.storeName.isNotEmpty == true ? seller!.storeName : (o.items.isNotEmpty ? o.items.first.sellerName : context.tr('Store', 'स्टोर')),
                        subtitle: [seller?.address ?? '', seller?.city ?? ''].where((e) => e.isNotEmpty).join(', '),
                        label: context.tr('Pickup', 'पिकअप'),
                        phone: mine ? (seller?.phone ?? '') : '',
                        target: sellerLatLng(seller),
                      ).stagger(2),
                      const SizedBox(height: 10),
                      _place(
                        icon: Icons.home_rounded,
                        color: G4MColors.accent,
                        title: o.customerName,
                        subtitle: addressLine(o.address),
                        label: context.tr('Drop', 'ड्रॉप'),
                        phone: mine ? (o.customerPhone.isNotEmpty ? o.customerPhone : '${o.address['phone'] ?? ''}') : '',
                        target: orderLatLng(o),
                      ).stagger(3),
                      const SizedBox(height: 18),
                      _items(o).stagger(4),
                      const SizedBox(height: 12),
                      _payment(o).stagger(5),
                      if (o.status == OrderStatus.cancelled && o.cancelReason.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        AppCard(
                          color: G4MColors.danger.withValues(alpha: .08),
                          child: Text('${context.tr('Cancelled', 'रद्द')}: ${o.cancelReason}'),
                        ),
                      ],
                    ]),
                  ),
                ),
              ]),
              bottomNavigationBar: (actionable || inPool)
                  ? SafeArea(
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                        color: Theme.of(context).scaffoldBackgroundColor,
                        child: inPool
                            ? FilledButton.icon(
                                icon: const Icon(Icons.check_rounded),
                                label: Text(context.tr('Accept delivery', 'डिलीवरी स्वीकार करें')),
                                onPressed: !LocationService.instance.running
                                    ? () => toast(context, context.tr('Go online first', 'पहले ऑनलाइन जाएं'), error: true)
                                    : () async {
                                        final r = await runBusy(context, () => G4MApi.instance.acceptDelivery(o.id));
                                        if (r != null && context.mounted) toast(context, context.tr('Order accepted', 'ऑर्डर स्वीकार'));
                                      },
                              )
                            : _swipe(o),
                      ).animate().slideY(begin: 1, duration: 450.ms, curve: Curves.easeOutCubic),
                    )
                  : null,
            );
          },
        );
      },
    );
  }

  Widget _swipe(ShopOrder o) => switch (o.status) {
        OrderStatus.assigned => SwipeToConfirm(
            label: context.tr('Swipe to confirm pickup', 'पिकअप की पुष्टि के लिए स्वाइप करें'),
            icon: Icons.shopping_bag_rounded,
            color: G4MColors.primaryDeep,
            onConfirm: () => _advance(o, OrderStatus.pickedUp),
          ),
        OrderStatus.pickedUp => SwipeToConfirm(
            label: context.tr('Swipe to start delivery', 'डिलीवरी शुरू करने के लिए स्वाइप करें'),
            icon: Icons.delivery_dining_rounded,
            color: G4MColors.accent,
            onConfirm: () => _advance(o, OrderStatus.outForDelivery),
          ),
        _ => SwipeToConfirm(
            label: context.tr('Swipe to complete delivery', 'डिलीवरी पूरी करने के लिए स्वाइप करें'),
            icon: Icons.task_alt_rounded,
            color: G4MColors.success,
            onConfirm: () => _deliver(o),
          ),
      };

  Widget _roundBtn(IconData icon, VoidCallback onTap) => Material(
        color: context.rc.card,
        shape: const CircleBorder(),
        elevation: 4,
        shadowColor: Colors.black26,
        child: InkWell(customBorder: const CircleBorder(), onTap: onTap, child: Padding(padding: const EdgeInsets.all(10), child: Icon(icon))),
      );

  Widget _countdownChip(ShopOrder o) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: G4MColors.accentGradient,
          borderRadius: BorderRadius.circular(G4MRadius.pill),
          boxShadow: G4MShadows.glowAccent,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.bolt_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 4),
          CountdownText(target: quickDeadline(o)!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
        ]),
      ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(begin: const Offset(1, 1), end: const Offset(1.05, 1.05), duration: 900.ms);

  Widget _mapView(ShopOrder o, Seller? seller) {
    final store = sellerLatLng(seller);
    final drop = orderLatLng(o);
    return ListenableBuilder(
      listenable: LocationService.instance,
      builder: (context, _) {
        final me = myLatLng();
        final pts = [?store, ?drop, ?me];
        if (pts.isEmpty) {
          return Container(
            decoration: BoxDecoration(gradient: context.rc.hero),
            alignment: Alignment.center,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.map_outlined, color: Colors.white70, size: 48),
              const SizedBox(height: 8),
              Text(context.tr('Map unavailable for this order', 'इस ऑर्डर के लिए नक्शा उपलब्ध नहीं'), style: const TextStyle(color: Colors.white70)),
            ]),
          );
        }
        final target = o.status == OrderStatus.assigned || o.status == OrderStatus.packed ? store : drop;
        return Stack(children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: pts.first,
              initialZoom: 14,
              initialCameraFit: pts.length >= 2
                  ? CameraFit.coordinates(coordinates: pts, padding: const EdgeInsets.fromLTRB(60, 100, 60, 60), maxZoom: 17)
                  : null,
            ),
            children: [
              osmTiles(),
              if (me != null && target != null)
                PolylineLayer(polylines: [
                  Polyline(points: [me, target], strokeWidth: 4, color: context.rc.brand, pattern: const StrokePattern.dotted()),
                ]),
              MarkerLayer(markers: [
                if (store != null) pinMarker(store, Icons.storefront_rounded, G4MColors.primaryDeep),
                if (drop != null) pinMarker(drop, Icons.home_rounded, G4MColors.accent),
                if (me != null) pinMarker(me, Icons.two_wheeler_rounded, G4MColors.info, pulse: true),
              ]),
              osmAttribution(),
            ],
          ),
          if (pts.length >= 2)
            Positioned(
              right: 12,
              bottom: 16,
              child: _roundBtn(Icons.center_focus_strong_rounded, () {
                _map.fitCamera(CameraFit.coordinates(coordinates: pts, padding: const EdgeInsets.fromLTRB(60, 100, 60, 60), maxZoom: 17));
              }),
            ),
        ]);
      },
    );
  }

  Widget _header(ShopOrder o) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('#${o.orderNo}', style: context.tt.headlineSmall),
            const SizedBox(height: 4),
            Wrap(spacing: 6, runSpacing: 6, children: [
              StatusPill(o.status),
              InfoChip(icon: Icons.bolt_rounded, label: speedLabel(context, o.speed), color: quickDeadline(o) != null ? G4MColors.accent : context.rc.muted),
              if (o.distanceKm > 0) InfoChip(icon: Icons.route_rounded, label: '${o.distanceKm.toStringAsFixed(1)} km', color: G4MColors.info),
            ]),
          ]),
        ),
        Text(Fmt.time(o.createdAt), style: context.tt.bodySmall),
      ]);

  Widget _place({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required String label,
    required String phone,
    required LatLng? target,
  }) =>
      AppCard(
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: color.withValues(alpha: .14), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label.toUpperCase(), style: context.tt.labelSmall?.copyWith(color: color, letterSpacing: 1, fontWeight: FontWeight.w800)),
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.tt.titleSmall),
              if (subtitle.isNotEmpty) Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.tt.bodySmall),
            ]),
          ),
          if (phone.isNotEmpty)
            IconButton.filledTonal(
              tooltip: context.s.call,
              onPressed: () => callPhone(context, phone),
              icon: const Icon(Icons.call_rounded),
            ),
          IconButton.filled(
            tooltip: context.s.navigate,
            style: IconButton.styleFrom(backgroundColor: G4MColors.primaryDeep, foregroundColor: Colors.white),
            onPressed: target == null ? null : () => openNavigation(target.latitude, target.longitude),
            icon: const Icon(Icons.navigation_rounded),
          ),
        ]),
      );

  Widget _items(ShopOrder o) => AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${o.itemCount} ${context.tr('items', 'आइटम')}', style: context.tt.titleSmall),
          const SizedBox(height: 8),
          for (final it in o.items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(children: [
                NetImage(it.image, width: 40, height: 40, radius: 8),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(it.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.tt.bodyMedium),
                    if (it.variantName.isNotEmpty) Text(it.variantName, style: context.tt.bodySmall),
                  ]),
                ),
                Text('× ${it.qty}', style: context.tt.titleSmall),
              ]),
            ),
        ]),
      );

  Widget _payment(ShopOrder o) {
    final cod = isCodDue(o);
    return AppCard(
      color: cod ? G4MColors.warning.withValues(alpha: .1) : null,
      borderColor: cod ? G4MColors.warning.withValues(alpha: .5) : null,
      child: Row(children: [
        Icon(cod ? Icons.payments_rounded : Icons.verified_rounded, color: cod ? G4MColors.warning : G4MColors.success),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(cod ? context.tr('Collect cash on delivery', 'डिलीवरी पर नकद लें') : context.tr('Prepaid, nothing to collect', 'प्रीपेड, कुछ नहीं लेना'),
                style: context.tt.titleSmall),
            Text('${Fmt.titleCase(o.paymentMethod)} · ${Fmt.titleCase(o.paymentStatus)}', style: context.tt.bodySmall),
          ]),
        ),
        Text(Fmt.money(o.payable), style: context.tt.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
      ]),
    );
  }
}

class _DeliverResult {
  const _DeliverResult(this.otp);
  final String otp;
}

/// OTP + COD cash confirmation before marking delivered.
@visibleForTesting
class DeliverSheet extends StatefulWidget {
  const DeliverSheet({super.key, required this.order});
  final ShopOrder order;
  @override
  State<DeliverSheet> createState() => _DeliverSheetState();
}

class _DeliverSheetState extends State<DeliverSheet> {
  final _otp = TextEditingController();
  final _focus = FocusNode();
  bool _cash = false;
  int _shake = 0;
  String? _err;

  bool get _otpRequired => widget.order.deliveryOtp.isNotEmpty;
  int get _len => widget.order.deliveryOtp.length.clamp(4, 6);

  @override
  void dispose() {
    _otp.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit() {
    final o = widget.order;
    final code = _otp.text.trim();
    // Instant feedback when the OTP is known locally; the server still verifies.
    if (_otpRequired && code != o.deliveryOtp) {
      HapticFeedback.heavyImpact();
      setState(() {
        _shake++;
        _err = context.tr('Incorrect OTP. Ask the customer again.', 'गलत OTP। ग्राहक से फिर पूछें।');
      });
      return;
    }
    Navigator.pop(context, _DeliverResult(code));
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    final cod = isCodDue(o);
    final code = _otp.text;
    final ready = (!_otpRequired || code.length >= _len) && (code.isEmpty || code.length >= 4) && (!cod || _cash);
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(context.tr('Complete delivery', 'डिलीवरी पूरी करें'), style: context.tt.titleLarge),
        const SizedBox(height: 4),
        Text(
          _otpRequired
              ? context.tr('Ask the customer for the delivery OTP shown in their app.', 'ग्राहक से उनके ऐप में दिखा डिलीवरी OTP पूछें।')
              : context.tr('Enter the delivery OTP if the customer has one.', 'यदि ग्राहक के पास OTP है तो दर्ज करें।'),
          style: context.tt.bodySmall,
        ),
        const SizedBox(height: 18),
        GestureDetector(
          onTap: () {
            _focus.requestFocus();
            _otp.selection = TextSelection.collapsed(offset: _otp.text.length);
          },
          child: Stack(children: [
            Opacity(
              opacity: 0,
              child: TextField(
                controller: _otp,
                focusNode: _focus,
                autofocus: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                showCursor: false,
                enableInteractiveSelection: false,
                onChanged: (v) {
                  // The field is invisible, so a tap can park its caret mid-text; keep typing appended.
                  final end = TextSelection.collapsed(offset: v.length);
                  if (_otp.selection != end) _otp.selection = end;
                  setState(() => _err = null);
                },
              ),
            ),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (var i = 0; i < (_otpRequired ? _len : 6); i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 46,
                  height: 56,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: context.rc.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _err != null
                          ? G4MColors.danger
                          : i == code.length
                              ? context.rc.brand
                              : i < code.length
                                  ? context.rc.brand.withValues(alpha: .5)
                                  : context.rc.line,
                      width: i == code.length ? 2 : 1.2,
                    ),
                  ),
                  child: Text(i < code.length ? code[i] : '', style: context.tt.headlineSmall),
                ).animate(key: ValueKey('$i${i < code.length}')).scale(begin: const Offset(.9, .9), duration: 160.ms),
            ]).animate(key: ValueKey(_shake), target: _shake > 0 ? 1 : 0).shakeX(hz: 5, amount: 6, duration: 400.ms),
          ]),
        ),
        if (_err != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_err!, textAlign: TextAlign.center, style: const TextStyle(color: G4MColors.danger, fontWeight: FontWeight.w600)),
          ),
        if (cod) ...[
          const SizedBox(height: 18),
          AnimatedContainer(
            duration: G4MMotion.standard,
            decoration: BoxDecoration(
              color: _cash ? G4MColors.success.withValues(alpha: .1) : G4MColors.warning.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(G4MRadius.md),
              border: Border.all(color: _cash ? G4MColors.success : G4MColors.warning),
            ),
            child: CheckboxListTile(
              value: _cash,
              onChanged: (v) {
                HapticFeedback.selectionClick();
                setState(() => _cash = v ?? false);
              },
              activeColor: G4MColors.success,
              title: Text('${context.tr('Cash collected', 'नकद प्राप्त')} ${Fmt.money(o.payable)}', style: context.tt.titleMedium),
              subtitle: Text(context.tr('I have received the full amount in cash', 'मुझे पूरी राशि नकद मिल गई है')),
            ),
          ),
        ],
        const SizedBox(height: 20),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: G4MColors.success),
          onPressed: ready ? _submit : null,
          icon: const Icon(Icons.task_alt_rounded),
          label: Text(context.tr('Mark delivered', 'डिलीवर चिह्नित करें')),
        ),
      ]),
    );
  }
}
