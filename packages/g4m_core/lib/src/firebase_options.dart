import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Which Go4Market client is booting. Android app ids differ per package name.
enum G4MClient { website, admin, seller, delivery, customerApp, partnerApp }

class G4MFirebaseOptions {
  static const _apiKeyWeb = 'AIzaSyB2xehXMJCcMIPSVpnE26HFt9F_R_ppRGo';
  static const _apiKeyAndroid = 'AIzaSyDmaezfDVZOACHVuHlNNOWfVyf6P4m0jt0';
  static const _projectId = 'go4market';
  static const _senderId = '734533490664';
  static const _bucket = 'go4market.firebasestorage.app';

  static const web = FirebaseOptions(
    apiKey: _apiKeyWeb,
    appId: '1:734533490664:web:dbd25e9c62cdc58c04b65d',
    messagingSenderId: _senderId,
    projectId: _projectId,
    authDomain: 'go4market.firebaseapp.com',
    storageBucket: _bucket,
  );

  static const androidCustomer = FirebaseOptions(
    apiKey: _apiKeyAndroid,
    appId: '1:734533490664:android:70095f1daf555d6304b65d',
    messagingSenderId: _senderId,
    projectId: _projectId,
    storageBucket: _bucket,
  );

  static const androidPartner = FirebaseOptions(
    apiKey: _apiKeyAndroid,
    appId: '1:734533490664:android:478617e6f77c2f9104b65d',
    messagingSenderId: _senderId,
    projectId: _projectId,
    storageBucket: _bucket,
  );

  static FirebaseOptions forClient(G4MClient client) {
    if (kIsWeb) return web;
    return client == G4MClient.partnerApp ? androidPartner : androidCustomer;
  }
}

/// Initialise Firebase once for any Go4Market client.
Future<FirebaseApp> initG4MFirebase(G4MClient client) =>
    Firebase.initializeApp(options: G4MFirebaseOptions.forClient(client));

const kFunctionsRegion = 'asia-south1';
