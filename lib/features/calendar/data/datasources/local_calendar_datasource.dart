// lib/features/calendar/data/datasources/local_calendar_datasource.dart
import 'package:hive/hive.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/utils/date_utils.dart';
import '../models/calendar_event_model.dart';
import '../../domain/entities/calendar_date_range.dart';

abstract class LocalCalendarDataSource {
  Future<List<CalendarEventModel>> getEvents(CalendarDateRange dateRange);
  Future<List<CalendarEventModel>> getEventsForDate(DateTime date);
  Future<CalendarEventModel> createEvent(CalendarEventModel event);
  Future<CalendarEventModel> updateEvent(CalendarEventModel event);
  Future<bool> deleteEvent(String eventId);
  Future<bool> cacheEvents(List<CalendarEventModel> events);
  Future<bool> clearCache();
  Future<DateTime?> getLastSyncTime();
  Future<bool> setLastSyncTime(DateTime syncTime);
}

class LocalCalendarDataSourceImpl implements LocalCalendarDataSource {
  late Box<CalendarEventModel> _eventsBox;
  late Box<String> _metadataBox;

  Future<void> init() async {
    _eventsBox = await Hive.openBox<CalendarEventModel>(
      AppConstants.hiveBoxName,
    );
    _metadataBox = await Hive.openBox<String>('calendar_metadata');
  }

  @override
  Future<List<CalendarEventModel>> getEvents(
    CalendarDateRange dateRange,
  ) async {
    try {
      final allEvents = _eventsBox.values.toList();

      return allEvents.where((event) {
        final eventStart = AppDateUtils.getStartOfDay(event.startTime);
        final eventEnd = AppDateUtils.getEndOfDay(event.endTime);

        return eventStart.isBefore(
              dateRange.endDate.add(const Duration(days: 1)),
            ) &&
            eventEnd.isAfter(
              dateRange.startDate.subtract(const Duration(days: 1)),
            );
      }).toList();
    } catch (e) {
      throw CacheException(
        'Gagal mengambil events dari cache: ${e.toString()}',
      );
    }
  }

  @override
  Future<List<CalendarEventModel>> getEventsForDate(DateTime date) async {
    try {
      final startOfDay = AppDateUtils.getStartOfDay(date);
      final endOfDay = AppDateUtils.getEndOfDay(date);

      final allEvents = _eventsBox.values.toList();

      return allEvents.where((event) {
        return event.startTime.isBefore(
              endOfDay.add(const Duration(seconds: 1)),
            ) &&
            event.endTime.isAfter(
              startOfDay.subtract(const Duration(seconds: 1)),
            );
      }).toList();
    } catch (e) {
      throw CacheException(
        'Gagal mengambil events untuk tanggal: ${e.toString()}',
      );
    }
  }

  @override
  Future<CalendarEventModel> createEvent(CalendarEventModel event) async {
    try {
      await _eventsBox.put(event.id, event);
      return event;
    } catch (e) {
      throw CacheException('Gagal menyimpan event: ${e.toString()}');
    }
  }

  @override
  Future<CalendarEventModel> updateEvent(CalendarEventModel event) async {
    try {
      await _eventsBox.put(event.id, event);
      return event;
    } catch (e) {
      throw CacheException('Gagal update event: ${e.toString()}');
    }
  }

  @override
  Future<bool> deleteEvent(String eventId) async {
    try {
      await _eventsBox.delete(eventId);
      return true;
    } catch (e) {
      throw CacheException('Gagal menghapus event: ${e.toString()}');
    }
  }

  @override
  Future<bool> cacheEvents(List<CalendarEventModel> events) async {
    try {
      final Map<String, CalendarEventModel> eventMap = {
        for (var event in events) event.id: event,
      };

      await _eventsBox.putAll(eventMap);
      return true;
    } catch (e) {
      throw CacheException('Gagal cache events: ${e.toString()}');
    }
  }

  @override
  Future<bool> clearCache() async {
    try {
      await _eventsBox.clear();
      return true;
    } catch (e) {
      throw CacheException('Gagal clear cache: ${e.toString()}');
    }
  }

  @override
  Future<DateTime?> getLastSyncTime() async {
    try {
      final syncTimeString = _metadataBox.get('last_sync_time');
      if (syncTimeString != null) {
        return DateTime.parse(syncTimeString);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  @override
  Future<bool> setLastSyncTime(DateTime syncTime) async {
    try {
      await _metadataBox.put('last_sync_time', syncTime.toIso8601String());
      return true;
    } catch (e) {
      throw CacheException('Gagal set sync time: ${e.toString()}');
    }
  }
}
