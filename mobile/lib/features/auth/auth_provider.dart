import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../firebase/firestore_models.dart';
import '../../firebase/salon_auth.dart';
import '../../firebase/salon_firestore.dart';
import 'auth_state.dart';

class AuthController extends Notifier<AuthState> {
  StreamSubscription<User?>? _authSub;

  // The settings doc sign-in already paid for, handed to the first AppData
  // load that follows so it doesn't fetch the same document again.
  //
  // Sign-in needs it for salonName (the dashboard header would otherwise
  // read "Salon" until the full load lands), and loadAppData needs it for
  // AppData.settings - so every login read settings twice, a second apart.
  // Deliberately not part of AuthState: it's a one-shot hand-off, not
  // session state, and putting it there would make every AppData rebuild
  // re-adopt a snapshot that gets staler the longer the session runs.
  FSSettings? _initialSettings;

  /// Returns the settings fetched during sign-in, once. Every later call -
  /// including [AppDataNotifier.refresh] - gets null and fetches its own, so
  /// a stale doc can never be served twice.
  FSSettings? consumeInitialSettings() {
    final settings = _initialSettings;
    _initialSettings = null;
    return settings;
  }

  @override
  AuthState build() {
    ref.onDispose(() {
      _authSub?.cancel();
      _authSub = null;
    });
    // Start auto login validation asynchronously
    Future.microtask(() => _tryAutoLogin());
    return AuthState();
  }

  // Firebase Auth persists to IndexedDB/localStorage, which every tab on this
  // origin shares (see the comment in SalonAuth._trySignIn re: persistence).
  // So signing in as someone else in a second tab swaps the credential out
  // from under this one - and because our own session lives in this Notifier's
  // memory, the stale tab would happily keep rendering the previous user's
  // dashboard while its Firestore requests carried the new user's token.
  // Watching the stream lets us catch that and drop the tab back to login
  // instead of acting as the wrong person.
  void _watchForIdentityChange(SalonLoginResult session) {
    _authSub?.cancel();
    final selfUid = session.user.uid;
    _authSub = FirebaseAuth.instanceFor(app: session.app).authStateChanges().listen((user) {
      if (user != null && user.uid == selfUid) return;
      // Our own logout() already resets state and cancels this, so anything
      // reaching here is another tab (or a revoked session) taking over.
      if (!state.isAuthenticated) return;
      _authSub?.cancel();
      _authSub = null;
      state = AuthState(
        sessionChecked: true,
        error: user == null
            ? 'You were signed out. Please log in again.'
            : 'This browser signed in as a different user in another tab, so this tab was signed out. Please log in again.',
      );
    });
  }

  // Resolves role/employeeProfileId/branchId from the employees/{uid}
  // Firestore doc - router.dart's OWNER/EMPLOYEE redirect and the
  // pay-redaction logic in firebase/firestore_app_data.dart both depend on
  // `role` actually being set here, not left null.
  Future<AuthState> _stateFromFirebase(SalonLoginResult session) async {
    // Before the first query on this app: Firestore refuses to turn the
    // local cache on once an instance has been used. This is the earliest
    // point a salon's app is known, and every later read - here and in
    // loadAppData - goes through it.
    await SalonFirestore.enablePersistence(session.app);
    final fs = SalonFirestore(session.app);
    // Fetched together rather than one after the other: neither depends on
    // the other, and sign-in already costs two Firebase app inits plus the
    // auth round trip before this point, so a needless serial hop here is
    // directly visible as login lag.
    final results = await Future.wait([
      fs.getEmployee(session.user.uid),
      fs.getSettings(),
    ]);
    final profile = results[0] as FSEmployee?;
    final settings = results[1] as FSSettings;
    if (profile == null) {
      throw SalonAuthException('Your account is signed in but has no employee profile yet. Ask the salon owner to finish setting it up.');
    }
    // Set before the state assignment that triggers appDataProvider's
    // build(), so the load about to start can pick it up.
    _initialSettings = settings;
    return AuthState(
      isLoading: false,
      sessionChecked: true,
      userId: session.user.uid,
      email: session.user.email,
      name: profile.name,
      role: profile.role,
      employeeProfileId: profile.id,
      branchId: profile.branchId,
      salonId: session.salonId,
      salonName: settings.salonName,
    );
  }

  Future<void> _tryAutoLogin() async {
    state = state.copyWith(isLoading: true);

    SalonLoginResult? firebaseSession;
    try {
      firebaseSession = await SalonAuth.restoreSession();
    } catch (_) {
      // A broken/expired local Firebase session shouldn't block the login
      // screen from rendering - fall through to it below.
    }
    if (firebaseSession == null) {
      // Distinguish "never signed in here" from "was signed in, credential is
      // gone". The second is what a Safari ITP storage eviction looks like,
      // and landing on a blank login form with no explanation reads as a bug.
      final hadSession = await SalonAuth.hadSessionButLostIt();
      state = state.copyWith(
        isLoading: false,
        sessionChecked: true,
        error: hadSession ? 'Your session expired. Please sign in again.' : null,
      );
      return;
    }

    try {
      state = await _stateFromFirebase(firebaseSession);
      _watchForIdentityChange(firebaseSession);
    } catch (e) {
      state = AuthState(error: e.toString(), isLoading: false, sessionChecked: true);
    }
  }

  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final session = await SalonAuth.signIn(email, password);
      state = await _stateFromFirebase(session);
      _watchForIdentityChange(session);
    } catch (e) {
      state = AuthState(error: e.toString(), isLoading: false, sessionChecked: true);
    }
  }

  Future<void> logout() async {
    _authSub?.cancel();
    _authSub = null;
    final salonId = state.salonId;
    // Drop the session *before* signing out, not after. appDataProvider
    // watches this Notifier and rebuilds on every state change, so the old
    // `copyWith(isLoading: true)` left userId set and made its build() run as
    // a still-authenticated user: a full reload of every collection in the
    // salon, fired against Firestore at the exact moment the credential was
    // being revoked, and thrown away either way. Clearing first means that
    // rebuild sees a logged-out user and returns the empty snapshot without
    // touching the network.
    state = AuthState(sessionChecked: true);
    if (salonId != null) {
      await SalonAuth.signOut(salonId);
    }
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(() {
  return AuthController();
});
