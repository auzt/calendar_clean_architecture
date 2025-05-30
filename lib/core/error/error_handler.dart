// lib/core/error/error_handler.dart
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'exceptions.dart';
import 'failures.dart';

class ErrorHandler {
  static Failure handleException(dynamic error) {
    if (error is DioException) {
      return _handleDioError(error);
    } else if (error is SocketException) {
      return const NetworkFailure('Tidak ada koneksi internet');
    } else if (error is ServerException) {
      return ServerFailure(error.message, statusCode: error.statusCode);
    } else if (error is CacheException) {
      return CacheFailure(error.message);
    } else if (error is NetworkException) {
      return NetworkFailure(error.message);
    } else if (error is AuthException) {
      return AuthFailure(error.message);
    } else if (error is ValidationException) {
      return ValidationFailure(error.message);
    } else {
      return Failure(
        'Terjadi kesalahan yang tidak diketahui: ${error.toString()}',
      );
    }
  }

  static Failure _handleDioError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const NetworkFailure('Koneksi timeout, coba lagi nanti');

      case DioExceptionType.badResponse:
        return _handleHttpError(
          error.response?.statusCode ?? 500,
          error.response?.data?['message'] ?? 'Server error',
        );

      case DioExceptionType.cancel:
        return const NetworkFailure('Request dibatalkan');

      case DioExceptionType.connectionError:
        return const NetworkFailure('Tidak dapat terhubung ke server');

      default:
        return const NetworkFailure('Terjadi kesalahan jaringan');
    }
  }

  static Failure _handleHttpError(int statusCode, String message) {
    switch (statusCode) {
      case 400:
        return ValidationFailure('Request tidak valid: $message');
      case 401:
        return const AuthFailure('Sesi telah berakhir, silakan login kembali');
      case 403:
        return const AuthFailure('Akses ditolak');
      case 404:
        return const ServerFailure('Data tidak ditemukan');
      case 429:
        return const ServerFailure('Terlalu banyak request, coba lagi nanti');
      case 500:
      case 502:
      case 503:
        return const ServerFailure('Server sedang bermasalah, coba lagi nanti');
      default:
        return ServerFailure('Server error: $message', statusCode: statusCode);
    }
  }

  static void logError(dynamic error, [StackTrace? stackTrace]) {
    if (kDebugMode) {
      print('🚨 Error: $error');
      if (stackTrace != null) {
        print('📍 Stack trace: $stackTrace');
      }
    }
  }
}
