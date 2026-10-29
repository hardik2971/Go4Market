import 'package:flutter/material.dart';
import 'package:g4m_core/g4m_core.dart';

import '../../core/l10n.dart';
import '../../core/live.dart';
import '../../core/motion.dart';
import '../../core/partner_theme.dart';
import '../../core/ui.dart';
import 'active_delivery_screen.dart';
import 'delivery_data.dart';
import 'delivery_widgets.dart';

/// Finished deliveries (delivered / cancelled / returned), grouped by day.
class DeliveryHistoryTab extends StatefulWidget {
  const DeliveryHistoryTab({super.key});
  @override
  State<DeliveryHistoryTab> createState() => _DeliveryHistoryTabState();
}

class _DeliveryHistoryTabState extends State<DeliveryHistoryTab> {
  late final Stream<List<ShopOrder>> _orders = DeliveryData.myOrders();
  late final Stream<DeliveryPartner?> _me = DeliveryData.me();
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.s.history)),
      body: StreamBuilder<DeliveryPartner?>(
        stream: _me,
        builder: (context, meSnap) => LiveList<List<ShopOrder>>(
          stream: _orders,
          isEmpty: (l) => !l.any((o) => OrderStatus.terminal.contains(o.status)),
          empty: AppEmpty(
            icon: Icons.history_rounded,
            title: context.tr('No deliveries yet', 'अभी कोई डिलीवरी नहीं'),
            message: context.tr('Completed deliveries will be listed here.', 'पूरी हुई डिलीवरी यहां दिखेंगी।'),
          ),
          builder: (context, all) {
            final done = all.where((o) => OrderStatus.terminal.contains(o.status)).toList();
            final shown = _filter == 'all' ? done : done.where((o) => o.status == _filter).toList();
            final delivered = done.where((o) => o.status == OrderStatus.delivered).toList();
            final earned = delivered.fold<double>(0, (a, o) => a + orderEarning(o, meSnap.data));
            final groups = <DateTime, List<ShopOrder>>{};
            for (final o in shown) {
              final d = dayStart(deliveredAt(o) ?? DateTime(2000));
              groups.putIfAbsent(d, () => []).add(o);
            }
            final days = groups.keys.toList()..sort((a, b) => b.compareTo(a));
            var idx = 0;
            return ListView(padding: pagePad, children: [
              Row(children: [
                Expanded(child: StatTile(icon: Icons.task_alt_rounded, label: context.tr('Delivered', 'डिलीवर'), value: delivered.length, color: G4MColors.success)),
                const SizedBox(width: 12),
                Expanded(child: StatTile(icon: Icons.currency_rupee_rounded, label: context.s.earnings, value: earned, money: true, color: G4MColors.accent)),
              ]).popIn(),
              const SizedBox(height: 14),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  for (final f in const ['all', OrderStatus.delivered, OrderStatus.cancelled, OrderStatus.returned])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(f == 'all' ? context.tr('All', 'सभी') : OrderStatus.label(f)),
                        selected: _filter == f,
                        selectedColor: context.rc.brandSoft,
                        onSelected: (_) => setState(() => _filter = f),
                      ),
                    ),
                ]),
              ),
              const SizedBox(height: 6),
              if (shown.isEmpty)
                SizedBox(height: 240, child: AppEmpty(icon: Icons.filter_alt_off_rounded, title: context.s.noData)),
              for (final d in days) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
                  child: Row(children: [
                    Expanded(
                      child: Text(isToday(d) ? context.s.today : Fmt.date(d),
                          style: context.tt.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                    ),
                    Text(
                      '${groups[d]!.where((o) => o.status == OrderStatus.delivered).length} ${context.tr('delivered', 'डिलीवर')}'
                      ' · ${Fmt.money(groups[d]!.where((o) => o.status == OrderStatus.delivered).fold<double>(0, (a, o) => a + orderEarning(o, meSnap.data)))}',
                      style: context.tt.bodySmall,
                    ),
                  ]),
                ),
                for (final o in groups[d]!)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: DeliveryOrderCard(
                      order: o,
                      onTap: () => Go.push(context, ActiveDeliveryScreen(orderId: o.id)),
                    ).stagger(idx++),
                  ),
              ],
            ]);
          },
        ),
      ),
    );
  }
}
