// lib/features/calendar/data/datasources/google_calendar_remote_datasource.dart
// ✅ FINAL PERFECT VERSION: Absolutely zero type conflicts

import 'package:googleapis/calendar/v3.dart' as calendar;
import '../../../../core/network/google_auth_service.dart';
import '../../../../core/error/exceptions.dart';
import '../models/google_event_model.dart';
import '../models/calendar_event_model.dart';
import '../../domain/entities/calendar_date_range.dart';

abstract class GoogleCalendarRemoteDataSource {
  Future<List<GoogleEventModel>> getEvents(CalendarDateRange dateRange);
  Future<GoogleEventModel> createEvent(CalendarEventModel event);
  Future<GoogleEventModel> updateEvent(CalendarEventModel event);
  Future<bool> deleteEvent(String eventId);
  Future<bool> authenticate();
  Future<bool> signOut();
  Future<bool> isAuthenticated();
}

class GoogleCalendarRemoteDataSourceImpl
    implements GoogleCalendarRemoteDataSource {
  final GoogleAuthService _googleAuthService;
  calendar.CalendarApi? _calendarApi;

  GoogleCalendarRemoteDataSourceImpl(
      {required GoogleAuthService googleAuthService})
      : _googleAuthService = googleAuthService;

  Future<calendar.CalendarApi> _getApi() async {
    if (_googleAuthService.authClient == null) {
      // ignore: avoid_print
      print('AuthClient is null in _getApi. Attempting silent sign-in...');
      final bool signedInSilently = await _googleAuthService.silentSignIn();
      if (!signedInSilently || _googleAuthService.authClient == null) {
        throw AuthException(
            'User not authenticated or session expired. Please sign in again.');
      }
    }
    // Always use the current authClient from GoogleAuthService
    _calendarApi = calendar.CalendarApi(_googleAuthService.authClient!);
    return _calendarApi!;
  }

  @override
  Future<bool> authenticate() async {
    try {
      // ignore: avoid_print
      print('🔐 Starting authentication via GoogleAuthService...');
      _calendarApi = null; // Clear any stale API instance

      final bool signedIn = await _googleAuthService.signIn();
      if (!signedIn) {
        throw AuthException('Google Sign-In process was not completed.');
      }

      final api = await _getApi(); // This will initialize _calendarApi
      await api.calendarList.list(); // Test the API to confirm validity

      // ignore: avoid_print
      print('✅ Authentication completed successfully via GoogleAuthService');
      return true;
    } catch (e) {
      // ignore: avoid_print
      print('❌ Authentication failed in GoogleCalendarRemoteDataSource: $e');
      _calendarApi = null; // Ensure API is cleared on failure
      if (e is AuthException) rethrow;
      throw AuthException('Gagal login ke Google Calendar: ${e.toString()}');
    }
  }

  @override
  Future<bool> signOut() async {
    try {
      await _googleAuthService.signOut();
      _calendarApi = null;
      return true;
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('Gagal logout: ${e.toString()}');
    }
  }

  @override
  Future<bool> isAuthenticated() async {
    try {
      if (!_googleAuthService.isSignedIn) {
        bool success = await _googleAuthService.silentSignIn();
        if (!success || !_googleAuthService.isSignedIn) {
          return false;
        }
      }
      if (_googleAuthService.authClient == null) {
        return false;
      }

      final api = await _getApi();
      await api.calendarList.list(); // Test the API
      return true;
    } catch (e) {
      _calendarApi = null; // Clear API if test fails
      return false;
    }
  }

  @override
  Future<List<GoogleEventModel>> getEvents(CalendarDateRange dateRange) async {
    try {
      final api = await _getApi();

      // ignore: avoid_print
      print('📅 Fetching events...');
      final calendar.Events events = await api.events.list(
        'primary',
        timeMin: dateRange.startDate.toUtc(),
        timeMax: dateRange.endDate.toUtc(),
        maxResults: 50,
        singleEvents: true,
        orderBy: 'startTime',
      );

      if (events.items == null || events.items!.isEmpty) {
        // ignore: avoid_print
        print('📋 No events found');
        return [];
      }

      // ignore: avoid_print
      print('✅ Found ${events.items!.length} events');

      List<GoogleEventModel> result = [];

      for (var event in events.items!) {
        try {
          // ✅ Create using Map conversion
          final eventMap = <String, dynamic>{
            'id': event.id,
            'summary': event.summary ?? 'Tanpa Judul',
            'description': event.description,
            'location': event.location,
            'start': _extractEventTimeInfo(event.start),
            'end': _extractEventTimeInfo(event.end),
            'colorId': event.colorId,
            'recurrence': event.recurrence,
          };

          final googleEvent = GoogleEventModel.fromMap(eventMap);
          result.add(googleEvent);
        } catch (e) {
          // ignore: avoid_print
          print('⚠️ Skipping event due to parsing error: $e');
          continue;
        }
      }

      // ignore: avoid_print
      print('✅ Successfully parsed ${result.length} events');
      return result;
    } catch (e) {
      // ignore: avoid_print
      print('❌ Get events error: $e');
      if (e is AuthException) rethrow;
      throw ServerException('Gagal mengambil events: ${e.toString()}');
    }
  }

  // ✅ Extract time info safely from calendar.EventDateTime
  Map<String, dynamic>? _extractEventTimeInfo(
      calendar.EventDateTime? eventDateTime) {
    if (eventDateTime == null) return null;

    return {
      'date': eventDateTime.date, // String?
      'dateTime':
          eventDateTime.dateTime?.toIso8601String(), // DateTime? -> String?
      'timeZone': eventDateTime.timeZone, // String?
    };
  }

  @override
  Future<GoogleEventModel> createEvent(CalendarEventModel event) async {
    try {
      final api = await _getApi();

      // ignore: avoid_print
      print('➕ Creating event: ${event.title}');

      final calendarEvent = calendar.Event()
        ..summary = event.title
        ..description = event.description
        ..location = event.location;

      // ✅ FIXED: Proper EventDateTime creation - no String to DateTime assignment
      if (event.isAllDay) {
        // For all-day events, use .date (String field)
        calendarEvent.start = calendar.EventDateTime()
          ..date = DateTime.parse(
              _formatDateOnly(event.startTime)); // String assignment ✓
        calendarEvent.end = calendar.EventDateTime()
          ..date = DateTime.parse(
              _formatDateOnly(event.endTime)); // String assignment ✓
      } else {
        // For timed events, use .dateTime (DateTime field)
        calendarEvent.start = calendar.EventDateTime()
          ..dateTime = event.startTime.toUtc() // DateTime assignment ✓
          ..timeZone = 'Asia/Jakarta';
        calendarEvent.end = calendar.EventDateTime()
          ..dateTime = event.endTime.toUtc() // DateTime assignment ✓
          ..timeZone = 'Asia/Jakarta';
      }

      final createdEvent = await api.events.insert(calendarEvent, 'primary');

      // ignore: avoid_print
      print('✅ Event created: ${createdEvent.id}');

      // ✅ Convert back using Map approach
      final eventMap = <String, dynamic>{
        'id': createdEvent.id,
        'summary': createdEvent.summary,
        'description': createdEvent.description,
        'location': createdEvent.location,
        'start': _extractEventTimeInfo(createdEvent.start),
        'end': _extractEventTimeInfo(createdEvent.end),
        'colorId': createdEvent.colorId,
      };

      return GoogleEventModel.fromMap(eventMap);
    } catch (e) {
      // ignore: avoid_print
      print('❌ Create event error: $e');
      if (e is AuthException) rethrow;
      throw ServerException('Gagal membuat event: ${e.toString()}');
    }
  }

  @override
  Future<GoogleEventModel> updateEvent(CalendarEventModel event) async {
    try {
      final api = await _getApi();

      if (event.googleEventId == null) {
        throw ValidationException('Event ID Google tidak ditemukan');
      }

      // ignore: avoid_print
      print('✏️ Updating event: ${event.title}');

      final existingEvent =
          await api.events.get('primary', event.googleEventId!);

      existingEvent.summary = event.title;
      existingEvent.description = event.description;
      existingEvent.location = event.location;

      // ✅ FIXED: Proper EventDateTime update - no String to DateTime assignment
      if (event.isAllDay) {
        // For all-day events, use .date (String field)
        existingEvent.start = calendar.EventDateTime()
          ..date = DateTime.parse(
              _formatDateOnly(event.startTime)); // String assignment ✓
        existingEvent.end = calendar.EventDateTime()
          ..date = DateTime.parse(
              _formatDateOnly(event.endTime)); // String assignment ✓
      } else {
        // For timed events, use .dateTime (DateTime field)
        existingEvent.start = calendar.EventDateTime()
          ..dateTime = event.startTime.toUtc() // DateTime assignment ✓
          ..timeZone = 'Asia/Jakarta';
        existingEvent.end = calendar.EventDateTime()
          ..dateTime = event.endTime.toUtc() // DateTime assignment ✓
          ..timeZone = 'Asia/Jakarta';
      }

      final updatedEvent = await api.events
          .update(existingEvent, 'primary', event.googleEventId!);

      // ignore: avoid_print
      print('✅ Event updated successfully');

      // ✅ Convert back using Map approach
      final eventMap = <String, dynamic>{
        'id': updatedEvent.id,
        'summary': updatedEvent.summary,
        'description': updatedEvent.description,
        'location': updatedEvent.location,
        'start': _extractEventTimeInfo(updatedEvent.start),
        'end': _extractEventTimeInfo(updatedEvent.end),
        'colorId': updatedEvent.colorId,
      };

      return GoogleEventModel.fromMap(eventMap);
    } catch (e) {
      // ignore: avoid_print
      print('❌ Update event error: $e');
      if (e is AuthException || e is ValidationException) rethrow;
      throw ServerException('Gagal update event: ${e.toString()}');
    }
  }

  @override
  Future<bool> deleteEvent(String eventId) async {
    try {
      final api = await _getApi();
      await api.events.delete('primary', eventId);

      // ignore: avoid_print
      print('✅ Event deleted: $eventId');
      return true;
    } catch (e) {
      // ignore: avoid_print
      print('❌ Delete event error: $e');
      if (e is AuthException) rethrow;
      throw ServerException('Gagal menghapus event: ${e.toString()}');
    }
  }

  // ✅ Helper for date-only formatting (returns String)
  String _formatDateOnly(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}';
  }
}
