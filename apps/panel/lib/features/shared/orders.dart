import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:g4m_core/g4m_core.dart' hide Fmt, EmptyState;
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../core/doc.dart';
import '../../core/live.dart';
import '../../core/session.dart';
import '../../core/web_utils.dart';
import '../../ui/data_view.dart';
import '../../ui/kit.dart';
import 'a_common.dart';
import 'a_invoice.dart';
import 'package:panel/l10n/overrides.dart';

// ═════════════════════════════ Orders list ═════════════════════════════

class OrdersPage extends StatelessWidget {
  const OrdersPage({super.key, this.scope = 'all'});

  /// 'all' | 'pickup' | 'pos'
  final String scope;

  Query<Json> _base() {
    Query<Json> q = Fs.orders;
    if (isSellerPanel) q = q.where('sellerIds', arrayContains: session.uid);
    if (scope == 'pickup') q = q.where('deliveryType', isEqualTo: 'pickup');
    if (scope == 'pos') q = q.where('channel', isEqualTo: 'pos');
    return q;
  }

  Stream<List<ShopOrder>> _source(SourceQuery sq) {
    var base = _base();
    final st = sq.filters['status'];
    if (st != null) base = base.where('status', isEqualTo: st);
    return liveQuery<ShopOrder>(
      base.orderBy('createdAt', descending: true).limit(sq.limit),
      ShopOrder.fromDoc,
      fallback: base.limit(sq.limit),
      sortFallback: (a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)),
      label: 'orders ${isSellerPanel ? 'sellerIds+' : ''}${scope == 'all' ? '' : '$scope+'}${st != null ? 'status+' : ''}createdAt',
    );
  }

  String get _title => switch (scope) {
        'pickup' => 'Self-pickup orders',
        'pos' => 'POS orders',
        _ => isSellerPanel ? 'Orders' : 'All orders',
      };

  double _amount(ShopOrder o) => isSellerPanel ? sellerSubtotal(o, session.uid) : o.total;

  @override
  Widget build(BuildContext context) {
    final seller = isSellerPanel;
    return PanelPage(
      title: _title,
      subtitle: switch (scope) {
        'pickup' => 'Orders customers collect in store — mark them ready and hand them over.',
        'pos' => 'In-store sales made from the point of sale.',
        _ => seller ? 'Orders that contain your products.' : 'Every order across sellers, modules and channels.',
      },
      actions: [
        if (scope != 'pos') OutlinedButton.icon(onPressed: () => context.go('/pos'), icon: const Icon(Icons.point_of_sale_rounded, size: 18), label: Text(tr('New POS sale'))),
      ],
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _StatStrip(stream: _source(const SourceQuery(300, {})), amount: _amount),
        const SizedBox(height: 18),
        DataView<ShopOrder>(
          id: 'orders_$scope',
          source: _source,
          rowId: (o) => o.id,
          csvName: 'orders_$scope',
          searchText: (o) => [
            o.orderNo,
            o.customerName,
            o.customerPhone,
            '${o.customer['email'] ?? ''}',
            o.couponCode,
            o.deliveryPartnerName,
            ...o.items.map((i) => '${i.name} ${i.sellerName}'),
          ].join(' '),
          filters: [
            TableFilter('status', 'Status', orderStatusOptions, server: true),
            TableFilter('payment', 'Payment', paymentStatusOptions, test: (o, v) => o.paymentStatus == v),
            TableFilter('method', 'Method', paymentMethodOptions, test: (o, v) => o.paymentMethod == v),
            if (scope == 'all') TableFilter('channel', 'Channel', channelOptions, test: (o, v) => o.channel == v),
            if (scope != 'pos') TableFilter('speed', 'Speed', speedOptions, test: (o, v) => o.speed == v),
          ],
          columns: [
            Col('Order',
                flex: 3,
                text: (o) => o.orderNo,
                sort: (o) => o.createdAt?.millisecondsSinceEpoch ?? 0,
                cell: (c, o) => TwoLine(o.orderNo, Fmt.dateTime(o.createdAt))),
            Col('Customer', flex: 3, text: (o) => o.customerName, cell: (c, o) => TwoLine(o.customerName, o.customerPhone)),
            if (!seller)
              Col('Sellers',
                  flex: 3,
                  text: (o) => o.items.map((i) => i.sellerName).where((s) => s.isNotEmpty).toSet().join(', '),
                  cell: (c, o) {
                    final s = o.items.map((i) => i.sellerName).where((s) => s.isNotEmpty).toSet().toList();
                    return TwoLine(s.isEmpty ? '—' : s.first, s.length > 1 ? '+${s.length - 1} more' : null);
                  }),
            Col('Items', flex: 1, numeric: true, text: (o) => '${seller ? o.items.where((i) => i.sellerId == session.uid).fold<int>(0, (a, i) => a + i.qty) : o.itemCount}', sort: (o) => o.itemCount),
            Col('Total',
                flex: 2,
                numeric: true,
                text: (o) => Fmt.money(_amount(o)),
                csv: (o) => _amount(o).toStringAsFixed(2),
                sort: _amount,
                cell: (c, o) => Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
                      Text(Fmt.money(_amount(o)), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                      Text(Fmt.titleCase(o.paymentMethod), style: TextStyle(fontSize: 11.5, color: c.pal.muted)),
                    ])),
            Col('Payment', flex: 2, text: (o) => o.paymentStatus, cell: (c, o) => statusPill(o.paymentStatus)),
            Col('Status', flex: 2, text: (o) => tr(OrderStatus.label(o.status)), cell: (c, o) => orderStatusPill(o.status)),
            Col('Type', flex: 2, text: (o) => '${o.deliveryType} ${o.speed}', cell: (c, o) => _typeTags(c, o)),
          ],
          card: (c, o) => _OrderCard(order: o, amount: _amount(o)),
          onTap: (o) => context.go('/orders/${o.id}'),
          actions: [
            RowAction('View details', Icons.open_in_new_rounded, (o) => context.go('/orders/${o.id}')),
            RowAction('Invoice', Icons.receipt_rounded, (o) => context.go('/print/invoice/${o.id}')),
            RowAction('Accept / confirm', Icons.check_circle_outline_rounded, (o) => runToast(() => G4MApi.instance.updateOrderStatus(o.id, OrderStatus.confirmed), success: '${o.orderNo} confirmed'),
                visible: (o) => o.status == OrderStatus.placed),
            RowAction('Mark packed', Icons.inventory_2_outlined, (o) => runToast(() => G4MApi.instance.updateOrderStatus(o.id, OrderStatus.packed), success: '${o.orderNo} packed'),
                visible: (o) => o.status == OrderStatus.confirmed),
          ],
          bulkActions: [
            BulkAction('Confirm placed orders', Icons.done_all_rounded, (rows) async {
              final placed = rows.where((o) => o.status == OrderStatus.placed).toList();
              if (placed.isEmpty) throw 'None of the selected orders are in "placed" status';
              final errors = <String>[];
              for (final o in placed) {
                try {
                  await G4MApi.instance.updateOrderStatus(o.id, OrderStatus.confirmed, note: 'Bulk confirmed');
                } catch (e) {
                  errors.add('${o.orderNo}: ${friendlyError(e)}');
                }
              }
              if (errors.isNotEmpty) throw errors.join('\n');
            }),
          ],
          emptyIcon: Icons.receipt_long_outlined,
          emptyTitle: 'No orders yet',
          emptyMessage: 'New orders appear here in real time.',
        ),
      ]),
    );
  }

  Widget _typeTags(BuildContext c, ShopOrder o) => Wrap(spacing: 4, runSpacing: 4, children: [
        if (o.channel == 'pos')
          const Tag('POS', color: G4MColors.primaryDeep, icon: Icons.point_of_sale_rounded)
        else if (o.deliveryType == 'pickup')
          const Tag('Pickup', color: Color(0xFF7C3AED), icon: Icons.storefront_rounded)
        else
          const Tag('Home', color: G4MColors.info, icon: Icons.home_rounded),
        if (o.speed == 'quick15' || o.speed == 'quick30') Tag(o.speed == 'quick15' ? '15 min' : '30 min', color: G4MColors.accent, icon: Icons.bolt_rounded),
        if (o.speed == 'scheduled') const Tag('Slot', color: Color(0xFF0891B2), icon: Icons.schedule_rounded),
      ]);
}

