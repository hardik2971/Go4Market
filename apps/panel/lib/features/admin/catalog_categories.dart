import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:g4m_core/g4m_core.dart' hide Fmt, EmptyState;

import '../../core/doc.dart';
import '../../core/session.dart';
import '../../ui/data_view.dart';
import '../../ui/form_kit.dart';
import '../../ui/kit.dart';
import 'catalog_util.dart';
import 'package:panel/l10n/overrides.dart';

/// Infinite nested category tree with drag ordering, move and inline editing.
class CategoriesPage extends StatefulWidget {
  const CategoriesPage({super.key});
  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  late final Stream<List<Doc>> _stream = allCategories();
  late String? _module = session.moduleId;
  final _expanded = <String>{};
  String _q = '';
  Map<String, Doc> _byId = {};

  List<F> _fields(String? selfId) => [
        const F('name', 'Name', FT.text, required: true),
        const F('slug', 'Slug', FT.text, help: 'Leave empty to generate from name'),
        F('moduleId', 'Module', FT.select, required: true, options: moduleOptionsLocal, initial: _module ?? 'ecommerce'),
        F('parentId', 'Parent category', FT.select, options: {
          for (final c in (_byId.values.where((c) => c.id != selfId && (selfId == null || !c.list('path').contains(selfId))).toList()
            ..sort((a, b) => categoryLabel(a.id, _byId).compareTo(categoryLabel(b.id, _byId)))))
            c.id: categoryLabel(c.id, _byId),
        }, help: 'Empty = top-level category'),
        const F('image', 'Image / icon', FT.image, folder: 'categories', help: 'Square, 256×256 or larger · WebP/PNG'),
        const F('subtitle', 'Subtitle', FT.text),
        const F('bgColor', 'Tile background (light)', FT.color),
        const F('bgColorDark', 'Tile background (dark)', FT.color),
        const F('active', 'Active', FT.toggle, initial: true),
        const F.section('SEO'),
        const F('metaTitle', 'Meta title', FT.text, wide: true),
        const F('metaDescription', 'Meta description', FT.multiline),
        const F('metaKeywords', 'Meta keywords', FT.tags),
      ];

  Future<void> _edit({Doc? d, String? parentId}) async {
    final init = d?.data ?? {'parentId': parentId, 'moduleId': parentId != null ? _byId[parentId]?.s('moduleId') : (_module ?? 'ecommerce'), 'active': true};
    await openEditor(
      context,
      title: d == null ? (parentId == null ? 'New category' : 'New sub-category') : 'Edit category',
      subtitle: parentId != null ? 'Inside ${categoryLabel(parentId, _byId)}' : null,
      fields: _fields(d?.id),
      initial: init,
      onSave: (raw) async {
        final v = cleanValues(raw);
        if ('${v['slug'] ?? ''}'.isEmpty) v['slug'] = Fmt.slugify('${v['name']}');
        final pid = '${v['parentId'] ?? ''}';
        v['parentId'] = pid.isEmpty ? null : pid;
        final parentPath = pid.isEmpty ? <String>[] : categoryChain(pid, _byId);
        v['updatedAt'] = FieldValue.serverTimestamp();
        if (d == null) {
          final siblings = _byId.values.where((c) => c.s('parentId') == pid);
          v['order'] = siblings.isEmpty ? 0 : siblings.map((c) => c.i('order')).reduce((a, b) => a > b ? a : b) + 1;
          v['path'] = parentPath;
          v['depth'] = parentPath.length;
          v['productCount'] = 0;
          v['createdAt'] = FieldValue.serverTimestamp();
          await Fs.categories.add(v);
          if (pid.isNotEmpty) setState(() => _expanded.add(pid));
        } else {
          final moved = d.s('parentId') != pid;
          v.remove('path');
          v.remove('depth');
          await d.ref!.set(v, SetOptions(merge: true));
          if (moved) await _reparent(d, pid.isEmpty ? null : pid);
        }
      },
    );
  }

  /// Moves [d] under [newParent] and rewrites path/depth for the whole subtree + product categoryPaths.
  Future<void> _reparent(Doc d, String? newParent) async {
    final byId = Map<String, Doc>.from(_byId);
    byId[d.id] = Doc(d.id, {...d.data, 'parentId': newParent}, d.ref);
    final subtree = byId.values.where((c) => c.id == d.id || c.list('path').contains(d.id)).toList();
    final b = ChunkedBatch();
    for (final c in subtree) {
      final chain = categoryChain(c.id, byId);
      final path = chain.sublist(0, chain.length - 1);
      b.update(c.ref!, {'path': path, 'depth': path.length, if (c.id == d.id) 'parentId': newParent, 'updatedAt': FieldValue.serverTimestamp()});
    }
    // Products under the moved subtree carry categoryPath — refresh it.
    final prods = await Fs.products.where('categoryPath', arrayContains: d.id).limit(500).get();
    for (final p in prods.docs) {
      final cid = '${p.data()['categoryId'] ?? ''}';
      if (cid.isEmpty) continue;
      b.update(p.reference, {'categoryPath': categoryChain(cid, byId)});
    }
    await b.commit();
  }

