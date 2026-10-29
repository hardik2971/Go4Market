import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/brand.dart';
import '../utils/format.dart';

/// The bag-and-arrow mark from logo.png.
class G4MLogo extends StatelessWidget {
  const G4MLogo({super.key, this.size = 40});
  final double size;
  @override
  Widget build(BuildContext context) => Image.asset(
        'packages/g4m_core/assets/logo.png',
        width: size,
        height: size,
        filterQuality: FilterQuality.medium,
        semanticLabel: 'Go4Market logo',
      );
}

/// Logo mark + "Go4Market" wordmark: Go in deep green, 4 in orange, Market in brand green.
class G4MWordmark extends StatelessWidget {
  const G4MWordmark({super.key, this.size = 36, this.light = false, this.showMark = true});
  final double size;
  final bool light;
  final bool showMark;
  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: size * .62,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.8,
      height: 1,
      color: light ? Colors.white : G4MColors.primaryDeep,
    );
    return Row(mainAxisSize: MainAxisSize.min, children: [
      if (showMark) ...[G4MLogo(size: size), SizedBox(width: size * .18)],
      Text.rich(
        TextSpan(style: style, children: [
          const TextSpan(text: 'Go'),
          const TextSpan(text: '4', style: TextStyle(color: G4MColors.accent)),
          TextSpan(text: 'Market', style: TextStyle(color: light ? const Color(0xFFBFF0D4) : G4MColors.primary)),
        ]),
        semanticsLabel: 'Go4Market',
      ),
    ]);
  }
}

/// Network image with soft placeholder + fade-in. Never throws on a bad URL.
class NetImage extends StatelessWidget {
  const NetImage(this.url, {super.key, this.fit = BoxFit.cover, this.width, this.height, this.radius = 0, this.semanticLabel});
  final String url;
  final BoxFit fit;
  final double? width, height;
  final double radius;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final ph = Container(
      width: width,
      height: height,
      color: G4MColors.surfaceAlt,
      alignment: Alignment.center,
      child: const Icon(Icons.image_outlined, color: G4MColors.inkFaint),
    );
    final img = url.isEmpty
        ? ph
        : CachedNetworkImage(
            imageUrl: url,
            width: width,
            height: height,
            fit: fit,
            fadeInDuration: G4MMotion.standard,
            placeholder: (_, _) => Container(width: width, height: height, color: G4MColors.surfaceAlt),
            errorWidget: (_, _, _) => ph,
          );
    final child = semanticLabel == null ? img : Semantics(label: semanticLabel, image: true, child: img);
    return radius == 0 ? child : ClipRRect(borderRadius: BorderRadius.circular(radius), child: child);
  }
}

/// Pill showing a status with its semantic colour.
class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key, this.label});
  final String status;
  final String? label;
  @override
  Widget build(BuildContext context) {
    final c = statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: c.withValues(alpha: .1), borderRadius: BorderRadius.circular(G4MRadius.pill)),
      child: Text(label ?? Fmt.titleCase(status),
          style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }
}

/// Price with struck-through MRP and discount badge.
class PriceTag extends StatelessWidget {
  const PriceTag({super.key, required this.price, this.mrp, this.size = 16, this.showBadge = true});
  final double price;
  final double? mrp;
  final double size;
  final bool showBadge;
  @override
  Widget build(BuildContext context) {
    final off = mrp != null && mrp! > price ? (((mrp! - price) / mrp!) * 100).round() : 0;
    return Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 6, runSpacing: 2, children: [
      Text(Fmt.money(price), style: TextStyle(fontSize: size, fontWeight: FontWeight.w800, color: G4MColors.ink)),
      if (off > 0)
        Text(Fmt.money(mrp!),
            style: TextStyle(
              fontSize: size * .78,
              color: G4MColors.inkMuted,
              decoration: TextDecoration.lineThrough,
              decorationColor: G4MColors.inkMuted,
            )),
      if (off > 0 && showBadge)
        Text('$off% off', style: TextStyle(fontSize: size * .78, fontWeight: FontWeight.w800, color: G4MColors.success)),
    ]);
  }
}

/// Wraps any child with a subtle press-down scale + haptic. Use for cards/buttons.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, this.onTap, this.scale = .97, this.haptic = true});
  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  final bool haptic;
  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;
  void _set(bool v) => setState(() => _down = v);
  @override
  Widget build(BuildContext context) => MouseRegion(
        cursor: widget.onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: widget.onTap == null ? null : (_) => _set(true),
          onTapCancel: () => _set(false),
          onTapUp: (_) => _set(false),
          onTap: widget.onTap == null
              ? null
              : () {
                  if (widget.haptic) HapticFeedback.selectionClick();
                  widget.onTap!();
                },
          child: AnimatedScale(
            scale: _down ? widget.scale : 1,
            duration: G4MMotion.fast,
            curve: G4MMotion.curve,
            child: widget.child,
          ),
        ),
      );
}

/// Shimmering placeholder block for loading states.
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, this.width, this.height = 16, this.radius = G4MRadius.sm});
  final double? width;
  final double height;
  final double radius;
  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300))..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, _) => Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(-1.5 + _c.value * 3, 0),
              end: Alignment(-0.5 + _c.value * 3, 0),
              colors: const [Color(0xFFEDF2EF), Color(0xFFF7FAF8), Color(0xFFEDF2EF)],
            ),
          ),
        ),
      );
}

/// Friendly empty / error state.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.message, this.action});
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 88,
              height: 88,
              decoration: const BoxDecoration(color: G4MColors.primarySoft, shape: BoxShape.circle),
              child: Icon(icon, size: 40, color: G4MColors.primary),
            ),
            const SizedBox(height: 20),
            Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(message!, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: G4MColors.inkMuted)),
            ],
            if (action != null) ...[const SizedBox(height: 20), action!],
          ]),
        ),
      );
}

/// Star rating row (read-only).
class RatingStars extends StatelessWidget {
  const RatingStars(this.rating, {super.key, this.size = 14, this.count});
  final double rating;
  final double size;
  final int? count;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 1; i <= 5; i++)
          Icon(
            rating >= i ? Icons.star_rounded : rating >= i - .5 ? Icons.star_half_rounded : Icons.star_outline_rounded,
            size: size,
            color: const Color(0xFFF5A524),
          ),
        if (count != null) ...[
          const SizedBox(width: 4),
          Text('($count)', style: TextStyle(fontSize: size * .85, color: G4MColors.inkMuted)),
        ],
      ]);
}

/// Veg / non-veg marker (square with dot).
class VegMark extends StatelessWidget {
  const VegMark({super.key, required this.isVeg, this.size = 14});
  final bool isVeg;
  final double size;
  @override
  Widget build(BuildContext context) {
    final c = isVeg ? G4MColors.success : G4MColors.danger;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(border: Border.all(color: c, width: 1.4), borderRadius: BorderRadius.circular(3)),
      alignment: Alignment.center,
      child: Container(width: size * .45, height: size * .45, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
    );
  }
}

String friendlyError(Object e) {
  final s = e.toString();
  final m = RegExp(r'\] (.+)$').firstMatch(s);
  return (m?.group(1) ?? s).replaceAll('Exception: ', '');
}
