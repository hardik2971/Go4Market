import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:g4m_core/g4m_core.dart';

import '../core/data.dart';
import '../core/shop.dart';
import '../l10n/l10n.dart';
import '../ui/kit.dart';
import '../ui/product_widgets.dart';
import '../ui/shell.dart';
import 'home_page.dart' show CategoryTile;

class Breadcrumbs extends StatelessWidget {
  const Breadcrumbs({super.key, required this.items});
  final List<(String, String?)> items;
  @override
  Widget build(BuildContext context) => Semantics(
        label: context.l.catalog.breadcrumb,
        child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Icon(Icons.chevron_right_rounded, size: 16, color: G4MColors.inkMuted)),
            items[i].$2 == null
                ? Text(items[i].$1, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: G4MColors.ink))
                : TextLink(items[i].$1, to: items[i].$2!, style: const TextStyle(fontSize: 13.5, color: G4MColors.inkMuted, fontWeight: FontWeight.w600)),
          ],
        ]),
      );
}

// ------------------------------------------------------------------ all categories

class CategoriesPage extends StatelessWidget {
  const CategoriesPage({super.key, this.moduleId});
  final String? moduleId;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Shop.instance,
        builder: (context, _) {
          final shop = Shop.instance;
          final mods = moduleId == null ? shop.modules : shop.modules.where((m) => m.id == moduleId).toList();
          return SeoMeta(
            title: context.l.common.allCategories,
            description: context.l.catalog.allCategoriesSeoDescription,
            child: PageScroll(children: [
              Contained(
                vertical: 28,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Breadcrumbs(items: [(context.l.common.navHome, '/'), (context.l.catalog.categories, null)]),
                  const SizedBox(height: 12),
                  Heading(context.l.common.allCategories),
                  const SizedBox(height: 6),
                  Text(context.l.catalog.categoriesSubtitle, style: const TextStyle(color: G4MColors.inkMuted, fontSize: 16)),
                  const SizedBox(height: 28),
                  if (!shop.catalogReady) const LinearProgressIndicator(),
                  if (shop.catalogReady && shop.categories.isEmpty)
                    EmptyState(icon: Icons.category_outlined, title: context.l.catalog.categoriesSoonTitle, message: context.l.catalog.categoriesSoonMessage),
                  for (final m in mods)
                    if (shop.roots(m.id).isNotEmpty) ...[
                      Row(children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(color: G4MColors.fromHex(m.themeColor).withValues(alpha: .12), borderRadius: BorderRadius.circular(12)),
                          child: Icon(moduleIcon(m.id), color: G4MColors.fromHex(m.themeColor)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Heading(m.name, level: 2, style: const TextStyle(fontSize: 22))),
                        ViewAllButton(to: '/m/${m.id}', label: context.l.catalog.visitStore(m.name)),
                      ]),
                      const SizedBox(height: 18),
                      LayoutBuilder(builder: (context, c) {
                        final roots = shop.roots(m.id);
                        final cols = c.maxWidth > 1100 ? 4 : (c.maxWidth > 700 ? 3 : (c.maxWidth > 420 ? 2 : 1));
                        final w = (c.maxWidth - 16 * (cols - 1)) / cols;
                        return Wrap(spacing: 16, runSpacing: 16, children: [
                          for (var i = 0; i < roots.length; i++)
                            SizedBox(width: w, child: Reveal(index: i % cols, child: _RootCard(category: roots[i], index: i))),
                        ]);
                      }),
                      const SizedBox(height: 40),
                    ],
                ]),
              ),
            ]),
          );
        },
      );
}

