import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:g4m_core/g4m_core.dart';

import '../core/theme.dart';

export 'package:g4m_core/g4m_core.dart' show Pressable, RatingStars, VegMark, StatusChip, G4MLogo, G4MWordmark;

/// Staggered entrance used by every list on every page.
extension Stagger on Widget {
  Widget stagger(int i, {double dy = .08, int stepMs = 45, int maxSteps = 10}) => animate(
        delay: Duration(milliseconds: (i.clamp(0, maxSteps)) * stepMs),
      ).fadeIn(duration: 380.ms, curve: Curves.easeOut).slideY(begin: dy, end: 0, duration: 420.ms, curve: Curves.easeOutCubic);
}

/// Dark-mode aware network image (g4m_core's NetImage placeholder is light-only).
class Img extends StatelessWidget {
  const Img(this.url, {super.key, this.fit = BoxFit.cover, this.width, this.height, this.radius = 0, this.iconSize = 28});
  final String url;
  final BoxFit fit;
  final double? width, height;
  final double radius;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final bg = context.cardAlt;
    final ph = Container(
      width: width,
      height: height,
      color: bg,
      alignment: Alignment.center,
      child: Icon(Icons.shopping_bag_outlined, color: context.muted.withValues(alpha: .45), size: iconSize),
    );
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final img = url.isEmpty || !url.startsWith('http')
        ? ph
        : CachedNetworkImage(
            imageUrl: url,
            width: width,
            height: height,
            fit: fit,
            memCacheWidth: width == null || width!.isInfinite ? null : (width! * dpr).round(),
            fadeInDuration: G4MMotion.standard,
            placeholder: (_, _) => Container(width: width, height: height, color: bg),
            errorWidget: (_, _, _) => ph,
          );
    return radius == 0 ? img : ClipRRect(borderRadius: BorderRadius.circular(radius), child: img);
  }
}

/// Skeleton shimmer block, dark-mode aware.
class Shimmer extends StatefulWidget {
  const Shimmer({super.key, this.width, this.height = 16, this.radius = G4MRadius.sm});
  final double? width;
  final double height;
  final double radius;
  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1250))..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = context.isDark ? const Color(0xFF17251E) : const Color(0xFFEAF0EC);
    final b = context.isDark ? const Color(0xFF223529) : const Color(0xFFF8FBF9);
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) => Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(-2 + _c.value * 4, -.3),
              end: Alignment(-1 + _c.value * 4, .3),
              colors: [a, b, a],
            ),
          ),
        ),
      ),
    );
  }
}

/// Grid of product-card skeletons.
class ProductGridSkeleton extends StatelessWidget {
  const ProductGridSkeleton({super.key, this.count = 6, this.sliver = false});
  final int count;
  final bool sliver;
  @override
  Widget build(BuildContext context) {
    Widget cell(int i) => Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: context.card, borderRadius: BorderRadius.circular(G4MRadius.md)),
          child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Shimmer(height: double.infinity, radius: 12)),
            SizedBox(height: 10),
            Shimmer(height: 12, width: 110),
            SizedBox(height: 6),
            Shimmer(height: 12, width: 70),
            SizedBox(height: 10),
            Shimmer(height: 30, radius: 10),
          ]),
        );
    const d = SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: .62);
    if (sliver) {
      return SliverPadding(
        padding: const EdgeInsets.all(16),
        sliver: SliverGrid(delegate: SliverChildBuilderDelegate((_, i) => cell(i), childCount: count), gridDelegate: d),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: count,
      gridDelegate: d,
      itemBuilder: (_, i) => cell(i),
    );
  }
}

class ListSkeleton extends StatelessWidget {
  const ListSkeleton({super.key, this.count = 6, this.height = 76});
  final int count;
  final double height;
  @override
  Widget build(BuildContext context) => ListView.separated(
        padding: const EdgeInsets.all(16),
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        itemCount: count,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, i) => Shimmer(height: height, radius: G4MRadius.md),
      );
}

/// Theme-aware price with MRP strike and discount (core PriceTag hardcodes light ink).
class Price extends StatelessWidget {
  const Price({super.key, required this.price, this.mrp, this.size = 16, this.showOff = true});
  final double price;
  final double? mrp;
  final double size;
  final bool showOff;
  @override
  Widget build(BuildContext context) {
    final off = mrp != null && mrp! > price && mrp! > 0 ? (((mrp! - price) / mrp!) * 100).round() : 0;
    return Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 6, runSpacing: 2, children: [
      Text(Fmt.money(price), style: TextStyle(fontSize: size, fontWeight: FontWeight.w800, color: context.ink, letterSpacing: -.3)),
      if (off > 0)
        Text(Fmt.money(mrp!),
            style: TextStyle(
              fontSize: size * .76,
              color: context.muted,
              decoration: TextDecoration.lineThrough,
              decorationColor: context.muted,
            )),
      if (off > 0 && showOff)
        Text('$off% off', style: TextStyle(fontSize: size * .76, fontWeight: FontWeight.w800, color: G4MColors.success)),
    ]);
  }
}