class _StatStrip extends StatelessWidget {
  const _StatStrip({required this.stream, required this.amount});
  final Stream<List<ShopOrder>> stream;
  final double Function(ShopOrder) amount;
  @override
  Widget build(BuildContext context) => StreamBuilder<List<ShopOrder>>(
        stream: stream,
        builder: (context, snap) {
          final l = snap.data ?? const <ShopOrder>[];
          int n(Set<String> s) => l.where((o) => s.contains(o.status)).length;
          final today = dayStart(DateTime.now());
          final todayRev = l.where((o) => (o.createdAt ?? DateTime(0)).isAfter(today) && countsAsSale(o)).fold<double>(0, (a, o) => a + amount(o));
          final cards = [
            KpiCard(label: 'New', value: snap.hasData ? '${n({OrderStatus.placed})}' : '—', icon: Icons.fiber_new_rounded, color: G4MColors.info),
            KpiCard(label: 'Processing', value: snap.hasData ? '${n({OrderStatus.confirmed, OrderStatus.packed, OrderStatus.readyForPickup})}' : '—', icon: Icons.sync_rounded, color: const Color(0xFF7C3AED)),
            KpiCard(label: 'On the way', value: snap.hasData ? '${n({OrderStatus.assigned, OrderStatus.pickedUp, OrderStatus.outForDelivery})}' : '—', icon: Icons.local_shipping_rounded, color: G4MColors.accent),
            KpiCard(label: 'Delivered', value: snap.hasData ? '${n({OrderStatus.delivered})}' : '—', icon: Icons.check_circle_rounded, color: G4MColors.success),
            KpiCard(label: 'Cancelled', value: snap.hasData ? '${n({OrderStatus.cancelled, OrderStatus.returned})}' : '—', icon: Icons.cancel_rounded, color: G4MColors.danger),
            KpiCard(label: "Today's sales", value: snap.hasData ? Fmt.money(todayRev) : '—', icon: Icons.currency_rupee_rounded),
          ];
          return ResponsiveGrid(minItemWidth: 170, spacing: 12, children: [
            for (var i = 0; i < cards.length; i++) cards[i].animate(delay: (40 * i).ms).fadeIn(duration: 260.ms).slideY(begin: .08),
          ]);
        },
      );
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.amount});
  final ShopOrder order;
  final double amount;
  @override
  Widget build(BuildContext context) {
    final o = order;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(end: 80),
          child: Text(o.orderNo, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
        ),
        Text(Fmt.dateTime(o.createdAt), style: TextStyle(color: context.pal.muted, fontSize: 12)),
        const SizedBox(height: 10),
        orderStatusPill(o.status),
        const SizedBox(height: 12),
        Row(children: [
          Avatar(name: o.customerName, size: 30),
          const SizedBox(width: 8),
          Expanded(child: TwoLine(o.customerName, o.customerPhone)),
        ]),
        const SizedBox(height: 12),
        SizedBox(
          height: 40,
          child: Row(children: [
            for (final i in o.items.take(4)) Padding(padding: const EdgeInsetsDirectional.only(end: 6), child: RowThumb(i.image, size: 38)),
            if (o.items.length > 4) Text('+${o.items.length - 4}', style: TextStyle(color: context.pal.muted, fontWeight: FontWeight.w700)),
          ]),
        ),
        const SizedBox(height: 12),
        Divider(color: context.pal.line, height: 1),
        const SizedBox(height: 10),
        Row(children: [
          Text(Fmt.titleCase(o.paymentMethod), style: TextStyle(color: context.pal.muted, fontSize: 12.5)),
          const SizedBox(width: 6),
          statusPill(o.paymentStatus),
          const Spacer(),
          Text(Fmt.money(amount), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        ]),
      ]),
    );
  }
}

// ═════════════════════════════ Order detail ═════════════════════════════

