import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  DefaultFirebaseOptions._();

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return ios;
      default:
        return web;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCNLJ8VD46pT3yLwx_dwpufI08_1BVG_SM',
    authDomain: 'geoportal-97fd1.firebaseapp.com',
    projectId: 'geoportal-97fd1',
    storageBucket: 'geoportal-97fd1.firebasestorage.app',
    messagingSenderId: '31195696289',
    appId: '1:31195696289:web:82556b87bfdd6c474334e0',
    measurementId: 'G-C3CV685F5M',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCNLJ8VD46pT3yLwx_dwpufI08_1BVG_SM',
    authDomain: 'geoportal-97fd1.firebaseapp.com',
    projectId: 'geoportal-97fd1',
    storageBucket: 'geoportal-97fd1.firebasestorage.app',
    messagingSenderId: '31195696289',
    appId: '1:31195696289:web:82556b87bfdd6c474334e0',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCNLJ8VD46pT3yLwx_dwpufI08_1BVG_SM',
    authDomain: 'geoportal-97fd1.firebaseapp.com',
    projectId: 'geoportal-97fd1',
    storageBucket: 'geoportal-97fd1.firebasestorage.app',
    messagingSenderId: '31195696289',
    appId: '1:31195696289:web:82556b87bfdd6c474334e0',
  );
}
