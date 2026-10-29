import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:g4m_core/g4m_core.dart';

import '../../core/device.dart';
import '../../core/l10n.dart';
import '../../core/motion.dart';
import '../../core/partner_theme.dart';
import '../../core/ui.dart';
import 'seller_data.dart';
import 'seller_widgets.dart';

class SellerOrderDetailScreen extends StatelessWidget {
  const SellerOrderDetailScreen({super.key, required this.orderId});
  final String orderId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ShopOrder?>(
      stream: SellerData.order(orderId),
      builder: (context, snap) {
        final o = snap.data;
        return Scaffold(
          appBar: AppBar(
            title: Text(o == null ? context.s.orders : '#${o.orderNo}'),
            actions: [
              if (o != null && o.customerPhone.isNotEmpty)
                IconButton(tooltip: context.s.call, icon: const Icon(Icons.call_outlined), onPressed: () => callPhone(context, o.customerPhone)),
              if (o != null && o.isActive)
                PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'cancel') _cancel(context, o);
                  },
                  itemBuilder: (c) => [
                    PopupMenuItem(value: 'cancel', child: Text(c.tr('Cancel order', 'ऑर्डर रद्द करें'), style: const TextStyle(color: G4MColors.danger))),
                  ],
                ),
            ],
          ),
          body: snap.hasError
              ? ErrorView(snap.error!)
              : !snap.hasData && snap.connectionState == ConnectionState.waiting
                  ? const SkeletonList(count: 4, itemHeight: 110)
                  : o == null
                      ? AppEmpty(icon: Icons.search_off_rounded, title: context.tr('Order not found', 'ऑर्डर नहीं मिला'))
                      : _Body(order: o),
          bottomNavigationBar: o == null ? null : _ActionBar(order: o),
        );
      },
    );
  }

  static Future<void> _cancel(BuildContext context, ShopOrder o) async {
    final reason = await promptText(
      context,
      title: context.tr('Why cancel this order?', 'यह ऑर्डर क्यों रद्द करें?'),
      hint: context.tr('Reason', 'कारण'),
      suggestions: [
        context.tr('Out of stock', 'स्टॉक खत्म'),
        context.tr('Store closed', 'स्टोर बंद है'),
        context.tr('Cannot deliver to this area', 'इस क्षेत्र में डिलीवरी नहीं'),
        context.tr('Customer requested', 'ग्राहक ने अनुरोध किया'),
      ],
      confirmText: context.tr('Cancel order', 'ऑर्डर रद्द करें'),
    );
    if (reason == null || !context.mounted) return;
    await runBusy(context, () => G4MApi.instance.updateOrderStatus(o.id, OrderStatus.cancelled, note: reason),
        success: context.tr('Order cancelled', 'ऑर्डर रद्द हुआ'));
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.order});
  final ShopOrder order;

  @override
  Widget build(BuildContext context) {
    final o = order;
    final mine = SellerData.myItems(o).map((e) => '${e.productId}_${e.variantId}').toSet();
    bool isMine(OrderItem it) => mine.contains('${it.productId}_${it.variantId}');
    final addr = Address('', o.address);
    var i = 0;
    return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
      // Header
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            StatusPill(o.status),
            const Spacer(),
            Text(Fmt.dateTime(o.createdAt), style: context.tt.bodySmall),
          ]),
          const SizedBox(height: 14),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _chip(context, o.deliveryType == 'pickup' ? Icons.storefront_rounded : Icons.delivery_dining_rounded,
                o.deliveryType == 'pickup' ? context.tr('Self pickup', 'स्वयं पिकअप') : context.tr('Home delivery', 'होम डिलीवरी')),
            _chip(context, Icons.speed_rounded, switch (o.speed) {
              'quick15' => context.tr('Quick · 15 min', 'क्विक · 15 मिनट'),
              'quick30' => context.tr('Quick · 30 min', 'क्विक · 30 मिनट'),
              'scheduled' => context.tr('Scheduled', 'निर्धारित'),
              _ => context.tr('Standard', 'सामान्य'),
            }),
            _chip(context, Icons.devices_rounded, o.channel.toUpperCase()),
            if (o.speed == 'scheduled' && o.scheduledSlot.isNotEmpty)
              _chip(context, Icons.event_rounded, '${o.scheduledSlot['date'] ?? ''} ${o.scheduledSlot['from'] ?? ''}-${o.scheduledSlot['to'] ?? ''}'),
          ]),
          if ((o.speed == 'quick15' || o.speed == 'quick30') && o.isActive) ...[
            const SizedBox(height: 14),
            Row(children: [
              const Icon(Icons.timer_outlined, color: G4MColors.accent),
              const SizedBox(width: 8),
              Text(context.tr('Delivery due in', 'डिलीवरी बाकी'), style: context.tt.bodyMedium),
              const Spacer(),
              CountdownText(
                target: o.etaAt ?? (o.createdAt ?? DateTime.now()).add(Duration(minutes: o.speed == 'quick15' ? 15 : 30)),
                style: context.tt.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ]),
          ],
          if (o.status == OrderStatus.cancelled && o.cancelReason.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('${context.tr('Reason', 'कारण')}: ${o.cancelReason}', style: context.tt.bodyMedium?.copyWith(color: G4MColors.danger)),
          ],
        ]),
      ).stagger(i++),
      const SizedBox(height: 12),
      // Customer
      AppCard(
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Avatar(name: o.customerName, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(o.customerName, style: context.tt.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
              if (o.customerPhone.isNotEmpty) Text(o.customerPhone, style: context.tt.bodySmall),
              if (o.deliveryType != 'pickup' && addr.oneLine.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(addr.oneLine, style: context.tt.bodyMedium?.copyWith(color: context.rc.muted)),
                if (o.distanceKm > 0) Text('${o.distanceKm.toStringAsFixed(1)} km', style: context.tt.bodySmall),
              ],
            ]),
          ),
          if (o.customerPhone.isNotEmpty)
            IconButton.filledTonal(onPressed: () => callPhone(context, o.customerPhone), icon: const Icon(Icons.call_rounded)),
        ]),
      ).stagger(i++),
      if (o.deliveryPartnerName.isNotEmpty) ...[
        const SizedBox(height: 12),
        AppCard(
          child: Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: G4MColors.accent.withValues(alpha: .14), shape: BoxShape.circle),
              child: const Icon(Icons.delivery_dining_rounded, color: G4MColors.accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(context.tr('Delivery partner', 'डिलीवरी पार्टनर'), style: context.tt.bodySmall),
                Text(o.deliveryPartnerName, style: context.tt.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
              ]),
            ),
          ]),
        ).stagger(i++),
      ],
      const SizedBox(height: 12),
      // Items
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(context.tr('Items', 'आइटम'), style: context.tt.titleMedium),
          const SizedBox(height: 8),
          for (final it in o.items)
            Opacity(
              opacity: isMine(it) ? 1 : .45,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(children: [
                  ProductThumb(it.image, size: 48),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(it.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.tt.titleSmall),
                      Text(
                        [if (it.variantName.isNotEmpty) it.variantName, '${it.qty} × ${Fmt.money(it.price)}', if (!isMine(it)) it.sellerName]
                            .join(' · '),
                        style: context.tt.bodySmall,
                      ),
                    ]),
                  ),
                  Text(Fmt.money(it.lineTotal), style: context.tt.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                ]),
              ),
            ),
          const Divider(height: 24),
          _row(context, context.tr('Subtotal', 'उप-योग'), Fmt.money(o.subtotal)),
          if (o.deliveryFee > 0) _row(context, context.tr('Delivery fee', 'डिलीवरी शुल्क'), Fmt.money(o.deliveryFee)),
          if (o.discount > 0) _row(context, '${context.tr('Discount', 'छूट')}${o.couponCode.isEmpty ? '' : ' (${o.couponCode})'}', '-${Fmt.money(o.discount)}'),
          if (o.tax > 0) _row(context, context.tr('Tax', 'टैक्स'), Fmt.money(o.tax)),
          if (o.walletUsed > 0) _row(context, context.tr('Wallet', 'वॉलेट'), '-${Fmt.money(o.walletUsed)}'),
          const SizedBox(height: 4),
          _row(context, context.tr('Payable', 'देय'), Fmt.money(o.payable), bold: true),
          if (o.sellerIds.length > 1) _row(context, context.tr('Your share', 'आपका हिस्सा'), Fmt.money(SellerData.myRevenue(o)), bold: true),
          const SizedBox(height: 10),
          Row(children: [
            Icon(o.paymentMethod == 'cod' ? Icons.payments_outlined : Icons.credit_card_rounded, size: 18, color: context.rc.muted),
            const SizedBox(width: 6),
            Text(o.paymentMethod.toUpperCase(), style: context.tt.labelLarge),
            const Spacer(),
            StatusPill(o.paymentStatus, label: Fmt.titleCase(o.paymentStatus)),
          ]),
        ]),
      ).stagger(i++),
      const SizedBox(height: 12),
      AppCard(child: OrderTimeline(order: o)).stagger(i++),
    ]);
  }

  Widget _chip(BuildContext context, IconData icon, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: context.rc.cardAlt, borderRadius: BorderRadius.circular(G4MRadius.pill)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 15, color: context.rc.brand),
          const SizedBox(width: 6),
          Text(label, style: context.tt.labelMedium?.copyWith(fontWeight: FontWeight.w700)),
        ]),
      );

  Widget _row(BuildContext context, String k, String v, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Text(k, style: bold ? context.tt.titleSmall : context.tt.bodyMedium?.copyWith(color: context.rc.muted)),
          const Spacer(),
          Text(v, style: bold ? context.tt.titleMedium?.copyWith(fontWeight: FontWeight.w800) : context.tt.bodyMedium),
        ]),
      );
}

