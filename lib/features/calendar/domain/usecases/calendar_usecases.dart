// lib/features/calendar/domain/usecases/calendar_usecases.dart
class CalendarUseCases {
  final GetCalendarEvents getCalendarEvents;
  final GetEventsForDate getEventsForDate;
  final CreateCalendarEvent createCalendarEvent;
  final UpdateCalendarEvent updateCalendarEvent;
  final DeleteCalendarEvent deleteCalendarEvent;
  final SyncGoogleCalendar syncGoogleCalendar;
  final AuthenticateGoogleCalendar authenticateGoogleCalendar;
  final WatchCalendarEvents watchCalendarEvents;

  CalendarUseCases({
    required this.getCalendarEvents,
    required this.getEventsForDate,
    required this.createCalendarEvent,
    required this.updateCalendarEvent,
    required this.deleteCalendarEvent,
    required this.syncGoogleCalendar,
    required this.authenticateGoogleCalendar,
    required this.watchCalendarEvents,
  });
}
