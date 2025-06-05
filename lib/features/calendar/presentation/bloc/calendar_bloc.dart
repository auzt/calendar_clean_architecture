// lib/features/calendar/presentation/bloc/calendar_bloc.dart
// COMPLETELY SILENT VERSION untuk drag operations

import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/error_handler.dart';
import '../../domain/entities/calendar_event.dart' as domain;
import '../../domain/usecases/calendar_usecases.dart';
import '../../data/repositories/calendar_repository_impl.dart';
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

      await result.fold(
        (failure) async {
          if (!emit.isDone) {
            emit(
              CalendarError(
                message: failure.message,
                isNetworkError: failure is NetworkFailure,
                isAuthError: failure is AuthFailure,
              ),
            );
          }
        },
        (events) async {
          final authResult = await useCases
              .authenticateGoogleCalendar.repository
              .isGoogleCalendarAuthenticated();
          final isAuthenticated = authResult.fold((l) => false, (r) => r);

          final syncTimeResult = await useCases
              .authenticateGoogleCalendar.repository
              .getLastSyncTime();
          final lastSyncTime = syncTimeResult.fold((l) => null, (r) => r);

          if (!emit.isDone) {
            emit(
              CalendarLoaded(
                events: events,
                lastSyncTime: lastSyncTime,
                isGoogleAuthenticated: isAuthenticated,
              ),
            );
          }
        },
      );
    } catch (e) {
      ErrorHandler.logError(e);
      if (!emit.isDone) {
        emit(CalendarError(message: 'Terjadi kesalahan: ${e.toString()}'));
      }
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

      await result.fold(
        (failure) async {
          if (!emit.isDone) {
            emit(
              CalendarError(
                message: failure.message,
                isNetworkError: failure is NetworkFailure,
                isAuthError: failure is AuthFailure,
              ),
            );
          }
        },
        (events) async {
          final authResult = await useCases
              .authenticateGoogleCalendar.repository
              .isGoogleCalendarAuthenticated();
          final isAuthenticated = authResult.fold((l) => false, (r) => r);

          final syncTimeResult = await useCases
              .authenticateGoogleCalendar.repository
              .getLastSyncTime();
          final lastSyncTime = syncTimeResult.fold((l) => null, (r) => r);

          if (!emit.isDone) {
            emit(
              CalendarLoaded(
                events: events,
                lastSyncTime: lastSyncTime,
                isGoogleAuthenticated: isAuthenticated,
              ),
            );
          }
        },
      );
    } catch (e) {
      ErrorHandler.logError(e);
      if (!emit.isDone) {
        emit(CalendarError(message: 'Terjadi kesalahan: ${e.toString()}'));
      }
    }
  }

  Future<void> _onCreateEvent(
    CreateEvent event,
    Emitter<CalendarState> emit,
  ) async {
    try {
      final result = await useCases.createCalendarEvent(event.event);

      result.fold(
        (failure) {
          if (!emit.isDone) {
            emit(CalendarError(message: failure.message));
          }
        },
        (createdEvent) {
          if (!emit.isDone) {
            emit(EventCreated(createdEvent));

            // Update events list if currently loaded
            if (state is CalendarLoaded) {
              final currentState = state as CalendarLoaded;
              final updatedEvents = <domain.CalendarEvent>[
                ...currentState.events,
                createdEvent
              ];
              updatedEvents.sort((a, b) => a.startTime.compareTo(b.startTime));

              if (!emit.isDone) {
                emit(currentState.copyWith(events: updatedEvents));
              }
            }
          }
        },
      );
    } catch (e) {
      ErrorHandler.logError(e);
      if (!emit.isDone) {
        emit(CalendarError(message: 'Gagal membuat event: ${e.toString()}'));
      }
    }
  }

  // ✅ COMPLETELY SILENT: Tidak emit apa-apa untuk drag operations
  Future<void> _onUpdateEvent(
    UpdateEvent event,
    Emitter<CalendarState> emit,
  ) async {
    try {
      print('🔇 SILENT UPDATE: Processing ${event.event.title}');

      final result = await useCases.updateCalendarEvent(event.event);

      result.fold(
        (failure) {
          print('❌ Silent update failed: ${failure.message}');
          // ✅ ONLY emit error untuk critical failures
          if (!emit.isDone) {
            emit(CalendarError(message: failure.message));
          }
        },
        (updatedEvent) {
          print('✅ Silent update completed: ${updatedEvent.title}');

          // ✅ CRITICAL: NO EMISSION WHATSOEVER
          // UI sudah ter-handle di day view level dengan local events
          // Background state akan di-update by repository secara internal

          // ✅ COMPLETELY SILENT - tidak ada emit() sama sekali
          print('🔇 Update completed silently - no state emission');
        },
      );
    } catch (e) {
      ErrorHandler.logError(e);
      print('❌ Silent update error: $e');
      // Only emit untuk critical errors
      if (!emit.isDone) {
        emit(CalendarError(message: 'Background sync failed: ${e.toString()}'));
      }
    }
  }

  Future<void> _onDeleteEvent(
    DeleteEvent event,
    Emitter<CalendarState> emit,
  ) async {
    try {
      final result = await useCases.deleteCalendarEvent(event.eventId);

      result.fold(
        (failure) {
          if (!emit.isDone) {
            emit(CalendarError(message: failure.message));
          }
        },
        (success) {
          if (!emit.isDone) {
            emit(EventDeleted(event.eventId));

            // Update events list if currently loaded
            if (state is CalendarLoaded) {
              final currentState = state as CalendarLoaded;
              final updatedEvents = currentState.events
                  .where((e) => e.id != event.eventId)
                  .toList();

              if (!emit.isDone) {
                emit(currentState.copyWith(events: updatedEvents));
              }
            }
          }
        },
      );
    } catch (e) {
      ErrorHandler.logError(e);
      if (!emit.isDone) {
        emit(CalendarError(message: 'Gagal menghapus event: ${e.toString()}'));
      }
    }
  }

  // ✅ Manual sync dengan forceSync
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

      print(
          '🔄 Manual sync started for range: ${event.dateRange.startDate} to ${event.dateRange.endDate}');

      final repository = useCases.authenticateGoogleCalendar.repository;

      if (repository is CalendarRepositoryImpl) {
        final result = await repository.forceSync(event.dateRange);

        await result.fold(
          (failure) async {
            print('❌ Manual sync failed: ${failure.message}');
            if (!emit.isDone) {
              emit(
                CalendarError(
                  message: 'Sync gagal: ${failure.message}',
                  isNetworkError: failure is NetworkFailure,
                  isAuthError: failure is AuthFailure,
                ),
              );
            }
          },
          (events) async {
            print('✅ Manual sync completed with ${events.length} events');

            final authResult = await repository.isGoogleCalendarAuthenticated();
            final isAuthenticated = authResult.fold((l) => false, (r) => r);

            final syncTimeResult = await repository.getLastSyncTime();
            final lastSyncTime = syncTimeResult.fold((l) => null, (r) => r);

            if (!emit.isDone) {
              emit(
                CalendarLoaded(
                  events: events,
                  lastSyncTime: lastSyncTime,
                  isGoogleAuthenticated: isAuthenticated,
                ),
              );
            }
          },
        );
      } else {
        // Fallback sync
        final result = await useCases.syncGoogleCalendar(event.dateRange);

        await result.fold(
          (failure) async {
            print('❌ Fallback sync failed: ${failure.message}');
            if (!emit.isDone) {
              emit(
                CalendarError(
                  message: 'Sync gagal: ${failure.message}',
                  isNetworkError: failure is NetworkFailure,
                  isAuthError: failure is AuthFailure,
                ),
              );
            }
          },
          (events) async {
            print('✅ Fallback sync completed with ${events.length} events');

            final authResult = await useCases
                .authenticateGoogleCalendar.repository
                .isGoogleCalendarAuthenticated();
            final isAuthenticated = authResult.fold((l) => false, (r) => r);

            final syncTimeResult = await useCases
                .authenticateGoogleCalendar.repository
                .getLastSyncTime();
            final lastSyncTime = syncTimeResult.fold((l) => null, (r) => r);

            if (!emit.isDone) {
              emit(
                CalendarLoaded(
                  events: events,
                  lastSyncTime: lastSyncTime,
                  isGoogleAuthenticated: isAuthenticated,
                ),
              );
            }
          },
        );
      }
    } catch (e) {
      ErrorHandler.logError(e);
      print('❌ Manual sync error: $e');
      if (!emit.isDone) {
        emit(CalendarError(message: 'Gagal sinkronisasi: ${e.toString()}'));
      }
    }
  }

  Future<void> _onAuthenticateGoogle(
    AuthenticateGoogle event,
    Emitter<CalendarState> emit,
  ) async {
    try {
      print('🔐 Starting Google authentication...');
      emit(CalendarLoading());

      final result = await useCases.authenticateGoogleCalendar();

      result.fold(
        (failure) {
          print('❌ Authentication failed: ${failure.message}');
          if (!emit.isDone) {
            emit(GoogleAuthFailed(failure.message));
          }
        },
        (success) {
          print('✅ Authentication result: $success');
          if (!emit.isDone) {
            if (success) {
              emit(GoogleAuthSuccess());
            } else {
              emit(const GoogleAuthFailed('Login gagal - tidak ada respons'));
            }
          }
        },
      );
    } catch (e) {
      print('❌ Authentication error: $e');
      ErrorHandler.logError(e);
      if (!emit.isDone) {
        emit(GoogleAuthFailed('Login error: ${e.toString()}'));
      }
    }
  }

  Future<void> _onSignOutGoogle(
    SignOutGoogle event,
    Emitter<CalendarState> emit,
  ) async {
    try {
      final result = await useCases.authenticateGoogleCalendar.repository
          .signOutGoogleCalendar();

      result.fold(
        (failure) {
          if (!emit.isDone) {
            emit(CalendarError(message: failure.message));
          }
        },
        (success) {
          if (!emit.isDone) {
            if (success) {
              emit(GoogleSignedOut());
              emit(CalendarInitial());
            }
          }
        },
      );
    } catch (e) {
      ErrorHandler.logError(e);
      if (!emit.isDone) {
        emit(CalendarError(message: 'Logout error: ${e.toString()}'));
      }
    }
  }

  Future<void> _onCheckGoogleAuth(
    CheckGoogleAuth event,
    Emitter<CalendarState> emit,
  ) async {
    try {
      final result = await useCases.authenticateGoogleCalendar.repository
          .isGoogleCalendarAuthenticated();

      result.fold(
        (failure) => {}, // Do nothing on failure for this check
        (isAuthenticated) {
          if (!emit.isDone && state is CalendarLoaded) {
            final currentState = state as CalendarLoaded;
            emit(currentState.copyWith(isGoogleAuthenticated: isAuthenticated));
          }
        },
      );
    } catch (e) {
      ErrorHandler.logError(e);
      // Silent fail for auth check
    }
  }

  Future<void> _onClearCache(
    ClearCache event,
    Emitter<CalendarState> emit,
  ) async {
    try {
      final result =
          await useCases.authenticateGoogleCalendar.repository.clearCache();

      result.fold(
        (failure) {
          if (!emit.isDone) {
            emit(CalendarError(message: failure.message));
          }
        },
        (success) {
          if (!emit.isDone) {
            emit(CalendarInitial());
          }
        },
      );
    } catch (e) {
      ErrorHandler.logError(e);
      if (!emit.isDone) {
        emit(CalendarError(message: 'Gagal clear cache: ${e.toString()}'));
      }
    }
  }

  Future<void> _onWatchEventsForRange(
    WatchEventsForRange event,
    Emitter<CalendarState> emit,
  ) async {
    try {
      await _eventsSubscription?.cancel();

      _eventsSubscription =
          useCases.watchCalendarEvents(event.dateRange).listen(
        (events) {
          if (!emit.isDone) {
            if (state is CalendarLoaded) {
              final currentState = state as CalendarLoaded;
              emit(currentState.copyWith(events: events));
            } else {
              emit(CalendarLoaded(events: events));
            }
          }
        },
        onError: (error) {
          ErrorHandler.logError(error);
          if (!emit.isDone) {
            emit(CalendarError(message: 'Stream error: ${error.toString()}'));
          }
        },
      );
    } catch (e) {
      ErrorHandler.logError(e);
      if (!emit.isDone) {
        emit(CalendarError(message: 'Watch events error: ${e.toString()}'));
      }
    }
  }

  // ✅ Add mounted check for safety
  bool get mounted => !isClosed;

  @override
  Future<void> close() {
    _eventsSubscription?.cancel();
    return super.close();
  }
}
