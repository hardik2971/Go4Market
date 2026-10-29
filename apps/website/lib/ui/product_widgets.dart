import 'package:flutter/material.dart';
import 'package:g4m_core/g4m_core.dart';

import '../core/shop.dart';
import '../l10n/l10n.dart';
import 'kit.dart';

String defaultVariantId(Product p) {
  if (p.variants.isEmpty) return 'default';
  return (p.variants.where((v) => v.stock > 0).firstOrNull ?? p.variants.first).id;
}

Future<void> _guard(BuildContext context, Future<void> Function() f) async {
  try {
    await f();
  } catch (e) {
    if (context.mounted) toast(context, friendlyError(e), error: true);
  }
}

/// "Add" button that morphs into a − qty + stepper; the header cart badge bumps on add.
class AddToCartButton extends StatelessWidget {
  const AddToCartButton({super.key, required this.product, this.variantId, this.compact = true, this.expand = false});
  final Product product;
  final String? variantId;
  final bool compact;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final shop = Shop.instance;
    return ListenableBuilder(
      listenable: shop,
      builder: (context, _) {
        final p = product;
        final multi = variantId == null && p.variants.length > 1;
        final vid = variantId ?? defaultVariantId(p);
        final variant = p.variants.where((v) => v.id == vid).firstOrNull;
        final stock = variant?.stock ?? p.stock;
        final q = multi ? p.variants.fold(0, (a, v) => a + shop.qty(p.id, v.id)) : shop.qty(p.id, vid);
        final h = compact ? 38.0 : 52.0;
        final inStock = variant != null ? stock > 0 : p.inStock;

        Widget child;
        if (!inStock && q == 0) {
          child = Container(
            key: const ValueKey('oos'),
            height: h,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: G4MColors.surfaceAlt, borderRadius: BorderRadius.circular(G4MRadius.sm)),
            child: Text(context.l.catalog.outOfStock, style: TextStyle(fontWeight: FontWeight.w700, color: G4MColors.inkMuted, fontSize: compact ? 12.5 : 15)),
          );
        } else if (q == 0) {
          child = Semantics(
            key: const ValueKey('add'),
            button: true,
            label: context.l.catalog.addNameToCart(p.name),
            excludeSemantics: true,
            child: Pressable(
              onTap: () => multi ? showVariantSheet(context, p) : _guard(context, () => shop.setQty(p, 1, variantId: vid)),
              child: Container(
                height: h,
                padding: EdgeInsets.symmetric(horizontal: compact ? 14 : 22),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: compact ? G4MColors.primarySoft : G4MColors.primary,
                  borderRadius: BorderRadius.circular(G4MRadius.sm),
                  border: compact ? Border.all(color: const Color(0xFFBFE3CE)) : null,
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(compact ? Icons.add_rounded : Icons.shopping_bag_outlined, size: compact ? 18 : 20, color: compact ? G4MColors.primaryDeep : Colors.white),
                  const SizedBox(width: 6),
                  Text(compact ? context.l.catalog.add : context.l.catalog.addToCart,
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: compact ? 13.5 : 16, color: compact ? G4MColors.primaryDeep : Colors.white)),
                  if (multi) ...[const SizedBox(width: 2), Icon(Icons.expand_more_rounded, size: 16, color: compact ? G4MColors.primaryDeep : Colors.white)],
                ]),
              ),
            ),
          );
        } else {
          child = Container(
            key: const ValueKey('stepper'),
            height: h,
            decoration: BoxDecoration(color: G4MColors.primary, borderRadius: BorderRadius.circular(G4MRadius.sm), boxShadow: G4MShadows.soft),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              _StepBtn(
                icon: q == 1 && !multi ? Icons.delete_outline_rounded : Icons.remove_rounded,
                label: context.l.catalog.removeOne(p.name),
                h: h,
                onTap: () => multi ? showVariantSheet(context, p) : _guard(context, () => shop.setQty(p, q - 1, variantId: vid)),
              ),
              SizedBox(
                width: compact ? 26 : 40,
                child: AnimatedSwitcher(
                  duration: G4MMotion.fast,
                  transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                  child: Text('$q',
                      key: ValueKey(q),
                      textAlign: TextAlign.center,
                      semanticsLabel: context.l.catalog.inCart(q),
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: compact ? 14 : 17)),
                ),
              ),
              _StepBtn(
                icon: Icons.add_rounded,
                label: context.l.catalog.addOneMore(p.name),
                h: h,
                onTap: q >= stock && !multi
                    ? () => toast(context, context.l.catalog.onlyInStock(stock))
                    : () => multi ? showVariantSheet(context, p) : _guard(context, () => shop.setQty(p, q + 1, variantId: vid)),
              ),
            ]),
          );
        }
        final switched = AnimatedSwitcher(
          duration: G4MMotion.standard,
          switchInCurve: G4MMotion.spring,
          transitionBuilder: (c, a) => FadeTransition(opacity: a, child: ScaleTransition(scale: Tween(begin: .85, end: 1.0).animate(a), child: c)),
          layoutBuilder: (cur, prev) => Stack(alignment: AlignmentDirectional.centerEnd, children: [...prev, ?cur]),
          child: child,
        );
        return expand ? SizedBox(width: double.infinity, child: switched) : AnimatedSize(duration: G4MMotion.standard, curve: G4MMotion.curve, child: switched);
      },
    );
  }
}

