import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:g4m_core/g4m_core.dart';

import 'l10n.dart';
import 'live.dart';
import 'partner_theme.dart';

// ---------------------------------------------------------------------------
// Feedback helpers
// ---------------------------------------------------------------------------

void toast(BuildContext context, String msg, {bool error = false, IconData? icon}) {
  final m = ScaffoldMessenger.maybeOf(context);
  if (m == null) return;
  m.hideCurrentSnackBar();
  m.showSnackBar(SnackBar(
    backgroundColor: error ? G4MColors.danger : G4MColors.primaryDeep,
    content: Row(children: [
      Icon(icon ?? (error ? Icons.error_outline_rounded : Icons.check_circle_rounded), color: Colors.white, size: 20),
      const SizedBox(width: 10),
      Expanded(child: Text(msg)),
    ]),
  ));
}

/// Runs [action] behind a blocking progress overlay; shows a toast on error.
/// Returns the result or null on failure.
Future<T?> runBusy<T>(BuildContext context, Future<T> Function() action, {String? success}) async {
  final nav = Navigator.of(context, rootNavigator: true);
  var shown = true;
  showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black26,
    transitionDuration: G4MMotion.standard,
    pageBuilder: (_, _, _) => const PopScope(canPop: false, child: Center(child: _BusyCard())),
    transitionBuilder: (_, a, _, c) => FadeTransition(opacity: a, child: ScaleTransition(scale: Tween(begin: .9, end: 1.0).animate(a), child: c)),
  );
  try {
    final r = await action();
    if (shown) {
      nav.pop();
      shown = false;
    }
    if (success != null && context.mounted) toast(context, success);
    return r;
  } catch (e) {
    if (shown) {
      nav.pop();
      shown = false;
    }
    if (context.mounted) toast(context, describeError(e), error: true);
    return null;
  }
}

class _BusyCard extends StatelessWidget {
  const _BusyCard();
  @override
  Widget build(BuildContext context) => Container(
        width: 84,
        height: 84,
        decoration: BoxDecoration(color: context.rc.card, borderRadius: BorderRadius.circular(G4MRadius.lg), boxShadow: G4MShadows.lifted),
        alignment: Alignment.center,
        child: const SizedBox(width: 30, height: 30, child: CircularProgressIndicator(strokeWidth: 3)),
      );
}

Future<bool> confirmDialog(BuildContext context, {required String title, String? message, String? confirmText, bool danger = false}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: message == null ? null : Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: Text(c.s.cancel)),
        FilledButton(
          style: danger ? FilledButton.styleFrom(backgroundColor: G4MColors.danger) : null,
          onPressed: () => Navigator.pop(c, true),
          child: Text(confirmText ?? c.s.confirm),
        ),
      ],
    ),
  );
  return r ?? false;
}

/// Bottom sheet asking for a line of text (e.g. cancel reason). Returns null on dismiss.
Future<String?> promptText(BuildContext context,
    {required String title, String? hint, List<String> suggestions = const [], String? initial, TextInputType? keyboard, String? confirmText}) {
  final ctrl = TextEditingController(text: initial);
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (c) => Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(c).viewInsets.bottom + 20),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(title, style: c.tt.titleLarge),
        const SizedBox(height: 12),
        if (suggestions.isNotEmpty)
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final s in suggestions) ActionChip(label: Text(s), onPressed: () => ctrl.text = s),
          ]),
        const SizedBox(height: 12),
        TextField(controller: ctrl, autofocus: suggestions.isEmpty, keyboardType: keyboard, decoration: InputDecoration(hintText: hint)),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () {
            if (ctrl.text.trim().isEmpty) return;
            Navigator.pop(c, ctrl.text.trim());
          },
          child: Text(confirmText ?? c.s.confirm),
        ),
      ]),
    ),
  );
}

// ---------------------------------------------------------------------------
// Loading / empty / error
// ---------------------------------------------------------------------------

