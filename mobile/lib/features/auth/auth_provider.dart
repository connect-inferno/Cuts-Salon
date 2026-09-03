import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../firebase/salon_auth.dart';
import '../../firebase/salon_firestore.dart';
import 'auth_state.dart';

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    // Start auto login validation asynchronously
    Future.microtask(() => _tryAutoLogin());
    return AuthState();
  }

  // Resolves role/employeeProfileId/branchId from the employees/{uid}
  // Firestore doc - router.dart's OWNER/EMPLOYEE redirect and the
  // pay-redaction logic in firebase/firestore_app_data.dart both depend on
  // `role` actually being set here, not left null.
  Future<AuthState> _stateFromFirebase(SalonLoginResult session) async {
    final fs = SalonFirestore(session.app);
    final profile = await fs.getEmployee(session.user.uid);
    if (profile == null) {
      throw SalonAuthException('Your account is signed in but has no employee profile yet. Ask the salon owner to finish setting it up.');
    }
    final settings = await fs.getSettings();
    return AuthState(
      isLoading: false,
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
      state = state.copyWith(isLoading: false);
      return;
    }

    try {
      state = await _stateFromFirebase(firebaseSession);
    } catch (e) {
      state = AuthState(error: e.toString(), isLoading: false);
    }
  }

  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final session = await SalonAuth.signIn(email, password);
      state = await _stateFromFirebase(session);
    } catch (e) {
      state = AuthState(error: e.toString(), isLoading: false);
    }
  }

  Future<void> logout() async {
    state = state.copyWith(isLoading: true);
    if (state.salonId != null) {
      await SalonAuth.signOut(state.salonId!);
    }
    state = AuthState();
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(() {
  return AuthController();
});
