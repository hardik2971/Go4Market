import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:g4m_core/g4m_core.dart';

import '../../core/l10n.dart';
import '../../core/motion.dart';
import '../../core/push.dart';
import 'dashboard_screen.dart';
import 'more_screen.dart';
import 'order_detail_screen.dart';
import 'orders_screen.dart';
import 'pos_screen.dart';
import 'products_screen.dart';
import 'seller_store.dart';

/// Bottom-nav shell for approved sellers.
class SellerShell extends StatefulWidget {
  const SellerShell({super.key});

  /// Lets nested screens switch tabs (e.g. dashboard "See all orders").
  static void goTab(BuildContext context, int i) => context.findAncestorStateOfType<_SellerShellState>()?._select(i);

  @override
  State<SellerShell> createState() => _SellerShellState();
}

class _SellerShellState extends State<SellerShell> {
  int _tab = 0;
  final _visited = <int>{0};
  StreamSubscription<ShopOrder>? _newSub;
  ShopOrder? _banner;
  Timer? _bannerTimer;

  @override
  void initState() {
    super.initState();
    SellerStore.instance.start();
    _newSub = SellerStore.instance.newOrders.stream.listen(_onNewOrder);
    WidgetsBinding.instance.addPostFrameCallback((_) => PushService.instance.flushPending());
  }

  @override
  void dispose() {
    _newSub?.cancel();
    _bannerTimer?.cancel();
    SellerStore.instance.stop();
    super.dispose();
  }

  void _onNewOrder(ShopOrder o) {
    HapticFeedback.heavyImpact();
    setState(() => _banner = o);
    _bannerTimer?.cancel();
    _bannerTimer = Timer(const Duration(seconds: 6), () {
      if (mounted) setState(() => _banner = null);
    });
  }

  void _select(int i) {
    if (i == _tab) return;
    HapticFeedback.selectionClick();
    setState(() {
      _tab = i;
      _visited.add(i);
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = const [SellerDashboardScreen(), SellerOrdersScreen(), SellerProductsScreen(), PosScreen(), SellerMoreScreen()];
    return Scaffold(
      body: Stack(children: [
        for (var i = 0; i < pages.length; i++)
          if (_visited.contains(i))
            IgnorePointer(
              ignoring: i != _tab,
              child: TickerMode(
                enabled: i == _tab,
                child: AnimatedOpacity(
                  opacity: i == _tab ? 1 : 0,
                  duration: G4MMotion.standard,
                  curve: G4MMotion.curve,
                  child: AnimatedSlide(
                    offset: i == _tab ? Offset.zero : const Offset(0, .015),
                    duration: G4MMotion.emphasized,
                    curve: G4MMotion.curve,
                    child: pages[i],
                  ),
                ),
              ),
            ),
        if (_banner != null)
          Positioned(
            left: 12,
            right: 12,
            top: MediaQuery.of(context).padding.top + 8,
            child: _NewOrderBanner(
              order: _banner!,
              onTap: () {
                final o = _banner!;
                setState(() => _banner = null);
                Go.push(context, SellerOrderDetailScreen(orderId: o.id));
              },
              onClose: () => setState(() => _banner = null),
            ),
          ),
      ]),
      bottomNavigationBar: ValueListenableBuilder<List<ShopOrder>?>(
        valueListenable: SellerStore.instance.orders,
        builder: (context, orders, _) {
          final fresh = (orders ?? const []).where((o) => o.status == OrderStatus.placed).length;
          return NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: _select,
            destinations: [
              NavigationDestination(icon: const Icon(Icons.space_dashboard_outlined), selectedIcon: const Icon(Icons.space_dashboard_rounded), label: context.s.dashboard),
              NavigationDestination(
                icon: Badge(isLabelVisible: fresh > 0, backgroundColor: G4MColors.accent, label: Text('$fresh'), child: const Icon(Icons.receipt_long_outlined)),
                selectedIcon: Badge(isLabelVisible: fresh > 0, backgroundColor: G4MColors.accent, label: Text('$fresh'), child: const Icon(Icons.receipt_long_rounded)),
                label: context.s.orders,
              ),
              NavigationDestination(icon: const Icon(Icons.inventory_2_outlined), selectedIcon: const Icon(Icons.inventory_2_rounded), label: context.s.products),
              NavigationDestination(icon: const Icon(Icons.point_of_sale_outlined), selectedIcon: const Icon(Icons.point_of_sale_rounded), label: 'POS'),
              NavigationDestination(icon: const Icon(Icons.grid_view_outlined), selectedIcon: const Icon(Icons.grid_view_rounded), label: context.s.more),
            ],
          );
        },
      ),
    );
  }
}

class _NewOrderBanner extends StatelessWidget {
  const _NewOrderBanner({required this.order, required this.onTap, required this.onClose});
  final ShopOrder order;
  final VoidCallback onTap, onClose;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Pressable(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
          decoration: BoxDecoration(
            gradient: G4MColors.accentGradient,
            borderRadius: BorderRadius.circular(G4MRadius.md),
            boxShadow: G4MShadows.glowAccent,
          ),
          child: Row(children: [
            const Icon(Icons.notifications_active_rounded, color: Colors.white)
                .animate(onPlay: (c) => c.repeat())
                .shake(hz: 4, rotation: .12, duration: 700.ms)
                .then(delay: 900.ms),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(context.tr('New order #${order.orderNo}', 'नया ऑर्डर #${order.orderNo}'),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                Text('${order.customerName} · ${Fmt.money(order.payable)}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ]),
            ),
            IconButton(onPressed: onClose, icon: const Icon(Icons.close_rounded, color: Colors.white)),
          ]),
        ),
      ),
    ).animate().slideY(begin: -1.2, duration: 500.ms, curve: Curves.easeOutBack).fadeIn();
  }
}
