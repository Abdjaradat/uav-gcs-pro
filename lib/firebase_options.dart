import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        throw UnsupportedError('Windows not supported');
      case TargetPlatform.linux:
        throw UnsupportedError('Linux not supported');
      default:
        throw UnsupportedError('Unsupported platform');
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDUtt_fjtRAfCV8CISyXcAB9p9t4i4QR18',
    appId: '1:287871558568:android:5e3fdbc7755bf52109739d',
    messagingSenderId: '287871558568',
    projectId: 'uav-gcs-pro-v4-aa',
    storageBucket: 'uav-gcs-pro-v4-aa.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDUtt_fjtRAfCV8CISyXcAB9p9t4i4QR18',
    appId: '1:287871558568:ios:YOUR_IOS_APP_ID',
    messagingSenderId: '287871558568',
    projectId: 'uav-gcs-pro-v4-aa',
    storageBucket: 'uav-gcs-pro-v4-aa.firebasestorage.app',
    iosBundleId: 'com.uavgcs.uav-gcs-pro',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyDUtt_fjtRAfCV8CISyXcAB9p9t4i4QR18',
    appId: '1:287871558568:ios:YOUR_IOS_APP_ID',
    messagingSenderId: '287871558568',
    projectId: 'uav-gcs-pro-v4-aa',
    storageBucket: 'uav-gcs-pro-v4-aa.firebasestorage.app',
    iosBundleId: 'com.uavgcs.uav-gcs-pro',
  );
}
