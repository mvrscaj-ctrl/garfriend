import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    throw UnsupportedError('This config only supports web.');
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: "AIzaSyARz7TTd9ygv_elMacFi5wdKoKPCZnP_2Y",
    authDomain: "share-web-30d66.firebaseapp.com",
    projectId: "share-web-30d66",
    storageBucket: "share-web-30d66.firebasestorage.app",
    messagingSenderId: "449951874226",
    appId: "1:449951874226:web:6e7a40042ef495dfaf5dab",
    measurementId: "G-MH9X953CJV",
  );
}
