// lib/core/constants/google_calendar_constants.dart
import 'google_oauth_config.dart';

class GoogleCalendarConstants {
  // ✅ Menggunakan scopes dari OAuth config
  static const List<String> scopes = GoogleOAuthConfig.scopes;

  static const String primaryCalendarId = 'primary';
  static const int maxEventsPerRequest = 2500;
  static const String timeZone = 'Asia/Jakarta';

  // ✅ Client ID berdasarkan platform
  static String get clientId => GoogleOAuthConfig.clientId;

  // ✅ Project number dari OAuth config
  static String get projectNumber => GoogleOAuthConfig.projectNumber;

  // API Configuration
  static const String calendarApiBaseUrl =
      'https://www.googleapis.com/calendar/v3';
  static const String authApiBaseUrl = 'https://oauth2.googleapis.com';

  // Cache and sync settings
  static const Duration cacheExpiry = Duration(hours: 6);
  static const Duration syncInterval = Duration(minutes: 30);
  static const Duration authTimeout = GoogleOAuthConfig.authTimeout;

  // Retry configuration
  static const int maxRetryAttempts = GoogleOAuthConfig.maxRetryAttempts;
  static const Duration retryDelay = Duration(seconds: 2);

  // Error messages (Indonesian)
  static const String authFailedMessage = 'Gagal login ke Google Calendar';
  static const String networkErrorMessage = 'Tidak ada koneksi internet';
  static const String syncFailedMessage =
      'Gagal sinkronisasi dengan Google Calendar';
  static const String permissionDeniedMessage =
      'Akses ditolak. Mohon berikan izin untuk mengakses Google Calendar';
  static const String quotaExceededMessage =
      'Batas quota API terlampaui. Coba lagi nanti';
  static const String timeoutMessage =
      'Koneksi timeout. Periksa koneksi internet Anda';

  // Success messages
  static const String authSuccessMessage = 'Berhasil login ke Google Calendar';
  static const String syncSuccessMessage = 'Sinkronisasi berhasil';
  static const String logoutSuccessMessage =
      'Berhasil logout dari Google Calendar';

  // Event colors mapping (Google Calendar color IDs)
  static const Map<String, String> eventColors = {
    'blue': '1',
    'green': '2',
    'purple': '3',
    'red': '4',
    'orange': '5',
    'teal': '6',
    'cyan': '7',
    'grey': '8',
    'indigo': '9',
    'lime': '10',
    'pink': '11',
  };

  // Default settings
  static const String defaultTimeZone = timeZone;
  static const String defaultEventColor = '1'; // Blue
  static const bool defaultAllDayEvent = false;
  static const Duration defaultEventDuration = Duration(hours: 1);

  // Notification settings
  static const List<int> defaultReminderMinutes = [15, 30]; // Default reminders
  static const int maxReminders = 5;

  // Calendar limits
  static const int maxEventTitleLength = 1024;
  static const int maxEventDescriptionLength = 8192;
  static const int maxEventLocationLength = 1024;

  // Development flags
  static bool get isDevelopment => GoogleOAuthConfig.isDevelopment;
  static bool get enableDebugLogs => isDevelopment;
  static bool get enableVerboseLogging => isDevelopment;
}
