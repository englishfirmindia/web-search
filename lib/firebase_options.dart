// File generated by FlutterFire CLI.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
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
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyD1RViiPtc_ybN_yBJjBONXNkGKm4KJh1A',
    appId: '1:1048932909250:web:0b90eef3e86332ae3bfb5b',
    messagingSenderId: '1048932909250',
    projectId: 'beforerelease-8dec2',
    authDomain: 'beforerelease-8dec2.firebaseapp.com',
    storageBucket: 'beforerelease-8dec2.firebasestorage.app',
    measurementId: 'G-CRVVBKX8SH',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCkOOzMyoqaje5xf-AVTdP8ODkaO3aFhqs',
    appId: '1:1048932909250:android:f5b0764b0d3b1b603bfb5b',
    messagingSenderId: '1048932909250',
    projectId: 'beforerelease-8dec2',
    storageBucket: 'beforerelease-8dec2.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDUYW3Cu3IY4nqZ1dDkqxrQMJkz2v9TCdw',
    appId: '1:1048932909250:ios:b4fbdf12e040595a3bfb5b',
    messagingSenderId: '1048932909250',
    projectId: 'beforerelease-8dec2',
    storageBucket: 'beforerelease-8dec2.firebasestorage.app',
    iosBundleId: 'com.englishfirm.app',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyDUYW3Cu3IY4nqZ1dDkqxrQMJkz2v9TCdw',
    appId: '1:1048932909250:ios:b5c2e205c4c827083bfb5b',
    messagingSenderId: '1048932909250',
    projectId: 'beforerelease-8dec2',
    storageBucket: 'beforerelease-8dec2.firebasestorage.app',
    iosBundleId: 'com.example.englishfirm',
  );

}