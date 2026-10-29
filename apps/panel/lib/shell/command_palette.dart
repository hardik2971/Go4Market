import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../core/panel.dart';
import '../core/session.dart';
import '../l10n/l10n.dart';
import '../ui/kit.dart';

class _Entry {
  _Entry(this.title, this.subtitle, this.icon, this.run, {String? group, this.en = ''}) : group = group ?? S.pages;
  final String title;

  /// English title, so searching in English still works in another UI language.
  final String en;
  final String subtitle;
  final IconData icon;
  final VoidCallback run;
  final String group;
}

bool _open = false;

/// Ctrl+K command palette: jump to any page, run quick actions, live entity search.
Future<void> showCommandPalette(BuildContext context, PanelSpec spec) async {
  if (_open) return;
  _open = true;
  final router = GoRouter.of(context);
  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: Colors.black.withValues(alpha: .4),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (ctx, _, _) => _Palette(spec: spec, router: router),
    transitionBuilder: (ctx, a, _, child) {
      final c = CurvedAnimation(parent: a, curve: Curves.easeOutCubic);
      return FadeTransition(opacity: c, child: ScaleTransition(scale: Tween(begin: .96, end: 1.0).animate(c), child: child));
    },
  );
  _open = false;
}

class _Palette extends StatefulWidget {
  const _Palette({required this.spec, required this.router});
  final PanelSpec spec;
  final GoRouter router;
  @override
  State<_Palette> createState() => _PaletteState();
}

class _PaletteState extends State<_Palette> {
  final _c = TextEditingController();
  final _scroll = ScrollController();
  int _sel = 0;
  List<SearchHit> _hits = const [];
  Timer? _debounce;
  bool _searching = false;

  List<_Entry> get _static {
    void go(String p) {
      Navigator.pop(context);
      widget.router.go(p);
    }

    return [
      for (final p in widget.spec.pages)
        if (p.searchable && !p.hasParams && (p.permission == null || session.can(p.permission!)))
          _Entry(tr(p.title), p.path, p.icon ?? Icons.arrow_forward_rounded, () => go(p.path), en: p.title),
      _Entry(S.toggleDark, S.appearance, Icons.dark_mode_outlined, () {
        Navigator.pop(context);
        session.toggleTheme();
      }, group: S.actions, en: 'Toggle dark mode'),
      _Entry(S.signOut, S.account, Icons.logout_rounded, () {
        Navigator.pop(context);
        session.signOut();
      }, group: S.actions, en: 'Sign out'),
    ];
  }

  List<_Entry> _results() {
    final q = _c.text.trim().toLowerCase();
    final kw = {for (final p in widget.spec.pages) p.path: p.keywords.toLowerCase()};
    final list = _static.where((e) {
      if (q.isEmpty) return true;
      final hay = '${e.title} ${e.en} ${e.subtitle} ${kw[e.subtitle] ?? ''}'.toLowerCase();
      return q.split(' ').every(hay.contains);
    }).toList();
    if (q.isNotEmpty) {
      list.sort((a, b) {
        final sa = a.title.toLowerCase().startsWith(q) ? 0 : 1, sb = b.title.toLowerCase().startsWith(q) ? 0 : 1;
        return sa.compareTo(sb);
      });
    }
    return [
      for (final h in _hits)
        _Entry(h.title, h.subtitle, h.icon, () {
          Navigator.pop(context);
          widget.router.go(h.path);
        }, group: S.records),
      ...list.take(q.isEmpty ? 40 : 30),
    ];
  }

  void _onChanged(String v) {
    setState(() => _sel = 0);
    _debounce?.cancel();
    if (widget.spec.search == null || v.trim().length < 2) {
      setState(() => _hits = const []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 280), () async {
      setState(() => _searching = true);
      try {
        final r = await widget.spec.search!(v.trim());
        if (mounted && _c.text.trim() == v.trim()) setState(() => _hits = r);
      } catch (_) {
        // search is best effort
      } finally {
        if (mounted) setState(() => _searching = false);
      }
    });
  }

  void _move(int d, int len) {
    if (len == 0) return;
    setState(() => _sel = (_sel + d) % len < 0 ? len - 1 : (_sel + d) % len);
    final off = _sel * 56.0;
    if (_scroll.hasClients) {
      _scroll.animateTo(off.clamp(0, _scroll.position.maxScrollExtent), duration: const Duration(milliseconds: 120), curve: Curves.easeOut);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final res = _results();
    return Align(
      alignment: const Alignment(0, -.55),
      child: Material(
        color: context.pal.surface,
        borderRadius: BorderRadius.circular(18),
        elevation: 24,
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: 640,
          height: 480,
          child: CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.arrowDown): () => _move(1, res.length),
              const SingleActivator(LogicalKeyboardKey.arrowUp): () => _move(-1, res.length),
              const SingleActivator(LogicalKeyboardKey.enter): () {
                if (res.isNotEmpty) res[_sel.clamp(0, res.length - 1)].run();
              },
            },
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 12, 0),
                child: TextField(
                  controller: _c,
                  autofocus: true,
                  onChanged: _onChanged,
                  style: const TextStyle(fontSize: 17),
                  decoration: InputDecoration(
                    hintText: widget.spec.search == null ? S.jumpHint : S.paletteSearchHint,
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searching
                        ? const Padding(padding: EdgeInsets.all(14), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)))
                        : null,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                  ),
                ),
              ),
              Divider(height: 1, color: context.pal.line),
              Expanded(
                child: res.isEmpty
                    ? Center(child: Text(S.noResults, style: TextStyle(color: context.pal.muted)))
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.all(8),
                        itemCount: res.length,
                        itemExtent: 56,
                        itemBuilder: (_, i) {
                          final e = res[i];
                          final sel = i == _sel;
                          final showGroup = i == 0 || res[i - 1].group != e.group;
                          return MouseRegion(
                            onHover: (_) {
                              if (_sel != i) setState(() => _sel = i);
                            },
                            child: InkWell(
                              onTap: e.run,
                              borderRadius: BorderRadius.circular(10),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 100),
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: sel ? context.pal.accent.withValues(alpha: .1) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(children: [
                                  Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      color: sel ? context.pal.accent : context.pal.surfaceAlt,
                                      borderRadius: BorderRadius.circular(9),
                                    ),
                                    child: Icon(e.icon, size: 18, color: sel ? Colors.white : context.pal.muted),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Text(e.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                                      Text(e.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: context.pal.muted)),
                                    ]),
                                  ),
                                  if (showGroup) Tag(e.group),
                                  if (sel) ...[const SizedBox(width: 8), Icon(Icons.keyboard_return_rounded, size: 16, color: context.pal.muted)],
                                ]),
                              ),
                            ),
                          ).animate().fadeIn(duration: 120.ms, delay: (i < 12 ? i * 12 : 0).ms);
                        },
                      ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                color: context.pal.surfaceAlt.withValues(alpha: .5),
                child: Row(children: [
                  _kbd(context, '↑↓'),
                  Text(' ${S.navigate}   ', style: TextStyle(fontSize: 12, color: context.pal.muted)),
                  _kbd(context, '↵'),
                  Text(' ${S.open}   ', style: TextStyle(fontSize: 12, color: context.pal.muted)),
                  _kbd(context, 'Esc'),
                  Text(' ${S.close}', style: TextStyle(fontSize: 12, color: context.pal.muted)),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _kbd(BuildContext context, String k) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(color: context.pal.surface, borderRadius: BorderRadius.circular(5), border: Border.all(color: context.pal.line)),
        child: Text(k, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
      );
}
