import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:g4m_core/g4m_core.dart' hide Fmt;
import 'package:go_router/go_router.dart';

import '../core/doc.dart';
import '../core/live.dart';
import '../core/panel.dart';
import '../core/router.dart';
import '../core/session.dart';
import '../core/web_utils.dart';
import '../l10n/lang_picker.dart';
import '../ui/kit.dart';
import 'command_palette.dart';
import 'push.dart';
import 'package:panel/l10n/overrides.dart';

const _sidebarW = 268.0;
const _sidebarCollapsedW = 78.0;

/// Persistent chrome around every shell page.
class PanelShell extends StatefulWidget {
  const PanelShell({super.key, required this.spec, required this.state, required this.child});
  final PanelSpec spec;
  final GoRouterState state;
  final Widget child;
  @override
  State<PanelShell> createState() => _PanelShellState();
}

class _PanelShellState extends State<PanelShell> {
  bool? _collapsed;
  final _scaffold = GlobalKey<ScaffoldState>();
  late final Map<String, Stream<int>> _badges = {for (final e in widget.spec.badges.entries) e.key: e.value().asBroadcastStream()};

  String get _loc => widget.state.uri.path;

  void _openPalette() => showCommandPalette(context, widget.spec);

  @override
  void didUpdateWidget(covariant PanelShell old) {
    super.didUpdateWidget(old);
    _updateTitle();
  }

  @override
  void initState() {
    super.initState();
    _updateTitle();
  }