/// Theme-aware shimmer block (core `Skeleton` is light-only).
class Shimmer extends StatefulWidget {
  const Shimmer({super.key, this.width, this.height = 16, this.radius = G4MRadius.sm});
  final double? width;
  final double height;
  final double radius;
  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300))..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rc = context.rc;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          gradient: LinearGradient(
            begin: Alignment(-1.5 + _c.value * 3, 0),
            end: Alignment(-0.5 + _c.value * 3, 0),
            colors: [rc.skeletonBase, rc.skeletonShine, rc.skeletonBase],
          ),
        ),
      ),
    );
  }
}

/// A list of card-shaped skeleton rows.
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.count = 6, this.itemHeight = 84, this.padding = const EdgeInsets.all(16)});
  final int count;
  final double itemHeight;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => ListView.separated(
        padding: padding,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: count,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, i) => Container(
          height: itemHeight,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: context.rc.card, borderRadius: BorderRadius.circular(G4MRadius.md), border: Border.all(color: context.rc.line)),
          child: Row(children: [
            Shimmer(width: itemHeight - 28, height: itemHeight - 28),
            const SizedBox(width: 14),
            Expanded(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Shimmer(width: 140 + (i % 3) * 30.0, height: 14),
                const SizedBox(height: 10),
                const Shimmer(width: 90, height: 12),
              ]),
            ),
          ]),
        ).animate(delay: (i * 60).ms).fadeIn(duration: 300.ms),
      );
}

/// Theme-aware empty state (core `EmptyState` uses fixed light colours).
class AppEmpty extends StatelessWidget {
  const AppEmpty({super.key, required this.icon, required this.title, this.message, this.action});
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;
  @override
  Widget build(BuildContext context) {
    final rc = context.rc;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(color: rc.brandSoft, shape: BoxShape.circle),
            child: Icon(icon, size: 42, color: rc.brand),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .moveY(begin: 0, end: -6, duration: 1600.ms, curve: Curves.easeInOut),
          const SizedBox(height: 20),
          Text(title, textAlign: TextAlign.center, style: context.tt.titleLarge),
          if (message != null) ...[
            const SizedBox(height: 8),
            Text(message!, textAlign: TextAlign.center, style: context.tt.bodyMedium?.copyWith(color: rc.muted)),
          ],
          if (action != null) ...[const SizedBox(height: 20), action!],
        ]).animate().fadeIn(duration: 400.ms).slideY(begin: .06),
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView(this.error, {super.key, this.onRetry});
  final Object error;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => AppEmpty(
        icon: Icons.cloud_off_rounded,
        title: context.s.somethingWrong,
        message: describeError(error),
        action: onRetry == null ? null : OutlinedButton(onPressed: onRetry, child: Text(context.s.retry)),
      );
}

/// StreamBuilder with skeleton loading, friendly errors and an empty state.
class LiveList<T> extends StatelessWidget {
  const LiveList({
    super.key,
    required this.stream,
    required this.builder,
    this.empty,
    this.skeleton,
    this.isEmpty,
  });
  final Stream<T> stream;
  final Widget Function(BuildContext context, T data) builder;
  final Widget? empty;
  final Widget? skeleton;
  final bool Function(T data)? isEmpty;

  @override
  Widget build(BuildContext context) => StreamBuilder<T>(
        stream: stream,
        builder: (context, snap) {
          Widget child;
          if (snap.hasError) {
            child = ErrorView(snap.error!);
          } else if (!snap.hasData) {
            child = skeleton ?? const SkeletonList();
          } else {
            final d = snap.data as T;
            final e = isEmpty?.call(d) ?? (d is List && d.isEmpty);
            child = e && empty != null ? empty! : builder(context, d);
          }
          return AnimatedSwitcher(duration: G4MMotion.standard, child: KeyedSubtree(key: ValueKey(child.runtimeType), child: child));
        },
      );
}

// ---------------------------------------------------------------------------
// Cards, stats, counters
// ---------------------------------------------------------------------------

class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.onTap, this.padding = const EdgeInsets.all(16), this.color, this.borderColor, this.radius = G4MRadius.md});
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final Color? color;
  final Color? borderColor;
  final double radius;
  @override
  Widget build(BuildContext context) {
    final box = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? context.rc.card,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? context.rc.line),
        boxShadow: context.isDark ? null : G4MShadows.soft,
      ),
      child: child,
    );
    return onTap == null ? box : Pressable(onTap: onTap, child: box);
  }
}

