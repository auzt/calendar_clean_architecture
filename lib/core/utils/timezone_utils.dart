// lib/core/utils/timezone_utils.dart
// Helper untuk debugging dan fixing timezone issues

import 'package:intl/intl.dart';

class TimezoneUtils {
  static const int jakartaOffsetHours = 7; // GMT+7
  static const String jakartaTimeZone = 'Asia/Jakarta';

  /// Debug timezone information untuk development
  static void debugTimezoneInfo({
    required DateTime originalTime,
    required String source,
    String? timeZone,
  }) {
    print('🌍 ===== TIMEZONE DEBUG ($source) =====');
    print('📅 Original: $originalTime');
    print('🕐 Is UTC: ${originalTime.isUtc}');
    print('🌏 TimeZone: ${timeZone ?? 'Unknown'}');
    print('📍 Local Now: ${DateTime.now()}');
    print('🌐 UTC Now: ${DateTime.now().toUtc()}');

    // Show different conversions
    if (originalTime.isUtc) {
      final jakartaTime = originalTime.add(Duration(hours: jakartaOffsetHours));
      print('🏠 Converted to Jakarta: $jakartaTime');
      print(
          '⏰ Difference: ${jakartaTime.difference(originalTime).inHours} hours');
    } else {
      final utcTime =
          originalTime.subtract(Duration(hours: jakartaOffsetHours));
      print('🌐 As UTC would be: $utcTime');
    }

    // Format untuk display
    print('📄 Formatted: ${formatDateTime(originalTime)}');
    print('=====================================');
  }

  /// Convert UTC time to Jakarta time
  static DateTime utcToJakarta(DateTime utcTime) {
    if (!utcTime.isUtc) {
      print('⚠️ Warning: Input time is not UTC: $utcTime');
    }
    return utcTime.add(Duration(hours: jakartaOffsetHours));
  }

  /// Convert Jakarta time to UTC
  static DateTime jakartaToUtc(DateTime jakartaTime) {
    return jakartaTime.subtract(Duration(hours: jakartaOffsetHours));
  }

  /// Smart timezone conversion - detects and fixes common issues
  static DateTime smartTimezoneConvert(DateTime inputTime,
      {String? originalTimeZone}) {
    print('🔄 Smart converting: $inputTime (tz: $originalTimeZone)');

    // If it's clearly UTC, convert to Jakarta
    if (inputTime.isUtc) {
      final converted = utcToJakarta(inputTime);
      print('✅ UTC->Jakarta: $inputTime -> $converted');
      return converted;
    }

    // If timezone indicates UTC/GMT, convert
    if (originalTimeZone != null) {
      if (originalTimeZone.contains('UTC') ||
          originalTimeZone.contains('GMT') ||
          originalTimeZone == 'Z') {
        final converted = inputTime.add(Duration(hours: jakartaOffsetHours));
        print('✅ ${originalTimeZone}->Jakarta: $inputTime -> $converted');
        return converted;
      }

      // If already Jakarta timezone, keep as is
      if (originalTimeZone.contains('Jakarta') ||
          originalTimeZone.contains('+07') ||
          originalTimeZone.contains('+0700')) {
        print('✅ Already Jakarta time: $inputTime');
        return inputTime;
      }
    }

    // Heuristic: Check if time seems wrong (too far from current time)
    final now = DateTime.now();
    final diff = inputTime.difference(now).inHours.abs();

    if (diff >= 5 && diff <= 9) {
      // Likely timezone offset issue
      final correctedPlus = inputTime.add(Duration(hours: jakartaOffsetHours));
      final correctedMinus =
          inputTime.subtract(Duration(hours: jakartaOffsetHours));

      final diffPlus = correctedPlus.difference(now).inHours.abs();
      final diffMinus = correctedMinus.difference(now).inHours.abs();

      if (diffPlus < diff && diffPlus < diffMinus) {
        print('🔧 Applied +7 correction: $inputTime -> $correctedPlus');
        return correctedPlus;
      } else if (diffMinus < diff) {
        print('🔧 Applied -7 correction: $inputTime -> $correctedMinus');
        return correctedMinus;
      }
    }

    print('✅ No conversion needed: $inputTime');
    return inputTime;
  }

