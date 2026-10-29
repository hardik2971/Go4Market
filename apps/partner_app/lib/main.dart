import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:g4m_core/g4m_core.dart';

import 'app.dart';
import 'core/app_state.dart';
import 'core/push.dart';
import 'features/delivery/delivery_root.dart';
import 'features/seller/seller_root.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
  ));
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  await Future.wait([_initFirebase(), AppState.instance.load()]);
  FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);

  // Push / inbox deep links -> the role's order screen.
  PushService.instance.onOpenOrder = (role, orderId) {
    final ctx = navKey.currentContext;
    if (ctx == null) return;
    if (role == PartnerRole.seller) {
      SellerNav.openOrder(ctx, orderId);
    } else {
      DeliveryNav.openOrder(ctx, orderId);
    }
  };

  runApp(const PartnerApp());
}

Future<void> _initFirebase() async {
  try {
    await initG4MFirebase(G4MClient.partnerApp);
  } on FirebaseException catch (e) {
    // google-services may already have created the default app natively.
    if (e.code != 'duplicate-app') rethrow;
  }
}
