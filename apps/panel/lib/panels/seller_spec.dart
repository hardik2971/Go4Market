import 'package:flutter/material.dart';
import 'package:g4m_core/g4m_core.dart';
import 'package:go_router/go_router.dart';

import '../core/live.dart';
import '../core/panel.dart';
import '../core/router.dart';
import '../core/session.dart';
import '../features/admin/catalog.dart';
import '../features/admin/marketing.dart';
import '../features/auth/login_page.dart';
import '../features/auth/register_page.dart';
import '../features/seller/dashboard.dart';
import '../features/seller/seller_pages.dart';
import '../features/shared/orders.dart';
import '../features/shared/pos.dart';
import '../features/shared/products.dart';
import '../features/shared/reports.dart';
import '../features/shared/returns.dart';
import '../features/shared/withdrawals_self.dart';

PageDef _p(String path, String title, IconData icon, Widget Function(GoRouterState s) b, {String kw = ''}) =>
    PageDef(path, title, (c, s) => b(s), icon: icon, keywords: kw);

PanelSpec sellerSpec() {
  final pages = <PageDef>[
    _p('/dashboard', 'Dashboard', Icons.space_dashboard_rounded, (s) => const SellerDashboardPage()),
    _p('/orders', 'Orders', Icons.receipt_long_rounded, (s) => const OrdersPage()),
    _p('/orders/pickup', 'Self-pickup orders', Icons.storefront_rounded, (s) => const OrdersPage(scope: 'pickup')),
    _p('/orders/pos', 'POS orders', Icons.point_of_sale_rounded, (s) => const OrdersPage(scope: 'pos')),
    PageDef('/orders/:id', 'Order', (c, s) => OrderDetailPage(id: s.pathParameters['id']!), searchable: false),
    _p('/returns', 'Returns', Icons.assignment_return_rounded, (s) => const ReturnsPage()),
    _p('/catalog/products', 'My products', Icons.inventory_2_rounded, (s) => const ProductsPage()),
    _p('/catalog/products/new', 'Add product', Icons.add_box_rounded, (s) => const ProductEditorPage()),
    PageDef('/catalog/products/:id/edit', 'Edit product', (c, s) => ProductEditorPage(id: s.pathParameters['id']), searchable: false),
    _p('/catalog/attributes', 'Attributes & custom fields', Icons.tune_rounded, (s) => const AttributesPage()),
    _p('/catalog/stock', 'Stock', Icons.warehouse_rounded, (s) => const StockPage(), kw: 'inventory'),
    _p('/catalog/reviews', 'Reviews', Icons.star_rate_rounded, (s) => const RatingsPage(), kw: 'ratings'),
    _p('/catalog/bulk', 'Bulk upload', Icons.upload_file_rounded, (s) => const BulkProductsPage(), kw: 'csv'),
    _p('/pos', 'Point of sale', Icons.point_of_sale_rounded, (s) => const PosPage(), kw: 'barcode'),
    _p('/marketing/coupons', 'My coupons', Icons.confirmation_number_rounded, (s) => const CouponsPage()),
    _p('/marketing/abandoned-carts', 'Abandoned carts', Icons.remove_shopping_cart_rounded, (s) => const AbandonedCartsPage()),
    _p('/riders', 'My delivery partners', Icons.delivery_dining_rounded, (s) => const SellerRidersPage(), kw: 'boys riders'),
    _p('/finance/earnings', 'Earnings', Icons.account_balance_wallet_rounded, (s) => const SellerEarningsPage(), kw: 'wallet balance'),
    _p('/finance/withdrawals', 'Withdrawals', Icons.outbox_rounded, (s) => const MyWithdrawalsPage(), kw: 'payout'),
    _p('/reports/sales', 'Sales report', Icons.insights_rounded, (s) => const ReportsPage(kind: 'sales')),
    _p('/reports/products', 'Product sales', Icons.leaderboard_rounded, (s) => const ReportsPage(kind: 'products')),
    _p('/reports/pos', 'POS report', Icons.point_of_sale_outlined, (s) => const ReportsPage(kind: 'pos')),
    _p('/store', 'Store profile & settings', Icons.store_rounded, (s) => const StoreProfilePage(), kw: 'logo banner bank policies'),
  ];
  const nav = [
    NavSection('Overview', [
      NavItem('Dashboard', Icons.space_dashboard_rounded, path: '/dashboard'),
      NavItem('Point of sale', Icons.point_of_sale_rounded, path: '/pos'),
    ]),
    NavSection('Sales', [
      NavItem('Orders', Icons.receipt_long_rounded, children: [
        NavItem('All orders', Icons.list_alt_rounded, path: '/orders', badge: 'orders'),
        NavItem('Self pickup', Icons.storefront_rounded, path: '/orders/pickup'),
        NavItem('POS orders', Icons.point_of_sale_rounded, path: '/orders/pos'),
      ]),
      NavItem('Returns', Icons.assignment_return_rounded, path: '/returns', badge: 'returns'),
      NavItem('Delivery partners', Icons.delivery_dining_rounded, path: '/riders'),
    ]),
    NavSection('Catalog', [
      NavItem('Products', Icons.inventory_2_rounded, children: [
        NavItem('My products', Icons.inventory_2_outlined, path: '/catalog/products'),
        NavItem('Add product', Icons.add_box_outlined, path: '/catalog/products/new'),
        NavItem('Bulk upload', Icons.upload_file_outlined, path: '/catalog/bulk'),
        NavItem('Attributes', Icons.tune_outlined, path: '/catalog/attributes'),
      ]),
      NavItem('Stock', Icons.warehouse_rounded, path: '/catalog/stock'),
      NavItem('Reviews', Icons.star_rate_rounded, path: '/catalog/reviews'),
    ]),
    NavSection('Growth', [
      NavItem('Coupons', Icons.confirmation_number_rounded, path: '/marketing/coupons'),
      NavItem('Abandoned carts', Icons.remove_shopping_cart_rounded, path: '/marketing/abandoned-carts'),
      NavItem('Reports', Icons.insights_rounded, children: [
        NavItem('Sales', Icons.show_chart_rounded, path: '/reports/sales'),
        NavItem('Product sales', Icons.leaderboard_outlined, path: '/reports/products'),
        NavItem('POS', Icons.point_of_sale_outlined, path: '/reports/pos'),
      ]),
    ]),
    NavSection('Money', [
      NavItem('Earnings', Icons.account_balance_wallet_rounded, path: '/finance/earnings'),
      NavItem('Withdrawals', Icons.outbox_rounded, path: '/finance/withdrawals'),
      NavItem('Store settings', Icons.store_rounded, path: '/store'),
    ]),
  ];
  return PanelSpec(
    pages: pages,
    nav: nav,
    badges: {
      'orders': () => liveCount(Fs.orders.where('sellerIds', arrayContains: session.uid).where('status', isEqualTo: OrderStatus.placed)),
      'returns': () => liveCount(Fs.returns.where('sellerIds', arrayContains: session.uid).where('status', isEqualTo: 'requested')),
    },
    publicRoutes: [
      GoRoute(path: '/login', pageBuilder: (c, s) => fadeThroughPage(s, const LoginPage())),
      GoRoute(path: '/register', pageBuilder: (c, s) => fadeThroughPage(s, const RegisterPage())),
      GoRoute(path: '/pending', pageBuilder: (c, s) => fadeThroughPage(s, const PendingPage())),
      GoRoute(path: '/print/invoice/:id', pageBuilder: (c, s) => fadeThroughPage(s, InvoicePage(id: s.pathParameters['id']!))),
    ],
  );
}