/// Number that counts up/down to its new value.
class AnimatedCounter extends StatelessWidget {
  const AnimatedCounter(this.value, {super.key, this.money = false, this.style, this.compact = false, this.duration = const Duration(milliseconds: 1100)});
  final num value;
  final bool money;
  final bool compact;
  final TextStyle? style;
  final Duration duration;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(end: value.toDouble()),
        duration: duration,
        curve: Curves.easeOutExpo,
        builder: (_, v, _) => Text(
          money ? (compact && v >= 100000 ? Fmt.moneyCompact(v) : Fmt.money(v.roundToDouble())) : Fmt.number(v.round()),
          style: style,
        ),
      );
}

class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.icon, required this.label, required this.value, this.money = false, this.color, this.onTap});
  final IconData icon;
  final String label;
  final num value;
  final bool money;
  final Color? color;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final c = color ?? context.rc.brand;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(color: c.withValues(alpha: .12), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: c, size: 20),
        ),
        const SizedBox(height: 12),
        AnimatedCounter(value, money: money, compact: true, style: context.tt.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.tt.bodySmall?.copyWith(color: context.rc.muted)),
      ]),
    );
  }
}

/// Gradient hero surface with a faint glyph pattern.
class HeroPanel extends StatelessWidget {
  const HeroPanel({super.key, required this.child, this.padding = const EdgeInsets.all(20)});
  final Widget child;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          gradient: context.rc.hero,
          borderRadius: BorderRadius.circular(G4MRadius.lg),
          boxShadow: G4MShadows.lifted,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(G4MRadius.lg),
          child: Stack(children: [
            Positioned(right: -30, top: -30, child: _ring(140)),
            Positioned(right: 40, bottom: -50, child: _ring(110)),
            Padding(padding: padding, child: DefaultTextStyle.merge(style: const TextStyle(color: Colors.white), child: child)),
          ]),
        ),
      );

  Widget _ring(double s) => Container(
        width: s,
        height: s,
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: .08), width: 18)),
      );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.action, this.onAction});
  final String title;
  final String? action;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
        child: Row(children: [
          Expanded(child: Text(title, style: context.tt.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
          if (action != null) TextButton(onPressed: onAction, child: Text(action!)),
        ]),
      );
}

/// Theme-aware status pill (core StatusChip works in both themes too, this adds an icon dot).
class StatusPill extends StatelessWidget {
  const StatusPill(this.status, {super.key, this.label});
  final String status;
  final String? label;
  @override
  Widget build(BuildContext context) {
    final c = statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: c.withValues(alpha: context.isDark ? .22 : .1), borderRadius: BorderRadius.circular(G4MRadius.pill)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label ?? OrderStatus.label(status), style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: 12)),
      ]),
    );
  }
}

/// Small pulsing dot (online indicator, new-order marker).
class PulseDot extends StatelessWidget {
  const PulseDot({super.key, this.color = G4MColors.success, this.size = 10});
  final Color color;
  final double size;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: size * 2.2,
        height: size * 2.2,
        child: Stack(alignment: Alignment.center, children: [
          Container(width: size, height: size, decoration: BoxDecoration(color: color.withValues(alpha: .35), shape: BoxShape.circle))
              .animate(onPlay: (c) => c.repeat())
              .scale(begin: const Offset(1, 1), end: const Offset(2.2, 2.2), duration: 1200.ms, curve: Curves.easeOut)
              .fadeOut(duration: 1200.ms),
          Container(width: size, height: size, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        ]),
      );
}

/// Avatar with network image fallback to initials.
class Avatar extends StatelessWidget {
  const Avatar({super.key, required this.name, this.url = '', this.size = 44});
  final String name;
  final String url;
  final double size;
  @override
  Widget build(BuildContext context) {
    final initials = name.trim().isEmpty
        ? '?'
        : name.trim().split(RegExp(r'\s+')).take(2).map((w) => w[0].toUpperCase()).join();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: context.rc.brandSoft),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: url.isEmpty
          ? Text(initials, style: TextStyle(fontWeight: FontWeight.w800, color: context.rc.brand, fontSize: size * .36))
          : NetImage(url, width: size, height: size),
    );
  }
}

