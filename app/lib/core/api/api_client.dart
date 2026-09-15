import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'api_exception.dart';

/// Default API base URL per platform. An Android emulator reaches the host
/// machine at 10.0.2.2; everything else talks to localhost. Override with:
///   flutter run --dart-define=WAVELENGTH_API_URL=https://api.example.com
///
/// Uses `defaultTargetPlatform` rather than `dart:io` so the same code compiles
/// for web as well as mobile and desktop.
String _defaultBaseUrl() {
  const fromEnv = String.fromEnvironment('WAVELENGTH_API_URL');
  if (fromEnv.isNotEmpty) return fromEnv;
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    return 'http://10.0.2.2:4000';
  }
  return 'http://localhost:4000';
}

typedef TokenReader = Future<String?> Function();

class ApiClient {
  ApiClient({String? baseUrl, this._readToken})
      : _dio = Dio(BaseOptions(
          baseUrl: baseUrl ?? _defaultBaseUrl(),
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 15),
          contentType: 'application/json',
        )) {
    _dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) async {
      final token = await _readToken?.call();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      handler.next(options);
    }));
  }

  final Dio _dio;
  final TokenReader? _readToken;

  String get baseUrl => _dio.options.baseUrl;

  Future<Map<String, dynamic>> get(String path) => _send(() => _dio.get(path));

  /// Sends `{}` rather than null for a body-less POST: Dio still sets a JSON
  /// content-type, and the server rejects that header with an empty body.
  Future<Map<String, dynamic>> post(String path, {Map<String, dynamic>? body}) =>
      _send(() => _dio.post(path, data: body ?? const <String, dynamic>{}));

  Future<Map<String, dynamic>> getWithQuery(String path, Map<String, dynamic> query) =>
      _send(() => _dio.get(path, queryParameters: query));

  Future<Map<String, dynamic>> patch(String path, {Map<String, dynamic>? body}) =>
      _send(() => _dio.patch(path, data: body));

  Future<Map<String, dynamic>> delete(String path, {Map<String, dynamic>? query}) =>
      _send(() => _dio.delete(path, queryParameters: query));

  Future<Map<String, dynamic>> _send(Future<Response> Function() run) async {
    try {
      final res = await run();
      final data = res.data;
      return data is Map<String, dynamic> ? data : <String, dynamic>{};
    } on DioException catch (e) {
      throw _translate(e);
    }
  }

  ApiException _translate(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['error'] is Map) {
      final err = data['error'] as Map;
      return ApiException(
        code: (err['code'] ?? 'unknown_error').toString(),
        message: (err['message'] ?? 'Something went wrong.').toString(),
        statusCode: e.response?.statusCode,
      );
    }
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout) {
      return ApiException.network();
    }
    return ApiException(
      code: 'unknown_error',
      message: 'Something went wrong. Please try again.',
      statusCode: e.response?.statusCode,
    );
  }
}
