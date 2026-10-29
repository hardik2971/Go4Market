import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:g4m_core/g4m_core.dart';

/// Marketplace doodle wallpaper: shopping glyphs tiled in a staggered grid, slightly rotated,
/// at low opacity, slowly drifting diagonally. Glyph painters are built once and cached.
class DoodleBackground extends StatefulWidget {
  const DoodleBackground({super.key, this.color = G4MColors.primary, this.opacity = .07, this.drift = true, this.cell = 64, this.child});
  final Color color;
  final double opacity;
  final bool drift;
  final double cell;
  final Widget? child;

  @override
  State<DoodleBackground> createState() => _DoodleBackgroundState();
}

class _DoodleBackgroundState extends State<DoodleBackground> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 28));

  @override
  void initState() {
    super.initState();
    if (widget.drift) _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(fit: StackFit.expand, children: [
        RepaintBoundary(
          child: CustomPaint(
            painter: DoodlePainter(
              color: widget.color.withValues(alpha: widget.opacity),
              cell: widget.cell,
              progress: _c,
            ),
          ),
        ),
        ?widget.child,
      ]);
}

class DoodlePainter extends CustomPainter {
  DoodlePainter({required this.color, required this.cell, required this.progress}) : super(repaint: progress);
  final Color color;
  final double cell;
  final Animation<double> progress;

  static const glyphs = <IconData>[
    Icons.shopping_bag_outlined,
    Icons.shopping_cart_outlined,
    Icons.shopping_basket_outlined,
    Icons.eco_outlined, // fresh produce
    Icons.egg_outlined,
    Icons.medication_outlined, // pill
    Icons.card_giftcard_outlined,
    Icons.sell_outlined, // price tag
    Icons.local_shipping_outlined, // truck
    Icons.coffee_outlined,
    Icons.storefront_outlined,
    Icons.local_pizza_outlined,
    Icons.bakery_dining_outlined,
    Icons.icecream_outlined,
    Icons.local_offer_outlined,
    Icons.local_florist_outlined,
  ];

  static final Map<int, List<TextPainter>> _cache = {};

  List<TextPainter> _painters(double size) {
    final key = Object.hash(color.toARGB32(), size.round());
    return _cache.putIfAbsent(key, () {
      return [
        for (final g in glyphs)
          TextPainter(
            text: TextSpan(
              text: String.fromCharCode(g.codePoint),
              style: TextStyle(fontFamily: g.fontFamily, package: g.fontPackage, fontSize: size, color: color),
            ),
            textDirection: TextDirection.ltr,
          )..layout(),
      ];
    });
  }

  @override
  void paint(Canvas canvas, Size size) {
    final glyphSize = cell * .42;
    final ps = _painters(glyphSize);
    final shift = progress.value * cell * 2; // two cells per loop -> seamless
    final cols = (size.width / cell).ceil() + 3;
    final rows = (size.height / cell).ceil() + 3;
    for (var r = -2; r < rows; r++) {
      for (var c = -2; c < cols; c++) {
        final idx = ((r * 7 + c * 3) % ps.length + ps.length) % ps.length;
        final tp = ps[idx];
        final dx = c * cell + (r.isOdd ? cell / 2 : 0) + shift;
        final dy = r * cell + shift * .5;
        final angle = ((r * 13 + c * 7) % 9 - 4) * .09; // ~ -20°..20°
        canvas.save();
        canvas.translate(dx % (cols * cell) - cell, dy % (rows * cell) - cell);
        canvas.rotate(angle);
        tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(DoodlePainter old) => old.color != color || old.cell != cell;
}

/// Soft radial glow used behind the logo.
class GlowPainter extends CustomPainter {
  GlowPainter(this.t, this.color);
  final double t;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final paint = Paint()
      ..shader = RadialGradient(colors: [
        color.withValues(alpha: .28 * t),
        color.withValues(alpha: .10 * t),
        color.withValues(alpha: 0),
      ], stops: const [0, .55, 1])
          .createShader(Rect.fromCircle(center: c, radius: r));
    canvas.drawCircle(c, r * (0.85 + .15 * math.sin(t * math.pi)), paint);
  }

  @override
  bool shouldRepaint(GlowPainter old) => old.t != t || old.color != color;
}
