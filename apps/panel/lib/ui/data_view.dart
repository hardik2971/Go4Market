import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:g4m_core/g4m_core.dart' hide EmptyState;
import 'package:intl/intl.dart';

import '../core/web_utils.dart';
import 'kit.dart';
import 'package:panel/l10n/overrides.dart';

/// Column definition.
class Col<T> {
  const Col(this.label, {this.text, this.cell, this.sort, this.flex = 2, this.csv, this.numeric = false, this.minWidth});
  final String label;

  /// Plain text value (also used for CSV / default cell).
  final String Function(T row)? text;
  final Widget Function(BuildContext context, T row)? cell;
  final Comparable<dynamic>? Function(T row)? sort;
  final int flex;
  final String Function(T row)? csv;
  final bool numeric;
  final double? minWidth;

  double get minW => minWidth ?? flex * 64.0;
}

class RowAction<T> {
  const RowAction(this.label, this.icon, this.onTap, {this.danger = false, this.visible});
  final String label;
  final IconData icon;
  final FutureOr<void> Function(T row) onTap;
  final bool danger;
  final bool Function(T row)? visible;
}

class BulkAction<T> {
  const BulkAction(this.label, this.icon, this.run, {this.danger = false});
  final String label;
  final IconData icon;
  final Future<void> Function(List<T> rows) run;
  final bool danger;
}

/// Dropdown filter. When [server] is true its value is passed to the source.
class TableFilter<T> {
  const TableFilter(this.key, this.label, this.options, {this.test, this.server = false, this.initial});
  final String key;
  final String label;
  final Map<String, String> options;
  final bool Function(T row, String value)? test;
  final bool server;
  final String? initial;
}

class SourceQuery {
  const SourceQuery(this.limit, this.filters);
  final int limit;
  final Map<String, String> filters; // only server filters with a value
}

/// Remembers card/table preference per table id for the session.
final _viewPrefs = <String, bool>{};

/// Searchable, filterable, sortable, paginated live table with card/table toggle,
/// bulk selection and CSV export of the current view.
class DataView<T> extends StatefulWidget {
  const DataView({
    super.key,
    required this.id,
    required this.source,
    required this.columns,
    required this.rowId,
    this.searchText,
    this.filters = const [],
    this.actions = const [],
    this.bulkActions = const [],
    this.onTap,
    this.card,
    this.leading,
    this.toolbar = const [],
    this.pageSize = 25,
    this.initialLimit = 300,
    this.emptyIcon = Icons.inbox_outlined,
    this.emptyTitle = 'Nothing here yet',
    this.emptyMessage,
    this.emptyAction,
    this.csvName,
    this.defaultSort,
    this.defaultDesc = true,
    this.rowHeight = 64,
    this.cardMinWidth = 280,
    this.dense = false,
  });

  final String id;
  final Stream<List<T>> Function(SourceQuery q) source;
  final List<Col<T>> columns;
  final String Function(T row) rowId;
  final String Function(T row)? searchText;
  final List<TableFilter<T>> filters;
  final List<RowAction<T>> actions;
  final List<BulkAction<T>> bulkActions;
  final void Function(T row)? onTap;
  final Widget Function(BuildContext context, T row)? card;

  /// Optional thumbnail/avatar cell rendered before the first column.
  final Widget Function(BuildContext context, T row)? leading;
  final List<Widget> toolbar;
  final int pageSize;
  final int initialLimit;
  final IconData emptyIcon;
  final String emptyTitle;
  final String? emptyMessage;
  final Widget? emptyAction;
  final String? csvName;
  final int? defaultSort;
  final bool defaultDesc;
  final double rowHeight;
  final double cardMinWidth;
  final bool dense;

  @override
  State<DataView<T>> createState() => _DataViewState<T>();
}

class _DataViewState<T> extends State<DataView<T>> {
  final _search = TextEditingController();
  String _q = '';
  Timer? _debounce;
  late final Map<String, String?> _filters = {for (final f in widget.filters) f.key: f.initial};
  late int _limit = widget.initialLimit;
  late int? _sortCol = widget.defaultSort;
  late bool _desc = widget.defaultDesc;
  int _page = 0;
  late int _pageSize = widget.pageSize;
  final Set<String> _selected = {};
  late bool _cards = _viewPrefs[widget.id] ?? false;
  late Stream<List<T>> _stream;
  List<T> _lastView = const [];

  @override
  void initState() {
    super.initState();
    _stream = _makeStream();
  }

