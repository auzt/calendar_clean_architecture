// lib/core/utils/date_utils.dart
import 'package:intl/intl.dart';

class AppDateUtils {
  static String formatDisplayDate(DateTime date) {
    // ✅ FIX: Hapus 'id_ID' locale
    return DateFormat('EEE, d MMM yyyy').format(date);
  }

  static String formatTime(DateTime date) {
    return DateFormat('HH:mm').format(date);
  }

  static String formatDateTime(DateTime date) {
    // ✅ FIX: Hapus 'id_ID' locale
    return DateFormat('d MMM yyyy HH:mm').format(date);
  }

  static String formatApiDate(DateTime date) {
    return date.toIso8601String();
  }

  static DateTime parseApiDate(String dateString) {
    return DateTime.parse(dateString);
  }

  static bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static bool isSameMonth(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month;
  }

  static DateTime getStartOfMonth(DateTime date) {
    return DateTime(date.year, date.month, 1);
  }

  static DateTime getEndOfMonth(DateTime date) {
    return DateTime(date.year, date.month + 1, 0, 23, 59, 59);
  }

  static DateTime getStartOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  static DateTime getEndOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day, 23, 59, 59);
  }

  static List<DateTime> getDatesInMonth(DateTime month) {
    final startOfMonth = getStartOfMonth(month);
    final endOfMonth = getEndOfMonth(month);

    final dates = <DateTime>[];
    var current = startOfMonth;

    while (current.isBefore(endOfMonth) || isSameDay(current, endOfMonth)) {
      dates.add(current);
      current = current.add(const Duration(days: 1));
    }

    return dates;
  }

  static String getDateKey(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  static DateTime? tryParseDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return null;
    try {
      return DateTime.parse(dateString);
    } catch (e) {
      return null;
    }
  }
}
