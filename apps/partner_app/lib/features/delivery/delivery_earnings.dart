import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:g4m_core/g4m_core.dart';
import 'package:intl/intl.dart';

import '../../core/app_state.dart';
import '../../core/l10n.dart';
import '../../core/live.dart';
import '../../core/motion.dart';
import '../../core/partner_theme.dart';
import '../../core/ui.dart';
import '../common/withdrawals_screen.dart';
import 'delivery_data.dart';
import 'delivery_widgets.dart';

class DeliveryEarningsTab extends StatefulWidget {
  const DeliveryEarningsTab({super.key});
  @override
  State<DeliveryEarningsTab> createState() => _DeliveryEarningsTabState();
}

class _DeliveryEarningsTabState extends State<DeliveryEarningsTab> {
  late final Stream<DeliveryPartner?> _me = DeliveryData.me();
  late final Stream<List<ShopOrder>> _orders = DeliveryData.myOrders();
  late final Stream<List<WalletTxn>> _txns = DeliveryData.walletTxns();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.s.earnings)),
      body: StreamBuilder<DeliveryPartner?>(
        stream: _me,
        builder: (context, meSnap) {
          final me = meSnap.data;
          return StreamBuilder<List<ShopOrder>>(
            stream: _orders,
            builder: (context, oSnap) {
              final delivered = (oSnap.data ?? const <ShopOrder>[]).where((o) => o.status == OrderStatus.delivered).toList();
              final now = DateTime.now();
              final weekStart = dayStart(now).subtract(const Duration(days: 6));
              bool inWeek(ShopOrder o) => !(deliveredAt(o) ?? DateTime(2000)).isBefore(weekStart);
              final today = delivered.where((o) => isToday(deliveredAt(o))).toList();
              final week = delivered.where(inWeek).toList();
              double sum(List<ShopOrder> l) => l.fold(0, (a, o) => a + orderEarning(o, me));
              final perOrder = isPerOrder(me);
              final salary = me?.data['salary'];
              return ListView(padding: pagePad, children: [
                HeroPanel(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(context.s.balance, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    AnimatedCounter(me?.balance ?? 0, money: true, style: context.tt.displaySmall?.copyWith(color: Colors.white)),
                    const SizedBox(height: 14),
                    Row(children: [
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: G4MColors.primaryDeep),
                          icon: const Icon(Icons.north_east_rounded, size: 18),
                          label: Text(context.s.withdrawals),
                          onPressed: () => Go.push(context, WithdrawalsScreen(role: PartnerRole.delivery, balance: DeliveryData.balance())),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white54)),
                          icon: const Icon(Icons.payments_rounded, size: 18),
                          label: Text(context.tr('Cash', 'नकद')),
                          onPressed: () => Go.push(context, const CashCollectionScreen()),
                        ),
                      ),
                    ]),
                  ]),
                ).popIn(),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(child: _period(context, context.s.today, today.length, sum(today)).stagger(0)),
                  const SizedBox(width: 10),
                  Expanded(child: _period(context, context.tr('7 days', '7 दिन'), week.length, sum(week)).stagger(1)),
                  const SizedBox(width: 10),
                  Expanded(child: _period(context, context.tr('All time', 'कुल'), me?.completedCount ?? delivered.length, sum(delivered)).stagger(2)),
                ]),
                const SizedBox(height: 16),
                AppCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(perOrder ? context.tr('Earnings · last 7 days', 'कमाई · पिछले 7 दिन') : context.tr('Deliveries · last 7 days', 'डिलीवरी · पिछले 7 दिन'),
                        style: context.tt.titleSmall),
                    const SizedBox(height: 16),
                    SizedBox(height: 180, child: _WeekChart(orders: week, partner: me, money: perOrder)),
                  ]),
                ).stagger(3),
                const SizedBox(height: 12),
                AppCard(
                  child: Row(children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(color: context.rc.brandSoft, borderRadius: BorderRadius.circular(12)),
                      child: Icon(Icons.badge_rounded, color: context.rc.brand),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(context.tr('Pay structure', 'भुगतान संरचना'), style: context.tt.titleSmall),
                        Text(
                          salary is Map
                              ? (salary['type'] == 'monthly'
                                  ? '${context.tr('Monthly salary', 'मासिक वेतन')} ${Fmt.money(asNum(salary['amount']))}'
                                  : '${Fmt.money(asNum(salary['amount']))} ${context.tr('per delivered order', 'प्रति डिलीवर ऑर्डर')}')
                              : context.tr('Set by Go4Market. Contact support for details.', 'Go4Market द्वारा निर्धारित। विवरण के लिए सहायता से संपर्क करें।'),
                          style: context.tt.bodySmall,
                        ),
                      ]),
                    ),
                  ]),
                ).stagger(4),
                const SizedBox(height: 8),
                StreamBuilder<List<WalletTxn>>(
                  stream: _txns,
                  builder: (context, t) {
                    final list = t.data ?? const <WalletTxn>[];
                    if (t.hasError || list.isEmpty) return const SizedBox.shrink();
                    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      SectionTitle(context.tr('Transactions', 'लेनदेन')),
                      for (var i = 0; i < list.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: AppCard(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            child: Row(children: [
                              Icon(list[i].isCredit ? Icons.south_west_rounded : Icons.north_east_rounded,
                                  color: list[i].isCredit ? G4MColors.success : G4MColors.danger),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(Fmt.titleCase(list[i].reason.isEmpty ? list[i].type : list[i].reason), style: context.tt.titleSmall),
                                  Text(Fmt.dateTime(list[i].createdAt), style: context.tt.bodySmall),
                                ]),
                              ),
                              Text('${list[i].isCredit ? '+' : '-'}${Fmt.money(list[i].amount)}',
                                  style: context.tt.titleSmall?.copyWith(color: list[i].isCredit ? G4MColors.success : G4MColors.danger)),
                            ]),
                          ).stagger(i),
                        ),
                    ]);
                  },
                ),
              ]);
            },
          );
        },
      ),
    );
  }

  Widget _period(BuildContext context, String label, int count, double earned) => AppCard(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: context.tt.bodySmall),
          const SizedBox(height: 4),
          AnimatedCounter(earned, money: true, compact: true, style: context.tt.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          Text('$count ${context.tr('orders', 'ऑर्डर')}', style: context.tt.bodySmall),
        ]),
      );
}