  Stream<List<T>> _makeStream() {
    final server = <String, String>{
      for (final f in widget.filters)
        if (f.server && _filters[f.key] != null) f.key: _filters[f.key]!,
    };
    return widget.source(SourceQuery(_limit, server));
  }

  void _reload() => setState(() => _stream = _makeStream());

  @override
  void dispose() {
    _search.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  List<T> _apply(List<T> rows) {
    var out = rows;
    for (final f in widget.filters) {
      final v = _filters[f.key];
      if (v != null && f.test != null && !f.server) out = out.where((r) => f.test!(r, v)).toList();
    }
    if (_q.isNotEmpty && widget.searchText != null) {
      final terms = _q.toLowerCase().split(RegExp(r'\s+')).where((t) => t.isNotEmpty);
      out = out.where((r) {
        final hay = widget.searchText!(r).toLowerCase();
        return terms.every(hay.contains);
      }).toList();
    }
    final sc = _sortCol;
    if (sc != null && sc < widget.columns.length) {
      final col = widget.columns[sc];
      final key = col.sort ?? (col.text == null ? null : (T r) => col.text!(r).toLowerCase());
      if (key != null) {
        out = List.of(out)
          ..sort((a, b) {
            final x = key(a), y = key(b);
            int r;
            if (x == null && y == null) {
              r = 0;
            } else if (x == null) {
              r = -1;
            } else if (y == null) {
              r = 1;
            } else {
              r = Comparable.compare(x, y);
            }
            return _desc ? -r : r;
          });
      }
    }
    return out;
  }

  void _exportCsv() {
    final cols = widget.columns.where((c) => c.text != null || c.csv != null).toList();
    final rows = _lastView.map((r) => [for (final c in cols) (c.csv ?? c.text)!(r)]).toList();
    final name = '${widget.csvName ?? widget.id}_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv';
    downloadText(name, toCsv(cols.map((c) => tr(c.label)).toList(), rows));
    toast(S.exported(rows.length));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<T>>(
      stream: _stream,
      builder: (context, snap) {
        final all = snap.data ?? const [];
        final view = _apply(all);
        _lastView = view;
        final pages = (view.length / _pageSize).ceil().clamp(1, 1 << 30);
        if (_page >= pages) _page = pages - 1;
        final pageRows = view.skip(_page * _pageSize).take(_pageSize).toList();
        final selectedRows = all.where((r) => _selected.contains(widget.rowId(r))).toList();

        return Container(
          decoration: BoxDecoration(
            color: context.pal.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.pal.line),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _toolbar(context, all.length, view.length),
            AnimatedSize(
              duration: G4MMotion.standard,
              curve: G4MMotion.curve,
              child: selectedRows.isEmpty ? const SizedBox(width: double.infinity) : _bulkBar(context, selectedRows),
            ),
            Divider(height: 1, color: context.pal.line),
            if (snap.hasError && all.isEmpty)
              Padding(padding: const EdgeInsets.all(24), child: ErrorBox(snap.error!, onRetry: _reload))
            else if (!snap.hasData)
              const Padding(padding: EdgeInsets.all(20), child: LoadingBlock())
            else if (view.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 36),
                child: EmptyState(
                  icon: _q.isNotEmpty || _filters.values.any((v) => v != null) ? Icons.search_off_rounded : widget.emptyIcon,
                  title: _q.isNotEmpty || _filters.values.any((v) => v != null) ? S.noMatches : tr(widget.emptyTitle),
                  message: _q.isNotEmpty || _filters.values.any((v) => v != null)
                      ? S.tryDifferent
                      : widget.emptyMessage == null ? null : tr(widget.emptyMessage!),
                  action: _q.isNotEmpty || _filters.values.any((v) => v != null)
                      ? OutlinedButton(
                          onPressed: () => setState(() {
                                _search.clear();
                                _q = '';
                                for (final k in _filters.keys) {
                                  _filters[k] = null;
                                }
                                _stream = _makeStream();
                              }),
                          child: Text(S.clearFilters))
                      : widget.emptyAction,
                ),
              )
            else if (_cards && widget.card != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: ResponsiveGrid(
                  minItemWidth: widget.cardMinWidth,
                  children: [
                    for (var i = 0; i < pageRows.length; i++)
                      _cardWrap(context, pageRows[i])
                          .animate(delay: (18 * i).ms)
                          .fadeIn(duration: 220.ms)
                          .slideY(begin: .04, duration: 260.ms, curve: Curves.easeOutCubic),
                  ],
                ),
              )
            else
              _table(context, pageRows, view),
            if (view.isNotEmpty) _footer(context, view.length, pages, all.length),
          ]),
        );
      },
    );
  }

  Widget _cardWrap(BuildContext context, T row) {
    final id = widget.rowId(row);
    final selected = _selected.contains(id);
    return Stack(children: [
      Pressable(
        onTap: widget.onTap == null ? null : () => widget.onTap!(row),
        scale: .985,
        child: AnimatedContainer(
          duration: G4MMotion.fast,
          decoration: BoxDecoration(
            color: context.pal.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? context.pal.accent : context.pal.line, width: selected ? 1.6 : 1),
          ),
          clipBehavior: Clip.antiAlias,
          child: widget.card!(context, row),
        ),
      ),
      PositionedDirectional(
        top: 6,
        end: 6,
        child: Row(children: [
          if (widget.bulkActions.isNotEmpty)
            Checkbox(value: selected, onChanged: (v) => setState(() => v! ? _selected.add(id) : _selected.remove(id))),
          if (widget.actions.isNotEmpty) _actionsMenu(context, row),
        ]),
      ),
    ]);
  }

  Widget _toolbar(BuildContext context, int total, int shown) {
    final narrow = MediaQuery.sizeOf(context).width < 900;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (widget.searchText != null)
            SizedBox(
              width: narrow ? double.infinity : 300,
              height: 40,
              child: TextField(
                controller: _search,
                decoration: InputDecoration(
                  hintText: S.search,
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _q.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () => setState(() {
                                _search.clear();
                                _q = '';
                              })),
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                ),
                onChanged: (v) {
                  _debounce?.cancel();
                  _debounce = Timer(const Duration(milliseconds: 220), () => setState(() {
                        _q = v.trim();
                        _page = 0;
                      }));
                },
              ),
            ),
          for (final f in widget.filters) _filterChip(context, f),
          ...widget.toolbar,
          if (!narrow) const SizedBox(width: 8),
          Row(mainAxisSize: MainAxisSize.min, children: [
            if (widget.card != null)
              Segmented<bool>(
                value: _cards,
                options: {false: S.table, true: S.cards},
                onChanged: (v) => setState(() => _viewPrefs[widget.id] = _cards = v),
              ),
            const SizedBox(width: 6),
            IconButton(tooltip: S.refresh, onPressed: _reload, icon: const Icon(Icons.refresh_rounded, size: 20)),
            IconButton(tooltip: S.exportCsv, onPressed: _exportCsv, icon: const Icon(Icons.download_rounded, size: 20)),
          ]),
        ],
      ),
    );
  }

  Widget _filterChip(BuildContext context, TableFilter<T> f) {
    final v = _filters[f.key];
    final active = v != null;
    return PopupMenuButton<String>(
      tooltip: tr(f.label),
      position: PopupMenuPosition.under,
      onSelected: (x) => setState(() {
        _filters[f.key] = x == '__all' ? null : x;
        _page = 0;
        if (f.server) _stream = _makeStream();
      }),
      itemBuilder: (_) => [
        PopupMenuItem(value: '__all', child: Text(S.allOf(f.label))),
        const PopupMenuDivider(),
        for (final e in f.options.entries)
          PopupMenuItem(
            value: e.key,
            child: Row(children: [
              Expanded(child: Text(tr(e.value))),
              if (e.key == v) Icon(Icons.check_rounded, size: 18, color: context.pal.accent),
            ]),
          ),
      ],
      child: AnimatedContainer(
        duration: G4MMotion.fast,
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: active ? context.pal.accent.withValues(alpha: .1) : context.pal.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: active ? context.pal.accent : context.pal.line),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.filter_list_rounded, size: 16, color: active ? context.pal.accent : context.pal.muted),
          const SizedBox(width: 6),
          Text(active ? '${tr(f.label)}: ${tr(f.options[v] ?? v)}' : tr(f.label),
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: active ? context.pal.accent : context.pal.ink)),
          const SizedBox(width: 4),
          Icon(Icons.expand_more_rounded, size: 16, color: context.pal.muted),
        ]),
      ),
    );
  }

  Widget _bulkBar(BuildContext context, List<T> rows) => Container(
        color: context.pal.accent.withValues(alpha: .08),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(children: [
          Text(S.selected(rows.length), style: TextStyle(fontWeight: FontWeight.w800, color: context.pal.accent)),
          const SizedBox(width: 16),
          Expanded(
            child: Wrap(spacing: 8, runSpacing: 8, children: [
              for (final a in widget.bulkActions)
                AsyncButton(
                  outlined: true,
                  icon: a.icon,
                  label: a.label,
                  onPressed: () async {
                    if (a.danger &&
                        !await confirm(context, S.bulkConfirm(a.label, rows.length), danger: true, confirmLabel: a.label)) {
                      return;
                    }
                    try {
                      await a.run(rows);
                      toast(S.bulkDone(a.label, rows.length));
                      if (mounted) setState(_selected.clear);
                    } catch (e) {
                      toastError(e);
                    }
                  },
                ),
            ]),
          ),
          TextButton(onPressed: () => setState(_selected.clear), child: Text(S.clear)),
        ]),
      );

  Widget _actionsMenu(BuildContext context, T row) {
    final acts = widget.actions.where((a) => a.visible?.call(row) ?? true).toList();
    if (acts.isEmpty) return const SizedBox(width: 40);
    return PopupMenuButton<int>(
      tooltip: S.actions,
      icon: Icon(Icons.more_horiz_rounded, color: context.pal.muted),
      position: PopupMenuPosition.under,
      onSelected: (i) => acts[i].onTap(row),
      itemBuilder: (_) => [
        for (var i = 0; i < acts.length; i++)
          PopupMenuItem(
            value: i,
            child: Row(children: [
              Icon(acts[i].icon, size: 18, color: acts[i].danger ? G4MColors.danger : context.pal.muted),
              const SizedBox(width: 10),
              Text(tr(acts[i].label), style: TextStyle(color: acts[i].danger ? G4MColors.danger : null)),
            ]),
          ),
      ],
    );
  }

  Widget _table(BuildContext context, List<T> rows, List<T> view) {
    final cols = widget.columns;
    final bulk = widget.bulkActions.isNotEmpty;
    final hasActions = widget.actions.isNotEmpty;
    final minWidth = cols.fold<double>(0, (a, c) => a + c.minW) +
        (bulk ? 48 : 0) +
        (hasActions ? 56 : 0) +
        (widget.leading != null ? 60 : 0) +
        32;
    final pageIds = rows.map(widget.rowId).toSet();
    final allSelected = pageIds.isNotEmpty && pageIds.every(_selected.contains);

    Widget header = Container(
      color: context.pal.surfaceAlt.withValues(alpha: .6),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      height: 44,
      child: Row(children: [
        if (bulk)
          SizedBox(
            width: 48,
            child: Checkbox(
              value: allSelected,
              onChanged: (v) => setState(() => v! ? _selected.addAll(pageIds) : _selected.removeAll(pageIds)),
            ),
          ),
        if (widget.leading != null) const SizedBox(width: 60),
        for (var i = 0; i < cols.length; i++)
          Expanded(
            flex: cols[i].flex,
            child: InkWell(
              onTap: (cols[i].sort != null || cols[i].text != null)
                  ? () => setState(() {
                        if (_sortCol == i) {
                          _desc = !_desc;
                        } else {
                          _sortCol = i;
                          _desc = false;
                        }
                      })
                  : null,
              child: Row(
                mainAxisAlignment: cols[i].numeric ? MainAxisAlignment.end : MainAxisAlignment.start,
                children: [
                  Flexible(
                    child: Text(L10n.instance.code == 'en' ? cols[i].label.toUpperCase() : tr(cols[i].label),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, letterSpacing: .6, fontWeight: FontWeight.w800, color: context.pal.muted)),
                  ),
                  if (_sortCol == i)
                    Icon(_desc ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded, size: 14, color: context.pal.accent),
                ],
              ),
            ),
          ),
        if (hasActions) const SizedBox(width: 56),
      ]),
    );

    final body = Column(children: [
      header,
      for (var r = 0; r < rows.length; r++) _TableRow<T>(
        key: ValueKey(widget.rowId(rows[r])),
        row: rows[r],
        state: this,
        index: r,
      ),
    ]);

    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth >= minWidth) return body;
      return Scrollbar(
        child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: SizedBox(width: minWidth, child: body)),
      );
    });
  }

  Widget _footer(BuildContext context, int count, int pages, int loaded) {
    final from = _page * _pageSize + 1;
    final to = ((_page + 1) * _pageSize).clamp(0, count);
    final more = loaded >= _limit;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: context.pal.line))),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 8,
        children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            Text(S.showing(from, to, count), style: TextStyle(color: context.pal.muted, fontSize: 13)),
            if (more) ...[
              const SizedBox(width: 12),
              TextButton.icon(
                onPressed: () => setState(() {
                  _limit += widget.initialLimit;
                  _stream = _makeStream();
                }),
                icon: const Icon(Icons.expand_more_rounded, size: 18),
                label: Text(S.loadMore),
              ),
            ],
          ]),
          Row(mainAxisSize: MainAxisSize.min, children: [
            Text(S.rows, style: TextStyle(color: context.pal.muted, fontSize: 13)),
            const SizedBox(width: 6),
            DropdownButton<int>(
              value: _pageSize,
              underline: const SizedBox(),
              borderRadius: BorderRadius.circular(10),
              items: [for (final n in {10, 25, 50, 100, widget.pageSize}) DropdownMenuItem(value: n, child: Text('$n'))],
              onChanged: (v) => setState(() {
                _pageSize = v!;
                _page = 0;
              }),
            ),
            const SizedBox(width: 12),
            IconButton(
              onPressed: _page > 0 ? () => setState(() => _page--) : null,
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            Text('${_page + 1} / $pages', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            IconButton(
              onPressed: _page < pages - 1 ? () => setState(() => _page++) : null,
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ]),
        ],
      ),
    );
  }
}

