// lib/features/calendar/domain/usecases/update_calendar_event.dart
import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/calendar_event.dart';
import '../repositories/calendar_repository.dart';

class UpdateCalendarEvent {
  final CalendarRepository repository;

  UpdateCalendarEvent(this.repository);

  Future<Either<Failure, CalendarEvent>> call(CalendarEvent event) async {
    return await repository.updateEvent(event);
  }
}
