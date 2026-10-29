import 'package:flutter/material.dart';
import 'package:g4m_core/g4m_core.dart';
import 'package:go_router/go_router.dart';

import '../core/live.dart';
import '../core/panel.dart';
import '../core/router.dart';
import '../core/session.dart';
import '../features/auth/login_page.dart';
import '../features/auth/register_page.dart';
import '../features/delivery/delivery_pages.dart';
import '../features/shared/orders.dart';
import '../features/shared/withdrawals_self.dart';

PageDef _p(String path, String title, IconData icon, Widget Function(GoRouterState s) b, {String kw = ''}) =>
    PageDef(path, title, (c, s) => b(s), icon: icon, keywords: kw);

PanelSpec deliverySpec() {
  final pages = <PageDef>[
    _p('/dashboard', 'Dashboard', Icons.space_dashboard_rounded, (s) => const DeliveryDashboardPage(), kw: 'online offline'),
    _p('/orders/available', 'Available orders', Icons.local_mall_rounded, (s) => const AvailableOrdersPage(), kw: 'pool accept'),
    _p('/orders', 'My deliveries', Icons.delivery_dining_rounded, (s) => const MyDeliveriesPage()),
    PageDef('/orders/:id', 'Delivery', (c, s) => OrderDetailPage(id: s.pathParameters['id']!), searchable: false),
    _p('/map', 'Route map', Icons.map_rounded, (s) => const DeliveryRoutePage(), kw: 'navigation'),
    _p('/finance/earnings', 'Earnings', Icons.account_balance_wallet_rounded, (s) => const DeliveryEarningsPage(), kw: 'salary'),
    _p('/finance/cash', 'Cash in hand', Icons.payments_rounded, (s) => const CashInHandPage(), kw: 'cod collection'),
    _p('/finance/withdrawals', 'Withdrawals', Icons.outbox_rounded, (s) => const MyWithdrawalsPage()),
    _p('/profile', 'Profile', Icons.person_rounded, (s) => const DeliveryProfilePage(), kw: 'vehicle cities'),
  ];
  const nav = [
    NavSection('Work', [
      NavItem('Dashboard', Icons.space_dashboard_rounded, path: '/dashboard'),
      NavItem('Available orders', Icons.local_mall_rounded, path: '/orders/available', badge: 'pool'),
      NavItem('My deliveries', Icons.delivery_dining_rounded, path: '/orders', badge: 'active'),
      NavItem('Route map', Icons.map_rounded, path: '/map'),
    ]),
    NavSection('Money', [
      NavItem('Earnings', Icons.account_balance_wallet_rounded, path: '/finance/earnings'),
      NavItem('Cash in hand', Icons.payments_rounded, path: '/finance/cash'),
      NavItem('Withdrawals', Icons.outbox_rounded, path: '/finance/withdrawals'),
    ]),
    NavSection('Account', [
      NavItem('Profile', Icons.person_rounded, path: '/profile'),
    ]),
  ];
  return PanelSpec(
    pages: pages,
    nav: nav,
    badges: {
      // Mirrors the orders read rule for the rider pool.
      'pool': () => liveCount(Fs.orders.where('deliveryPartnerId', isNull: true).where('deliveryType', isEqualTo: 'home').where('status', whereIn: [OrderStatus.confirmed, OrderStatus.packed])),
      'active': () => liveCount(Fs.orders
          .where('deliveryPartnerId', isEqualTo: session.uid)
          .where('status', whereIn: [OrderStatus.assigned, OrderStatus.pickedUp, OrderStatus.outForDelivery])),
    },
    publicRoutes: [
      GoRoute(path: '/login', pageBuilder: (c, s) => fadeThroughPage(s, const LoginPage())),
      GoRoute(path: '/register', pageBuilder: (c, s) => fadeThroughPage(s, const RegisterPage())),
      GoRoute(path: '/pending', pageBuilder: (c, s) => fadeThroughPage(s, const PendingPage())),
    ],
  );
}
