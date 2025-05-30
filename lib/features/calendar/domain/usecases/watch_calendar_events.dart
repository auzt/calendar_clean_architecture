// lib/features/calendar/domain/usecases/watch_calendar_events.dart
import '../entities/calendar_event.dart';
import '../entities/calendar_date_range.dart';
import '../repositories/calendar_repository.dart';

class WatchCalendarEvents {
  final CalendarRepository repository;

  WatchCalendarEvents(this.repository);

  Stream<List<CalendarEvent>> call(CalendarDateRange dateRange) {
    return repository.watchEvents(dateRange);
  }
}
