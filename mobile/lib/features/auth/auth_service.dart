class AuthService {
  AuthService();

  Future<Map<String, dynamic>> login(String email, String password) async {
    // Simulate minor network delay
    await Future.delayed(const Duration(milliseconds: 600));

    if (password != 'password123') {
      throw Exception('Invalid password. Use "password123" for demo.');
    }

    final isOwner = email.toLowerCase().contains('owner');
    final isEmployee = email.toLowerCase().contains('employee');

    if (!isOwner && !isEmployee) {
      throw Exception('Invalid email. Use owner@salon.com or employee@salon.com');
    }

    if (isOwner) {
      return {
        'token': 'mock_owner_token',
        'user': {
          'email': email,
          'role': 'OWNER',
          'profile': {'name': 'Alex Mercer'},
        }
      };
    } else {
      return {
        'token': 'mock_employee_token',
        'user': {
          'email': email,
          'role': 'EMPLOYEE',
          'profile': {'name': 'Sarah Connor'},
        }
      };
    }
  }

  Future<Map<String, dynamic>> getMe(String token) async {
    await Future.delayed(const Duration(milliseconds: 100));
    if (token == 'mock_owner_token') {
      return {
        'email': 'owner@salon.com',
        'role': 'OWNER',
        'profile': {'name': 'Alex Mercer'},
      };
    } else if (token == 'mock_employee_token') {
      return {
        'email': 'employee@salon.com',
        'role': 'EMPLOYEE',
        'profile': {'name': 'Sarah Connor'},
      };
    }
    throw Exception('Invalid token');
  }
}

