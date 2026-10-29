import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:g4m_core/g4m_core.dart';
import 'package:go_router/go_router.dart';

import '../core/data.dart';
import '../core/shop.dart';
import '../core/web_bridge.dart';
import '../l10n/l10n.dart';
import '../ui/kit.dart';
import '../ui/lazy.dart';
import '../ui/product_widgets.dart';
import '../ui/shell.dart';
import 'catalog_pages.dart' show Breadcrumbs;

class ProductPage extends StatefulWidget {
  const ProductPage({super.key, required this.slug});
  final String slug;
  @override
  State<ProductPage> createState() => _ProductPageState();
}

class _ProductPageState extends State<ProductPage> {
  late final Future<Product?> _f = CatalogRepo.instance.productBySlug(widget.slug).then((p) {
    if (p != null) Shop.instance.markViewed(p.id);
    return p;
  });

  @override
  Widget build(BuildContext context) => FutureBuilder<Product?>(
        future: _f,
        builder: (context, s) {
          if (s.hasError) {
            return PageScroll(children: [EmptyState(icon: Icons.cloud_off_rounded, title: context.l.product.loadError, message: errorMessage(s.error!))]);
          }
          if (s.connectionState != ConnectionState.done) return const PageScroll(children: [_ProductSkeleton()]);
          final p = s.data;
          if (p == null || p.status != 'active') {
            return PageScroll(children: [
              SeoMeta(
                title: context.l.product.notFoundTitle,
                child: EmptyState(
                  icon: Icons.search_off_rounded,
                  title: context.l.product.notAvailable,
                  message: context.l.product.notAvailableBody,
                  action: FilledButton(onPressed: () => context.go('/search?q=${Uri.encodeQueryComponent(widget.slug.replaceAll('-', ' '))}'), child: Text(context.l.product.findSimilar)),
                ),
              ),
            ]);
          }
          return StreamBuilder<Product?>(
            stream: live('product_${p.id}', () => CatalogRepo.instance.watchProduct(p.id)),
            initialData: p,
            builder: (context, ls) => _ProductView(product: ls.data ?? p),
          );
        },
      );
}

class _ProductSkeleton extends StatelessWidget {
  const _ProductSkeleton();
  @override
  Widget build(BuildContext context) => Contained(
        vertical: 32,
        child: Flex(direction: context.isPhone ? Axis.vertical : Axis.horizontal, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Flexible(flex: context.isPhone ? 0 : 1, child: const AspectRatio(aspectRatio: 1, child: Skeleton(radius: 28))),
          const SizedBox(width: 32, height: 24),
          Flexible(
            flex: context.isPhone ? 0 : 1,
            child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Skeleton(width: 120, height: 14),
              SizedBox(height: 14),
              Skeleton(height: 34),
              SizedBox(height: 10),
              Skeleton(width: 260, height: 34),
              SizedBox(height: 24),
              Skeleton(width: 180, height: 28),
              SizedBox(height: 24),
              Skeleton(height: 52),
            ]),
          ),
        ]),
      );
}

class _ProductView extends StatefulWidget {
  const _ProductView({required this.product});
  final Product product;
  @override
  State<_ProductView> createState() => _ProductViewState();
}

class _ProductViewState extends State<_ProductView> {
  late String _variant = defaultVariantId(widget.product);
  final _addons = <String>{};

  /// Food add-ons / modifiers: `products.addons[{id, name, price, active}]`.
  List<Map<String, dynamic>> get _addonList => (p.data['addons'] is List ? p.data['addons'] as List : const [])
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .where((e) => e['active'] != false)
      .toList();
  double get _addonTotal => _addonList.where((a) => _addons.contains('${a['id']}')).fold(0.0, (s, a) => s + ((a['price'] as num?) ?? 0));
  final _reviewsKey = GlobalKey();

  Product get p => widget.product;
  Variant? get v => p.variants.where((e) => e.id == _variant).firstOrNull;

