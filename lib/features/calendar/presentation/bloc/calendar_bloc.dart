// lib/features/calendar/presentation/bloc/calendar_bloc.dart
// UPDATED VERSION - Menggunakan forceSync untuk mencegah duplikasi

import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/error_handler.dart';
import '../../domain/entities/calendar_event.dart' as domain;
import '../../domain/usecases/calendar_usecases.dart';
import '../../data/repositories/calendar_repository_impl.dart'; // ✅ TAMBAHAN IMPORT INI
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

  Future<void> _onUpdateEvent(
    UpdateEvent event,
    Emitter<CalendarState> emit,
  ) async {
    try {
      final result = await useCases.updateCalendarEvent(event.event);

      result.fold(
        (failure) {
          if (!emit.isDone) {
            emit(CalendarError(message: failure.message));
          }
        },
        (updatedEvent) {
          if (!emit.isDone) {
            emit(EventUpdated(updatedEvent));

            // Update the event in the current list
            if (state is CalendarLoaded) {
              final currentState = state as CalendarLoaded;
              final updatedEvents =
                  currentState.events.map<domain.CalendarEvent>((e) {
                return e.id == updatedEvent.id ? updatedEvent : e;
              }).toList();
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
        emit(CalendarError(message: 'Gagal update event: ${e.toString()}'));
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

            // Remove the event from the current list
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

  // ✅ UPDATED: Menggunakan forceSync untuk mencegah duplikasi
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

      // ✅ Gunakan repository langsung untuk forceSync
      final repository = useCases.authenticateGoogleCalendar.repository;

      // Cast repository ke implementation untuk akses forceSync
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
        // Fallback ke sync biasa jika tidak bisa cast
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

  // ✅ IMPROVED: Better error handling for authentication
  Future<void> _onAuthenticateGoogle(
    AuthenticateGoogle event,
    Emitter<CalendarState> emit,
  ) async {
    try {
      print('🔐 Starting Google authentication...');

      // Show loading state
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

  @override
  Future<void> close() {
    _eventsSubscription?.cancel();
    return super.close();
  }
}
