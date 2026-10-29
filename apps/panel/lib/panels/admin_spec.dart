import 'package:flutter/material.dart';
import 'package:g4m_core/g4m_core.dart' hide Fmt;
import 'package:go_router/go_router.dart';

import '../core/doc.dart';
import '../core/live.dart';
import '../core/panel.dart';
import '../core/router.dart';
import '../features/admin/catalog.dart';
import '../features/admin/content.dart';
import '../features/admin/dashboard.dart';
import '../features/admin/finance.dart';
import '../features/admin/live_map.dart';
import '../features/admin/marketing.dart';
import '../features/admin/people.dart';
import '../features/admin/settings.dart';
import '../features/admin/staff.dart';
import '../features/auth/login_page.dart';
import '../features/shared/orders.dart';
import '../features/shared/pos.dart';
import '../features/shared/products.dart';
import '../features/shared/reports.dart';
import '../features/shared/returns.dart';
import 'package:panel/l10n/overrides.dart';

PageDef _p(String path, String title, IconData icon, Widget Function(GoRouterState s) b, {String kw = '', String? perm}) =>
    PageDef(path, title, (c, s) => b(s), icon: icon, keywords: kw, permission: perm);

/// Permission keys used by admin roles (adminRoles/{id}.permissions).
const adminPermissions = <String, String>{
  'orders': 'Orders, returns & live map',
  'catalog': 'Catalog & stock',
  'sellers': 'Sellers',
  'delivery': 'Delivery partners',
  'customers': 'Customers',
  'finance': 'Finance & payouts',
  'marketing': 'Marketing',
  'content': 'Content & CMS',
  'reports': 'Reports',
  'pos': 'Point of sale',
  'settings': 'Settings',
  'staff': 'Staff & roles',
  'system': 'System',
};

