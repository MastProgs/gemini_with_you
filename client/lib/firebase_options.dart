// File generated by FlutterFire CLI.
// ignore_for_file: lines_longer_than_80_chars, avoid_classes_with_only_static_members
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
    apiKey: 'AIzaSyC7dFDnm1ss4Hufz3ff8ENa03z7yjOeplE',
    appId: '1:661325520228:web:7c2b846b0bbf5c3b362e71',
    messagingSenderId: '661325520228',
    projectId: 'gemini-with-you',
    authDomain: 'gemini-with-you.firebaseapp.com',
    storageBucket: 'gemini-with-you.appspot.com',
    measurementId: 'G-K9664R5NFP',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyC7dFDnm1ss4Hufz3ff8ENa03z7yjOeplE',
    appId: '1:661325520228:web:7c2b846b0bbf5c3b362e71',
    messagingSenderId: '661325520228',
    projectId: 'gemini-with-you',
    authDomain: 'gemini-with-you.firebaseapp.com',
    storageBucket: 'gemini-with-you.appspot.com',
    measurementId: 'G-K9664R5NFP',
  );

  static const FirebaseOptions linux = FirebaseOptions(
    apiKey: 'AIzaSyC7dFDnm1ss4Hufz3ff8ENa03z7yjOeplE',
    appId: '1:661325520228:web:7c2b846b0bbf5c3b362e71',
    messagingSenderId: '661325520228',
    projectId: 'gemini-with-you',
    authDomain: 'gemini-with-you.firebaseapp.com',
    storageBucket: 'gemini-with-you.appspot.com',
    measurementId: 'G-K9664R5NFP',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBNycj3oUHE9MZbJGtqyW3nP8_XWgLKG1M',
    appId: '1:661325520228:android:219838fe4622c852362e71',
    messagingSenderId: '661325520228',
    projectId: 'gemini-with-you',
    storageBucket: 'gemini-with-you.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBYn5xNR_cNuudp2G0fq6Nn2taYEiMmkkI',
    appId: '1:661325520228:ios:af6c0a8ea514156b362e71',
    messagingSenderId: '661325520228',
    projectId: 'gemini-with-you',
    storageBucket: 'gemini-with-you.appspot.com',
    iosBundleId: 'com.example.client',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyBYn5xNR_cNuudp2G0fq6Nn2taYEiMmkkI',
    appId: '1:661325520228:ios:a21aa5c93c7ad162362e71',
    messagingSenderId: '661325520228',
    projectId: 'gemini-with-you',
    storageBucket: 'gemini-with-you.appspot.com',
    iosBundleId: 'com.example.client.RunnerTests',
  );
}