  @override
  void initState() {
    super.initState();
    WebBridge.setJsonLd('product', {
      '@context': 'https://schema.org',
      '@type': 'Product',
      'name': p.name,
      'image': p.images,
      'description': p.shortDescription.isEmpty ? p.name : p.shortDescription,
      'sku': p.id,
      if (p.brandName.isNotEmpty) 'brand': {'@type': 'Brand', 'name': p.brandName},
      if (p.ratingCount > 0) 'aggregateRating': {'@type': 'AggregateRating', 'ratingValue': p.rating, 'reviewCount': p.ratingCount},
      'offers': {
        '@type': 'Offer',
        'priceCurrency': 'INR',
        'price': p.price,
        'availability': p.inStock ? 'https://schema.org/InStock' : 'https://schema.org/OutOfStock',
        'url': '$kSiteUrl/p/${p.slug}',
      },
    });
  }

  @override
  void dispose() {
    WebBridge.setJsonLd('product', null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shop = Shop.instance;
    final cat = shop.categoryById(p.categoryId);
    final module = shop.module(p.moduleId);
    final trail = cat == null ? <Category>[] : shop.trail(cat);
    final phone = context.isPhone;
    final gallery = _Gallery(images: p.images, name: p.name);
    final info = _info(context);
    final l = context.l;
    final t = l.product;
    return SeoMeta(
      title: p.name,
      description: p.shortDescription.isNotEmpty ? p.shortDescription : t.seoDescription(p.name, l.money(p.price)),
      image: p.image,
      child: PageScroll(children: [
        Contained(
          vertical: 24,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Breadcrumbs(items: [
              (l.common.navHome, '/'),
              if (module != null) (module.name, '/m/${module.id}'),
              for (final t in trail) (t.name, '/c/${t.slug}'),
              (p.name, null),
            ]),
            const SizedBox(height: 18),
            if (context.isDesktop)
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(flex: 11, child: gallery),
                const SizedBox(width: 40),
                Expanded(flex: 10, child: info),
              ])
            else
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [gallery, const SizedBox(height: 24), info]),
            SizedBox(height: phone ? 32 : 56),
            _Details(product: p),
            SizedBox(height: phone ? 32 : 56),
            KeyedSubtree(key: _reviewsKey, child: _Reviews(product: p)),
            SizedBox(height: phone ? 32 : 56),
            ProductsFuture(
              key: ValueKey('sim${p.id}'),
              load: () => Data.similar(p, limit: 12),
              builder: (list) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                SectionHeader(title: p.inStock ? t.similarProducts : t.inStockAlternatives, subtitle: cat == null ? t.moreFromThisCategory : t.moreFrom(cat.name)),
                ProductCarousel(products: list),
                SizedBox(height: phone ? 32 : 56),
              ]),
            ),
            ProductsFuture(
              key: ValueKey('x${p.id}'),
              load: () => Data.crossSell(p, limit: 12),
              builder: (list) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                SectionHeader(eyebrow: t.completeBasket, title: t.boughtTogether),
                ProductCarousel(products: list),
                SizedBox(height: phone ? 32 : 56),
              ]),
            ),
            Builder(builder: (context) {
              final ids = shop.recentlyViewed.where((e) => e != p.id).take(12).toList();
              if (ids.isEmpty) return const SizedBox.shrink();
              return ProductsFuture(
                key: ValueKey('rv${ids.join()}'),
                load: () => CatalogRepo.instance.productsByIds(ids),
                builder: (list) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  SectionHeader(title: t.recentlyViewed),
                  ProductCarousel(products: list),
                ]),
              );
            }),
          ]),
        ),
      ]),
    );
  }

  Widget _info(BuildContext context) {
    final shop = Shop.instance;
    final price = v?.price ?? p.price;
    final mrp = v?.mrp ?? p.mrp;
    final stock = v?.stock ?? p.stock;
    final s = shop.settings;
    final quick = s.quick15Enabled && p.deliveryMinutes <= 15
        ? 15
        : (s.quick30Enabled && p.deliveryMinutes <= 30 ? 30 : null);
    final l = context.l;
    final t = l.product;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
        if (p.brandName.isNotEmpty) Pill(p.brandName, bg: G4MColors.primarySoft, fg: G4MColors.primaryDeep),
        if (p.isVeg != null)
          Row(mainAxisSize: MainAxisSize.min, children: [
            VegMark(isVeg: p.isVeg!, size: 16),
            const SizedBox(width: 6),
            Text(p.isVeg! ? t.vegetarian : t.nonVegetarian, style: TextStyle(fontWeight: FontWeight.w700, color: p.isVeg! ? kDiscountInk : G4MColors.danger, fontSize: 13)),
          ]),
        if (p.soldCount > 20) Pill(t.soldCount(l.number(p.soldCount)), icon: Icons.local_fire_department_rounded),
      ]),
      const SizedBox(height: 12),
      Heading(p.name, style: TextStyle(fontSize: context.isPhone ? 24 : 32, height: 1.2)),
      if (p.unit.isNotEmpty) Padding(padding: const EdgeInsetsDirectional.only(top: 6), child: Text(p.unit, style: const TextStyle(color: G4MColors.inkMuted, fontSize: 15, fontWeight: FontWeight.w600))),
      const SizedBox(height: 12),
      if (p.ratingCount > 0)
        InkWell(
          onTap: () => Scrollable.ensureVisible(_reviewsKey.currentContext!, duration: G4MMotion.slow, curve: G4MMotion.curve),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            RatingStars(p.rating, size: 18),
            const SizedBox(width: 8),
            Text('${p.rating.toStringAsFixed(1)} · ${t.ratingsCount(p.ratingCount, l.number(p.ratingCount))}', style: const TextStyle(fontWeight: FontWeight.w700, color: G4MColors.primary)),
          ]),
        ),
      const SizedBox(height: 20),
      Price(price: price, mrp: mrp, size: 30),
      const SizedBox(height: 4),
      Text(mrp > price ? t.youSave(l.money(mrp - price)) : t.inclusiveTaxes, style: const TextStyle(color: G4MColors.inkMuted, fontSize: 13.5)),
      if (p.variants.length > 1) ...[
        const SizedBox(height: 22),
        Text(t.chooseOption, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
        const SizedBox(height: 10),
        Wrap(spacing: 10, runSpacing: 10, children: [
          for (final e in p.variants)
            Semantics(
              button: true,
              selected: e.id == _variant,
              label: t.variantLabel(e.name, l.money(e.price), e.stock <= 0),
              excludeSemantics: true,
              child: Pressable(
                onTap: () => setState(() => _variant = e.id),
                child: AnimatedContainer(
                  duration: G4MMotion.standard,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: e.id == _variant ? G4MColors.primarySoft : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: e.id == _variant ? G4MColors.primary : G4MColors.line, width: e.id == _variant ? 1.8 : 1),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(e.name, style: TextStyle(fontWeight: FontWeight.w800, color: e.stock <= 0 ? G4MColors.inkMuted : G4MColors.ink, decoration: e.stock <= 0 ? TextDecoration.lineThrough : null)),
                    Text(l.money(e.price), style: const TextStyle(fontSize: 13, color: G4MColors.inkMuted, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            ),
        ]),
      ],
      const SizedBox(height: 18),
      Row(children: [
        Icon(stock > 0 ? Icons.check_circle_rounded : Icons.cancel_rounded, size: 18, color: stock > 0 ? kDiscountInk : G4MColors.danger),
        const SizedBox(width: 6),
        Text(
          stock <= 0 ? t.outOfStock : (stock <= p.lowStockAt ? t.onlyLeft(stock) : t.inStock),
          style: TextStyle(fontWeight: FontWeight.w700, color: stock <= 0 ? G4MColors.danger : (stock <= p.lowStockAt ? kAccentInk : kDiscountInk)),
        ),
      ]),
      if (_addonList.isNotEmpty) ...[
        const SizedBox(height: 20),
        Text(t.customise, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
        const SizedBox(height: 4),
        Text(t.addExtras, style: const TextStyle(color: G4MColors.inkMuted, fontSize: 13)),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final a in _addonList)
            FilterChip(
              label: Text('${a['name']}  +${l.money((a['price'] as num?) ?? 0)}'),
              selected: _addons.contains('${a['id']}'),
              onSelected: (v) => setState(() => v ? _addons.add('${a['id']}') : _addons.remove('${a['id']}')),
            ),
        ]),
      ],
      const SizedBox(height: 18),
      Row(children: [
        Expanded(
          child: _addonList.isEmpty
              ? AddToCartButton(product: p, variantId: _variant, compact: false, expand: true)
              : SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: stock <= 0
                        ? null
                        : () async {
                            try {
                              await Shop.instance.addWithAddons(p, _variant, _addons.toList());
                              if (context.mounted) toast(context, t.addedToCart, actionLabel: t.viewCart, onAction: () => context.go('/cart'));
                            } catch (e) {
                              if (context.mounted) toast(context, friendlyError(e), error: true);
                            }
                          },
                    icon: const Icon(Icons.shopping_bag_outlined),
                    label: Text(t.addToCartFor(l.money(price + _addonTotal))),
                  ),
                ),
        ),
        const SizedBox(width: 12),
        WishButton(productId: p.id, size: 52),
        const SizedBox(width: 8),
        IconButton.outlined(
          tooltip: t.share,
          style: IconButton.styleFrom(minimumSize: const Size(52, 52), side: const BorderSide(color: G4MColors.line)),
          onPressed: () async {
            final url = '$kSiteUrl/p/${p.slug}';
            if (!await WebBridge.share(title: p.name, text: t.shareText(p.name), url: url) && context.mounted) {
              copyText(context, url, t.linkCopied);
            }
          },
          icon: const Icon(Icons.ios_share_rounded),
        ),
      ]),
      if (p.moduleId == 'grocery' || p.moduleId == 'pharmacy') ...[
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => showSubscribeDialog(context, p, _variant),
          icon: const Icon(Icons.autorenew_rounded),
          label: Text(t.subscribeRegularly),
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
        ),
      ],
      const SizedBox(height: 22),
      Panel(
        padding: const EdgeInsets.all(16),
        color: const Color(0xFFF6FBF8),
        child: Column(children: [
          _Perk(
            icon: Icons.bolt_rounded,
            title: quick != null ? t.quickDelivery(quick) : t.deliveredAbout(p.deliveryMinutes),
            body: t.etaNote,
          ),
          const Divider(height: 22),
          _Perk(icon: Icons.local_shipping_outlined, title: t.freeDeliveryAbove(l.money(s.freeDeliveryAbove)), body: s.scheduledEnabled ? t.scheduledSlot : t.standardDelivery),
          if (s.pickupEnabled) ...[
            const Divider(height: 22),
            _Perk(icon: Icons.storefront_outlined, title: t.selfPickup, body: t.pickupBody),
          ],
        ]),
      ),
      const SizedBox(height: 16),
      _SellerCard(sellerId: p.sellerId, fallbackName: p.sellerName),
    ]);
  }
}

