import 'package:flutter/material.dart';
import 'package:g4m_core/g4m_core.dart';

import '../../core/data.dart';
import '../../core/nav.dart';
import '../../core/prefs.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/product_card.dart';
import '../../widgets/ui.dart';
import '../search/search_screen.dart';

class ProductFilters {
  RangeValues? price;
  double minRating = 0;
  bool inStockOnly = false;
  bool vegOnly = false;
  bool dealsOnly = false;
  Set<String> brands = {};

  int get count =>
      (price != null ? 1 : 0) + (minRating > 0 ? 1 : 0) + (inStockOnly ? 1 : 0) + (vegOnly ? 1 : 0) + (dealsOnly ? 1 : 0) + (brands.isNotEmpty ? 1 : 0);

  bool test(Product p) {
    if (price != null && (p.price < price!.start || p.price > price!.end)) return false;
    if (minRating > 0 && p.rating < minRating) return false;
    if (inStockOnly && !p.inStock) return false;
    if (vegOnly && p.isVeg != true) return false;
    if (dealsOnly && p.discountPct <= 0) return false;
    if (brands.isNotEmpty && !brands.contains(p.brandName)) return false;
    return true;
  }

  ProductFilters copy() => ProductFilters()
    ..price = price
    ..minRating = minRating
    ..inStockOnly = inStockOnly
    ..vegOnly = vegOnly
    ..dealsOnly = dealsOnly
    ..brands = {...brands};
}

const _sorts = {
  'newest': 'Newest',
  'popular': 'Popular',
  'price_asc': 'Price ↑',
  'price_desc': 'Price ↓',
  'rating': 'Top rated',
  'discount': 'Best deals',
};

/// Product listing with sort chips, filter sheet and an animated grid/list toggle.
class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key, required this.title, this.moduleId, this.categoryId, this.sellerId, this.section, this.initialSort = 'newest'});
  final String title;
  final String? moduleId, categoryId, sellerId;
  final FeaturedSection? section;
  final String initialSort;
  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  late String _sort = widget.initialSort;
  var _filters = ProductFilters();
  List<Product>? _all;
  Object? _error;
  int _limit = 40;
  bool _loadingMore = false, _exhausted = false;
  String? _subCat;
  List<Category> _subs = [];
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _load();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 600) _more();
    });
    if (widget.categoryId != null) {
      CatalogRepo.instance.categories(parentId: widget.categoryId).first.then((l) {
        if (mounted) setState(() => _subs = l);
      }).catchError((_) {});
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = true}) async {
    if (reset) {
      setState(() {
        _all = null;
        _error = null;
        _limit = 40;
        _exhausted = false;
      });
    }
    try {
      List<Product> l;
      if (widget.section != null && _subCat == null) {
        l = await Catalog.section(widget.section!, limit: _limit);
        _exhausted = true;
        if (_sort != 'newest') Catalog.sortLocal(l, _sort);
      } else {
        l = await Catalog.products(
          moduleId: (_subCat ?? widget.categoryId) == null ? widget.moduleId : null,
          categoryId: _subCat ?? widget.categoryId,
          sellerId: widget.sellerId,
          sort: _sort,
          limit: _limit,
        );
        _exhausted = l.length < _limit;
      }
      Session.instance.remember(l);
      if (mounted) setState(() => _all = l);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _more() async {
    if (_loadingMore || _exhausted || _all == null || _limit >= 240) return;
    setState(() => _loadingMore = true);
    _limit += 40;
    await _load(reset: false);
    if (mounted) setState(() => _loadingMore = false);
  }

  Future<void> _openFilters() async {
    final all = _all ?? const <Product>[];
    final r = await showAppSheet<ProductFilters>(context, builder: (_) => _FilterSheet(initial: _filters.copy(), products: all));
    if (r != null) setState(() => _filters = r);
  }

  @override
  Widget build(BuildContext context) {
    final grid = AppPrefs.instance.gridView;
    final list = (_all ?? const <Product>[]).where(_filters.test).toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(onPressed: () => context.push(const SearchScreen(), style: RouteStyle.fadeThrough), icon: const Icon(Icons.search_rounded)),
          const CartAction(),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(),
        child: CustomScrollView(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            if (_subs.isNotEmpty)
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 48,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    itemCount: _subs.length + 1,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final id = i == 0 ? null : _subs[i - 1].id;
                      return ChoiceChip(
                        label: Text(i == 0 ? 'All' : _subs[i - 1].name),
                        selected: _subCat == id,
                        onSelected: (_) {
                          setState(() => _subCat = id);
                          _load();
                        },
                      );
                    },
                  ),
                ),
              ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _ToolbarDelegate(
                child: Container(
                  color: context.theme.scaffoldBackgroundColor,
                  padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
                  child: Row(children: [
                    Badge(
                      isLabelVisible: _filters.count > 0,
                      label: Text('${_filters.count}'),
                      backgroundColor: G4MColors.accent,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(minimumSize: const Size(0, 38), padding: const EdgeInsets.symmetric(horizontal: 12)),
                        onPressed: _openFilters,
                        icon: const Icon(Icons.tune_rounded, size: 18),
                        label: const Text('Filter'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(children: [
                          for (final e in _sorts.entries)
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(
                                label: Text(e.value),
                                selected: _sort == e.key,
                                visualDensity: VisualDensity.compact,
                                onSelected: (_) {
                                  setState(() => _sort = e.key);
                                  _load();
                                },
                              ),
                            ),
                        ]),
                      ),
                    ),
                    IconButton(
                      tooltip: grid ? 'List view' : 'Grid view',
                      onPressed: () => setState(() => AppPrefs.instance.setGridView(!grid)),
                      icon: AnimatedSwitcher(
                        duration: G4MMotion.standard,
                        transitionBuilder: (c, a) => RotationTransition(turns: Tween(begin: .75, end: 1.0).animate(a), child: FadeTransition(opacity: a, child: c)),
                        child: Icon(grid ? Icons.view_agenda_outlined : Icons.grid_view_rounded, key: ValueKey(grid)),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
            if (_error != null)
              SliverFillRemaining(hasScrollBody: false, child: ErrorView(error: _error!, onRetry: _load))
            else if (_all == null)
              const ProductGridSkeleton(sliver: true)
            else if (list.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: Icons.inventory_2_outlined,
                  title: _filters.count > 0 ? 'No products match these filters' : 'Nothing here yet',
                  message: _filters.count > 0 ? 'Try removing a filter.' : 'Sellers are adding products to this aisle.',
                  action: _filters.count > 0 ? OutlinedButton(onPressed: () => setState(() => _filters = ProductFilters()), child: const Text('Clear filters')) : null,
                ),
              )
            else
              SliverAnimatedSwitcher(
                duration: G4MMotion.emphasized,
                child: grid
                    ? SliverProductGrid(key: const ValueKey('g'), products: list, scope: 'pl')
                    : SliverPadding(
                        key: const ValueKey('l'),
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        sliver: SliverList.separated(
                          itemCount: list.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (_, i) => ProductTile(product: list[i], scope: 'pl').stagger(i % 10),
                        ),
                      ),
              ),
            if (_loadingMore)
              const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator()))),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }
}

