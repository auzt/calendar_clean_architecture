// lib/core/constants/app_constants.dart
class AppConstants {
  static const String appName = 'Calendar App';
  static const String hiveBoxName = 'calendar_events';

  // Cache durations
  static const Duration cacheExpiry = Duration(hours: 6);
  static const Duration syncInterval = Duration(minutes: 30);

  // UI Constants
  static const int maxEventsPerDay = 50;
  static const double cellAspectRatio = 0.8;
  static const int monthsToPreload = 3;

  // Date formats
  static const String displayDateFormat = 'EEE, d MMM yyyy';
  static const String apiDateFormat = 'yyyy-MM-ddTHH:mm:ss.SSSZ';
}
