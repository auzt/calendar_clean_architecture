// lib/features/calendar/domain/usecases/get_calendar_events.dart
import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/calendar_event.dart';
import '../entities/calendar_date_range.dart';
import '../repositories/calendar_repository.dart';

class GetCalendarEvents {
  final CalendarRepository repository;

  GetCalendarEvents(this.repository);

  Future<Either<Failure, List<CalendarEvent>>> call(
    CalendarDateRange dateRange, {
    bool forceRefresh = false,
  }) async {
    return await repository.getEvents(dateRange, forceRefresh: forceRefresh);
  }
}
