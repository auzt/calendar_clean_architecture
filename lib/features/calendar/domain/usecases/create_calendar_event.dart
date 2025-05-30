// lib/features/calendar/domain/usecases/create_calendar_event.dart
import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/calendar_event.dart';
import '../repositories/calendar_repository.dart';

class CreateCalendarEvent {
  final CalendarRepository repository;

  CreateCalendarEvent(this.repository);

  Future<Either<Failure, CalendarEvent>> call(CalendarEvent event) async {
    return await repository.createEvent(event);
  }
}
