import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// A routable page inside the shell.
class PageDef {
  const PageDef(
    this.path,
    this.title,
    this.builder, {
    this.icon,
    this.searchable = true,
    this.keywords = '',
    this.permission,
    this.crumb,
  });

  /// Absolute path, may include `:params` (e.g. `/orders/:id`).
  final String path;
  final String title;
  final Widget Function(BuildContext context, GoRouterState state) builder;
  final IconData? icon;

  /// Listed in the Ctrl+K command palette (only param-less paths).
  final bool searchable;
  final String keywords;
  final String? permission;

  /// Breadcrumb label for a param segment (e.g. order no) – defaults to title.
  final String Function(GoRouterState state)? crumb;

  bool get hasParams => path.contains(':');
}

/// Sidebar item; [children] makes it a collapsible group.
class NavItem {
  const NavItem(this.label, this.icon, {this.path, this.children = const [], this.badge, this.permission});
  final String label;
  final IconData icon;
  final String? path;
  final List<NavItem> children;

  /// Key into [PanelSpec.badges].
  final String? badge;
  final String? permission;

  bool matches(String location) {
    if (path != null && (location == path || location.startsWith('$path/'))) return true;
    return children.any((c) => c.matches(location));
  }
}

class NavSection {
  const NavSection(this.title, this.items);
  final String title;
  final List<NavItem> items;
}

/// Everything that differs between admin / seller / delivery.
class PanelSpec {
  const PanelSpec({
    required this.pages,
    required this.nav,
    required this.badges,
    this.publicRoutes = const [],
    this.home = '/dashboard',
    this.search,
  });
  final List<PageDef> pages;
  final List<NavSection> nav;

  /// badge key -> live count stream factory.
  final Map<String, Stream<int> Function()> badges;

  /// Full-screen routes outside the shell (login, onboarding, print views…).
  final List<GoRoute> publicRoutes;
  final String home;

  /// Optional live entity search for the command palette.
  final Future<List<SearchHit>> Function(String query)? search;
}

/// Result row for the Ctrl+K palette's live entity search.
class SearchHit {
  const SearchHit(this.title, this.subtitle, this.path, this.icon);
  final String title;
  final String subtitle;
  final String path;
  final IconData icon;
}
