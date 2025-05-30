// lib/features/calendar/data/datasources/google_calendar_remote_datasource.dart
import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis_auth/googleapis_auth.dart' as auth;
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
    : _googleSignIn =
          googleSignIn ?? GoogleSignIn(scopes: GoogleCalendarConstants.scopes);

  @override
  Future<bool> authenticate() async {
    try {
      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      if (account == null) {
        throw AuthException('Login dibatalkan oleh user');
      }

      final GoogleSignInAuthentication authentication =
          await account.authentication;
      final auth.AccessCredentials credentials = auth.AccessCredentials(
        auth.AccessToken(
          'Bearer',
          authentication.accessToken!,
          DateTime.now().add(const Duration(hours: 1)),
        ),
        authentication.idToken,
        GoogleCalendarConstants.scopes,
      );

      final auth.AuthClient client = auth.authenticatedClient(
        auth.ClientId('', ''),
        credentials,
      );

      _calendarApi = calendar.CalendarApi(client);
      return true;
    } catch (e) {
      throw AuthException('Gagal login ke Google Calendar: ${e.toString()}');
    }
  }

  @override
  Future<bool> signOut() async {
    try {
      await _googleSignIn.signOut();
      _calendarApi = null;
      return true;
    } catch (e) {
      throw AuthException('Gagal logout: ${e.toString()}');
    }
  }

  @override
  Future<bool> isAuthenticated() async {
    try {
      final GoogleSignInAccount? account = _googleSignIn.currentUser;
      return account != null && _calendarApi != null;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<List<GoogleEventModel>> getEvents(CalendarDateRange dateRange) async {
    try {
      if (_calendarApi == null) {
        throw AuthException('Belum login ke Google Calendar');
      }

      final calendar.Events events = await _calendarApi!.events.list(
        GoogleCalendarConstants.primaryCalendarId,
        timeMin: dateRange.startDate.toUtc(),
        timeMax: dateRange.endDate.toUtc(),
        maxResults: GoogleCalendarConstants.maxEventsPerRequest,
        singleEvents: true,
        orderBy: 'startTime',
      );

      if (events.items == null) {
        return [];
      }

      return events.items!.map((event) {
        return GoogleEventModel.fromJson(event.toJson());
      }).toList();
    } catch (e) {
      if (e is AuthException) rethrow;
      throw ServerException(
        'Gagal mengambil events dari Google Calendar: ${e.toString()}',
      );
    }
  }

  @override
  Future<GoogleEventModel> createEvent(CalendarEventModel event) async {
    try {
      if (_calendarApi == null) {
        throw AuthException('Belum login ke Google Calendar');
      }

      final googleEvent = GoogleEventModel.fromCalendarEventModel(event);
      final calendar.Event calendarEvent = calendar.Event.fromJson(
        googleEvent.toJson(),
      );

      final calendar.Event createdEvent = await _calendarApi!.events.insert(
        calendarEvent,
        GoogleCalendarConstants.primaryCalendarId,
      );

      return GoogleEventModel.fromJson(createdEvent.toJson());
    } catch (e) {
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

      final googleEvent = GoogleEventModel.fromCalendarEventModel(event);
      final calendar.Event calendarEvent = calendar.Event.fromJson(
        googleEvent.toJson(),
      );

      final calendar.Event updatedEvent = await _calendarApi!.events.update(
        calendarEvent,
        GoogleCalendarConstants.primaryCalendarId,
        event.googleEventId!,
      );

      return GoogleEventModel.fromJson(updatedEvent.toJson());
    } catch (e) {
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

      await _calendarApi!.events.delete(
        GoogleCalendarConstants.primaryCalendarId,
        eventId,
      );

      return true;
    } catch (e) {
      if (e is AuthException) rethrow;
      throw ServerException(
        'Gagal menghapus event di Google Calendar: ${e.toString()}',
      );
    }
  }
}
