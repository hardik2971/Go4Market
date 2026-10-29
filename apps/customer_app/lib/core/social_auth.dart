import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:g4m_core/g4m_core.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'data.dart';
import 'session.dart';

/// Result of a phone / Google sign-in.
class SocialSignIn {
  const SocialSignIn({required this.user, required this.isNew, required this.needsProfile});
  final User user;
  final bool isNew;

  /// True after a first sign-in (or when the profile still has no name): show "Complete your profile".
  final bool needsProfile;
}

/// Thrown with a message that is already friendly enough to show.
class AuthFlowException implements Exception {
  const AuthFlowException(this.message, {this.code});
  final String message;
  final String? code;
  @override
  String toString() => message;
}

/// Phone OTP + Google sign-in (FEATURES #47), both merging a guest cart like the email flow.
class SocialAuth {
  SocialAuth._();

  /// OAuth *web* client of the Firebase project; Google returns an ID token for this audience,
  /// which is what `GoogleAuthProvider.credential` needs.
  static const webClientId = '734533490664-c4du5em77tt3rmn0mbqopqf6d3ri029e.apps.googleusercontent.com';

  static Future<void>? _googleInit;

  // ------------------------------------------------------------------ Google

  /// Returns null if the user closed the account picker.
  static Future<SocialSignIn?> google() async {
    final g = GoogleSignIn.instance;
    _googleInit ??= g.initialize(serverClientId: webClientId).catchError((Object e) {
      _googleInit = null;
      throw e;
    });
    await _googleInit;
    GoogleSignInAccount account;
    try {
      account = await g.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled || e.code == GoogleSignInExceptionCode.interrupted) return null;
      throw AuthFlowException(googleError(e), code: e.code.name);
    }
    final idToken = account.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw const AuthFlowException('Google did not return a sign-in token. Please try again.');
    }
    final cred = await Session.instance.signInWithCredential(GoogleAuthProvider.credential(idToken: idToken));
    return _outcome(cred);
  }

  static String googleError(GoogleSignInException e) => switch (e.code) {
        GoogleSignInExceptionCode.clientConfigurationError || GoogleSignInExceptionCode.providerConfigurationError =>
          'Google sign-in is not set up for this build yet. Please use phone or email for now.',
        GoogleSignInExceptionCode.uiUnavailable => 'Google sign-in could not open. Check that Google Play services is up to date.',
        GoogleSignInExceptionCode.userMismatch => 'That Google account does not match. Please try again.',
        _ => (e.description?.isNotEmpty ?? false) ? e.description! : 'Google sign-in failed. Please try again.',
      };

  /// Signs out of the Google account picker too, so the next sign-in can choose another account.
  static Future<void> signOutGoogle() async {
    if (_googleInit == null) return;
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
  }

  // ------------------------------------------------------------------ Phone

  /// Starts (or restarts, with [resendToken]) phone verification.
  /// On Android, [onAutoVerified] fires when the SMS is retrieved automatically or the number is
  /// verified instantly; Play Integrity is used, with a reCAPTCHA browser fallback handled by Firebase.
  static Future<void> sendCode({
    required String phoneE164,
    int? resendToken,
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required void Function(PhoneAuthCredential credential) onAutoVerified,
    required void Function(FirebaseAuthException e) onFailed,
    void Function(String verificationId)? onTimeout,
  }) {
    return FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phoneE164,
      forceResendingToken: resendToken,
      timeout: const Duration(seconds: 60),
      verificationCompleted: onAutoVerified,
      verificationFailed: onFailed,
      codeSent: onCodeSent,
      codeAutoRetrievalTimeout: onTimeout ?? (_) {},
    );
  }

  static Future<SocialSignIn> signInWithPhone(PhoneAuthCredential credential) async {
    final cred = await Session.instance.signInWithCredential(credential);
    return _outcome(cred);
  }

  static Future<SocialSignIn> verifyCode(String verificationId, String code) =>
      signInWithPhone(PhoneAuthProvider.credential(verificationId: verificationId, smsCode: code));

  // ------------------------------------------------------------------ profile

  static Future<SocialSignIn> _outcome(UserCredential cred) async {
    final u = cred.user!;
    final isNew = cred.additionalUserInfo?.isNewUser ?? false;
    var needs = isNew;
    if (!needs) {
      // A returning user who skipped the step earlier still has no name on file.
      try {
        final d = await Fs.user(u.uid).get().timeout(const Duration(seconds: 4));
        final name = '${d.data()?['name'] ?? ''}'.trim();
        needs = name.isEmpty && (u.displayName ?? '').trim().isEmpty;
      } catch (_) {}
    }
    return SocialSignIn(user: u, isNew: isNew, needsProfile: needs);
  }

  /// Calls `completeProfile {name, email?, phone?, referralCode?}`; if that callable isn't deployed
  /// yet (not-found / unimplemented), merges the same fields into `users/{uid}` directly.
  static Future<void> completeProfile({required String name, String? email, String? phone, String? referralCode}) async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) throw const AuthFlowException('Please sign in again.');
    final code = (referralCode ?? '').trim().toUpperCase();
    final input = <String, dynamic>{
      'name': name.trim(),
      if ((email ?? '').trim().isNotEmpty) 'email': email!.trim(),
      if ((phone ?? '').trim().isNotEmpty) 'phone': phone!.trim(),
      if (code.isNotEmpty) 'referralCode': code,
    };
    try {
      await G4MApi.instance.call('completeProfile', input);
    } catch (e) {
      if (!isMissingFunction(e)) rethrow;
      debugPrint('[g4m] completeProfile not deployed, writing users/${u.uid}');
      await Fs.user(u.uid).set({
        'name': input['name'],
        if (input['email'] != null) 'email': input['email'],
        if (input['phone'] != null) 'phone': input['phone'],
        if (code.isNotEmpty) 'referredBy': code,
        'updatedAt': Fs.now,
      }, SetOptions(merge: true));
    }
    try {
      if ((u.displayName ?? '') != input['name']) await u.updateDisplayName(input['name'] as String);
    } catch (_) {}
  }
}

