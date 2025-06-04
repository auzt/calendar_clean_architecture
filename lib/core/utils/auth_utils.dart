// lib/core/utils/auth_utils.dart
// Helper untuk testing dan debugging UTC DateTime issues

class AuthUtils {
  /// Test UTC DateTime creation dan validation
  static void testUtcDateTime() {
    print('🧪 Testing UTC DateTime creation...');

    // Test various DateTime creation methods
    final localNow = DateTime.now();
    final utcNow = DateTime.now().toUtc();
    final utcDirect = DateTime.utc(2024, 1, 20, 15, 30, 0);
    final utcFromLocal = localNow.toUtc();

    print('📅 DateTime Tests:');
    print('   Local Now: $localNow (isUtc: ${localNow.isUtc})');
    print('   UTC Now: $utcNow (isUtc: ${utcNow.isUtc})');
    print('   UTC Direct: $utcDirect (isUtc: ${utcDirect.isUtc})');
    print('   UTC From Local: $utcFromLocal (isUtc: ${utcFromLocal.isUtc})');

    // Test expiry times
    final localExpiry = DateTime.now().add(const Duration(hours: 1));
    final utcExpiry = DateTime.now().toUtc().add(const Duration(hours: 1));
    final utcExpiryDirect = DateTime.utc(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
      DateTime.now().hour + 1,
      DateTime.now().minute,
    );

    print('⏰ Expiry Time Tests:');
    print('   Local Expiry: $localExpiry (isUtc: ${localExpiry.isUtc})');
    print('   UTC Expiry: $utcExpiry (isUtc: ${utcExpiry.isUtc})');
    print(
        '   UTC Direct Expiry: $utcExpiryDirect (isUtc: ${utcExpiryDirect.isUtc})');

    // Test future validation
    final currentUtc = DateTime.now().toUtc();
    print('🔮 Future Validation:');
    print('   Current UTC: $currentUtc');
    print('   UTC Expiry is future: ${utcExpiry.isAfter(currentUtc)}');
    print(
        '   Time difference: ${utcExpiry.difference(currentUtc).inMinutes} minutes');
  }

  /// Create safe UTC expiry time
  static DateTime createSafeUtcExpiry(
      {Duration duration = const Duration(hours: 1)}) {
    final utcExpiry = DateTime.now().toUtc().add(duration);

    // Validate
    if (!utcExpiry.isUtc) {
      throw Exception('Created expiry is not UTC: $utcExpiry');
    }

    if (utcExpiry.isBefore(DateTime.now().toUtc())) {
      throw Exception('Created expiry is in the past: $utcExpiry');
    }

    print('✅ Safe UTC expiry created: $utcExpiry');
    return utcExpiry;
  }

  /// Debug current timezone info
  static void debugTimezoneInfo() {
    final local = DateTime.now();
    final utc = DateTime.now().toUtc();
    final offset = local.timeZoneOffset;

    print('🌍 Timezone Debug Info:');
    print('   Local Time: $local');
    print('   UTC Time: $utc');
    print('   Timezone Offset: $offset');
    print('   Timezone Name: ${local.timeZoneName}');
  }

  /// Validate DateTime for OAuth usage
  static bool validateOAuthDateTime(DateTime dateTime) {
    if (!dateTime.isUtc) {
      print('❌ DateTime is not UTC: $dateTime');
      return false;
    }

    if (dateTime.isBefore(DateTime.now().toUtc())) {
      print('❌ DateTime is in the past: $dateTime');
      return false;
    }

    // Check if it's too far in the future (more than 24 hours)
    final maxFuture = DateTime.now().toUtc().add(const Duration(hours: 24));
    if (dateTime.isAfter(maxFuture)) {
      print('⚠️ DateTime is very far in future: $dateTime');
    }

    print('✅ DateTime validation passed: $dateTime');
    return true;
  }
}
