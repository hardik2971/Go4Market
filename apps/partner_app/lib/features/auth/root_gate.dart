import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:g4m_core/g4m_core.dart';

import '../../core/app_state.dart';
import '../../core/l10n.dart';
import '../../core/partner_theme.dart';
import '../../core/push.dart';
import '../../core/session.dart';
import '../../core/ui.dart';
import '../delivery/delivery_root.dart';
import '../onboarding/onboarding_screen.dart';
import '../seller/seller_root.dart';
import 'login_screen.dart';
import 'role_chooser_screen.dart';

/// Decides what to show: onboarding / login / role chooser / seller app / delivery app.
/// The role comes from the `role` custom claim (never from Firestore).
class RootGate extends StatelessWidget {
  const RootGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      initialData: FirebaseAuth.instance.currentUser,
      builder: (context, snap) => ListenableBuilder(
        // Session.holdRouting keeps the login screen while a phone / Google sign-in finishes.
        listenable: Session.instance,
        builder: (context, _) => _route(snap.data),
      ),
    );
  }

  Widget _route(User? u) {
    final Widget child;
    if (u == null || u.isAnonymous || Session.instance.holdRouting) {
      child = AppState.instance.onboardingSeen ? const LoginScreen() : const OnboardingScreen();
    } else {
      child = _RoleResolver(key: ValueKey(u.uid));
    }
    return AnimatedSwitcher(duration: const Duration(milliseconds: 450), child: child);
  }
}

class _RoleResolver extends StatefulWidget {
  const _RoleResolver({super.key});
  @override
  State<_RoleResolver> createState() => _RoleResolverState();
}

class _RoleResolverState extends State<_RoleResolver> {
  late Future<String> _claim;
  int _version = -1;

  @override
  void initState() {
    super.initState();
    Session.instance.addListener(_onSession);
    _load();
  }

  @override
  void dispose() {
    Session.instance.removeListener(_onSession);
    super.dispose();
  }

  void _onSession() {
    if (Session.instance.version != _version) setState(_load);
  }

  void _load() {
    _version = Session.instance.version;
    _claim = Session.instance.resolveClaim().then((c) {
      final role = PartnerRoleX.fromClaim(c);
      Session.instance.role = role;
      if (role != null) {
        AppState.instance.setRoleTint(role);
        PushService.instance.attach(role);
      }
      return c;
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _claim,
      builder: (context, snap) {
        if (snap.hasError) {
          return Scaffold(body: ErrorView(snap.error!, onRetry: () => setState(_load)));
        }
        if (!snap.hasData) return const _Booting();
        return switch (snap.data) {
          Roles.seller => const SellerRoot(),
          Roles.delivery => const DeliveryRoot(),
          Roles.admin => const _AdminNotice(),
          _ => const RoleChooserScreen(),
        };
      },
    );
  }
}

class _Booting extends StatelessWidget {
  const _Booting();
  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const G4MLogo(size: 64),
            const SizedBox(height: 24),
            SizedBox(width: 120, child: LinearProgressIndicator(borderRadius: BorderRadius.circular(4), minHeight: 3)),
          ]),
        ),
      );
}

class _AdminNotice extends StatelessWidget {
  const _AdminNotice();
  @override
  Widget build(BuildContext context) => Scaffold(
        body: AppEmpty(
          icon: Icons.admin_panel_settings_outlined,
          title: context.tr('Admin account', 'एडमिन खाता'),
          message: context.tr(
            'This app is for sellers and delivery partners. Please use the Go4Market admin panel on the web.',
            'यह ऐप विक्रेताओं और डिलीवरी पार्टनर्स के लिए है। कृपया वेब पर एडमिन पैनल का उपयोग करें।',
          ),
          action: OutlinedButton(
            onPressed: () => Session.instance.signOut(),
            child: Text(context.s.logout, style: TextStyle(color: context.rc.ink)),
          ),
        ),
      );
}
