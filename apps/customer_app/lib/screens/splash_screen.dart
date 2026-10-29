import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:g4m_core/g4m_core.dart';

import '../core/data.dart';
import '../core/nav.dart';
import '../core/prefs.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../widgets/doodle.dart';
import 'auth/auth_screens.dart';
import 'onboarding_screen.dart';
import 'shell/main_shell.dart';

/// Animated brand splash: elastic logo, glow pulse, letter-by-letter wordmark, shimmer sweep.
/// Firebase boots in parallel; the user can tap to skip once it is ready.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2500));
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
  bool _ready = false;
  bool _left = false;
  Object? _error;

  static const _word = 'Go4Market';

  @override
  void initState() {
    super.initState();
    _c.forward();
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed) _go();
    });
    Future.delayed(const Duration(milliseconds: 650), () {
      if (mounted) _pulse.repeat(reverse: true);
    });
    _boot();
  }

  Future<void> _boot() async {
    setState(() => _error = null);
    try {
      if (Firebase.apps.isEmpty) await initG4MFirebase(G4MClient.customerApp);
      Session.instance.start();
      AppConfig.start();
      // Wait for the persisted auth session to restore (fast, local).
      await FirebaseAuth.instance.authStateChanges().first.timeout(const Duration(seconds: 4), onTimeout: () => null);
      _ready = true;
      if (_c.isCompleted) _go();
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  void _go() {
    if (!_ready || _left || !mounted) return;
    _left = true;
    final prefs = AppPrefs.instance;
    final Widget next;
    if (!prefs.onboardingSeen) {
      next = const OnboardingScreen();
    } else if (FirebaseAuth.instance.currentUser == null) {
      next = const LoginScreen(root: true);
    } else {
      next = const MainShell();
    }
    context.replaceAll(next, style: RouteStyle.fadeThrough);
  }

  @override
  void dispose() {
    _c.dispose();
    _pulse.dispose();
    super.dispose();
  }

  double _iv(double begin, double end, [Curve curve = Curves.easeOutCubic]) =>
      curve.transform(((_c.value - begin) / (end - begin)).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final deep = dark ? const Color(0xFFE8F1EC) : G4MColors.primaryDeep;
    final green = dark ? const Color(0xFF5FD39A) : G4MColors.primary;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _go,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: dark ? const [Color(0xFF0B1410), Color(0xFF0F1D16)] : const [Colors.white, Color(0xFFEAF7EF)],
              ),
            ),
            child: DoodleBackground(
              opacity: dark ? .06 : .075,
              color: dark ? const Color(0xFF5FD39A) : G4MColors.primary,
              child: AnimatedBuilder(
                animation: Listenable.merge([_c, _pulse]),
                builder: (context, _) {
                  final logoT = _iv(0, .42, Curves.elasticOut);
                  final glowT = _iv(.15, .45) * (.75 + .25 * _pulse.value);
                  final shimmer = _iv(.74, .96, Curves.easeInOut);
                  final tagT = _iv(.70, .92);
                  return Stack(children: [
                    Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        SizedBox(
                          width: 240,
                          height: 220,
                          child: Stack(alignment: Alignment.center, children: [
                            CustomPaint(size: const Size(240, 240), painter: GlowPainter(glowT, G4MColors.primary)),
                            Transform.scale(
                              scale: .2 + .8 * logoT,
                              child: Opacity(
                                opacity: _iv(0, .12),
                                child: Image.asset('assets/brand/logo.png', width: 132, height: 132, filterQuality: FilterQuality.medium),
                              ),
                            ),
                          ]),
                        ),
                        const SizedBox(height: 4),
                        ShaderMask(
                          blendMode: BlendMode.srcATop,
                          shaderCallback: (r) => LinearGradient(
                            begin: Alignment(-1.6 + shimmer * 3.2, -.2),
                            end: Alignment(-.8 + shimmer * 3.2, .2),
                            colors: [
                              Colors.white.withValues(alpha: 0),
                              Colors.white.withValues(alpha: shimmer > 0 && shimmer < 1 ? .75 : 0),
                              Colors.white.withValues(alpha: 0),
                            ],
                          ).createShader(r),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            for (var i = 0; i < _word.length; i++) _letter(i, deep, green),
                          ]),
                        ),
                        const SizedBox(height: 10),
                        Opacity(
                          opacity: tagT,
                          child: Transform.translate(
                            offset: Offset(0, 8 * (1 - tagT)),
                            child: Text(
                              'Everything you need, delivered fast',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                letterSpacing: .2,
                                color: dark ? const Color(0xFF9DB0A5) : G4MColors.inkMuted,
                              ),
                            ),
                          ),
                        ),
                      ]),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 48 + MediaQuery.paddingOf(context).bottom,
                      child: Center(
                        child: AnimatedSwitcher(
                          duration: G4MMotion.standard,
                          child: _error != null
                              ? Column(key: const ValueKey('err'), mainAxisSize: MainAxisSize.min, children: [
                                  Text('Could not start. Check your connection.', style: TextStyle(color: context.muted)),
                                  TextButton(onPressed: _boot, child: const Text('Retry')),
                                ])
                              : (_c.isCompleted && !_ready)
                                  ? const SizedBox(key: ValueKey('wait'), width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4))
                                  : const SizedBox(key: ValueKey('none'), height: 22),
                        ),
                      ),
                    ),
                  ]);
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _letter(int i, Color deep, Color green) {
    final start = .38 + i * .035;
    final t = _iv(start, start + .14, Curves.easeOutBack);
    final ch = _word[i];
    final color = i < 2 ? deep : (i == 2 ? G4MColors.accent : green);
    return Opacity(
      opacity: t.clamp(0.0, 1.0),
      child: Transform.translate(
        offset: Offset(0, 14 * (1 - t)),
        child: Transform.scale(
          scale: .7 + .3 * t,
          child: Text(ch,
              style: TextStyle(fontSize: 38, fontWeight: FontWeight.w800, letterSpacing: -1, height: 1.1, color: color)),
        ),
      ),
    );
  }
}
