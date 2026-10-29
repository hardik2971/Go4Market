import 'package:flutter/material.dart';
import 'package:g4m_core/g4m_core.dart';

import '../core/nav.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../screens/cart/cart_screen.dart';
import '../screens/product/product_detail_screen.dart';
import 'cart_fx.dart';
import 'ui.dart';

String heroTagFor(String scope, String productId) => 'p-$scope-$productId';

void openProduct(BuildContext context, Product p, {String scope = 'x'}) {
  Session.instance.remember([p]);
  Navigator.of(context).push(PageRouteBuilder(
    transitionDuration: const Duration(milliseconds: 460),
    reverseTransitionDuration: const Duration(milliseconds: 360),
    pageBuilder: (_, _, _) => ProductDetailScreen(product: p, heroTag: heroTagFor(scope, p.id)),
    transitionsBuilder: (_, a, _, child) {
      final c = CurvedAnimation(parent: a, curve: G4MMotion.curve);
      return FadeTransition(
        opacity: c,
        child: SlideTransition(position: Tween(begin: const Offset(0, .04), end: Offset.zero).animate(c), child: child),
      );
    },
  ));
}

/// Grid product card with hero image, discount ribbon, wishlist heart and morphing add button.
class ProductCard extends StatelessWidget {
  const ProductCard({super.key, required this.product, this.scope = 'grid', this.width});
  final Product product;
  final String scope;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final p = product;
    final v = p.variants.isEmpty ? null : p.variants.first;
    final price = v?.price ?? p.price;
    final mrp = v?.mrp ?? p.mrp;
    final off = mrp > price && mrp > 0 ? (((mrp - price) / mrp) * 100).round() : 0;
    return SizedBox(
      width: width,
      child: AppCard(
        padding: EdgeInsets.zero,
        onTap: () => openProduct(context, p, scope: scope),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          AspectRatio(
            aspectRatio: 1,
            child: Stack(children: [
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Hero(
                    tag: heroTagFor(scope, p.id),
                    child: Img(p.image, radius: 12, fit: BoxFit.cover),
                  ),
                ),
              ),
              if (off > 0)
                Positioned(
                  left: 0,
                  top: 12,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(8, 3, 9, 3),
                    decoration: const BoxDecoration(
                      gradient: G4MColors.accentGradient,
                      borderRadius: BorderRadius.horizontal(right: Radius.circular(8)),
                    ),
                    child: Text('$off% OFF', style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800)),
                  ),
                ),
              Positioned(right: 10, top: 10, child: WishButton(productId: p.id, size: 17)),
              if (p.isVeg != null) Positioned(left: 12, bottom: 12, child: _VegChip(isVeg: p.isVeg!)),
              if (!p.inStock)
                Positioned.fill(
                  child: Container(
                    margin: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: context.card.withValues(alpha: .55), borderRadius: BorderRadius.circular(12)),
                  ),
                ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 2, 10, 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.bolt_rounded, size: 13, color: G4MColors.primary.withValues(alpha: .9)),
                Text(' ${p.deliveryMinutes} min', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: context.muted)),
                if (p.rating > 0) ...[
                  const Spacer(),
                  const Icon(Icons.star_rounded, size: 13, color: Color(0xFFF5A524)),
                  Text(p.rating.toStringAsFixed(1), style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: context.muted)),
                ],
              ]),
              const SizedBox(height: 4),
              SizedBox(
                height: 36,
                child: Text(p.name,
                    maxLines: 2, overflow: TextOverflow.ellipsis, style: context.text.titleSmall?.copyWith(fontSize: 13, height: 1.3)),
              ),
              Text(v?.name.isNotEmpty == true ? v!.name : p.unit,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.bodySmall?.copyWith(fontSize: 11.5)),
              const SizedBox(height: 8),
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Expanded(child: Price(price: price, mrp: mrp, size: 14, showOff: false)),
                AddToCartButton(product: p, height: 32),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _VegChip extends StatelessWidget {
  const _VegChip({required this.isVeg});
  final bool isVeg;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)),
        child: VegMark(isVeg: isVeg, size: 12),
      );
}

