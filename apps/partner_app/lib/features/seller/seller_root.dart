import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:g4m_core/g4m_core.dart';

import '../../core/l10n.dart';
import '../../core/motion.dart';
import '../../core/partner_theme.dart';
import '../../core/session.dart';
import '../../core/ui.dart';
import '../common/help_screen.dart';
import 'order_detail_screen.dart';
import 'seller_data.dart';
import 'seller_registration_screen.dart';
import 'seller_shell.dart';

/// Streams `sellers/{uid}`: missing -> registration wizard, not approved -> pending, approved -> shell.
class SellerRoot extends StatelessWidget {
  const SellerRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Seller?>(
      stream: SellerData.me(),
      builder: (context, snap) {
        Widget child;
        if (snap.hasError && '${snap.error}'.contains('permission-denied')) {
          // Rules may hide a not-yet-created / unapproved doc: treat as "not registered".
          child = const SellerRegistrationScreen();
        } else if (snap.hasError) {
          child = Scaffold(body: ErrorView(snap.error!));
        } else if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          child = const Scaffold(body: Center(child: CircularProgressIndicator()));
        } else if (snap.data == null) {
          child = const SellerRegistrationScreen();
        } else if (snap.data!.status != 'approved') {
          child = SellerPendingScreen(seller: snap.data!);
        } else {
          child = const SellerShell();
        }
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 450),
          child: KeyedSubtree(key: ValueKey(child.runtimeType), child: child),
        );
      },
    );
  }
}

/// Deep-link entry points used by push notifications and the inbox.
abstract final class SellerNav {
  static Future<void> openOrder(BuildContext context, String orderId) async {
    await Go.push(context, SellerOrderDetailScreen(orderId: orderId));
  }
}

/// Live pending / rejected / suspended screen.
class SellerPendingScreen extends StatelessWidget {
  const SellerPendingScreen({super.key, required this.seller});
  final Seller seller;

  @override
  Widget build(BuildContext context) {
    final status = seller.status;
    final rejected = status == 'rejected';
    final suspended = status == 'suspended';
    final color = rejected || suspended ? G4MColors.danger : G4MColors.warning;
    final icon = rejected
        ? Icons.gpp_bad_rounded
        : suspended
            ? Icons.block_rounded
            : Icons.hourglass_top_rounded;
    final title = rejected
        ? context.tr('Application not approved', 'आवेदन स्वीकृत नहीं हुआ')
        : suspended
            ? context.tr('Store suspended', 'स्टोर निलंबित')
            : context.s.pendingApproval;
    final msg = rejected
        ? context.tr('Our team could not approve your store. Contact support to know more or update your details.',
            'हमारी टीम आपका स्टोर स्वीकृत नहीं कर सकी। अधिक जानकारी के लिए सहायता से संपर्क करें।')
        : suspended
            ? context.tr('Your store is temporarily suspended. Please contact support.', 'आपका स्टोर अस्थायी रूप से निलंबित है। कृपया सहायता से संपर्क करें।')
            : context.tr('Thanks for registering ${seller.storeName}! We are verifying your details. This screen updates automatically once you are approved.',
                '${seller.storeName} पंजीकरण के लिए धन्यवाद! हम आपकी जानकारी की जांच कर रहे हैं। स्वीकृति मिलते ही यह स्क्रीन अपने आप अपडेट होगी।');

    Widget badge = Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(color: color.withValues(alpha: .12), shape: BoxShape.circle),
      child: Icon(icon, size: 56, color: color),
    );
    badge = rejected || suspended
        ? badge.animate().shake(duration: 700.ms)
        : badge
            .animate(onPlay: (c) => c.repeat())
            .rotate(begin: 0, end: .5, duration: 1200.ms, curve: Curves.easeInOutBack)
            .then(delay: 600.ms);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            Align(alignment: Alignment.centerLeft, child: G4MWordmark(size: 30, light: context.isDark)),
            const Spacer(),
            badge,
            const SizedBox(height: 28),
            Text(title, textAlign: TextAlign.center, style: context.tt.headlineSmall).animate().fadeIn(delay: 150.ms).slideY(begin: .2),
            const SizedBox(height: 12),
            Text(msg, textAlign: TextAlign.center, style: context.tt.bodyMedium?.copyWith(color: context.rc.muted, height: 1.5))
                .animate()
                .fadeIn(delay: 250.ms),
            const SizedBox(height: 24),
            if (!rejected && !suspended)
              AppCard(
                child: Column(children: [
                  _step(context, Icons.check_circle_rounded, context.tr('Application submitted', 'आवेदन जमा हुआ'), true),
                  _step(context, Icons.manage_search_rounded, context.tr('Verification in progress', 'सत्यापन जारी है'), false, active: true),
                  _step(context, Icons.storefront_rounded, context.tr('Start selling', 'बेचना शुरू करें'), false),
                ]),
              ).stagger(3),
            const Spacer(),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.help_outline_rounded),
                  label: Text(context.s.helpFaq),
                  onPressed: () => Go.push(context, const HelpScreen()),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.logout_rounded),
                  label: Text(context.s.logout),
                  onPressed: () => Session.instance.signOut(),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _step(BuildContext context, IconData icon, String label, bool done, {bool active = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          active
              ? const PulseDot(color: G4MColors.warning, size: 12)
              : Icon(icon, color: done ? G4MColors.success : context.rc.faint, size: 26),
          const SizedBox(width: 12),
          Text(label, style: context.tt.titleSmall?.copyWith(color: done || active ? context.rc.ink : context.rc.muted)),
        ]),
      );
}
