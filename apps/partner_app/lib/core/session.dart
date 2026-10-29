import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:g4m_core/g4m_core.dart';

import 'app_state.dart';
import 'location_service.dart';
import 'push.dart';
import 'social_auth.dart';

/// Name / phone / email taken from the sign-in provider, used to prefill the
/// registration wizards after a first phone or Google sign-in.
class PartnerPrefill {
  const PartnerPrefill({this.name, this.phone, this.email});
  final String? name, phone, email;
}

/// Auth/role session. `version` bumps whenever claims are refreshed so the
/// RootGate re-resolves the role (e.g. right after registerSeller / registerDeliveryPartner).
class Session extends ChangeNotifier {
  Session._();
  static final instance = Session._();

  int version = 0;
  PartnerRole? role;

  /// While true the RootGate keeps the login screen up even though a user is
  /// signed in, so the login flow can finish (profile, mismatch prompt) first.
  bool holdRouting = false;

  /// Provider details from the last phone / Google sign-in.
  PartnerPrefill prefill = const PartnerPrefill();

  void hold() {
    if (holdRouting) return;
    holdRouting = true;
    notifyListeners();
  }

  void release() {
    if (!holdRouting) return;
    holdRouting = false;
    notifyListeners();
  }

  User? get user => FirebaseAuth.instance.currentUser;
  String get uid => user?.uid ?? '';

  /// Forces a fresh ID token (custom claims) and asks the gate to re-route.
  Future<void> refreshClaims() async {
    await user?.getIdToken(true);
    version++;
    notifyListeners();
  }

  /// Reads the role claim (forcing a token refresh so newly-set claims apply).
  Future<String> resolveClaim() async {
    try {
      return await AuthRepo.instance.role(refresh: true);
    } catch (_) {
      return AuthRepo.instance.role();
    }
  }

  Future<void> signOut() async {
    try {
      if (role == PartnerRole.delivery) await LocationService.instance.stop();
    } catch (_) {}
    try {
      await PushService.instance.detach();
    } catch (_) {}
    role = null;
    prefill = const PartnerPrefill();
    await SocialAuth.instance.signOutGoogle();
    await AuthRepo.instance.signOut();
  }
}
