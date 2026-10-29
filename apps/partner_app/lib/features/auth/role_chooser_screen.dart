import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:g4m_core/g4m_core.dart';

import '../../core/app_state.dart';
import '../../core/l10n.dart';
import '../../core/motion.dart';
import '../../core/partner_theme.dart';
import '../../core/session.dart';
import '../delivery/delivery_registration_screen.dart';
import '../seller/seller_registration_screen.dart';

/// Shown to signed-in users without a partner claim: pick Sell or Deliver,
/// then run that role's registration wizard.
class RoleChooserScreen extends StatefulWidget {
  const RoleChooserScreen({super.key});
  @override
  State<RoleChooserScreen> createState() => _RoleChooserScreenState();
}

class _RoleChooserScreenState extends State<RoleChooserScreen> {
  late PartnerRole _pick = AppState.instance.roleTint;

  void _continue() {
    AppState.instance.setRoleTint(_pick);
    Go.push(context, _pick == PartnerRole.seller ? const SellerRegistrationScreen() : const DeliveryRegistrationScreen());
  }

  @override
  Widget build(BuildContext context) {
    final name = Session.instance.user?.displayName ?? '';
    return Scaffold(
      appBar: AppBar(
        actions: [
          TextButton.icon(
            onPressed: () => Session.instance.signOut(),
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: Text(context.s.logout),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(
              name.isEmpty ? context.tr('How will you partner with us?', 'आप हमारे साथ कैसे जुड़ेंगे?') : '${context.tr('Hi', 'नमस्ते')} ${name.split(' ').first} 👋',
              style: context.tt.headlineMedium,
            ).animate().fadeIn().slideY(begin: .2),
            const SizedBox(height: 6),
            Text(
              context.tr('Choose how you want to work with Go4Market. You can only hold one partner role per account.',
                  'चुनें कि आप Go4Market के साथ कैसे काम करना चाहते हैं। एक खाते में एक ही भूमिका होती है।'),
              style: context.tt.bodyMedium?.copyWith(color: context.rc.muted),
            ).animate().fadeIn(delay: 80.ms),
            const SizedBox(height: 24),
            _RoleCard(
              selected: _pick == PartnerRole.seller,
              gradient: G4MColors.heroGradient,
              color: G4MColors.primary,
              icon: Icons.storefront_rounded,
              title: context.s.sellOn,
              points: [
                context.tr('List products across 4 modules', '4 मॉड्यूल में उत्पाद सूचीबद्ध करें'),
                context.tr('Orders, POS and stock in one app', 'ऑर्डर, POS और स्टॉक एक ऐप में'),
                context.tr('Weekly payouts to your bank', 'बैंक में साप्ताहिक भुगतान'),
              ],
              onTap: () => setState(() => _pick = PartnerRole.seller),
            ).stagger(1),
            const SizedBox(height: 14),
            _RoleCard(
              selected: _pick == PartnerRole.delivery,
              gradient: G4MColors.accentGradient,
              color: G4MColors.accent,
              icon: Icons.delivery_dining_rounded,
              title: context.s.deliverWith,
              points: [
                context.tr('Choose when you go online', 'खुद तय करें कब ऑनलाइन जाना है'),
                context.tr('Nearby orders with live navigation', 'लाइव नेविगेशन के साथ नज़दीकी ऑर्डर'),
                context.tr('Earn per delivery, withdraw anytime', 'हर डिलीवरी पर कमाएं, कभी भी निकालें'),
              ],
              onTap: () => setState(() => _pick = PartnerRole.delivery),
            ).stagger(2),
            const Spacer(),
            SizedBox(
              height: 56,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: _pick == PartnerRole.seller ? G4MColors.primary : G4MColors.primaryDeep),
                onPressed: _continue,
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(context.s.continueBtn),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_rounded),
                ]),
              ),
            ).stagger(3),
          ]),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.selected,
    required this.gradient,
    required this.color,
    required this.icon,
    required this.title,
    required this.points,
    required this.onTap,
  });
  final bool selected;
  final Gradient gradient;
  final Color color;
  final IconData icon;
  final String title;
  final List<String> points;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: G4MMotion.emphasized,
        curve: G4MMotion.curve,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: context.rc.card,
          borderRadius: BorderRadius.circular(G4MRadius.lg),
          border: Border.all(color: selected ? color : context.rc.line, width: selected ? 2 : 1),
          boxShadow: selected ? [BoxShadow(color: color.withValues(alpha: .22), blurRadius: 24, offset: const Offset(0, 10))] : null,
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          AnimatedScale(
            scale: selected ? 1.06 : 1,
            duration: G4MMotion.emphasized,
            curve: Curves.easeOutBack,
            child: Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(gradient: gradient, borderRadius: BorderRadius.circular(18)),
              child: Icon(icon, color: Colors.white, size: 30),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(title, style: context.tt.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
                AnimatedSwitcher(
                  duration: G4MMotion.standard,
                  transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                  child: Icon(
                    selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                    key: ValueKey(selected),
                    color: selected ? color : context.rc.faint,
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              for (final p in points)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(children: [
                    Icon(Icons.check_rounded, size: 16, color: color),
                    const SizedBox(width: 6),
                    Expanded(child: Text(p, style: context.tt.bodySmall?.copyWith(color: context.rc.muted))),
                  ]),
                ),
            ]),
          ),
        ]),
      ),
    );
  }
}