  void _updateTitle() {
    final page = widget.spec.pages.where((p) => matchPattern(p.path, _loc)).firstOrNull;
    setDocumentTitle('${tr(page?.title ?? 'Dashboard')} · Go4Market ${tr(session.panel.title)}');
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final mobile = w < 760;
    final collapsed = _collapsed ?? w < 1180;
    final sidebar = Sidebar(
      spec: widget.spec,
      location: _loc,
      collapsed: mobile ? false : collapsed,
      badges: _badges,
      onNavigate: (p) {
        if (mobile) Navigator.of(context).maybePop();
        context.go(p);
      },
    );
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): _openPalette,
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true): _openPalette,
        const SingleActivator(LogicalKeyboardKey.slash): _openPalette,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          key: _scaffold,
          backgroundColor: context.pal.bg,
          drawer: mobile ? Drawer(width: _sidebarW, child: sidebar) : null,
          body: Row(children: [
            if (!mobile)
              AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                width: collapsed ? _sidebarCollapsedW : _sidebarW,
                child: sidebar,
              ),
            Expanded(
              child: Column(children: [
                TopBar(
                  spec: widget.spec,
                  location: _loc,
                  mobile: mobile,
                  onMenu: () => mobile ? _scaffold.currentState?.openDrawer() : setState(() => _collapsed = !collapsed),
                  onSearch: _openPalette,
                ),
                Expanded(
                  child: ClipRect(child: widget.child),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

// ───────────────────────── Sidebar ─────────────────────────

class Sidebar extends StatefulWidget {
  const Sidebar({super.key, required this.spec, required this.location, required this.collapsed, required this.badges, required this.onNavigate});
  final PanelSpec spec;
  final String location;
  final bool collapsed;
  final Map<String, Stream<int>> badges;
  final ValueChanged<String> onNavigate;
  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  final _open = <String>{};
  final _keys = <String, GlobalKey>{};
  final _stackKey = GlobalKey();
  final _scroll = ScrollController();
  double? _indTop;
  double _indH = 40;

  @override
  void initState() {
    super.initState();
    _autoOpen();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  @override
  void didUpdateWidget(covariant Sidebar old) {
    super.didUpdateWidget(old);
    if (old.location != widget.location) _autoOpen();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
    // Measure again after group expand animations settle.
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _measure();
    });
  }

  void _autoOpen() {
    for (final s in widget.spec.nav) {
      for (final i in s.items) {
        if (i.children.isNotEmpty && i.matches(widget.location)) _open.add(i.label);
      }
    }
  }

  /// Most specific nav path that matches the current location.
  String? get _activePath {
    String? best;
    void visit(NavItem i) {
      final p = i.path;
      if (p != null && (widget.location == p || widget.location.startsWith('$p/')) && (best == null || p.length > best!.length)) best = p;
      for (final c in i.children) {
        visit(c);
      }
    }

    for (final s in widget.spec.nav) {
      for (final i in s.items) {
        visit(i);
      }
    }
    return best;
  }

  void _measure() {
    final active = _activePath;
    // When collapsed, child items aren't shown: indicate on the parent group instead.
    String? target = active;
    if (active != null) {
      for (final s in widget.spec.nav) {
        for (final i in s.items) {
          if (i.children.any((c) => c.path == active) && (widget.collapsed || !_open.contains(i.label))) target = 'group:${i.label}';
        }
      }
    }
    final key = target == null ? null : _keys[target];
    final stackBox = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    final box = key?.currentContext?.findRenderObject() as RenderBox?;
    if (stackBox == null || box == null || !box.attached) {
      if (_indTop != null) setState(() => _indTop = null);
      return;
    }
    final top = box.localToGlobal(Offset.zero, ancestor: stackBox).dy;
    if (top != _indTop || box.size.height != _indH) {
      setState(() {
        _indTop = top;
        _indH = box.size.height;
      });
    }
  }

  GlobalKey _k(String id) => _keys.putIfAbsent(id, GlobalKey.new);

  @override
  Widget build(BuildContext context) {
    final accent = session.accent;
    final c = widget.collapsed;
    final active = _activePath;
    final en = L10n.instance.code == 'en';
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF07291D), Color(0xFF0A1F17)],
        ),
      ),
      child: Column(children: [
        // Brand
        SizedBox(
          height: 68,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: c ? 0 : 20),
            child: Row(
              mainAxisAlignment: c ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                if (c)
                  const G4MLogo(size: 34)
                else ...[
                  const Flexible(child: G4MWordmark(size: 32, light: true)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(color: accent.withValues(alpha: .25), borderRadius: BorderRadius.circular(6)),
                    child: Text(en ? session.panel.title.toUpperCase() : tr(session.panel.title),
                        style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: .8)),
                  ),
                ],
              ],
            ),
          ),
        ),
        Container(height: 1, color: Colors.white.withValues(alpha: .06)),
        Expanded(
          child: NotificationListener<ScrollNotification>(
            onNotification: (_) => false,
            child: SingleChildScrollView(
              controller: _scroll,
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Stack(key: _stackKey, children: [
                if (_indTop != null)
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeOutCubic,
                    top: _indTop,
                    left: c ? 12 : 12,
                    right: c ? 12 : 12,
                    height: _indH,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        gradient: LinearGradient(
                            begin: AlignmentDirectional.centerStart,
                            end: AlignmentDirectional.centerEnd,
                            colors: [accent.withValues(alpha: .34), accent.withValues(alpha: .12)]),
                        border: Border.all(color: accent.withValues(alpha: .35)),
                      ),
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Container(width: 3, height: _indH * .5, decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(3))),
                      ),
                    ),
                  ),
                Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  for (final s in widget.spec.nav) ...[
                    if (s.items.any((i) => i.permission == null || session.can(i.permission!))) ...[
                      if (!c)
                        Padding(
                          padding: const EdgeInsetsDirectional.fromSTEB(24, 14, 16, 6),
                          child: Text(en ? s.title.toUpperCase() : tr(s.title),
                              style: TextStyle(color: Colors.white.withValues(alpha: .38), fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 1.1)),
                        )
                      else
                        Padding(padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 24), child: Container(height: 1, color: Colors.white.withValues(alpha: .07))),
                      for (final i in s.items)
                        if (i.permission == null || session.can(i.permission!)) _item(context, i, active),
                    ],
                  ],
                ]),
              ]),
            ),
          ),
        ),
        _footer(context),
      ]),
    );
  }

  Widget _item(BuildContext context, NavItem i, String? active) {
    final c = widget.collapsed;
    final isGroup = i.children.isNotEmpty;
    final open = _open.contains(i.label);
    final selected = !isGroup && i.path == active;
    final groupActive = isGroup && i.matches(widget.location);
    final rtl = Directionality.of(context) == TextDirection.rtl;

    Widget tile = _NavTile(
      key: _k(isGroup ? 'group:${i.label}' : i.path!),
      icon: i.icon,
      label: i.label,
      collapsed: c,
      selected: selected || (groupActive && (c || !open)),
      highlight: groupActive,
      badge: _badgeFor(i),
      trailing: isGroup && !c
          ? AnimatedRotation(
              turns: open ? (rtl ? -.25 : .25) : 0,
              duration: G4MMotion.standard,
              child: Icon(Icons.chevron_right_rounded, size: 18, color: Colors.white.withValues(alpha: .5)),
            )
          : null,
      onTap: () {
        if (isGroup) {
          if (c) return; // handled by popup
          setState(() => open ? _open.remove(i.label) : _open.add(i.label));
          Future.delayed(const Duration(milliseconds: 260), () {
            if (mounted) _measure();
          });
        } else {
          widget.onNavigate(i.path!);
        }
      },
    );

    if (isGroup && c) {
      tile = PopupMenuButton<String>(
        tooltip: tr(i.label),
        offset: Offset(rtl ? -(_sidebarCollapsedW - 8) : _sidebarCollapsedW - 8, 0),
        onSelected: widget.onNavigate,
        itemBuilder: (_) => [
          PopupMenuItem(enabled: false, child: Text(tr(i.label), style: const TextStyle(fontWeight: FontWeight.w800))),
          for (final ch in i.children)
            if (ch.permission == null || session.can(ch.permission!))
              PopupMenuItem(
                value: ch.path,
                child: Row(children: [
                  Icon(ch.icon, size: 18),
                  const SizedBox(width: 10),
                  Expanded(child: Text(tr(ch.label))),
                  if (ch.badge != null) _BadgeCount(stream: widget.badges[ch.badge]),
                ]),
              ),
        ],
        child: IgnorePointer(child: tile),
      );
    } else if (c) {
      tile = Tooltip(message: tr(i.label), preferBelow: false, child: tile);
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      tile,
      if (isGroup && !c)
        AnimatedSize(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: open
              ? Padding(
                  padding: const EdgeInsetsDirectional.only(start: 20),
                  child: Container(
                    margin: const EdgeInsetsDirectional.only(start: 18),
                    decoration: BoxDecoration(border: BorderDirectional(start: BorderSide(color: Colors.white.withValues(alpha: .08)))),
                    child: Column(children: [
                      for (final ch in i.children)
                        if (ch.permission == null || session.can(ch.permission!))
                          _NavTile(
                            key: _k(ch.path!),
                            icon: ch.icon,
                            label: ch.label,
                            collapsed: false,
                            dense: true,
                            selected: ch.path == active,
                            badge: ch.badge == null ? null : widget.badges[ch.badge],
                            onTap: () => widget.onNavigate(ch.path!),
                          ),
                    ]),
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
    ]);
  }

  Stream<int>? _badgeFor(NavItem i) {
    if (i.badge != null) return widget.badges[i.badge];
    final keys = i.children.map((c) => c.badge).whereType<String>().map((k) => widget.badges[k]).whereType<Stream<int>>().toList();
    if (keys.isEmpty) return null;
    if (keys.length == 1) return keys.first;
    return _combine(keys);
  }

  Stream<int> _combine(List<Stream<int>> streams) {
    final vals = List<int>.filled(streams.length, 0);
    late StreamController<int> c;
    final subs = <StreamSubscription>[];
    c = StreamController<int>(
      onListen: () {
        for (var i = 0; i < streams.length; i++) {
          subs.add(streams[i].listen((v) {
            vals[i] = v;
            c.add(vals.fold(0, (a, b) => a + b));
          }));
        }
      },
      onCancel: () {
        for (final s in subs) {
          s.cancel();
        }
      },
    );
    return c.stream;
  }

  Widget _footer(BuildContext context) {
    final c = widget.collapsed;
    return Container(
      padding: EdgeInsets.all(c ? 10 : 14),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.white.withValues(alpha: .06)))),
      child: ListenableBuilder(
        listenable: session,
        builder: (context, _) => Row(mainAxisAlignment: c ? MainAxisAlignment.center : MainAxisAlignment.start, children: [
          Avatar(name: session.displayName, size: 36, color: session.accent, url: session.profile?.s(session.panel == PanelRole.seller ? 'logo' : 'photoUrl') ?? ''),
          if (!c) ...[
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(session.displayName,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                Text(session.panel == PanelRole.admin ? tr(session.staffRoleName) : (session.user?.email ?? ''),
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white.withValues(alpha: .5), fontSize: 11.5)),
              ]),
            ),
            IconButton(
              tooltip: S.signOut,
              onPressed: () async {
                if (await confirm(context, S.signOutQ, confirmLabel: S.signOut)) await session.signOut();
              },
              icon: Icon(Icons.logout_rounded, color: Colors.white.withValues(alpha: .6), size: 19),
            ),
          ],
        ]),
      ),
    );
  }
}

