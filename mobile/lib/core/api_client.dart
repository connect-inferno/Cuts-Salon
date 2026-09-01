import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_config.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) => const FlutterSecureStorage());

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(ref.read(secureStorageProvider));
});

/// Thin wrapper around Dio: attaches the stored JWT to every request and
/// converts failures into ApiException with the backend's own `error`
/// message, so callers can just show `e.toString()` to the user.
class ApiClient {
  final FlutterSecureStorage _storage;
  late final Dio _dio;

  ApiClient(this._storage) {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 20),
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: 'auth_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
    ));
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _run(() => _dio.get(path, queryParameters: _cleanQuery(query)));

  Future<dynamic> post(String path, {dynamic data}) => _run(() => _dio.post(path, data: data));

  Future<dynamic> patch(String path, {dynamic data}) => _run(() => _dio.patch(path, data: data));

  Map<String, dynamic>? _cleanQuery(Map<String, dynamic>? query) {
    if (query == null) return null;
    final cleaned = <String, dynamic>{};
    query.forEach((key, value) {
      if (value != null) cleaned[key] = value;
    });
    return cleaned;
  }

  Future<dynamic> _run(Future<Response> Function() request) async {
    try {
      final response = await request();
      return response.data;
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map && data['error'] is String) {
        throw ApiException(data['error'] as String, statusCode: e.response?.statusCode);
      }
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionError) {
        throw ApiException('Could not reach the server. It may be waking up from sleep - try again in a moment.');
      }
      throw ApiException('Something went wrong. Please try again.', statusCode: e.response?.statusCode);
    }
  }
}
