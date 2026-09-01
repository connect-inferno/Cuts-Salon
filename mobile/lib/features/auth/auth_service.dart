import '../../core/api_client.dart';

class AuthService {
  final ApiClient _client;
  AuthService(this._client);

  Future<Map<String, dynamic>> login(String email, String password) async {
    final data = await _client.post('/api/v1/auth/login', data: {
      'email': email,
      'password': password,
    });
    return data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getMe() async {
    final data = await _client.get('/api/v1/auth/me');
    return data as Map<String, dynamic>;
  }

  Future<void> changePassword(String currentPassword, String newPassword) async {
    await _client.post('/api/v1/auth/change-password', data: {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    });
  }
}
