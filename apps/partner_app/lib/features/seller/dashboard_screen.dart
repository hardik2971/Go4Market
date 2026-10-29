import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:g4m_core/g4m_core.dart';
import 'package:intl/intl.dart';

import '../../core/l10n.dart';
import '../../core/live.dart';
import '../../core/motion.dart';
import '../../core/partner_theme.dart';
import '../../core/ui.dart';
import '../common/notifications_screen.dart';
import 'order_detail_screen.dart';
import 'seller_data.dart';
import 'seller_shell.dart';
import 'seller_store.dart';
import 'seller_widgets.dart';
import 'stock_screen.dart';

class SellerDashboardScreen extends StatelessWidget {
  const SellerDashboardScreen({super.key});

  String _greeting(BuildContext c) {
    final h = DateTime.now().hour;
    if (h < 12) return c.tr('Good morning', 'सुप्रभात');
    if (h < 17) return c.tr('Good afternoon', 'नमस्कार');
    return c.tr('Good evening', 'शुभ संध्या');
  }

  @override
  Widget build(BuildContext context) {
    final store = SellerStore.instance;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: Listenable.merge([store.seller, store.orders, store.products, store.ordersError]),
          builder: (context, _) {
            final seller = store.seller.value;
            final orders = store.orders.value;
            final products = store.products.value ?? const <Product>[];
            final live = (orders ?? const <ShopOrder>[]).where((o) => o.status != OrderStatus.pending).toList();
            final valid = live.where((o) => !SellerTabs.closed.contains(o.status)).toList();
            final today = valid.where((o) => isToday(o.createdAt)).toList();
            final todayRevenue = today.fold<double>(0, (a, o) => a + SellerData.myRevenue(o));
            final lowStock = products.where(SellerData.isLowStock).toList()
              ..sort((a, b) => SellerData.totalStock(a).compareTo(SellerData.totalStock(b)));

            int count(bool Function(ShopOrder) f) => live.where(f).length;
            final counts = <(String, String, int, Color)>[
              (OrderStatus.placed, context.tr('New', 'नए'), count((o) => o.status == OrderStatus.placed), G4MColors.accent),
              (OrderStatus.confirmed, context.tr('Confirmed', 'पुष्ट'), count((o) => o.status == OrderStatus.confirmed), G4MColors.info),
              (OrderStatus.packed, context.tr('Packed', 'पैक'), count((o) => o.status == OrderStatus.packed), const Color(0xFF7C3AED)),
              (OrderStatus.outForDelivery, context.tr('On the way', 'रास्ते में'), count((o) => SellerTabs.inTransit.contains(o.status)), G4MColors.warning),
              (OrderStatus.delivered, context.tr('Delivered', 'डिलीवर'), count((o) => o.status == OrderStatus.delivered), G4MColors.success),
              (OrderStatus.cancelled, context.tr('Cancelled', 'रद्द'), count((o) => SellerTabs.closed.contains(o.status)), G4MColors.danger),
            ];

            return RefreshIndicator(
              onRefresh: () async => await Future<void>.delayed(const Duration(milliseconds: 600)),
              child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
                Row(children: [
                  Avatar(name: seller?.storeName ?? '', url: seller?.logo ?? '', size: 46),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_greeting(context), style: context.tt.bodySmall),
                      Text(seller?.storeName.isNotEmpty == true ? seller!.storeName : context.s.dashboard,
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: context.tt.titleLarge),
                    ]),
                  ),
                  const NotificationBell(),
                ]).stagger(0),
                const SizedBox(height: 16),
                HeroPanel(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Text(context.tr("Today's revenue", 'आज की आय'), style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: .14), borderRadius: BorderRadius.circular(G4MRadius.pill)),
                        child: Text(DateFormat('EEE, d MMM').format(DateTime.now()), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                      ),
                    ]),
                    const SizedBox(height: 6),
                    orders == null
                        ? const Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Shimmer(width: 160, height: 34))
                        : AnimatedCounter(todayRevenue, money: true, style: context.tt.displaySmall?.copyWith(color: Colors.white)),
                    const SizedBox(height: 16),
                    Row(children: [
                      _heroStat(context, context.tr('Orders today', 'आज के ऑर्डर'), today.length, false),
                      _divider(),
                      _heroStat(context, context.s.balance, seller?.balance ?? 0, true),
                      _divider(),
                      _heroStat(context, context.tr('Products', 'उत्पाद'), products.length, false),
                    ]),
                  ]),
                ).popIn(delayMs: 80),
                const SizedBox(height: 20),
                if (store.ordersError.value != null && orders == null)
                  SizedBox(height: 240, child: ErrorView(store.ordersError.value!))
                else ...[
                  SectionTitle(context.tr('Order status', 'ऑर्डर स्थिति'),
                      action: context.tr('View all', 'सभी देखें'), onAction: () => SellerShell.goTab(context, 1)),
                  GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.25,
                    children: [
                      for (var i = 0; i < counts.length; i++)
                        AppCard(
                          padding: const EdgeInsets.all(12),
                          onTap: () => SellerShell.goTab(context, 1),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                            Row(children: [
                              Container(width: 8, height: 8, decoration: BoxDecoration(color: counts[i].$4, shape: BoxShape.circle)),
                              const Spacer(),
                              if (i == 0 && counts[i].$3 > 0) PulseDot(color: counts[i].$4, size: 7),
                            ]),
                            AnimatedCounter(counts[i].$3, style: context.tt.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                            Text(counts[i].$2, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.tt.bodySmall),
                          ]),
                        ).stagger(i + 2),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SectionTitle(context.tr('Sales · last 7 days', 'बिक्री · पिछले 7 दिन')),
                  AppCard(child: SizedBox(height: 200, child: orders == null ? const Shimmer(height: 200) : _SalesChart(orders: valid))).stagger(8),
                ],
                const SizedBox(height: 20),
                SectionTitle(
                  context.tr('Low stock alerts', 'कम स्टॉक अलर्ट'),
                  action: lowStock.isEmpty ? null : context.tr('Manage', 'प्रबंधित करें'),
                  onAction: () => Go.push(context, const StockScreen()),
                ),
                if (lowStock.isEmpty)
                  AppCard(
                    child: Row(children: [
                      const Icon(Icons.verified_rounded, color: G4MColors.success),
                      const SizedBox(width: 12),
                      Expanded(child: Text(context.tr('All products are well stocked', 'सभी उत्पादों का स्टॉक पर्याप्त है'))),
                    ]),
                  ).stagger(9)
                else
                  for (var i = 0; i < lowStock.take(4).length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: AppCard(
                        onTap: () => Go.push(context, const StockScreen()),
                        padding: const EdgeInsets.all(12),
                        child: Row(children: [
                          ProductThumb(lowStock[i].image, size: 44),
                          const SizedBox(width: 12),
                          Expanded(child: Text(lowStock[i].name, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.tt.titleSmall)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: (SellerData.totalStock(lowStock[i]) == 0 ? G4MColors.danger : G4MColors.warning).withValues(alpha: .14),
                              borderRadius: BorderRadius.circular(G4MRadius.pill),
                            ),
                            child: Text(
                              SellerData.totalStock(lowStock[i]) == 0
                                  ? context.tr('Out of stock', 'स्टॉक खत्म')
                                  : '${SellerData.totalStock(lowStock[i])} ${context.tr('left', 'बचे')}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: SellerData.totalStock(lowStock[i]) == 0 ? G4MColors.danger : G4MColors.warning,
                              ),
                            ),
                          ),
                        ]),
                      ).stagger(i + 9),
                    ),
                const SizedBox(height: 20),
                SectionTitle(context.tr('Recent orders', 'हाल के ऑर्डर'),
                    action: context.tr('See all', 'सभी देखें'), onAction: () => SellerShell.goTab(context, 1)),
                if (orders == null)
                  const SizedBox(height: 260, child: SkeletonList(count: 3, padding: EdgeInsets.zero))
                else if (live.isEmpty)
                  AppEmpty(
                    icon: Icons.receipt_long_outlined,
                    title: context.tr('No orders yet', 'अभी कोई ऑर्डर नहीं'),
                    message: context.tr('New orders will appear here instantly.', 'नए ऑर्डर यहां तुरंत दिखेंगे।'),
                  )
                else
                  for (var i = 0; i < live.take(5).length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: SellerOrderCard(
                        order: live[i],
                        onTap: () => Go.push(context, SellerOrderDetailScreen(orderId: live[i].id)),
                      ).stagger(i + 12),
                    ),
              ]),
            );
          },
        ),
      ),
    );
  }

  Widget _divider() => Container(width: 1, height: 34, margin: const EdgeInsets.symmetric(horizontal: 14), color: Colors.white24);

  Widget _heroStat(BuildContext context, String label, num v, bool money) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          AnimatedCounter(v, money: money, compact: true, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ]),
      );
}

