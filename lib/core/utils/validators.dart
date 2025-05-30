// lib/core/utils/validators.dart
class Validators {
  static String? validateTitle(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Judul tidak boleh kosong';
    }
    if (value.trim().length > 100) {
      return 'Judul maksimal 100 karakter';
    }
    return null;
  }

  static String? validateDescription(String? value) {
    if (value != null && value.length > 1000) {
      return 'Deskripsi maksimal 1000 karakter';
    }
    return null;
  }

  static String? validateLocation(String? value) {
    if (value != null && value.length > 200) {
      return 'Lokasi maksimal 200 karakter';
    }
    return null;
  }

  static String? validateDateRange(DateTime? startDate, DateTime? endDate) {
    if (startDate == null) {
      return 'Tanggal mulai wajib diisi';
    }
    if (endDate == null) {
      return 'Tanggal selesai wajib diisi';
    }
    if (endDate.isBefore(startDate)) {
      return 'Tanggal selesai tidak boleh sebelum tanggal mulai';
    }
    return null;
  }

  static bool isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  static bool isValidUrl(String url) {
    return Uri.tryParse(url)?.hasAbsolutePath ?? false;
  }
}
