// lib/features/calendar/domain/usecases/calendar_usecases.dart
import 'get_calendar_events.dart';
import 'get_events_for_date.dart';
import 'create_calendar_event.dart';
import 'update_calendar_event.dart';
import 'delete_calendar_event.dart';
import 'sync_google_calendar.dart';
import 'authenticate_google_calendar.dart';
import 'watch_calendar_events.dart';

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
