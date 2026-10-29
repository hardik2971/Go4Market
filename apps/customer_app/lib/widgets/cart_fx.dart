import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:g4m_core/g4m_core.dart';

import '../core/nav.dart';
import '../core/session.dart';
import '../core/theme.dart';
import 'ui.dart';

/// Registry of on-screen cart icons. The most recently mounted one is the fly-to-cart target.
class CartTargets {
  CartTargets._();
  static final _keys = <GlobalKey>[];
  static void add(GlobalKey k) => _keys.add(k);
  static void remove(GlobalKey k) => _keys.remove(k);
  static Rect? rect() {
    for (final k in _keys.reversed) {
      final ctx = k.currentContext;
      final box = ctx?.findRenderObject() as RenderBox?;
      if (box != null && box.attached && box.hasSize) {
        final o = box.localToGlobal(Offset.zero);
        if (o.dx >= 0 && o.dy >= 0) return o & box.size;
      }
    }
    return null;
  }
}

/// Animates a thumbnail from [from] to the current cart icon along an arc.
void flyToCart(BuildContext context, String image) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  final box = context.findRenderObject() as RenderBox?;
  final target = CartTargets.rect();
  if (overlay == null || box == null || target == null || !box.attached) return;
  final start = box.localToGlobal(box.size.center(Offset.zero));
  final end = target.center;
  late OverlayEntry entry;
  final ctrl = AnimationController(vsync: overlay, duration: const Duration(milliseconds: 720));
  final curve = CurvedAnimation(parent: ctrl, curve: Curves.easeInOutCubic);
  final control = Offset((start.dx + end.dx) / 2, start.dy - 160);
  entry = OverlayEntry(
    builder: (_) => AnimatedBuilder(
      animation: curve,
      builder: (_, _) {
        final t = curve.value;
        // Quadratic bezier.
        final p = Offset(
          (1 - t) * (1 - t) * start.dx + 2 * (1 - t) * t * control.dx + t * t * end.dx,
          (1 - t) * (1 - t) * start.dy + 2 * (1 - t) * t * control.dy + t * t * end.dy,
        );
        final size = 54 * (1 - .7 * t);
        return Positioned(
          left: p.dx - size / 2,
          top: p.dy - size / 2,
          child: IgnorePointer(
            child: Opacity(
              opacity: t > .9 ? (1 - t) * 10 : 1,
              child: Transform.rotate(
                angle: t * .6,
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(color: G4MColors.primary, width: 2),
                    boxShadow: G4MShadows.lifted,
                  ),
                  child: ClipOval(child: Img(image, width: size, height: size, iconSize: 16)),
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
  overlay.insert(entry);
  ctrl.forward().whenComplete(() {
    entry.remove();
    ctrl.dispose();
  });
}

/// Cart icon with a badge that bumps every time the count changes.
class CartBadgeIcon extends StatefulWidget {
  const CartBadgeIcon({super.key, this.icon = Icons.shopping_bag_outlined, this.color, this.size = 24, this.register = true});
  final IconData icon;
  final Color? color;
  final double size;
  final bool register;
  @override
  State<CartBadgeIcon> createState() => _CartBadgeIconState();
}

class _CartBadgeIconState extends State<CartBadgeIcon> with SingleTickerProviderStateMixin {
  final _key = GlobalKey();
  late final _bump = AnimationController(vsync: this, duration: const Duration(milliseconds: 520));
  late int _count = Session.instance.cartCount;

  @override
  void initState() {
    super.initState();
    if (widget.register) CartTargets.add(_key);
    Session.instance.cart.addListener(_onCart);
  }

  void _onCart() {
    final c = Session.instance.cartCount;
    if (c != _count) {
      final up = c > _count;
      setState(() => _count = c);
      if (up) {
        // Let the flying thumbnail land first.
        Future.delayed(const Duration(milliseconds: 560), () {
          if (mounted) _bump.forward(from: 0);
        });
      }
    }
  }

  @override
  void dispose() {
    CartTargets.remove(_key);
    Session.instance.cart.removeListener(_onCart);
    _bump.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _bump,
      builder: (_, child) {
        final t = _bump.value;
        final s = 1 + .35 * Curves.elasticOut.transform(t) * (1 - t);
        return Transform.scale(scale: s, child: child);
      },
      child: Stack(clipBehavior: Clip.none, children: [
        Icon(widget.icon, key: _key, color: widget.color, size: widget.size),
        Positioned(
          right: -8,
          top: -6,
          child: AnimatedSwitcher(
            duration: G4MMotion.standard,
            transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
            child: _count == 0
                ? const SizedBox.shrink()
                : Container(
                    key: ValueKey(_count),
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    constraints: const BoxConstraints(minWidth: 18),
                    decoration: BoxDecoration(
                      color: G4MColors.accent,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: context.card, width: 1.5),
                    ),
                    child: Text(
                      _count > 99 ? '99+' : '$_count',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800, height: 1.3),
                    ),
                  ),
          ),
        ),
      ]),
    );
  }
}

/// "ADD" pill that morphs into a − qty + stepper. Optionally flies the product image to the cart.
class AddToCartButton extends StatefulWidget {
  const AddToCartButton({super.key, required this.product, this.variantId, this.height = 34, this.expanded = false, this.label});
  final Product product;
  final String? variantId;
  final double height;
  final bool expanded;
  final String? label;
  @override
  State<AddToCartButton> createState() => _AddToCartButtonState();
}

class _AddToCartButtonState extends State<AddToCartButton> {
  String get _vid => widget.variantId ?? (widget.product.variants.isEmpty ? 'default' : widget.product.variants.first.id);

  int _stockLimit() {
    final p = widget.product;
    if (p.variants.isEmpty) return p.stock <= 0 ? 0 : p.stock;
    final v = p.variants.where((e) => e.id == _vid);
    return v.isEmpty ? p.stock : v.first.stock;
  }

  Future<void> _set(int q) async {
    final limit = _stockLimit();
    if (q > limit && limit > 0) {
      context.toast('Only $limit available');
      return;
    }
    HapticFeedback.lightImpact();
    try {
      await Session.instance.setQty(widget.product, q, variantId: _vid);
    } catch (e) {
      if (mounted) context.toast(friendlyError(e), error: true);
    }
  }

  Widget _qty(int q) => AnimatedSwitcher(
        duration: G4MMotion.standard,
        transitionBuilder: (c, a) => SlideTransition(
          position: Tween(begin: const Offset(0, .6), end: Offset.zero).animate(a),
          child: FadeTransition(opacity: a, child: c),
        ),
        child: Text('$q',
            key: ValueKey(q), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
      );

  @override
  Widget build(BuildContext context) {
    final inStock = _stockLimit() > 0;
    return ValueListenableBuilder(
      valueListenable: Session.instance.cart,
      builder: (context, _, _) {
        final q = Session.instance.qtyOf(widget.product.id, _vid);
        final h = widget.height;
        final Widget child;
        if (!inStock) {
          child = Container(
            key: const ValueKey('oos'),
            height: h,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: context.cardAlt, borderRadius: BorderRadius.circular(10)),
            child: Text('Sold out', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: context.muted)),
          );
        } else if (q == 0) {
          child = Builder(
            key: const ValueKey('add'),
            builder: (bctx) => Pressable(
              onTap: () {
                flyToCart(bctx, widget.product.image);
                _set(1);
              },
              child: Container(
                height: h,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: context.isDark ? const Color(0xFF15372A) : Colors.white,
                  border: Border.all(color: G4MColors.primary, width: 1.4),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
                  if (widget.expanded) ...[const Icon(Icons.add_shopping_cart_rounded, size: 18, color: G4MColors.primary), const SizedBox(width: 8)],
                  Text(widget.label ?? 'ADD',
                      style: TextStyle(fontWeight: FontWeight.w800, color: G4MColors.primary, fontSize: widget.expanded ? 15 : 13, letterSpacing: .4)),
                ]),
              ),
            ),
          );
        } else {
          child = Container(
            key: const ValueKey('stepper'),
            height: h,
            decoration: BoxDecoration(
              color: G4MColors.primary,
              borderRadius: BorderRadius.circular(10),
              boxShadow: const [BoxShadow(color: Color(0x330B8A4F), blurRadius: 12, offset: Offset(0, 4))],
            ),
            child: Row(mainAxisSize: widget.expanded ? MainAxisSize.max : MainAxisSize.min, children: [
              _StepBtn(icon: q == 1 ? Icons.delete_outline_rounded : Icons.remove_rounded, onTap: () => _set(q - 1), h: h),
              if (widget.expanded) Expanded(child: _qty(q)) else SizedBox(width: 24, child: _qty(q)),
              _StepBtn(icon: Icons.add_rounded, onTap: () => _set(q + 1), h: h),
            ]),
          );
        }
        return AnimatedSize(
          duration: G4MMotion.standard,
          curve: G4MMotion.curve,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            switchInCurve: Curves.easeOutBack,
            transitionBuilder: (c, a) => ScaleTransition(scale: Tween(begin: .85, end: 1.0).animate(a), child: FadeTransition(opacity: a, child: c)),
            child: child,
          ),
        );
      },
    );
  }
}