class _WeekChart extends StatelessWidget {
  const _WeekChart({required this.orders, required this.partner, required this.money});
  final List<ShopOrder> orders;
  final DeliveryPartner? partner;
  final bool money;

  @override
  Widget build(BuildContext context) {
    final today = dayStart(DateTime.now());
    final days = List.generate(7, (i) => today.subtract(Duration(days: 6 - i)));
    final values = [
      for (final d in days)
        orders
            .where((o) => dayStart(deliveredAt(o) ?? DateTime(2000)) == d)
            .fold<double>(0, (a, o) => a + (money ? orderEarning(o, partner) : 1)),
    ];
    final maxV = values.fold<double>(0, (a, b) => b > a ? b : a);
    return BarChart(
      BarChartData(
        maxY: maxV <= 0 ? 4 : maxV * 1.25,
        alignment: BarChartAlignment.spaceAround,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(color: context.rc.line, strokeWidth: 1, dashArray: [4, 4]),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: const AxisTitles(),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              getTitlesWidget: (v, meta) => SideTitleWidget(
                meta: meta,
                child: Text(DateFormat.E().format(days[v.toInt()]).substring(0, 2), style: context.tt.bodySmall),
              ),
            ),
          ),
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => G4MColors.primaryDeep,
            getTooltipItem: (g, _, rod, _) => BarTooltipItem(
              money ? Fmt.money(rod.toY) : '${rod.toY.round()}',
              const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < 7; i++)
            BarChartGroupData(x: i, barRods: [
              BarChartRodData(
                toY: values[i],
                width: 18,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: i == 6 ? [G4MColors.accent, const Color(0xFFFFB45C)] : [G4MColors.primaryDeep, G4MColors.primary],
                ),
                backDrawRodData: BackgroundBarChartRodData(show: true, toY: maxV <= 0 ? 4 : maxV * 1.25, color: context.rc.cardAlt),
              ),
            ]),
        ],
      ),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
    );
  }
}