class _Perk extends StatelessWidget {
  const _Perk({required this.icon, required this.title, required this.body});
  final IconData icon;
  final String title, body;
  @override
  Widget build(BuildContext context) => Row(children: [
        Container(width: 40, height: 40, decoration: BoxDecoration(color: G4MColors.primarySoft, borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: G4MColors.primaryDeep, size: 21)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            Text(body, style: const TextStyle(color: G4MColors.inkMuted, fontSize: 13)),
          ]),
        ),
      ]);
}

class _SellerCard extends StatelessWidget {
  const _SellerCard({required this.sellerId, required this.fallbackName});
  final String sellerId, fallbackName;
  @override
  Widget build(BuildContext context) => FutureBuilder<Seller?>(
        future: Data.seller(sellerId),
        builder: (context, s) {
          final seller = s.data;
          final name = seller?.storeName ?? fallbackName;
          if (name.isEmpty) return const SizedBox.shrink();
          final t = context.l.product;
          return Panel(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(color: G4MColors.surfaceAlt, borderRadius: BorderRadius.circular(14)),
                clipBehavior: Clip.antiAlias,
                child: seller == null || seller.logo.isEmpty
                    ? const Icon(Icons.storefront_rounded, color: G4MColors.primaryDeep)
                    : NetImage(seller.logo, semanticLabel: t.logoOf(name)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(t.soldBy, style: const TextStyle(fontSize: 12.5, color: G4MColors.inkMuted, fontWeight: FontWeight.w600)),
                  Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  if (seller != null && seller.rating > 0)
                    Row(children: [
                      const Icon(Icons.star_rounded, size: 15, color: Color(0xFFF5A524)),
                      Text(' ${t.sellerRating(seller.rating.toStringAsFixed(1), seller.city)}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                    ]),
                ]),
              ),
              if (seller != null) ViewAllButton(to: '/store/${seller.slug}', label: t.visitStore(name)),
            ]),
          );
        },
      );
}