PanelSpec adminSpec() {
  final pages = <PageDef>[
    _p('/dashboard', 'Dashboard', Icons.space_dashboard_rounded, (s) => const AdminDashboardPage(), kw: 'home overview kpi'),
    // Orders
    _p('/orders', 'All orders', Icons.receipt_long_rounded, (s) => const OrdersPage(), perm: 'orders'),
    _p('/orders/pickup', 'Self-pickup orders', Icons.storefront_rounded, (s) => const OrdersPage(scope: 'pickup'), perm: 'orders'),
    _p('/orders/pos', 'POS orders', Icons.point_of_sale_rounded, (s) => const OrdersPage(scope: 'pos'), perm: 'orders'),
    PageDef('/orders/:id', 'Order', (c, s) => OrderDetailPage(id: s.pathParameters['id']!), searchable: false, permission: 'orders'),
    _p('/returns', 'Return requests', Icons.assignment_return_rounded, (s) => const ReturnsPage(), perm: 'orders', kw: 'refund'),
    _p('/live-map', 'Live rider map', Icons.map_rounded, (s) => const LiveMapPage(), perm: 'orders', kw: 'tracking riders online'),
    // Catalog
    _p('/catalog/products', 'Products', Icons.inventory_2_rounded, (s) => const ProductsPage(), perm: 'catalog'),
    _p('/catalog/products/new', 'Add product', Icons.add_box_rounded, (s) => const ProductEditorPage(), perm: 'catalog'),
    PageDef('/catalog/products/:id/edit', 'Edit product', (c, s) => ProductEditorPage(id: s.pathParameters['id']), searchable: false, permission: 'catalog'),
    _p('/catalog/approvals', 'Product approvals', Icons.fact_check_rounded, (s) => const ProductsPage(approvals: true), perm: 'catalog', kw: 'seller requests pending'),
    _p('/catalog/categories', 'Categories', Icons.account_tree_rounded, (s) => const CategoriesPage(), perm: 'catalog'),
    _p('/catalog/brands', 'Brands', Icons.workspace_premium_rounded, (s) => const BrandsPage(), perm: 'catalog'),
    _p('/catalog/attributes', 'Attributes', Icons.tune_rounded, (s) => const AttributesPage(), perm: 'catalog', kw: 'variants size color'),
    _p('/catalog/custom-fields', 'Custom fields', Icons.dynamic_form_rounded, (s) => const CustomFieldsPage(), perm: 'catalog', kw: 'veg allergen'),
    _p('/catalog/taxes', 'Taxes', Icons.percent_rounded, (s) => const TaxesPage(), perm: 'catalog', kw: 'gst'),
    _p('/catalog/stock', 'Stock management', Icons.warehouse_rounded, (s) => const StockPage(), perm: 'catalog', kw: 'inventory low out of stock'),
    _p('/catalog/ratings', 'Product ratings', Icons.star_rate_rounded, (s) => const RatingsPage(), perm: 'catalog', kw: 'reviews'),
    _p('/catalog/media', 'Media library', Icons.perm_media_rounded, (s) => const MediaPage(), perm: 'catalog', kw: 'images upload'),
    _p('/catalog/bulk', 'Bulk upload / update', Icons.upload_file_rounded, (s) => const BulkProductsPage(), perm: 'catalog', kw: 'csv import export'),
    _p('/catalog/sort', 'Product order', Icons.sort_rounded, (s) => const ProductOrderPage(), perm: 'catalog', kw: 'sorting'),
    // Sellers
    _p('/sellers', 'All sellers', Icons.store_mall_directory_rounded, (s) => const SellersPage(), perm: 'sellers', kw: 'vendors'),
    _p('/sellers/requests', 'Seller requests', Icons.how_to_reg_rounded, (s) => const SellersPage(requests: true), perm: 'sellers', kw: 'approve onboarding'),
    _p('/sellers/wallet', 'Seller wallet', Icons.account_balance_wallet_outlined, (s) => const SellerWalletPage(), perm: 'sellers'),
    _p('/sellers/policies', 'Seller policies', Icons.policy_rounded, (s) => const PolicyPage(slug: 'seller-policy', title: 'Seller policies'), perm: 'sellers'),
    PageDef('/sellers/:id', 'Seller', (c, s) => SellerDetailPage(id: s.pathParameters['id']!), searchable: false, permission: 'sellers'),
    // Delivery
    _p('/delivery/partners', 'Delivery partners', Icons.delivery_dining_rounded, (s) => const DeliveryPartnersPage(), perm: 'delivery', kw: 'riders boys'),
    _p('/delivery/requests', 'Partner requests', Icons.person_add_alt_1_rounded, (s) => const DeliveryPartnersPage(requests: true), perm: 'delivery'),
    PageDef('/delivery/partners/:id', 'Partner', (c, s) => DeliveryPartnerDetailPage(id: s.pathParameters['id']!), searchable: false, permission: 'delivery'),
    _p('/delivery/cash', 'Cash collection', Icons.payments_rounded, (s) => const CashCollectionPage(), perm: 'delivery', kw: 'cod settle'),
    _p('/delivery/salary', 'Salary', Icons.badge_rounded, (s) => const SalaryPage(), perm: 'delivery'),
    _p('/delivery/settings', 'Delivery settings', Icons.schedule_rounded, (s) => const DeliverySettingsPage(), perm: 'delivery', kw: 'slots time quick'),
    _p('/delivery/policies', 'Partner policies', Icons.gavel_rounded, (s) => const PolicyPage(slug: 'delivery-policy', title: 'Delivery partner policies'), perm: 'delivery'),
    // Customers
    _p('/customers', 'Customers', Icons.people_alt_rounded, (s) => const CustomersPage(), perm: 'customers', kw: 'users'),
    _p('/customers/wishlists', 'Wishlists', Icons.favorite_rounded, (s) => const WishlistsPage(), perm: 'customers'),
    _p('/customers/product-requests', 'Product requests', Icons.lightbulb_rounded, (s) => const ProductRequestsPage(), perm: 'customers'),
    PageDef('/customers/:id', 'Customer', (c, s) => CustomerDetailPage(id: s.pathParameters['id']!), searchable: false, permission: 'customers'),
    // Finance
    _p('/finance/wallet', 'Wallet transactions', Icons.account_balance_wallet_rounded, (s) => const WalletTxnsPage(), perm: 'finance'),
    _p('/finance/withdrawals', 'Withdrawal requests', Icons.outbox_rounded, (s) => const WithdrawalsAdminPage(), perm: 'finance', kw: 'payout'),
    _p('/finance/transfers', 'Fund transfers', Icons.swap_horiz_rounded, (s) => const FundTransfersPage(), perm: 'finance'),
    _p('/finance/payouts', 'Seller payouts', Icons.request_quote_rounded, (s) => const PayoutsPage(), perm: 'finance', kw: 'commission balance'),
    _p('/finance/transactions', 'Payment transactions', Icons.credit_card_rounded, (s) => const PaymentTxnsPage(), perm: 'finance', kw: 'razorpay stripe paypal'),
    // Marketing
    _p('/marketing/sliders', 'Home sliders', Icons.view_carousel_rounded, (s) => const SlidersPage(), perm: 'marketing', kw: 'banner'),
    _p('/marketing/offers', 'Offer banners', Icons.local_offer_rounded, (s) => const OffersPage(), perm: 'marketing'),
    _p('/marketing/popups', 'Popups', Icons.open_in_new_rounded, (s) => const PopupsPage(), perm: 'marketing'),
    _p('/marketing/featured', 'Featured sections', Icons.auto_awesome_mosaic_rounded, (s) => const FeaturedSectionsPage(), perm: 'marketing', kw: 'homepage'),
    _p('/marketing/coupons', 'Coupons & promo codes', Icons.confirmation_number_rounded, (s) => const CouponsPage(), perm: 'marketing', kw: 'discount'),
    _p('/marketing/campaigns', 'Push campaigns', Icons.campaign_rounded, (s) => const CampaignsPage(), perm: 'marketing', kw: 'notification fcm'),
    _p('/marketing/membership', 'Membership plans', Icons.card_membership_rounded, (s) => const MembershipPlansPage(), perm: 'marketing'),
    _p('/marketing/subscriptions', 'Subscriptions', Icons.autorenew_rounded, (s) => const SubscriptionsPage(), perm: 'marketing', kw: 'recurring'),
    _p('/marketing/abandoned-carts', 'Abandoned carts', Icons.remove_shopping_cart_rounded, (s) => const AbandonedCartsPage(), perm: 'marketing'),
    // Content
    _p('/content/blogs', 'Blogs', Icons.article_rounded, (s) => const BlogsPage(), perm: 'content'),
    _p('/content/blog-categories', 'Blog categories', Icons.folder_rounded, (s) => const BlogCategoriesPage(), perm: 'content'),
    _p('/content/faqs', 'FAQs', Icons.quiz_rounded, (s) => const FaqsPage(), perm: 'content'),
    _p('/content/pages', 'Pages & policies', Icons.description_rounded, (s) => const CmsPagesPage(), perm: 'content', kw: 'about terms privacy refund customer policies'),
    _p('/content/email-templates', 'Email templates', Icons.mark_email_read_rounded, (s) => const EmailTemplatesPage(), perm: 'content'),
    _p('/content/emails', 'Send email', Icons.forward_to_inbox_rounded, (s) => const EmailLogPage(), perm: 'content'),
    // Reports
    _p('/reports/sales', 'Sales report', Icons.insights_rounded, (s) => const ReportsPage(kind: 'sales'), perm: 'reports'),
    _p('/reports/products', 'Product sales', Icons.leaderboard_rounded, (s) => const ReportsPage(kind: 'products'), perm: 'reports', kw: 'best worst selling'),
    _p('/reports/categories', 'Category report', Icons.donut_large_rounded, (s) => const ReportsPage(kind: 'categories'), perm: 'reports'),
    _p('/reports/sellers', 'Seller report', Icons.storefront_outlined, (s) => const ReportsPage(kind: 'sellers'), perm: 'reports'),
    _p('/reports/commission', 'Commission report', Icons.percent_rounded, (s) => const ReportsPage(kind: 'commission'), perm: 'reports'),
    _p('/reports/pos', 'POS report', Icons.point_of_sale_outlined, (s) => const ReportsPage(kind: 'pos'), perm: 'reports'),
    _p('/pos', 'Point of sale', Icons.point_of_sale_rounded, (s) => const PosPage(), perm: 'pos', kw: 'barcode checkout counter'),
    // Settings
    _p('/settings', 'All settings', Icons.settings_rounded, (s) => const SettingsHubPage(), perm: 'settings'),
    _p('/settings/platform', 'Platform settings', Icons.tune_rounded, (s) => const PlatformSettingsPage(), perm: 'settings', kw: 'store currency delivery fee tax cod wallet referral'),
    _p('/settings/payments', 'Payment gateways', Icons.payment_rounded, (s) => const PaymentSettingsPage(), perm: 'settings', kw: 'razorpay stripe paypal'),
    _p('/settings/modules', 'Modules', Icons.widgets_rounded, (s) => const ModulesPage(), perm: 'settings', kw: 'grocery pharmacy food ecommerce'),
    _p('/settings/theme', 'Theme', Icons.palette_rounded, (s) => const ThemeSettingsPage(), perm: 'settings', kw: 'colors'),
    _p('/settings/seo', 'SEO', Icons.travel_explore_rounded, (s) => const SeoSettingsPage(), perm: 'settings'),
    _p('/settings/social', 'Social links', Icons.share_rounded, (s) => const SocialSettingsPage(), perm: 'settings'),
    _p('/settings/app-versions', 'App versions', Icons.system_update_rounded, (s) => const AppVersionsPage(), perm: 'settings', kw: 'force update'),
    _p('/settings/languages', 'Languages', Icons.translate_rounded, (s) => const LanguagesPage(), perm: 'settings', kw: 'localization rtl'),
    _p('/settings/cities', 'Cities & zones', Icons.location_city_rounded, (s) => const CitiesPage(), perm: 'settings', kw: 'locations'),
    _p('/settings/countries', 'Countries', Icons.public_rounded, (s) => const CountriesPage(), perm: 'settings'),
    _p('/settings/communication', 'Communication', Icons.sms_rounded, (s) => const CommunicationSettingsPage(), perm: 'settings', kw: 'smtp sms email notifications'),
    _p('/settings/system-mode', 'Demo & maintenance', Icons.construction_rounded, (s) => const SystemModePage(), perm: 'settings'),
    _p('/staff', 'Staff users', Icons.admin_panel_settings_rounded, (s) => const StaffPage(), perm: 'staff'),
    _p('/staff/roles', 'Roles & permissions', Icons.lock_person_rounded, (s) => const RolesPage(), perm: 'staff'),
    _p('/system', 'System health', Icons.monitor_heart_rounded, (s) => const SystemPage(), perm: 'system', kw: 'status indexes'),
    _p('/account', 'My account', Icons.person_rounded, (s) => const AccountPage(), kw: 'password profile'),
  ];

  const nav = [
    NavSection('Overview', [
      NavItem('Dashboard', Icons.space_dashboard_rounded, path: '/dashboard'),
      NavItem('Point of sale', Icons.point_of_sale_rounded, path: '/pos', permission: 'pos'),
      NavItem('Live map', Icons.map_rounded, path: '/live-map', permission: 'orders'),
    ]),
    NavSection('Commerce', [
      NavItem('Orders', Icons.receipt_long_rounded, permission: 'orders', children: [
        NavItem('All orders', Icons.list_alt_rounded, path: '/orders', badge: 'orders'),
        NavItem('Self pickup', Icons.storefront_rounded, path: '/orders/pickup'),
        NavItem('POS orders', Icons.point_of_sale_rounded, path: '/orders/pos'),
        NavItem('Returns', Icons.assignment_return_rounded, path: '/returns', badge: 'returns'),
      ]),
      NavItem('Catalog', Icons.inventory_2_rounded, permission: 'catalog', children: [
        NavItem('Products', Icons.inventory_2_outlined, path: '/catalog/products'),
        NavItem('Approvals', Icons.fact_check_outlined, path: '/catalog/approvals', badge: 'approvals'),
        NavItem('Categories', Icons.account_tree_outlined, path: '/catalog/categories'),
        NavItem('Brands', Icons.workspace_premium_outlined, path: '/catalog/brands'),
        NavItem('Attributes', Icons.tune_outlined, path: '/catalog/attributes'),
        NavItem('Custom fields', Icons.dynamic_form_outlined, path: '/catalog/custom-fields'),
        NavItem('Taxes', Icons.percent_outlined, path: '/catalog/taxes'),
        NavItem('Stock', Icons.warehouse_outlined, path: '/catalog/stock'),
        NavItem('Ratings', Icons.star_outline_rounded, path: '/catalog/ratings'),
        NavItem('Media', Icons.perm_media_outlined, path: '/catalog/media'),
        NavItem('Bulk upload', Icons.upload_file_outlined, path: '/catalog/bulk'),
        NavItem('Product order', Icons.sort_rounded, path: '/catalog/sort'),
      ]),
    ]),
    NavSection('People', [
      NavItem('Sellers', Icons.store_mall_directory_rounded, permission: 'sellers', children: [
        NavItem('All sellers', Icons.storefront_outlined, path: '/sellers'),
        NavItem('Requests', Icons.how_to_reg_outlined, path: '/sellers/requests', badge: 'sellers'),
        NavItem('Seller wallet', Icons.account_balance_wallet_outlined, path: '/sellers/wallet'),
        NavItem('Policies', Icons.policy_outlined, path: '/sellers/policies'),
      ]),
      NavItem('Delivery', Icons.delivery_dining_rounded, permission: 'delivery', children: [
        NavItem('Partners', Icons.two_wheeler_rounded, path: '/delivery/partners'),
        NavItem('Requests', Icons.person_add_alt_outlined, path: '/delivery/requests', badge: 'riders'),
        NavItem('Cash collection', Icons.payments_outlined, path: '/delivery/cash'),
        NavItem('Salary', Icons.badge_outlined, path: '/delivery/salary'),
        NavItem('Delivery settings', Icons.schedule_outlined, path: '/delivery/settings'),
        NavItem('Policies', Icons.gavel_outlined, path: '/delivery/policies'),
      ]),
      NavItem('Customers', Icons.people_alt_rounded, permission: 'customers', children: [
        NavItem('All customers', Icons.people_outline_rounded, path: '/customers'),
        NavItem('Wishlists', Icons.favorite_outline_rounded, path: '/customers/wishlists'),
        NavItem('Product requests', Icons.lightbulb_outline_rounded, path: '/customers/product-requests', badge: 'productRequests'),
      ]),
    ]),
    NavSection('Money', [
      NavItem('Finance', Icons.account_balance_rounded, permission: 'finance', children: [
        NavItem('Withdrawals', Icons.outbox_outlined, path: '/finance/withdrawals', badge: 'withdrawals'),
        NavItem('Wallet transactions', Icons.account_balance_wallet_outlined, path: '/finance/wallet'),
        NavItem('Fund transfers', Icons.swap_horiz_rounded, path: '/finance/transfers'),
        NavItem('Seller payouts', Icons.request_quote_outlined, path: '/finance/payouts'),
        NavItem('Payments', Icons.credit_card_outlined, path: '/finance/transactions'),
      ]),
      NavItem('Reports', Icons.insights_rounded, permission: 'reports', children: [
        NavItem('Sales', Icons.show_chart_rounded, path: '/reports/sales'),
        NavItem('Product sales', Icons.leaderboard_outlined, path: '/reports/products'),
        NavItem('Categories', Icons.donut_large_outlined, path: '/reports/categories'),
        NavItem('Sellers', Icons.storefront_outlined, path: '/reports/sellers'),
        NavItem('Commission', Icons.percent_outlined, path: '/reports/commission'),
        NavItem('POS', Icons.point_of_sale_outlined, path: '/reports/pos'),
      ]),
    ]),
    NavSection('Growth', [
      NavItem('Marketing', Icons.campaign_rounded, permission: 'marketing', children: [
        NavItem('Home sliders', Icons.view_carousel_outlined, path: '/marketing/sliders'),
        NavItem('Offer banners', Icons.local_offer_outlined, path: '/marketing/offers'),
        NavItem('Featured sections', Icons.auto_awesome_mosaic_outlined, path: '/marketing/featured'),
        NavItem('Coupons', Icons.confirmation_number_outlined, path: '/marketing/coupons'),
        NavItem('Popups', Icons.open_in_new_rounded, path: '/marketing/popups'),
        NavItem('Push campaigns', Icons.campaign_outlined, path: '/marketing/campaigns'),
        NavItem('Membership plans', Icons.card_membership_outlined, path: '/marketing/membership'),
        NavItem('Subscriptions', Icons.autorenew_rounded, path: '/marketing/subscriptions'),
        NavItem('Abandoned carts', Icons.remove_shopping_cart_outlined, path: '/marketing/abandoned-carts'),
      ]),
      NavItem('Content', Icons.article_rounded, permission: 'content', children: [
        NavItem('Blogs', Icons.article_outlined, path: '/content/blogs'),
        NavItem('Blog categories', Icons.folder_outlined, path: '/content/blog-categories'),
        NavItem('FAQs', Icons.quiz_outlined, path: '/content/faqs'),
        NavItem('Pages & policies', Icons.description_outlined, path: '/content/pages'),
        NavItem('Email templates', Icons.mark_email_read_outlined, path: '/content/email-templates'),
        NavItem('Send email', Icons.forward_to_inbox_outlined, path: '/content/emails'),
      ]),
    ]),
    NavSection('Configure', [
      NavItem('Settings', Icons.settings_rounded, permission: 'settings', children: [
        NavItem('All settings', Icons.grid_view_rounded, path: '/settings'),
        NavItem('Platform', Icons.tune_rounded, path: '/settings/platform'),
        NavItem('Payments', Icons.payment_rounded, path: '/settings/payments'),
        NavItem('Modules', Icons.widgets_outlined, path: '/settings/modules'),
        NavItem('Theme', Icons.palette_outlined, path: '/settings/theme'),
        NavItem('SEO', Icons.travel_explore_rounded, path: '/settings/seo'),
        NavItem('Social links', Icons.share_outlined, path: '/settings/social'),
        NavItem('App versions', Icons.system_update_outlined, path: '/settings/app-versions'),
        NavItem('Languages', Icons.translate_rounded, path: '/settings/languages'),
        NavItem('Cities & zones', Icons.location_city_outlined, path: '/settings/cities'),
        NavItem('Countries', Icons.public_rounded, path: '/settings/countries'),
        NavItem('Communication', Icons.sms_outlined, path: '/settings/communication'),
        NavItem('Demo & maintenance', Icons.construction_outlined, path: '/settings/system-mode'),
      ]),
      NavItem('Staff & roles', Icons.admin_panel_settings_rounded, permission: 'staff', children: [
        NavItem('Staff users', Icons.manage_accounts_outlined, path: '/staff'),
        NavItem('Roles', Icons.lock_person_outlined, path: '/staff/roles'),
      ]),
      NavItem('System health', Icons.monitor_heart_rounded, path: '/system', permission: 'system'),
    ]),
  ];

  return PanelSpec(
    pages: pages,
    nav: nav,
    badges: {
      'orders': () => liveCount(Fs.orders.where('status', isEqualTo: OrderStatus.placed)),
      'returns': () => liveCount(Fs.returns.where('status', isEqualTo: 'requested')),
      'approvals': () => liveCount(Fs.products.where('status', isEqualTo: 'pending')),
      'sellers': () => liveCount(Fs.sellers.where('status', isEqualTo: 'pending')),
      'riders': () => liveCount(Fs.deliveryPartners.where('status', isEqualTo: 'pending')),
      'withdrawals': () => liveCount(Fs.withdrawals.where('status', isEqualTo: 'pending')),
      'productRequests': () => liveCount(Fs.productRequests.where('status', isEqualTo: 'open')),
    },
    publicRoutes: [
      GoRoute(path: '/login', pageBuilder: (c, s) => fadeThroughPage(s, const LoginPage())),
      GoRoute(path: '/print/invoice/:id', pageBuilder: (c, s) => fadeThroughPage(s, InvoicePage(id: s.pathParameters['id']!))),
    ],
    search: adminSearch,
  );
}