  Future<void> _move(Doc d) async {
    final target = await pickCategory(context, moduleId: d.s('moduleId'), excludeId: d.id, allowRoot: true, title: 'Move "${d.s('name')}" to…');
    if (target == null) return;
    if (target.isNotEmpty && (_byId[target]?.list('path').contains(d.id) ?? false)) {
      toast('Cannot move a category inside its own sub-category', kind: ToastKind.error);
      return;
    }
    await runToast(() => _reparent(d, target.isEmpty ? null : target), success: 'Category moved');
  }

  Future<void> _reorder(List<CatNode> siblings, int a, int b) async {
    if (b > a) b--;
    final l = List<CatNode>.from(siblings);
    l.insert(b, l.removeAt(a));
    final batch = Fs.db.batch();
    for (var i = 0; i < l.length; i++) {
      if (l[i].doc.i('order') != i) batch.update(l[i].doc.ref!, {'order': i});
    }
    await runToast(batch.commit);
  }

  Future<void> _delete(Doc d, CatNode n) async {
    if (n.children.isNotEmpty) {
      toast('Move or delete the ${n.children.length} sub-categories first', kind: ToastKind.error);
      return;
    }
    if (d.i('productCount') > 0 &&
        !await confirm(context, '"${d.s('name')}" has ${d.i('productCount')} products', message: 'They will keep pointing to a deleted category. Delete anyway?', danger: true)) {
      return;
    }
    if (!mounted) return;
    if (await confirm(context, 'Delete "${d.s('name')}"?', danger: true, confirmLabel: 'Delete')) {
      await runToast(() => d.ref!.delete(), success: 'Category deleted');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PanelPage(
      title: 'Categories',
      subtitle: 'Unlimited nesting · drag to reorder · per-module trees',
      actions: [
        OutlinedButton.icon(
          onPressed: () => setState(() => _expanded.length >= _byId.length ~/ 2 ? _expanded.clear() : _expanded.addAll(_byId.keys)),
          icon: const Icon(Icons.unfold_more_rounded, size: 18),
          label: Text(tr('Expand / collapse all')),
        ),
        FilledButton.icon(onPressed: () => _edit(), icon: const Icon(Icons.add_rounded, size: 18), label: Text(tr('Add category'))),
      ],
      child: StreamBuilder<List<Doc>>(
        stream: _stream,
        builder: (context, snap) {
          if (snap.hasError) return ErrorBox(snap.error!);
          if (!snap.hasData) return const SectionCard(child: LoadingBlock());
          _byId = {for (final c in snap.data!) c.id: c};
          final roots = buildTree(snap.data!, moduleId: _module);
          final total = snap.data!.where((c) => _module == null || c.s('moduleId', 'ecommerce') == _module).length;
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Segmented<String?>(value: _module, options: {null: 'All modules', ...moduleOptionsLocal}, onChanged: (m) => setState(() => _module = m)),
              SizedBox(
                width: 280,
                height: 40,
                child: TextField(
                  decoration: const InputDecoration(hintText: 'Find a category…', prefixIcon: Icon(Icons.search_rounded, size: 20), contentPadding: EdgeInsets.symmetric(vertical: 8)),
                  onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
                ),
              ),
              Text('$total categories · ${roots.length} top-level', style: TextStyle(color: context.pal.muted, fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 16),
            SectionCard(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: roots.isEmpty
                  ? EmptyState(
                      icon: Icons.account_tree_outlined,
                      title: 'No categories yet',
                      message: 'Create a top-level category, then add sub-categories inside it.',
                      action: FilledButton.icon(onPressed: () => _edit(), icon: const Icon(Icons.add_rounded), label: Text(tr('Add category'))),
                    )
                  : _q.isNotEmpty
                      ? _searchResults(context)
                      : _level(context, roots, 0),
            ),
          ]);
        },
      ),
    );
  }

