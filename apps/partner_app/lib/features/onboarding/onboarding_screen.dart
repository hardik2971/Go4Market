import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:g4m_core/g4m_core.dart';

import '../../core/app_state.dart';
import '../../core/l10n.dart';
import '../../core/motion.dart';
import '../../core/partner_theme.dart';
import '../auth/root_gate.dart';
import '../splash/doodle_painter.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _Slide {
  const _Slide(this.icon, this.satellites, this.color, this.title, this.body);
  final IconData icon;
  final List<IconData> satellites;
  final Color color;
  final (String, String) title;
  final (String, String) body;
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pc = PageController();
  double _page = 0;

  static const _slides = [
    _Slide(
      Icons.storefront_rounded,
      [Icons.inventory_2_rounded, Icons.qr_code_scanner_rounded, Icons.insights_rounded],
      G4MColors.primary,
      ('Run your store from your pocket', 'अपनी दुकान जेब से चलाएं'),
      ('Manage products, stock and orders across eCommerce, Grocery, Pharmacy and Food — with POS built in.',
          'ई-कॉमर्स, ग्रॉसरी, फ़ार्मेसी और फ़ूड में उत्पाद, स्टॉक और ऑर्डर संभालें — POS के साथ।'),
    ),
    _Slide(
      Icons.delivery_dining_rounded,
      [Icons.location_on_rounded, Icons.timer_rounded, Icons.payments_rounded],
      G4MColors.accent,
      ('Deliver and earn on your schedule', 'अपने समय पर डिलीवरी करें और कमाएं'),
      ('Go online, accept nearby orders, navigate with live maps and get paid for every drop.',
          'ऑनलाइन जाएं, नज़दीकी ऑर्डर लें, लाइव मैप से नेविगेट करें और हर डिलीवरी पर कमाएं।'),
    ),
    _Slide(
      Icons.account_balance_wallet_rounded,
      [Icons.trending_up_rounded, Icons.notifications_active_rounded, Icons.verified_rounded],
      G4MColors.primaryDeep,
      ('Track earnings, withdraw anytime', 'कमाई देखें, कभी भी निकालें'),
      ('Real-time dashboards, instant order alerts and quick withdrawals to your bank or UPI.',
          'रियल-टाइम डैशबोर्ड, तुरंत ऑर्डर अलर्ट और बैंक या UPI में जल्दी निकासी।'),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pc.addListener(() => setState(() => _page = _pc.page ?? 0));
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  void _finish() {
    AppState.instance.setOnboardingSeen();
    Go.root(context, const RootGate());
  }

  @override
  Widget build(BuildContext context) {
    final idx = _page.round();
    final last = idx == _slides.length - 1;
    final color = Color.lerp(_slides[_page.floor()].color, _slides[(_page.ceil()).clamp(0, _slides.length - 1)].color, _page - _page.floor())!;
    return Scaffold(
      body: Stack(children: [
        Positioned.fill(child: DoodleBackground(color: color, opacity: .05, period: const Duration(seconds: 40))),
        SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
              child: Row(children: [
                const G4MWordmark(size: 30),
                const Spacer(),
                AnimatedOpacity(
                  opacity: last ? 0 : 1,
                  duration: G4MMotion.standard,
                  child: TextButton(onPressed: last ? null : _finish, child: Text(context.s.skip)),
                ),
              ]),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pc,
                itemCount: _slides.length,
                itemBuilder: (context, i) {
                  final s = _slides[i];
                  final delta = (_page - i).clamp(-1.0, 1.0);
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Transform.translate(
                        offset: Offset(delta * -80, 0),
                        child: Opacity(opacity: (1 - delta.abs()).clamp(0.0, 1.0), child: _Illustration(slide: s)),
                      ),
                      const SizedBox(height: 44),
                      Transform.translate(
                        offset: Offset(delta * -40, 0),
                        child: Text(context.tr(s.title.$1, s.title.$2),
                            textAlign: TextAlign.center, style: context.tt.headlineMedium?.copyWith(height: 1.15)),
                      ),
                      const SizedBox(height: 14),
                      Transform.translate(
                        offset: Offset(delta * -20, 0),
                        child: Text(context.tr(s.body.$1, s.body.$2),
                            textAlign: TextAlign.center, style: context.tt.bodyLarge?.copyWith(color: context.rc.muted, height: 1.5)),
                      ),
                    ]),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Row(children: [
                Row(children: [
                  for (var i = 0; i < _slides.length; i++)
                    AnimatedContainer(
                      duration: G4MMotion.standard,
                      curve: G4MMotion.curve,
                      margin: const EdgeInsets.only(right: 6),
                      width: idx == i ? 26 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: idx == i ? color : context.rc.line,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                ]),
                const Spacer(),
                AnimatedContainer(
                  duration: G4MMotion.emphasized,
                  curve: G4MMotion.curve,
                  width: last ? 168 : 60,
                  height: 60,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      padding: EdgeInsets.zero,
                      backgroundColor: color,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                    onPressed: () => last
                        ? _finish()
                        : _pc.nextPage(duration: G4MMotion.emphasized, curve: G4MMotion.curve),
                    child: AnimatedSwitcher(
                      duration: G4MMotion.standard,
                      child: last
                          ? Text(context.tr('Get started', 'शुरू करें'), key: const ValueKey('go'), maxLines: 1)
                          : const Icon(Icons.arrow_forward_rounded, key: ValueKey('next')),
                    ),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }
}

/// Centre icon in a soft halo with three orbiting satellite badges.
class _Illustration extends StatelessWidget {
  const _Illustration({required this.slide});
  final _Slide slide;
  @override
  Widget build(BuildContext context) {
    final c = slide.color;
    const positions = [Alignment(-.95, -.55), Alignment(.95, -.35), Alignment(.55, .95)];
    return SizedBox(
      width: 260,
      height: 260,
      child: Stack(children: [
        Center(
          child: Container(
            width: 230,
            height: 230,
            decoration: BoxDecoration(shape: BoxShape.circle, color: c.withValues(alpha: .07)),
          ).animate(onPlay: (a) => a.repeat(reverse: true)).scale(begin: const Offset(.94, .94), end: const Offset(1.03, 1.03), duration: 2400.ms, curve: Curves.easeInOut),
        ),
        Center(
          child: Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [c.withValues(alpha: .85), c]),
              boxShadow: [BoxShadow(color: c.withValues(alpha: .35), blurRadius: 36, offset: const Offset(0, 16))],
            ),
            child: Icon(slide.icon, color: Colors.white, size: 72),
          ).animate().scale(begin: const Offset(.6, .6), duration: 700.ms, curve: Curves.elasticOut),
        ),
        for (var i = 0; i < 3; i++)
          Align(
            alignment: positions[i],
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: context.rc.card,
                borderRadius: BorderRadius.circular(18),
                boxShadow: G4MShadows.lifted,
              ),
              child: Icon(slide.satellites[i], color: i == 1 ? G4MColors.accent : G4MColors.primary),
            )
                .animate(delay: (200 + i * 120).ms)
                .fadeIn()
                .scale(begin: const Offset(.5, .5), curve: Curves.easeOutBack, duration: 500.ms)
                .then()
                .animate(onPlay: (a) => a.repeat(reverse: true))
                .moveY(begin: 0, end: i.isEven ? -8 : 8, duration: (1800 + i * 300).ms, curve: Curves.easeInOut),
          ),
      ]),
    );
  }
}