/// Cash in hand and the list of COD collections (settled by admin via settleCash).
class CashCollectionScreen extends StatefulWidget {
  const CashCollectionScreen({super.key});
  @override
  State<CashCollectionScreen> createState() => _CashCollectionScreenState();
}

class _CashCollectionScreenState extends State<CashCollectionScreen> {
  late final Stream<DeliveryPartner?> _me = DeliveryData.me();
  late final Stream<List<Json>> _cash = DeliveryData.cashCollections();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Cash collection', 'नकद संग्रह'))),
      body: StreamBuilder<DeliveryPartner?>(
        stream: _me,
        builder: (context, meSnap) => StreamBuilder<List<Json>>(
          stream: _cash,
          builder: (context, snap) {
            final list = snap.data ?? const <Json>[];
            final collected = list.where((c) => c['status'] != 'settled').fold<double>(0, (a, c) => a + asNum(c['amount']));
            final settled = list.where((c) => c['status'] == 'settled').fold<double>(0, (a, c) => a + asNum(c['amount']));
            return ListView(padding: pagePad, children: [
              HeroPanel(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(context.s.cashInHand, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  AnimatedCounter(meSnap.data?.cashInHand ?? collected, money: true, style: context.tt.displaySmall?.copyWith(color: Colors.white)),
                  const SizedBox(height: 14),
                  Row(children: [
                    _mini(context.tr('Unsettled', 'असेटल्ड'), collected),
                    const SizedBox(width: 24),
                    _mini(context.tr('Settled', 'सेटल्ड'), settled),
                  ]),
                ]),
              ).popIn(),
              const SizedBox(height: 12),
              AppCard(
                color: context.rc.highlightSoft,
                child: Row(children: [
                  Icon(Icons.info_outline_rounded, color: context.rc.brand),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      context.tr('Hand over collected cash to the Go4Market team. Settlements are recorded by the admin and appear here.',
                          'एकत्रित नकद Go4Market टीम को सौंपें। सेटलमेंट एडमिन द्वारा दर्ज होते हैं और यहां दिखते हैं।'),
                      style: context.tt.bodySmall,
                    ),
                  ),
                ]),
              ),
              SectionTitle(context.tr('Collections', 'संग्रह')),
              if (snap.hasError)
                SizedBox(height: 240, child: ErrorView(snap.error!))
              else if (!snap.hasData)
                const SizedBox(height: 280, child: SkeletonList(count: 3, itemHeight: 70, padding: EdgeInsets.zero))
              else if (list.isEmpty)
                SizedBox(
                  height: 240,
                  child: AppEmpty(
                    icon: Icons.payments_outlined,
                    title: context.tr('No cash collected yet', 'अभी कोई नकद नहीं'),
                    message: context.tr('COD deliveries will be recorded here.', 'COD डिलीवरी यहां दर्ज होंगी।'),
                  ),
                )
              else
                for (var i = 0; i < list.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: AppCard(
                      child: Row(children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(color: statusColor('${list[i]['status']}').withValues(alpha: .12), borderRadius: BorderRadius.circular(12)),
                          child: Icon(Icons.payments_rounded, color: statusColor('${list[i]['status']}')),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(Fmt.money(asNum(list[i]['amount'])), style: context.tt.titleMedium),
                            Text(
                              '${context.tr('Order', 'ऑर्डर')} ${'${list[i]['orderNo'] ?? list[i]['orderId'] ?? ''}'.toUpperCase()} · ${Fmt.dateTime(asDate(list[i]['createdAt']))}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.tt.bodySmall,
                            ),
                          ]),
                        ),
                        InfoChip(
                          icon: list[i]['status'] == 'settled' ? Icons.check_circle_rounded : Icons.schedule_rounded,
                          label: Fmt.titleCase('${list[i]['status'] ?? 'collected'}'),
                          color: list[i]['status'] == 'settled' ? G4MColors.success : G4MColors.warning,
                        ),
                      ]),
                    ).stagger(i),
                  ),
            ]);
          },
        ),
      ),
    );
  }

  Widget _mini(String label, double v) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        AnimatedCounter(v, money: true, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
      ]);
}
