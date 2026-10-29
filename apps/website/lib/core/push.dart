// Browser push notifications (FEATURES #38).
//
// Permission is only ever requested from a button the shopper taps in the
// "Get order updates" card, which is offered after sign-in or after an order is
// placed. Never on page load. Tokens go to the `registerPushToken` callable,
// falling back to `users/{uid}.fcmTokens` (arrayUnion) while that is not deployed.
import 'dart:async';
import 'dart:js_interop_unsafe';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:g4m_core/g4m_core.dart';
import 'package:web/web.dart' as web;

import '../l10n/l10n.dart';
import 'web_bridge.dart';

class Push {
  Push._();
  static final instance = Push._();

  /// Lets push code show toasts without a page context (set on MaterialApp).
  static final messengerKey = GlobalKey<ScaffoldMessengerState>();

  /// Navigates inside the app (wired to the router in main).
  static void Function(String path)? navigate;

  /// Supplies an Overlay for the opt-in card (wired to the router's navigator in main).
  static OverlayState? Function()? overlay;

  static const _askedKey = 'g4m_push_asked_at';
  static const _regKey = 'g4m_push_reg';
  static const _snooze = Duration(days: 7);

  bool _started = false;
  bool? _supported;
  OverlayEntry? _card;
  StreamSubscription? _fg;

  /// Wires foreground messages and silently refreshes the token when permission was already granted.
  void init() {
    if (_started) return;
    _started = true;
    FirebaseAuth.instance.authStateChanges().listen((u) {
      if (u != null && !u.isAnonymous && permission == 'granted') unawaited(_register());
    });
  }

  /// `default` | `granted` | `denied` | `unsupported`.
  String get permission {
    try {
      if (!web.window.has('Notification')) return 'unsupported';
      return web.Notification.permission;
    } catch (_) {
      return 'unsupported';
    }
  }

  Future<bool> get supported async {
    if (_supported != null) return _supported!;
    try {
      _supported = permission != 'unsupported' && await FirebaseMessaging.instance.isSupported();
    } catch (_) {
      _supported = false;
    }
    return _supported!;
  }

  bool get _signedIn {
    final u = FirebaseAuth.instance.currentUser;
    return u != null && !u.isAnonymous;
  }

