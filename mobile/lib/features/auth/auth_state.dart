class AuthState {
  final bool isLoading;
  final String? token;
  final String? error;
  final String? email;
  final String? name;
  final String? role; // 'OWNER' or 'EMPLOYEE'

  AuthState({
    this.isLoading = false,
    this.token,
    this.error,
    this.email,
    this.name,
    this.role,
  });

  bool get isAuthenticated => token != null;

  AuthState copyWith({
    bool? isLoading,
    String? token,
    String? error,
    String? email,
    String? name,
    String? role,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      token: token ?? this.token,
      error: error ?? this.error,
      email: email ?? this.email,
      name: name ?? this.name,
      role: role ?? this.role,
    );
  }
}
