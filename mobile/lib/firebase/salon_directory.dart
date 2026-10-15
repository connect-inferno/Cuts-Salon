import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

// Each salon gets its own Firebase project (Firestore quotas/free-tier are
// per-project, so one salon's usage can never eat into another's). Since
// Firebase Auth is also per-project, there's no built-in place to ask
// "which project does this email belong to" - login_directory.dart is the
// (optional, currently unconfigured) fast answer to that; salon_auth.dart's
// signIn() falls back to trying every project below in turn whenever that
// fast path can't be used. Either way, every employee of a salon listed
// here can log in the moment their account exists in that salon's project,
// with nothing to add here per employee - only a whole new salon needs a
// new entry below.
//
// Firebase web config values (apiKey, appId, etc.) are not secrets - Google's
// own docs say they're safe in client code. The real access boundary is
// Firestore Security Rules + Firebase Auth, not hiding these values.
class SalonFirebaseConfig {
  final String salonId;

  /// The web app's config - what the Vercel build uses.
  final FirebaseOptions options;

  /// The Android app's config ("Stylux Android", package
  /// com.client.salon.mobile, registered in this salon's project). Android
  /// needs its own app ID and API key; the web ones aren't meant for it.
  final FirebaseOptions? androidOptions;

  const SalonFirebaseConfig({required this.salonId, required this.options, this.androidOptions});

  /// The config for the platform this build is running on.
  FirebaseOptions get platformOptions => forPlatform(options, androidOptions);
}

/// [android] on an Android build when there is one, [web] otherwise.
FirebaseOptions forPlatform(FirebaseOptions web, FirebaseOptions? android) =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android && android != null ? android : web;

const List<SalonFirebaseConfig> salonFirebaseConfigs = [
  SalonFirebaseConfig(
    salonId: 'cuts-salon',
    options: FirebaseOptions(
      apiKey: 'AIzaSyAwDOs0LypNlrLKcXxOCevtsOakg6O4f8E',
      authDomain: 'cuts-salon.firebaseapp.com',
      projectId: 'cuts-salon',
      storageBucket: 'cuts-salon.firebasestorage.app',
      messagingSenderId: '149609558350',
      appId: '1:149609558350:web:6c3112390aaaa7f9cbee1f',
    ),
    androidOptions: FirebaseOptions(
      apiKey: 'AIzaSyC5N8EMKjjebjU3U47gS-uyAE_Cby-Qakc',
      appId: '1:149609558350:android:b65f682f8f23e469cbee1f',
      messagingSenderId: '149609558350',
      projectId: 'cuts-salon',
      storageBucket: 'cuts-salon.firebasestorage.app',
    ),
  ),
  SalonFirebaseConfig(
    salonId: 'instyle-salon',
    options: FirebaseOptions(
      apiKey: 'AIzaSyBpZdX-4FN18X6W3m8sn71TJuFpCArsW98',
      authDomain: 'instyle-salon.firebaseapp.com',
      projectId: 'instyle-salon',
      storageBucket: 'instyle-salon.firebasestorage.app',
      messagingSenderId: '103628849521',
      appId: '1:103628849521:web:4acc34e8640888197a76d0',
    ),
    androidOptions: FirebaseOptions(
      apiKey: 'AIzaSyA3y0beoiEzuX2y1XeTCP13fFFBEyqd0Io',
      appId: '1:103628849521:android:418d018293cd99737a76d0',
      messagingSenderId: '103628849521',
      projectId: 'instyle-salon',
      storageBucket: 'instyle-salon.firebasestorage.app',
    ),
  ),
  SalonFirebaseConfig(
    salonId: 'test-salon-ee06a',
    options: FirebaseOptions(
      apiKey: 'AIzaSyC6nK2ddzD9J_-H7jHjSgkJrDHQzEhJgbY',
      authDomain: 'test-salon-ee06a.firebaseapp.com',
      projectId: 'test-salon-ee06a',
      storageBucket: 'test-salon-ee06a.firebasestorage.app',
      messagingSenderId: '451342816330',
      appId: '1:451342816330:web:7030bab7c96586622e02b3',
    ),
    androidOptions: FirebaseOptions(
      apiKey: 'AIzaSyAEWP0eYm5d9mS6jqA8yw9nGRkqFH5C5tI',
      appId: '1:451342816330:android:9592618f25ef89102e02b3',
      messagingSenderId: '451342816330',
      projectId: 'test-salon-ee06a',
      storageBucket: 'test-salon-ee06a.firebasestorage.app',
    ),
  ),
];

SalonFirebaseConfig? configForSalonId(String salonId) {
  for (final config in salonFirebaseConfigs) {
    if (config.salonId == salonId) return config;
  }
  return null;
}

// Returns the already-initialized named app, or initializes it. Deliberately
// never reads Firebase.apps: on web, firebase_core_web's `apps` getter only
// tolerates "no app initialized yet" when the JS error message contains
// "of undefined" - Chrome's wording - so on Safari it rethrows instead of
// returning an empty list, and every sign-in failed before the Firebase JS
// SDK was even loaded. Firebase.app(name) throws in that state on every
// browser, which the catch below turns into "initialize it".
Future<FirebaseApp> firebaseAppNamed(String name, FirebaseOptions options) async {
  try {
    return Firebase.app(name);
  } catch (_) {
    return Firebase.initializeApp(name: name, options: options);
  }
}