  /// Offers the opt-in card (after sign-in or after placing an order). No-op when it makes no sense:
  /// not signed in, already granted/denied, unsupported, or dismissed in the last week.
  Future<void> offer({Duration delay = const Duration(milliseconds: 1400)}) async {
    if (!_signedIn || permission != 'default' || _card != null) return;
    final last = int.tryParse(WebBridge.local(_askedKey) ?? '');
    if (last != null && DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(last)) < _snooze) return;
    if (!await supported) return;
    await Future<void>.delayed(delay);
    final o = overlay?.call();
    if (o == null || !o.mounted || _card != null || permission != 'default') return;
    _card = OverlayEntry(builder: (_) => _OptInCard(onEnable: _enable, onDismiss: _dismiss));
    o.insert(_card!);
  }

  void _close() {
    try {
      _card?.remove();
    } catch (_) {}
    _card = null;
  }

  void _dismiss() {
    WebBridge.setLocal(_askedKey, '${DateTime.now().millisecondsSinceEpoch}');
    _close();
  }

  /// Runs from the "Turn on" tap, so the browser sees a user gesture.
  Future<void> _enable() async {
    final s = L.current.common;
    WebBridge.setLocal(_askedKey, '${DateTime.now().millisecondsSinceEpoch}');
    try {
      final r = await FirebaseMessaging.instance.requestPermission();
      _close();
      if (r.authorizationStatus == AuthorizationStatus.authorized || r.authorizationStatus == AuthorizationStatus.provisional) {
        final ok = await _register(force: true);
        _toast(ok ? s.pushOn : s.pushFailed, error: !ok);
      } else if (permission == 'denied') {
        _toast(s.pushBlocked, error: true);
      }
    } catch (_) {
      _close();
      _toast(s.pushFailed, error: true);
    }
  }

  /// Gets the FCM token (Firebase default VAPID key) and stores it for the signed-in user.
  Future<bool> _register({bool force = false}) async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null || u.isAnonymous) return false;
    try {
      _listenForeground();
      // FCM registration token for the backend's token-based sends (register() yields an FID instead).
      // No vapidKey: the JS SDK falls back to Firebase's default key.
      // ignore: deprecated_member_use
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return false;
      final stamp = '${u.uid}:$token';
      if (!force && WebBridge.local(_regKey) == stamp) return true;
      try {
        await FirebaseFunctions.instanceFor(region: kFunctionsRegion)
            .httpsCallable('registerPushToken')
            .call<dynamic>({'token': token, 'platform': 'web'});
      } on FirebaseFunctionsException catch (e) {
        // Callable not deployed yet (a missing function surfaces as not-found, or as internal
        // because the 404 has no CORS headers): store the token on the user doc directly.
        if (!const {'not-found', 'internal', 'unimplemented', 'unavailable'}.contains(e.code)) rethrow;
        await Fs.user(u.uid).set({'fcmTokens': FieldValue.arrayUnion([token])}, SetOptions(merge: true));
      }
      WebBridge.setLocal(_regKey, stamp);
      return true;
    } catch (_) {
      return false;
    }
  }

  void _listenForeground() {
    _fg ??= FirebaseMessaging.onMessage.listen((m) {
      final n = m.notification;
      final title = n?.title ?? m.data['title'] as String? ?? '';
      final body = n?.body ?? m.data['body'] as String? ?? '';
      if (title.isEmpty && body.isEmpty) return;
      final link = linkFor(m.data);
      _toast(body.isEmpty ? title : (title.isEmpty ? body : '$title\n$body'), action: link == null ? null : () => navigate?.call(link));
    });
  }

  /// In-app path for a push payload's data.
  static String? linkFor(Map<String, dynamic> d) {
    final l = d['link'];
    if (l is String && l.startsWith('/') && !l.startsWith('//')) return l;
    final o = d['orderId'];
    if (o is String && o.isNotEmpty) return '/orders/$o';
    if (d['type'] == 'wallet') return '/wallet';
    return null;
  }

  void _toast(String msg, {bool error = false, VoidCallback? action}) {
    final m = messengerKey.currentState;
    if (m == null) return;
    m.hideCurrentSnackBar();
    m.showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? G4MColors.danger : G4MColors.primaryDeep,
      behavior: SnackBarBehavior.floating,
      width: 420,
      duration: const Duration(seconds: 6),
      action: action == null ? null : SnackBarAction(label: L.current.common.view, textColor: const Color(0xFFBFF0D4), onPressed: action),
    ));
  }
}

/// Small, dismissible opt-in card in the bottom corner (start side in RTL).
class _OptInCard extends StatelessWidget {
  const _OptInCard({required this.onEnable, required this.onDismiss});
  final Future<void> Function() onEnable;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final s = context.l.common;
    final phone = MediaQuery.sizeOf(context).width < 720;
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return PositionedDirectional(
      end: phone ? 12 : 24,
      start: phone ? 12 : null,
      bottom: phone ? 84 : 24,
      child: SafeArea(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: reduce ? 1 : 0, end: 1),
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutCubic,
          builder: (_, v, child) => Opacity(opacity: v, child: Transform.translate(offset: Offset(0, (1 - v) * 24), child: child)),
          child: Semantics(
            container: true,
            liveRegion: true,
            label: s.pushTitle,
            child: Material(
              color: Colors.white,
              elevation: 0,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: phone ? null : 380,
                padding: const EdgeInsets.fromLTRB(18, 16, 12, 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: G4MColors.line),
                  boxShadow: const [BoxShadow(color: Color(0x2A0A4A33), blurRadius: 32, offset: Offset(0, 12))],
                ),
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(color: G4MColors.primarySoft, borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.notifications_active_outlined, color: G4MColors.primaryDeep),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(s.pushTitle, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: G4MColors.ink)),
                        const SizedBox(height: 4),
                        Text(s.pushBody, style: const TextStyle(color: G4MColors.inkMuted, fontSize: 13.5, height: 1.45)),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    TextButton(onPressed: onDismiss, child: Text(s.pushLater)),
                    const SizedBox(width: 6),
                    FilledButton.icon(
                      onPressed: onEnable,
                      icon: const Icon(Icons.notifications_none_rounded, size: 18),
                      label: Text(s.pushEnable),
                    ),
                  ]),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