// ------------------------------------------------------------------ gallery

class _Gallery extends StatefulWidget {
  const _Gallery({required this.images, required this.name});
  final List<String> images;
  final String name;
  @override
  State<_Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<_Gallery> {
  int _i = 0;
  Offset? _zoom;

  @override
  Widget build(BuildContext context) {
    final imgs = widget.images.isEmpty ? const [''] : widget.images;
    final cur = imgs[_i.clamp(0, imgs.length - 1)];
    final main = AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(color: const Color(0xFFF4F8F5), borderRadius: BorderRadius.circular(28), border: Border.all(color: G4MColors.line)),
        clipBehavior: Clip.antiAlias,
        child: LayoutBuilder(builder: (context, c) {
          return MouseRegion(
            cursor: SystemMouseCursors.zoomIn,
            onHover: (e) => setState(() => _zoom = Offset(e.localPosition.dx / c.maxWidth, e.localPosition.dy / c.maxHeight)),
            onExit: (_) => setState(() => _zoom = null),
            child: Semantics(
              button: true,
              label: context.l.product.openViewer(widget.name),
              child: GestureDetector(
                onTap: () => _openViewer(context, imgs),
                child: AnimatedSwitcher(
                  duration: G4MMotion.emphasized,
                  child: Padding(
                    key: ValueKey(cur),
                    padding: const EdgeInsets.all(28),
                    child: AnimatedScale(
                      duration: G4MMotion.standard,
                      scale: _zoom != null && !context.isPhone ? 2.0 : 1,
                      alignment: _zoom == null ? Alignment.center : Alignment(_zoom!.dx * 2 - 1, _zoom!.dy * 2 - 1),
                      child: NetImage(cur, fit: BoxFit.contain, semanticLabel: widget.name),
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
    if (imgs.length < 2) return main;
    return Column(children: [
      main,
      const SizedBox(height: 14),
      SizedBox(
        height: 78,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: imgs.length,
          separatorBuilder: (_, _) => const SizedBox(width: 10),
          itemBuilder: (_, i) => Semantics(
            button: true,
            selected: i == _i,
            label: context.l.product.showImage(i + 1),
            excludeSemantics: true,
            child: Pressable(
              onTap: () => setState(() => _i = i),
              child: AnimatedContainer(
                duration: G4MMotion.standard,
                width: 78,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F8F5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: i == _i ? G4MColors.primary : G4MColors.line, width: i == _i ? 2 : 1),
                ),
                child: NetImage(imgs[i], fit: BoxFit.contain),
              ),
            ),
          ),
        ),
      ),
    ]);
  }

  void _openViewer(BuildContext context, List<String> imgs) => showDialog(
        context: context,
        barrierColor: const Color(0xE60A1A12),
        builder: (ctx) {
          final pc = PageController(initialPage: _i);
          final t = ctx.l.product;
          // PositionedDirectional + auto-mirroring chevrons: in RTL the PageView also runs
          // right-to-left, so "previous" sits on the right and points right.
          return Dialog.fullscreen(
            backgroundColor: Colors.transparent,
            child: Stack(children: [
              PageView(
                controller: pc,
                children: [
                  for (final u in imgs)
                    InteractiveViewer(
                      maxScale: 5,
                      child: Center(child: Padding(padding: const EdgeInsets.all(32), child: NetImage(u, fit: BoxFit.contain, semanticLabel: widget.name))),
                    ),
                ],
              ),
              PositionedDirectional(end: 20, top: 20, child: RoundIconButton(icon: Icons.close_rounded, tooltip: t.closeViewer, onTap: () => Navigator.pop(ctx))),
              if (imgs.length > 1) ...[
                PositionedDirectional(start: 20, top: 0, bottom: 0, child: Center(child: RoundIconButton(icon: Icons.chevron_left_rounded, tooltip: t.previousImage, onTap: () => pc.previousPage(duration: G4MMotion.emphasized, curve: G4MMotion.curve)))),
                PositionedDirectional(end: 20, top: 0, bottom: 0, child: Center(child: RoundIconButton(icon: Icons.chevron_right_rounded, tooltip: t.nextImage, onTap: () => pc.nextPage(duration: G4MMotion.emphasized, curve: G4MMotion.curve)))),
              ],
            ]),
          );
        },
      );
}

// ------------------------------------------------------------------ details

class _Details extends StatelessWidget {
  const _Details({required this.product});
  final Product product;
  @override
  Widget build(BuildContext context) {
    final p = product;
    final t = context.l.product;
    final fields = <(String, String)>[
      if (p.brandName.isNotEmpty) (t.brand, p.brandName),
      if (p.unit.isNotEmpty) (t.packSize, p.unit),
      if (p.isVeg != null) (t.dietary, p.isVeg! ? t.vegetarian : t.nonVegetarian),
      for (final e in p.customFields.entries)
        if ('${e.value}'.isNotEmpty) (Fmt.titleCase(e.key), e.value is List ? (e.value as List).join(', ') : '${e.value}'),
      if (p.sellerName.isNotEmpty) (t.soldBy, p.sellerName),
    ];
    final desc = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Heading(t.aboutProduct, level: 2, style: const TextStyle(fontSize: 22)),
      const SizedBox(height: 12),
      if (p.shortDescription.isNotEmpty) ...[
        Text(p.shortDescription, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w600, height: 1.6)),
        const SizedBox(height: 12),
      ],
      if (p.description.isNotEmpty) LazyMd(p.description) else if (p.shortDescription.isEmpty) Text(t.noDescription, style: const TextStyle(color: G4MColors.inkMuted)),
    ]);
    final spec = Panel(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Heading(t.specifications, level: 2, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 12),
        for (var i = 0; i < fields.length; i++)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
            decoration: BoxDecoration(color: i.isEven ? G4MColors.surfaceAlt : Colors.transparent, borderRadius: BorderRadius.circular(10)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(width: 130, child: Text(fields[i].$1, style: const TextStyle(color: G4MColors.inkMuted, fontWeight: FontWeight.w600))),
              Expanded(child: Text(fields[i].$2, style: const TextStyle(fontWeight: FontWeight.w700))),
            ]),
          ),
      ]),
    );
    if (!context.isDesktop) return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [desc, const SizedBox(height: 24), spec]);
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(flex: 3, child: desc),
      const SizedBox(width: 40),
      Expanded(flex: 2, child: spec),
    ]);
  }
}

