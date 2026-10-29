import 'package:flutter/material.dart';
import 'package:g4m_core/g4m_core.dart';

import '../../core/l10n.dart';
import '../../core/motion.dart';
import '../../core/partner_theme.dart';
import '../../core/ui.dart';
import 'order_detail_screen.dart';
import 'seller_data.dart';
import 'seller_store.dart';
import 'seller_widgets.dart';

class SellerOrdersScreen extends StatefulWidget {
  const SellerOrdersScreen({super.key});
  @override
  State<SellerOrdersScreen> createState() => _SellerOrdersScreenState();
}

class _SellerOrdersScreenState extends State<SellerOrdersScreen> {
  String _q = '';
  bool _searching = false;

  List<(String, bool Function(ShopOrder))> _tabs(BuildContext c) => [
        (c.tr('New', 'नए'), (o) => o.status == OrderStatus.placed),
        (c.tr('Confirmed', 'पुष्ट'), (o) => o.status == OrderStatus.confirmed),
        (c.tr('Packed', 'पैक'), (o) => o.status == OrderStatus.packed),
        (c.tr('Ready / Out', 'तैयार / रास्ते में'), (o) => SellerTabs.inTransit.contains(o.status)),
        (c.tr('Delivered', 'डिलीवर'), (o) => o.status == OrderStatus.delivered),
        (c.tr('Cancelled', 'रद्द'), (o) => SellerTabs.closed.contains(o.status)),
        (c.tr('All', 'सभी'), (o) => o.status != OrderStatus.pending),
      ];

  @override
  Widget build(BuildContext context) {
    final tabs = _tabs(context);
    final store = SellerStore.instance;
    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: AnimatedSwitcher(
            duration: G4MMotion.standard,
            child: _searching
                ? TextField(
                    key: const ValueKey('s'),
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: context.tr('Order no. or customer', 'ऑर्डर नं. या ग्राहक'),
                      isDense: true,
                    ),
                    onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
                  )
                : Text(context.s.orders, key: const ValueKey('t')),
          ),
          actions: [
            IconButton(
              icon: Icon(_searching ? Icons.close_rounded : Icons.search_rounded),
              onPressed: () => setState(() {
                _searching = !_searching;
                if (!_searching) _q = '';
              }),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(46),
            child: ValueListenableBuilder<List<ShopOrder>?>(
              valueListenable: store.orders,
              builder: (context, orders, _) => TabBar(
                isScrollable: true,
                tabs: [
                  for (final t in tabs)
                    Tab(
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(t.$1),
                        if (orders != null && orders.where(t.$2).isNotEmpty && t != tabs.last) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                            decoration: BoxDecoration(
                              color: t == tabs.first ? G4MColors.accent : context.rc.cardAlt,
                              borderRadius: BorderRadius.circular(G4MRadius.pill),
                            ),
                            child: Text(
                              '${orders.where(t.$2).length}',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: t == tabs.first ? Colors.white : context.rc.muted),
                            ),
                          ),
                        ],
                      ]),
                    ),
                ],
              ),
            ),
          ),
        ),
        body: ListenableBuilder(
          listenable: Listenable.merge([store.orders, store.ordersError]),
          builder: (context, _) {
            final orders = store.orders.value;
            if (orders == null) {
              return store.ordersError.value != null ? ErrorView(store.ordersError.value!) : const SkeletonList(itemHeight: 120);
            }
            final q = _q;
            final filtered = q.isEmpty
                ? orders
                : orders.where((o) => o.orderNo.toLowerCase().contains(q) || o.customerName.toLowerCase().contains(q) || o.customerPhone.contains(q)).toList();
            return TabBarView(children: [
              for (final t in tabs) _list(context, filtered.where(t.$2).toList()),
            ]);
          },
        ),
      ),
    );
  }

  Widget _list(BuildContext context, List<ShopOrder> list) {
    if (list.isEmpty) {
      return AppEmpty(
        icon: Icons.inbox_outlined,
        title: context.tr('No orders here', 'यहां कोई ऑर्डर नहीं'),
        message: _q.isEmpty ? null : context.tr('Try a different search.', 'कुछ और खोजें।'),
      );
    }
    return ListView.separated(
      padding: pagePad,
      itemCount: list.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, i) => SellerOrderCard(
        order: list[i],
        onTap: () => Go.push(context, SellerOrderDetailScreen(orderId: list[i].id)),
      ).stagger(i),
    );
  }
}