class _StepBtn extends StatelessWidget {
  const _StepBtn({required this.icon, required this.onTap, required this.label, required this.h});
  final IconData icon;
  final VoidCallback onTap;
  final String label;
  final double h;
  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: Pressable(
          onTap: onTap,
          scale: .85,
          child: SizedBox(width: h * .95, height: h, child: Icon(icon, color: Colors.white, size: h * .48)),
        ),
      );
}

Future<void> showVariantSheet(BuildContext context, Product p) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p.name, style: ctx.tt.titleLarge),
            const SizedBox(height: 4),
            Text(ctx.l.catalog.chooseOption, style: ctx.tt.bodyMedium?.copyWith(color: G4MColors.inkMuted)),
            const SizedBox(height: 16),
            for (final v in p.variants)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Panel(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  radius: G4MRadius.md,
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(v.name.isEmpty ? p.unit : v.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                        const SizedBox(height: 4),
                        Price(price: v.price, mrp: v.mrp, size: 14),
                      ]),
                    ),
                    AddToCartButton(product: p, variantId: v.id),
                  ]),
                ),
              ),
          ]),
        ),
      ),
    );

class WishButton extends StatelessWidget {
  const WishButton({super.key, required this.productId, this.size = 36});
  final String productId;
  final double size;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Shop.instance,
        builder: (context, _) {
          final on = Shop.instance.wished(productId);
          return Semantics(
            button: true,
            toggled: on,
            label: on ? context.l.catalog.removeFromWishlist : context.l.catalog.saveToWishlist,
            excludeSemantics: true,
            child: Pressable(
              scale: .8,
              onTap: () => _guard(context, () => Shop.instance.toggleWish(productId)),
              child: AnimatedContainer(
                duration: G4MMotion.standard,
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: on ? const Color(0xFFFFEDEF) : Colors.white.withValues(alpha: .92),
                  shape: BoxShape.circle,
                  boxShadow: G4MShadows.soft,
                ),
                child: AnimatedSwitcher(
                  duration: G4MMotion.standard,
                  transitionBuilder: (c, a) => ScaleTransition(scale: CurvedAnimation(parent: a, curve: G4MMotion.spring), child: c),
                  child: Icon(on ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      key: ValueKey(on), size: size * .5, color: on ? const Color(0xFFE11D48) : G4MColors.ink),
                ),
              ),
            ),
          );
        },
      );
}

/// Vertical product card for carousels and grids.
class ProductCard extends StatelessWidget {
  const ProductCard({super.key, required this.product, this.width});
  final Product product;
  final double? width;
  @override
  Widget build(BuildContext context) {
    final p = product;
    final food = p.moduleId == 'food';
    final card = HoverLift(
      radius: 20,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        AspectRatio(
          aspectRatio: 1,
          child: Stack(children: [
            Positioned.fill(
              child: AppLink(
                to: '/p/${p.slug}',
                label: '${p.name}, ${context.l.money(p.price)}',
                scale: 1,
                child: Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: const Color(0xFFF4F8F5), borderRadius: BorderRadius.circular(14)),
                  clipBehavior: Clip.antiAlias,
                  padding: food ? EdgeInsets.zero : const EdgeInsets.all(14),
                  child: Opacity(
                    opacity: p.inStock ? 1 : .45,
                    child: NetImage(p.image, fit: food ? BoxFit.cover : BoxFit.contain, semanticLabel: p.name),
                  ),
                ),
              ),
            ),
            if (p.discountPct > 0)
              PositionedDirectional(start: 14, top: 14, child: Pill(context.l.common.off(p.discountPct).toUpperCase(), bg: G4MColors.accent, fg: G4MColors.ink)),
            PositionedDirectional(end: 14, top: 14, child: WishButton(productId: p.id, size: 34)),
            if (p.isVeg != null) PositionedDirectional(start: 16, bottom: 16, child: _VegBadge(isVeg: p.isVeg!)),
            if (!p.inStock)
              Positioned(
                left: 14,
                right: 14,
                bottom: 14,
                child: Center(child: Pill(context.l.catalog.outOfStock, bg: G4MColors.ink.withValues(alpha: .8), fg: Colors.white)),
              ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 2, 14, 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(
                  [if (p.brandName.isNotEmpty) p.brandName, if (p.unit.isNotEmpty) p.unit].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: G4MColors.inkMuted, fontWeight: FontWeight.w600),
                ),
              ),
              if (p.deliveryMinutes > 0 && p.deliveryMinutes <= 30)
                Pill(context.l.catalog.minutes(p.deliveryMinutes), icon: Icons.bolt_rounded, bg: G4MColors.primarySoft, fg: G4MColors.primaryDeep, fontSize: 10.5),
            ]),
            const SizedBox(height: 6),
            AppLink(
              to: '/p/${p.slug}',
              scale: 1,
              child: SizedBox(
                height: 40,
                child: Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, height: 1.35, color: G4MColors.ink)),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 16,
              child: p.ratingCount > 0
                  ? Row(children: [
                      const Icon(Icons.star_rounded, size: 15, color: Color(0xFFF5A524)),
                      const SizedBox(width: 3),
                      Text(p.rating.toStringAsFixed(1), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                      Text('  (${context.l.number(p.ratingCount)})', style: const TextStyle(fontSize: 12, color: G4MColors.inkMuted)),
                    ])
                  : const SizedBox.shrink(),
            ),
            const SizedBox(height: 8),
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(child: Price(price: p.price, mrp: p.mrp, size: 16, showOff: false)),
              const SizedBox(width: 6),
              AddToCartButton(product: p),
            ]),
          ]),
        ),
      ]),
    );
    return width == null ? card : SizedBox(width: width, child: card);
  }
}