/// Vertical animated status stepper over the home or pickup flow.
class OrderTimeline extends StatelessWidget {
  const OrderTimeline({super.key, required this.order});
  final ShopOrder order;

  @override
  Widget build(BuildContext context) {
    final o = order;
    final entries = {for (final t in o.timeline) t.status: t};
    final closed = SellerTabs.closed.contains(o.status);
    final flow = closed
        ? o.timeline.map((t) => t.status).toList()
        : (o.deliveryType == 'pickup' ? OrderStatus.pickupFlow : OrderStatus.homeFlow);
    final current = flow.indexOf(o.status);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(context.tr('Timeline', 'समयरेखा'), style: context.tt.titleMedium),
      const SizedBox(height: 12),
      for (var i = 0; i < flow.length; i++)
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(
              width: 28,
              child: Column(children: [
                _dot(context, i <= current || closed, i == current && !closed, statusColor(flow[i])),
                if (i < flow.length - 1)
                  Expanded(
                    child: Container(
                      width: 2.5,
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      decoration: BoxDecoration(
                        color: i < current || closed ? context.rc.brand : context.rc.line,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ).animate().scaleY(begin: 0, alignment: Alignment.topCenter, delay: (i * 120).ms, duration: 300.ms),
                  ),
              ]),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(OrderStatus.label(flow[i]),
                      style: context.tt.titleSmall?.copyWith(
                        fontWeight: i == current ? FontWeight.w800 : FontWeight.w600,
                        color: i <= current || closed ? context.rc.ink : context.rc.faint,
                      )),
                  if (entries[flow[i]] != null)
                    Text(
                      [Fmt.dateTime(entries[flow[i]]!.at), if (entries[flow[i]]!.note.isNotEmpty) entries[flow[i]]!.note].join(' · '),
                      style: context.tt.bodySmall,
                    ),
                ]),
              ),
            ),
          ]),
        ).animate(delay: (i * 90).ms).fadeIn(duration: 300.ms).slideX(begin: .05),
    ]);
  }

  Widget _dot(BuildContext context, bool done, bool active, Color c) {
    final d = Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: done ? (active ? c : context.rc.brand) : context.rc.card,
        shape: BoxShape.circle,
        border: Border.all(color: done ? Colors.transparent : context.rc.line, width: 2),
      ),
      child: done ? const Icon(Icons.check_rounded, size: 13, color: Colors.white) : null,
    );
    if (!active) return d;
    return d.animate(onPlay: (x) => x.repeat(reverse: true)).scaleXY(begin: 1, end: 1.18, duration: 800.ms);
  }
}