class OrderDetailPage extends StatelessWidget {
  const OrderDetailPage({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context) => StreamBuilder<Doc?>(
        stream: liveDoc(Fs.orders.doc(id)),
        builder: (context, snap) {
          if (snap.hasError) {
            return PanelPage(title: 'Order', child: ErrorBox(snap.error!));
          }
          if (!snap.hasData && snap.connectionState != ConnectionState.active) {
            return const PanelPage(title: 'Loading order…', child: SectionCard(child: LoadingBlock(rows: 5)));
          }
          final d = snap.data;
          if (d == null) {
            return PanelPage(
              title: 'Order not found',
              child: EmptyState(
                icon: Icons.search_off_rounded,
                title: 'This order does not exist',
                message: 'It may have been removed, or you do not have access to it.',
                action: FilledButton(onPressed: () => context.go('/orders'), child: Text(tr('Back to orders'))),
              ),
            );
          }
          return _OrderDetail(order: orderOf(d));
        },
      );
}

class _OrderDetail extends StatelessWidget {
  const _OrderDetail({required this.order});
  final ShopOrder order;

  @override
  Widget build(BuildContext context) {
    final o = order;
    final wide = MediaQuery.sizeOf(context).width > 1180;
    final left = <Widget>[
      _ItemsCard(order: o),
      _PaymentCard(order: o),
      _TimelineCard(order: o),
    ];
    final right = <Widget>[
      _ActionsCard(order: o),
      _CustomerCard(order: o),
      if (o.deliveryType != 'pickup' && o.channel != 'pos') _RiderCard(order: o),
      _DeliveryInfoCard(order: o),
    ];
    Widget col(List<Widget> l) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (var i = 0; i < l.length; i++) ...[
            l[i].animate(delay: (50 * i).ms).fadeIn(duration: 280.ms).slideY(begin: .03, curve: Curves.easeOutCubic),
            const SizedBox(height: 16),
          ],
        ]);
    return PanelPage(
      title: 'Order ${o.orderNo}',
      subtitle: 'Placed ${Fmt.dateTime(o.createdAt)} · ${Fmt.titleCase(o.channel)} · ${o.itemCount} item(s)',
      actions: [
        orderStatusPill(o.status),
        OutlinedButton.icon(onPressed: () => context.go('/print/invoice/${o.id}'), icon: const Icon(Icons.receipt_rounded, size: 18), label: Text(tr('Invoice'))),
        OutlinedButton.icon(
          onPressed: () => context.go(isDeliveryPanel ? '/orders' : '/orders'),
          icon: const Icon(Icons.arrow_back_rounded, size: 18),
          label: Text(tr('All orders')),
        ),
      ],
      child: wide
          ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(flex: 3, child: col(left)),
              const SizedBox(width: 16),
              Expanded(flex: 2, child: col(right)),
            ])
          : col([right.first, ...left, ...right.skip(1)]),
    );
  }
}

// ───── Items ─────

class _ItemsCard extends StatelessWidget {
  const _ItemsCard({required this.order});
  final ShopOrder order;
  @override
  Widget build(BuildContext context) {
    final groups = <String, List<OrderItem>>{};
    for (final i in order.items) {
      groups.putIfAbsent(i.sellerId, () => []).add(i);
    }
    final me = session.uid;
    return SectionCard(
      title: 'Items',
      subtitle: '${order.itemCount} item(s) from ${groups.length} seller(s)',
      icon: Icons.shopping_bag_outlined,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final g in groups.entries) ...[
          Opacity(
            opacity: isSellerPanel && g.key != me ? .45 : 1,
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(border: Border.all(color: context.pal.line), borderRadius: BorderRadius.circular(12)),
              child: Column(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(color: context.pal.surfaceAlt.withValues(alpha: .6), borderRadius: const BorderRadius.vertical(top: Radius.circular(12))),
                  child: Row(children: [
                    Icon(Icons.storefront_rounded, size: 18, color: context.pal.accent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(g.value.first.sellerName.isEmpty ? 'Seller' : g.value.first.sellerName,
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                    ),
                    if (isSellerPanel && g.key != me) const Tag('Other seller'),
                    if (isSellerPanel && g.key == me) Tag('Your items', color: context.pal.accent),
                    if (isAdminPanel && g.key.isNotEmpty)
                      TextButton(onPressed: () => context.go('/sellers/${g.key}'), child: Text(tr('View seller'))),
                    const SizedBox(width: 6),
                    Text(Fmt.money(g.value.fold<double>(0, (a, i) => a + i.lineTotal)), style: const TextStyle(fontWeight: FontWeight.w800)),
                  ]),
                ),
                for (final i in g.value)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(children: [
                      RowThumb(i.image, size: 48),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(i.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                          Text([if (i.variantName.isNotEmpty) i.variantName, '${Fmt.money(i.price)} × ${i.qty}'].join(' · '),
                              style: TextStyle(color: context.pal.muted, fontSize: 12.5)),
                        ]),
                      ),
                      if (i.mrp > i.price)
                        Padding(
                          padding: const EdgeInsetsDirectional.only(end: 10),
                          child: Text(Fmt.money(i.mrp * i.qty),
                              style: TextStyle(color: context.pal.faint, decoration: TextDecoration.lineThrough, fontSize: 12)),
                        ),
                      Text(Fmt.money(i.lineTotal), style: const TextStyle(fontWeight: FontWeight.w800)),
                    ]),
                  ),
              ]),
            ),
          ),
        ],
      ]),
    );
  }
}

// ───── Payment summary ─────

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({required this.order});
  final ShopOrder order;
  @override
  Widget build(BuildContext context) {
    final o = order;
    Widget row(String l, double v, {bool neg = false, bool bold = false, String? extra}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(children: [
            Text(l, style: TextStyle(color: bold ? null : context.pal.muted, fontWeight: bold ? FontWeight.w800 : FontWeight.w500, fontSize: bold ? 15 : 13.5)),
            if (extra != null) ...[const SizedBox(width: 6), Tag(extra, color: G4MColors.success)],
            const Spacer(),
            Text('${neg && v > 0 ? '− ' : ''}${Fmt.money(v)}',
                style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w600, fontSize: bold ? 17 : 13.5, color: neg && v > 0 ? G4MColors.success : null)),
          ]),
        );
    return SectionCard(
      title: 'Payment',
      icon: Icons.payments_outlined,
      trailing: statusPill(o.paymentStatus),
      child: Column(children: [
        row('Subtotal', o.subtotal),
        row('Delivery fee', o.deliveryFee),
        if (o.discount > 0) row('Discount', o.discount, neg: true, extra: o.couponCode.isEmpty ? null : o.couponCode),
        if (o.tax > 0) row('Tax', o.tax),
        Divider(color: context.pal.line),
        row('Total', o.total, bold: true),
        if (o.walletUsed > 0) row('Paid from wallet', o.walletUsed, neg: true),
        row('Payable (${Fmt.titleCase(o.paymentMethod)})', o.payable),
        if (isSellerPanel) ...[
          Divider(color: context.pal.line),
          row('Your items subtotal', sellerSubtotal(o, session.uid), bold: true),
        ],
        if ('${o.data['paymentRef'] ?? ''}'.isNotEmpty) InfoRow('Payment ref', '${o.data['paymentRef']}'),
        if (o.data['cashCollected'] != null) InfoRow('Cash collected', Fmt.money(toNum(o.data['cashCollected']))),
      ]),
    );
  }
}

