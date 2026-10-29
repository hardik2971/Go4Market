import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:g4m_core/g4m_core.dart';
import 'package:go_router/go_router.dart';

import '../core/data.dart';
import '../core/shop.dart';
import '../l10n/l10n.dart';
import '../ui/kit.dart';
import '../ui/product_widgets.dart';
import '../ui/shell.dart';
import 'catalog_pages.dart';

/// Client-side filtered, sorted listing with a filter sidebar (desktop) or sheet (phone/tablet).
class ProductListing extends StatefulWidget {
  const ProductListing({super.key, required this.items, this.loading = false, this.initialSort = 'relevance', this.onSortChanged, this.emptyTitle, this.emptyMessage});
  final List<Product> items;
  final bool loading;
  final String initialSort;
  final ValueChanged<String>? onSortChanged;
  final String? emptyTitle;
  final String? emptyMessage;
  @override
  State<ProductListing> createState() => _ProductListingState();
}

class _ProductListingState extends State<ProductListing> {
  final _f = ProductFilters();
  late String _sort = widget.initialSort == 'relevance' ? 'relevance' : widget.initialSort;
  bool _list = false;

  void _sheet() => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, set) => DraggableScrollableSheet(
            expand: false,
            initialChildSize: .8,
            builder: (_, sc) => ListView(controller: sc, padding: const EdgeInsets.fromLTRB(20, 0, 20, 24), children: [
              FilterPanel(filters: _f, all: widget.items, onChanged: () {
                set(() {});
                setState(() {});
              }),
              const SizedBox(height: 16),
              FilledButton(onPressed: () => Navigator.pop(ctx), child: Text(ctx.l.catalog.showProducts(widget.items.where(_f.test).length))),
            ]),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    var shown = widget.items.where(_f.test).toList();
    if (_sort != 'relevance') shown = Data.sortProducts(shown, _sort);
    final desktop = context.isDesktop;
    final listing = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ListingToolbar(
        count: shown.length,
        sort: _sort == 'relevance' ? 'newest' : _sort,
        onSort: (v) {
          setState(() => _sort = v);
          widget.onSortChanged?.call(v);
        },
        list: _list,
        onList: (v) => setState(() => _list = v),
        onFilters: desktop ? null : _sheet,
        filterCount: _f.activeCount,
      ),
      const SizedBox(height: 18),
      if (widget.loading && widget.items.isEmpty)
        ProductGrid(products: const [], loading: true, list: _list, maxCols: desktop ? 4 : 6)
      else if (shown.isEmpty)
        EmptyState(
          icon: Icons.search_off_rounded,
          title: widget.items.isEmpty ? (widget.emptyTitle ?? context.l.catalog.noProductsFound) : context.l.catalog.noFilterMatch,
          message: widget.items.isEmpty ? widget.emptyMessage : context.l.catalog.tryRemovingFilter,
          action: _f.activeCount > 0 ? OutlinedButton(onPressed: () => setState(_f.clear), child: Text(context.l.catalog.clearFilters)) : null,
        )
      else
        ProductGrid(products: shown, list: _list, maxCols: desktop ? 4 : 6),
    ]);
    if (!desktop) return listing;
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 270, child: Panel(padding: const EdgeInsets.all(18), child: FilterPanel(filters: _f, all: widget.items, onChanged: () => setState(() {})))),
      const SizedBox(width: 24),
      Expanded(child: listing),
    ]);
  }
}

class SearchPage extends StatefulWidget {
  const SearchPage({super.key, required this.params});
  final Map<String, String> params;
  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  String get q => (widget.params['q'] ?? '').trim();
  String? get module => widget.params['module'];
  String get sort => widget.params['sort'] ?? 'relevance';
  late final List<String> _terms = q.isEmpty ? const [] : Data.splitTerms(q);
  bool get _multi => _terms.length > 1;

