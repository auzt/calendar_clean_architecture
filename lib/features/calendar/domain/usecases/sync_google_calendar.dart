import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/calendar_event.dart';
import '../entities/calendar_date_range.dart';
import '../repositories/calendar_repository.dart';

class SyncGoogleCalendar {
  final CalendarRepository repository;

  SyncGoogleCalendar(this.repository);

  Future<Either<Failure, List<CalendarEvent>>> call(
    CalendarDateRange dateRange,
  ) async {
    return await repository.syncWithGoogleCalendar(dateRange);
  }
}
