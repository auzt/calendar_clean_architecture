// lib/features/calendar/data/repositories/calendar_repository_impl.dart
// FIXED VERSION - Menghapus duplikasi forceSync dan perbaikan lengkap

import 'dart:async';
import 'package:dartz/dartz.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/error_handler.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/calendar_event.dart';
import '../../domain/entities/calendar_date_range.dart';
import '../../domain/repositories/calendar_repository.dart';
import '../datasources/google_calendar_remote_datasource.dart';
import '../datasources/local_calendar_datasource.dart';
import '../models/calendar_event_model.dart';

class CalendarRepositoryImpl implements CalendarRepository {
  final GoogleCalendarRemoteDataSource remoteDataSource;
  final LocalCalendarDataSource localDataSource;
  final NetworkInfo networkInfo;

  final StreamController<List<CalendarEvent>> _eventsController =
      StreamController<List<CalendarEvent>>.broadcast();

  CalendarRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.networkInfo,
  });

  // ✅ SINGLE forceSync method - tidak ada duplikasi
  Future<Either<Failure, List<CalendarEvent>>> forceSync(
    CalendarDateRange dateRange,
  ) async {
    try {
      if (!await networkInfo.isConnected) {
        return const Left(NetworkFailure('Tidak ada koneksi internet'));
      }

      final isAuthenticated = await remoteDataSource.isAuthenticated();
      if (!isAuthenticated) {
        return const Left(AuthFailure('Belum login ke Google Calendar'));
      }

      print(
          '🔄 FORCE SYNC initiated for range: ${dateRange.startDate} to ${dateRange.endDate}');

      // ✅ 1. Ambil events dari Google Calendar
      final googleEvents = await remoteDataSource.getEvents(dateRange);
      print('📥 Downloaded ${googleEvents.length} events from Google Calendar');

      // ✅ 2. Ambil existing local events untuk range yang sama
      final existingLocalEvents = await localDataSource.getEvents(dateRange);
      print('💾 Found ${existingLocalEvents.length} existing local events');

      // ✅ 3. Buat map untuk quick lookup berdasarkan Google Event ID
      final Map<String, CalendarEventModel> existingGoogleEventMap = {};
      final Map<String, CalendarEventModel> existingLocalEventMap = {};

      for (var event in existingLocalEvents) {
        if (event.googleEventId != null && event.googleEventId!.isNotEmpty) {
          existingGoogleEventMap[event.googleEventId!] = event;
        }
        existingLocalEventMap[event.id] = event;
      }

      print(
          '🗂️ Mapped ${existingGoogleEventMap.length} existing Google events');

      // ✅ 4. Process Google events untuk merge/update
      List<CalendarEventModel> eventsToSave = [];
      Set<String> processedGoogleEventIds = {};

      for (var googleEvent in googleEvents) {
        try {
          final calendarEventModel = googleEvent.toCalendarEventModel();
          final googleEventId = googleEvent.id;

          if (googleEventId == null || googleEventId.isEmpty) {
            print(
                '⚠️ Skipping event without Google ID: ${calendarEventModel.title}');
            continue;
          }

          // Cek apakah sudah ada event dengan Google ID yang sama
          if (processedGoogleEventIds.contains(googleEventId)) {
            print(
                '⚠️ Duplicate Google event ID detected, skipping: $googleEventId');
            continue;
          }
          processedGoogleEventIds.add(googleEventId);

          if (existingGoogleEventMap.containsKey(googleEventId)) {
            // ✅ Event sudah ada, update jika ada perubahan
            final existingEvent = existingGoogleEventMap[googleEventId]!;

            // Cek apakah ada perubahan substantif
            if (_hasEventChanged(existingEvent, calendarEventModel)) {
              final updatedEvent = existingEvent.copyWith(
                title: calendarEventModel.title,
                description: calendarEventModel.description,
                startTime: calendarEventModel.startTime,
                endTime: calendarEventModel.endTime,
                location: calendarEventModel.location,
                isAllDay: calendarEventModel.isAllDay,
                color: calendarEventModel.color,
                lastModified: DateTime.now(),
                isFromGoogle: true,
              );
              eventsToSave.add(updatedEvent);
              print('📝 Updated event: ${updatedEvent.title}');
            } else {
              // Tidak ada perubahan, gunakan existing event
              eventsToSave.add(existingEvent);
              print('✅ No changes for: ${existingEvent.title}');
            }
          } else {
            // ✅ Event baru dari Google
            final newEvent = calendarEventModel.copyWith(
              googleEventId: googleEventId,
              isFromGoogle: true,
              lastModified: DateTime.now(),
            );
            eventsToSave.add(newEvent);
            print('➕ New event from Google: ${newEvent.title}');
          }
        } catch (e) {
          print('❌ Error processing Google event: $e');
          continue;
        }
      }

      // ✅ 5. Tambahkan local-only events (yang tidak dari Google)
      for (var localEvent in existingLocalEvents) {
        if (!localEvent.isFromGoogle ||
            localEvent.googleEventId == null ||
            localEvent.googleEventId!.isEmpty) {
          // Event lokal yang bukan dari Google, tetap simpan
          if (!eventsToSave.any((e) => e.id == localEvent.id)) {
            eventsToSave.add(localEvent);
            print('💾 Keeping local event: ${localEvent.title}');
          }
        }
      }

      print('💾 Total events to save: ${eventsToSave.length}');

      // ✅ 6. Clear existing events untuk range ini dan simpan yang baru
      await _clearAndSaveEvents(dateRange, eventsToSave);

      // ✅ 7. Update last sync time
      await localDataSource.setLastSyncTime(DateTime.now());

      final events = eventsToSave.map((model) => model.toEntity()).toList();
      events.sort((a, b) => a.startTime.compareTo(b.startTime));

      // ✅ 8. Emit ke stream
      _eventsController.add(events);

      print('✅ Force sync completed successfully with ${events.length} events');
      return Right(events);
    } catch (e) {
      ErrorHandler.logError(e);
      print('❌ Force sync failed: $e');
      return Left(ErrorHandler.handleException(e));
    }
  }

  @override
  Future<Either<Failure, List<CalendarEvent>>> syncWithGoogleCalendar(
    CalendarDateRange dateRange,
  ) async {
    // ✅ syncWithGoogleCalendar menggunakan logic yang sama dengan forceSync
    return await forceSync(dateRange);
  }

  // ✅ Helper method untuk clear dan save events atomically
  Future<void> _clearAndSaveEvents(CalendarDateRange dateRange,
      List<CalendarEventModel> eventsToSave) async {
    try {
      // Ambil semua events yang ada
      final allExistingEvents = await localDataSource.getEvents(
        CalendarDateRange(
          startDate: DateTime.now().subtract(const Duration(days: 365)),
          endDate: DateTime.now().add(const Duration(days: 365)),
        ),
      );

      // Filter out events dalam range yang akan di-sync
      final eventsToKeep = allExistingEvents.where((event) {
        return !_isEventInDateRange(event, dateRange);
      }).toList();

      print('🗑️ Keeping ${eventsToKeep.length} events outside sync range');

      // Combine dengan events baru
      final finalEvents = [...eventsToKeep, ...eventsToSave];

      // Clear all dan save ulang
      await localDataSource.clearCache();
      await localDataSource.cacheEvents(finalEvents);

      print('💾 Saved ${finalEvents.length} total events');
    } catch (e) {
      print('❌ Error in clear and save: $e');
      throw e;
    }
  }

  // ✅ Cek apakah event ada dalam date range
  bool _isEventInDateRange(
      CalendarEventModel event, CalendarDateRange dateRange) {
    return event.startTime.isBefore(
          dateRange.endDate.add(const Duration(days: 1)),
        ) &&
        event.endTime.isAfter(
          dateRange.startDate.subtract(const Duration(days: 1)),
        );
  }

  // ✅ Cek apakah ada perubahan substantif pada event
  bool _hasEventChanged(
      CalendarEventModel existing, CalendarEventModel updated) {
    return existing.title != updated.title ||
        existing.description != updated.description ||
        existing.location != updated.location ||
        existing.startTime != updated.startTime ||
        existing.endTime != updated.endTime ||
        existing.isAllDay != updated.isAllDay;
  }

  @override
  Future<Either<Failure, List<CalendarEvent>>> getEvents(
    CalendarDateRange dateRange, {
    bool forceRefresh = false,
  }) async {
    try {
      // Cek apakah perlu sync
      final shouldSync = await _shouldSync(forceRefresh);

      if (shouldSync && await networkInfo.isConnected) {
        print('🔄 Auto-syncing because shouldSync = true');
        // Sync dengan Google Calendar terlebih dahulu
        final syncResult = await forceSync(dateRange);
        if (syncResult.isRight()) {
          return syncResult; // Return synced data
        } else {
          print('⚠️ Sync failed, falling back to local data');
          // Jika sync gagal, lanjut ambil dari local
        }
      }

      // Ambil dari local cache
      final localEvents = await localDataSource.getEvents(dateRange);
      final events = localEvents.map((model) => model.toEntity()).toList();

      // Sort events by start time
      events.sort((a, b) => a.startTime.compareTo(b.startTime));

      // Emit ke stream
      _eventsController.add(events);

      print('📱 Loaded ${events.length} events from local cache');
      return Right(events);
    } catch (e) {
      ErrorHandler.logError(e);
      return Left(ErrorHandler.handleException(e));
    }
  }

  @override
  Future<Either<Failure, List<CalendarEvent>>> getEventsForDate(
    DateTime date, {
    bool forceRefresh = false,
  }) async {
    try {
      // Cek apakah perlu sync untuk date ini
      final dateRange = CalendarDateRange(
        startDate: DateTime(date.year, date.month, date.day),
        endDate: DateTime(date.year, date.month, date.day, 23, 59, 59),
      );

      final shouldSync = await _shouldSync(forceRefresh);

      if (shouldSync && await networkInfo.isConnected) {
        await forceSync(dateRange);
      }

      final localEvents = await localDataSource.getEventsForDate(date);
      final events = localEvents.map((model) => model.toEntity()).toList();

      events.sort((a, b) => a.startTime.compareTo(b.startTime));

      return Right(events);
    } catch (e) {
      ErrorHandler.logError(e);
      return Left(ErrorHandler.handleException(e));
    }
  }

  @override
  Future<Either<Failure, CalendarEvent>> createEvent(
    CalendarEvent event,
  ) async {
    try {
      final eventModel = CalendarEventModel.fromEntity(event);

      // Simpan di local terlebih dahulu (optimistic update)
      final localEvent = await localDataSource.createEvent(eventModel);

      // Jika terkoneksi internet, sync ke Google Calendar
      if (await networkInfo.isConnected) {
        try {
          final isAuthenticated = await remoteDataSource.isAuthenticated();
          if (isAuthenticated) {
            final googleEvent = await remoteDataSource.createEvent(eventModel);

            // Update local dengan Google Event ID
            final updatedEventModel = localEvent.copyWith(
              googleEventId: googleEvent.id,
              isFromGoogle: true,
              lastModified: DateTime.now(),
            );

            await localDataSource.updateEvent(updatedEventModel);
            print(
                '✅ Created event synced to Google: ${updatedEventModel.title}');
            return Right(updatedEventModel.toEntity());
          }
        } catch (e) {
          // Jika gagal sync ke Google, tetap return local event
          ErrorHandler.logError(e);
          print(
              '⚠️ Failed to sync to Google, keeping local: ${localEvent.title}');
        }
      }

      return Right(localEvent.toEntity());
    } catch (e) {
      ErrorHandler.logError(e);
      return Left(ErrorHandler.handleException(e));
    }
  }

  @override
  Future<Either<Failure, CalendarEvent>> updateEvent(
    CalendarEvent event,
  ) async {
    try {
      final eventModel = CalendarEventModel.fromEntity(event);

      // Update di local terlebih dahulu
      final localEvent = await localDataSource.updateEvent(eventModel);

      // Jika ada Google Event ID dan terkoneksi internet, update di Google Calendar
      if (event.googleEventId != null && await networkInfo.isConnected) {
        try {
          final isAuthenticated = await remoteDataSource.isAuthenticated();
          if (isAuthenticated) {
            await remoteDataSource.updateEvent(eventModel);
            print('✅ Updated event synced to Google: ${localEvent.title}');
          }
        } catch (e) {
          ErrorHandler.logError(e);
          print('⚠️ Failed to sync update to Google: ${localEvent.title}');
        }
      }

      return Right(localEvent.toEntity());
    } catch (e) {
      ErrorHandler.logError(e);
      return Left(ErrorHandler.handleException(e));
    }
  }

  @override
  Future<Either<Failure, bool>> deleteEvent(String eventId) async {
    try {
      // Ambil event untuk cek Google Event ID
      final allEvents = await localDataSource.getEvents(
        CalendarDateRange(
          startDate: DateTime.now().subtract(const Duration(days: 365)),
          endDate: DateTime.now().add(const Duration(days: 365)),
        ),
      );

      final event = allEvents.firstWhere(
        (e) => e.id == eventId,
        orElse: () => throw Exception('Event tidak ditemukan'),
      );

      // Hapus dari local terlebih dahulu
      await localDataSource.deleteEvent(eventId);

      // Jika ada Google Event ID dan terkoneksi internet, hapus dari Google Calendar
      if (event.googleEventId != null && await networkInfo.isConnected) {
        try {
          final isAuthenticated = await remoteDataSource.isAuthenticated();
          if (isAuthenticated) {
            await remoteDataSource.deleteEvent(event.googleEventId!);
            print('✅ Deleted event synced to Google: ${event.title}');
          }
        } catch (e) {
          ErrorHandler.logError(e);
          print('⚠️ Failed to sync delete to Google: ${event.title}');
        }
      }

      return const Right(true);
    } catch (e) {
      ErrorHandler.logError(e);
      return Left(ErrorHandler.handleException(e));
    }
  }

  @override
  Future<Either<Failure, DateTime?>> getLastSyncTime() async {
    try {
      final syncTime = await localDataSource.getLastSyncTime();
      return Right(syncTime);
    } catch (e) {
      ErrorHandler.logError(e);
      return Left(ErrorHandler.handleException(e));
    }
  }

  @override
  Future<Either<Failure, bool>> authenticateGoogleCalendar() async {
    try {
      final result = await remoteDataSource.authenticate();
      return Right(result);
    } catch (e) {
      ErrorHandler.logError(e);
      return Left(ErrorHandler.handleException(e));
    }
  }

  @override
  Future<Either<Failure, bool>> signOutGoogleCalendar() async {
    try {
      final result = await remoteDataSource.signOut();
      if (result) {
        // Clear local cache when signing out
        await localDataSource.clearCache();
        print('✅ Signed out and cleared local cache');
      }
      return Right(result);
    } catch (e) {
      ErrorHandler.logError(e);
      return Left(ErrorHandler.handleException(e));
    }
  }

  @override
  Future<Either<Failure, bool>> isGoogleCalendarAuthenticated() async {
    try {
      final result = await remoteDataSource.isAuthenticated();
      return Right(result);
    } catch (e) {
      ErrorHandler.logError(e);
      return Left(ErrorHandler.handleException(e));
    }
  }

  @override
  Stream<List<CalendarEvent>> watchEvents(CalendarDateRange dateRange) {
    // Trigger initial load
    getEvents(dateRange);

    return _eventsController.stream.map((events) {
      // Filter events for the specific date range
      return events.where((event) {
        return event.startTime.isBefore(
              dateRange.endDate.add(const Duration(days: 1)),
            ) &&
            event.endTime.isAfter(
              dateRange.startDate.subtract(const Duration(days: 1)),
            );
      }).toList();
    });
  }

  @override
  Future<Either<Failure, bool>> clearCache() async {
    try {
      final result = await localDataSource.clearCache();
      print('🗑️ Local cache cleared');
      return Right(result);
    } catch (e) {
      ErrorHandler.logError(e);
      return Left(ErrorHandler.handleException(e));
    }
  }

  Future<bool> _shouldSync(bool forceRefresh) async {
    if (forceRefresh) {
      print('🔄 Force refresh requested');
      return true;
    }

    final lastSyncTime = await localDataSource.getLastSyncTime();
    if (lastSyncTime == null) {
      print('🔄 No previous sync time, syncing');
      return true;
    }

    final timeSinceLastSync = DateTime.now().difference(lastSyncTime);
    final shouldSync = timeSinceLastSync > AppConstants.syncInterval;

    print(
        '🕐 Last sync: ${timeSinceLastSync.inMinutes} minutes ago, should sync: $shouldSync');
    return shouldSync;
  }

  void dispose() {
    _eventsController.close();
  }
}
