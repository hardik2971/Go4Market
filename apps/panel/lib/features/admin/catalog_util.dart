import 'package:panel/l10n/overrides.dart';
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:g4m_core/g4m_core.dart';

import '../../core/doc.dart';
import '../../core/live.dart';
import '../../core/session.dart';
import '../../ui/kit.dart';

bool get isSeller => session.panel == PanelRole.seller;

/// Products visible to the current panel (admin: all, seller: own), newest first.
Stream<List<Doc>> scopedProducts({int limit = 300, String? status}) {
  Query<Json> base = Fs.products;
  if (isSeller) base = base.where('sellerId', isEqualTo: session.uid);
  if (status != null) base = base.where('status', isEqualTo: status);
  return liveDocs(base.orderBy('createdAt', descending: true).limit(limit),
      fallback: base.limit(limit), label: isSeller ? 'products(sellerId,createdAt)' : 'products(status,createdAt)');
}

/// Effective stock (sum of variants when present).
int effectiveStock(Doc p) {
  final v = p['variants'];
  if (v is List && v.isNotEmpty) {
    return v.fold<int>(0, (a, e) => a + (e is Map ? toNum(e['stock']).toInt() : 0));
  }
  return p.i('stock');
}

String stockState(Doc p) {
  final s = effectiveStock(p);
  if (s <= 0) return 'out';
  if (s <= p.i('lowStockAt', 5)) return 'low';
  return 'in';
}

Color stockColor(String state) => switch (state) {
      'out' => G4MColors.danger,
      'low' => G4MColors.warning,
      _ => G4MColors.success,
    };

/// Lowercase search tokens (mirrors onProductWritten so search works immediately).
List<String> productKeywords(Map<String, dynamic> p, {String categoryName = ''}) {
  final text = [
    p['name'],
    p['brandName'],
    categoryName,
    ...(p['tags'] is List ? p['tags'] as List : const []),
    p['barcode'],
    p['sku'],
  ].whereType<Object>().join(' ').toLowerCase();
  final tokens = text.split(RegExp(r'[^a-z0-9]+')).where((t) => t.length > 1).toSet();
  return tokens.take(50).toList();
}

// ───────────────────────── Categories ─────────────────────────

Stream<List<Doc>> allCategories() => liveDocs(Fs.categories, label: 'categories');

class CatNode {
  CatNode(this.doc);
  final Doc doc;
  final List<CatNode> children = [];
}

List<CatNode> buildTree(List<Doc> cats, {String? moduleId}) {
  final nodes = {for (final c in cats) c.id: CatNode(c)};
  final roots = <CatNode>[];
  for (final n in nodes.values) {
    if (moduleId != null && n.doc.s('moduleId', 'ecommerce') != moduleId) continue;
    final pid = n.doc.s('parentId');
    if (pid.isNotEmpty && nodes.containsKey(pid)) {
      nodes[pid]!.children.add(n);
    } else {
      roots.add(n);
    }
  }
  void sort(List<CatNode> l) {
    l.sort((a, b) {
      final r = a.doc.n('order').compareTo(b.doc.n('order'));
      return r != 0 ? r : a.doc.s('name').compareTo(b.doc.s('name'));
    });
    for (final n in l) {
      sort(n.children);
    }
  }

  sort(roots);
  return roots;
}

/// Ancestor ids from root to [id] inclusive.
List<String> categoryChain(String id, Map<String, Doc> byId) {
  final out = <String>[];
  var cur = byId[id];
  final seen = <String>{};
  while (cur != null && seen.add(cur.id)) {
    out.insert(0, cur.id);
    final p = cur.s('parentId');
    cur = p.isEmpty ? null : byId[p];
  }
  return out;
}

String categoryLabel(String id, Map<String, Doc> byId) =>
    categoryChain(id, byId).map((c) => byId[c]?.s('name') ?? c).join(' › ');

/// Dialog with a searchable category tree. Returns the picked id, '' for root (when [allowRoot]) or null.
Future<String?> pickCategory(BuildContext context, {String? moduleId, String? excludeId, bool allowRoot = false, String title = 'Choose category'}) {
  return showDialog<String>(
    context: context,
    builder: (ctx) => _CategoryPicker(moduleId: moduleId, excludeId: excludeId, allowRoot: allowRoot, title: title),
  );
}

class _CategoryPicker extends StatefulWidget {
  const _CategoryPicker({this.moduleId, this.excludeId, required this.allowRoot, required this.title});
  final String? moduleId;
  final String? excludeId;
  final bool allowRoot;
  final String title;
  @override
  State<_CategoryPicker> createState() => _CategoryPickerState();
}