/// Horizontal list-style product row.
class ProductTile extends StatelessWidget {
  const ProductTile({super.key, required this.product, this.scope = 'list', this.trailing});
  final Product product;
  final String scope;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) {
    final p = product;
    final v = p.variants.isEmpty ? null : p.variants.first;
    return AppCard(
      padding: const EdgeInsets.all(10),
      onTap: () => openProduct(context, p, scope: scope),
      child: Row(children: [
        SizedBox(
          width: 96,
          height: 96,
          child: Stack(children: [
            Positioned.fill(child: Hero(tag: heroTagFor(scope, p.id), child: Img(p.image, radius: 12))),
            if (p.discountPct > 0)
              Positioned(left: 4, top: 4, child: Tag('${p.discountPct}% OFF', color: G4MColors.accent)),
          ]),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              if (p.isVeg != null) ...[VegMark(isVeg: p.isVeg!, size: 12), const SizedBox(width: 6)],
              Expanded(
                child: Text(p.brandName.isNotEmpty ? p.brandName : p.sellerName,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
              ),
              WishButton(productId: p.id, size: 18, background: false),
            ]),
            const SizedBox(height: 2),
            Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.text.titleSmall?.copyWith(height: 1.3)),
            const SizedBox(height: 2),
            Row(children: [
              Text(v?.name.isNotEmpty == true ? v!.name : p.unit, style: context.text.bodySmall),
              if (p.rating > 0) ...[
                const SizedBox(width: 8),
                RatingStars(p.rating, size: 12, count: p.ratingCount),
              ],
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: Price(price: v?.price ?? p.price, mrp: v?.mrp ?? p.mrp, size: 15)),
              trailing ?? AddToCartButton(product: p, height: 32),
            ]),
          ]),
        ),
      ]),
    );
  }
}

/// Horizontal carousel of product cards with staggered entrance.
class ProductCarousel extends StatelessWidget {
  const ProductCarousel({super.key, required this.products, required this.scope, this.height = 300});
  final List<Product> products;
  final String scope;
  final double height;
  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          itemCount: products.length,
          separatorBuilder: (_, _) => const SizedBox(width: 12),
          itemBuilder: (_, i) => ProductCard(product: products[i], scope: scope, width: 160).stagger(i, dy: 0),
        ),
      );
}

class CarouselSkeleton extends StatelessWidget {
  const CarouselSkeleton({super.key, this.height = 300});
  final double height;
  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: 3,
          separatorBuilder: (_, _) => const SizedBox(width: 12),
          itemBuilder: (_, _) => const Shimmer(width: 160, height: double.infinity, radius: 16),
        ),
      );
}

/// Responsive product grid as a sliver.
class SliverProductGrid extends StatelessWidget {
  const SliverProductGrid({super.key, required this.products, required this.scope, this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 24)});
  final List<Product> products;
  final String scope;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final cols = w > 900 ? 4 : w > 600 ? 3 : 2;
    return SliverPadding(
      padding: padding,
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          mainAxisExtent: (w - padding.horizontal - 12 * (cols - 1)) / cols + 150,
        ),
        delegate: SliverChildBuilderDelegate(
          (_, i) => ProductCard(product: products[i], scope: scope).stagger(i % 10),
          childCount: products.length,
        ),
      ),
    );
  }
}

/// Cart icon for app bars; opens the single-screen cart + checkout.
class CartAction extends StatelessWidget {
  const CartAction({super.key});
  @override
  Widget build(BuildContext context) => IconButton(
        onPressed: () => context.push(const CartScreen(standalone: true), style: RouteStyle.sharedY),
        icon: const CartBadgeIcon(),
      );
}