class _NavTile extends StatefulWidget {
  const _NavTile({
    super.key,
    required this.icon,
    required this.label,
    required this.collapsed,
    required this.selected,
    required this.onTap,
    this.highlight = false,
    this.badge,
    this.trailing,
    this.dense = false,
  });
  final IconData icon;
  final String label;
  final bool collapsed;
  final bool selected;
  final bool highlight;
  final VoidCallback onTap;
  final Stream<int>? badge;
  final Widget? trailing;
  final bool dense;
  @override
  State<_NavTile> createState() => _NavTileState();
}

class _NavTileState extends State<_NavTile> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final on = widget.selected || widget.highlight;
    final fg = on ? Colors.white : Colors.white.withValues(alpha: _hover ? .92 : .68);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: G4MMotion.fast,
          margin: EdgeInsets.symmetric(horizontal: 12, vertical: widget.dense ? 1 : 2),
          padding: EdgeInsets.symmetric(horizontal: widget.collapsed ? 0 : 14, vertical: widget.dense ? 8 : 10),
          decoration: BoxDecoration(
            color: _hover && !widget.selected ? Colors.white.withValues(alpha: .05) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(mainAxisAlignment: widget.collapsed ? MainAxisAlignment.center : MainAxisAlignment.start, children: [
            Stack(clipBehavior: Clip.none, children: [
              Icon(widget.icon, size: widget.dense ? 18 : 20, color: widget.selected ? Colors.white : fg),
              if (widget.collapsed && widget.badge != null)
                PositionedDirectional(end: -6, top: -6, child: _BadgeCount(stream: widget.badge, dot: true)),
            ]),
            if (!widget.collapsed) ...[
              const SizedBox(width: 12),
              Expanded(
                child: Text(tr(widget.label),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: fg, fontWeight: on ? FontWeight.w700 : FontWeight.w500, fontSize: widget.dense ? 13 : 13.8)),
              ),
              if (widget.badge != null) _BadgeCount(stream: widget.badge),
              if (widget.trailing != null) ...[const SizedBox(width: 4), widget.trailing!],
            ],
          ]),
        ),
      ),
    );
  }
}

