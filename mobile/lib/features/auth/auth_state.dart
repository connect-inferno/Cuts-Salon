// Sentinel so copyWith can tell "error not passed" apart from
// "error explicitly cleared to null" - `error: error ?? this.error` would
// otherwise make copyWith(error: null) a no-op and leave a stale error
// message stuck forever (it can never again differ from `previous.error`,
// so the login screen's ref.listen SnackBar never re-fires on repeat
// failures).
const _unset = Object();

class AuthState {
  final bool isLoading;
  // False only until the initial auto-login check (restoring a persisted
  // Firebase session) resolves - router.dart holds the app on a splash
  // screen while this is false so it never flashes the login form for an
  // already-logged-in user. See AuthController._tryAutoLogin.
  final bool sessionChecked;
  final String? error;
  final String? userId;
  final String? email;
  final String? name;
  final String? role; // 'OWNER' or 'EMPLOYEE'
  final String? employeeProfileId;
  final String? branchId; // the employee's own branch; null for OWNER
  final String? salonId;
  final String? salonName;

  AuthState({
    this.isLoading = false,
    this.sessionChecked = false,
    this.error,
    this.userId,
    this.email,
    this.name,
    this.role,
    this.employeeProfileId,
    this.branchId,
    this.salonId,
    this.salonName,
  });

  bool get isAuthenticated => userId != null;
  bool get isOwner => role == 'OWNER';

  AuthState copyWith({
    bool? isLoading,
    bool? sessionChecked,
    Object? error = _unset,
    String? userId,
    String? email,
    String? name,
    String? role,
    String? employeeProfileId,
    String? branchId,
    String? salonId,
    String? salonName,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      sessionChecked: sessionChecked ?? this.sessionChecked,
      error: identical(error, _unset) ? this.error : error as String?,
      userId: userId ?? this.userId,
      email: email ?? this.email,
      name: name ?? this.name,
      role: role ?? this.role,
      employeeProfileId: employeeProfileId ?? this.employeeProfileId,
      branchId: branchId ?? this.branchId,
      salonId: salonId ?? this.salonId,
      salonName: salonName ?? this.salonName,
    );
  }
}
