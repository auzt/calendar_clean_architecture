// lib/core/network/api_client.dart
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../error/error_handler.dart';

class ApiClient {
  late final Dio _dio;
  static ApiClient? _instance;

  ApiClient._internal() {
    _dio = Dio();
    _setupInterceptors();
  }

  factory ApiClient() {
    return _instance ??= ApiClient._internal();
  }

  Dio get dio => _dio;

  void _setupInterceptors() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (kDebugMode) {
            print('🔗 REQUEST: ${options.method} ${options.uri}');
            print('📝 Headers: ${options.headers}');
            if (options.data != null) {
              print('📄 Data: ${options.data}');
            }
          }
          handler.next(options);
        },
        onResponse: (response, handler) {
          if (kDebugMode) {
            print(
              '✅ RESPONSE: ${response.statusCode} ${response.requestOptions.uri}',
            );
          }
          handler.next(response);
        },
        onError: (error, handler) {
          ErrorHandler.logError(error);
          if (kDebugMode) {
            print('❌ ERROR: ${error.requestOptions.uri}');
            print('📄 Error Data: ${error.response?.data}');
          }
          handler.next(error);
        },
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          // Add default headers
          options.headers.addAll({
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          });
          handler.next(options);
        },
      ),
    );
  }

  void updateTimeout({
    Duration? connectTimeout,
    Duration? receiveTimeout,
    Duration? sendTimeout,
  }) {
    _dio.options = _dio.options.copyWith(
      connectTimeout: connectTimeout ?? const Duration(seconds: 30),
      receiveTimeout: receiveTimeout ?? const Duration(seconds: 30),
      sendTimeout: sendTimeout ?? const Duration(seconds: 30),
    );
  }

  void addAuthHeader(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  void removeAuthHeader() {
    _dio.options.headers.remove('Authorization');
  }
}