class _TableRow<T> extends StatefulWidget {
  const _TableRow({super.key, required this.row, required this.state, required this.index});
  final T row;
  final _DataViewState<T> state;
  final int index;
  @override
  State<_TableRow<T>> createState() => _TableRowState<T>();
}

class _TableRowState<T> extends State<_TableRow<T>> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final w = s.widget;
    final id = w.rowId(widget.row);
    final selected = s._selected.contains(id);
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: w.onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: w.onTap == null ? null : () => w.onTap!(widget.row),
        child: AnimatedContainer(
          duration: G4MMotion.fast,
          constraints: BoxConstraints(minHeight: w.dense ? 48 : w.rowHeight),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? context.pal.accent.withValues(alpha: .07)
                : _hover
                    ? context.pal.surfaceAlt.withValues(alpha: .7)
                    : Colors.transparent,
            border: BorderDirectional(
              bottom: BorderSide(color: context.pal.line.withValues(alpha: .7)),
              start: BorderSide(color: _hover || selected ? context.pal.accent : Colors.transparent, width: 3),
            ),
          ),
          child: Row(children: [
            if (w.bulkActions.isNotEmpty)
              SizedBox(
                width: 48,
                child: Checkbox(
                  value: selected,
                  onChanged: (v) => s.setState(() => v! ? s._selected.add(id) : s._selected.remove(id)),
                ),
              ),
            if (w.leading != null) SizedBox(width: 60, child: Align(alignment: AlignmentDirectional.centerStart, child: w.leading!(context, widget.row))),
            for (final c in w.columns)
              Expanded(
                flex: c.flex,
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(end: 12),
                  child: Align(
                    alignment: c.numeric ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
                    child: c.cell != null
                        ? c.cell!(context, widget.row)
                        : Text(c.text?.call(widget.row) ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: c.numeric ? FontWeight.w700 : FontWeight.w500,
                              fontFeatures: c.numeric ? const [FontFeature.tabularFigures()] : null,
                            )),
                  ),
                ),
              ),
            if (w.actions.isNotEmpty) SizedBox(width: 56, child: s._actionsMenu(context, widget.row)),
          ]),
        ),
      ),
    );
  }
}

/// Two-line cell: bold title + muted subtitle.
class TwoLine extends StatelessWidget {
  const TwoLine(this.title, [this.subtitle, this.trailing, Key? key]) : super(key: key);
  final String title;
  final String? subtitle;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            Flexible(
              child: Text(title,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
            ),
            if (trailing != null) ...[const SizedBox(width: 6), trailing!],
          ]),
          if (subtitle != null && subtitle!.isNotEmpty)
            Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.pal.muted, fontSize: 12)),
        ],
      );
}

/// Square thumbnail for table rows.
class RowThumb extends StatelessWidget {
  const RowThumb(this.url, {super.key, this.size = 42, this.icon = Icons.image_outlined});
  final String url;
  final double size;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: context.pal.surfaceAlt,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: context.pal.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: url.isEmpty ? Icon(icon, size: size * .45, color: context.pal.faint) : NetImage(url, width: size, height: size),
      );
}
