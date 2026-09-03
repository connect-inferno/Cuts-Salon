import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'salon_directory.dart';

class SalonLoginResult {
  final String salonId;
  final FirebaseApp app;
  final User user;
  SalonLoginResult({required this.salonId, required this.app, required this.user});
}

class SalonAuthException implements Exception {
  final String message;
  SalonAuthException(this.message);
  @override
  String toString() => message;
}

class SalonAuth {
  static const _storage = FlutterSecureStorage();
  static const _lastSalonIdKey = 'firebase_last_salon_id';
  static const _lastEmailKey = 'firebase_last_email';

  // Firebase.initializeApp throws if called twice with the same name - this
  // can happen across a hot restart on web, or if sign-in runs again after
  // a restored session, so always check Firebase.apps first.
  static Future<FirebaseApp> _appFor(SalonFirebaseConfig config) async {
    final existing = Firebase.apps.where((a) => a.name == config.salonId);
    if (existing.isNotEmpty) return existing.first;
    return Firebase.initializeApp(name: config.salonId, options: config.options);
  }

  // Tries every configured salon project in turn rather than looking one up
  // by email - there are only a handful of salons, so trying them all is
  // cheap, and it means a newly-created employee can log in the moment
  // their account exists in their salon's project, with no per-employee
  // entry needed anywhere. AuthController.login() only falls back to the
  // REST backend once every project here has rejected the credentials.
  static Future<SalonLoginResult> signIn(String email, String password) async {
    for (final config in salonFirebaseConfigs) {
      final app = await _appFor(config);
      try {
        final credential = await FirebaseAuth.instanceFor(app: app).signInWithEmailAndPassword(email: email, password: password);
        final user = credential.user;
        if (user == null) continue;

        await _storage.write(key: _lastSalonIdKey, value: config.salonId);
        await _storage.write(key: _lastEmailKey, value: email.trim().toLowerCase());

        return SalonLoginResult(salonId: config.salonId, app: app, user: user);
      } on FirebaseAuthException {
        // Wrong password and "no such user" are deliberately indistinguishable
        // in modern Firebase Auth error codes (anti-enumeration) - either way,
        // just try the next project.
        continue;
      }
    }
    // Same generic message regardless of which step failed - don't reveal
    // whether an email exists in any salon's directory.
    throw SalonAuthException('Invalid email or password');
  }

  // Called on app startup, before showing the login screen - restores a
  // previous session the same way the old REST backend's "read stored JWT,
  // call /auth/me" flow did.
  static Future<SalonLoginResult?> restoreSession() async {
    final salonId = await _storage.read(key: _lastSalonIdKey);
    final email = await _storage.read(key: _lastEmailKey);
    if (salonId == null || email == null) return null;

    final config = configForSalonId(salonId);
    if (config == null) return null;

    final app = await _appFor(config);
    final auth = FirebaseAuth.instanceFor(app: app);
    // authStateChanges().first waits for Firebase Auth's async local-session
    // check to resolve, rather than reading currentUser before it's loaded.
    final user = await auth.authStateChanges().first;
    if (user == null) return null;

    return SalonLoginResult(salonId: config.salonId, app: app, user: user);
  }

  // Looks up the already-initialized named app for a salon that's currently
  // logged in - safe any time after a successful signIn/restoreSession,
  // since both guarantee this app exists in Firebase.apps by then.
  static FirebaseApp? currentApp(String salonId) {
    final matches = Firebase.apps.where((a) => a.name == salonId);
    return matches.isEmpty ? null : matches.first;
  }

  static Future<void> signOut(String salonId) async {
    final config = configForSalonId(salonId);
    if (config != null) {
      final app = await _appFor(config);
      await FirebaseAuth.instanceFor(app: app).signOut();
    }
    await _storage.delete(key: _lastSalonIdKey);
    await _storage.delete(key: _lastEmailKey);
  }

  // Creates a new employee's Firebase Auth account without disturbing the
  // owner's own signed-in session: there's no Admin SDK (no server), so the
  // standard client-side workaround is to sign up on a throwaway secondary
  // named FirebaseApp pointed at the same project, then discard just that
  // local app/session object. The account itself is created for real in the
  // project - only the temporary local handle is thrown away.
  static Future<String> createEmployeeAccount(FirebaseApp ownerApp, String email, String password) async {
    final tempApp = await Firebase.initializeApp(
      name: '${ownerApp.name}-create-${DateTime.now().microsecondsSinceEpoch}',
      options: ownerApp.options,
    );
    try {
      final credential = await FirebaseAuth.instanceFor(app: tempApp).createUserWithEmailAndPassword(email: email, password: password);
      final uid = credential.user?.uid;
      if (uid == null) throw SalonAuthException('Could not create the employee account');
      return uid;
    } on FirebaseAuthException catch (e) {
      throw SalonAuthException(_authErrorMessage(e));
    } finally {
      // Only tears down the temporary local app/session - the Auth account
      // just created above remains in the project.
      await tempApp.delete();
    }
  }

  // The only client-side equivalent of the REST backend's owner-set-a-known-
  // password reset (employee.service.ts's resetPassword) - Firebase's client
  // SDK can't set another user's password without the Admin SDK, so the
  // owner can only trigger Firebase's own reset-link email instead of
  // choosing the new password directly. A real, deliberate capability
  // difference - see owner_customers_employees_tab.dart's reset dialog.
  static Future<void> sendPasswordResetEmail(FirebaseApp app, String email) async {
    try {
      await FirebaseAuth.instanceFor(app: app).sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw SalonAuthException(_authErrorMessage(e));
    }
  }

  // Unlike resetting a *coworker's* password (createEmployeeAccount /
  // sendPasswordResetEmail above), Firebase's client SDK can change the
  // currently-signed-in user's OWN password directly - no workaround
  // needed. updatePassword() alone throws requires-recent-login if the
  // session is old, so reauthenticate with the current password first,
  // which conveniently also verifies it's correct - the same check the
  // REST backend's changePassword endpoint makes server-side.
  static Future<void> changeOwnPassword(FirebaseApp app, {required String currentPassword, required String newPassword}) async {
    final auth = FirebaseAuth.instanceFor(app: app);
    final user = auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) throw SalonAuthException('Not signed in');

    try {
      await user.reauthenticateWithCredential(EmailAuthProvider.credential(email: email, password: currentPassword));
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        throw SalonAuthException('Current password is incorrect');
      }
      throw SalonAuthException(_authErrorMessage(e));
    }
  }

  static String _authErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'A user with this email already exists';
      case 'weak-password':
        return 'Password must be at least 6 characters';
      case 'invalid-email':
        return 'Invalid email address';
      case 'user-not-found':
        return 'No account found for this email';
      default:
        return e.message ?? 'Something went wrong';
    }
  }
}
