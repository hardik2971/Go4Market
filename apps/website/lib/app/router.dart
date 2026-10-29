import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../pages/account_page.dart' deferred as account;
import '../pages/auth_pages.dart';
import '../pages/cart_page.dart' deferred as cart;
import '../pages/catalog_pages.dart';
import '../pages/content_pages.dart' deferred as content;
import '../pages/home_page.dart';
import '../pages/not_found_page.dart';
import '../pages/orders_pages.dart' deferred as orders;
import '../pages/payment_return_page.dart' deferred as payret;
import '../pages/product_page.dart';
import '../pages/search_page.dart';
import '../pages/store_page.dart';
import '../pages/wallet_page.dart' deferred as wallet;
import '../pages/wishlist_page.dart';
import '../l10n/l10n.dart';
import '../ui/lazy.dart';
import '../ui/shell.dart';

/// Fade + gentle rise between pages; instant when the user prefers reduced motion.
Page<void> _page(GoRouterState s, Widget child) => CustomTransitionPage<void>(
      key: s.pageKey,
      // Rebuild the page from scratch when the language changes, so strings cached in state are refreshed.
      child: KeyedSubtree(key: ValueKey('lang-${LangController.instance.code}'), child: child),
      transitionDuration: const Duration(milliseconds: 360),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      transitionsBuilder: (context, a, _, child) {
        if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return child;
        final c = CurvedAnimation(parent: a, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: c,
          child: SlideTransition(position: Tween(begin: const Offset(0, .015), end: Offset.zero).animate(c), child: child),
        );
      },
    );

GoRoute _r(String path, Widget Function(GoRouterState s) b) => GoRoute(path: path, pageBuilder: (_, s) => _page(s, b(s)));

/// Route whose page code lives in a deferred chunk (keeps the first download small).
GoRoute _lazy(String path, Future<void> Function() load, Widget Function(GoRouterState s) b) =>
    GoRoute(path: path, pageBuilder: (_, s) => _page(s, Deferred(key: ValueKey(s.uri.toString()), load: load, builder: (_) => b(s))));

final appRouter = GoRouter(
  initialLocation: '/',
  // Rebuild pages (re-keyed per language in _page / the shell) when the language changes.
  refreshListenable: LangController.instance,
  errorPageBuilder: (_, s) => _page(s, const NotFoundPage()),
  redirect: (_, s) => switch (s.uri.path) {
    '/membership' => '/account?tab=membership',
    '/subscriptions' => '/account?tab=subscriptions',
    '/notifications' => '/account?tab=notifications',
    '/addresses' => '/account?tab=addresses',
    '/referral' || '/refer' => '/account?tab=refer',
    '/returns' => '/account?tab=returns',
    '/profile' => '/account',
    '/faqs' || '/help' => '/faq',
    '/stores' => '/categories',
    '/about' || '/terms' || '/privacy' || '/refund' || '/shipping' || '/cancellation' => '/page${s.uri.path}',
    _ => null,
  },
  routes: [
    ShellRoute(
      builder: (_, s, child) => KeyedSubtree(key: ValueKey('lang-${LangController.instance.code}'), child: SiteShell(location: s.uri.path, child: child)),
      routes: [
        _r('/', (_) => const HomePage()),
        _r('/m/:module', (s) => HomePage(key: ValueKey(s.pathParameters['module']), moduleId: s.pathParameters['module'])),
        _r('/categories', (s) => CategoriesPage(moduleId: s.uri.queryParameters['module'])),
        _r('/c/:slug', (s) => CategoryPage(key: ValueKey(s.pathParameters['slug']), slug: s.pathParameters['slug']!)),
        _r('/p/:slug', (s) => ProductPage(key: ValueKey(s.pathParameters['slug']), slug: s.pathParameters['slug']!)),
        _r('/search', (s) => SearchPage(key: ValueKey(s.uri.query), params: s.uri.queryParameters)),
        _r('/store/:slug', (s) => StorePage(key: ValueKey(s.pathParameters['slug']), slug: s.pathParameters['slug']!)),
        _r('/wishlist', (_) => const WishlistPage()),
        _lazy('/cart', cart.loadLibrary, (_) => cart.CartPage()),
        _lazy('/payment/return', payret.loadLibrary, (s) => payret.PaymentReturnPage(params: s.uri.queryParameters)),
        _lazy('/orders', orders.loadLibrary, (_) => orders.OrdersPage()),
        _lazy('/orders/:id', orders.loadLibrary, (s) => orders.OrderDetailPage(key: ValueKey(s.pathParameters['id']), orderId: s.pathParameters['id']!)),
        _lazy('/wallet', wallet.loadLibrary, (_) => wallet.WalletPage()),
        _lazy('/account', account.loadLibrary, (s) => account.AccountPage(key: ValueKey(s.uri.query), params: s.uri.queryParameters)),
        _lazy('/blog', content.loadLibrary, (_) => content.BlogListPage()),
        _lazy('/blog/:slug', content.loadLibrary, (s) => content.BlogPostPage(key: ValueKey(s.pathParameters['slug']), slug: s.pathParameters['slug']!)),
        _lazy('/faq', content.loadLibrary, (_) => content.FaqPage()),
        _lazy('/page/:slug', content.loadLibrary, (s) => content.CmsPageView(key: ValueKey(s.pathParameters['slug']), slug: s.pathParameters['slug']!)),
        _r('/login', (s) => LoginPage(next: s.uri.queryParameters['next'])),
        _r('/signup', (s) => SignupPage(next: s.uri.queryParameters['next'], referral: s.uri.queryParameters['ref'])),
        _r('/forgot-password', (_) => const ForgotPasswordPage()),
      ],
    ),
  ],
);
