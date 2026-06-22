// Firebase configuration for Runic Sudoku (Phase 4).
//
// Hand-generated from android/app/google-services.json (the project is
// Android-only). If iOS/web/macOS support is added later, regenerate this file
// with `flutterfire configure`.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with Firebase on the current platform.
class DefaultFirebaseOptions {
  const DefaultFirebaseOptions._();

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'Firebase web is not configured for Runic Sudoku.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'Firebase is only configured for Android in Runic Sudoku '
          '(got $defaultTargetPlatform).',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBGiuY1gH4pGiRjFVVwRIjhizypgVBnu_I',
    appId: '1:193010253277:android:cd1272ea079bf176388a34',
    messagingSenderId: '193010253277',
    projectId: 'runic-sudoku',
    storageBucket: 'runic-sudoku.firebasestorage.app',
  );
}
