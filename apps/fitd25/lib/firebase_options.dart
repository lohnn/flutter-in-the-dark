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
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for android - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for ios - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
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
    apiKey: 'AIzaSyDtYy2aGDzJMYkN95Yc4eqzzaIin2gwE1A',
    appId: '1:593790140169:web:3fad9a840ae4c12ecd9dd8',
    messagingSenderId: '593790140169',
    projectId: 'flutter-in-the-dark-f8570',
    authDomain: 'flutter-in-the-dark-f8570.firebaseapp.com',
    storageBucket: 'flutter-in-the-dark-f8570.appspot.com',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyC9kBmVfQ6DqA7qErha3_Bl0su2qlAOU9w',
    appId: '1:593790140169:ios:6d51120cbad83ab0cd9dd8',
    messagingSenderId: '593790140169',
    projectId: 'flutter-in-the-dark-f8570',
    storageBucket: 'flutter-in-the-dark-f8570.appspot.com',
    iosBundleId: 'dev.flutterfriends.fitd25',
  );
}
