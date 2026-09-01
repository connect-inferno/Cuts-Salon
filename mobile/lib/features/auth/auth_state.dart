class AuthState {
  final bool isLoading;
  final String? token;
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
    this.token,
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

  bool get isAuthenticated => token != null;
  bool get isOwner => role == 'OWNER';

  AuthState copyWith({
    bool? isLoading,
    String? token,
    String? error,
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
      token: token ?? this.token,
      error: error ?? this.error,
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
