// File generated manually with exact Firebase credentials for messenger-app-4b05e.
// Do not modify manually unless credentials change.

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
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for ios - '
          'you can reconfigure this by running the FlutterFire CLI.',
        );
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          'you can reconfigure this by running the FlutterFire CLI.',
        );
      case TargetPlatform.windows:
        return web; // Windows desktop falls back to Web SDK options
      case TargetPlatform.linux:
        return web;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyB0I2_sLVLrsn0rxV8xPosK3yNjeknCMBg',
    appId: '1:1062003220328:web:5e0474c0583fe62c4480dd',
    messagingSenderId: '1062003220328',
    projectId: 'messenger-app-4b05e',
    authDomain: 'messenger-app-4b05e.firebaseapp.com',
    storageBucket: 'messenger-app-4b05e.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCGC5RQeNiy2u4wz-wi85B0pmRKVLZvRvE',
    appId: '1:1062003220328:android:58a8059e712d89364480dd',
    messagingSenderId: '1062003220328',
    projectId: 'messenger-app-4b05e',
    storageBucket: 'messenger-app-4b05e.firebasestorage.app',
  );
}
