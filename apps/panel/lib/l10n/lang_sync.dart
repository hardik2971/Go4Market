import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:g4m_core/g4m_core.dart' show Fs;
import 'package:web/web.dart' as web;

import '../core/session.dart';
import 'l10n.dart';

/// Keeps [L10n] in sync with localStorage, Firestore `languages` (active flags) and
/// the signed-in user's saved preference (`users/{uid}.lang`, plus `staff/{uid}.lang` for admins).
abstract final class LangSync {
  static const _key = 'g4m.lang';
  static StreamSubscription? _langSub;
  static String? _appliedFor;

  static String? _get() {
    try {
      return web.window.localStorage.getItem(_key);
    } catch (_) {
      return null;
    }
  }

  static void _put(String v) {
    try {
      web.window.localStorage.setItem(_key, v);
    } catch (_) {}
  }

  /// Call once before runApp.
  static void start(Session s) {
    final saved = _get();
    if (saved != null) L10n.instance.set(saved);
    _langSub ??= Fs.languages.snapshots().listen((snap) {
      if (snap.docs.isEmpty) return; // collection not seeded → offer all
      final codes = <String>{
        for (final d in snap.docs)
          if (d.data()['active'] == true) '${d.data()['code'] ?? d.id}',
      };
      L10n.instance.setActive(codes);
    }, onError: (_) {});
    s.addListener(() => _onSession(s));
  }

  static void _onSession(Session s) {
    if (!s.signedIn) {
      _appliedFor = null;
      return;
    }
    final doc = s.userDoc;
    if (doc == null || _appliedFor == s.uid) return;
    _appliedFor = s.uid;
    final l = doc.s('lang');
    if (l.isNotEmpty && l != L10n.instance.code && L10n.instance.set(l)) _put(l);
  }

  /// User picked a language: apply, remember locally and on the profile.
  static Future<void> choose(String code) async {
    if (!L10n.instance.set(code)) return;
    _put(code);
    final s = Session.instance;
    if (!s.signedIn) return;
    _appliedFor = s.uid;
    try {
      await Fs.user(s.uid).set({'lang': code}, SetOptions(merge: true));
    } catch (_) {}
    if (s.panel == PanelRole.admin) {
      try {
        final ref = Fs.staff.doc(s.uid);
        if ((await ref.get()).exists) await ref.update({'lang': code});
      } catch (_) {}
    }
  }
}
