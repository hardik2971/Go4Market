import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/l10n.dart';
import '../shell/shell.dart';
import 'panel.dart';
import 'session.dart';

final rootNavKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final shellNavKey = GlobalKey<NavigatorState>(debugLabel: 'shell');

/// Content-area transition: fade + slight upward slide + subtle scale, 260 ms easeOutCubic.
CustomTransitionPage<void> fadeThroughPage(GoRouterState state, Widget child) => CustomTransitionPage<void>(
      key: state.pageKey,
      name: state.matchedLocation,
      transitionDuration: const Duration(milliseconds: 260),
      reverseTransitionDuration: const Duration(milliseconds: 180),
      child: child,
      transitionsBuilder: (context, animation, secondary, child) {
        final a = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        final out = CurvedAnimation(parent: secondary, curve: Curves.easeInCubic);
        return FadeTransition(
          opacity: Tween<double>(begin: 1, end: 0).animate(out),
          child: FadeTransition(
            opacity: a,
            child: SlideTransition(
              position: Tween(begin: const Offset(0, .018), end: Offset.zero).animate(a),
              child: ScaleTransition(scale: Tween<double>(begin: .985, end: 1).animate(a), child: child),
            ),
          ),
        );
      },
    );

const _gateRoutes = {'/login', '/register', '/pending'};

GoRouter buildRouter(PanelSpec spec) {
  final s = Session.instance;
  return GoRouter(
    navigatorKey: rootNavKey,
    initialLocation: spec.home,
    refreshListenable: s,
    debugLogDiagnostics: false,
    redirect: (context, state) {
      final path = state.uri.path;
      if (!s.ready) return null;
      final from = state.uri.queryParameters['from'];
      String back() => (from != null && from.startsWith('/') && !_gateRoutes.contains(from)) ? from : spec.home;
      final isPrint = path.startsWith('/print/');

      if (!s.signedIn) {
        if (path == '/login' || (path == '/register' && s.panel != PanelRole.admin)) return null;
        return Uri(path: '/login', queryParameters: path == '/' || path == spec.home ? null : {'from': state.uri.toString()}).toString();
      }

      if (s.panel == PanelRole.admin) {
        if (!s.authorized) return path == '/login' ? null : '/login';
        if (_gateRoutes.contains(path) || path == '/') return back();
        return null;
      }

      // Seller / delivery: role + profile gates.
      switch (s.profileState) {
        case ProfileState.none:
          if (s.role == 'admin') return path == '/login' ? null : '/login';
          return path == '/register' ? null : '/register';
        case ProfileState.pending:
        case ProfileState.rejected:
        case ProfileState.suspended:
          return path == '/pending' ? null : '/pending';
        case ProfileState.approved:
          if (_gateRoutes.contains(path) || path == '/') return back();
          if (!isPrint && !s.authorized) {
            // Approved but token not yet refreshed — let the shell load; claims refresh in background.
            s.refreshClaims();
          }
          return null;
      }
    },
    routes: [
      GoRoute(path: '/', redirect: (_, _) => spec.home),
      ...spec.publicRoutes,
      ShellRoute(
        navigatorKey: shellNavKey,
        builder: (context, state, child) => PanelShell(spec: spec, state: state, child: child),
        routes: [
          for (final p in spec.pages)
            GoRoute(
              path: p.path,
              pageBuilder: (context, state) => fadeThroughPage(state, Builder(builder: (c) => p.builder(c, state))),
            ),
        ],
      ),
    ],
    errorPageBuilder: (context, state) => fadeThroughPage(
      state,
      Scaffold(
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.explore_off_rounded, size: 56),
            const SizedBox(height: 12),
            Text(S.pageNotFound, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text(state.uri.toString()),
            const SizedBox(height: 16),
            FilledButton(onPressed: () => context.go(spec.home), child: Text(S.backToDashboard)),
          ]),
        ),
      ),
    ),
  );
}

/// Matches a concrete location against a `/a/:b/c` pattern.
bool matchPattern(String pattern, String location) {
  final p = pattern.split('/'), l = location.split('/');
  if (p.length != l.length) return false;
  for (var i = 0; i < p.length; i++) {
    if (p[i].startsWith(':')) continue;
    if (p[i] != l[i]) return false;
  }
  return true;
}