class _BadgeCount extends StatelessWidget {
  const _BadgeCount({required this.stream, this.dot = false});
  final Stream<int>? stream;
  final bool dot;
  @override
  Widget build(BuildContext context) => StreamBuilder<int>(
        stream: stream,
        builder: (context, s) {
          final n = s.data ?? 0;
          if (n <= 0) return const SizedBox();
          return Container(
            padding: EdgeInsets.symmetric(horizontal: dot ? 4 : 7, vertical: dot ? 1 : 2),
            constraints: const BoxConstraints(minWidth: 18),
            decoration: BoxDecoration(color: G4MColors.accent, borderRadius: BorderRadius.circular(99)),
            child: Text(n >= 99 ? '99+' : '$n',
                textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: dot ? 9 : 10.5, fontWeight: FontWeight.w800)),
          ).animate(key: ValueKey(n)).scale(begin: const Offset(.6, .6), duration: 260.ms, curve: Curves.easeOutBack);
        },
      );
}

// ───────────────────────── Top bar ─────────────────────────

class TopBar extends StatelessWidget {
  const TopBar({super.key, required this.spec, required this.location, required this.mobile, required this.onMenu, required this.onSearch});
  final PanelSpec spec;
  final String location;
  final bool mobile;
  final VoidCallback onMenu;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width > 1000;
    return Container(
      height: 64,
      padding: EdgeInsets.symmetric(horizontal: mobile ? 8 : 16),
      decoration: BoxDecoration(
        color: context.pal.surface.withValues(alpha: .92),
        border: Border(bottom: BorderSide(color: context.pal.line)),
      ),
      child: Row(children: [
        IconButton(tooltip: S.menu, onPressed: onMenu, icon: const Icon(Icons.menu_rounded)),
        const SizedBox(width: 6),
        Expanded(child: mobile ? const G4MWordmark(size: 26) : Breadcrumbs(spec: spec, location: location)),
        if (wide)
          _SearchButton(onTap: onSearch)
        else
          IconButton(tooltip: S.searchShort, onPressed: onSearch, icon: const Icon(Icons.search_rounded)),
        const SizedBox(width: 6),
        if (session.panel == PanelRole.admin) const ModuleSwitcher(),
        LanguagePicker(compact: !wide),
        ListenableBuilder(
          listenable: session,
          builder: (context, _) => IconButton(
            tooltip: session.themeMode == ThemeMode.dark ? S.lightMode : S.darkMode,
            onPressed: session.toggleTheme,
            icon: AnimatedSwitcher(
              duration: G4MMotion.standard,
              transitionBuilder: (c, a) => RotationTransition(turns: Tween(begin: .6, end: 1.0).animate(a), child: FadeTransition(opacity: a, child: c)),
              child: Icon(session.themeMode == ThemeMode.dark ? Icons.light_mode_rounded : Icons.dark_mode_outlined, key: ValueKey(session.themeMode)),
            ),
          ),
        ),
        const NotificationBell(),
        const SizedBox(width: 4),
        const ProfileMenu(),
      ]),
    );
  }
}

