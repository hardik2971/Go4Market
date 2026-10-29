import 'package:flutter/material.dart';
import 'package:g4m_core/g4m_core.dart';

import '../../core/l10n.dart';
import '../../core/live.dart';
import '../../core/location_service.dart';
import '../../core/motion.dart';
import '../../core/ui.dart';
import 'active_delivery_screen.dart';
import 'delivery_data.dart';
import 'delivery_widgets.dart';

/// Active deliveries + the available pool of packed orders.
class DeliveryOrdersTab extends StatefulWidget {
  const DeliveryOrdersTab({super.key});
  @override
  State<DeliveryOrdersTab> createState() => _DeliveryOrdersTabState();
}

class _DeliveryOrdersTabState extends State<DeliveryOrdersTab> {
  int _seg = 0;
  late Stream<List<ShopOrder>> _mine = DeliveryData.myOrders();
  late Stream<List<ShopOrder>> _pool = DeliveryData.pool();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.s.orders)),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<int>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: 0, icon: const Icon(Icons.route_rounded), label: Text(context.tr('Active', 'सक्रिय'))),
                ButtonSegment(value: 1, icon: const Icon(Icons.inventory_rounded), label: Text(context.tr('Available', 'उपलब्ध'))),
              ],
              selected: {_seg},
              onSelectionChanged: (s) => setState(() {
                _seg = s.first;
                // Fresh subscriptions: the switcher disposes the old list.
                if (_seg == 0) {
                  _mine = DeliveryData.myOrders();
                } else {
                  _pool = DeliveryData.pool();
                }
              }),
            ),
          ),
        ),
        Expanded(
          child: AnimatedSwitcher(
            duration: G4MMotion.emphasized,
            transitionBuilder: (c, a) => FadeTransition(
              opacity: a,
              child: SlideTransition(position: Tween(begin: const Offset(0, .03), end: Offset.zero).animate(a), child: c),
            ),
            child: _seg == 0 ? KeyedSubtree(key: const ValueKey(0), child: _active()) : KeyedSubtree(key: const ValueKey(1), child: _available()),
          ),
        ),
      ]),
    );
  }

  Widget _active() => LiveList<List<ShopOrder>>(
        stream: _mine,
        isEmpty: (l) => !l.any((o) => activeDeliveryStatuses.contains(o.status)),
        empty: AppEmpty(
          icon: Icons.delivery_dining_outlined,
          title: context.tr('No active deliveries', 'कोई सक्रिय डिलीवरी नहीं'),
          message: context.tr('Accept an order from Available, or wait for one to be assigned.', 'उपलब्ध से ऑर्डर स्वीकार करें या असाइन होने की प्रतीक्षा करें।'),
          action: OutlinedButton(onPressed: () => setState(() {
            _seg = 1;
            _pool = DeliveryData.pool();
          }), child: Text(context.tr('See available', 'उपलब्ध देखें'))),
        ),
        builder: (context, all) {
          final list = all.where((o) => activeDeliveryStatuses.contains(o.status)).toList();
          return ListView.separated(
            padding: pagePad,
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, i) => DeliveryOrderCard(
              order: list[i],
              highlight: i == 0,
              onTap: () => Go.push(context, ActiveDeliveryScreen(orderId: list[i].id)),
            ).stagger(i),
          );
        },
      );

  Widget _available() => StreamBuilder<List<ShopOrder>>(
        stream: _pool,
        builder: (context, snap) {
          if (snap.hasError) {
            final denied = snap.error.toString().contains('permission-denied');
            return AppEmpty(
              icon: denied ? Icons.assignment_ind_outlined : Icons.cloud_off_rounded,
              title: denied ? context.tr('Orders come to you', 'ऑर्डर आप तक आएंगे') : context.s.somethingWrong,
              message: denied
                  ? context.tr('New orders will be assigned to you automatically while you are online.', 'ऑनलाइन रहने पर नए ऑर्डर अपने आप आपको असाइन होंगे।')
                  : describeError(snap.error!),
              action: OutlinedButton(onPressed: () => setState(() => _pool = DeliveryData.pool()), child: Text(context.s.retry)),
            );
          }
          if (!snap.hasData) return const SkeletonList(itemHeight: 130);
          return ListenableBuilder(
            listenable: LocationService.instance,
            builder: (context, _) {
              final me = myLatLng();
              final online = LocationService.instance.running;
              final list = [...snap.data!]
                ..sort((a, b) => (kmBetween(me, orderLatLng(a)) ?? 9999).compareTo(kmBetween(me, orderLatLng(b)) ?? 9999));
              if (list.isEmpty) {
                return AppEmpty(
                  icon: Icons.inbox_outlined,
                  title: context.tr('No orders right now', 'अभी कोई ऑर्डर नहीं'),
                  message: context.tr('Packed orders near you will appear here instantly.', 'आपके पास पैक ऑर्डर यहां तुरंत दिखेंगे।'),
                );
              }
              return ListView(padding: pagePad, children: [
                if (!online)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: AppCard(
                      color: G4MColors.warning.withValues(alpha: .1),
                      borderColor: G4MColors.warning.withValues(alpha: .4),
                      child: Row(children: [
                        const Icon(Icons.info_outline_rounded, color: G4MColors.warning),
                        const SizedBox(width: 10),
                        Expanded(child: Text(context.tr('Go online from Home to accept orders.', 'ऑर्डर स्वीकार करने के लिए होम से ऑनलाइन जाएं।'))),
                      ]),
                    ),
                  ),
                for (var i = 0; i < list.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: DeliveryOrderCard(
                      order: list[i],
                      distanceKm: kmBetween(me, orderLatLng(list[i])),
                      trailing: InfoChip(icon: Icons.schedule_rounded, label: Fmt.ago(list[i].createdAt), color: G4MColors.info),
                      onTap: () => Go.push(context, ActiveDeliveryScreen(orderId: list[i].id)),
                      footer: Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            icon: const Icon(Icons.check_rounded),
                            label: Text(context.tr('Accept delivery', 'डिलीवरी स्वीकार करें')),
                            onPressed: !online ? null : () => acceptOrder(context, list[i].id),
                          ),
                        ),
                      ),
                    ).stagger(i),
                  ),
              ]);
            },
          );
        },
      );
}

/// Self-assign via `acceptDelivery`, then open the live delivery screen.
Future<void> acceptOrder(BuildContext context, String orderId) async {
  final r = await runBusy(context, () => G4MApi.instance.acceptDelivery(orderId));
  if (r == null || !context.mounted) return;
  toast(context, context.tr('Order accepted. Head to the store!', 'ऑर्डर स्वीकार। स्टोर की ओर चलें!'), icon: Icons.delivery_dining_rounded);
  await Go.push(context, ActiveDeliveryScreen(orderId: orderId));
}