/// Settings-style row.
class MenuTile extends StatelessWidget {
  const MenuTile({super.key, required this.icon, required this.title, this.subtitle, this.onTap, this.trailing, this.color});
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final c = color ?? context.rc.brand;
    return Pressable(
      onTap: onTap,
      scale: .985,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: c.withValues(alpha: .12), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: c, size: 21),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: context.tt.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              if (subtitle != null) Text(subtitle!, style: context.tt.bodySmall?.copyWith(color: context.rc.muted)),
            ]),
          ),
          trailing ?? Icon(Icons.chevron_right_rounded, color: context.rc.faint),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Swipe to confirm
// ---------------------------------------------------------------------------

/// Drag the thumb to the end to confirm. [onConfirm] may be async; while it runs
/// the thumb shows a spinner. If it throws or returns false, the slider springs back.
class SwipeToConfirm extends StatefulWidget {
  const SwipeToConfirm({super.key, required this.label, required this.onConfirm, this.color, this.icon = Icons.arrow_forward_rounded, this.enabled = true});
  final String label;
  final Future<bool> Function() onConfirm;
  final Color? color;
  final IconData icon;
  final bool enabled;
  @override
  State<SwipeToConfirm> createState() => _SwipeToConfirmState();
}

class _SwipeToConfirmState extends State<SwipeToConfirm> with TickerProviderStateMixin {
  double _drag = 0; // 0..1
  bool _busy = false;
  bool _done = false;
  late final _spring = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
  late final _shine = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))..repeat();
  double _springFrom = 0;
  int _lastTick = 0;

  @override
  void initState() {
    super.initState();
    _spring.addListener(() => setState(() => _drag = _springFrom * (1 - Curves.easeOutBack.transform(_spring.value)).clamp(0.0, 1.0)));
  }

  @override
  void dispose() {
    _spring.dispose();
    _shine.dispose();
    super.dispose();
  }

  void _reset() {
    _springFrom = _drag;
    _spring.forward(from: 0);
  }

  Future<void> _complete() async {
    HapticFeedback.heavyImpact();
    setState(() {
      _drag = 1;
      _busy = true;
    });
    var ok = false;
    try {
      ok = await widget.onConfirm();
    } catch (_) {
      ok = false;
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _done = ok;
    });
    if (!ok) {
      _reset();
    } else {
      // Ready for the next step after a beat (the parent usually rebuilds with a new label).
      Future.delayed(const Duration(milliseconds: 900), () {
        if (mounted) {
          setState(() {
            _done = false;
            _drag = 0;
          });
        }
      });
    }
  }

  @override
  void didUpdateWidget(SwipeToConfirm old) {
    super.didUpdateWidget(old);
    if (old.label != widget.label && !_busy) {
      _drag = 0;
      _done = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? context.rc.brand;
    const h = 62.0;
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth;
      final travel = w - h;
      return Opacity(
        opacity: widget.enabled ? 1 : .5,
        child: Container(
          height: h,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(h / 2),
            color: color.withValues(alpha: context.isDark ? .22 : .12),
            border: Border.all(color: color.withValues(alpha: .35)),
          ),
          child: Stack(children: [
            // Fill behind the thumb.
            Container(
              width: h + travel * _drag,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(h / 2),
                gradient: LinearGradient(colors: [color.withValues(alpha: .65), color]),
              ),
            ),
            // Shimmering label.
            Center(
              child: AnimatedBuilder(
                animation: _shine,
                builder: (_, _) => ShaderMask(
                  blendMode: BlendMode.srcIn,
                  shaderCallback: (r) => LinearGradient(
                    begin: Alignment(-1.8 + _shine.value * 3.6, 0),
                    end: Alignment(-0.8 + _shine.value * 3.6, 0),
                    colors: [color, context.rc.ink.withValues(alpha: .35), color],
                  ).createShader(r),
                  child: Padding(
                    padding: const EdgeInsets.only(left: h * .8, right: 16),
                    child: Text(
                      _done ? '✓' : widget.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: .2),
                    ),
                  ),
                ),
              ),
            ).animate(target: _drag > .1 ? 1 : 0).fade(begin: 1, end: 0.15),
            // Thumb.
            Positioned(
              left: travel * _drag,
              top: 0,
              bottom: 0,
              child: GestureDetector(
                onHorizontalDragUpdate: !widget.enabled || _busy
                    ? null
                    : (d) {
                        _spring.stop();
                        setState(() => _drag = (_drag + d.delta.dx / travel).clamp(0.0, 1.0));
                        final tick = (_drag * 10).floor();
                        if (tick != _lastTick) {
                          _lastTick = tick;
                          HapticFeedback.selectionClick();
                        }
                      },
                onHorizontalDragEnd: !widget.enabled || _busy
                    ? null
                    : (_) {
                        if (_drag > .86) {
                          _complete();
                        } else {
                          _reset();
                        }
                      },
                child: Container(
                  width: h,
                  height: h,
                  padding: const EdgeInsets.all(5),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: color.withValues(alpha: .35), blurRadius: 12, offset: const Offset(0, 4))],
                    ),
                    alignment: Alignment.center,
                    child: _busy
                        ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.6, color: color))
                        : Icon(_done ? Icons.check_rounded : widget.icon, color: color),
                  ),
                ),
              ),
            ),
          ]),
        ),
      );
    });
  }
}

