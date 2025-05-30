// lib/features/calendar/presentation/bloc/calendar_bloc.dart
import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/error_handler.dart';
import '../../domain/entities/calendar_event.dart' as domain;
import '../../domain/usecases/calendar_usecases.dart';
import 'calendar_event.dart';
import 'calendar_state.dart';

class CalendarBloc extends Bloc<CalendarEvent, CalendarState> {
  final CalendarUseCases useCases;
  StreamSubscription? _eventsSubscription;

  CalendarBloc({required this.useCases}) : super(CalendarInitial()) {
    on<LoadCalendarEvents>(_onLoadCalendarEvents);
    on<LoadEventsForDate>(_onLoadEventsForDate);
    on<CreateEvent>(_onCreateEvent);
    on<UpdateEvent>(_onUpdateEvent);
    on<DeleteEvent>(_onDeleteEvent);
    on<SyncWithGoogle>(_onSyncWithGoogle);
    on<AuthenticateGoogle>(_onAuthenticateGoogle);
    on<SignOutGoogle>(_onSignOutGoogle);
    on<CheckGoogleAuth>(_onCheckGoogleAuth);
    on<ClearCache>(_onClearCache);
    on<WatchEventsForRange>(_onWatchEventsForRange);
  }

  Future<void> _onLoadCalendarEvents(
    LoadCalendarEvents event,
    Emitter<CalendarState> emit,
  ) async {
    try {
      if (state is! CalendarLoaded) {
        emit(CalendarLoading());
      }

      final result = await useCases.getCalendarEvents(
        event.dateRange,
        forceRefresh: event.forceRefresh,
      );

      result.fold(
        (failure) => emit(
          CalendarError(
            message: failure.message,
            isNetworkError: failure is NetworkFailure,
            isAuthError: failure is AuthFailure,
          ),
        ),
        (events) async {
          // Get auth status and last sync time
          final authResult =
              await useCases.authenticateGoogleCalendar.repository
                  .isGoogleCalendarAuthenticated();
          final isAuthenticated = authResult.fold((l) => false, (r) => r);

          final syncTimeResult =
              await useCases.authenticateGoogleCalendar.repository
                  .getLastSyncTime();
          final lastSyncTime = syncTimeResult.fold((l) => null, (r) => r);

          emit(
            CalendarLoaded(
              events: events,
              lastSyncTime: lastSyncTime,
              isGoogleAuthenticated: isAuthenticated,
            ),
          );
        },
      );
    } catch (e) {
      ErrorHandler.logError(e);
      emit(CalendarError(message: 'Terjadi kesalahan: ${e.toString()}'));
    }
  }

  Future<void> _onLoadEventsForDate(
    LoadEventsForDate event,
    Emitter<CalendarState> emit,
  ) async {
    try {
      if (state is! CalendarLoaded) {
        emit(CalendarLoading());
      }

      final result = await useCases.getEventsForDate(
        event.date,
        forceRefresh: event.forceRefresh,
      );

      result.fold(
        (failure) => emit(
          CalendarError(
            message: failure.message,
            isNetworkError: failure is NetworkFailure,
            isAuthError: failure is AuthFailure,
          ),
        ),
        (events) async {
          final authResult =
              await useCases.authenticateGoogleCalendar.repository
                  .isGoogleCalendarAuthenticated();
          final isAuthenticated = authResult.fold((l) => false, (r) => r);

          final syncTimeResult =
              await useCases.authenticateGoogleCalendar.repository
                  .getLastSyncTime();
          final lastSyncTime = syncTimeResult.fold((l) => null, (r) => r);

          emit(
            CalendarLoaded(
              events: events,
              lastSyncTime: lastSyncTime,
              isGoogleAuthenticated: isAuthenticated,
            ),
          );
        },
      );
    } catch (e) {
      ErrorHandler.logError(e);
      emit(CalendarError(message: 'Terjadi kesalahan: ${e.toString()}'));
    }
  }

  Future<void> _onCreateEvent(
    CreateEvent event,
    Emitter<CalendarState> emit,
  ) async {
    try {
      final result = await useCases.createCalendarEvent(event.event);

      result.fold((failure) => emit(CalendarError(message: failure.message)), (
        createdEvent,
      ) {
        emit(EventCreated(createdEvent));
        // Reload events to show the new one
        if (state is CalendarLoaded) {
          final currentState = state as CalendarLoaded;
          final updatedEvents = [...currentState.events, createdEvent];
          updatedEvents.sort((a, b) => a.startTime.compareTo(b.startTime));

          emit(currentState.copyWith(events: updatedEvents));
        }
      });
    } catch (e) {
      ErrorHandler.logError(e);
      emit(CalendarError(message: 'Gagal membuat event: ${e.toString()}'));
    }
  }

  Future<void> _onUpdateEvent(
    UpdateEvent event,
    Emitter<CalendarState> emit,
  ) async {
    try {
      final result = await useCases.updateCalendarEvent(event.event);

      result.fold((failure) => emit(CalendarError(message: failure.message)), (
        updatedEvent,
      ) {
        emit(EventUpdated(updatedEvent));
        // Update the event in the current list
        if (state is CalendarLoaded) {
          final currentState = state as CalendarLoaded;
          final updatedEvents =
              currentState.events.map((e) {
                return e.id == updatedEvent.id ? updatedEvent : e;
              }).toList();
          updatedEvents.sort((a, b) => a.startTime.compareTo(b.startTime));

          emit(currentState.copyWith(events: updatedEvents));
        }
      });
    } catch (e) {
      ErrorHandler.logError(e);
      emit(CalendarError(message: 'Gagal update event: ${e.toString()}'));
    }
  }