/// Contextual primary action for the current status.
class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.order});
  final ShopOrder order;

  Future<void> _set(BuildContext context, String status, String done, {String? otp, double? cash}) async {
    final r = await runBusy(context, () => G4MApi.instance.updateOrderStatus(order.id, status, otp: otp, cashCollected: cash));
    if (r != null && context.mounted) {
      if (status == OrderStatus.delivered) {
        showSuccess(context, title: done, subtitle: '#${order.orderNo}');
      } else {
        toast(context, done);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = order;
    final pickup = o.deliveryType == 'pickup';
    Widget? primary;
    switch (o.status) {
      case OrderStatus.placed:
        primary = Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => SellerOrderDetailScreen._cancel(context, o),
              child: Text(context.tr('Reject', 'अस्वीकार'), style: const TextStyle(color: G4MColors.danger)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              icon: const Icon(Icons.check_rounded),
              label: Text(context.tr('Accept order', 'ऑर्डर स्वीकार करें')),
              onPressed: () => _set(context, OrderStatus.confirmed, context.tr('Order accepted', 'ऑर्डर स्वीकार हुआ')),
            ),
          ),
        ]);
      case OrderStatus.confirmed:
        primary = FilledButton.icon(
          icon: const Icon(Icons.inventory_rounded),
          label: Text(context.tr('Mark as packed', 'पैक के रूप में चिह्नित करें')),
          onPressed: () => _set(context, OrderStatus.packed, context.tr('Marked packed', 'पैक हो गया')),
        );
      case OrderStatus.packed:
        primary = pickup
            ? FilledButton.icon(
                icon: const Icon(Icons.storefront_rounded),
                label: Text(context.tr('Ready for pickup', 'पिकअप के लिए तैयार')),
                onPressed: () => _set(context, OrderStatus.readyForPickup, context.tr('Customer notified', 'ग्राहक को सूचित किया')),
              )
            : FilledButton.icon(
                icon: const Icon(Icons.delivery_dining_rounded),
                label: Text(context.tr('Assign delivery partner', 'डिलीवरी पार्टनर असाइन करें')),
                onPressed: () => showModalBottomSheet<void>(context: context, isScrollControlled: true, builder: (_) => _AssignSheet(order: o)),
              );
      case OrderStatus.readyForPickup:
        primary = FilledButton.icon(
          icon: const Icon(Icons.how_to_reg_rounded),
          label: Text(context.tr('Mark collected', 'प्राप्त के रूप में चिह्नित करें')),
          onPressed: () => showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            builder: (_) => _CollectSheet(order: o, onDone: (otp, cash) => _set(context, OrderStatus.delivered, context.tr('Order completed', 'ऑर्डर पूरा हुआ'), otp: otp, cash: cash)),
          ),
        );
      default:
        primary = null;
    }
    if (primary == null) return const SizedBox.shrink();
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: BoxDecoration(color: context.rc.card, border: Border(top: BorderSide(color: context.rc.line))),
        child: SizedBox(width: double.infinity, child: primary),
      ).animate().slideY(begin: 1, duration: 400.ms, curve: Curves.easeOutCubic),
    );
  }
}

