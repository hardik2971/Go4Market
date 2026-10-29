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
import 'order_detail_screen.dart';
import 'seller_data.dart';
import 'seller_store.dart';

class SellerEarningsScreen extends StatefulWidget {
  const SellerEarningsScreen({super.key});
  @override
  State<SellerEarningsScreen> createState() => _SellerEarningsScreenState();
}

class _SellerEarningsScreenState extends State<SellerEarningsScreen> {
  late final Stream<List<WalletTxn>> _txns = resilientQuery<WalletTxn>(
    [
      () => Fs.walletTransactions.where('userId', isEqualTo: myUid).orderBy('createdAt', descending: true).limit(50),
      () => Fs.walletTransactions.where('userId', isEqualTo: myUid).limit(50),
    ],
    WalletTxn.fromDoc,
    sort: (a, b) => newestFirst(a.createdAt, b.createdAt),
  );
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    SellerStore.instance.start();
  }

  @override
  void dispose() {
    SellerStore.instance.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = SellerStore.instance;
    return Scaffold(
      appBar: AppBar(title: Text(context.s.earnings)),
      body: ListenableBuilder(
        listenable: Listenable.merge([store.seller, store.orders]),
        builder: (context, _) {
          final s = store.seller.value;
          final commission = s?.commissionPct ?? 10;
          final delivered = (store.orders.value ?? const <ShopOrder>[]).where((o) => o.status == OrderStatus.delivered).toList();
          double net(ShopOrder o) => SellerData.myRevenue(o) * (1 - commission / 100);
          final totalNet = delivered.fold<double>(0, (a, o) => a + net(o));
          final monthStart = DateTime(DateTime.now().year, DateTime.now().month);
          final month = delivered.where((o) => o.createdAt != null && !o.createdAt!.isBefore(monthStart)).fold<double>(0, (a, o) => a + net(o));
          final byDay = <DateTime, List<ShopOrder>>{};
          for (final o in delivered) {
            byDay.putIfAbsent(dayStart(o.createdAt ?? DateTime(2000)), () => []).add(o);
          }
          final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));

          return ListView(padding: pagePad, children: [
            HeroPanel(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(context.tr('Withdrawable balance', 'निकासी योग्य बैलेंस'), style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                AnimatedCounter(s?.balance ?? 0, money: true, style: context.tt.displaySmall?.copyWith(color: Colors.white)),
                const SizedBox(height: 14),
                Row(children: [
                  _mini(context.tr('Total sales', 'कुल बिक्री'), s?.totalSales ?? 0),
                  const SizedBox(width: 22),
                  _mini(context.tr('This month (net)', 'इस माह (शुद्ध)'), month),
                ]),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: G4MColors.primaryDeep),
                    icon: const Icon(Icons.account_balance_wallet_rounded),
                    label: Text(context.s.withdrawals),
                    onPressed: () => Go.push(context, WithdrawalsScreen(role: PartnerRole.seller, balance: SellerData.balance())),
                  ),
                ),
              ]),
            ).popIn(),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: StatTile(icon: Icons.check_circle_rounded, label: context.tr('Delivered orders', 'डिलीवर ऑर्डर'), value: delivered.length, color: G4MColors.success)),
              const SizedBox(width: 10),
              Expanded(child: StatTile(icon: Icons.savings_rounded, label: context.tr('Net earnings', 'शुद्ध कमाई'), value: totalNet, money: true)),
              const SizedBox(width: 10),
              Expanded(child: StatTile(icon: Icons.percent_rounded, label: context.tr('Commission', 'कमीशन'), value: commission, color: G4MColors.accent)),
            ]).stagger(1),
            const SizedBox(height: 16),
            SegmentedButton<int>(
              segments: [
                ButtonSegment(value: 0, label: Text(context.tr('Order earnings', 'ऑर्डर कमाई'))),
                ButtonSegment(value: 1, label: Text(context.tr('Transactions', 'लेनदेन'))),
              ],
              selected: {_tab},
              onSelectionChanged: (v) => setState(() => _tab = v.first),
            ),
            const SizedBox(height: 12),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _tab == 0
                  ? Column(key: const ValueKey(0), children: [
                      if (store.orders.value == null)
                        const SizedBox(height: 200, child: SkeletonList(count: 3, padding: EdgeInsets.zero))
                      else if (days.isEmpty)
                        SizedBox(height: 240, child: AppEmpty(icon: Icons.insights_rounded, title: context.tr('No delivered orders yet', 'अभी कोई डिलीवर ऑर्डर नहीं')))
                      else
                        for (var i = 0; i < days.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: AppCard(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                              child: Column(children: [
                                Row(children: [
                                  Text(DateFormat('EEE, d MMM').format(days[i]), style: context.tt.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                                  const Spacer(),
                                  Text(Fmt.money(byDay[days[i]]!.fold<double>(0, (a, o) => a + net(o))),
                                      style: context.tt.titleSmall?.copyWith(fontWeight: FontWeight.w800, color: G4MColors.success)),
                                ]),
                                const Divider(height: 16),
                                for (final o in byDay[days[i]]!)
                                  InkWell(
                                    onTap: () => Go.push(context, SellerOrderDetailScreen(orderId: o.id)),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 5),
                                      child: Row(children: [
                                        Text('#${o.orderNo}', style: context.tt.bodyMedium),
                                        const SizedBox(width: 8),
                                        Text('${Fmt.money(SellerData.myRevenue(o))} − ${commission.toStringAsFixed(0)}%', style: context.tt.bodySmall),
                                        const Spacer(),
                                        Text(Fmt.money(net(o)), style: context.tt.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                                      ]),
                                    ),
                                  ),
                              ]),
                            ).stagger(i),
                          ),
                    ])
                  : StreamBuilder<List<WalletTxn>>(
                      key: const ValueKey(1),
                      stream: _txns,
                      builder: (context, snap) {
                        if (snap.hasError) {
                          return SizedBox(
                            height: 220,
                            child: AppEmpty(
                              icon: Icons.receipt_long_outlined,
                              title: context.tr('Transactions unavailable', 'लेनदेन उपलब्ध नहीं'),
                              message: describeError(snap.error!),
                            ),
                          );
                        }
                        if (!snap.hasData) return const SizedBox(height: 200, child: SkeletonList(count: 3, padding: EdgeInsets.zero));
                        final list = snap.data!;
                        if (list.isEmpty) {
                          return SizedBox(height: 220, child: AppEmpty(icon: Icons.receipt_long_outlined, title: context.tr('No transactions yet', 'अभी कोई लेनदेन नहीं')));
                        }
                        return Column(children: [
                          for (var i = 0; i < list.length; i++)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: AppCard(
                                padding: const EdgeInsets.all(12),
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
                                  Text('${list[i].isCredit ? '+' : '−'}${Fmt.money(list[i].amount)}',
                                      style: context.tt.titleSmall?.copyWith(fontWeight: FontWeight.w800, color: list[i].isCredit ? G4MColors.success : G4MColors.danger)),
                                ]),
                              ).stagger(i),
                            ),
                        ]);
                      },
                    ),
            ),
          ]);
        },
      ),
    );
  }

  Widget _mini(String label, double v) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        AnimatedCounter(v, money: true, compact: true, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
      ]);
}
