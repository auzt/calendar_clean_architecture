// lib/features/calendar/data/repositories/calendar_repository_impl.dart
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

  @override
  Future<Either<Failure, List<CalendarEvent>>> getEvents(
    CalendarDateRange dateRange, {
    bool forceRefresh = false,
  }) async {
    try {
      // Cek apakah perlu sync
      final shouldSync = await _shouldSync(forceRefresh);

      if (shouldSync && await networkInfo.isConnected) {
        // Sync dengan Google Calendar terlebih dahulu
        await syncWithGoogleCalendar(dateRange);
      }

      // Ambil dari local cache
      final localEvents = await localDataSource.getEvents(dateRange);
      final events = localEvents.map((model) => model.toEntity()).toList();

      // Sort events by start time
      events.sort((a, b) => a.startTime.compareTo(b.startTime));

      // Emit ke stream
      _eventsController.add(events);

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
        await syncWithGoogleCalendar(dateRange);
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
            return Right(updatedEventModel.toEntity());
          }
        } catch (e) {
          // Jika gagal sync ke Google, tetap return local event
          ErrorHandler.logError(e);
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
          }
        } catch (e) {
          ErrorHandler.logError(e);
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
          }
        } catch (e) {
          ErrorHandler.logError(e);
        }
      }

      return const Right(true);
    } catch (e) {
      ErrorHandler.logError(e);
      return Left(ErrorHandler.handleException(e));
    }
  }

  @override
  Future<Either<Failure, List<CalendarEvent>>> syncWithGoogleCalendar(
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

      // Ambil events dari Google Calendar
      final googleEvents = await remoteDataSource.getEvents(dateRange);

      // Konversi ke CalendarEventModel
      final eventModels =
          googleEvents.map((googleEvent) {
            return googleEvent.toCalendarEventModel();
          }).toList();

      // Cache di local
      await localDataSource.cacheEvents(eventModels);

      // Update last sync time
      await localDataSource.setLastSyncTime(DateTime.now());

      final events = eventModels.map((model) => model.toEntity()).toList();
      events.sort((a, b) => a.startTime.compareTo(b.startTime));

      // Emit ke stream
      _eventsController.add(events);

      return Right(events);
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
      return Right(result);
    } catch (e) {
      ErrorHandler.logError(e);
      return Left(ErrorHandler.handleException(e));
    }
  }

  Future<bool> _shouldSync(bool forceRefresh) async {
    if (forceRefresh) return true;

    final lastSyncTime = await localDataSource.getLastSyncTime();
    if (lastSyncTime == null) return true;

    final timeSinceLastSync = DateTime.now().difference(lastSyncTime);
    return timeSinceLastSync > AppConstants.syncInterval;
  }

  void dispose() {
    _eventsController.close();
  }
}
