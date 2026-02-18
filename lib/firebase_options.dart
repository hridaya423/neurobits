import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

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
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
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
    apiKey: 'AIzaSyCJ8_0fQoAdeFtd1UFsCO1qgxnOilfFlWc',
    appId: '1:468907860173:web:d83db499b78f5b030a8984',
    messagingSenderId: '468907860173',
    projectId: 'neurobits-b6768',
    authDomain: 'neurobits-b6768.firebaseapp.com',
    storageBucket: 'neurobits-b6768.firebasestorage.app',
    measurementId: 'G-DNC23CEH2Y',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyArvyQyAQhJel0vfPjDkSXqY_eZJcP4MDY',
    appId: '1:468907860173:android:165d4def660fb7610a8984',
    messagingSenderId: '468907860173',
    projectId: 'neurobits-b6768',
    storageBucket: 'neurobits-b6768.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyC7c2loAVk6npQnXMbEa_kCbPATtx-Yt4M',
    appId: '1:468907860173:ios:0005007611cbc7d80a8984',
    messagingSenderId: '468907860173',
    projectId: 'neurobits-b6768',
    storageBucket: 'neurobits-b6768.firebasestorage.app',
    iosBundleId: 'com.example.neurobits',
  );
}
