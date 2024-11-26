import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    return const FirebaseOptions(
      apiKey: 'AIzaSyCAaKThKeVChc9Z1i0OxBBK7C_HbofaS94',
      appId: '1:411960763521:android:ebbe4d5580fcbec4fc1980',
      messagingSenderId: '411960763521',
      projectId: 'aaaa-8a6a5',
      databaseURL: 'https://aaaa-8a6a5-default-rtdb.firebaseio.com',
    );
  }
} 