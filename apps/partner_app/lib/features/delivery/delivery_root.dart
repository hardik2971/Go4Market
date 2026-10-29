import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:g4m_core/g4m_core.dart';

import '../../core/l10n.dart';
import '../../core/live.dart';
import '../../core/motion.dart';
import '../../core/partner_theme.dart';
import '../../core/session.dart';
import '../../core/ui.dart';
import '../auth/root_gate.dart';
import '../common/help_screen.dart';
import 'active_delivery_screen.dart';
import 'delivery_data.dart';
import 'delivery_registration_screen.dart';
import 'delivery_shell.dart';

/// Streams `deliveryPartners/{uid}`: missing -> registration wizard,
/// not approved -> live pending screen, approved -> [DeliveryShell].
class DeliveryRoot extends StatelessWidget {
  const DeliveryRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DeliveryPartner?>(
      stream: DeliveryData.me(),
      builder: (context, snap) {
        Widget child;
        if (snap.hasError) {
          child = Scaffold(key: const ValueKey('err'), body: ErrorView(snap.error!, onRetry: () => Go.root(context, const RootGate())));
        } else if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          child = const Scaffold(key: ValueKey('load'), body: Center(child: CircularProgressIndicator()));
        } else if (snap.data == null) {
          child = const DeliveryRegistrationScreen(key: ValueKey('reg'));
        } else if (snap.data!.status != 'approved') {
          child = DeliveryPendingScreen(key: const ValueKey('pending'), partner: snap.data!);
        } else {
          child = const DeliveryShell(key: ValueKey('shell'));
        }
        return AnimatedSwitcher(duration: const Duration(milliseconds: 450), child: child);
      },
    );
  }
}

/// Deep-link entry points used by push notifications and the inbox.
abstract final class DeliveryNav {
  /// Opens the live delivery screen; it shows actions only when the order is
  /// assigned to me and still active, otherwise a read-only detail.
  static Future<void> openOrder(BuildContext context, String orderId) async {
    await Go.push(context, ActiveDeliveryScreen(orderId: orderId));
  }
}

class DeliveryPendingScreen extends StatelessWidget {
  const DeliveryPendingScreen({super.key, required this.partner});
  final DeliveryPartner partner;

  @override
  Widget build(BuildContext context) {
    final s = partner.status;
    final rejected = s == 'rejected' || s == 'suspended';
    final color = rejected ? G4MColors.danger : G4MColors.accent;
    final steps = [
      (context.tr('Application submitted', 'आवेदन जमा हुआ'), true),
      (context.tr('Document & identity check', 'दस्तावेज़ और पहचान जांच'), !rejected && s != 'pending'),
      (context.tr('Account activated', 'खाता सक्रिय'), false),
    ];
    return Scaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(24, 32, 24, 24), children: [
          Center(
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(color: color.withValues(alpha: .12), shape: BoxShape.circle),
              child: Icon(rejected ? Icons.block_rounded : Icons.hourglass_top_rounded, size: 54, color: color),
            )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scale(begin: const Offset(1, 1), end: const Offset(1.06, 1.06), duration: 1400.ms, curve: Curves.easeInOut),
          ),
          const SizedBox(height: 28),
          Text(
            rejected
                ? (s == 'suspended' ? context.tr('Account suspended', 'खाता निलंबित') : context.tr('Application not approved', 'आवेदन स्वीकृत नहीं'))
                : context.s.pendingApproval,
            textAlign: TextAlign.center,
            style: context.tt.headlineSmall,
          ).animate().fadeIn(delay: 150.ms).slideY(begin: .2),
          const SizedBox(height: 8),
          Text(
            rejected
                ? context.tr('Please contact support to know more or to re-apply.', 'अधिक जानकारी या पुनः आवेदन के लिए सहायता से संपर्क करें।')
                : context.tr('Thanks, ${partner.name.isEmpty ? 'partner' : partner.name}! Our team is verifying your details. This screen updates automatically once you are approved.',
                    'धन्यवाद, ${partner.name}! हमारी टीम आपके विवरण की जांच कर रही है। स्वीकृत होते ही यह स्क्रीन अपने आप अपडेट होगी।'),
            textAlign: TextAlign.center,
            style: context.tt.bodyMedium?.copyWith(color: context.rc.muted, height: 1.5),
          ).animate().fadeIn(delay: 250.ms),
          const SizedBox(height: 28),
          if (!rejected)
            AppCard(
              child: Column(children: [
                for (var i = 0; i < steps.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(children: [
                      Icon(steps[i].$2 ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                          color: steps[i].$2 ? G4MColors.success : context.rc.faint),
                      const SizedBox(width: 12),
                      Expanded(child: Text(steps[i].$1, style: context.tt.titleSmall)),
                      if (!steps[i].$2 && i == 1) const PulseDot(color: G4MColors.accent, size: 8),
                    ]),
                  ).stagger(i),
              ]),
            ),
          const SizedBox(height: 16),
          AppCard(
            child: Row(children: [
              Avatar(name: partner.name, url: partner.photoUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(partner.name, style: context.tt.titleSmall),
                  Text('${vehicleLabel(context, partner.vehicleType)} · ${partner.vehicleNo}', style: context.tt.bodySmall),
                  if (partner.cities.isNotEmpty) Text(partner.cities.join(', '), style: context.tt.bodySmall),
                ]),
              ),
              StatusPill(s, label: Fmt.titleCase(s)),
            ]),
          ).stagger(3),
          const SizedBox(height: 28),
          OutlinedButton.icon(
            icon: const Icon(Icons.help_outline_rounded),
            label: Text(context.s.helpFaq),
            onPressed: () => Go.push(context, const HelpScreen()),
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            icon: const Icon(Icons.logout_rounded),
            label: Text(context.s.logout),
            onPressed: () async {
              await Session.instance.signOut();
              if (context.mounted) Go.root(context, const RootGate());
            },
          ),
          const SizedBox(height: 4),
          Text(myUid.isEmpty ? '' : 'ID ${myUid.substring(0, 6).toUpperCase()}', textAlign: TextAlign.center, style: context.tt.bodySmall),
        ]),
      ),
    );
  }
}