/// Rounded card with soft shadow (light) / hairline (dark) and optional press animation.
class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap, this.color, this.radius = G4MRadius.md, this.margin});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? color;
  final double radius;
  @override
  Widget build(BuildContext context) {
    final box = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? context.card,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: context.softShadow,
        border: context.isDark ? Border.all(color: context.line) : null,
      ),
      child: child,
    );
    return onTap == null ? box : Pressable(onTap: onTap, child: box);
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.subtitle, this.onViewAll, this.padding = const EdgeInsets.fromLTRB(16, 22, 8, 10), this.trailing});
  final String title;
  final String? subtitle;
  final VoidCallback? onViewAll;
  final EdgeInsets padding;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
        padding: padding,
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: context.text.titleLarge?.copyWith(fontSize: 19)),
              if (subtitle != null && subtitle!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(subtitle!, style: context.text.bodySmall),
              ],
            ]),
          ),
          ?trailing,
          if (onViewAll != null)
            TextButton(
              onPressed: onViewAll,
              child: const Row(mainAxisSize: MainAxisSize.min, children: [Text('See all'), Icon(Icons.chevron_right_rounded, size: 18)]),
            ),
        ]),
      );
}

/// Friendly error with retry (index building, offline, permission).
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, this.onRetry, this.compact = false});
  final Object error;
  final VoidCallback? onRetry;
  final bool compact;
  @override
  Widget build(BuildContext context) {
    final s = error.toString();
    final msg = s.contains('failed-precondition')
        ? 'This list is being prepared. Please try again in a minute.'
        : s.contains('unavailable') || s.contains('network')
            ? 'You seem to be offline. Check your connection.'
            : s.contains('permission-denied')
                ? 'You do not have access to this yet.'
                : friendlyError(error);
    if (compact) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          const Icon(Icons.info_outline_rounded, color: G4MColors.warning),
          const SizedBox(width: 10),
          Expanded(child: Text(msg, style: context.text.bodySmall)),
          if (onRetry != null) TextButton(onPressed: onRetry, child: const Text('Retry')),
        ]),
      );
    }
    return EmptyState(
      icon: Icons.cloud_off_rounded,
      title: 'Something went wrong',
      message: msg,
      action: onRetry == null ? null : OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
    );
  }
}

/// Animated rupee amount (used in bills and wallet).
class MoneyText extends StatelessWidget {
  const MoneyText(this.value, {super.key, this.style});
  final double value;
  final TextStyle? style;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(end: value),
        duration: G4MMotion.emphasized,
        curve: G4MMotion.curve,
        builder: (_, v, _) => Text(Fmt.money(double.parse(v.toStringAsFixed(2))), style: style),
      );
}

/// Small pill label.
class Tag extends StatelessWidget {
  const Tag(this.text, {super.key, this.color = G4MColors.accent, this.filled = true, this.icon});
  final String text;
  final Color color;
  final bool filled;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: filled ? color : color.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(G4MRadius.pill),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 12, color: filled ? Colors.white : color), const SizedBox(width: 3)],
          Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: filled ? Colors.white : color, letterSpacing: .2)),
        ]),
      );
}

/// Material icon for a module doc (`icon` may be a material name, URL or emoji).
IconData moduleIcon(MarketModule m) {
  const byName = <String, IconData>{
    'shopping_bag': Icons.shopping_bag_rounded,
    'store': Icons.storefront_rounded,
    'storefront': Icons.storefront_rounded,
    'local_grocery_store': Icons.local_grocery_store_rounded,
    'grocery': Icons.local_grocery_store_rounded,
    'shopping_basket': Icons.shopping_basket_rounded,
    'medication': Icons.medication_rounded,
    'local_pharmacy': Icons.local_pharmacy_rounded,
    'pharmacy': Icons.local_pharmacy_rounded,
    'restaurant': Icons.restaurant_rounded,
    'fastfood': Icons.fastfood_rounded,
    'lunch_dining': Icons.lunch_dining_rounded,
    'food': Icons.restaurant_rounded,
    'devices': Icons.devices_rounded,
    'checkroom': Icons.checkroom_rounded,
  };
  final hit = byName[m.icon.toLowerCase()];
  if (hit != null) return hit;
  return switch (m.id) {
    'grocery' => Icons.local_grocery_store_rounded,
    'pharmacy' => Icons.local_pharmacy_rounded,
    'food' => Icons.restaurant_rounded,
    _ => Icons.shopping_bag_rounded,
  };
}

/// Rounded bottom sheet with consistent padding.
Future<T?> showAppSheet<T>(BuildContext context, {required WidgetBuilder builder, bool scroll = true}) => showModalBottomSheet<T>(
      context: context,
      isScrollControlled: scroll,
      useSafeArea: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: builder(ctx),
      ),
    );
