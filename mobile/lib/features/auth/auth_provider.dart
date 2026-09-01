import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'auth_state.dart';
import 'auth_service.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());
final secureStorageProvider = Provider<FlutterSecureStorage>((ref) => const FlutterSecureStorage());

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    // Start auto login validation asynchronously
    Future.microtask(() => _tryAutoLogin());
    return AuthState();
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
      final user = await authService.getMe(token);
      state = AuthState(
        token: token,
        email: user['email'],
        name: user['profile']?['name'] ?? 'Owner Account',
        role: user['role'],
        isLoading: false,
      );
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
      final token = result['token'];
      final user = result['user'];

      await storage.write(key: 'auth_token', value: token);

      state = AuthState(
        token: token,
        email: user['email'],
        name: user['profile']?['name'] ?? 'Owner Account',
        role: user['role'],
        isLoading: false,
      );
    } catch (e) {
      state = AuthState(error: e.toString().replaceAll('Exception: ', ''), isLoading: false);
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