class _ToolbarDelegate extends SliverPersistentHeaderDelegate {
  _ToolbarDelegate({required this.child});
  final Widget child;
  @override
  double get minExtent => 52;
  @override
  double get maxExtent => 52;
  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => child;
  @override
  bool shouldRebuild(_ToolbarDelegate old) => true;
}

/// Sliver version of AnimatedSwitcher (cross-fade between grid and list).
class SliverAnimatedSwitcher extends StatelessWidget {
  const SliverAnimatedSwitcher({super.key, required this.child, required this.duration});
  final Widget child;
  final Duration duration;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        key: child.key,
        tween: Tween(begin: 0, end: 1),
        duration: duration,
        curve: G4MMotion.curve,
        builder: (_, t, c) => SliverOpacity(opacity: t, sliver: c),
        child: child,
      );
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.initial, required this.products});
  final ProductFilters initial;
  final List<Product> products;
  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late final f = widget.initial;
  late final double _max = widget.products.fold<double>(0, (m, p) => p.price > m ? p.price : m).ceilToDouble().clamp(100, 1e7);
  late final _brands = widget.products.map((p) => p.brandName).where((b) => b.isNotEmpty).toSet().toList()..sort();

  @override
  Widget build(BuildContext context) {
    final range = f.price ?? RangeValues(0, _max);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('Filters', style: context.text.titleLarge)),
            TextButton(onPressed: () => Navigator.of(context).pop(ProductFilters()), child: const Text('Reset')),
          ]),
          const SizedBox(height: 8),
          Text('Price  ${Fmt.money(range.start)} – ${Fmt.money(range.end)}', style: context.text.titleSmall),
          RangeSlider(
            values: range,
            min: 0,
            max: _max,
            divisions: 50,
            activeColor: G4MColors.primary,
            onChanged: (v) => setState(() => f.price = v),
          ),
          const SizedBox(height: 8),
          Text('Rating', style: context.text.titleSmall),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            for (final r in [0.0, 3.0, 4.0, 4.5])
              ChoiceChip(
                label: Text(r == 0 ? 'Any' : '${r.toStringAsFixed(r % 1 == 0 ? 0 : 1)}★ & up'),
                selected: f.minRating == r,
                onSelected: (_) => setState(() => f.minRating = r),
              ),
          ]),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('In stock only'),
            value: f.inStockOnly,
            onChanged: (v) => setState(() => f.inStockOnly = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Row(children: [VegMark(isVeg: true), SizedBox(width: 8), Text('Veg only')]),
            value: f.vegOnly,
            onChanged: (v) => setState(() => f.vegOnly = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Discounted items'),
            value: f.dealsOnly,
            onChanged: (v) => setState(() => f.dealsOnly = v),
          ),
          if (_brands.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Brands', style: context.text.titleSmall),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final b in _brands)
                FilterChip(
                  label: Text(b),
                  selected: f.brands.contains(b),
                  onSelected: (on) => setState(() => on ? f.brands.add(b) : f.brands.remove(b)),
                ),
            ]),
          ],
          const SizedBox(height: 20),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            onPressed: () => Navigator.of(context).pop(f),
            child: const Text('Show results'),
          ),
        ]),
      ),
    );
  }
}