class _RootCard extends StatelessWidget {
  const _RootCard({required this.category, required this.index});
  final Category category;
  final int index;
  @override
  Widget build(BuildContext context) {
    final kids = Shop.instance.children(category.id);
    return HoverLift(
      radius: 22,
      lift: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          AppLink(
            to: '/c/${category.slug}',
            label: category.name,
            child: Row(children: [
              Container(
                width: 64,
                height: 64,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: G4MColors.pastels[index % G4MColors.pastels.length], borderRadius: BorderRadius.circular(16)),
                child: category.image.isEmpty ? Icon(moduleIcon(category.moduleId), color: G4MColors.primaryDeep) : NetImage(category.image, fit: BoxFit.contain, semanticLabel: category.name),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(category.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16.5)),
                  if (category.productCount > 0) Text(context.l.catalog.productsCount(category.productCount), style: const TextStyle(color: G4MColors.inkMuted, fontSize: 13)),
                ]),
              ),
              const Icon(Icons.arrow_forward_rounded, size: 18, color: G4MColors.primary),
            ]),
          ),
          if (kids.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final k in kids.take(8))
                AppLink(
                  to: '/c/${k.slug}',
                  label: k.name,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: G4MColors.surfaceAlt, borderRadius: BorderRadius.circular(G4MRadius.pill)),
                    child: Text(k.name, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                  ),
                ),
            ]),
          ],
        ]),
      ),
    );
  }
}

// ------------------------------------------------------------------ filters model

class ProductFilters {
  RangeValues? price;
  final brands = <String>{};
  String veg = 'any'; // any | veg | nonveg
  double minRating = 0;
  bool inStock = false;

  int get activeCount => (price != null ? 1 : 0) + (brands.isNotEmpty ? 1 : 0) + (veg != 'any' ? 1 : 0) + (minRating > 0 ? 1 : 0) + (inStock ? 1 : 0);

  void clear() {
    price = null;
    brands.clear();
    veg = 'any';
    minRating = 0;
    inStock = false;
  }

  bool test(Product p) {
    if (price != null && (p.price < price!.start || p.price > price!.end)) return false;
    if (brands.isNotEmpty && !brands.contains(p.brandName)) return false;
    if (veg == 'veg' && p.isVeg != true) return false;
    if (veg == 'nonveg' && p.isVeg != false) return false;
    if (minRating > 0 && p.rating < minRating) return false;
    if (inStock && !p.inStock) return false;
    return true;
  }
}

/// Sort keys; labels come from [CatalogStrings.sortLabel].
const sortOptions = ['newest', 'popular', 'price_asc', 'price_desc', 'rating', 'discount'];

class FilterPanel extends StatelessWidget {
  const FilterPanel({super.key, required this.filters, required this.all, required this.onChanged});
  final ProductFilters filters;
  final List<Product> all;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final f = filters;
    final s = context.l.catalog;
    final prices = all.map((p) => p.price).toList();
    final lo = prices.isEmpty ? 0.0 : prices.reduce((a, b) => a < b ? a : b).floorToDouble();
    final hi = prices.isEmpty ? 0.0 : prices.reduce((a, b) => a > b ? a : b).ceilToDouble();
    final brands = all.map((p) => p.brandName).where((b) => b.isNotEmpty).toSet().toList()..sort();
    final hasVeg = all.any((p) => p.isVeg != null);
    final range = f.price == null ? RangeValues(lo, hi) : RangeValues(f.price!.start.clamp(lo, hi), f.price!.end.clamp(lo, hi));
    Widget title(String t) => Padding(padding: const EdgeInsets.only(top: 18, bottom: 8), child: Text(t, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text(s.filters, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18))),
        if (f.activeCount > 0)
          TextButton(
            onPressed: () {
              f.clear();
              onChanged();
            },
            child: Text(s.clearAll),
          ),
      ]),
      if (hi > lo) ...[
        title(s.price),
        RangeSlider(
          values: range,
          min: lo,
          max: hi,
          divisions: ((hi - lo) / 10).clamp(1, 200).round(),
          labels: RangeLabels(context.l.money(range.start), context.l.money(range.end)),
          onChanged: (v) {
            f.price = v;
            onChanged();
          },
        ),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(context.l.money(range.start)), Text(context.l.money(range.end))]),
      ],
      title(s.availability),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        title: Text(s.inStockOnly, style: const TextStyle(fontWeight: FontWeight.w600)),
        value: f.inStock,
        onChanged: (v) {
          f.inStock = v;
          onChanged();
        },
      ),
      if (hasVeg) ...[
        title(s.dietaryPreference),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final o in [('any', s.any), ('veg', s.veg), ('nonveg', s.nonVeg)])
            ChoiceChip(
              label: Text(o.$2),
              avatar: o.$1 == 'any' ? null : VegMark(isVeg: o.$1 == 'veg', size: 12),
              selected: f.veg == o.$1,
              onSelected: (_) {
                f.veg = o.$1;
                onChanged();
              },
            ),
        ]),
      ],
      title(s.customerRating),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final r in const [0.0, 3.0, 4.0, 4.5])
          ChoiceChip(
            label: Text(r == 0 ? s.any : s.ratingAndUp(r)),
            selected: f.minRating == r,
            onSelected: (_) {
              f.minRating = r;
              onChanged();
            },
          ),
      ]),
      if (brands.isNotEmpty) ...[
        title(s.brand),
        for (final b in brands.take(20))
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(b, style: const TextStyle(fontWeight: FontWeight.w600)),
            value: f.brands.contains(b),
            onChanged: (v) {
              v == true ? f.brands.add(b) : f.brands.remove(b);
              onChanged();
            },
          ),
      ],
    ]);
  }
}