// ------------------------------------------------------------------ reviews

class _Reviews extends StatefulWidget {
  const _Reviews({required this.product});
  final Product product;
  @override
  State<_Reviews> createState() => _ReviewsState();
}

class _ReviewsState extends State<_Reviews> {
  int _rating = 0;
  final _c = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final t = context.l.product;
    if (_rating == 0) return toast(context, t.tapStars, error: true);
    setState(() => _busy = true);
    try {
      await G4MApi.instance.submitReview(widget.product.id, _rating, _c.text.trim());
      _c.clear();
      setState(() => _rating = 0);
      if (mounted) toast(context, t.reviewLive);
    } catch (e) {
      if (mounted) toast(context, friendlyError(e), error: true);
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final loc = context.l;
    final t = loc.product;
    return StreamBuilder<List<Review>>(
      stream: live('reviews_${p.id}', () => CatalogRepo.instance.reviews(p.id)),
      builder: (context, s) {
        final l = s.data ?? const <Review>[];
        final dist = List.filled(5, 0);
        for (final r in l) {
          if (r.rating >= 1 && r.rating <= 5) dist[r.rating - 1]++;
        }
        final avg = p.ratingCount > 0 ? p.rating : (l.isEmpty ? 0.0 : l.fold(0, (a, r) => a + r.rating) / l.length);
        final count = p.ratingCount > 0 ? p.ratingCount : l.length;
        final summary = Panel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(avg.toStringAsFixed(1), style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w800, letterSpacing: -1)),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                RatingStars(avg, size: 20),
                Text(t.ratingsCount(count, loc.number(count)), style: const TextStyle(color: G4MColors.inkMuted)),
              ]),
            ]),
            const SizedBox(height: 14),
            for (var i = 5; i >= 1; i--)
              Padding(
                padding: const EdgeInsetsDirectional.only(bottom: 6),
                child: Row(children: [
                  SizedBox(width: 26, child: Text('${loc.number(i)}★', style: const TextStyle(fontWeight: FontWeight.w700))),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: l.isEmpty ? 0 : dist[i - 1] / l.length,
                        minHeight: 8,
                        backgroundColor: G4MColors.surfaceAlt,
                        color: i >= 4 ? G4MColors.primary : (i == 3 ? G4MColors.warning : G4MColors.danger),
                      ),
                    ),
                  ),
                  SizedBox(width: 32, child: Text(loc.number(dist[i - 1]), textAlign: TextAlign.end, style: const TextStyle(color: G4MColors.inkMuted))),
                ]),
              ),
            const Divider(height: 28),
            Text(t.rateProduct, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 4),
            Text(t.reviewsOpenTo, style: const TextStyle(color: G4MColors.inkMuted, fontSize: 13)),
            const SizedBox(height: 10),
            if (!Shop.instance.signedIn)
              OutlinedButton(onPressed: () => context.go('/login?next=${Uri.encodeQueryComponent('/p/${p.slug}')}'), child: Text(t.signInToReview))
            else ...[
              Row(children: [
                for (var i = 1; i <= 5; i++)
                  IconButton(
                    tooltip: t.stars(i),
                    onPressed: () => setState(() => _rating = i),
                    icon: Icon(i <= _rating ? Icons.star_rounded : Icons.star_outline_rounded, color: const Color(0xFFF5A524), size: 32),
                  ),
              ]),
              TextField(controller: _c, maxLines: 3, maxLength: 600, decoration: InputDecoration(hintText: t.reviewHint, labelText: t.yourReview)),
              const SizedBox(height: 8),
              FilledButton(onPressed: _busy ? null : _submit, child: _busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(t.submitReview)),
            ],
          ]),
        );
        final list = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (l.isEmpty)
            Panel(child: Text(t.noReviews, style: const TextStyle(color: G4MColors.inkMuted)))
          else
            for (var i = 0; i < l.length; i++)
              Padding(
                padding: const EdgeInsetsDirectional.only(bottom: 12),
                child: Reveal(
                  index: i % 4,
                  child: Panel(
                    padding: const EdgeInsets.all(18),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: G4MColors.pastels[i % G4MColors.pastels.length],
                          child: Text(l[i].userName.isEmpty ? t.customerInitial :l[i].userName[0].toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w800, color: G4MColors.primaryDeep)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(l[i].userName, style: const TextStyle(fontWeight: FontWeight.w800)),
                            Text(loc.ago(l[i].createdAt), style: const TextStyle(fontSize: 12.5, color: G4MColors.inkMuted)),
                          ]),
                        ),
                        RatingStars(l[i].rating.toDouble(), size: 16),
                      ]),
                      if (l[i].comment.isNotEmpty) ...[const SizedBox(height: 10), Text(l[i].comment, style: const TextStyle(height: 1.55))],
                    ]),
                  ),
                ),
              ),
        ]);
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SectionHeader(title: t.ratingsReviews),
          if (context.isDesktop)
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 380, child: summary), const SizedBox(width: 28), Expanded(child: list)])
          else ...[summary, const SizedBox(height: 16), list],
        ]);
      },
    );
  }
}

