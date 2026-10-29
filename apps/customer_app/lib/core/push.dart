import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:g4m_core/g4m_core.dart';

import 'data.dart';

/// Background handler must be a top-level function.
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  // Notification payloads are displayed by the system; nothing to do for data-only messages yet.
  await initG4MFirebase(G4MClient.customerApp);
}

/// Deep link waiting to be opened by the shell (set by notification taps).
final pendingDeepLink = ValueNotifier<Map<String, dynamic>?>(null);

class PushService {
  PushService._();
  static final _local = FlutterLocalNotificationsPlugin();
  static const _channel = AndroidNotificationChannel(
    'g4m_default',
    'Go4Market updates',
    description: 'Order updates, offers and account alerts',
    importance: Importance.high,
  );
  static bool _started = false;
  static StreamSubscription? _authSub;

  static Future<void> init() async {
    if (_started) return;
    _started = true;
    try {
      await _local.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
        ),
        onDidReceiveNotificationResponse: (r) {
          final p = r.payload;
          if (p == null || p.isEmpty) return;
          try {
            pendingDeepLink.value = Map<String, dynamic>.from(jsonDecode(p) as Map);
          } catch (_) {}
        },
      );
      await _local
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);

      final fm = FirebaseMessaging.instance;
      await fm.requestPermission(alert: true, badge: true, sound: true);
      await fm.setForegroundNotificationPresentationOptions(alert: false, badge: true, sound: true);

      FirebaseMessaging.onMessage.listen(_showForeground);
      FirebaseMessaging.onMessageOpenedApp.listen((m) => pendingDeepLink.value = m.data);
      final initial = await fm.getInitialMessage();
      if (initial != null) pendingDeepLink.value = initial.data;

      final launch = await _local.getNotificationAppLaunchDetails();
      final lp = launch?.notificationResponse?.payload;
      if ((launch?.didNotificationLaunchApp ?? false) && lp != null && lp.isNotEmpty) {
        try {
          pendingDeepLink.value = Map<String, dynamic>.from(jsonDecode(lp) as Map);
        } catch (_) {}
      }

      for (final t in ['all', 'customers']) {
        unawaited(fm.subscribeToTopic(t).catchError((_) {}));
      }
      // Classic FCM registration tokens are what the backend stores in users.fcmTokens and sends to;
      // the new register()/onRegistered API yields installation IDs, which the functions don't use yet.
      // ignore: deprecated_member_use
      fm.onTokenRefresh.listen(_save);
      _authSub = FirebaseAuth.instance.authStateChanges().listen((u) async {
        if (u == null) return;
        try {
          // ignore: deprecated_member_use
          final tok = await fm.getToken();
          if (tok != null) await _save(tok);
        } catch (e) {
          debugPrint('[g4m] fcm token: $e');
        }
      });
    } catch (e) {
      debugPrint('[g4m] push init: $e');
    }
  }

  /// Registers the token through the `registerPushToken` callable (it stores the token and
  /// subscribes topics server-side). Falls back to writing `users.fcmTokens` when the callable
  /// isn't deployed yet. Client-side topic subscription above stays as a harmless backup.
  static Future<void> _save(String token) async {
    if (FirebaseAuth.instance.currentUser == null) return;
    try {
      await G4MApi.instance.call('registerPushToken', {'token': token, 'platform': _platform});
      return;
    } catch (e) {
      if (!isMissingFunction(e)) debugPrint('[g4m] registerPushToken: $e');
    }
    try {
      await ShopperRepo.instance.saveFcmToken(token);
    } catch (e) {
      debugPrint('[g4m] save token: $e');
    }
  }

  static String get _platform => switch (defaultTargetPlatform) {
        TargetPlatform.iOS => 'ios',
        _ => 'android',
      };

  static Future<void> _showForeground(RemoteMessage m) async {
    final n = m.notification;
    final title = n?.title ?? '${m.data['title'] ?? ''}';
    final body = n?.body ?? '${m.data['body'] ?? ''}';
    if (title.isEmpty && body.isEmpty) return;
    await _local.show(
      id: m.hashCode & 0x7fffffff,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          color: G4MColors.primary,
          styleInformation: BigTextStyleInformation(body),
        ),
        iOS: const DarwinNotificationDetails(presentAlert: true, presentSound: true),
      ),
      payload: jsonEncode(m.data),
    );
  }

  static void dispose() => _authSub?.cancel();
}
