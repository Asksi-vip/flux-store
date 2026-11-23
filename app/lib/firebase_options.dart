// File generated for Firebase project flux-games
// https://firebase.google.com/docs/flutter/setup
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// إعدادات Firebase الافتراضية المستخرجة مباشرة من google-services.json
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        return android;
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAfiC2sP9Z7mIf10TO3aVEtovHXWTFup3Q',
    appId: '1:864539935993:android:75e533ad978cf46e73ce28',
    messagingSenderId: '864539935993',
    projectId: 'flux-games',
    databaseURL: 'https://flux-games-default-rtdb.firebaseio.com',
    storageBucket: 'flux-games.firebasestorage.app',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAfiC2sP9Z7mIf10TO3aVEtovHXWTFup3Q',
    appId: '1:864539935993:web:75e533ad978cf46e73ce28',
    messagingSenderId: '864539935993',
    projectId: 'flux-games',
    databaseURL: 'https://flux-games-default-rtdb.firebaseio.com',
    storageBucket: 'flux-games.firebasestorage.app',
  );
}
