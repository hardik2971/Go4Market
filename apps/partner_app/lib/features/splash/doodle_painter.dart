import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Tiled marketplace doodle: shopping and delivery glyphs laid out on a
/// staggered grid, each slightly rotated, drifting diagonally with [drift].
class MarketplaceDoodlePainter extends CustomPainter {
  MarketplaceDoodlePainter({required this.drift, required this.color, this.opacity = .07, this.cell = 68}) : super(repaint: drift);

  final Animation<double> drift;
  final Color color;
  final double opacity;
  final double cell;

  static const glyphs = <IconData>[
    Icons.shopping_bag_outlined,
    Icons.shopping_cart_outlined,
    Icons.storefront_outlined,
    Icons.local_shipping_outlined,
    Icons.delivery_dining_outlined,
    Icons.inventory_2_outlined,
    Icons.sell_outlined,
    Icons.location_on_outlined,
    Icons.receipt_long_outlined,
  ];

  // Cache laid-out glyphs: building TextPainters every frame is wasteful.
  static final Map<String, TextPainter> _cache = {};

  TextPainter _glyph(IconData icon, double size, Color c) {
    final key = '${icon.codePoint}_${size.toStringAsFixed(1)}_${c.toARGB32()}';
    return _cache.putIfAbsent(key, () {
      final tp = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(icon.codePoint),
          style: TextStyle(fontFamily: icon.fontFamily, package: icon.fontPackage, fontSize: size, color: c),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      return tp;
    });
  }

  @override
  void paint(Canvas canvas, Size size) {
    final c = color.withValues(alpha: opacity);
    // The glyph pattern repeats every 6 cells; drifting exactly one period per
    // cycle makes the loop seamless.
    const period = 6;
    final span = cell * period;
    final t = drift.value;
    final dx = (t * span) % span;
    final dy = span - (t * span) % span;
    final cols = (size.width / cell).ceil() + period + 2;
    final rows = (size.height / cell).ceil() + period + 2;

    for (var r = -period; r < rows; r++) {
      for (var col = -period; col < cols; col++) {
        final pr = (r % 6 + 6) % 6;
        final pc = (col % 6 + 6) % 6;
        final seed = pr * 7 + pc * 13;
        final icon = glyphs[seed % glyphs.length];
        final rot = ((seed * 37) % 31 - 15) * math.pi / 180; // -15deg .. +15deg
        final s = 22.0 + (seed % 3) * 4;
        final x = col * cell + (r.isOdd ? cell / 2 : 0) + dx;
        final y = r * cell + dy - span;
        if (x < -cell || y < -cell || x > size.width + cell || y > size.height + cell) continue;
        final tp = _glyph(icon, s, c);
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(rot);
        tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(MarketplaceDoodlePainter old) => old.color != color || old.opacity != opacity || old.cell != cell;
}

/// Convenience widget: full-bleed animated doodle background.
class DoodleBackground extends StatefulWidget {
  const DoodleBackground({super.key, required this.color, this.opacity = .07, this.period = const Duration(seconds: 24)});
  final Color color;
  final double opacity;
  final Duration period;
  @override
  State<DoodleBackground> createState() => _DoodleBackgroundState();
}

class _DoodleBackgroundState extends State<DoodleBackground> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: widget.period)..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: CustomPaint(
          painter: MarketplaceDoodlePainter(drift: _c, color: widget.color, opacity: widget.opacity),
          size: Size.infinite,
        ),
      );
}
