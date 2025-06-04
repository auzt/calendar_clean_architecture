// lib/features/calendar/data/datasources/google_calendar_remote_datasource.dart
import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis_auth/googleapis_auth.dart' as auth;
import 'package:http/http.dart' as http;
import '../../../../core/constants/google_calendar_constants.dart';
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
  final GoogleSignIn _googleSignIn;
  calendar.CalendarApi? _calendarApi;

  GoogleCalendarRemoteDataSourceImpl({GoogleSignIn? googleSignIn})
      : _googleSignIn = googleSignIn ??
            GoogleSignIn(scopes: GoogleCalendarConstants.scopes);

  @override
  Future<bool> authenticate() async {
    try {
      print('🔐 Starting Google Calendar authentication...');
      print('   Current Time (Local): ${DateTime.now()}');
      print('   Current Time (UTC): ${DateTime.now().toUtc()}');

      // Clear any existing auth
      await _clearAuth();

      // Perform Google Sign In
      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      if (account == null) {
        throw AuthException('Login dibatalkan oleh user');
      }

      print('✅ Google Sign In successful for: ${account.email}');

      // Get fresh authentication
      final GoogleSignInAuthentication authentication =
          await account.authentication;

      // Validate tokens
      if (authentication.accessToken == null ||
          authentication.accessToken!.isEmpty) {
        throw AuthException('Access token tidak valid');
      }

      print('🔑 Authentication tokens obtained successfully');

      // Create UTC expiry time
      final DateTime utcExpiryTime =
          DateTime.now().toUtc().add(const Duration(hours: 1));

      print('🕐 Token expiry (UTC): $utcExpiryTime');

      // Double-check UTC requirement
      if (!utcExpiryTime.isUtc) {
        throw AuthException('CRITICAL: Expiry time must be UTC');
      }

      // Create credentials with UTC expiry
      final auth.AccessCredentials credentials = auth.AccessCredentials(
        auth.AccessToken(
          'Bearer',
          authentication.accessToken!,
          utcExpiryTime,
        ),
        authentication.idToken,
        GoogleCalendarConstants.scopes,
      );

      // Create authenticated HTTP client
      final httpClient = http.Client();
      final authClient = auth.authenticatedClient(httpClient, credentials);

      // Create Calendar API instance
      _calendarApi = calendar.CalendarApi(authClient);

      // Test API access
      await _testApiAccess();

      print('✅ Google Calendar authentication completed successfully');
      return true;
    } catch (e) {
      print('❌ Authentication failed: $e');
      print('   Error type: ${e.runtimeType}');

      await _clearAuth();

      if (e is AuthException) rethrow;
      throw AuthException('Gagal login ke Google Calendar: ${e.toString()}');
    }
  }

  Future<void> _testApiAccess() async {
    try {
      if (_calendarApi == null) {
        throw AuthException('Calendar API tidak tersedia');
      }

      print('🧪 Testing API access...');

      // Test with a simple calendar list request
      final calendars = await _calendarApi!.calendarList.list();
      print(
          '✅ API test successful - Found ${calendars.items?.length ?? 0} calendars');
    } catch (e) {
      print('❌ API test failed: $e');
      throw AuthException(
          'Tidak dapat mengakses Google Calendar API: ${e.toString()}');
    }
  }

  @override
  Future<bool> signOut() async {
    try {
      print('👋 Signing out from Google Calendar...');

      await _clearAuth();
      await _googleSignIn.signOut();

      print('✅ Sign out successful');
      return true;
    } catch (e) {
      print('❌ Sign out error: $e');
      throw AuthException('Gagal logout: ${e.toString()}');
    }
  }

  @override
  Future<bool> isAuthenticated() async {
    try {
      final GoogleSignInAccount? account = _googleSignIn.currentUser;

      if (account == null || _calendarApi == null) {
        return false;
      }

      // Test if we can still access the API
      try {
        await _calendarApi!.calendarList.list();
        return true;
      } catch (e) {
        print('⚠️ API access test failed, re-authentication needed: $e');
        return false;
      }
    } catch (e) {
      print('❌ Authentication check failed: $e');
      return false;
    }
  }

  @override
  Future<List<GoogleEventModel>> getEvents(CalendarDateRange dateRange) async {
    try {
      if (_calendarApi == null) {
        throw AuthException('Belum login ke Google Calendar');
      }

      print(
          '📅 Fetching events from ${dateRange.startDate} to ${dateRange.endDate}');

      final calendar.Events events = await _calendarApi!.events.list(
        GoogleCalendarConstants.primaryCalendarId,
        timeMin: dateRange.startDate.toUtc(),
        timeMax: dateRange.endDate.toUtc(),
        maxResults: GoogleCalendarConstants.maxEventsPerRequest,
        singleEvents: true,
        orderBy: 'startTime',
      );

      if (events.items == null || events.items!.isEmpty) {
        print('📋 No events found');
        return [];
      }

      print('✅ Found ${events.items!.length} events from Google Calendar');

      // ✅ SAFE CONVERSION dengan error handling per item
      List<GoogleEventModel> googleEvents = [];

      for (int i = 0; i < events.items!.length; i++) {
        try {
          final calendarEvent = events.items![i];

          // Convert calendar.Event to Map untuk parsing yang aman
          final Map<String, dynamic> eventJson =
              _safeEventToJson(calendarEvent);

          // Parse dengan GoogleEventModel yang sudah diperbaiki
          final googleEvent = GoogleEventModel.fromJson(eventJson);
          googleEvents.add(googleEvent);
        } catch (e) {
          print('⚠️ Error parsing event ${i + 1}: $e');
          print('   Event ID: ${events.items![i].id}');
          print('   Event Summary: ${events.items![i].summary}');
          // Skip event yang error, lanjutkan ke event berikutnya
          continue;
        }
      }

      print(
          '✅ Successfully parsed ${googleEvents.length} out of ${events.items!.length} events');
      return googleEvents;
    } catch (e) {
      print('❌ Get events error: $e');

      if (e is AuthException) rethrow;
      throw ServerException(
        'Gagal mengambil events dari Google Calendar: ${e.toString()}',
      );
    }
  }

  // ✅ SAFE EVENT TO JSON CONVERTER
  Map<String, dynamic> _safeEventToJson(calendar.Event event) {
    try {
      return {
        'id': event.id,
        'summary': event.summary,
        'description': event.description,
        'location': event.location,
        'start': _safeEventDateTimeToJson(event.start),
        'end': _safeEventDateTimeToJson(event.end),
        'attendees': _safeAttendeesToJson(event.attendees),
        'recurrence': event.recurrence,
        'created': _safeEventDateTimeToJson(event.created),
        'updated': _safeEventDateTimeToJson(event.updated),
        'colorId': event.colorId,
        'creator': _safeCreatorToJson(event.creator),
      };
    } catch (e) {
      print('❌ Error converting event to JSON: $e');
      print('   Event: ${event.toString()}');
      rethrow;
    }
  }

  Map<String, dynamic>? _safeEventDateTimeToJson(
      calendar.EventDateTime? eventDateTime) {
    if (eventDateTime == null) return null;

    try {
      return {
        'date': eventDateTime.date?.toString(),
        'dateTime': eventDateTime.dateTime?.toString(),
        'timeZone': eventDateTime.timeZone,
      };
    } catch (e) {
      print('⚠️ Error converting EventDateTime: $e');
      return null;
    }
  }

  List<Map<String, dynamic>>? _safeAttendeesToJson(
      List<calendar.EventAttendee>? attendees) {
    if (attendees == null || attendees.isEmpty) return null;

    try {
      return attendees
          .map((attendee) => {
                'email': attendee.email,
                'displayName': attendee.displayName,
                'responseStatus': attendee.responseStatus,
              })
          .toList();
    } catch (e) {
      print('⚠️ Error converting attendees: $e');
      return null;
    }
  }

  Map<String, dynamic>? _safeCreatorToJson(calendar.EventCreator? creator) {
    if (creator == null) return null;

    try {
      return {
        'email': creator.email,
        'displayName': creator.displayName,
      };
    } catch (e) {
      print('⚠️ Error converting creator: $e');
      return null;
    }
  }

  @override
  Future<GoogleEventModel> createEvent(CalendarEventModel event) async {
    try {
      if (_calendarApi == null) {
        throw AuthException('Belum login ke Google Calendar');
      }

      print('➕ Creating event: ${event.title}');

      final googleEvent = GoogleEventModel.fromCalendarEventModel(event);
      final calendar.Event calendarEvent = calendar.Event.fromJson(
        googleEvent.toJson(),
      );

      final calendar.Event createdEvent = await _calendarApi!.events.insert(
        calendarEvent,
        GoogleCalendarConstants.primaryCalendarId,
      );

      print('✅ Event created successfully with ID: ${createdEvent.id}');

      // Safe conversion back to GoogleEventModel
      final eventJson = _safeEventToJson(createdEvent);
      return GoogleEventModel.fromJson(eventJson);
    } catch (e) {
      print('❌ Create event error: $e');

      if (e is AuthException) rethrow;
      throw ServerException(
        'Gagal membuat event di Google Calendar: ${e.toString()}',
      );
    }
  }

  @override
  Future<GoogleEventModel> updateEvent(CalendarEventModel event) async {
    try {
      if (_calendarApi == null) {
        throw AuthException('Belum login ke Google Calendar');
      }

      if (event.googleEventId == null) {
        throw ValidationException('Event ID Google tidak ditemukan');
      }

      print('✏️ Updating event: ${event.title} (ID: ${event.googleEventId})');

      final googleEvent = GoogleEventModel.fromCalendarEventModel(event);
      final calendar.Event calendarEvent = calendar.Event.fromJson(
        googleEvent.toJson(),
      );

      final calendar.Event updatedEvent = await _calendarApi!.events.update(
        calendarEvent,
        GoogleCalendarConstants.primaryCalendarId,
        event.googleEventId!,
      );

      print('✅ Event updated successfully');

      // Safe conversion back to GoogleEventModel
      final eventJson = _safeEventToJson(updatedEvent);
      return GoogleEventModel.fromJson(eventJson);
    } catch (e) {
      print('❌ Update event error: $e');

      if (e is AuthException || e is ValidationException) rethrow;
      throw ServerException(
        'Gagal update event di Google Calendar: ${e.toString()}',
      );
    }
  }

  @override
  Future<bool> deleteEvent(String eventId) async {
    try {
      if (_calendarApi == null) {
        throw AuthException('Belum login ke Google Calendar');
      }

      print('🗑️ Deleting event with ID: $eventId');

      await _calendarApi!.events.delete(
        GoogleCalendarConstants.primaryCalendarId,
        eventId,
      );

      print('✅ Event deleted successfully');
      return true;
    } catch (e) {
      print('❌ Delete event error: $e');

      if (e is AuthException) rethrow;
      throw ServerException(
        'Gagal menghapus event di Google Calendar: ${e.toString()}',
      );
    }
  }

  Future<void> _clearAuth() async {
    try {
      _calendarApi = null;
    } catch (e) {
      print('⚠️ Clear auth warning: $e');
    }
  }
}
