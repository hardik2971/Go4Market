import 'package:flutter/material.dart';
import 'package:g4m_core/g4m_core.dart';

import '../../core/l10n.dart';
import '../../core/live.dart';
import '../../core/motion.dart';
import '../../core/partner_theme.dart';
import '../../core/ui.dart';

/// Bottom sheet that drills through the nested category tree of one module.
/// Any level can be selected ("Use" on the current level), leaves select on tap.
Future<Category?> pickCategory(BuildContext context, String moduleId) => showModalBottomSheet<Category>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CategorySheet(moduleId: moduleId),
    );

class _CategorySheet extends StatefulWidget {
  const _CategorySheet({required this.moduleId});
  final String moduleId;
  @override
  State<_CategorySheet> createState() => _CategorySheetState();
}

class _CategorySheetState extends State<_CategorySheet> {
  late final Future<List<Category>> _all = resilientGet<Category>(
    [
      () => Fs.categories.where('moduleId', isEqualTo: widget.moduleId).where('active', isEqualTo: true),
      () => Fs.categories.where('moduleId', isEqualTo: widget.moduleId),
    ],
    Category.fromDoc,
  );
  final List<Category> _trail = [];
  String _q = '';

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: .75,
      maxChildSize: .95,
      builder: (context, sc) => FutureBuilder<List<Category>>(
        future: _all,
        builder: (context, snap) {
          if (snap.hasError) return ErrorView(snap.error!);
          if (!snap.hasData) return const SkeletonList(count: 5, itemHeight: 56);
          final all = snap.data!;
          final parent = _trail.isEmpty ? null : _trail.last;
          final q = _q.toLowerCase();
          final List<Category> items;
          if (q.isNotEmpty) {
            items = all.where((c) => c.name.toLowerCase().contains(q)).toList();
          } else {
            items = all.where((c) => (c.parentId ?? '') == (parent?.id ?? '')).toList();
          }
          items.sort((a, b) => a.order != b.order ? a.order.compareTo(b.order) : a.name.compareTo(b.name));
          bool hasKids(Category c) => all.any((x) => x.parentId == c.id);
          String pathOf(Category c) => [...c.path.map((id) => all.where((x) => x.id == id).firstOrNull?.name ?? ''), c.name]
              .where((e) => e.isNotEmpty)
              .join(' › ');

          return Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(context.tr('Choose category', 'श्रेणी चुनें'), style: context.tt.titleLarge),
                const SizedBox(height: 10),
                TextField(
                  decoration: InputDecoration(prefixIcon: const Icon(Icons.search_rounded), hintText: context.s.search, isDense: true),
                  onChanged: (v) => setState(() => _q = v.trim()),
                ),
                if (_trail.isNotEmpty && q.isEmpty) ...[
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: [
                      ActionChip(label: Text(context.tr('All', 'सभी')), onPressed: () => setState(_trail.clear)),
                      for (var i = 0; i < _trail.length; i++) ...[
                        Icon(Icons.chevron_right_rounded, size: 18, color: context.rc.faint),
                        ActionChip(label: Text(_trail[i].name), onPressed: () => setState(() => _trail.removeRange(i + 1, _trail.length))),
                      ],
                    ]),
                  ),
                ],
              ]),
            ),
            if (parent != null && q.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    icon: const Icon(Icons.check_rounded),
                    label: Text('${context.tr('Use', 'उपयोग करें')} "${parent.name}"'),
                    onPressed: () => Navigator.pop(context, parent),
                  ),
                ),
              ),
            Expanded(
              child: items.isEmpty
                  ? AppEmpty(icon: Icons.category_outlined, title: context.tr('No categories', 'कोई श्रेणी नहीं'))
                  : AnimatedSwitcher(
                      duration: G4MMotion.standard,
                      child: ListView.builder(
                        key: ValueKey('${parent?.id}_$q'),
                        controller: sc,
                        padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
                        itemCount: items.length,
                        itemBuilder: (context, i) {
                          final c = items[i];
                          final kids = hasKids(c);
                          return ListTile(
                            leading: c.image.isEmpty
                                ? CircleAvatar(backgroundColor: context.rc.brandSoft, child: Icon(Icons.category_rounded, color: context.rc.brand, size: 20))
                                : ClipOval(child: NetImage(c.image, width: 40, height: 40)),
                            title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: q.isNotEmpty ? Text(pathOf(c), maxLines: 1, overflow: TextOverflow.ellipsis) : null,
                            trailing: kids && q.isEmpty ? const Icon(Icons.chevron_right_rounded) : null,
                            onTap: () {
                              if (kids && q.isEmpty) {
                                setState(() => _trail.add(c));
                              } else {
                                Navigator.pop(context, c);
                              }
                            },
                          ).stagger(i, stepMs: 25);
                        },
                      ),
                    ),
            ),
          ]);
        },
      ),
    );
  }
}

/// Human-readable breadcrumb for a stored categoryPath.
Future<String> categoryBreadcrumb(List<String> ids) async {
  if (ids.isEmpty) return '';
  final names = <String>[];
  for (final id in ids) {
    try {
      final d = await Fs.categories.doc(id).get();
      final n = d.data()?['name'];
      if (n is String && n.isNotEmpty) names.add(n);
    } catch (_) {}
  }
  return names.join(' › ');
}
