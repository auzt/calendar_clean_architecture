// lib/features/calendar/domain/usecases/authenticate_google_calendar.dart
import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../repositories/calendar_repository.dart';

class AuthenticateGoogleCalendar {
  final CalendarRepository repository;

  AuthenticateGoogleCalendar(this.repository);

  Future<Either<Failure, bool>> call() async {
    return await repository.authenticateGoogleCalendar();
  }
}