// ───── Timeline ─────

class _TimelineCard extends StatelessWidget {
  const _TimelineCard({required this.order});
  final ShopOrder order;
  @override
  Widget build(BuildContext context) {
    final o = order;
    final tl = o.timeline;
    final flow = flowOf(o);
    final terminalBad = o.status == OrderStatus.cancelled || o.status == OrderStatus.returned;
    final reached = <String, TimelineEntry>{for (final t in tl) t.status: t};
    final curIdx = flow.indexOf(o.status);
    final steps = <(String, TimelineEntry?, bool done, bool current)>[];
    for (var i = 0; i < flow.length; i++) {
      final s = flow[i];
      final done = reached.containsKey(s) || (curIdx >= 0 && i <= curIdx);
      if (terminalBad && !reached.containsKey(s)) continue;
      steps.add((s, reached[s], done, s == o.status));
    }
    if (terminalBad) steps.add((o.status, reached[o.status], true, true));

    return SectionCard(
      title: 'Timeline',
      icon: Icons.timeline_rounded,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (var i = 0; i < steps.length; i++)
          _TimelineStep(
            label: OrderStatus.label(steps[i].$1),
            entry: steps[i].$2,
            done: steps[i].$3,
            current: steps[i].$4,
            last: i == steps.length - 1,
            color: steps[i].$1 == OrderStatus.cancelled || steps[i].$1 == OrderStatus.returned ? G4MColors.danger : orderStatusColor(steps[i].$1),
            note: steps[i].$1 == OrderStatus.cancelled && o.cancelReason.isNotEmpty ? o.cancelReason : null,
          ).animate(delay: (70 * i).ms).fadeIn(duration: 260.ms).slideX(begin: -.03),
        if (tl.isNotEmpty) ...[
          const SizedBox(height: 8),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text('Activity log (${tl.length})', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
            children: [
              for (final t in tl.reversed)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.circle, size: 10, color: orderStatusColor(t.status)),
                  title: Text('${OrderStatus.label(t.status)}${t.note.isNotEmpty ? ' — ${t.note}' : ''}'),
                  subtitle: Text('${Fmt.dateTime(t.at)}${t.by.isNotEmpty ? ' · by ${t.by}' : ''}'),
                ),
            ],
          ),
        ],
      ]),
    );
  }
}

class _TimelineStep extends StatelessWidget {
  const _TimelineStep({required this.label, required this.entry, required this.done, required this.current, required this.last, required this.color, this.note});
  final String label;
  final TimelineEntry? entry;
  final bool done;
  final bool current;
  final bool last;
  final Color color;
  final String? note;
  @override
  Widget build(BuildContext context) {
    final c = done ? color : context.pal.line;
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          width: 28,
          child: Column(children: [
            Container(
              width: current ? 22 : 18,
              height: current ? 22 : 18,
              decoration: BoxDecoration(
                color: done ? c : context.pal.surface,
                shape: BoxShape.circle,
                border: Border.all(color: c, width: 2),
                boxShadow: current ? [BoxShadow(color: c.withValues(alpha: .4), blurRadius: 10)] : null,
              ),
              child: done ? const Icon(Icons.check_rounded, size: 12, color: Colors.white) : null,
            ),
            if (!last) Expanded(child: Container(width: 2, color: done ? c.withValues(alpha: .5) : context.pal.line)),
          ]),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: TextStyle(fontWeight: current ? FontWeight.w800 : FontWeight.w600, color: done ? null : context.pal.muted)),
              if (entry?.at != null) Text(Fmt.dateTime(entry!.at), style: TextStyle(fontSize: 12, color: context.pal.muted)),
              if ((entry?.note ?? '').isNotEmpty || note != null)
                Text(note ?? entry!.note, style: TextStyle(fontSize: 12, color: context.pal.faint, fontStyle: FontStyle.italic)),
            ]),
          ),
        ),
      ]),
    );
  }
}

// ───── Customer / address ─────

class _CustomerCard extends StatelessWidget {
  const _CustomerCard({required this.order});
  final ShopOrder order;
  @override
  Widget build(BuildContext context) {
    final o = order;
    final a = Address('addr', o.address);
    return SectionCard(
      title: 'Customer',
      icon: Icons.person_outline_rounded,
      trailing: isAdminPanel && o.userId.isNotEmpty ? TextButton(onPressed: () => context.go('/customers/${o.userId}'), child: Text(tr('Profile'))) : null,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Avatar(name: o.customerName, size: 42),
          const SizedBox(width: 12),
          Expanded(child: TwoLine(o.customerName, [o.customerPhone, '${o.customer['email'] ?? ''}'].where((e) => e.isNotEmpty).join(' · '))),
          if (o.customerPhone.isNotEmpty)
            IconButton(tooltip: 'Call', onPressed: () => openUrl('tel:${o.customerPhone}'), icon: const Icon(Icons.call_outlined, size: 20)),
        ]),
        if (o.deliveryType != 'pickup' && o.address.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text('Delivery address', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: context.pal.muted)),
          const SizedBox(height: 4),
          SelectableText([if (a.name.isNotEmpty) '${a.name}${a.phone.isNotEmpty ? ' · ${a.phone}' : ''}', a.oneLine].join('\n'), style: const TextStyle(height: 1.45)),
          if (a.lat != null && a.lng != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 200,
                child: _OrderMap(order: o, drop: LatLng(a.lat!, a.lng!)),
              ),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Text('${o.distanceKm > 0 ? '${o.distanceKm.toStringAsFixed(1)} km · ' : ''}${a.lat!.toStringAsFixed(5)}, ${a.lng!.toStringAsFixed(5)}',
                  style: TextStyle(fontSize: 12, color: context.pal.muted)),
              const Spacer(),
              TextButton.icon(onPressed: () => openUrl(directionsUrl(a.lat!, a.lng!)), icon: const Icon(Icons.navigation_rounded, size: 16), label: Text(tr('Navigate'))),
            ]),
          ],
        ],
        if (o.deliveryType == 'pickup') ...[
          const SizedBox(height: 12),
          const Tag('Customer will collect in store', icon: Icons.storefront_rounded, color: Color(0xFF7C3AED)),
        ],
      ]),
    );
  }
}