class _AssignSheet extends StatelessWidget {
  const _AssignSheet({required this.order});
  final ShopOrder order;

  Future<void> _assign(BuildContext context, String? partnerId) async {
    final nav = Navigator.of(context);
    final r = await runBusy(context, () => G4MApi.instance.assignDeliveryPartner(order.id, partnerId));
    if (r != null) {
      nav.pop();
      if (context.mounted) toast(context, context.tr('Delivery partner assigned', 'डिलीवरी पार्टनर असाइन हुआ'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: .6,
      maxChildSize: .9,
      builder: (context, sc) => StreamBuilder<List<DeliveryPartner>>(
        stream: SellerData.riders(),
        builder: (context, snap) {
          final riders = (snap.data ?? const <DeliveryPartner>[]).where((r) => r.status == 'approved').toList();
          return ListView(controller: sc, padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: [
            Text(context.tr('Assign delivery', 'डिलीवरी असाइन करें'), style: context.tt.titleLarge),
            const SizedBox(height: 14),
            AppCard(
              color: context.rc.brandSoft,
              borderColor: context.rc.brand.withValues(alpha: .4),
              onTap: () => _assign(context, null),
              child: Row(children: [
                Icon(Icons.auto_awesome_rounded, color: context.rc.brand),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(context.tr('Auto-assign nearest', 'निकटतम को स्वतः असाइन करें'), style: context.tt.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                    Text(context.tr('Go4Market picks the closest online rider', 'Go4Market निकटतम ऑनलाइन राइडर चुनेगा'), style: context.tt.bodySmall),
                  ]),
                ),
                const Icon(Icons.chevron_right_rounded),
              ]),
            ).stagger(0),
            const SizedBox(height: 16),
            SectionTitle(context.tr('Your delivery boys', 'आपके डिलीवरी बॉय')),
            if (snap.hasError)
              Text(describeErrorShort(snap.error!), style: context.tt.bodySmall)
            else if (!snap.hasData)
              const Shimmer(height: 64)
            else if (riders.isEmpty)
              Text(context.tr('No riders linked to your store yet.', 'आपके स्टोर से अभी कोई राइडर नहीं जुड़ा है।'), style: context.tt.bodySmall)
            else
              for (var i = 0; i < riders.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AppCard(
                    onTap: () => _assign(context, riders[i].id),
                    padding: const EdgeInsets.all(12),
                    child: Row(children: [
                      Stack(children: [
                        Avatar(name: riders[i].name, url: riders[i].photoUrl),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: riders[i].online ? G4MColors.success : context.rc.faint,
                              shape: BoxShape.circle,
                              border: Border.all(color: context.rc.card, width: 2),
                            ),
                          ),
                        ),
                      ]),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(riders[i].name, style: context.tt.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                          Text(
                            '${riders[i].online ? context.s.online : context.s.offline} · ${Fmt.titleCase(riders[i].vehicleType)} · ${riders[i].completedCount} ${context.tr('done', 'पूर्ण')}',
                            style: context.tt.bodySmall,
                          ),
                        ]),
                      ),
                      if (riders[i].online) const PulseDot(size: 8),
                    ]),
                  ).stagger(i + 1),
                ),
          ]);
        },
      ),
    );
  }
}

