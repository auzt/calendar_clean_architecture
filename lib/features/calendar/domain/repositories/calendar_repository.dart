// lib/features/calendar/domain/repositories/calendar_repository.dart
// UPDATED VERSION - Menambahkan forceSync method

import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/calendar_event.dart';
import '../entities/calendar_date_range.dart';

abstract class CalendarRepository {
  /// Mendapatkan events dalam rentang tanggal
  Future<Either<Failure, List<CalendarEvent>>> getEvents(
    CalendarDateRange dateRange, {
    bool forceRefresh = false,
  });

  /// Mendapatkan events untuk tanggal tertentu
  Future<Either<Failure, List<CalendarEvent>>> getEventsForDate(
    DateTime date, {
    bool forceRefresh = false,
  });

  /// Membuat event baru
  Future<Either<Failure, CalendarEvent>> createEvent(CalendarEvent event);

  /// Update event yang sudah ada
  Future<Either<Failure, CalendarEvent>> updateEvent(CalendarEvent event);

  /// Menghapus event
  Future<Either<Failure, bool>> deleteEvent(String eventId);

  /// Sinkronisasi dengan Google Calendar
  Future<Either<Failure, List<CalendarEvent>>> syncWithGoogleCalendar(
    CalendarDateRange dateRange,
  );

  /// ✅ TAMBAHAN: Force sync untuk mencegah duplikasi
  /// Method ini akan:
  /// 1. Mengambil data fresh dari Google Calendar
  /// 2. Membersihkan data lokal untuk range tertentu
  /// 3. Merge dengan smart duplicate detection
  /// 4. Menyimpan hasil final tanpa duplikasi
  Future<Either<Failure, List<CalendarEvent>>> forceSync(
    CalendarDateRange dateRange,
  );

  /// Mendapatkan status sinkronisasi
  Future<Either<Failure, DateTime?>> getLastSyncTime();

  /// Login ke Google Calendar
  Future<Either<Failure, bool>> authenticateGoogleCalendar();

  /// Logout dari Google Calendar
  Future<Either<Failure, bool>> signOutGoogleCalendar();

  /// Cek status autentikasi
  Future<Either<Failure, bool>> isGoogleCalendarAuthenticated();

  /// Stream untuk mendengarkan perubahan events
  Stream<List<CalendarEvent>> watchEvents(CalendarDateRange dateRange);

  /// Clear cache
  Future<Either<Failure, bool>> clearCache();
}