class _OrderMap extends StatelessWidget {
  const _OrderMap({required this.order, required this.drop});
  final ShopOrder order;
  final LatLng drop;
  @override
  Widget build(BuildContext context) {
    final riderId = order.deliveryPartnerId;
    final riderStream = riderId.isEmpty ? Stream<Doc?>.value(null) : liveDoc(Fs.deliveryPartners.doc(riderId)).handleError((_) {});
    return StreamBuilder<Doc?>(
      stream: riderStream,
      builder: (context, snap) {
        final r = snap.data;
        final rider = r != null && r['lat'] != null && r['lng'] != null ? LatLng(r.n('lat'), r.n('lng')) : null;
        return FlutterMap(
          options: MapOptions(
            initialCenter: drop,
            initialZoom: 14,
            initialCameraFit: rider == null ? null : CameraFit.coordinates(coordinates: [drop, rider], padding: const EdgeInsets.all(40), maxZoom: 16),
            interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
          ),
          children: [
            TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.go4market.panel'),
            if (rider != null)
              PolylineLayer(polylines: [
                Polyline(points: [rider, drop], color: G4MColors.accent.withValues(alpha: .7), strokeWidth: 3, pattern: StrokePattern.dashed(segments: const [8, 6])),
              ]),
            MarkerLayer(markers: [
              Marker(point: drop, width: 40, height: 40, alignment: Alignment.topCenter, child: const Icon(Icons.location_on_rounded, color: G4MColors.danger, size: 40)),
              if (rider != null)
                Marker(
                  point: rider,
                  width: 36,
                  height: 36,
                  child: Container(
                    decoration: BoxDecoration(color: G4MColors.accent, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3)),
                    child: const Icon(Icons.two_wheeler_rounded, color: Colors.white, size: 16),
                  ),
                ),
            ]),
            SimpleAttributionWidget(source: Text(tr('OpenStreetMap'))),
          ],
        );
      },
    );
  }
}

// ───── Delivery info ─────

class _DeliveryInfoCard extends StatelessWidget {
  const _DeliveryInfoCard({required this.order});
  final ShopOrder order;
  @override
  Widget build(BuildContext context) {
    final o = order;
    final slot = o.scheduledSlot;
    return SectionCard(
      title: 'Fulfilment',
      icon: Icons.local_shipping_outlined,
      child: Column(children: [
        InfoRow('Type', o.channel == 'pos' ? 'In-store (POS)' : o.deliveryType == 'pickup' ? 'Self pickup' : 'Home delivery'),
        InfoRow('Speed', speedOptions[o.speed] ?? Fmt.titleCase(o.speed)),
        if (slot.isNotEmpty) InfoRow('Scheduled slot', '${slot['date'] ?? ''} · ${slot['from'] ?? ''}–${slot['to'] ?? ''}'),
        if (o.etaAt != null)
          InfoRow('ETA', '', valueWidget: _Countdown(eta: o.etaAt!, active: o.isActive)),
        if (o.distanceKm > 0) InfoRow('Distance', '${o.distanceKm.toStringAsFixed(1)} km'),
        if (o.couponCode.isNotEmpty) InfoRow('Coupon', o.couponCode),
        if (o.cancelReason.isNotEmpty) InfoRow('Cancel reason', o.cancelReason),
        if (isAdminPanel || isDeliveryPanel)
          if (o.deliveryOtp.isNotEmpty && isAdminPanel) InfoRow('Delivery OTP', o.deliveryOtp),
      ]),
    );
  }
}

class _Countdown extends StatefulWidget {
  const _Countdown({required this.eta, required this.active});
  final DateTime eta;
  final bool active;
  @override
  State<_Countdown> createState() => _CountdownState();
}

class _CountdownState extends State<_Countdown> {
  Timer? _t;
  @override
  void initState() {
    super.initState();
    if (widget.active) _t = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final diff = widget.eta.difference(DateTime.now());
    final late = diff.isNegative;
    final m = diff.inMinutes.abs(), s = diff.inSeconds.abs() % 60;
    return Row(children: [
      Text(Fmt.time(widget.eta), style: const TextStyle(fontWeight: FontWeight.w700)),
      if (widget.active) ...[
        const SizedBox(width: 8),
        Tag(late ? 'Late by ${m}m' : '${m}m ${s.toString().padLeft(2, '0')}s left', color: late ? G4MColors.danger : G4MColors.success, icon: Icons.timer_outlined),
      ],
    ]);
  }
}

// ───── Rider ─────