class ListingToolbar extends StatelessWidget {
  const ListingToolbar({super.key, required this.count, required this.sort, required this.onSort, required this.list, required this.onList, this.onFilters, this.filterCount = 0});
  final int count;
  final String sort;
  final ValueChanged<String> onSort;
  final bool list;
  final ValueChanged<bool> onList;
  final VoidCallback? onFilters;
  final int filterCount;
  @override
  Widget build(BuildContext context) => Row(children: [
        if (onFilters != null) ...[
          OutlinedButton.icon(
            onPressed: onFilters,
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 42)),
            icon: const Icon(Icons.tune_rounded, size: 18),
            label: Text(filterCount > 0 ? context.l.catalog.filtersCount(filterCount) : context.l.catalog.filters),
          ),
          const SizedBox(width: 10),
        ],
        if (!context.isPhone) Text(context.l.catalog.productsCount(count), style: const TextStyle(color: G4MColors.inkMuted, fontWeight: FontWeight.w600)),
        const Spacer(),
        Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(color: Colors.white, border: Border.all(color: G4MColors.line), borderRadius: BorderRadius.circular(G4MRadius.sm)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: sort,
              borderRadius: BorderRadius.circular(G4MRadius.sm),
              icon: const Icon(Icons.swap_vert_rounded, size: 18),
              style: const TextStyle(fontWeight: FontWeight.w700, color: G4MColors.ink, fontSize: 14),
              items: [
                for (final o in sortOptions)
                  DropdownMenuItem(
                    value: o,
                    child: Text(context.isPhone ? context.l.catalog.sortLabel(o).split(':').first : context.l.catalog.sortPrefixed(context.l.catalog.sortLabel(o))),
                  ),
              ],
              onChanged: (v) => v == null ? null : onSort(v),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SegmentedButton<bool>(
          showSelectedIcon: false,
          style: SegmentedButton.styleFrom(minimumSize: const Size(0, 42), visualDensity: VisualDensity.compact),
          segments: [
            ButtonSegment(value: false, icon: const Icon(Icons.grid_view_rounded, size: 18), tooltip: context.l.catalog.gridView),
            ButtonSegment(value: true, icon: const Icon(Icons.view_agenda_outlined, size: 18), tooltip: context.l.catalog.listView),
          ],
          selected: {list},
          onSelectionChanged: (s) => onList(s.first),
        ),
      ]);
}

// ------------------------------------------------------------------ category page