// ---------------------------------------------------------------------------
// Success celebration
// ---------------------------------------------------------------------------

/// Full-screen celebratory overlay: drawn check, ring burst and confetti.
Future<void> showSuccess(BuildContext context, {required String title, String? subtitle, Color? color}) {
  HapticFeedback.heavyImpact();
  final c = color ?? context.rc.brand;
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'success',
    barrierColor: Colors.black45,
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (ctx, _, _) => _SuccessView(title: title, subtitle: subtitle, color: c),
    transitionBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
  );
}

class _SuccessView extends StatefulWidget {
  const _SuccessView({required this.title, this.subtitle, required this.color});
  final String title;
  final String? subtitle;
  final Color color;
  @override
  State<_SuccessView> createState() => _SuccessViewState();
}

class _SuccessViewState extends State<_SuccessView> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))..forward();
  Timer? _auto;

  @override
  void initState() {
    super.initState();
    _auto = Timer(const Duration(milliseconds: 3200), () {
      if (mounted) Navigator.of(context).maybePop();
    });
  }

  @override
  void dispose() {
    _auto?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Center(
        child: Material(
          color: Colors.transparent,
          child: AnimatedBuilder(
            animation: _c,
            builder: (_, _) => SizedBox(
              width: 320,
              height: 420,
              child: Stack(alignment: Alignment.center, children: [
                Positioned.fill(child: CustomPaint(painter: _ConfettiPainter(_c.value, widget.color))),
                Container(
                  width: 300,
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
                  decoration: BoxDecoration(color: context.rc.card, borderRadius: BorderRadius.circular(28), boxShadow: G4MShadows.lifted),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    SizedBox(width: 110, height: 110, child: CustomPaint(painter: _CheckPainter(_c.value, widget.color))),
                    const SizedBox(height: 18),
                    Opacity(
                      opacity: Interval(.35, .6).transform(_c.value),
                      child: Text(widget.title, textAlign: TextAlign.center, style: context.tt.headlineSmall),
                    ),
                    if (widget.subtitle != null) ...[
                      const SizedBox(height: 6),
                      Opacity(
                        opacity: Interval(.45, .7).transform(_c.value),
                        child: Text(widget.subtitle!, textAlign: TextAlign.center, style: context.tt.bodyMedium?.copyWith(color: context.rc.muted)),
                      ),
                    ],
                  ]),
                ).animate().scale(begin: const Offset(.7, .7), duration: 520.ms, curve: Curves.easeOutBack),
              ]),
            ),
          ),
        ),
      );
}