  /// Format DateTime untuk display yang user-friendly
  static String formatDateTime(DateTime dateTime) {
    return DateFormat('EEE, d MMM yyyy HH:mm').format(dateTime);
  }

  /// Format time only
  static String formatTime(DateTime dateTime) {
    return DateFormat('HH:mm').format(dateTime);
  }

  /// Test timezone conversion dengan berbagai skenario
  static void testTimezoneConversions() {
    print('🧪 ===== TESTING TIMEZONE CONVERSIONS =====');

    final now = DateTime.now();
    final utcNow = DateTime.now().toUtc();

    // Test case 1: UTC to Jakarta
    print('\n1️⃣ UTC to Jakarta:');
    final utcTime = DateTime.utc(2024, 1, 15, 12, 0); // 12:00 UTC
    final jakartaTime = utcToJakarta(utcTime);
    print('   UTC: $utcTime');
    print('   Jakarta: $jakartaTime (should be 19:00)');

    // Test case 2: Jakarta to UTC
    print('\n2️⃣ Jakarta to UTC:');
    final localTime = DateTime(2024, 1, 15, 19, 0); // 19:00 Jakarta
    final convertedUtc = jakartaToUtc(localTime);
    print('   Jakarta: $localTime');
    print('   UTC: $convertedUtc (should be 12:00)');

    // Test case 3: Smart conversion
    print('\n3️⃣ Smart conversion:');
    final testTimes = [
      DateTime.utc(2024, 1, 15, 5, 0), // Should become 12:00 Jakarta
      DateTime(2024, 1, 15, 12, 0), // Should stay 12:00 if already local
    ];

    for (var testTime in testTimes) {
      final smart = smartTimezoneConvert(testTime);
      print('   Input: $testTime -> Output: $smart');
    }

    print('\n🔍 Current times:');
    print('   Local: $now');
    print('   UTC: $utcNow');
    print('   Offset hours: $jakartaOffsetHours');
    print('==========================================');
  }

  /// Validate apakah waktu event masuk akal
  static bool isTimeReasonable(DateTime eventTime) {
    final now = DateTime.now();
    final difference = eventTime.difference(now);

    // Event tidak boleh lebih dari 10 tahun di masa depan atau lampau
    if (difference.inDays.abs() > 3650) {
      print('⚠️ Unreasonable time: ${difference.inDays} days difference');
      return false;
    }

    return true;
  }

  /// Get timezone offset dari DateTime
  static int getTimezoneOffsetHours(DateTime dateTime) {
    return dateTime.timeZoneOffset.inHours;
  }

  /// Compare dua waktu dan deteksi timezone mismatch
  static Map<String, dynamic> compareAndAnalyze(
    DateTime time1,
    DateTime time2, {
    String? label1,
    String? label2,
  }) {
    final diff = time1.difference(time2);
    final hoursDiff = diff.inHours;
    final minutesDiff = diff.inMinutes % 60;

    final analysis = <String, dynamic>{
      'timeDifference': diff,
      'hoursDifference': hoursDiff,
      'minutesDifference': minutesDiff,
      'likelyTimezoneMismatch': hoursDiff.abs() == jakartaOffsetHours,
      'isSignificantDifference': hoursDiff.abs() >= 1,
    };

    print('📊 Time Analysis (${label1 ?? 'Time1'} vs ${label2 ?? 'Time2'}):');
    print('   ${label1 ?? 'Time1'}: $time1');
    print('   ${label2 ?? 'Time2'}: $time2');
    print('   Difference: ${hoursDiff}h ${minutesDiff}m');
    print('   Timezone mismatch? ${analysis['likelyTimezoneMismatch']}');

    return analysis;
  }
}