class _RiderCard extends StatelessWidget {
  const _RiderCard({required this.order});
  final ShopOrder order;
  @override
  Widget build(BuildContext context) {
    final o = order;
    final has = o.deliveryPartnerId.isNotEmpty;
    return SectionCard(
      title: 'Delivery partner',
      icon: Icons.delivery_dining_outlined,
      trailing: has && isAdminPanel ? TextButton(onPressed: () => context.go('/delivery/partners/${o.deliveryPartnerId}'), child: Text(tr('Profile'))) : null,
      child: !has
          ? Row(children: [
              Icon(Icons.hourglass_empty_rounded, color: context.pal.muted),
              const SizedBox(width: 10),
              Expanded(child: Text('No rider assigned yet', style: TextStyle(color: context.pal.muted))),
            ])
          : StreamBuilder<Doc?>(
              stream: liveDoc(Fs.deliveryPartners.doc(o.deliveryPartnerId)).handleError((_) {}),
              builder: (context, snap) {
                final r = snap.data;
                return Row(children: [
                  Avatar(name: o.deliveryPartnerName, url: r?.s('photoUrl') ?? '', size: 42, color: G4MColors.accent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(o.deliveryPartnerName.isEmpty ? (r?.s('name') ?? 'Rider') : o.deliveryPartnerName, style: const TextStyle(fontWeight: FontWeight.w800)),
                      if (r != null)
                        Text('${Fmt.titleCase(r.s('vehicleType', 'bike'))} ${r.s('vehicleNo')} · ${r.s('phone')}',
                            style: TextStyle(color: context.pal.muted, fontSize: 12.5)),
                      if (r != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Tag(r.b('online') ? 'Online · ${Fmt.ago(r.dt('locationUpdatedAt'))}' : 'Offline',
                              color: r.b('online') ? G4MColors.success : context.pal.muted),
                        ),
                    ]),
                  ),
                  if ((r?.s('phone') ?? '').isNotEmpty)
                    IconButton(tooltip: 'Call rider', onPressed: () => openUrl('tel:${r!.s('phone')}'), icon: const Icon(Icons.call_outlined, size: 20)),
                ]);
              },
            ),
    );
  }
}

// ───── Role-aware actions ─────

class _ActionsCard extends StatelessWidget {
  const _ActionsCard({required this.order});
  final ShopOrder order;

  Future<void> _set(BuildContext context, String status, {String? note, String? otp, double? cash}) async {
    await runToast(
      () => G4MApi.instance.updateOrderStatus(order.id, status, note: note, otp: otp, cashCollected: cash),
      success: '${order.orderNo} → ${OrderStatus.label(status)}',
    );
  }

  Future<void> _cancel(BuildContext context) async {
    final reason = await promptText(context, 'Cancel order ${order.orderNo}', label: 'Reason (shared with the customer)', required: true, maxLines: 3, confirmLabel: 'Cancel order');
    if (reason == null || !context.mounted) return;
    await _set(context, OrderStatus.cancelled, note: reason);
  }

  Future<void> _deliver(BuildContext context) async {
    final r = await showDialog<(String, double?)>(context: context, builder: (_) => _DeliverDialog(order: order));
    if (r == null || !context.mounted) return;
    await _set(context, OrderStatus.delivered, otp: r.$1.isEmpty ? null : r.$1, cash: r.$2);
  }

  Future<void> _assign(BuildContext context, {required bool own}) async {
    final picked = await showDialog<String>(context: context, builder: (_) => _RiderPicker(order: order, sellerOwn: own));
    if (picked == null || !context.mounted) return;
    await runToast(
      () => G4MApi.instance.assignDeliveryPartner(order.id, picked == '__auto' ? null : picked),
      success: picked == '__auto' ? 'Nearest online rider is being assigned' : 'Rider assigned',
    );
  }

