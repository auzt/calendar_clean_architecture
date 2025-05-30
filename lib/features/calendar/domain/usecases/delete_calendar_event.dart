// lib/features/calendar/domain/usecases/delete_calendar_event.dart
import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../repositories/calendar_repository.dart';

class DeleteCalendarEvent {
  final CalendarRepository repository;

  DeleteCalendarEvent(this.repository);

  Future<Either<Failure, bool>> call(String eventId) async {
    return await repository.deleteEvent(eventId);
  }
}
