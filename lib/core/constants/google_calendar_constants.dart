// lib/core/constants/google_calendar_constants.dart
class GoogleCalendarConstants {
  static const List<String> scopes = [
    'https://www.googleapis.com/auth/calendar',
    'https://www.googleapis.com/auth/calendar.events',
  ];

  static const String primaryCalendarId = 'primary';
  static const int maxEventsPerRequest = 2500;
  static const String timeZone = 'Asia/Jakarta';

  // Error messages
  static const String authFailedMessage = 'Gagal login ke Google Calendar';
  static const String networkErrorMessage = 'Tidak ada koneksi internet';
  static const String syncFailedMessage =
      'Gagal sinkronisasi dengan Google Calendar';
}