  Widget _searchResults(BuildContext context) {
    final hits = _byId.values
        .where((c) => (_module == null || c.s('moduleId', 'ecommerce') == _module) && c.s('name').toLowerCase().contains(_q))
        .toList()
      ..sort((a, b) => categoryLabel(a.id, _byId).compareTo(categoryLabel(b.id, _byId)));
    if (hits.isEmpty) return Padding(padding: EdgeInsets.all(24), child: Center(child: Text(tr('No categories match'))));
    return Column(children: [
      for (final c in hits)
        ListTile(
          leading: RowThumb(c.s('image'), size: 36, icon: Icons.category_outlined),
          title: Text(c.s('name'), style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(categoryLabel(c.id, _byId)),
          trailing: IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => _edit(d: c)),
          onTap: () => _edit(d: c),
        ),
    ]);
  }

  Widget _level(BuildContext context, List<CatNode> nodes, int depth) => ReorderableListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        buildDefaultDragHandles: false,
        itemCount: nodes.length,
        onReorder: (a, b) => _reorder(nodes, a, b),
        proxyDecorator: (child, _, _) => Material(elevation: 6, borderRadius: BorderRadius.circular(12), color: context.pal.surface, child: child),
        itemBuilder: (context, i) {
          final n = nodes[i];
          final open = _expanded.contains(n.doc.id);
          return Column(key: ValueKey(n.doc.id), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _row(context, n, i, depth, open),
            AnimatedSize(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: open && n.children.isNotEmpty
                  ? Padding(
                      padding: const EdgeInsetsDirectional.only(start: 28),
                      child: Container(
                        decoration: BoxDecoration(border: BorderDirectional(start: BorderSide(color: context.pal.line, width: 2))),
                        child: _level(context, n.children, depth + 1),
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ]);
        },
      );

  Widget _row(BuildContext context, CatNode n, int index, int depth, bool open) {
    final d = n.doc;
    return _HoverRow(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(children: [
          ReorderableDragStartListener(
            index: index,
            child: MouseRegion(cursor: SystemMouseCursors.grab, child: Icon(Icons.drag_indicator_rounded, color: context.pal.faint, size: 20)),
          ),
          SizedBox(
            width: 32,
            child: n.children.isEmpty
                ? null
                : IconButton(
                    padding: EdgeInsets.zero,
                    icon: AnimatedRotation(turns: open ? .25 : 0, duration: G4MMotion.standard, child: const Icon(Icons.chevron_right_rounded)),
                    onPressed: () => setState(() => open ? _expanded.remove(d.id) : _expanded.add(d.id)),
                  ),
          ),
          RowThumb(d.s('image'), size: 38, icon: Icons.category_outlined),
          const SizedBox(width: 12),
          Expanded(
            child: TwoLine(
              d.s('name'),
              [
                '/${d.s('slug', d.id)}',
                if (n.children.isNotEmpty) '${n.children.length} sub-categories',
                if (_module == null) moduleOptionsLocal[d.s('moduleId', 'ecommerce')] ?? d.s('moduleId'),
              ].join(' · '),
            ),
          ),
          Tag('${d.i('productCount')} products', color: context.pal.accent),
          SizedBox(width: 8),
          Transform.scale(
            scale: .8,
            child: Switch(value: d.b('active', true), onChanged: (v) => runToast(() => d.ref!.update({'active': v}))),
          ),
          IconButton(tooltip: 'Add sub-category', onPressed: () => _edit(parentId: d.id), icon: Icon(Icons.add_circle_outline_rounded, size: 20)),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_horiz_rounded, color: context.pal.muted),
            onSelected: (a) {
              switch (a) {
                case 'edit':
                  _edit(d: d);
                case 'move':
                  _move(d);
                case 'delete':
                  _delete(d, n);
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'edit', child: ListTile(dense: true, leading: Icon(Icons.edit_outlined), title: Text(tr('Edit')))),
              PopupMenuItem(value: 'move', child: ListTile(dense: true, leading: Icon(Icons.drive_file_move_outline), title: Text(tr('Move to…')))),
              PopupMenuItem(value: 'delete', child: ListTile(dense: true, leading: Icon(Icons.delete_outline_rounded, color: G4MColors.danger), title: Text(tr('Delete')))),
            ],
          ),
        ]),
      ),
    ).animate().fadeIn(duration: 200.ms);
  }
}

class _HoverRow extends StatefulWidget {
  const _HoverRow({required this.child});
  final Widget child;
  @override
  State<_HoverRow> createState() => _HoverRowState();
}

class _HoverRowState extends State<_HoverRow> {
  bool _h = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
        onEnter: (_) => setState(() => _h = true),
        onExit: (_) => setState(() => _h = false),
        child: AnimatedContainer(
          duration: G4MMotion.fast,
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
          decoration: BoxDecoration(color: _h ? context.pal.surfaceAlt.withValues(alpha: .7) : Colors.transparent, borderRadius: BorderRadius.circular(10)),
          child: widget.child,
        ),
      );
}
