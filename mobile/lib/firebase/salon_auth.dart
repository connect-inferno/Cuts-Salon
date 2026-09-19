import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_directory.dart';
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
  static const _lastSalonIdKey = 'last_salon_id';
  static const _lastEmailKey = 'last_email';

  // SharedPreferences uses localStorage on web - simple key/value, no
  // encryption needed since we only store a salon ID and email (no passwords).
  // All methods are wrapped in try/catch: Safari in Private Browsing mode
  // blocks localStorage and throws a SecurityError, which would otherwise
  // crash the login flow.  A storage failure just means no auto-login
  // next time - the user simply logs in manually again.
  static Future<void> _safeWrite(String key, String value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, value);
    } catch (_) {
      // Storage unavailable (e.g. Safari Private Browsing) - ignore.
    }
  }

  static Future<String?> _safeRead(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(key);
    } catch (_) {
      return null;
    }
  }

  static Future<void> _safeDelete(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
    } catch (_) {
      // ignore
    }
  }

  // Firebase.initializeApp throws if called twice with the same name - this
  // can happen across a hot restart on web, or if sign-in runs again after
  // a restored session, so reuse the existing app when there is one (see
  // firebaseAppNamed for why that check must not use Firebase.apps).
  static Future<FirebaseApp> _appFor(SalonFirebaseConfig config) =>
      firebaseAppNamed(config.salonId, config.options);

  // Fast path: ask the login directory (login_directory.dart) which salon
  // this email belongs to, so sign-in only ever tries the ONE right
  // project's Firebase Auth instead of every configured salon in turn -
  // that loop gets slower with every salon added, and stays O(salon count)
  // even for a mistyped password. Falls straight through to the loop below
  // whenever the fast path can't be used: directory not configured yet,
  // email not in it, or the lookup itself fails.
  //
  // Deliberately does NOT fall through to the loop after a directory HIT
  // whose password check then fails - trying every other project too would
  // leak whether this email exists in one of them (the same anti-
  // enumeration reasoning as _credentialErrorCodes below).
  //
  // Throws SalonAuthException with the real reason for anything that isn't
  // a plain email/password mismatch (network down, too many attempts,
  // disabled account, Firebase failing to load, ...) - those used to be
  // swallowed and shown as "Invalid email or password", which hid real
  // outages (e.g. the Safari Firebase.apps bug) behind a misleading message.
  static Future<SalonLoginResult> signIn(String email, String password) async {
    final normalizedEmail = email.trim();

    final directedSalonId = await lookupSalonIdForEmail(normalizedEmail);
    if (directedSalonId != null) {
      final config = configForSalonId(directedSalonId);
      if (config != null) {
        final result = await _trySignIn(config, normalizedEmail, password);
        if (result != null) return result;
        throw SalonAuthException(_invalidCredentialsMessage);
      }
    }

    // Fallback: try every configured salon project in turn - covers salons
    // not yet added to the directory, and keeps sign-in working even if the
    // directory project itself is unreachable. A real error from one project
    // doesn't stop the loop (the account may live in a later one), but if
    // no project accepts the login, that error is what the user sees - it's
    // more useful than a generic mismatch message.
    SalonAuthException? firstRealError;
    for (final config in salonFirebaseConfigs) {
      try {
        final result = await _trySignIn(config, normalizedEmail, password);
        if (result != null) return result;
      } on SalonAuthException catch (e) {
        firstRealError ??= e;
      }
    }
    if (firstRealError != null) throw firstRealError;
    // Same generic message whichever project(s) rejected the credentials -
    // don't reveal whether an email exists in any salon's project.
    throw SalonAuthException(_invalidCredentialsMessage);
  }

  static const _invalidCredentialsMessage = 'Invalid email or password';

  static const _sdkLoadTimeout = Duration(seconds: 15);

  // Firebase Auth codes that only mean "this email/password doesn't match an
  // account in this project". With email-enumeration protection (on by
  // default) Firebase already folds wrong-password and user-not-found into
  // invalid-credential, so these all get the same generic message and let
  // the fallback loop move on to the next project.
  static const _credentialErrorCodes = {
    'invalid-credential',
    'invalid-login-credentials',
    'wrong-password',
    'user-not-found',
  };

  // Returns null when the credentials don't match an account in this
  // project; throws SalonAuthException with the real reason for any other
  // failure.
  static Future<SalonLoginResult?> _trySignIn(SalonFirebaseConfig config, String email, String password) async {
    try {
      // On web the first _appFor loads the Firebase JS SDK from gstatic.com;
      // if that script is blocked (content blocker, flaky network)
      // firebase_core_web waits for it forever, so bound it.
      final app = await _appFor(config).timeout(_sdkLoadTimeout);
      final auth = FirebaseAuth.instanceFor(app: app);

      // SESSION persistence keeps the signed-in user in sessionStorage: it
      // survives a page refresh in the same tab (restoreSession below reads
      // it back) and works in Safari Private Browsing too.
      if (kIsWeb) {
        try {
          await auth.setPersistence(Persistence.SESSION);
        } catch (_) {
          // If SESSION fails, Firebase falls back to in-memory - fine.
        }
      }

      final credential = await auth.signInWithEmailAndPassword(email: email, password: password);
      final user = credential.user;
      if (user == null) return null;

      await _safeWrite(_lastSalonIdKey, config.salonId);
      await _safeWrite(_lastEmailKey, email.toLowerCase());

      return SalonLoginResult(salonId: config.salonId, app: app, user: user);
    } on FirebaseAuthException catch (e) {
      // Wrong password / no such user - don't reveal which.
      if (_credentialErrorCodes.contains(e.code)) return null;
      debugPrint('[Trimly] sign-in to ${config.salonId} failed: ${e.code} ${e.message}');
      throw SalonAuthException(_authErrorMessage(e));
    } on TimeoutException {
      debugPrint('[Trimly] sign-in to ${config.salonId} failed: Firebase did not load within ${_sdkLoadTimeout.inSeconds}s');
      throw SalonAuthException('Could not load the sign-in service. Check your internet connection (or turn off any content blocker) and try again.');
    } catch (e) {
      // Not an Auth response at all - Firebase failed to load/initialize,
      // a JS interop error, etc. Surface it rather than blaming the password.
      debugPrint('[Trimly] sign-in to ${config.salonId} failed: $e');
      throw SalonAuthException('Could not sign in: $e');
    }
  }

  // Called on app startup, before showing the login screen - restores a
  // previous session the same way the old REST backend's "read stored JWT,
  // call /auth/me" flow did.
  static Future<SalonLoginResult?> restoreSession() async {
    final salonId = await _safeRead(_lastSalonIdKey);
    final email = await _safeRead(_lastEmailKey);
    if (salonId == null || email == null) return null;

    final config = configForSalonId(salonId);
    if (config == null) return null;

    final app = await _appFor(config);
    final auth = FirebaseAuth.instanceFor(app: app);
    // Match the SESSION persistence set during sign-in so Firebase looks in
    // sessionStorage for the saved user.
    if (kIsWeb) {
      try {
        await auth.setPersistence(Persistence.SESSION);
      } catch (_) {}
    }
    // authStateChanges().first waits for Firebase Auth's async local-session
    // check to resolve, rather than reading currentUser before it's loaded;
    // the timeout keeps a hung check from blocking the login screen.
    final user = await auth.authStateChanges().first.timeout(
      const Duration(seconds: 5),
      onTimeout: () => null,
    );
    if (user == null) return null;

    return SalonLoginResult(salonId: config.salonId, app: app, user: user);
  }

  // Looks up the already-initialized named app for a salon that's currently
  // logged in - safe any time after a successful signIn/restoreSession,
  // since both guarantee this app has been initialized by then.
  static FirebaseApp? currentApp(String salonId) {
    try {
      return Firebase.app(salonId);
    } catch (_) {
      return null;
    }
  }

  static Future<void> signOut(String salonId) async {
    final config = configForSalonId(salonId);
    if (config != null) {
      final app = await _appFor(config);
      await FirebaseAuth.instanceFor(app: app).signOut();
    }
    await _safeDelete(_lastSalonIdKey);
    await _safeDelete(_lastEmailKey);
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
      case 'user-disabled':
        return 'This account has been disabled. Ask the salon owner to re-enable it.';
      case 'too-many-requests':
        return 'Too many attempts. Wait a few minutes and try again, or reset your password.';
      case 'network-request-failed':
        return 'Could not reach the server. Check your internet connection and try again.';
      case 'operation-not-allowed':
        return 'Email/password sign-in is not enabled for this salon.';
      case 'web-storage-unsupported':
        return 'This browser is blocking the storage sign-in needs. Allow site data (or leave Private Browsing) and try again.';
      default:
        return e.message ?? 'Something went wrong';
    }
  }
}