String describeErrorShort(Object e) => e.toString().contains('permission') ? 'Riders list is not available for your account yet.' : friendlyError(e);

class _CollectSheet extends StatefulWidget {
  const _CollectSheet({required this.order, required this.onDone});
  final ShopOrder order;
  final void Function(String? otp, double? cash) onDone;
  @override
  State<_CollectSheet> createState() => _CollectSheetState();
}

class _CollectSheetState extends State<_CollectSheet> {
  final _otp = TextEditingController();
  bool _cash = false;

  bool get _cod => widget.order.paymentMethod == 'cod' && widget.order.paymentStatus != 'paid';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(context.tr('Hand over order', 'ऑर्डर सौंपें'), style: context.tt.titleLarge),
        const SizedBox(height: 6),
        Text(context.tr('Ask the customer for their pickup code (if shown in their app).', 'ग्राहक से उनका पिकअप कोड पूछें (यदि उनके ऐप में दिखे)।'),
            style: context.tt.bodySmall),
        const SizedBox(height: 14),
        TextField(
          controller: _otp,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: context.tt.headlineSmall?.copyWith(letterSpacing: 10),
          decoration: InputDecoration(counterText: '', hintText: context.tr('Code (optional)', 'कोड (वैकल्पिक)')),
        ),
        if (_cod) ...[
          const SizedBox(height: 10),
          CheckboxListTile(
            value: _cash,
            onChanged: (v) => setState(() => _cash = v ?? false),
            contentPadding: EdgeInsets.zero,
            title: Text('${context.tr('Cash collected', 'नकद प्राप्त')} ${Fmt.money(widget.order.payable)}'),
          ),
        ],
        const SizedBox(height: 14),
        FilledButton(
          onPressed: _cod && !_cash
              ? null
              : () {
                  Navigator.pop(context);
                  widget.onDone(_otp.text.trim().isEmpty ? null : _otp.text.trim(), _cod ? widget.order.payable : null);
                },
          child: Text(context.tr('Complete order', 'ऑर्डर पूरा करें')),
        ),
      ]),
    );
  }
}
