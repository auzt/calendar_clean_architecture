// lib/core/constants/google_oauth_config.dart
import 'dart:io';
import 'package:flutter/foundation.dart';

class GoogleOAuthConfig {
  // ✅ Client ID yang Anda dapatkan dari Google Cloud Console
  static const String webClientId =
      '924202442883-0ghnjhqh5ni0mis42b3s32u3aev1k6l4.apps.googleusercontent.com';

  // ⚠️ PENTING: Untuk Android dan iOS, Anda perlu membuat Client ID terpisah
  // di Google Cloud Console untuk setiap platform
  static const String androidClientId =
      '924202442883-0ghnjhqh5ni0mis42b3s32u3aev1k6l4.apps.googleusercontent.com'; // Gunakan yang sama dulu untuk testing
  static const String iosClientId =
      '924202442883-0ghnjhqh5ni0mis42b3s32u3aev1k6l4.apps.googleusercontent.com'; // Gunakan yang sama dulu untuk testing

  // Calendar API Scopes
  static const List<String> scopes = [
    'https://www.googleapis.com/auth/calendar',
    'https://www.googleapis.com/auth/calendar.events',
    'https://www.googleapis.com/auth/calendar.readonly',
  ];

  // Project Info
  static const String projectNumber = '924202442883';

  // Server Auth Code untuk server-side authentication jika diperlukan
  static const String serverClientId = webClientId;

  // Redirect URIs (untuk development)
  static const List<String> redirectUris = [
    'http://localhost:3000',
    'http://localhost:8080',
    'https://your-domain.com', // Ganti dengan domain Anda
  ];

  // Get Client ID based on platform
  static String get clientId {
    if (kIsWeb) {
      return webClientId;
    } else if (Platform.isAndroid) {
      return androidClientId;
    } else if (Platform.isIOS) {
      return iosClientId;
    }
    return webClientId; // fallback
  }

  // Platform check helper
  static bool get isWeb => kIsWeb;
  static bool get isAndroid => !kIsWeb && Platform.isAndroid;
  static bool get isIOS => !kIsWeb && Platform.isIOS;

  // Development mode flag
  static const bool isDevelopment = true; // Set ke false untuk production

  // Debug flags
  static const bool enableDebugLogs = isDevelopment;
  static const bool enableVerboseLogging = isDevelopment;

  // Additional configuration
  static const Duration authTimeout = Duration(seconds: 60);
  static const int maxRetryAttempts = 3;
}
