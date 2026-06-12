// Archivo de opciones de Firebase generado automáticamente.
// Reemplaza este archivo con el generado por el asistente de Firebase CLI si tienes uno.
// Puedes obtenerlo ejecutando:
// flutterfire configure

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDP8ppif26ur2HKRBRL-IIYvG44tkdmrD4',
    appId: '1:10974886481:web:e0deb893836f0a08b41670',
    messagingSenderId: '10974886481',
    projectId: 'geoportal-gestion',
    authDomain: 'geoportal-gestion.firebaseapp.com',
    storageBucket: 'geoportal-gestion.appspot.com',
    // measurementId no proporcionado en tu config, puedes agregarlo si lo tienes
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'TU_API_KEY',
    appId: 'TU_APP_ID',
    messagingSenderId: 'TU_MESSAGING_SENDER_ID',
    projectId: 'geoportal-97fd1',
    storageBucket: 'geoportal-97fd1.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'TU_API_KEY',
    appId: 'TU_APP_ID',
    messagingSenderId: 'TU_MESSAGING_SENDER_ID',
    projectId: 'geoportal-97fd1',
    storageBucket: 'geoportal-97fd1.appspot.com',
    iosClientId: 'TU_IOS_CLIENT_ID',
    iosBundleId: 'TU_IOS_BUNDLE_ID',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'TU_API_KEY',
    appId: 'TU_APP_ID',
    messagingSenderId: 'TU_MESSAGING_SENDER_ID',
    projectId: 'geoportal-97fd1',
    storageBucket: 'geoportal-97fd1.appspot.com',
    iosClientId: 'TU_IOS_CLIENT_ID',
    iosBundleId: 'TU_MACOS_BUNDLE_ID',
  );
}