class _SalesChart extends StatelessWidget {
  const _SalesChart({required this.orders});
  final List<ShopOrder> orders;

  @override
  Widget build(BuildContext context) {
    final now = dayStart(DateTime.now());
    final days = List.generate(7, (i) => now.subtract(Duration(days: 6 - i)));
    final totals = List<double>.filled(7, 0);
    for (final o in orders) {
      final c = o.createdAt;
      if (c == null) continue;
      final idx = 6 - now.difference(dayStart(c)).inDays;
      if (idx >= 0 && idx < 7) totals[idx] += SellerData.myRevenue(o);
    }
    final maxY = totals.fold<double>(0, (a, b) => b > a ? b : a);
    final top = maxY <= 0 ? 100.0 : maxY * 1.25;
    final rc = context.rc;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1100),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) => BarChart(
        BarChartData(
          maxY: top,
          alignment: BarChartAlignment.spaceAround,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: top / 4,
            getDrawingHorizontalLine: (_) => FlLine(color: rc.line, strokeWidth: 1, dashArray: [4, 4]),
          ),
          borderData: FlBorderData(show: false),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => G4MColors.primaryDeep,
              getTooltipItem: (g, _, rod, _) => BarTooltipItem(
                Fmt.money(totals[g.x]),
                const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
              ),
            ),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 42,
                interval: top / 4,
                getTitlesWidget: (v, meta) => Text(
                  v == 0 ? '0' : Fmt.moneyCompact(v).replaceAll('.00', ''),
                  style: TextStyle(fontSize: 10, color: rc.faint),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                getTitlesWidget: (v, meta) {
                  final i = v.toInt();
                  if (i < 0 || i > 6) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      DateFormat('E').format(days[i]),
                      style: TextStyle(fontSize: 11, color: i == 6 ? rc.ink : rc.muted, fontWeight: i == 6 ? FontWeight.w800 : FontWeight.w500),
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < 7; i++)
              BarChartGroupData(x: i, barRods: [
                BarChartRodData(
                  toY: totals[i] * t,
                  width: 18,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: i == 6 ? [G4MColors.accent, const Color(0xFFFFB25C)] : [rc.brandDeep, rc.brand],
                  ),
                  backDrawRodData: BackgroundBarChartRodData(show: true, toY: top, color: rc.cardAlt),
                ),
              ]),
          ],
        ),
      ),
    );
  }
}