  @override
  Widget build(BuildContext context) {
    final o = order;
    final next = nextStatusOf(o);
    final buttons = <Widget>[];
    final isHome = o.deliveryType != 'pickup' && o.channel != 'pos';
    String hint = '';

    if (isAdminPanel) {
      if (next == OrderStatus.assigned) {
        buttons.add(AsyncButton(icon: Icons.bolt_rounded, label: 'Auto-assign nearest rider', onPressed: () async {
          await runToast(() => G4MApi.instance.assignDeliveryPartner(o.id), success: 'Assigning nearest online rider');
        }));
        buttons.add(AsyncButton(outlined: true, icon: Icons.person_search_rounded, label: 'Choose rider', onPressed: () => _assign(context, own: false)));
      } else if (next == OrderStatus.delivered) {
        buttons.add(AsyncButton(icon: Icons.task_alt_rounded, label: 'Mark delivered', onPressed: () => _deliver(context)));
      } else if (next != null) {
        buttons.add(AsyncButton(icon: Icons.arrow_forward_rounded, label: 'Mark ${OrderStatus.label(next).toLowerCase()}', onPressed: () => _set(context, next)));
      }
      if (isHome && o.deliveryPartnerId.isNotEmpty && {OrderStatus.assigned, OrderStatus.pickedUp}.contains(o.status)) {
        buttons.add(AsyncButton(outlined: true, icon: Icons.swap_horiz_rounded, label: 'Reassign rider', onPressed: () => _assign(context, own: false)));
      }
      if (o.status == OrderStatus.delivered) {
        buttons.add(AsyncButton(outlined: true, icon: Icons.assignment_return_outlined, label: 'Mark returned', onPressed: () async {
          final note = await promptText(context, 'Mark as returned', label: 'Note', required: true);
          if (note != null && context.mounted) await _set(context, OrderStatus.returned, note: note);
        }));
      }
      hint = next == null ? 'This order is closed.' : 'Next step: ${OrderStatus.label(next)}';
    } else if (isSellerPanel) {
      switch (o.status) {
        case OrderStatus.placed:
          buttons.add(AsyncButton(icon: Icons.check_rounded, label: 'Accept order', onPressed: () => _set(context, OrderStatus.confirmed, note: 'Accepted by seller')));
          hint = 'Accept to start preparing the order.';
        case OrderStatus.confirmed:
          buttons.add(AsyncButton(icon: Icons.inventory_2_rounded, label: 'Mark packed', onPressed: () => _set(context, OrderStatus.packed)));
          hint = 'Pack the items, then mark the order packed.';
        case OrderStatus.packed:
          if (o.deliveryType == 'pickup') {
            buttons.add(AsyncButton(icon: Icons.storefront_rounded, label: 'Ready for pickup', onPressed: () => _set(context, OrderStatus.readyForPickup)));
            hint = 'Let the customer know the order is ready to collect.';
          } else if (o.deliveryPartnerId.isEmpty) {
            buttons.add(AsyncButton(icon: Icons.delivery_dining_rounded, label: 'Assign my rider', onPressed: () => _assign(context, own: true)));
            buttons.add(AsyncButton(outlined: true, icon: Icons.support_agent_rounded, label: 'Request platform rider', onPressed: () async {
              await runToast(() => G4MApi.instance.assignDeliveryPartner(o.id), success: 'Requested a Go4Market rider');
            }));
            hint = 'Hand over to your own delivery partner or request one from Go4Market.';
          }
        case OrderStatus.readyForPickup:
          buttons.add(AsyncButton(icon: Icons.handshake_rounded, label: 'Handed to customer', onPressed: () => _deliver(context)));
          hint = 'Mark delivered once the customer collects the order.';
        default:
          hint = o.isActive ? 'The delivery partner is handling this order.' : 'This order is closed.';
      }
    } else {
      // delivery partner
      final mine = o.deliveryPartnerId == session.uid;
      if (!mine) {
        hint = 'This order is not assigned to you.';
      } else {
        switch (o.status) {
          case OrderStatus.assigned:
            buttons.add(AsyncButton(icon: Icons.shopping_bag_rounded, label: 'Picked up from store', onPressed: () => _set(context, OrderStatus.pickedUp)));
            hint = 'Collect the package from the seller.';
          case OrderStatus.pickedUp:
            buttons.add(AsyncButton(icon: Icons.two_wheeler_rounded, label: 'Start delivery', onPressed: () => _set(context, OrderStatus.outForDelivery)));
            hint = 'Head to the customer.';
          case OrderStatus.outForDelivery:
            buttons.add(AsyncButton(icon: Icons.task_alt_rounded, label: 'Complete delivery', onPressed: () => _deliver(context), color: G4MColors.success));
            hint = o.paymentMethod == 'cod' && o.paymentStatus != 'paid' ? 'Collect ${Fmt.money(o.payable)} cash and the OTP from the customer.' : 'Ask the customer for the delivery OTP.';
          default:
            hint = o.isActive ? 'Waiting for the store.' : 'Delivery closed.';
        }
        final lat = toNum(o.address['lat'], double.nan), lng = toNum(o.address['lng'], double.nan);
        if (!lat.isNaN && !lng.isNaN && o.isActive) {
          buttons.add(OutlinedButton.icon(onPressed: () => openUrl(directionsUrl(lat, lng)), icon: const Icon(Icons.navigation_rounded, size: 18), label: Text(tr('Navigate'))));
        }
      }
    }

    final canCancelHere = canCancel(o) &&
        (isAdminPanel || (isSellerPanel && !{OrderStatus.pickedUp, OrderStatus.outForDelivery}.contains(o.status)));

    return SectionCard(
      title: 'Actions',
      icon: Icons.bolt_outlined,
      trailing: isAdminPanel && o.isActive
          ? PopupMenuButton<String>(
              tooltip: 'Set any status',
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (s) async {
                final note = await promptText(context, 'Set status to ${OrderStatus.label(s)}', label: 'Note (optional)');
                if (note != null && context.mounted) await _set(context, s, note: note.isEmpty ? 'Set by admin' : note);
              },
              itemBuilder: (_) => [
                const PopupMenuItem(enabled: false, child: Text('Override status', style: TextStyle(fontWeight: FontWeight.w800))),
                for (final s in flowOf(o))
                  if (s != o.status && s != OrderStatus.assigned) PopupMenuItem(value: s, child: Text(OrderStatus.label(s))),
              ],
            )
          : null,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: orderStatusColor(o.status).withValues(alpha: .08), borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            Icon(o.isActive ? Icons.info_outline_rounded : Icons.lock_outline_rounded, color: orderStatusColor(o.status), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(OrderStatus.label(o.status), style: TextStyle(fontWeight: FontWeight.w800, color: orderStatusColor(o.status))),
                if (hint.isNotEmpty) Text(hint, style: TextStyle(fontSize: 12.5, color: context.pal.muted)),
              ]),
            ),
          ]),
        ),
        if (buttons.isNotEmpty || canCancelHere) const SizedBox(height: 14),
        Wrap(spacing: 10, runSpacing: 10, children: [
          ...buttons,
          if (canCancelHere)
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: G4MColors.danger, side: BorderSide(color: G4MColors.danger.withValues(alpha: .4))),
              onPressed: () => _cancel(context),
              icon: const Icon(Icons.close_rounded, size: 18),
              label: Text(isSellerPanel && o.status == OrderStatus.placed ? 'Reject' : 'Cancel order'),
            ),
        ]),
      ]),
    );
  }
}

class _DeliverDialog extends StatefulWidget {
  const _DeliverDialog({required this.order});
  final ShopOrder order;
  @override
  State<_DeliverDialog> createState() => _DeliverDialogState();
}

class _DeliverDialogState extends State<_DeliverDialog> {
  final _otp = TextEditingController();
  late final _cash = TextEditingController(
      text: widget.order.paymentMethod == 'cod' && widget.order.paymentStatus != 'paid' ? widget.order.payable.toStringAsFixed(widget.order.payable % 1 == 0 ? 0 : 2) : '');
  final _key = GlobalKey<FormState>();
  bool get _cod => widget.order.paymentMethod == 'cod' && widget.order.paymentStatus != 'paid';

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(tr('Complete delivery')),
        content: SizedBox(
          width: 420,
          child: Form(
            key: _key,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (widget.order.deliveryType != 'pickup')
                TextFormField(
                  controller: _otp,
                  autofocus: true,
                  maxLength: 6,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(letterSpacing: 8, fontWeight: FontWeight.w800, fontSize: 20),
                  decoration: InputDecoration(
                    labelText: 'Delivery OTP from customer',
                    helperText: isAdminPanel ? 'Optional for admins' : null,
                    prefixIcon: const Icon(Icons.password_rounded),
                  ),
                  validator: (v) => !isAdminPanel && (v == null || v.trim().length < 4) ? 'Enter the OTP' : null,
                ),
              if (_cod) ...[
                const SizedBox(height: 8),
                TextFormField(
                  controller: _cash,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: 'Cash collected', prefixText: '₹ ', helperText: 'Payable: ${Fmt.money(widget.order.payable)}'),
                  validator: (v) => double.tryParse(v ?? '') == null ? 'Enter the amount collected' : null,
                ),
              ],
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('Cancel'))),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: G4MColors.success),
            onPressed: () {
              if (!_key.currentState!.validate()) return;
              Navigator.pop(context, (_otp.text.trim(), _cod ? double.tryParse(_cash.text) : null));
            },
            icon: const Icon(Icons.task_alt_rounded, size: 18),
            label: Text(tr('Mark delivered')),
          ),
        ],
      );
}