class _CategoryPickerState extends State<_CategoryPicker> {
  String _q = '';
  late String? _module = widget.moduleId;
  late final Stream<List<Doc>> _s = allCategories();

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.title),
        content: SizedBox(
          width: 520,
          height: 520,
          child: StreamBuilder<List<Doc>>(
            stream: _s,
            builder: (context, snap) {
              if (snap.hasError) return ErrorBox(snap.error!);
              if (!snap.hasData) return const LoadingBlock(rows: 5);
              final byId = {for (final c in snap.data!) c.id: c};
              final rows = <Widget>[];
              void walk(List<CatNode> l, int depth) {
                for (final n in l) {
                  if (n.doc.id == widget.excludeId) continue;
                  final match = _q.isEmpty || n.doc.s('name').toLowerCase().contains(_q);
                  if (match) {
                    rows.add(ListTile(
                      dense: true,
                      contentPadding: EdgeInsetsDirectional.only(start: 8.0 + depth * 18, end: 8),
                      leading: Icon(n.children.isEmpty ? Icons.label_outline_rounded : Icons.folder_open_rounded, size: 18),
                      title: Text(n.doc.s('name')),
                      subtitle: _q.isEmpty ? null : Text(categoryLabel(n.doc.id, byId), style: const TextStyle(fontSize: 11)),
                      trailing: n.doc.b('active', true) ? null : const Tag('Inactive'),
                      onTap: () => Navigator.pop(context, n.doc.id),
                    ));
                  }
                  walk(n.children, _q.isEmpty ? depth + 1 : depth);
                }
              }

              walk(buildTree(snap.data!, moduleId: _module), 0);
              return Column(children: [
                TextField(
                  autofocus: true,
                  decoration: const InputDecoration(hintText: 'Search categories…', prefixIcon: Icon(Icons.search_rounded)),
                  onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Segmented<String?>(
                    value: _module,
                    options: {null: 'All', ...moduleOptionsLocal},
                    onChanged: (m) => setState(() => _module = m),
                  ),
                ),
                const SizedBox(height: 8),
                if (widget.allowRoot)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.vertical_align_top_rounded, size: 18),
                    title: Text(tr('— Top level (no parent) —')),
                    onTap: () => Navigator.pop(context, ''),
                  ),
                Expanded(child: rows.isEmpty ? Center(child: Text(tr('No categories'))) : ListView(children: rows)),
              ]);
            },
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('Cancel')))],
      );
}

const moduleOptionsLocal = {'ecommerce': 'eCommerce', 'grocery': 'Grocery', 'pharmacy': 'Pharmacy', 'food': 'Food'};

// ───────────────────────── Lookups ─────────────────────────

final _userNames = <String, Future<String>>{};
final _productNames = <String, Future<String>>{};

Future<String> userName(String uid) => uid.isEmpty
    ? Future.value('—')
    : _userNames.putIfAbsent(uid, () async {
        try {
          final d = await Fs.user(uid).get();
          final m = d.data() ?? {};
          return '${m['name'] ?? m['email'] ?? uid}';
        } catch (_) {
          return uid.length > 8 ? uid.substring(0, 8) : uid;
        }
      });

Future<String> productName(String id) => _productNames.putIfAbsent(id, () async {
      try {
        final d = await Fs.products.doc(id).get();
        return '${d.data()?['name'] ?? id}';
      } catch (_) {
        return id;
      }
    });

/// Text resolved from a cached future.
class LookupText extends StatelessWidget {
  const LookupText(this.future, {super.key, this.style, this.prefix = ''});
  final Future<String> future;
  final TextStyle? style;
  final String prefix;
  @override
  Widget build(BuildContext context) => FutureBuilder<String>(
        future: future,
        builder: (context, s) => Text('$prefix${s.data ?? '…'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: style),
      );
}

/// Stars row that adapts to dark mode.
Widget stars(num rating, {double size = 15}) => Row(mainAxisSize: MainAxisSize.min, children: [
      for (var i = 1; i <= 5; i++)
        Icon(
          rating >= i ? Icons.star_rounded : rating >= i - .5 ? Icons.star_half_rounded : Icons.star_outline_rounded,
          size: size,
          color: const Color(0xFFF5A524),
        ),
    ]);

/// Firestore batch writer that commits every 400 ops.
class ChunkedBatch {
  WriteBatch _b = Fs.db.batch();
  int _n = 0;
  final _pending = <Future<void>>[];
  void set(DocumentReference<Json> r, Json data, [SetOptions? o]) {
    _b.set(r, data, o);
    _tick();
  }

  void update(DocumentReference<Json> r, Json data) {
    _b.update(r, data);
    _tick();
  }

  void delete(DocumentReference<Json> r) {
    _b.delete(r);
    _tick();
  }

  void _tick() {
    if (++_n >= 400) {
      _pending.add(_b.commit());
      _b = Fs.db.batch();
      _n = 0;
    }
  }

  Future<void> commit() async {
    if (_n > 0) _pending.add(_b.commit());
    await Future.wait(_pending);
  }
}
