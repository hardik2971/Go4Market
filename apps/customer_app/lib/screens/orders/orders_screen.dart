import 'package:flutter/material.dart';
import 'package:g4m_core/g4m_core.dart';

import '../../core/data.dart';
import '../../core/nav.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/ui.dart';
import '../auth/auth_screens.dart';
import '../shell/main_shell.dart';
import 'order_detail_screen.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key, this.standalone = false});
  final bool standalone;
  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  int _tab = 0;
  Stream<List<ShopOrder>>? _stream;
  String? _uid;
  Stream<List<ShopOrder>> get _orders {
    if (_stream == null || _uid != Session.instance.uid) {
      _uid = Session.instance.uid;
      _stream = MyData.orders();
    }
    return _stream!;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ValueListenableBuilder(
      valueListenable: Session.instance.epoch,
      builder: (context, _, _) => Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: widget.standalone,
          title: Text(l.orders),
          bottom: Session.instance.isGuest
              ? null
              : PreferredSize(
                  preferredSize: const Size.fromHeight(56),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: SegmentedButton<int>(
                      showSelectedIcon: false,
                      segments: [
                        ButtonSegment(value: 0, label: Text(l.activeOrders), icon: const Icon(Icons.local_shipping_outlined)),
                        ButtonSegment(value: 1, label: Text(l.pastOrders), icon: const Icon(Icons.history_rounded)),
                      ],
                      selected: {_tab},
                      onSelectionChanged: (s) => setState(() => _tab = s.first),
                    ),
                  ),
                ),
        ),
        body: Session.instance.isGuest
            ? EmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'Log in to see your orders',
                message: 'Track deliveries, reorder favourites and request returns.',
                action: FilledButton(onPressed: () => requireAccount(context), child: Text(l.login)),
              )
            : StreamBuilder<List<ShopOrder>>(
                key: ValueKey(Session.instance.uid),
                stream: _orders,
                builder: (context, snap) {
                  if (snap.hasError) return ErrorView(error: snap.error!, onRetry: () => setState(() => _stream = null));
                  if (!snap.hasData) return const ListSkeleton(count: 5, height: 120);
                  final all = snap.data!;
                  final list = all.where((o) => _tab == 0 ? o.isActive : !o.isActive).toList();
                  if (list.isEmpty) {
                    return EmptyState(
                      icon: _tab == 0 ? Icons.delivery_dining_outlined : Icons.receipt_long_outlined,
                      title: _tab == 0 ? 'No active orders' : l.noOrders,
                      message: _tab == 0 && all.isNotEmpty ? 'Your past orders are in the Past tab.' : 'Your orders will show up here.',
                      action: FilledButton(onPressed: () => goHomeTab(context), child: Text(l.startShopping)),
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: () async => setState(() => _stream = null),
                    child: AnimatedSwitcher(
                      duration: G4MMotion.standard,
                      child: ListView.separated(
                        key: ValueKey(_tab),
                        padding: EdgeInsets.fromLTRB(16, 8, 16, widget.standalone ? 24 : kNavPad),
                        itemCount: list.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (_, i) => OrderCard(order: list[i]).stagger(i),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class OrderCard extends StatelessWidget {
  const OrderCard({super.key, required this.order});
  final ShopOrder order;
  @override
  Widget build(BuildContext context) {
    final o = order;
    final items = o.items;
    return AppCard(
      onTap: () => context.push(OrderDetailScreen(orderId: o.id, initial: o)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('#${o.orderNo}', style: context.text.titleSmall),
              Text(Fmt.dateTime(o.createdAt), style: context.text.bodySmall),
            ]),
          ),
          StatusChip(o.status, label: OrderStatus.label(o.status)),
        ]),
        const SizedBox(height: 12),
        SizedBox(
          height: 52,
          child: Row(children: [
            for (final it in items.take(4))
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Container(
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: context.line)),
                  child: Img(it.image, width: 50, height: 50, radius: 11, iconSize: 18),
                ),
              ),
            if (items.length > 4)
              CircleAvatar(radius: 22, backgroundColor: context.cardAlt, child: Text('+${items.length - 4}', style: context.text.labelLarge)),
            const Spacer(),
            Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(Fmt.money(o.payable > 0 ? o.payable : o.total), style: context.text.titleMedium),
              Text('${o.itemCount} items', style: context.text.bodySmall),
            ]),
          ]),
        ),
        if (o.isActive) ...[
          const SizedBox(height: 12),
          _MiniProgress(order: o),
        ],
      ]),
    );
  }
}

class _MiniProgress extends StatelessWidget {
  const _MiniProgress({required this.order});
  final ShopOrder order;
  @override
  Widget build(BuildContext context) {
    final flow = order.deliveryType == 'pickup' ? OrderStatus.pickupFlow : OrderStatus.homeFlow;
    final idx = flow.indexOf(order.status);
    final v = order.status == OrderStatus.pending ? .03 : (idx < 0 ? 0.0 : (idx + 1) / flow.length);
    return Row(children: [
      Expanded(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: v),
            duration: G4MMotion.slow,
            curve: G4MMotion.curve,
            builder: (_, x, _) => LinearProgressIndicator(value: x, minHeight: 6, backgroundColor: context.cardAlt, color: G4MColors.primary),
          ),
        ),
      ),
      const SizedBox(width: 10),
      Text(
        order.speed.startsWith('quick') ? 'Express' : (order.speed == 'scheduled' ? 'Scheduled' : 'Track'),
        style: context.text.labelLarge?.copyWith(color: order.speed.startsWith('quick') ? G4MColors.accent : G4MColors.primary),
      ),
      const Icon(Icons.chevron_right_rounded, size: 18),
    ]);
  }
}
