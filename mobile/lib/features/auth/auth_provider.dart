import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';
import 'auth_state.dart';
import 'auth_service.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService(ref.read(apiClientProvider)));

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    // Start auto login validation asynchronously
    Future.microtask(() => _tryAutoLogin());
    return AuthState();
  }

  AuthState _stateFromUser(String token, Map<String, dynamic> user, Map<String, dynamic>? salon) {
    final profile = user['profile'] as Map<String, dynamic>?;
    return AuthState(
      token: token,
      userId: user['id'] as String?,
      email: user['email'] as String?,
      name: profile?['name'] as String? ?? (user['role'] == 'OWNER' ? 'Owner' : 'Staff'),
      role: user['role'] as String?,
      employeeProfileId: profile?['id'] as String?,
      branchId: profile?['branchId'] as String?,
      salonId: salon?['id'] as String?,
      salonName: salon?['name'] as String?,
      isLoading: false,
    );
  }

  Future<void> _tryAutoLogin() async {
    state = state.copyWith(isLoading: true);
    final storage = ref.read(secureStorageProvider);
    final token = await storage.read(key: 'auth_token');
    if (token == null) {
      state = state.copyWith(isLoading: false);
      return;
    }

    try {
      final authService = ref.read(authServiceProvider);
      final user = await authService.getMe();
      state = _stateFromUser(token, user, user['salon'] as Map<String, dynamic>?);
    } catch (e) {
      await storage.delete(key: 'auth_token');
      state = AuthState(error: e.toString(), isLoading: false);
    }
  }

  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final authService = ref.read(authServiceProvider);
      final storage = ref.read(secureStorageProvider);

      final result = await authService.login(email, password);
      final token = result['token'] as String;
      final user = result['user'] as Map<String, dynamic>;
      final salon = result['salon'] as Map<String, dynamic>?;

      await storage.write(key: 'auth_token', value: token);
      state = _stateFromUser(token, user, salon);
    } catch (e) {
      state = AuthState(error: e.toString(), isLoading: false);
    }
  }

  Future<void> logout() async {
    state = state.copyWith(isLoading: true);
    final storage = ref.read(secureStorageProvider);
    await storage.delete(key: 'auth_token');
    state = AuthState();
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(() {
  return AuthController();
});
