import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:g4m_core/g4m_core.dart';

import '../../core/nav.dart';
import '../../core/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/ui.dart';
import '../orders/order_detail_screen.dart';
import '../shell/main_shell.dart';

/// Animated confirmation: drawn check mark, confetti burst, live order status.
class OrderSuccessScreen extends StatefulWidget {
  const OrderSuccessScreen({super.key, required this.orderId, required this.orderNo, this.paid = true, this.note = '', this.method = 'cod'});
  final String orderId, orderNo, note, method;
  final bool paid;
  @override
  State<OrderSuccessScreen> createState() => _OrderSuccessScreenState();
}

class _OrderSuccessScreenState extends State<OrderSuccessScreen> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (did, _) {
        if (!did) goHomeTab(context);
      },
      child: Scaffold(
        body: StreamBuilder<ShopOrder?>(
          stream: ShopperRepo.instance.order(widget.orderId),
          builder: (context, snap) {
            final o = snap.data;
            final paymentPending = !widget.paid && (o == null || o.paymentStatus != 'paid');
            final color = paymentPending ? G4MColors.warning : G4MColors.primary;
            return SafeArea(
              child: Stack(children: [
                if (!paymentPending)
                  Positioned.fill(
                    child: IgnorePointer(child: AnimatedBuilder(animation: _c, builder: (_, _) => CustomPaint(painter: _ConfettiPainter(_c.value)))),
                  ),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(children: [
                    const Spacer(),
                    SizedBox(
                      width: 140,
                      height: 140,
                      child: AnimatedBuilder(
                        animation: _c,
                        builder: (_, _) => CustomPaint(painter: _CheckPainter(_c.value, color, pending: paymentPending)),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(paymentPending ? 'Order received' : l.orderPlaced, style: context.text.headlineMedium, textAlign: TextAlign.center)
                        .animate(delay: 600.ms)
                        .fadeIn()
                        .slideY(begin: .3),
                    const SizedBox(height: 8),
                    Text(
                      paymentPending
                          ? (widget.note.isNotEmpty ? widget.note : 'Payment is pending. We will confirm your order once it is paid.')
                          : 'Order #${o?.orderNo ?? widget.orderNo} is confirmed. Sit back, we are on it!',
                      textAlign: TextAlign.center,
                      style: context.text.bodyLarge?.copyWith(color: context.muted),
                    ).animate(delay: 750.ms).fadeIn(),
                    const SizedBox(height: 22),
                    if (o != null)
                      AppCard(
                        child: Column(children: [
                          _kv(context, 'Status', OrderStatus.label(o.status)),
                          _kv(context, 'Payment', '${Fmt.titleCase(o.paymentMethod)} · ${Fmt.titleCase(o.paymentStatus)}'),
                          _kv(context, 'Total', Fmt.money(o.payable)),
                          if (o.speed.startsWith('quick') || o.etaAt != null)
                            _kv(context, 'Arriving', o.etaAt != null ? Fmt.time(o.etaAt) : (o.speed == 'quick15' ? 'in ~15 min' : 'in ~30 min')),
                          if (o.speed == 'scheduled' && o.scheduledSlot.isNotEmpty)
                            _kv(context, 'Slot', '${o.scheduledSlot['date']} · ${o.scheduledSlot['from']}–${o.scheduledSlot['to']}'),
                        ]),
                      ).animate(delay: 900.ms).fadeIn().slideY(begin: .15),
                    const Spacer(),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
                      onPressed: () => Navigator.of(context).pushReplacement(appRoute(OrderDetailScreen(orderId: widget.orderId))),
                      icon: const Icon(Icons.route_rounded),
                      label: Text(l.trackOrder),
                    ).animate(delay: 1000.ms).fadeIn().slideY(begin: .4),
                    const SizedBox(height: 10),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(54)),
                      onPressed: () => goHomeTab(context),
                      child: Text(l.continueShopping),
                    ).animate(delay: 1080.ms).fadeIn(),
                  ]),
                ),
              ]),
            );
          },
        ),
      ),
    );
  }

  Widget _kv(BuildContext context, String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          Expanded(child: Text(k, style: context.text.bodyMedium?.copyWith(color: context.muted))),
          Text(v, style: context.text.titleSmall),
        ]),
      );
}

class _CheckPainter extends CustomPainter {
  _CheckPainter(this.t, this.color, {this.pending = false});
  final double t;
  final Color color;
  final bool pending;
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final grow = Curves.elasticOut.transform((t / .45).clamp(0, 1));
    canvas.drawCircle(c, r * grow, Paint()..color = color.withValues(alpha: .14));
    canvas.drawCircle(c, r * .72 * grow, Paint()..color = color);
    final p = (t - .35) / .4;
    if (p <= 0) return;
    final stroke = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    if (pending) {
      // Clock hands.
      final k = p.clamp(0.0, 1.0);
      canvas.drawLine(c, c + Offset(0, -r * .32 * k), stroke);
      canvas.drawLine(c, c + Offset(r * .22 * k, r * .1 * k), stroke);
      return;
    }
    final path = Path()
      ..moveTo(c.dx - r * .3, c.dy + r * .02)
      ..lineTo(c.dx - r * .07, c.dy + r * .25)
      ..lineTo(c.dx + r * .33, c.dy - r * .2);
    final metric = path.computeMetrics().first;
    canvas.drawPath(metric.extractPath(0, metric.length * Curves.easeOutCubic.transform(p.clamp(0, 1))), stroke);
  }

  @override
  bool shouldRepaint(_CheckPainter old) => old.t != t || old.color != color;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.t);
  final double t;
  static final _rnd = math.Random(7);
  static final _pieces = List.generate(70, (_) => (_rnd.nextDouble(), _rnd.nextDouble(), _rnd.nextDouble(), _rnd.nextInt(4)));
  static const _colors = [G4MColors.primary, G4MColors.accent, Color(0xFF2563EB), Color(0xFFF5A524)];

  @override
  void paint(Canvas canvas, Size size) {
    if (t < .3) return;
    final k = ((t - .3) / .7).clamp(0.0, 1.0);
    final origin = Offset(size.width / 2, size.height * .32);
    for (final (a, sp, rot, ci) in _pieces) {
      final angle = -math.pi / 2 + (a - .5) * math.pi * 1.4;
      final speed = 260 + sp * 340;
      final pos = origin + Offset(math.cos(angle) * speed * k, math.sin(angle) * speed * k + 520 * k * k);
      final paint = Paint()..color = _colors[ci].withValues(alpha: (1 - k).clamp(0, 1));
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(rot * 12 * k);
      canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-4, -2, 8, 4), const Radius.circular(1)), paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
