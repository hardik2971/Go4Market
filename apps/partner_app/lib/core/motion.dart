import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:g4m_core/g4m_core.dart';

/// Premium shared-axis style transition: the incoming page slides up a touch,
/// scales from 0.96 and fades in; the outgoing page recedes and dims slightly.
class G4MPageTransitionsBuilder extends PageTransitionsBuilder {
  const G4MPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(PageRoute<T> route, BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    return _G4MTransition(animation: animation, secondary: secondaryAnimation, child: child);
  }
}

class _G4MTransition extends StatelessWidget {
  const _G4MTransition({required this.animation, required this.secondary, required this.child});
  final Animation<double> animation, secondary;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final inCurve = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
    final outCurve = CurvedAnimation(parent: secondary, curve: Curves.easeOutCubic);
    return AnimatedBuilder(
      animation: Listenable.merge([inCurve, outCurve]),
      child: child,
      builder: (context, child) {
        final t = inCurve.value;
        final s = outCurve.value;
        return Opacity(
          opacity: (t.clamp(0.0, 1.0) * (1 - s * .35)).clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 28),
            child: Transform.scale(scale: (0.96 + t * .04) * (1 - s * .03), child: child),
          ),
        );
      },
    );
  }
}

/// Navigation helpers so every push gets the same premium transition.
abstract final class Go {
  static Route<T> route<T>(Widget page, {bool fullscreenDialog = false}) => PageRouteBuilder<T>(
        fullscreenDialog: fullscreenDialog,
        transitionDuration: G4MMotion.emphasized,
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (_, _, _) => page,
        transitionsBuilder: (c, a, s, child) => _G4MTransition(animation: a, secondary: s, child: child),
      );

  static Future<T?> push<T>(BuildContext context, Widget page) => Navigator.of(context).push<T>(route<T>(page));

  static Future<T?> replace<T>(BuildContext context, Widget page) =>
      Navigator.of(context).pushReplacement<T, void>(route<T>(page));

  static Future<T?> root<T>(BuildContext context, Widget page) =>
      Navigator.of(context).pushAndRemoveUntil<T>(fadeRoute<T>(page), (_) => false);

  /// Crossfade + gentle zoom, used for root swaps (splash -> app, role gate).
  static Route<T> fadeRoute<T>(Widget page) => PageRouteBuilder<T>(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (_, _, _) => page,
        transitionsBuilder: (c, a, s, child) => FadeTransition(
          opacity: CurvedAnimation(parent: a, curve: Curves.easeOut),
          child: ScaleTransition(
            scale: Tween(begin: 1.04, end: 1.0).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
            child: child,
          ),
        ),
      );
}

extension StaggerX on Widget {
  /// Staggered list entrance: fade + rise, delayed by index (capped so long lists don't lag).
  Widget stagger(int index, {int stepMs = 45, double rise = .12}) => animate(delay: (index.clamp(0, 12) * stepMs).ms)
      .fadeIn(duration: 380.ms, curve: Curves.easeOutCubic)
      .slideY(begin: rise, end: 0, duration: 420.ms, curve: Curves.easeOutCubic);

  /// Gentle pop-in for hero cards and stats.
  Widget popIn({int delayMs = 0}) => animate(delay: delayMs.ms)
      .fadeIn(duration: 300.ms)
      .scale(begin: const Offset(.94, .94), end: const Offset(1, 1), duration: 480.ms, curve: Curves.easeOutBack);
}
