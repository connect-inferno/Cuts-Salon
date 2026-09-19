import 'package:firebase_core/firebase_core.dart';

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
  final FirebaseOptions options;

  const SalonFirebaseConfig({required this.salonId, required this.options});
}

const List<SalonFirebaseConfig> salonFirebaseConfigs = [
  SalonFirebaseConfig(
    salonId: 'cuts-salon',
    options: FirebaseOptions(
      apiKey: 'AIzaSyAwDOs0LypNlrLKcXxOCevtsOakg6O4f8E',
      authDomain: 'cuts-salon.firebaseapp.com',
      projectId: 'cuts-salon',
      storageBucket: 'cuts-salon.firebasestorage.app',
      messagingSenderId: '149609558350',
      appId: '1:149609558350:web:6c3112390aaaa7f9cbeef1f',
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
