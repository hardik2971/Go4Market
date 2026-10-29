import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:g4m_core/g4m_core.dart';

import '../../core/motion.dart';
import '../auth/root_gate.dart';
import 'doodle_painter.dart';

/// Animated brand splash (~2.6 s), shown right after the native splash.
///
/// Timeline (fractions of the controller):
///   0.00-0.38  logo elastic scale-in        0.18-0.62  soft glow pulse
///   0.34-0.56  "Go4Market" wordmark reveal  0.50-0.68  "Partner" pill slides in
///   0.62-0.86  shimmer sweep across logo + wordmark
///   0.88-1.00  gentle zoom/fade, then crossfade into the app.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));

  late final _logoScale = CurvedAnimation(parent: _c, curve: const Interval(0, .38, curve: Curves.elasticOut));
  late final _logoFade = CurvedAnimation(parent: _c, curve: const Interval(0, .1, curve: Curves.easeOut));
  late final _glow = CurvedAnimation(parent: _c, curve: const Interval(.18, .62));
  late final _word = CurvedAnimation(parent: _c, curve: const Interval(.34, .56, curve: Curves.easeOutCubic));
  late final _pill = CurvedAnimation(parent: _c, curve: const Interval(.5, .68, curve: Curves.easeOutBack));
  late final _shimmer = CurvedAnimation(parent: _c, curve: const Interval(.62, .86, curve: Curves.easeInOut));
  late final _exit = CurvedAnimation(parent: _c, curve: const Interval(.88, 1, curve: Curves.easeInCubic));
  late final _bg = CurvedAnimation(parent: _c, curve: const Interval(0, .3, curve: Curves.easeOut));

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent));
    _c.forward().whenComplete(() {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(Go.fadeRoute(const RootGate()));
    });
    // A light tap of haptics when the logo lands.
    Future.delayed(const Duration(milliseconds: 320), () => HapticFeedback.lightImpact());
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The splash is always light so it matches the native splash exactly.
    return Scaffold(
      backgroundColor: G4MColors.background,
      body: Stack(fit: StackFit.expand, children: [
        FadeTransition(opacity: _bg, child: const DoodleBackground(color: G4MColors.primary, opacity: .07)),
        // Soft vignette so the centre reads cleanly over the doodle.
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              radius: .75,
              colors: [G4MColors.background, Color(0x00F7FAF8)],
              stops: [.25, 1],
            ),
          ),
        ),
        Center(
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final exit = _exit.value;
              return Opacity(
                opacity: 1 - exit,
                child: Transform.scale(
                  scale: 1 + exit * .08,
                  child: _ShimmerSweep(
                    progress: _shimmer.value,
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      _logo(),
                      const SizedBox(height: 22),
                      _wordmark(),
                      const SizedBox(height: 14),
                      _partnerPill(),
                    ]),
                  ),
                ),
              );
            },
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 40,
          child: SafeArea(
            child: FadeTransition(
              opacity: _pill,
              child: const Text(
                'Sell · Deliver · Grow',
                textAlign: TextAlign.center,
                style: TextStyle(color: G4MColors.inkMuted, fontWeight: FontWeight.w600, letterSpacing: 1.2, fontSize: 12),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _logo() {
    final g = _glow.value;
    // Pulse: rises then settles (sin over the interval).
    final pulse = g == 0 ? 0.0 : (g < .5 ? g * 2 : (1 - g) * 2);
    return SizedBox(
      width: 200,
      height: 200,
      child: Stack(alignment: Alignment.center, children: [
        Container(
          width: 150 + 60 * pulse,
          height: 150 + 60 * pulse,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [
              G4MColors.primary.withValues(alpha: .22 * pulse + .04 * g),
              G4MColors.accent.withValues(alpha: .08 * pulse),
              G4MColors.primary.withValues(alpha: 0),
            ], stops: const [0, .55, 1]),
          ),
        ),
        Opacity(
          opacity: _logoFade.value,
          child: Transform.scale(
            scale: _logoScale.value,
            child: Image.asset('assets/branding/logo.png', width: 132, height: 132, filterQuality: FilterQuality.high),
          ),
        ),
      ]),
    );
  }

  Widget _wordmark() {
    final w = _word.value;
    return Opacity(
      opacity: w,
      child: ClipRect(
        child: Align(
          alignment: Alignment.centerLeft,
          widthFactor: w.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(-12 * (1 - w), 0),
            child: const G4MWordmark(size: 54, showMark: false),
          ),
        ),
      ),
    );
  }

  Widget _partnerPill() {
    final p = _pill.value;
    return Opacity(
      opacity: p.clamp(0.0, 1.0),
      child: Transform.translate(
        offset: Offset(0, 18 * (1 - p)),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            gradient: G4MColors.accentGradient,
            borderRadius: BorderRadius.circular(G4MRadius.pill),
            boxShadow: G4MShadows.glowAccent,
          ),
          child: const Text(
            'PARTNER',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 3, fontSize: 13),
          ),
        ),
      ),
    );
  }
}

/// Paints a diagonal white highlight band across [child] at [progress] 0..1.
class _ShimmerSweep extends StatelessWidget {
  const _ShimmerSweep({required this.progress, required this.child});
  final double progress;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    if (progress <= 0 || progress >= 1) return child;
    return ShaderMask(
      blendMode: BlendMode.srcATop,
      shaderCallback: (rect) {
        final x = -1.6 + progress * 3.2;
        return LinearGradient(
          begin: Alignment(x - .5, -.6),
          end: Alignment(x + .5, .6),
          colors: [
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: .65),
            Colors.white.withValues(alpha: 0),
          ],
          stops: const [.35, .5, .65],
        ).createShader(rect);
      },
      child: child,
    );
  }
}
