import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:g4m_core/g4m_core.dart' show Fs, G4MApi;
import 'package:go_router/go_router.dart';
import 'package:web/web.dart' as web;

import '../core/router.dart';
import '../core/session.dart';
import '../l10n/l10n.dart';
import '../ui/kit.dart';

/// Optional web-push certificate key: `--dart-define=FCM_VAPID_KEY=...`.
/// Empty → the Firebase JS SDK's default VAPID key is used.
const _vapidKey = String.fromEnvironment('FCM_VAPID_KEY');

/// Browser push for the panels. Permission is only requested from a user gesture
/// (the "Enable notifications" toggle in the profile menu).
abstract final class PushService {
  static const _pref = 'g4m.push';
  static final enabled = ValueNotifier<bool>(false);
  static String? _token;
  static String? _registeredFor;
  static bool _listening = false;

  static bool get supported {
    try {
      return web.window.has('Notification') && web.window.navigator.has('serviceWorker');
    } catch (_) {
      return false;
    }
  }

  static String get permission {
    try {
      return web.Notification.permission;
    } catch (_) {
      return 'denied';
    }
  }

  static bool get _wanted {
    try {
      return web.window.localStorage.getItem(_pref) == '1';
    } catch (_) {
      return false;
    }
  }

  static void _setWanted(bool v) {
    try {
      web.window.localStorage.setItem(_pref, v ? '1' : '0');
    } catch (_) {}
  }

  static void start(Session s) {
    if (!supported) return;
    enabled.value = _wanted && permission == 'granted';
    _listen();
    // Notification clicked while a panel tab is open: the service worker posts {type:'g4m-open', path}.
    try {
      web.window.navigator.serviceWorker.addEventListener(
        'message',
        ((web.MessageEvent e) {
          final d = e.data.dartify();
          final c = rootNavKey.currentContext;
          if (c != null && d is Map && d['type'] == 'g4m-open' && d['path'] is String) GoRouter.of(c).go(d['path'] as String);
        }).toJS,
      );
    } catch (_) {}
    // Previously enabled + permission still granted → refresh the token silently after sign-in.
    s.addListener(() {
      if (!s.signedIn) {
        _registeredFor = null;
        return;
      }
      if (enabled.value && _registeredFor != s.uid) {
        _registeredFor = s.uid;
        unawaited(_register(s).catchError((_) => false));
      }
    });
  }

  static void _listen() {
    if (_listening) return;
    _listening = true;
    try {
      FirebaseMessaging.onMessage.listen((m) {
        final title = m.notification?.title ?? m.data['title']?.toString() ?? '';
        final body = m.notification?.body ?? m.data['body']?.toString() ?? '';
        toast([title, body].where((x) => x.isNotEmpty).join(' — '), kind: ToastKind.info);
      });
    } catch (_) {}
  }

  /// Toggle from the profile menu (runs inside the click handler, so the browser allows the prompt).
  static Future<void> toggle() async {
    final s = Session.instance;
    if (enabled.value) {
      await _disable(s);
      return;
    }
    if (!supported) {
      toast(S.notificationsBlocked, kind: ToastKind.error);
      return;
    }
    try {
      final settings = await FirebaseMessaging.instance.requestPermission();
      if (settings.authorizationStatus != AuthorizationStatus.authorized && settings.authorizationStatus != AuthorizationStatus.provisional) {
        toast(S.notificationsBlocked, kind: ToastKind.error);
        return;
      }
      if (await _register(s)) {
        _registeredFor = s.uid;
        _setWanted(true);
        enabled.value = true;
        toast(S.notificationsOn);
      }
    } catch (e) {
      toastError(e);
    }
  }

  static Future<bool> _register(Session s) async {
    // getToken (not register/FID): the backend sends to FCM registration tokens.
    // ignore: deprecated_member_use
    final token = await FirebaseMessaging.instance.getToken(vapidKey: _vapidKey.isEmpty ? null : _vapidKey);
    if (token == null || token.isEmpty) return false;
    _token = token;
    try {
      await G4MApi.instance.call('registerPushToken', {'token': token, 'platform': 'web'});
    } catch (_) {
      // Callable not deployed yet (or failed): store the token directly; onUserWritten subscribes topics.
      await Fs.user(s.uid).set({'fcmTokens': FieldValue.arrayUnion([token])}, SetOptions(merge: true));
    }
    return true;
  }

  static Future<void> _disable(Session s) async {
    _setWanted(false);
    enabled.value = false;
    final t = _token;
    try {
      if (t != null) {
        try {
          await G4MApi.instance.call('unregisterPushToken', {'token': t});
        } catch (_) {
          await Fs.user(s.uid).update({'fcmTokens': FieldValue.arrayRemove([t])});
        }
      }
      // ignore: deprecated_member_use
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {}
    _token = null;
  }
}
