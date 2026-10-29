import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:g4m_core/g4m_core.dart';

import 'app_state.dart';

final navKey = GlobalKey<NavigatorState>();

/// Background FCM handler: the system tray shows notification messages itself.
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {}

/// FCM: permission, token -> `users/{uid}.fcmTokens`, role topic, foreground
/// banners via flutter_local_notifications and deep links to orders.
class PushService {
  PushService._();
  static final instance = PushService._();

  static const _channel = AndroidNotificationChannel(
    'orders',
    'Orders & deliveries',
    description: 'New orders, delivery assignments and status updates',
    importance: Importance.high,
  );

  final _local = FlutterLocalNotificationsPlugin();
  bool _localReady = false;
  PartnerRole? _role;
  String? _token;
  StreamSubscription<String>? _tokenSub;
  StreamSubscription<RemoteMessage>? _fgSub, _openSub;
  String? _pendingOrderId;

  /// Set by the root gate: opens an order for the given role.
  void Function(PartnerRole role, String orderId)? onOpenOrder;

  /// Stream of foreground messages (e.g. to flash a "new order" banner in the UI).
  final foreground = StreamController<RemoteMessage>.broadcast();

  Future<void> _initLocal() async {
    if (_localReady || kIsWeb) return;
    _localReady = true;
    await _local.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_notify'),
        iOS: DarwinInitializationSettings(requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false),
      ),
      onDidReceiveNotificationResponse: (r) {
        final id = _orderIdFrom(r.payload);
        if (id != null) _open(id);
      },
    );
    await _local
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);
  }

  String? _orderIdFrom(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    try {
      final m = jsonDecode(payload);
      if (m is Map && m['orderId'] is String) return m['orderId'] as String;
    } catch (_) {}
    return null;
  }

  /// Called once the role is known (after login / role resolution).
  Future<void> attach(PartnerRole role) async {
    if (kIsWeb) return;
    _role = role;
    try {
      await _initLocal();
      final fm = FirebaseMessaging.instance;
      await fm.requestPermission(alert: true, badge: true, sound: true);
      await fm.setForegroundNotificationPresentationOptions(alert: true, badge: true, sound: true);

      // getToken/onTokenRefresh are deprecated in favour of register()/onRegistered, which yield an
      // installation id (FID). The backend sends to classic registration tokens in users/{uid}.fcmTokens,
      // so we deliberately stay on the token API.
      // ignore: deprecated_member_use
      _token = await fm.getToken();
      await _saveToken(_token);
      _tokenSub?.cancel();
      // ignore: deprecated_member_use
      _tokenSub = fm.onTokenRefresh.listen((t) {
        _token = t;
        _saveToken(t);
      });

      // Topic per role; make sure we are not on the other role's topic.
      final other = role == PartnerRole.seller ? PartnerRole.delivery : PartnerRole.seller;
      unawaited(fm.unsubscribeFromTopic(other.topic).catchError((_) {}));
      await fm.subscribeToTopic(role.topic);
      await fm.subscribeToTopic('all').catchError((_) {});

      _fgSub?.cancel();
      _fgSub = FirebaseMessaging.onMessage.listen(_showForeground);
      _openSub?.cancel();
      _openSub = FirebaseMessaging.onMessageOpenedApp.listen((m) {
        final id = m.data['orderId'];
        if (id is String && id.isNotEmpty) _open(id);
      });
      final initial = await fm.getInitialMessage();
      final initId = initial?.data['orderId'];
      if (initId is String && initId.isNotEmpty) _pendingOrderId = initId;
      final launch = await _local.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp == true) {
        _pendingOrderId ??= _orderIdFrom(launch?.notificationResponse?.payload);
      }
    } catch (e) {
      debugPrint('Push attach failed: $e');
    }
  }

  /// Call when the role shell is on screen, so a deep link from a cold start can navigate.
  void flushPending() {
    final id = _pendingOrderId;
    _pendingOrderId = null;
    if (id != null) Future.delayed(const Duration(milliseconds: 400), () => _open(id));
  }

  void _open(String orderId) {
    final r = _role;
    if (r == null || onOpenOrder == null) {
      _pendingOrderId = orderId;
      return;
    }
    onOpenOrder!(r, orderId);
  }

  Future<void> _saveToken(String? t) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (t == null || uid == null) return;
    // Preferred: the backend stores the token (and de-duplicates it across users).
    // Falls back to the direct users/{uid}.fcmTokens write while the function is not deployed.
    try {
      await G4MApi.instance.call('registerPushToken', {
        'token': t,
        'platform': defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
      });
      return;
    } on FirebaseFunctionsException catch (e) {
      if (e.code != 'not-found') debugPrint('registerPushToken failed (${e.code}); using direct write');
    } catch (e) {
      debugPrint('registerPushToken failed ($e); using direct write');
    }
    await Fs.user(uid).set({'fcmTokens': FieldValue.arrayUnion([t])}, SetOptions(merge: true)).catchError((_) {});
  }

  Future<void> _showForeground(RemoteMessage m) async {
    foreground.add(m);
    final n = m.notification;
    if (n == null || !_localReady) return;
    await _local.show(
      id: m.hashCode & 0x7fffffff,
      title: n.title,
      body: n.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          color: G4MColors.primary,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: jsonEncode(m.data),
    );
  }

  /// On logout: drop this device's token and role topic.
  Future<void> detach() async {
    if (kIsWeb) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final fm = FirebaseMessaging.instance;
    // ignore: deprecated_member_use
    final t = _token ?? await fm.getToken().catchError((_) => null);
    if (uid != null && t != null) {
      await Fs.user(uid).set({'fcmTokens': FieldValue.arrayRemove([t])}, SetOptions(merge: true)).catchError((_) {});
    }
    final r = _role;
    if (r != null) await fm.unsubscribeFromTopic(r.topic).catchError((_) {});
    await _tokenSub?.cancel();
    await _fgSub?.cancel();
    await _openSub?.cancel();
    _role = null;
  }
}