  Future<void> _onDeleteEvent(
    DeleteEvent event,
    Emitter<CalendarState> emit,
  ) async {
    try {
      final result = await useCases.deleteCalendarEvent(event.eventId);

      result.fold((failure) => emit(CalendarError(message: failure.message)), (
        success,
      ) {
        emit(EventDeleted(event.eventId));
        // Remove the event from the current list
        if (state is CalendarLoaded) {
          final currentState = state as CalendarLoaded;
          final updatedEvents =
              currentState.events.where((e) => e.id != event.eventId).toList();

          emit(currentState.copyWith(events: updatedEvents));
        }
      });
    } catch (e) {
      ErrorHandler.logError(e);
      emit(CalendarError(message: 'Gagal menghapus event: ${e.toString()}'));
    }
  }

  Future<void> _onSyncWithGoogle(
    SyncWithGoogle event,
    Emitter<CalendarState> emit,
  ) async {
    try {
      List<domain.CalendarEvent> currentEvents = [];
      if (state is CalendarLoaded) {
        currentEvents = (state as CalendarLoaded).events;
        emit(CalendarSyncing(currentEvents));
      } else {
        emit(CalendarLoading());
      }

      final result = await useCases.syncGoogleCalendar(event.dateRange);

      result.fold(
        (failure) => emit(
          CalendarError(
            message: failure.message,
            isNetworkError: failure is NetworkFailure,
            isAuthError: failure is AuthFailure,
          ),
        ),
        (events) async {
          final authResult =
              await useCases.authenticateGoogleCalendar.repository
                  .isGoogleCalendarAuthenticated();
          final isAuthenticated = authResult.fold((l) => false, (r) => r);

          final syncTimeResult =
              await useCases.authenticateGoogleCalendar.repository
                  .getLastSyncTime();
          final lastSyncTime = syncTimeResult.fold((l) => null, (r) => r);

          emit(
            CalendarLoaded(
              events: events,
              lastSyncTime: lastSyncTime,
              isGoogleAuthenticated: isAuthenticated,
            ),
          );
        },
      );
    } catch (e) {
      ErrorHandler.logError(e);
      emit(CalendarError(message: 'Gagal sinkronisasi: ${e.toString()}'));
    }
  }

  Future<void> _onAuthenticateGoogle(
    AuthenticateGoogle event,
    Emitter<CalendarState> emit,
  ) async {
    try {
      final result = await useCases.authenticateGoogleCalendar();

      result.fold((failure) => emit(GoogleAuthFailed(failure.message)), (
        success,
      ) {
        if (success) {
          emit(GoogleAuthSuccess());
        } else {
          emit(const GoogleAuthFailed('Login gagal'));
        }
      });
    } catch (e) {
      ErrorHandler.logError(e);
      emit(GoogleAuthFailed('Login error: ${e.toString()}'));
    }
  }

  Future<void> _onSignOutGoogle(
    SignOutGoogle event,
    Emitter<CalendarState> emit,
  ) async {
    try {
      final result =
          await useCases.authenticateGoogleCalendar.repository
              .signOutGoogleCalendar();

      result.fold((failure) => emit(CalendarError(message: failure.message)), (
        success,
      ) {
        if (success) {
          emit(GoogleSignedOut());
          emit(CalendarInitial());
        }
      });
    } catch (e) {
      ErrorHandler.logError(e);
      emit(CalendarError(message: 'Logout error: ${e.toString()}'));
    }
  }

  Future<void> _onCheckGoogleAuth(
    CheckGoogleAuth event,
    Emitter<CalendarState> emit,
  ) async {
    try {
      final result =
          await useCases.authenticateGoogleCalendar.repository
              .isGoogleCalendarAuthenticated();

      result.fold((failure) => {}, (isAuthenticated) {
        if (state is CalendarLoaded) {
          final currentState = state as CalendarLoaded;
          emit(currentState.copyWith(isGoogleAuthenticated: isAuthenticated));
        }
      });
    } catch (e) {
      ErrorHandler.logError(e);
    }
  }

  Future<void> _onClearCache(
    ClearCache event,
    Emitter<CalendarState> emit,
  ) async {
    try {
      final result =
          await useCases.authenticateGoogleCalendar.repository.clearCache();

      result.fold((failure) => emit(CalendarError(message: failure.message)), (
        success,
      ) {
        emit(CalendarInitial());
      });
    } catch (e) {
      ErrorHandler.logError(e);
      emit(CalendarError(message: 'Gagal clear cache: ${e.toString()}'));
    }
  }

  Future<void> _onWatchEventsForRange(
    WatchEventsForRange event,
    Emitter<CalendarState> emit,
  ) async {
    try {
      await _eventsSubscription?.cancel();

      _eventsSubscription = useCases
          .watchCalendarEvents(event.dateRange)
          .listen(
            (events) {
              if (state is CalendarLoaded) {
                final currentState = state as CalendarLoaded;
                emit(currentState.copyWith(events: events));
              } else {
                emit(CalendarLoaded(events: events));
              }
            },
            onError: (error) {
              ErrorHandler.logError(error);
              emit(CalendarError(message: 'Stream error: ${error.toString()}'));
            },
          );
    } catch (e) {
      ErrorHandler.logError(e);
      emit(CalendarError(message: 'Watch events error: ${e.toString()}'));
    }
  }

  @override
  Future<void> close() {
    _eventsSubscription?.cancel();
    return super.close();
  }
}