class _StepBtn extends StatelessWidget {
  const _StepBtn({required this.icon, required this.onTap, required this.h});
  final IconData icon;
  final VoidCallback onTap;
  final double h;
  @override
  Widget build(BuildContext context) => InkResponse(
        onTap: onTap,
        radius: h * .7,
        child: SizedBox(width: h, height: h, child: Icon(icon, color: Colors.white, size: h * .5)),
      );
}

/// Heart that pops when toggled.
class WishButton extends StatelessWidget {
  const WishButton({super.key, required this.productId, this.size = 20, this.background = true});
  final String productId;
  final double size;
  final bool background;
  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
        valueListenable: Session.instance.wishlist,
        builder: (context, set, _) {
          final on = set.contains(productId);
          return Pressable(
            scale: .85,
            onTap: () => Session.instance.toggleWishlist(productId).catchError((e) {
              if (context.mounted) context.toast(friendlyError(e), error: true);
            }),
            child: Container(
              padding: EdgeInsets.all(background ? 6 : 0),
              decoration: background
                  ? BoxDecoration(color: context.card.withValues(alpha: .92), shape: BoxShape.circle, boxShadow: context.softShadow)
                  : null,
              child: TweenAnimationBuilder<double>(
                key: ValueKey(on),
                tween: Tween(begin: on ? .5 : 1, end: 1),
                duration: const Duration(milliseconds: 420),
                curve: Curves.elasticOut,
                builder: (_, s, child) => Transform.scale(scale: s, child: child),
                child: Icon(on ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    size: size, color: on ? const Color(0xFFE5484D) : context.muted),
              ),
            ),
          );
        },
      );
}