class _SearchButton extends StatelessWidget {
  const _SearchButton({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 280,
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: context.pal.surfaceAlt.withValues(alpha: .7),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: context.pal.line),
          ),
          child: Row(children: [
            Icon(Icons.search_rounded, size: 19, color: context.pal.muted),
            const SizedBox(width: 8),
            Expanded(child: Text(S.searchHint, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.pal.muted, fontSize: 13))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: context.pal.surface, borderRadius: BorderRadius.circular(6), border: Border.all(color: context.pal.line)),
              child: Text('Ctrl K', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: context.pal.muted)),
            ),
          ]),
        ),
      );
}

class Breadcrumbs extends StatelessWidget {
  const Breadcrumbs({super.key, required this.spec, required this.location});
  final PanelSpec spec;
  final String location;
  @override
  Widget build(BuildContext context) {
    final segs = location.split('/').where((s) => s.isNotEmpty).toList();
    final crumbs = <(String, String?)>[];
    for (var i = 0; i < segs.length; i++) {
      final prefix = '/${segs.sublist(0, i + 1).join('/')}';
      final page = spec.pages.where((p) => matchPattern(p.path, prefix)).firstOrNull;
      if (page != null) {
        final isParam = page.path.split('/').last.startsWith(':');
        crumbs.add((isParam ? (segs[i].length > 10 ? '#${segs[i].substring(0, 8)}' : '#${segs[i]}') : tr(page.title), prefix));
      } else {
        crumbs.add((tr(Fmt.titleCase(segs[i].replaceAll('-', ' '))), null));
      }
    }
    if (crumbs.isNotEmpty) {
      final last = spec.pages.where((p) => matchPattern(p.path, location)).firstOrNull;
      if (last != null && !last.path.split('/').last.startsWith(':')) crumbs[crumbs.length - 1] = (tr(last.title), location);
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        InkWell(
          onTap: () => context.go(spec.home),
          borderRadius: BorderRadius.circular(6),
          child: Padding(padding: const EdgeInsets.all(4), child: Icon(Icons.home_rounded, size: 18, color: context.pal.muted)),
        ),
        for (var i = 0; i < crumbs.length; i++) ...[
          Icon(Icons.chevron_right_rounded, size: 16, color: context.pal.faint),
          if (i == crumbs.length - 1 || crumbs[i].$2 == null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(crumbs[i].$1,
                  style: TextStyle(
                    fontWeight: i == crumbs.length - 1 ? FontWeight.w800 : FontWeight.w500,
                    color: i == crumbs.length - 1 ? context.pal.ink : context.pal.muted,
                    fontSize: 13.5,
                  )),
            )
          else
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: context.pal.muted,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                minimumSize: const Size(0, 30),
                textStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13.5),
              ),
              onPressed: () => context.go(crumbs[i].$2!),
              child: Text(crumbs[i].$1),
            ),
        ],
      ]),
    );
  }
}

