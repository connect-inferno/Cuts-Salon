import 'package:firebase_core/firebase_core.dart';

// Each salon gets its own Firebase project (Firestore quotas/free-tier are
// per-project, so one salon's usage can never eat into another's). Since
// Firebase Auth is also per-project, there's no single place to ask "which
// project does this email belong to" the way the old backend's
// globally-unique User.email column let us - so login doesn't look anything
// up by email at all. Instead it tries every configured project in turn
// (see salon_auth.dart's signIn) and only falls back to the REST backend if
// none of them accept the credentials. That means every employee of a
// Firebase-directory salon can log in the moment their account exists in
// that salon's project, with nothing to add here per employee - only a
// whole new salon needs a new entry below.
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
