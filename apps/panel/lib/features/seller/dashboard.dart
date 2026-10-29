import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:g4m_core/g4m_core.dart' hide Fmt, EmptyState;
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/doc.dart';
import '../../core/live.dart';
import '../../core/session.dart';
import '../../ui/data_view.dart';
import '../../ui/kit.dart';
import '../shared/a_common.dart';
import 'package:panel/l10n/overrides.dart';

/// Seller home: KPIs, sales chart, status mix, recent orders, top & low-stock products.
class SellerDashboardPage extends StatefulWidget {
  const SellerDashboardPage({super.key});
  @override
  State<SellerDashboardPage> createState() => _SellerDashboardPageState();
}

class _SellerDashboardPageState extends State<SellerDashboardPage> {
  String _period = '7d';
  bool _revenue = true;

  late final Stream<List<ShopOrder>> _orders = liveQuery<ShopOrder>(
    Fs.orders
        .where('sellerIds', arrayContains: session.uid)
        .where('createdAt', isGreaterThanOrEqualTo: DateTime(DateTime.now().year, DateTime.now().month - 1, 1))
        .orderBy('createdAt', descending: true)
        .limit(1500),
    ShopOrder.fromDoc,
    fallback: Fs.orders.where('sellerIds', arrayContains: session.uid).limit(1500),
    sortFallback: (a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)),
    label: 'orders sellerIds+createdAt',
  );

  late final Stream<List<Doc>> _products = liveDocs(Fs.products.where('sellerId', isEqualTo: session.uid).limit(1000), label: 'products sellerId');

  @override
  Widget build(BuildContext context) {
    final uid = session.uid;
    final wide = MediaQuery.sizeOf(context).width > 1150;
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) => PanelPage(
        title: 'Welcome back, ${session.displayName}',
        subtitle: DateFormat('EEEE, d MMMM yyyy').format(DateTime.now()),
        actions: [
          Segmented<String>(value: _period, options: const {'7d': '7 days', '30d': '30 days'}, onChanged: (v) => setState(() => _period = v)),
          OutlinedButton.icon(onPressed: () => context.go('/pos'), icon: const Icon(Icons.point_of_sale_rounded, size: 18), label: Text(tr('Open POS'))),
          FilledButton.icon(onPressed: () => context.go('/catalog/products/new'), icon: const Icon(Icons.add_rounded, size: 18), label: Text(tr('Add product'))),
        ],
        child: StreamBuilder<List<ShopOrder>>(
          stream: _orders,
          builder: (context, os) => StreamBuilder<List<Doc>>(
            stream: _products,
            builder: (context, ps) {
              final orders = os.data ?? const <ShopOrder>[];
              final products = ps.data ?? const <Doc>[];
              final now = DateTime.now();
              final today = dayStart(now);
              final month = DateTime(now.year, now.month);
              final sales = orders.where(countsAsSale).toList();
              double rev(Iterable<ShopOrder> l) => l.fold(0, (a, o) => a + sellerSubtotal(o, uid));
              final todayOrders = orders.where((o) => (o.createdAt ?? DateTime(0)).isAfter(today)).length;
              final monthRev = rev(sales.where((o) => !(o.createdAt ?? DateTime(0)).isBefore(month)));
              final prevMonthRev = rev(sales.where((o) {
                final c = o.createdAt ?? DateTime(0);
                return !c.isBefore(DateTime(now.year, now.month - 1)) && c.isBefore(DateTime(now.year, now.month - 1, now.day + 1));
              }));
              final out = products.where((p) => _stockOf(p) <= 0 && p.s('status') != 'draft').toList();
              final low = products.where((p) {
                final s = _stockOf(p);
                return s > 0 && s <= p.n('lowStockAt', 5);
              }).toList();
              final pending = orders.where((o) => o.status == OrderStatus.placed).length;
              final loading = !os.hasData;

              final days = _period == '30d' ? 30 : 7;
              final start = today.subtract(Duration(days: days - 1));
              final f = DateFormat(days == 7 ? 'EEE' : 'd MMM');
              final points = <(String, double)>[];
              for (var d = start; !d.isAfter(today); d = d.add(const Duration(days: 1))) {
                final dayOrders = sales.where((o) {
                  final c = o.createdAt;
                  return c != null && dayStart(c) == d;
                });
                points.add((f.format(d), _revenue ? rev(dayOrders) : dayOrders.length.toDouble()));
              }
              final byStatus = <String, double>{};
              for (final o in orders.where((o) => !(o.createdAt ?? DateTime(0)).isBefore(start))) {
                byStatus[o.status] = (byStatus[o.status] ?? 0) + 1;
              }

              final kpis = [
                KpiCard(label: "Today's orders", value: loading ? '—' : '$todayOrders', icon: Icons.shopping_bag_rounded, color: G4MColors.info, caption: pending > 0 ? '$pending awaiting acceptance' : null, onTap: () => context.go('/orders')),
                KpiCard(label: 'Revenue this month', value: loading ? '—' : Fmt.money(monthRev), icon: Icons.currency_rupee_rounded, trend: loading ? null : _pct(monthRev, prevMonthRev)),
                KpiCard(label: 'Wallet balance', value: Fmt.money(session.profile?.n('balance') ?? 0), icon: Icons.account_balance_wallet_rounded, color: G4MColors.success, onTap: () => context.go('/finance/earnings')),
                KpiCard(label: 'Products', value: ps.hasData ? '${products.length}' : '—', icon: Icons.inventory_2_rounded, color: const Color(0xFF7C3AED), caption: ps.hasData ? '${products.where((p) => p.s('status') == 'pending').length} pending approval' : null, onTap: () => context.go('/catalog/products')),
                KpiCard(label: 'Sold out', value: ps.hasData ? '${out.length}' : '—', icon: Icons.remove_shopping_cart_rounded, color: G4MColors.danger, onTap: () => context.go('/catalog/stock')),
                KpiCard(label: 'Low stock', value: ps.hasData ? '${low.length}' : '—', icon: Icons.warning_amber_rounded, color: G4MColors.warning, onTap: () => context.go('/catalog/stock')),
              ];

              Widget row(List<(int, Widget)> c) => wide
                  ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      for (var i = 0; i < c.length; i++) ...[if (i > 0) const SizedBox(width: 18), Expanded(flex: c[i].$1, child: c[i].$2)],
                    ])
                  : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      for (var i = 0; i < c.length; i++) ...[if (i > 0) const SizedBox(height: 18), c[i].$2],
                    ]);

              return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                if (os.hasError) ...[SectionCard(child: ErrorBox(os.error!)), const SizedBox(height: 16)],
                if (session.profile?.b('policiesAccepted') == false) ...[
                  _banner(context, Icons.policy_outlined, 'Please review and accept the seller policies in Store settings.', '/store'),
                  const SizedBox(height: 16),
                ],
                ResponsiveGrid(minItemWidth: 180, spacing: 14, children: [
                  for (var i = 0; i < kpis.length; i++) kpis[i].animate(delay: (45 * i).ms).fadeIn(duration: 300.ms).slideY(begin: .1),
                ]),
                const SizedBox(height: 18),
                row([
                  (
                    3,
                    SectionCard(
                      title: 'Sales',
                      icon: Icons.insights_rounded,
                      trailing: Segmented<bool>(value: _revenue, options: const {true: 'Revenue', false: 'Orders'}, onChanged: (v) => setState(() => _revenue = v)),
                      child: loading ? const Shimmer(height: 240) : SeriesChart(points: points, money: _revenue, line: days == 30, color: G4MColors.accent),
                    )
                  ),
                  (
                    2,
                    SectionCard(
                      title: 'Order status',
                      subtitle: 'Last $days days',
                      icon: Icons.donut_large_rounded,
                      child: loading
                          ? const Shimmer(height: 200)
                          : DonutChart(slices: [
                              for (final e in byStatus.entries.toList()..sort((a, b) => b.value.compareTo(a.value))) (OrderStatus.label(e.key), e.value, orderStatusColor(e.key)),
                            ]),
                    )
                  ),
                ]),
                const SizedBox(height: 18),
                row([
                  (3, _recent(context, orders, loading)),
                  (
                    2,
                    Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      SectionCard(
                        title: 'Top products',
                        icon: Icons.local_fire_department_rounded,
                        child: !ps.hasData
                            ? const LoadingBlock(rows: 4)
                            : RankBars(
                                rows: [
                                  for (final p in ([...products]..sort((a, b) => b.n('soldCount').compareTo(a.n('soldCount')))).where((p) => p.n('soldCount') > 0).take(5))
                                    (p.s('name'), p.n('soldCount'), Fmt.money(p.n('price'))),
                                ],
                                color: G4MColors.accent,
                              ),
                      ),
                      const SizedBox(height: 18),
                      _lowStock(context, [...out, ...low], ps.hasData),
                    ]),
                  ),
                ]),
              ]);
            },
          ),
        ),
      ),
    );
  }

  double _pct(double cur, double prev) => prev <= 0 ? (cur > 0 ? 100 : 0) : (cur - prev) / prev * 100;

  double _stockOf(Doc p) {
    final v = p['variants'];
    if (v is List && v.isNotEmpty) return v.fold<double>(0, (a, e) => a + (e is Map ? toNum(e['stock']) : 0));
    return p.n('stock');
  }

  Widget _banner(BuildContext context, IconData icon, String text, String path) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: G4MColors.warning.withValues(alpha: .1), borderRadius: BorderRadius.circular(12), border: Border.all(color: G4MColors.warning.withValues(alpha: .3))),
        child: Row(children: [
          Icon(icon, color: G4MColors.warning),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600))),
          TextButton(onPressed: () => context.go(path), child: Text(tr('Open'))),
        ]),
      );

  Widget _recent(BuildContext context, List<ShopOrder> orders, bool loading) => SectionCard(
        title: 'Recent orders',
        icon: Icons.receipt_long_rounded,
        trailing: TextButton(onPressed: () => context.go('/orders'), child: Text(tr('All orders'))),
        child: loading
            ? const LoadingBlock(rows: 5)
            : orders.isEmpty
                ? const EmptyState(icon: Icons.receipt_long_outlined, title: 'No orders yet', message: 'New orders for your products appear here instantly.')
                : Column(children: [
                    for (final o in orders.take(8))
                      InkWell(
                        onTap: () => context.go('/orders/${o.id}'),
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
                          child: Row(children: [
                            Avatar(name: o.customerName, size: 34, color: G4MColors.accent),
                            const SizedBox(width: 12),
                            Expanded(child: TwoLine(o.orderNo, '${o.customerName} · ${Fmt.ago(o.createdAt)}')),
                            orderStatusPill(o.status),
                            const SizedBox(width: 12),
                            SizedBox(width: 80, child: Text(Fmt.money(sellerSubtotal(o, session.uid)), textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.w800))),
                          ]),
                        ),
                      ),
                  ]),
      );

  Widget _lowStock(BuildContext context, List<Doc> items, bool ready) => SectionCard(
        title: 'Needs restocking',
        icon: Icons.warehouse_rounded,
        trailing: TextButton(onPressed: () => context.go('/catalog/stock'), child: Text(tr('Manage stock'))),
        child: !ready
            ? const LoadingBlock(rows: 3)
            : items.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(children: [
                      const Icon(Icons.check_circle_rounded, color: G4MColors.success),
                      const SizedBox(width: 10),
                      Text('All products are well stocked', style: TextStyle(color: context.pal.muted)),
                    ]),
                  )
                : Column(children: [
                    for (final p in items.take(6))
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(children: [
                          RowThumb(p.list('images').isEmpty ? '' : p.list('images').first, size: 36),
                          const SizedBox(width: 10),
                          Expanded(child: Text(p.s('name'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600))),
                          Tag(_stockOf(p) <= 0 ? 'Sold out' : '${_stockOf(p).toInt()} left', color: _stockOf(p) <= 0 ? G4MColors.danger : G4MColors.warning),
                        ]),
                      ),
                  ]),
      );
}