// ------------------------------------------------------------------ subscriptions

Future<void> showSubscribeDialog(BuildContext context, Product p, String variantId) async {
  final shop = Shop.instance;
  final t = context.l.product;
  if (!shop.signedIn) {
    toast(context, t.signInForSubscription);
    context.go('/login?next=${Uri.encodeQueryComponent('/p/${p.slug}')}');
    return;
  }
  var freq = 'weekly';
  var qty = 1;
  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: Text(t.subscribeTitle),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            Text(t.howOften, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(value: 'daily', label: Text(t.daily)),
                ButtonSegment(value: 'weekly', label: Text(t.weekly)),
                ButtonSegment(value: 'monthly', label: Text(t.monthly)),
              ],
              selected: {freq},
              onSelectionChanged: (s) => set(() => freq = s.first),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Text(t.quantity, style: const TextStyle(fontWeight: FontWeight.w800)),
              const Spacer(),
              IconButton.outlined(tooltip: t.decrease, onPressed: qty > 1 ? () => set(() => qty--) : null, icon: const Icon(Icons.remove_rounded)),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text(ctx.l.number(qty), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18))),
              IconButton.outlined(tooltip: t.increase, onPressed: () => set(() => qty++), icon: const Icon(Icons.add_rounded)),
            ]),
            const SizedBox(height: 12),
            Text(t.subscribeNote, style: const TextStyle(color: G4MColors.inkMuted, fontSize: 13)),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(ctx.l.common.cancel)),
          FilledButton(
            onPressed: () async {
              try {
                final now = DateTime.now();
                await Fs.subscriptions.add({
                  'userId': shop.user!.uid,
                  'productId': p.id,
                  'variantId': variantId,
                  'qty': qty,
                  'frequency': freq,
                  'nextRunAt': Timestamp.fromDate(DateTime(now.year, now.month, now.day + 1, 7)),
                  'status': 'active',
                  'addressId': shop.profile?.data['defaultAddressId'],
                  'createdAt': Fs.now,
                  'updatedAt': Fs.now,
                });
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) toast(context, t.subscribed, actionLabel: t.manage, onAction: () => context.go('/account?tab=subscriptions'));
              } catch (e) {
                if (ctx.mounted) toast(ctx, friendlyError(e), error: true);
              }
            },
            child: Text(t.subscribe),
          ),
        ],
      ),
    ),
  );
}