class _VegBadge extends StatelessWidget {
  const _VegBadge({required this.isVeg});
  final bool isVeg;
  @override
  Widget build(BuildContext context) => Semantics(
        label: isVeg ? context.l.catalog.vegetarian : context.l.catalog.nonVegetarian,
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), boxShadow: G4MShadows.soft),
          child: VegMark(isVeg: isVeg, size: 14),
        ),
      );
}

/// Horizontal product row for list view, deals and search results.
class ProductRow extends StatelessWidget {
  const ProductRow({super.key, required this.product, this.dense = false, this.trailing});
  final Product product;
  final bool dense;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) {
    final p = product;
    final img = dense ? 84.0 : 120.0;
    return HoverLift(
      radius: 20,
      lift: 3,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          AppLink(
            to: '/p/${p.slug}',
            label: p.name,
            child: Container(
              width: img,
              height: img,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: const Color(0xFFF4F8F5), borderRadius: BorderRadius.circular(14)),
              child: NetImage(p.image, fit: BoxFit.contain, semanticLabel: p.name),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                if (p.isVeg != null) ...[VegMark(isVeg: p.isVeg!, size: 13), const SizedBox(width: 6)],
                Flexible(
                  child: Text([if (p.brandName.isNotEmpty) p.brandName, if (p.unit.isNotEmpty) p.unit].join(' · '),
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: G4MColors.inkMuted, fontWeight: FontWeight.w600)),
                ),
              ]),
              const SizedBox(height: 4),
              AppLink(
                to: '/p/${p.slug}',
                scale: 1,
                child: Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700, fontSize: dense ? 14 : 15.5, height: 1.3)),
              ),
              if (!dense && p.shortDescription.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(p.shortDescription, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: G4MColors.inkMuted, height: 1.4)),
              ],
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: Price(price: p.price, mrp: p.mrp, size: dense ? 14.5 : 16)),
                trailing ?? AddToCartButton(product: p),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

class ProductCardSkeleton extends StatelessWidget {
  const ProductCardSkeleton({super.key, this.width});
  final double? width;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        child: Container(
          decoration: BoxDecoration(color: G4MColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: G4MColors.line)),
          padding: const EdgeInsets.all(8),
          child: const Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            AspectRatio(aspectRatio: 1, child: Skeleton(radius: 14)),
            SizedBox(height: 12),
            Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Skeleton(width: 80, height: 10)),
            SizedBox(height: 10),
            Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Skeleton(height: 14)),
            SizedBox(height: 6),
            Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Skeleton(width: 120, height: 14)),
            SizedBox(height: 16),
            Padding(
              padding: EdgeInsets.fromLTRB(6, 0, 6, 8),
              child: Row(children: [Skeleton(width: 60, height: 18), Spacer(), Skeleton(width: 64, height: 36)]),
            ),
          ]),
        ),
      );
}

double cardWidthFor(BuildContext context) => context.isPhone ? 168 : (context.isTablet ? 200 : 228);

/// Horizontally scrolling product rail with arrow buttons on wider screens.
class ProductCarousel extends StatefulWidget {
  const ProductCarousel({super.key, required this.products, this.loading = false});
  final List<Product> products;
  final bool loading;
  @override
  State<ProductCarousel> createState() => _ProductCarouselState();
}