/// Admin module switcher: scopes dashboard/catalog views and re-themes the panel.
class ModuleSwitcher extends StatelessWidget {
  const ModuleSwitcher({super.key});
  @override
  Widget build(BuildContext context) => StreamBuilder<List<Doc>>(
        stream: liveDocs(Fs.modules.orderBy('order'), fallback: Fs.modules, sortField: 'order', desc: false, label: 'modules'),
        builder: (context, snap) {
          final mods = snap.data ?? const [];
          final current = mods.where((m) => m.id == session.moduleId).firstOrNull;
          return PopupMenuButton<String>(
            tooltip: S.switchModule,
            position: PopupMenuPosition.under,
            onSelected: (id) {
              if (id == '__all') {
                session.setModule(null, G4MColors.primary);
              } else {
                final m = mods.firstWhere((m) => m.id == id);
                session.setModule(id, G4MColors.fromHex(m.s('themeColor'), G4MColors.primary));
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: '__all', child: ListTile(dense: true, leading: const Icon(Icons.apps_rounded), title: Text(S.allModules))),
              for (final m in mods)
                PopupMenuItem(
                  value: m.id,
                  child: ListTile(
                    dense: true,
                    leading: CircleAvatar(radius: 8, backgroundColor: G4MColors.fromHex(m.s('themeColor'))),
                    title: Text(tr(m.s('name', m.id))),
                    subtitle: m.b('enabled', true) ? null : Text(S.disabled),
                    trailing: m.id == session.moduleId ? const Icon(Icons.check_rounded, size: 18) : null,
                  ),
                ),
            ],
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: session.accent.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: session.accent.withValues(alpha: .3)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.storefront_rounded, size: 17, color: session.accent),
                if (MediaQuery.sizeOf(context).width > 900) ...[
                  const SizedBox(width: 6),
                  Text(current == null ? S.allModules : tr(current.s('name')), style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: session.accent)),
                ],
                Icon(Icons.expand_more_rounded, size: 17, color: session.accent),
              ]),
            ),
          );
        },
      );
}