class CategoryPage extends StatefulWidget {
  const CategoryPage({super.key, required this.slug});
  final String slug;
  @override
  State<CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage> {
  final _filters = ProductFilters();
  String _sort = 'newest';
  bool _list = false;
  final _items = <Product>[];
  DocumentSnapshot? _last;
  bool _more = true, _loading = false;
  Object? _error;
  String? _loadedFor;

  Future<void> _load({bool reset = false}) async {
    final c = Shop.instance.categoryBySlug(widget.slug);
    if (c == null || _loading || (!_more && !reset)) return;
    if (reset) {
      _items.clear();
      _last = null;
      _more = true;
    }
    setState(() => _loading = true);
    try {
      final page = await Data.productPage(categoryId: c.id, sort: _sort, after: _last);
      _items.addAll(page.items.where((p) => !_items.any((e) => e.id == p.id)));
      _last = page.last;
      _more = page.more;
      _error = null;
    } catch (e) {
      _error = e;
      _more = false;
    }
    if (mounted) setState(() => _loading = false);
  }

  void _openFilters() => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, set) => DraggableScrollableSheet(
            expand: false,
            initialChildSize: .8,
            builder: (_, sc) => ListView(controller: sc, padding: const EdgeInsets.fromLTRB(20, 0, 20, 24), children: [
              FilterPanel(filters: _filters, all: _items, onChanged: () {
                set(() {});
                setState(() {});
              }),
              const SizedBox(height: 16),
              FilledButton(onPressed: () => Navigator.pop(ctx), child: Text(ctx.l.catalog.showProducts(_items.where(_filters.test).length))),
            ]),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Shop.instance,
        builder: (context, _) {
          final shop = Shop.instance;
          final c = shop.categoryBySlug(widget.slug);
          if (c == null) {
            return PageScroll(children: [
              if (!shop.catalogReady)
                const Padding(padding: EdgeInsets.all(80), child: Center(child: CircularProgressIndicator()))
              else
                SeoMeta(
                  title: context.l.catalog.categoryNotFound,
                  child: EmptyState(icon: Icons.search_off_rounded, title: context.l.catalog.categoryNotFoundTitle, message: context.l.catalog.categoryNotFoundMessage),
                ),
            ]);
          }
          if (_loadedFor != c.id) {
            _loadedFor = c.id;
            WidgetsBinding.instance.addPostFrameCallback((_) => _load(reset: true));
          }
          final trail = shop.trail(c);
          final kids = shop.children(c.id);
          final siblings = c.parentId == null || c.parentId!.isEmpty ? shop.roots(c.moduleId) : shop.children(c.parentId!);
          final module = shop.module(c.moduleId);
          final shown = _items.where(_filters.test).toList();
          final desktop = context.isDesktop;
          final listing = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            ListingToolbar(
              count: shown.length,
              sort: _sort,
              onSort: (v) {
                _sort = v;
                _load(reset: true);
              },
              list: _list,
              onList: (v) => setState(() => _list = v),
              onFilters: desktop ? null : _openFilters,
              filterCount: _filters.activeCount,
            ),
            const SizedBox(height: 18),
            if (_error != null && _items.isEmpty)
              EmptyState(icon: Icons.cloud_off_rounded, title: context.l.catalog.productsLoadError, message: errorMessage(_error!))
            else if (_items.isEmpty && _loading)
              ProductGrid(products: const [], loading: true, list: _list, maxCols: desktop ? 4 : 6)
            else if (shown.isEmpty)
              EmptyState(
                icon: Icons.inventory_2_outlined,
                title: _items.isEmpty ? context.l.catalog.noProductsHere : context.l.catalog.noFilterMatch,
                message: _items.isEmpty ? context.l.catalog.sellersAdding(c.name) : context.l.catalog.tryRemovingFilter,
                action: _filters.activeCount > 0 ? OutlinedButton(onPressed: () => setState(_filters.clear), child: Text(context.l.catalog.clearFilters)) : null,
              )
            else
              ProductGrid(products: shown, list: _list, maxCols: desktop ? 4 : 6),
            if (_loading && _items.isNotEmpty) const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
          ]);
          return SeoMeta(
            title: '${c.name}${module == null ? '' : ' | ${module.name}'}',
            description: context.l.catalog.categorySeoDescription(c.name, c.productCount),
            child: PageScroll(
              onNearEnd: () {
                if (_more && !_loading) _load();
              },
              children: [
                Contained(
                  vertical: 24,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Breadcrumbs(items: [
                      (context.l.common.navHome, '/'),
                      if (module != null) (module.name, '/m/${module.id}'),
                      for (final t in trail) (t.name, t.id == c.id ? null : '/c/${t.slug}'),
                    ]),
                    const SizedBox(height: 14),
                    Container(
                      padding: EdgeInsets.all(context.isPhone ? 18 : 28),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [G4MColors.fromHex(module?.themeColor).withValues(alpha: .10), const Color(0xFFFFF7EE)]),
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: Row(children: [
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Heading(c.name, style: TextStyle(fontSize: context.isPhone ? 26 : 36)),
                            const SizedBox(height: 6),
                            Text(
                              kids.isEmpty ? context.l.catalog.exploreFrom(c.name) : context.l.catalog.subCategories(kids.length),
                              style: const TextStyle(color: G4MColors.inkMuted, fontSize: 15.5),
                            ),
                          ]),
                        ),
                        if (c.image.isNotEmpty && !context.isPhone) SizedBox(width: 120, height: 120, child: NetImage(c.image, fit: BoxFit.contain, semanticLabel: c.name)),
                      ]),
                    ),
                    if (kids.isNotEmpty) ...[
                      const SizedBox(height: 22),
                      SizedBox(
                        height: (context.isPhone ? 84 : 104) + 48,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: kids.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 14),
                          itemBuilder: (_, i) => Reveal(index: i, child: CategoryTile(category: kids[i], size: context.isPhone ? 84 : 104, index: i)),
                        ),
                      ),
                    ],
                    const SizedBox(height: 22),
                    if (desktop)
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        SizedBox(
                          width: 270,
                          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                            Panel(
                              padding: const EdgeInsets.all(18),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(context.l.catalog.categories, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                                const SizedBox(height: 10),
                                for (final s in siblings) _TreeLink(category: s, selected: s.id == c.id || c.path.contains(s.id), depth: 0),
                                for (final k in kids) _TreeLink(category: k, selected: false, depth: 1),
                              ]),
                            ),
                            const SizedBox(height: 16),
                            Panel(padding: const EdgeInsets.all(18), child: FilterPanel(filters: _filters, all: _items, onChanged: () => setState(() {}))),
                          ]),
                        ),
                        const SizedBox(width: 24),
                        Expanded(child: listing),
                      ])
                    else
                      listing,
                  ]),
                ),
              ],
            ),
          );
        },
      );
}

class _TreeLink extends StatelessWidget {
  const _TreeLink({required this.category, required this.selected, required this.depth});
  final Category category;
  final bool selected;
  final int depth;
  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsetsDirectional.only(start: depth * 16.0, bottom: 2),
        child: AppLink(
          to: '/c/${category.slug}',
          label: category.name,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(color: selected ? G4MColors.primarySoft : Colors.transparent, borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              if (depth > 0) Transform.flip(flipX: context.l.rtl, child: const Icon(Icons.subdirectory_arrow_right_rounded, size: 16, color: G4MColors.inkMuted)),
              if (depth > 0) const SizedBox(width: 4),
              Expanded(child: Text(category.name, style: TextStyle(fontWeight: selected ? FontWeight.w800 : FontWeight.w600, color: selected ? G4MColors.primaryDeep : G4MColors.ink))),
              if (category.productCount > 0) Text(context.l.number(category.productCount), style: const TextStyle(fontSize: 12.5, color: G4MColors.inkMuted)),
            ]),
          ),
        ),
      );
}