class _ProductCarouselState extends State<ProductCarousel> {
  final _c = ScrollController();
  bool _canBack = false, _canFwd = true;

  @override
  void initState() {
    super.initState();
    _c.addListener(_sync);
  }

  void _sync() {
    if (!_c.hasClients) return;
    final b = _c.offset > 4, f = _c.offset < _c.position.maxScrollExtent - 4;
    if (b != _canBack || f != _canFwd) {
      setState(() {
        _canBack = b;
        _canFwd = f;
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _page(int dir) {
    final w = _c.position.viewportDimension * .85;
    _c.animateTo((_c.offset + dir * w).clamp(0, _c.position.maxScrollExtent), duration: G4MMotion.slow, curve: G4MMotion.curve);
  }

  @override
  Widget build(BuildContext context) {
    final cw = cardWidthFor(context);
    final n = widget.loading ? 6 : widget.products.length;
    final list = SizedBox(
      height: cw + 178,
      child: ListView.separated(
        controller: _c,
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: n,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (_, i) => widget.loading
            ? ProductCardSkeleton(width: cw)
            : Align(alignment: Alignment.topCenter, child: Reveal(index: i, offset: 16, child: ProductCard(product: widget.products[i], width: cw))),
      ),
    );
    if (context.isPhone) return list;
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
    return Stack(clipBehavior: Clip.none, children: [
      list,
      PositionedDirectional(
        start: -18,
        top: cw / 2 - 12,
        child: AnimatedOpacity(
          opacity: _canBack ? 1 : 0,
          duration: G4MMotion.standard,
          child: IgnorePointer(ignoring: !_canBack, child: RoundIconButton(icon: Icons.chevron_left_rounded, tooltip: context.l.catalog.scrollBack, onTap: () => _page(-1))),
        ),
      ),
      PositionedDirectional(
        end: -18,
        top: cw / 2 - 12,
        child: AnimatedOpacity(
          opacity: _canFwd ? 1 : 0,
          duration: G4MMotion.standard,
          child: IgnorePointer(ignoring: !_canFwd, child: RoundIconButton(icon: Icons.chevron_right_rounded, tooltip: context.l.catalog.scrollForward, onTap: () => _page(1))),
        ),
      ),
    ]);
  }
}

/// Responsive grid of product cards.
class ProductGrid extends StatelessWidget {
  const ProductGrid({super.key, required this.products, this.loading = false, this.minTile = 200, this.list = false, this.maxCols = 6});
  final List<Product> products;
  final bool loading;
  final double minTile;
  final bool list;
  final int maxCols;
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        const gap = 14.0;
        if (list) {
          final cols = c.maxWidth > 980 ? 2 : 1;
          final w = (c.maxWidth - gap * (cols - 1)) / cols;
          return Wrap(spacing: gap, runSpacing: gap, children: [
            for (var i = 0; i < (loading ? 6 : products.length); i++)
              SizedBox(
                width: w,
                child: loading ? const Skeleton(height: 144, radius: 20) : Reveal(index: i % 6, child: ProductRow(product: products[i])),
              ),
          ]);
        }
        final min = context.isPhone ? 150.0 : minTile;
        final cols = (c.maxWidth / (min + gap)).floor().clamp(2, maxCols);
        final w = (c.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(spacing: gap, runSpacing: gap, children: [
          for (var i = 0; i < (loading ? cols * 2 : products.length); i++)
            loading ? ProductCardSkeleton(width: w) : Reveal(index: i % cols, child: ProductCard(product: products[i], width: w)),
        ]);
      });
}

/// FutureBuilder for product lists with skeletons while loading.
class ProductsFuture extends StatefulWidget {
  const ProductsFuture({super.key, required this.load, required this.builder, this.skeleton, this.hideWhenEmpty = true});
  final Future<List<Product>> Function() load;
  final Widget Function(List<Product>) builder;
  final Widget? skeleton;
  final bool hideWhenEmpty;
  @override
  State<ProductsFuture> createState() => _ProductsFutureState();
}

class _ProductsFutureState extends State<ProductsFuture> {
  late Future<List<Product>> _f = widget.load();
  @override
  void didUpdateWidget(ProductsFuture old) {
    super.didUpdateWidget(old);
    if (old.key != widget.key) _f = widget.load();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Product>>(
        future: _f,
        builder: (_, s) {
          if (s.hasError) return widget.hideWhenEmpty ? const SizedBox.shrink() : Text(errorMessage(s.error!));
          if (!s.hasData) return widget.skeleton ?? const ProductCarousel(products: [], loading: true);
          if (s.data!.isEmpty && widget.hideWhenEmpty) return const SizedBox.shrink();
          return widget.builder(s.data!);
        },
      );
}
