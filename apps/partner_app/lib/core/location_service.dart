import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:g4m_core/g4m_core.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

/// Streams the delivery partner's GPS position to `deliveryPartners/{uid}`
/// (only `online`, `lat`, `lng`, `locationUpdatedAt`, the fields the rules allow)
/// while they are online. On Android it runs as a foreground service with a
/// persistent notification so tracking survives the app being backgrounded.
///
/// Writes are throttled: at most every ~15 s, or sooner once the rider moves 30 m.
class LocationService extends ChangeNotifier {
  LocationService._();
  static final instance = LocationService._();

  static const writeEvery = Duration(seconds: 15);
  static const writeAfterMeters = 30.0;

  StreamSubscription<Position>? _sub;
  Timer? _heartbeat;
  String? _uid;
  Position? last;
  Position? _lastWritten;
  DateTime _lastWriteAt = DateTime.fromMillisecondsSinceEpoch(0);
  String? error;

  bool get running => _sub != null;

  /// Shows a rationale, then requests location (and notification permission for
  /// the tracking notification). Returns true when at least "while in use" is granted.
  Future<bool> ensurePermission(BuildContext context, {bool askBackground = true}) async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      if (context.mounted) {
        final open = await _ask(context,
            title: 'Turn on location',
            body: 'Location services are off. Turn them on so we can match you with nearby orders and share your live position with customers while you are online.',
            cta: 'Open settings');
        if (open) await Geolocator.openLocationSettings();
      }
      return false;
    }
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) {
      if (!context.mounted) return false;
      final ok = await _ask(context,
          title: 'Share your location while online',
          body: 'Go4Market Partner uses your location only while you are Online, to show nearby orders, guide you to the store and customer, and let customers track their delivery live. Tracking stops the moment you go Offline.',
          cta: 'Allow location');
      if (!ok) return false;
      p = await Geolocator.requestPermission();
    }
    if (p == LocationPermission.deniedForever) {
      if (context.mounted) {
        final open = await _ask(context,
            title: 'Location permission needed',
            body: 'Location access was denied. Enable it in app settings to go online.',
            cta: 'App settings');
        if (open) await Geolocator.openAppSettings();
      }
      return false;
    }
    if (p == LocationPermission.denied || p == LocationPermission.unableToDetermine) return false;

    // Notification permission (Android 13+) for the foreground tracking notification.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      await ph.Permission.notification.request();
    }

    // Optional "Allow all the time" upgrade: improves tracking with the screen off.
    if (askBackground && p == LocationPermission.whileInUse && context.mounted) {
      final ok = await _ask(context,
          title: 'Keep tracking with the screen off?',
          body: 'For accurate live tracking during a delivery, choose "Allow all the time". Go4Market only tracks you while you are Online, and a notification is always shown while tracking is active.',
          cta: 'Continue',
          secondary: 'Not now');
      if (ok) await ph.Permission.locationAlways.request();
    }
    return true;
  }

  Future<bool> _ask(BuildContext context, {required String title, required String body, required String cta, String secondary = 'Cancel'}) async {
    final r = await showModalBottomSheet<bool>(
      context: context,
      builder: (c) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: G4MColors.accentSoft, shape: BoxShape.circle),
            child: const Icon(Icons.my_location_rounded, color: G4MColors.accent, size: 30),
          ),
          const SizedBox(height: 16),
          Text(title, textAlign: TextAlign.center, style: Theme.of(c).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(body, textAlign: TextAlign.center, style: Theme.of(c).textTheme.bodyMedium),
          const SizedBox(height: 20),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(cta)),
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(secondary)),
        ]),
      ),
    );
    return r ?? false;
  }

  LocationSettings _settings() {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
        intervalDuration: const Duration(seconds: 5),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'You are online',
          notificationText: 'Go4Market Partner is sharing your location for deliveries.',
          notificationChannelName: 'Online tracking',
          enableWakeLock: true,
          setOngoing: true,
          notificationIcon: AndroidResource(name: 'ic_stat_notify', defType: 'drawable'),
          color: G4MColors.primary,
        ),
      );
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
        activityType: ActivityType.automotiveNavigation,
        pauseLocationUpdatesAutomatically: false,
        allowBackgroundLocationUpdates: true,
        showBackgroundLocationIndicator: true,
      );
    }
    return const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10);
  }

  /// Marks the partner online and starts streaming. Call [ensurePermission] first.
  Future<void> start(String uid) async {
    if (running && _uid == uid) return;
    await stop(writeOffline: false);
    _uid = uid;
    error = null;
    try {
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 12)),
      );
      last = p;
    } catch (_) {
      last = await Geolocator.getLastKnownPosition();
    }
    await _write(force: true);
    _sub = Geolocator.getPositionStream(locationSettings: _settings()).listen((p) {
      last = p;
      notifyListeners();
      _write();
    }, onError: (Object e) {
      error = e.toString();
      notifyListeners();
    });
    // Heartbeat so a stationary rider still refreshes locationUpdatedAt every ~15 s.
    _heartbeat = Timer.periodic(writeEvery, (_) => _write());
    notifyListeners();
  }

  Future<void> _write({bool force = false}) async {
    final uid = _uid;
    final p = last;
    if (uid == null) return;
    final now = DateTime.now();
    final moved = (p != null && _lastWritten != null)
        ? Geolocator.distanceBetween(_lastWritten!.latitude, _lastWritten!.longitude, p.latitude, p.longitude)
        : double.infinity;
    final due = now.difference(_lastWriteAt) >= writeEvery - const Duration(seconds: 1);
    final far = moved >= writeAfterMeters && now.difference(_lastWriteAt) >= const Duration(seconds: 3);
    if (!force && !due && !far) return;
    _lastWriteAt = now;
    _lastWritten = p;
    try {
      await Fs.deliveryPartners.doc(uid).update({
        'online': true,
        'lat': ?p?.latitude,
        'lng': ?p?.longitude,
        'locationUpdatedAt': Fs.now,
      });
    } catch (e) {
      error = e.toString();
      notifyListeners();
    }
  }

  /// Stops streaming and (by default) marks the partner offline.
  Future<void> stop({bool writeOffline = true}) async {
    await _sub?.cancel();
    _sub = null;
    _heartbeat?.cancel();
    _heartbeat = null;
    final uid = _uid;
    if (writeOffline && uid != null) {
      try {
        await Fs.deliveryPartners.doc(uid).update({'online': false, 'locationUpdatedAt': Fs.now});
      } catch (_) {}
    }
    notifyListeners();
  }
}