/// Ctrl+K live search: order numbers, products, customers, sellers.
Future<List<SearchHit>> adminSearch(String q) async {
  final hits = <SearchHit>[];
  final upper = q.toUpperCase();
  final futures = <Future<void>>[];
  if (RegExp(r'^(G4M)?\d{3,}$').hasMatch(upper)) {
    final no = upper.startsWith('G4M') ? upper : 'G4M$upper';
    futures.add(Fs.orders.where('orderNo', isEqualTo: no).limit(3).get().then((s) {
      for (final d in s.docs.map(Doc.fromSnap)) {
        hits.add(SearchHit('Order ${d.s('orderNo')}', '${d.s('customer.name')} · ${Fmt.money(d.n('total'))} · ${OrderStatus.label(d.s('status'))}', '/orders/${d.id}', Icons.receipt_long_rounded));
      }
    }).catchError((_) {}));
  }
  final tokens = q.toLowerCase().split(RegExp(r'[^a-z0-9]+')).where((t) => t.length > 1).take(10).toList();
  if (tokens.isNotEmpty) {
    futures.add(Fs.products.where('keywords', arrayContainsAny: tokens).limit(6).get().then((s) {
      for (final d in s.docs.map(Doc.fromSnap)) {
        hits.add(SearchHit(d.s('name'), 'Product · ${Fmt.money(d.n('price'))} · ${d.s('status')}', '/catalog/products/${d.id}/edit', Icons.inventory_2_rounded));
      }
    }).catchError((_) {}));
  }
  if (q.contains('@')) {
    futures.add(Fs.users.where('email', isEqualTo: q.trim().toLowerCase()).limit(3).get().then((s) {
      for (final d in s.docs.map(Doc.fromSnap)) {
        hits.add(SearchHit(d.s('name', d.s('email')), 'Customer · ${d.s('email')}', '/customers/${d.id}', Icons.person_rounded));
      }
    }).catchError((_) {}));
  } else if (q.length >= 3) {
    final cap = q[0].toUpperCase() + q.substring(1);
    futures.add(Fs.sellers.orderBy('storeName').startAt([cap]).endAt(['$cap']).limit(4).get().then((s) {
      for (final d in s.docs.map(Doc.fromSnap)) {
        hits.add(SearchHit(d.s('storeName'), 'Seller · ${d.s('city')} · ${d.s('status')}', '/sellers/${d.id}', Icons.storefront_rounded));
      }
    }).catchError((_) {}));
    futures.add(Fs.users.orderBy('name').startAt([cap]).endAt(['$cap']).limit(4).get().then((s) {
      for (final d in s.docs.map(Doc.fromSnap)) {
        hits.add(SearchHit(d.s('name'), '${Fmt.titleCase(d.s('role', 'customer'))} · ${d.s('email')}', '/customers/${d.id}', Icons.person_rounded));
      }
    }).catchError((_) {}));
  }
  await Future.wait(futures);
  return hits;
}