/// Friendly text for phone-auth failures.
String phoneAuthError(Object e) {
  if (e is AuthFlowException) return e.message;
  if (e is FirebaseAuthException) {
    return switch (e.code) {
      'operation-not-allowed' => 'Phone sign-in isn\'t switched on yet. Please use Google or email for now.',
      'invalid-phone-number' => 'That phone number doesn\'t look right.',
      'invalid-verification-code' => 'That code is incorrect. Check the SMS and try again.',
      'invalid-verification-id' || 'session-expired' || 'code-expired' => 'This code has expired. Tap resend to get a new one.',
      'too-many-requests' => 'Too many attempts from this device. Please try again later.',
      'quota-exceeded' => 'We\'ve hit today\'s SMS limit. Please try again later or use another method.',
      'network-request-failed' => 'No internet connection.',
      'captcha-check-failed' || 'web-context-cancelled' || 'web-context-already-presented' => 'Verification was cancelled. Please try again.',
      'app-not-authorized' || 'missing-client-identifier' || 'invalid-app-credential' || 'app-not-verified' =>
        'This app build isn\'t verified for phone sign-in yet. Please use Google or email.',
      'user-disabled' => 'This account has been disabled. Contact support.',
      'credential-already-in-use' || 'account-exists-with-different-credential' =>
        'This number is already linked to another account.',
      _ => e.message ?? 'Phone sign-in failed (${e.code}).',
    };
  }
  return friendlyError(e);
}

/// Friendly text for Google / profile failures.
String socialAuthError(Object e) {
  if (e is AuthFlowException) return e.message;
  if (e is FirebaseAuthException) {
    return switch (e.code) {
      'operation-not-allowed' => 'Google sign-in isn\'t switched on yet. Please use phone or email for now.',
      'account-exists-with-different-credential' => 'An account already exists with this email. Sign in with your email and password.',
      'user-disabled' => 'This account has been disabled. Contact support.',
      'invalid-credential' => 'Google sign-in expired. Please try again.',
      'network-request-failed' => 'No internet connection.',
      _ => e.message ?? e.code,
    };
  }
  if (e is GoogleSignInException) return SocialAuth.googleError(e);
  return friendlyError(e);
}
