import 'package:flutter/material.dart';
import 'package:g4m_core/g4m_core.dart';

import '../../core/data.dart';
import '../../core/nav.dart';
import '../../core/prefs.dart';
import '../../core/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/product_card.dart';
import '../../widgets/ui.dart';
import '../product/product_list_screen.dart';
import '../search/search_screen.dart';
import '../shell/main_shell.dart';

/// In-memory category tree for one module (supports unlimited depth via parentId).
class CatTree {
  CatTree(List<Category> all) {
    for (final c in all) {
      byId[c.id] = c;
      final p = (c.parentId ?? '').isEmpty ? '' : c.parentId!;
      children.putIfAbsent(p, () => []).add(c);
    }
    for (final l in children.values) {
      l.sort((a, b) => a.order.compareTo(b.order));
    }
  }
  final byId = <String, Category>{};
  final children = <String, List<Category>>{};
  List<Category> get roots => children[''] ?? const [];
  List<Category> of(String id) => children[id] ?? const [];
  bool hasChildren(String id) => (children[id] ?? const []).isNotEmpty;
  List<Category> trail(Category c) {
    final out = <Category>[c];
    var cur = c;
    while ((cur.parentId ?? '').isNotEmpty && byId[cur.parentId] != null) {
      cur = byId[cur.parentId]!;
      out.insert(0, cur);
    }
    return out;
  }
}

/// Two-pane category browser: root rail on the left, animated sub-category grid on the right.
class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});
  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  String? _selected;
  String? _streamModule;
  Stream<List<Category>>? _stream;
  Stream<List<Category>> _cats(String moduleId) {
    if (_stream == null || _streamModule != moduleId) {
      _streamModule = moduleId;
      _stream = CatalogRepo.instance.categories(moduleId: moduleId);
    }
    return _stream!;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: AppPrefs.instance,
      builder: (context, _) {
        final moduleId = AppPrefs.instance.moduleId;
        return Scaffold(
          appBar: AppBar(
            title: Text(l.categories),
            actions: [
              IconButton(onPressed: () => context.push(const SearchScreen(), style: RouteStyle.fadeThrough), icon: const Icon(Icons.search_rounded)),
              const CartAction(),
            ],
            bottom: PreferredSize(preferredSize: const Size.fromHeight(52), child: _ModuleTabs(selected: moduleId, onChanged: (_) => setState(() => _selected = null))),
          ),
          body: StreamBuilder<List<Category>>(
            stream: _cats(moduleId),
            builder: (context, snap) {
              if (snap.hasError) return ErrorView(error: snap.error!, onRetry: () => setState(() => _stream = null));
              if (!snap.hasData) {
                return Row(children: [
                  SizedBox(width: 92, child: ListSkeleton(count: 7, height: 72)),
                  const Expanded(child: ProductGridSkeleton(count: 6)),
                ]);
              }
              final tree = CatTree(snap.data!);
              final roots = tree.roots;
              if (roots.isEmpty) {
                return const EmptyState(icon: Icons.category_outlined, title: 'No categories yet', message: 'This store is setting up its aisles.');
              }
              final sel = roots.firstWhere((c) => c.id == _selected, orElse: () => roots.first);
              return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(
                  width: 92,
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: kNavPad),
                    itemCount: roots.length,
                    itemBuilder: (_, i) {
                      final c = roots[i];
                      final on = c.id == sel.id;
                      return InkWell(
                        onTap: () => setState(() => _selected = c.id),
                        child: AnimatedContainer(
                          duration: G4MMotion.standard,
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                          decoration: BoxDecoration(
                            color: on ? context.card : Colors.transparent,
                            border: Border(left: BorderSide(color: on ? G4MColors.primary : Colors.transparent, width: 3.5)),
                          ),
                          child: Column(children: [
                            AnimatedScale(
                              scale: on ? 1.08 : 1,
                              duration: G4MMotion.standard,
                              child: Container(
                                width: 52,
                                height: 52,
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: context.isDark ? context.cardAlt : G4MColors.pastels[i % G4MColors.pastels.length],
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Img(c.image, fit: BoxFit.contain, iconSize: 18),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(c.name,
                                maxLines: 2,
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  height: 1.2,
                                  fontWeight: on ? FontWeight.w800 : FontWeight.w600,
                                  color: on ? G4MColors.primary : context.ink,
                                )),
                          ]),
                        ),
                      ).stagger(i, dy: 0);
                    },
                  ),
                ),
                VerticalDivider(width: 1, color: context.line),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: G4MMotion.emphasized,
                    switchInCurve: G4MMotion.curve,
                    transitionBuilder: (c, a) => FadeTransition(
                      opacity: a,
                      child: SlideTransition(position: Tween(begin: const Offset(.04, 0), end: Offset.zero).animate(a), child: c),
                    ),
                    child: _SubGrid(key: ValueKey(sel.id), tree: tree, parent: sel, moduleId: moduleId),
                  ),
                ),
              ]);
            },
          ),
        );
      },
    );
  }
}