  List<Product> _items = [];
  bool _loading = true;
  Object? _error;
  DocumentSnapshot? _last;
  bool _more = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_multi) return;
    try {
      if (q.isEmpty) {
        if (widget.params['sort'] == null && module == null) {
          _loading = false;
          return;
        }
        final page = await Data.productPage(moduleId: module, sort: sort == 'relevance' || sort == 'discount' ? (sort == 'discount' ? 'popular' : 'newest') : sort, limit: 48);
        _items = page.items;
        _last = page.last;
        _more = page.more;
      } else {
        _items = await Data.search(q, limit: 60);
        if (module != null) _items = _items.where((p) => p.moduleId == module).toList();
      }
    } catch (e) {
      _error = e;
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadMore() async {
    if (!_more || _loading || q.isNotEmpty) return;
    setState(() => _loading = true);
    try {
      final page = await Data.productPage(moduleId: module, sort: sort == 'relevance' ? 'newest' : (sort == 'discount' ? 'popular' : sort), limit: 48, after: _last);
      _items = [..._items, ...page.items.where((p) => !_items.any((e) => e.id == p.id))];
      _last = page.last;
      _more = page.more;
    } catch (_) {
      _more = false;
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final shop = Shop.instance;
    final s = context.l.catalog;
    final title = q.isEmpty
        ? (sort == 'popular' ? s.bestSellers : sort == 'discount' ? s.topDeals : sort == 'rating' ? s.topRated : s.allProducts)
        : (_multi ? s.yourShoppingList : s.resultsFor(q));
    final matchingCats = q.isEmpty || _multi
        ? const <Category>[]
        : shop.categories.where((c) => c.name.toLowerCase().contains(q.toLowerCase())).take(8).toList();
    return SeoMeta(
      title: q.isEmpty ? title : s.searchSeoTitle(q),
      description: q.isEmpty ? s.browseSeoDescription(title) : s.searchSeoDescription(q),
      child: PageScroll(
        onNearEnd: _loadMore,
        children: [
          Contained(
            vertical: 24,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (!context.isPhone) ...[
                ConstrainedBox(constraints: const BoxConstraints(maxWidth: 720), child: SearchBox(initial: q, autofocus: q.isEmpty)),
                const SizedBox(height: 22),
              ],
              Heading(title, style: TextStyle(fontSize: context.isPhone ? 24 : 32)),
              if (_multi) ...[
                const SizedBox(height: 6),
                Text(s.splitInto(q, _terms.length), style: const TextStyle(color: G4MColors.inkMuted, fontSize: 15)),
              ],
              const SizedBox(height: 16),
              if (q.isEmpty && widget.params['sort'] == null && module == null) _SearchLanding(),
              if (matchingCats.isNotEmpty) ...[
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final c in matchingCats)
                    ActionChip(avatar: const Icon(Icons.category_outlined, size: 18), label: Text(c.name), onPressed: () => context.go('/c/${c.slug}')),
                ]),
                const SizedBox(height: 18),
              ],
              if (_multi)
                _ShoppingList(terms: _terms)
              else if (q.isNotEmpty || widget.params['sort'] != null || module != null)
                _error != null
                    ? EmptyState(icon: Icons.cloud_off_rounded, title: s.searchUnavailable, message: errorMessage(_error!))
                    : ProductListing(
                        key: ValueKey(_items.length),
                        items: _items,
                        loading: _loading,
                        initialSort: sort,
                        emptyTitle: s.noMatchesFor(q),
                        emptyMessage: s.noMatchesMessage,
                      ),
              if (q.isNotEmpty && !_loading && _items.isEmpty && !_multi)
                Center(child: FilledButton.tonalIcon(onPressed: () => context.go('/account?tab=request&name=${Uri.encodeQueryComponent(q)}'), icon: const Icon(Icons.add_task_rounded), label: Text(s.requestThisProduct))),
            ]),
          ),
        ],
      ),
    );
  }
}

class _SearchLanding extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final shop = Shop.instance;
    final cats = shop.roots().take(14).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Panel(
        color: G4MColors.primarySoft,
        child: Row(children: [
          const Icon(Icons.mic_rounded, color: G4MColors.primaryDeep, size: 32),
          const SizedBox(width: 14),
          Expanded(
            child: Text(context.l.catalog.voiceTip, style: const TextStyle(fontWeight: FontWeight.w600, height: 1.5)),
          ),
          VoiceButton(onResult: (t) => context.go('/search?q=${Uri.encodeQueryComponent(t)}')),
        ]),
      ),
      const SizedBox(height: 24),
      Text(context.l.catalog.popularNow, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final c in cats) ActionChip(label: Text(c.name), onPressed: () => context.go('/c/${c.slug}')),
        ActionChip(avatar: const Icon(Icons.local_offer_outlined, size: 18), label: Text(context.l.catalog.topDeals), onPressed: () => context.go('/search?sort=discount')),
        ActionChip(avatar: const Icon(Icons.trending_up_rounded, size: 18), label: Text(context.l.catalog.bestSellers), onPressed: () => context.go('/search?sort=popular')),
      ]),
    ]);
  }
}

/// Multi-product search: one result rail per spoken/typed item, with "add best match" shortcuts.
class _ShoppingList extends StatefulWidget {
  const _ShoppingList({required this.terms});
  final List<String> terms;
  @override
  State<_ShoppingList> createState() => _ShoppingListState();
}

class _ShoppingListState extends State<_ShoppingList> {
  late final _futures = {for (final t in widget.terms) t: Data.search(t, limit: 12)};

  Future<void> _addAll() async {
    var n = 0;
    for (final f in _futures.values) {
      final l = await f;
      final best = l.where((p) => p.inStock).firstOrNull;
      if (best != null && Shop.instance.qty(best.id, defaultVariantId(best)) == 0) {
        await Shop.instance.setQty(best, 1, variantId: defaultVariantId(best));
        n++;
      }
    }
    if (mounted) toast(context, n == 0 ? context.l.catalog.allAlreadyInCart : context.l.catalog.addedItems(n), actionLabel: context.l.catalog.viewCart, onAction: () => context.go('/cart'));
  }

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: FilledButton.icon(onPressed: _addAll, icon: const Icon(Icons.playlist_add_check_rounded), label: Text(context.l.catalog.addBestMatchAll)),
        ),
        const SizedBox(height: 24),
        for (var i = 0; i < widget.terms.length; i++) ...[
          Row(children: [
            CircleAvatar(radius: 15, backgroundColor: G4MColors.primary, child: Text(context.l.number(i + 1), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13))),
            const SizedBox(width: 10),
            Expanded(child: Heading(Fmt.titleCase(widget.terms[i]), level: 2, style: const TextStyle(fontSize: 20))),
            ViewAllButton(to: '/search?q=${Uri.encodeQueryComponent(widget.terms[i])}', label: context.l.catalog.allResultsFor(widget.terms[i])),
          ]),
          const SizedBox(height: 12),
          FutureBuilder<List<Product>>(
            future: _futures[widget.terms[i]],
            builder: (context, s) {
              if (!s.hasData && !s.hasError) return const ProductCarousel(products: [], loading: true);
              final l = s.data ?? const <Product>[];
              if (l.isEmpty) {
                return Panel(child: Text(context.l.catalog.noMatchTryAnother(widget.terms[i]), style: const TextStyle(color: G4MColors.inkMuted)));
              }
              return ProductCarousel(products: l);
            },
          ),
          const SizedBox(height: 28),
        ],
      ]);
}
