// lib/features/calendar/presentation/bloc/calendar_event.dart
import 'package:equatable/equatable.dart';
import '../../domain/entities/calendar_event.dart';
import '../../domain/entities/calendar_date_range.dart';

abstract class CalendarEvent extends Equatable {
  const CalendarEvent();

  @override
  List<Object?> get props => [];
}

class LoadCalendarEvents extends CalendarEvent {
  final CalendarDateRange dateRange;
  final bool forceRefresh;

  const LoadCalendarEvents({
    required this.dateRange,
    this.forceRefresh = false,
  });

  @override
  List<Object> get props => [dateRange, forceRefresh];
}

class LoadEventsForDate extends CalendarEvent {
  final DateTime date;
  final bool forceRefresh;

  const LoadEventsForDate({required this.date, this.forceRefresh = false});

  @override
  List<Object> get props => [date, forceRefresh];
}

class CreateEvent extends CalendarEvent {
  final CalendarEvent event;

  const CreateEvent(this.event);

  @override
  List<Object> get props => [event];
}

class UpdateEvent extends CalendarEvent {
  final CalendarEvent event;

  const UpdateEvent(this.event);

  @override
  List<Object> get props => [event];
}

class DeleteEvent extends CalendarEvent {
  final String eventId;

  const DeleteEvent(this.eventId);

  @override
  List<Object> get props => [eventId];
}

class SyncWithGoogle extends CalendarEvent {
  final CalendarDateRange dateRange;

  const SyncWithGoogle(this.dateRange);

  @override
  List<Object> get props => [dateRange];
}

class AuthenticateGoogle extends CalendarEvent {
  const AuthenticateGoogle();
}

class SignOutGoogle extends CalendarEvent {
  const SignOutGoogle();
}

class CheckGoogleAuth extends CalendarEvent {
  const CheckGoogleAuth();
}

class ClearCache extends CalendarEvent {
  const ClearCache();
}

class WatchEventsForRange extends CalendarEvent {
  final CalendarDateRange dateRange;

  const WatchEventsForRange(this.dateRange);

  @override
  List<Object> get props => [dateRange];
}
