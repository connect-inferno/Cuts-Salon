import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

// A tiny, separate Firebase project whose only job is answering "which
// salon does this email belong to" - so sign-in (salon_auth.dart) can go
// straight to the one right project instead of trying every configured
// salon in turn, which gets slower with every salon added.
//
// This project holds nothing sensitive: no passwords, no salon data, just
// a lowercase-email -> salonId pointer (collection `emailDirectory`, doc id
// = the email itself). The real password check always still happens at the
// target salon's own Firebase Auth, exactly as before - this project can't
// authenticate anyone by itself. A compromise here could misdirect a login
// attempt at a lookup that then fails, but can never itself leak a
// password or a salon's data, which is why it's safe for its Firestore
// rules to allow unauthenticated reads (see mobile/firebase-directory.rules)
// while writes stay fully locked down to manual/Console-only.
//
// Wired to the `salon-saas-87b6a` project (see CLAUDE.md's "Setting up the
// login directory" and "Operator salon registry" sections) - its Firestore
// rules (mobile/firebase-directory.rules) are deployed there, holding
// emailDirectory/{email} -> { salonId } for this fast path, plus the
// unrelated salons/{salonId} operator registry.
const bool directoryConfigured = true;

const FirebaseOptions _directoryOptions = FirebaseOptions(
  apiKey: 'AIzaSyDrSnMjasqY_Ak0VEP-L9dRUuBwekUITVw',
  authDomain: 'salon-saas-87b6a.firebaseapp.com',
  projectId: 'salon-saas-87b6a',
  storageBucket: 'salon-saas-87b6a.firebasestorage.app',
  messagingSenderId: '613090667402',
  appId: '1:613090667402:web:1fdc8762956a4c7f05f673',
);

const String _directoryAppName = 'login-directory';

Future<FirebaseApp> _directoryApp() async {
  final existing = Firebase.apps.where((a) => a.name == _directoryAppName);
  if (existing.isNotEmpty) return existing.first;
  return Firebase.initializeApp(name: _directoryAppName, options: _directoryOptions);
}

// Returns null whenever the fast path can't be used for any reason - the
// directory isn't configured yet, this email isn't registered in it, or
// the lookup itself fails (network, project not reachable, etc.). Every
// case means exactly the same thing to the caller: fall back to the
// try-every-project loop. This never throws - a directory outage should
// degrade sign-in speed, not break it.
Future<String?> lookupSalonIdForEmail(String email) async {
  if (!directoryConfigured) return null;
  try {
    final app = await _directoryApp();
    final doc = await FirebaseFirestore.instanceFor(app: app).collection('emailDirectory').doc(email.trim().toLowerCase()).get();
    return doc.data()?['salonId'] as String?;
  } catch (_) {
    return null;
  }
}