class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key});
  @override
  Widget build(BuildContext context) {
    final uid = session.uid;
    if (uid.isEmpty) return const SizedBox();
    final q = Fs.inbox(uid).orderBy('createdAt', descending: true).limit(30);
    return StreamBuilder<List<Doc>>(
      stream: liveDocs(q, fallback: Fs.inbox(uid).limit(30), label: 'inbox'),
      builder: (context, snap) {
        final items = snap.data ?? const [];
        final unread = items.where((d) => !d.b('read')).length;
        return PopupMenuButton<int>(
          tooltip: S.notifications,
          position: PopupMenuPosition.under,
          constraints: const BoxConstraints(minWidth: 360, maxWidth: 380),
          itemBuilder: (_) => [
            PopupMenuItem(
              enabled: false,
              child: Row(children: [
                Text(S.notifications, style: TextStyle(fontWeight: FontWeight.w800, color: context.pal.ink, fontSize: 15)),
                const Spacer(),
                if (unread > 0)
                  TextButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      final b = Fs.db.batch();
                      for (final d in items.where((d) => !d.b('read'))) {
                        b.update(d.ref!, {'read': true});
                      }
                      await b.commit();
                    },
                    child: Text(S.markAllRead),
                  ),
              ]),
            ),
            if (items.isEmpty)
              PopupMenuItem(
                enabled: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(child: Text(S.allCaughtUp, style: TextStyle(color: context.pal.muted))),
                ),
              ),
            for (final n in items.take(12))
              PopupMenuItem(
                onTap: () {
                  if (!n.b('read')) n.ref!.update({'read': true});
                  final orderId = n.s('data.orderId');
                  if (orderId.isNotEmpty) context.go('/orders/$orderId');
                },
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    margin: const EdgeInsetsDirectional.only(top: 6, end: 10),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: n.b('read') ? Colors.transparent : session.accent, shape: BoxShape.circle),
                  ),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(n.s('title'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                      Text(n.s('body'), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: context.pal.muted)),
                      Text(Fmt.ago(n.createdAt), style: TextStyle(fontSize: 11, color: context.pal.faint)),
                    ]),
                  ),
                ]),
              ),
          ],
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Badge(
              isLabelVisible: unread > 0,
              label: Text(unread > 9 ? '9+' : '$unread'),
              backgroundColor: G4MColors.accent,
              child: Icon(unread > 0 ? Icons.notifications_active_rounded : Icons.notifications_none_rounded),
            ),
          ),
        );
      },
    );
  }
}

class ProfileMenu extends StatelessWidget {
  const ProfileMenu({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: session,
        builder: (context, _) => PopupMenuButton<String>(
          tooltip: S.account,
          position: PopupMenuPosition.under,
          onSelected: (v) async {
            switch (v) {
              case 'profile':
                context.go(switch (session.panel) { PanelRole.admin => '/account', PanelRole.seller => '/store', PanelRole.delivery => '/profile' });
              case 'theme':
                session.toggleTheme();
              case 'push':
                await PushService.toggle();
              case 'logout':
                if (await confirm(context, S.signOutQ, confirmLabel: S.signOut)) await session.signOut();
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              enabled: false,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Avatar(name: session.displayName, color: session.accent),
                title: Text(session.displayName, style: TextStyle(fontWeight: FontWeight.w800, color: context.pal.ink)),
                subtitle: Text(session.user?.email ?? ''),
              ),
            ),
            const PopupMenuDivider(),
            PopupMenuItem(value: 'profile', child: ListTile(dense: true, leading: const Icon(Icons.person_outline_rounded), title: Text(S.myAccount))),
            PopupMenuItem(
              value: 'theme',
              child: ListTile(
                dense: true,
                leading: Icon(session.themeMode == ThemeMode.dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
                title: Text(session.themeMode == ThemeMode.dark ? S.lightMode : S.darkMode),
              ),
            ),
            if (PushService.supported)
              PopupMenuItem(
                value: 'push',
                child: ListTile(
                  dense: true,
                  leading: Icon(PushService.enabled.value ? Icons.notifications_active_outlined : Icons.notifications_off_outlined),
                  title: Text(S.enableNotifications),
                  trailing: IgnorePointer(child: Switch(value: PushService.enabled.value, onChanged: (_) {})),
                ),
              ),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: 'logout',
              child: ListTile(dense: true, leading: const Icon(Icons.logout_rounded, color: G4MColors.danger), title: Text(S.signOut, style: const TextStyle(color: G4MColors.danger))),
            ),
          ],
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Avatar(name: session.displayName, size: 34, color: session.accent),
          ),
        ),
      );
}
