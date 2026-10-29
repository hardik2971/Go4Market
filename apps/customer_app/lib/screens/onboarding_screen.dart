import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:g4m_core/g4m_core.dart';

import '../core/nav.dart';
import '../core/prefs.dart';
import '../core/theme.dart';
import '../l10n/app_localizations.dart';
import '../widgets/doodle.dart';
import 'auth/auth_screens.dart';
import 'shell/main_shell.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> with SingleTickerProviderStateMixin {
  final _pc = PageController();
  late final _float = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);
  double _page = 0;

  @override
  void initState() {
    super.initState();
    _pc.addListener(() => setState(() => _page = _pc.page ?? 0));
  }

  @override
  void dispose() {
    _pc.dispose();
    _float.dispose();
    super.dispose();
  }

  void _done() {
    AppPrefs.instance.setOnboardingSeen();
    context.replaceAll(FirebaseAuth.instance.currentUser == null ? const LoginScreen(root: true) : const MainShell());
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final slides = [
      (l.onb1Title, l.onb1Body, Icons.storefront_rounded, [Icons.local_grocery_store_rounded, Icons.medication_rounded, Icons.restaurant_rounded, Icons.devices_rounded], G4MColors.primary),
      (l.onb2Title, l.onb2Body, Icons.electric_moped_rounded, [Icons.timer_rounded, Icons.bolt_rounded, Icons.schedule_rounded, Icons.home_rounded], G4MColors.accent),
      (l.onb3Title, l.onb3Body, Icons.map_rounded, [Icons.location_on_rounded, Icons.account_balance_wallet_rounded, Icons.credit_card_rounded, Icons.verified_rounded], const Color(0xFF2563EB)),
    ];
    final last = _page.round() == slides.length - 1;
    return Scaffold(
      body: DoodleBackground(
        opacity: .045,
        drift: false,
        child: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
              child: Row(children: [
                G4MWordmark(size: 30, light: context.isDark),
                const Spacer(),
                AnimatedOpacity(
                  opacity: last ? 0 : 1,
                  duration: G4MMotion.standard,
                  child: TextButton(onPressed: last ? null : _done, child: Text(l.skip)),
                ),
              ]),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pc,
                itemCount: slides.length,
                itemBuilder: (_, i) {
                  final s = slides[i];
                  final delta = (_page - i).clamp(-1.0, 1.0);
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(children: [
                      const Spacer(),
                      Transform.translate(
                        offset: Offset(delta * -80, 0),
                        child: Opacity(
                          opacity: (1 - delta.abs()).clamp(0, 1),
                          child: _Illustration(main: s.$3, orbit: s.$4, color: s.$5, float: _float),
                        ),
                      ),
                      const Spacer(),
                      Transform.translate(
                        offset: Offset(delta * -40, 0),
                        child: Opacity(
                          opacity: (1 - delta.abs() * 1.4).clamp(0, 1),
                          child: Column(children: [
                            Text(s.$1, textAlign: TextAlign.center, style: context.text.headlineMedium),
                            const SizedBox(height: 12),
                            Text(s.$2, textAlign: TextAlign.center, style: context.text.bodyLarge?.copyWith(color: context.muted, height: 1.5)),
                          ]),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ]),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Row(children: [
                Row(children: [
                  for (var i = 0; i < slides.length; i++)
                    AnimatedContainer(
                      duration: G4MMotion.standard,
                      curve: G4MMotion.curve,
                      margin: const EdgeInsets.only(right: 6),
                      height: 8,
                      width: (_page - i).abs() < .5 ? 26 : 8,
                      decoration: BoxDecoration(
                        color: (_page - i).abs() < .5 ? G4MColors.primary : context.line,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                ]),
                const Spacer(),
                AnimatedContainer(
                  duration: G4MMotion.emphasized,
                  curve: G4MMotion.curve,
                  width: last ? 168 : 60,
                  height: 56,
                  child: FilledButton(
                    style: FilledButton.styleFrom(padding: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
                    onPressed: () => last ? _done() : _pc.nextPage(duration: G4MMotion.emphasized, curve: G4MMotion.curve),
                    child: AnimatedSwitcher(
                      duration: G4MMotion.standard,
                      child: last
                          ? Text(l.getStarted, key: const ValueKey('go'), maxLines: 1)
                          : const Icon(Icons.arrow_forward_rounded, key: ValueKey('next')),
                    ),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Illustration extends StatelessWidget {
  const _Illustration({required this.main, required this.orbit, required this.color, required this.float});
  final IconData main;
  final List<IconData> orbit;
  final Color color;
  final Animation<double> float;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: 280,
        height: 280,
        child: AnimatedBuilder(
          animation: float,
          builder: (_, _) {
            final f = Curves.easeInOut.transform(float.value);
            return Stack(alignment: Alignment.center, children: [
              Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: .08)),
              ),
              Container(
                width: 170,
                height: 170,
                decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: .12)),
              ),
              Transform.translate(
                offset: Offset(0, -6 + 12 * f),
                child: Container(
                  width: 112,
                  height: 112,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [BoxShadow(color: color.withValues(alpha: .35), blurRadius: 30, offset: const Offset(0, 14))],
                  ),
                  child: Icon(main, size: 56, color: Colors.white),
                ),
              ),
              for (var i = 0; i < orbit.length; i++)
                Transform.translate(
                  offset: Offset.fromDirection(i * math.pi / 2 - math.pi / 4 + f * .25, 102 + 4 * math.sin(f * math.pi + i)),
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: context.card,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: G4MShadows.soft,
                    ),
                    child: Icon(orbit[i], color: color, size: 24),
                  ),
                ),
            ]);
          },
        ),
      );
}
