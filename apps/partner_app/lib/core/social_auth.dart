import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:g4m_core/g4m_core.dart';

/// Web OAuth client of the Firebase project; Android needs it as `serverClientId`
/// so the Google ID token is minted for Firebase Auth.
const kGoogleServerClientId = '734533490664-c4du5em77tt3rmn0mbqopqf6d3ri029e.apps.googleusercontent.com';

/// Thrown when the user closes the Google account picker (not an error to show).
class SignInCancelled implements Exception {
  const SignInCancelled();
  @override
  String toString() => 'SignInCancelled';
}

/// Phone (OTP) and Google sign-in on top of Firebase Auth, plus `completeProfile`.
class SocialAuth {
  SocialAuth._();
  static final instance = SocialAuth._();

  final _auth = FirebaseAuth.instance;
  Future<void>? _googleInit;

  Future<void> _ensureGoogle() => _googleInit ??= GoogleSignIn.instance
      .initialize(serverClientId: kGoogleServerClientId)
      .catchError((Object e) {
        _googleInit = null;
        throw e;
      });

  /// Account picker -> ID token -> Firebase credential.
  Future<UserCredential> signInWithGoogle() async {
    await _ensureGoogle();
    final GoogleSignInAccount account;
    try {
      account = await GoogleSignIn.instance.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled || e.code == GoogleSignInExceptionCode.interrupted) {
        throw const SignInCancelled();
      }
      rethrow;
    }
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw FirebaseAuthException(code: 'missing-id-token', message: 'Google did not return an ID token.');
    }
    return _auth.signInWithCredential(GoogleAuthProvider.credential(idToken: idToken));
  }

  /// Clears the cached Google account so the picker shows next time.
  Future<void> signOutGoogle() async {
    if (kIsWeb || _googleInit == null) return;
    try {
      await _googleInit;
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
  }

  /// Starts phone verification. On Android the SMS may be read automatically:
  /// [onAutoVerified] then receives a ready credential (with `smsCode` when known).
  Future<void> sendCode({
    required String phoneE164,
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required void Function(FirebaseAuthException e) onFailed,
    required void Function(PhoneAuthCredential credential) onAutoVerified,
    int? resendToken,
  }) {
    return _auth.verifyPhoneNumber(
      phoneNumber: phoneE164,
      timeout: const Duration(seconds: 60),
      forceResendingToken: resendToken,
      verificationCompleted: onAutoVerified,
      verificationFailed: onFailed,
      codeSent: onCodeSent,
      codeAutoRetrievalTimeout: (_) {},
    );
  }

  Future<UserCredential> verifyCode(String verificationId, String smsCode) =>
      _auth.signInWithCredential(PhoneAuthProvider.credential(verificationId: verificationId, smsCode: smsCode));

  Future<UserCredential> signInWithCredential(AuthCredential c) => _auth.signInWithCredential(c);

  /// `completeProfile {name, email?, phone?}` after a first phone / Google sign-in.
  /// Falls back to a merge into `users/{uid}` while the function is not deployed.
  Future<void> completeProfile({required String name, String? email, String? phone}) async {
    final u = _auth.currentUser;
    if (u == null) return;
    final n = name.trim();
    if (n.isNotEmpty && (u.displayName ?? '').isEmpty) {
      await u.updateDisplayName(n).catchError((_) {});
    }
    final input = <String, dynamic>{
      'name': n,
      if (email != null && email.isNotEmpty) 'email': email,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
    };
    try {
      await G4MApi.instance.call('completeProfile', input);
    } on FirebaseFunctionsException catch (e) {
      if (e.code != 'not-found' && e.code != 'unimplemented') {
        debugPrint('completeProfile failed: ${e.code} ${e.message}');
      }
      await _fallbackProfile(u.uid, input);
    } catch (e) {
      debugPrint('completeProfile failed: $e');
      await _fallbackProfile(u.uid, input);
    }
  }

  Future<void> _fallbackProfile(String uid, Map<String, dynamic> input) async {
    await Fs.user(uid).set({
      if ((input['name'] as String).isNotEmpty) 'name': input['name'],
      'email': ?input['email'],
      'phone': ?input['phone'],
      'updatedAt': Fs.now,
    }, SetOptions(merge: true)).catchError((_) {});
  }
}
