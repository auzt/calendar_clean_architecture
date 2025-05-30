// lib/features/calendar/domain/usecases/get_events_for_date.dart
import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/calendar_event.dart';
import '../repositories/calendar_repository.dart';

class GetEventsForDate {
  final CalendarRepository repository;

  GetEventsForDate(this.repository);

  Future<Either<Failure, List<CalendarEvent>>> call(
    DateTime date, {
    bool forceRefresh = false,
  }) async {
    return await repository.getEventsForDate(date, forceRefresh: forceRefresh);
  }
}