class _ModuleTabs extends StatelessWidget {
  const _ModuleTabs({required this.selected, required this.onChanged});
  final String selected;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<List<MarketModule>>(
        valueListenable: AppConfig.modules,
        builder: (context, mods, _) {
          return SizedBox(
            height: 52,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              itemCount: mods.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final m = mods[i];
                final on = m.id == selected;
                final c = G4MColors.fromHex(m.themeColor);
                return ChoiceChip(
                  selected: on,
                  showCheckmark: false,
                  avatar: Icon(moduleIcon(m), size: 16, color: on ? Colors.white : c),
                  label: Text(m.name),
                  labelStyle: TextStyle(color: on ? Colors.white : context.ink, fontWeight: FontWeight.w700),
                  selectedColor: c,
                  onSelected: (_) {
                    AppPrefs.instance.setModule(m.id);
                    onChanged(m.id);
                  },
                );
              },
            ),
          );
        },
      );
}

class _SubGrid extends StatelessWidget {
  const _SubGrid({super.key, required this.tree, required this.parent, required this.moduleId});
  final CatTree tree;
  final Category parent;
  final String moduleId;
  @override
  Widget build(BuildContext context) {
    final subs = tree.of(parent.id);
    return CustomScrollView(slivers: [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
          child: AppCard(
            padding: const EdgeInsets.all(14),
            color: context.softPrimary,
            onTap: () => context.push(ProductListScreen(title: parent.name, categoryId: parent.id, moduleId: moduleId)),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(parent.name, style: context.text.titleMedium),
                  Text(parent.productCount > 0 ? '${parent.productCount} products' : 'Browse everything',
                      style: context.text.bodySmall),
                ]),
              ),
              const Icon(Icons.arrow_forward_rounded, color: G4MColors.primary),
            ]),
          ),
        ),
      ),
      if (subs.isEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Tap above to see all products in ${parent.name}.', style: context.text.bodySmall),
          ),
        )
      else
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, kNavPad),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 14,
              crossAxisSpacing: 10,
              childAspectRatio: .72,
            ),
            delegate: SliverChildBuilderDelegate(
              (_, i) => _CategoryTile(category: subs[i], tree: tree, moduleId: moduleId, index: i).stagger(i),
              childCount: subs.length,
            ),
          ),
        ),
    ]);
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.category, required this.tree, required this.moduleId, required this.index});
  final Category category;
  final CatTree tree;
  final String moduleId;
  final int index;
  @override
  Widget build(BuildContext context) {
    final c = category;
    return Pressable(
      onTap: () => tree.hasChildren(c.id)
          ? context.push(CategoryDrillScreen(tree: tree, parent: c, moduleId: moduleId))
          : context.push(ProductListScreen(title: c.name, categoryId: c.id, moduleId: moduleId)),
      child: Column(children: [
        AspectRatio(
          aspectRatio: 1,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: context.isDark ? context.cardAlt : G4MColors.pastels[(index + 2) % G4MColors.pastels.length],
              borderRadius: BorderRadius.circular(18),
            ),
            child: Stack(children: [
              Positioned.fill(child: Img(c.image, fit: BoxFit.contain, iconSize: 20)),
              if (tree.hasChildren(c.id))
                const Positioned(right: 0, bottom: 0, child: Icon(Icons.chevron_right_rounded, size: 18, color: G4MColors.primary)),
            ]),
          ),
        ),
        const SizedBox(height: 6),
        Text(c.name,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: context.text.labelMedium?.copyWith(fontWeight: FontWeight.w700, height: 1.2)),
      ]),
    );
  }
}

/// Deeper levels of the tree with a tappable breadcrumb.
class CategoryDrillScreen extends StatelessWidget {
  const CategoryDrillScreen({super.key, required this.tree, required this.parent, required this.moduleId});
  final CatTree tree;
  final Category parent;
  final String moduleId;
  @override
  Widget build(BuildContext context) {
    final trail = tree.trail(parent);
    return Scaffold(
      appBar: AppBar(
        title: Text(parent.name),
        actions: const [CartAction()],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(36),
          child: SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: trail.length,
              separatorBuilder: (_, _) => Icon(Icons.chevron_right_rounded, size: 16, color: context.muted),
              itemBuilder: (_, i) => Center(
                child: Text(trail[i].name,
                    style: TextStyle(
                      fontWeight: i == trail.length - 1 ? FontWeight.w800 : FontWeight.w500,
                      color: i == trail.length - 1 ? G4MColors.primary : context.muted,
                    )),
              ),
            ),
          ),
        ),
      ),
      body: _SubGrid(tree: tree, parent: parent, moduleId: moduleId),
    );
  }
}
