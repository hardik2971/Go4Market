import 'package:flutter/material.dart';
import 'package:g4m_core/g4m_core.dart';

import '../core/data.dart';
import '../core/shop.dart';
import '../core/web_bridge.dart';
import '../l10n/l10n.dart';
import '../ui/kit.dart';
import '../ui/shell.dart';
import 'catalog_pages.dart' show Breadcrumbs;
import 'search_page.dart' show ProductListing;

class StorePage extends StatefulWidget {
  const StorePage({super.key, required this.slug});
  final String slug;
  @override
  State<StorePage> createState() => _StorePageState();
}

class _StorePageState extends State<StorePage> {
  late final Future<Seller?> _seller = Data.sellerBySlug(widget.slug);
  Future<List<Product>>? _products;
  String? _cat;

  @override
  Widget build(BuildContext context) => FutureBuilder<Seller?>(
        future: _seller,
        builder: (context, s) {
          if (s.hasError) return PageScroll(children: [EmptyState(icon: Icons.cloud_off_rounded, title: context.l.catalog.storeUnavailable, message: errorMessage(s.error!))]);
          if (s.connectionState != ConnectionState.done) return const PageScroll(children: [Padding(padding: EdgeInsets.all(80), child: Center(child: CircularProgressIndicator()))]);
          final seller = s.data;
          if (seller == null || seller.status != 'approved') {
            return PageScroll(children: [
              SeoMeta(
                title: context.l.catalog.storeNotFound,
                child: EmptyState(icon: Icons.storefront_outlined, title: context.l.catalog.storeNotAvailableTitle, message: context.l.catalog.storeClosedMessage),
              ),
            ]);
          }
          _products ??= Data.list(sellerId: seller.id, limit: 120);
          final phone = context.isPhone;
          return SeoMeta(
            title: '${seller.storeName}${seller.city.isEmpty ? '' : ', ${seller.city}'}',
            description: seller.description.isNotEmpty ? seller.description : context.l.catalog.storeSeoDescription(seller.storeName, seller.productCount),
            image: seller.banner.isNotEmpty ? seller.banner : null,
            child: PageScroll(children: [
              Contained(
                vertical: 24,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Breadcrumbs(items: [(context.l.common.navHome, '/'), (context.l.catalog.stores, null), (seller.storeName, null)]),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: SizedBox(
                      height: phone ? 140 : 260,
                      child: Stack(fit: StackFit.expand, children: [
                        seller.banner.isEmpty ? const DecoratedBox(decoration: BoxDecoration(gradient: G4MColors.heroGradient)) : NetImage(seller.banner, semanticLabel: context.l.catalog.storeBanner(seller.storeName)),
                        const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x00000000), Color(0x660A1A12)]))),
                      ]),
                    ),
                  ),
                  Transform.translate(
                    offset: const Offset(0, -44),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: phone ? 12 : 32),
                      child: Panel(
                        child: Flex(direction: phone ? Axis.vertical : Axis.horizontal, crossAxisAlignment: phone ? CrossAxisAlignment.start : CrossAxisAlignment.center, children: [
                          Container(
                            width: 88,
                            height: 88,
                            decoration: BoxDecoration(color: G4MColors.surfaceAlt, borderRadius: BorderRadius.circular(22), border: Border.all(color: Colors.white, width: 3), boxShadow: G4MShadows.soft),
                            clipBehavior: Clip.antiAlias,
                            child: seller.logo.isEmpty
                                ? Center(child: Text(seller.storeName.isEmpty ? 'S' : seller.storeName[0], style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: G4MColors.primaryDeep)))
                                : NetImage(seller.logo, semanticLabel: context.l.catalog.storeLogo(seller.storeName)),
                          ),
                          const SizedBox(width: 20, height: 14),
                          Flexible(
                            flex: phone ? 0 : 1,
                            fit: FlexFit.loose,
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                              Heading(seller.storeName, style: TextStyle(fontSize: phone ? 24 : 30)),
                              const SizedBox(height: 6),
                              Wrap(spacing: 14, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                                if (seller.rating > 0) Row(mainAxisSize: MainAxisSize.min, children: [RatingStars(seller.rating, size: 16), Text(' ${seller.rating.toStringAsFixed(1)}', style: const TextStyle(fontWeight: FontWeight.w700))]),
                                Text(context.l.catalog.productsCount(seller.productCount), style: const TextStyle(color: G4MColors.inkMuted, fontWeight: FontWeight.w600)),
                                if (seller.city.isNotEmpty) Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.location_on_outlined, size: 16, color: G4MColors.inkMuted), Text(seller.city, style: const TextStyle(color: G4MColors.inkMuted, fontWeight: FontWeight.w600))]),
                              ]),
                              if (seller.description.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Text(seller.description, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(height: 1.5)),
                              ],
                            ]),
                          ),
                          const SizedBox(width: 16, height: 14),
                          OutlinedButton.icon(
                            onPressed: () async {
                              final url = '$kSiteUrl/store/${seller.slug}';
                              if (!await WebBridge.share(title: seller.storeName, text: context.l.catalog.shopOnGo4Market(seller.storeName), url: url) && context.mounted) copyText(context, url, context.l.catalog.storeLinkCopied);
                            },
                            icon: const Icon(Icons.ios_share_rounded, size: 18),
                            label: Text(context.l.catalog.shareStore),
                          ),
                        ]),
                      ),
                    ),
                  ),
                  FutureBuilder<List<Product>>(
                    future: _products,
                    builder: (context, ps) {
                      final all = ps.data ?? const <Product>[];
                      final cats = <String>{for (final p in all) p.categoryId}.map(Shop.instance.categoryById).whereType<Category>().toList();
                      final items = _cat == null ? all : all.where((p) => p.categoryPath.contains(_cat) || p.categoryId == _cat).toList();
                      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        if (cats.length > 1) ...[
                          SizedBox(
                            height: 44,
                            child: ListView(scrollDirection: Axis.horizontal, children: [
                              Padding(padding: const EdgeInsetsDirectional.only(end: 8), child: ChoiceChip(label: Text(context.l.common.all), selected: _cat == null, onSelected: (_) => setState(() => _cat = null))),
                              for (final c in cats)
                                Padding(padding: const EdgeInsetsDirectional.only(end: 8), child: ChoiceChip(label: Text(c.name), selected: _cat == c.id, onSelected: (_) => setState(() => _cat = c.id))),
                            ]),
                          ),
                          const SizedBox(height: 18),
                        ],
                        if (ps.hasError)
                          EmptyState(icon: Icons.cloud_off_rounded, title: context.l.catalog.productsLoadError, message: errorMessage(ps.error!))
                        else
                          ProductListing(
                            key: ValueKey('${all.length}$_cat'),
                            items: items,
                            loading: !ps.hasData,
                            initialSort: 'newest',
                            emptyTitle: context.l.catalog.noProductsYet,
                            emptyMessage: context.l.catalog.stockingUp(seller.storeName),
                          ),
                      ]);
                    },
                  ),
                ]),
              ),
            ]),
          );
        },
      );
}