class _RiderPicker extends StatefulWidget {
  const _RiderPicker({required this.order, required this.sellerOwn});
  final ShopOrder order;
  final bool sellerOwn;
  @override
  State<_RiderPicker> createState() => _RiderPickerState();
}

class _RiderPickerState extends State<_RiderPicker> {
  String _q = '';
  bool _onlineOnly = true;
  late final Stream<List<Doc>> _stream = widget.sellerOwn
      ? liveDocs(Fs.deliveryPartners.where('sellerId', isEqualTo: session.uid), label: 'deliveryPartners sellerId')
      : liveDocs(Fs.deliveryPartners.where('status', isEqualTo: 'approved'), label: 'deliveryPartners status');

  @override
  Widget build(BuildContext context) {
    final lat = toNum(widget.order.address['lat'], double.nan), lng = toNum(widget.order.address['lng'], double.nan);
    return AlertDialog(
      title: Text(widget.sellerOwn ? 'Assign your delivery partner' : 'Choose a rider'),
      content: SizedBox(
        width: 520,
        height: 460,
        child: Column(children: [
          Row(children: [
            Expanded(
              child: TextField(
                decoration: const InputDecoration(hintText: 'Search name, phone, vehicle…', prefixIcon: Icon(Icons.search_rounded)),
                onChanged: (v) => setState(() => _q = v.toLowerCase()),
              ),
            ),
            const SizedBox(width: 10),
            FilterChip(label: Text(tr('Online only')), selected: _onlineOnly, onSelected: (v) => setState(() => _onlineOnly = v)),
          ]),
          const SizedBox(height: 10),
          if (!widget.sellerOwn)
            ListTile(
              leading: const CircleAvatar(child: Icon(Icons.bolt_rounded)),
              title: const Text('Auto-assign nearest online rider', style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(tr('Let Go4Market pick the closest available partner')),
              onTap: () => Navigator.pop(context, '__auto'),
            ),
          Expanded(
            child: StreamBuilder<List<Doc>>(
              stream: _stream,
              builder: (context, snap) {
                if (snap.hasError) return ErrorBox(snap.error!);
                if (!snap.hasData) return const LoadingBlock(rows: 4);
                var l = snap.data!.where((d) => d.s('status') == 'approved').toList();
                if (!widget.sellerOwn) l = l.where((d) => d.s('ownerType', 'admin') == 'admin').toList();
                if (_onlineOnly) l = l.where((d) => d.b('online')).toList();
                if (_q.isNotEmpty) l = l.where((d) => '${d.s('name')} ${d.s('phone')} ${d.s('vehicleNo')}'.toLowerCase().contains(_q)).toList();
                double? dist(Doc d) => lat.isNaN || d['lat'] == null ? null : haversineKm(lat, lng, d.n('lat'), d.n('lng'));
                l.sort((a, b) => (dist(a) ?? 1e9).compareTo(dist(b) ?? 1e9));
                if (l.isEmpty) {
                  return EmptyState(
                    icon: Icons.two_wheeler_rounded,
                    title: _onlineOnly ? 'No online riders' : 'No riders found',
                    message: widget.sellerOwn ? 'Add delivery partners from "Delivery partners".' : 'Try turning off "Online only".',
                  );
                }
                return ListView.separated(
                  itemCount: l.length,
                  separatorBuilder: (_, _) => Divider(height: 1, color: context.pal.line),
                  itemBuilder: (_, i) {
                    final d = l[i];
                    final km = dist(d);
                    return ListTile(
                      leading: Stack(children: [
                        Avatar(name: d.s('name'), url: d.s('photoUrl'), color: G4MColors.accent),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 11,
                            height: 11,
                            decoration: BoxDecoration(
                              color: d.b('online') ? G4MColors.success : context.pal.faint,
                              shape: BoxShape.circle,
                              border: Border.all(color: context.pal.surface, width: 2),
                            ),
                          ),
                        ),
                      ]),
                      title: Text(d.s('name'), style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text('${Fmt.titleCase(d.s('vehicleType', 'bike'))} · ${d.s('phone')} · cash ${Fmt.money(d.n('cashInHand'))}'),
                      trailing: km == null ? null : Tag('${km.toStringAsFixed(1)} km', color: km < 3 ? G4MColors.success : G4MColors.warning),
                      onTap: () => Navigator.pop(context, d.id),
                    );
                  },
                );
              },
            ),
          ),
        ]),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('Close')))],
    );
  }
}

// ═════════════════════════════ Invoice ═════════════════════════════

class InvoicePage extends StatelessWidget {
  const InvoicePage({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.pal.bg,
      body: StreamBuilder<Doc?>(
        stream: liveDoc(Fs.orders.doc(id)),
        builder: (context, snap) {
          final top = Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(color: context.pal.surface, border: Border(bottom: BorderSide(color: context.pal.line))),
            child: Row(children: [
              IconButton(
                tooltip: 'Back',
                onPressed: () => context.canPop() ? context.pop() : context.go('/orders/$id'),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              const SizedBox(width: 8),
              Text('Invoice', style: context.tt.titleLarge),
              const Spacer(),
              if (snap.data != null)
                FutureBuilder<DocumentSnapshot<Json>>(
                  future: Fs.platformSettings.get(),
                  builder: (context, s) => FilledButton.icon(
                    onPressed: () => printHtml(invoiceHtml(orderOf(snap.data!), s.data?.data() ?? const {})),
                    icon: const Icon(Icons.print_rounded, size: 18),
                    label: Text(tr('Print / Save PDF')),
                  ),
                ),
            ]),
          );
          Widget body;
          if (snap.hasError) {
            body = ErrorBox(snap.error!);
          } else if (!snap.hasData) {
            body = snap.connectionState == ConnectionState.active
                ? const EmptyState(icon: Icons.search_off_rounded, title: 'Order not found')
                : const Padding(padding: EdgeInsets.all(40), child: LoadingBlock());
          } else {
            body = FutureBuilder<DocumentSnapshot<Json>>(
              future: Fs.platformSettings.get(),
              builder: (context, s) => InvoicePreview(order: orderOf(snap.data!), settings: s.data?.data() ?? const {}),
            );
          }
          return Column(children: [
            top,
            Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Center(child: body))),
          ]);
        },
      ),
    );
  }
}