class _CheckPainter extends CustomPainter {
  _CheckPainter(this.t, this.color);
  final double t;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    // Burst ring.
    final burst = const Interval(.25, .6, curve: Curves.easeOut).transform(t);
    if (burst > 0 && burst < 1) {
      canvas.drawCircle(c, r * (0.8 + burst * .5), Paint()
        ..color = color.withValues(alpha: (1 - burst) * .35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6 * (1 - burst) + 1);
    }
    // Filled disc scaling in.
    final disc = const Interval(0, .3, curve: Curves.easeOutBack).transform(t);
    canvas.drawCircle(c, r * .78 * disc, Paint()..color = color);
    // Check stroke.
    final draw = const Interval(.22, .5, curve: Curves.easeOut).transform(t);
    if (draw > 0) {
      final p = Path()
        ..moveTo(c.dx - r * .32, c.dy + r * .02)
        ..lineTo(c.dx - r * .08, c.dy + r * .26)
        ..lineTo(c.dx + r * .36, c.dy - r * .22);
      final metric = p.computeMetrics().first;
      canvas.drawPath(
        metric.extractPath(0, metric.length * draw),
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 9
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  @override
  bool shouldRepaint(_CheckPainter o) => o.t != t;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.t, this.color);
  final double t;
  final Color color;
  static final _rnd = math.Random(7);
  static final _parts = List.generate(46, (i) => (
        angle: _rnd.nextDouble() * math.pi * 2,
        speed: .45 + _rnd.nextDouble() * .55,
        size: 4 + _rnd.nextDouble() * 6,
        spin: _rnd.nextDouble() * 8 - 4,
        kind: i % 3,
      ));

  @override
  void paint(Canvas canvas, Size size) {
    final p = const Interval(.25, 1, curve: Curves.easeOutCubic).transform(t);
    if (p <= 0) return;
    final c = Offset(size.width / 2, size.height / 2 - 60);
    final colors = [color, G4MColors.accent, G4MColors.primary, const Color(0xFFFFC94D)];
    for (var i = 0; i < _parts.length; i++) {
      final q = _parts[i];
      final dist = q.speed * 190 * p;
      final pos = c + Offset(math.cos(q.angle) * dist, math.sin(q.angle) * dist + 120 * p * p);
      final paint = Paint()..color = colors[i % colors.length].withValues(alpha: (1 - p).clamp(0.0, 1.0));
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(q.spin * p);
      switch (q.kind) {
        case 0:
          canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: q.size, height: q.size * .5), const Radius.circular(1.5)), paint);
        case 1:
          canvas.drawCircle(Offset.zero, q.size * .4, paint);
        default:
          canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: q.size * .35, height: q.size), paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter o) => o.t != t;
}

// ---------------------------------------------------------------------------
// Misc
// ---------------------------------------------------------------------------

/// Standard page padding wrapper with a sliver-friendly bottom inset.
const pagePad = EdgeInsets.fromLTRB(16, 8, 16, 32);

/// Section of a form with a label above.
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6, top: 14, left: 2),
        child: Text(text, style: context.tt.labelLarge?.copyWith(color: context.rc.muted)),
      );
}

/// Countdown text to [target]; turns red when overdue.
class CountdownText extends StatefulWidget {
  const CountdownText({super.key, required this.target, this.style});
  final DateTime target;
  final TextStyle? style;
  @override
  State<CountdownText> createState() => _CountdownTextState();
}

class _CountdownTextState extends State<CountdownText> {
  late Timer _t;
  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _t.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.target.difference(DateTime.now());
    final late = d.isNegative;
    final a = d.abs();
    final txt = '${late ? '-' : ''}${a.inMinutes.toString().padLeft(2, '0')}:${(a.inSeconds % 60).toString().padLeft(2, '0')}';
    return Text(txt,
        style: (widget.style ?? context.tt.titleLarge)?.copyWith(
          color: late ? G4MColors.danger : null,
          fontFeatures: const [FontFeature.tabularFigures()],
        ));
  }
}
