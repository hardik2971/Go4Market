import 'package:flutter/material.dart';
import 'package:g4m_core/g4m_core.dart';

import '../../core/data.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/product_card.dart';
import '../../widgets/ui.dart';

/// Seller storefront: banner, logo, rating and the seller's products.
class SellerScreen extends StatefulWidget {
  const SellerScreen({super.key, required this.sellerId, this.seller});
  final String sellerId;
  final Seller? seller;
  @override
  State<SellerScreen> createState() => _SellerScreenState();
}

class _SellerScreenState extends State<SellerScreen> {
  late final Future<Seller?> _seller = widget.seller != null
      ? Future.value(widget.seller)
      : Fs.sellers.doc(widget.sellerId).get().then((d) => d.exists ? Seller.fromDoc(d) : null).catchError((_) => null);
  late Future<List<Product>> _products = _load();
  String _sort = 'popular';

  Future<List<Product>> _load() async {
    final l = await Catalog.products(sellerId: widget.sellerId, sort: _sort, limit: 80);
    Session.instance.remember(l);
    return l;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: FutureBuilder<Seller?>(
          future: _seller,
          builder: (context, ss) {
            final s = ss.data;
            return CustomScrollView(slivers: [
              SliverAppBar(
                pinned: true,
                expandedHeight: 200,
                actions: const [CartAction()],
                title: Text(s?.storeName ?? 'Store'),
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(fit: StackFit.expand, children: [
                    s == null || s.banner.isEmpty
                        ? Container(decoration: const BoxDecoration(gradient: G4MColors.heroGradient))
                        : Img(s.banner),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.black.withValues(alpha: .2), Colors.black.withValues(alpha: .55)],
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
              if (s != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: AppCard(
                      child: Row(children: [
                        ClipOval(child: Img(s.logo, width: 56, height: 56, iconSize: 22)),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(s.storeName, style: context.text.titleMedium),
                            if (s.description.isNotEmpty) Text(s.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.text.bodySmall),
                            const SizedBox(height: 6),
                            Row(children: [
                              if (s.rating > 0) Tag('★ ${s.rating.toStringAsFixed(1)}', color: G4MColors.success),
                              const SizedBox(width: 6),
                              if (s.city.isNotEmpty) Tag(s.city, color: G4MColors.primary, filled: false, icon: Icons.location_on_rounded),
                            ]),
                          ]),
                        ),
                      ]),
                    ).stagger(0),
                  ),
                ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 54,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    children: [
                      for (final e in const {'popular': 'Popular', 'newest': 'Newest', 'price_asc': 'Price ↑', 'rating': 'Top rated'}.entries)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(e.value),
                            selected: _sort == e.key,
                            onSelected: (_) => setState(() {
                              _sort = e.key;
                              _products = _load();
                            }),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              FutureBuilder<List<Product>>(
                future: _products,
                builder: (context, snap) {
                  if (snap.hasError) {
                    return SliverToBoxAdapter(child: ErrorView(error: snap.error!, onRetry: () => setState(() => _products = _load())));
                  }
                  if (!snap.hasData) return const ProductGridSkeleton(sliver: true);
                  if (snap.data!.isEmpty) {
                    return const SliverToBoxAdapter(
                      child: EmptyState(icon: Icons.storefront_outlined, title: 'No products yet', message: 'This store is stocking its shelves.'),
                    );
                  }
                  return SliverProductGrid(products: snap.data!, scope: 'seller');
                },
              ),
            ]);
          },
        ),
      );
}
