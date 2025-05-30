// lib/features/calendar/presentation/bloc/calendar_state.dart
import 'package:equatable/equatable.dart';
import '../../domain/entities/calendar_event.dart' as domain;

abstract class CalendarState extends Equatable {
  const CalendarState();

  @override
  List<Object?> get props => [];
}

class CalendarInitial extends CalendarState {}

class CalendarLoading extends CalendarState {}

class CalendarLoaded extends CalendarState {
  final List<domain.CalendarEvent> events;
  final DateTime? lastSyncTime;
  final bool isGoogleAuthenticated;

  const CalendarLoaded({
    required this.events,
    this.lastSyncTime,
    this.isGoogleAuthenticated = false,
  });

  @override
  List<Object?> get props => [events, lastSyncTime, isGoogleAuthenticated];

  CalendarLoaded copyWith({
    List<domain.CalendarEvent>? events,
    DateTime? lastSyncTime,
    bool? isGoogleAuthenticated,
  }) {
    return CalendarLoaded(
      events: events ?? this.events,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      isGoogleAuthenticated:
          isGoogleAuthenticated ?? this.isGoogleAuthenticated,
    );
  }
}

class CalendarError extends CalendarState {
  final String message;
  final bool isNetworkError;
  final bool isAuthError;

  const CalendarError({
    required this.message,
    this.isNetworkError = false,
    this.isAuthError = false,
  });

  @override
  List<Object> get props => [message, isNetworkError, isAuthError];
}

class CalendarSyncing extends CalendarState {
  final List<domain.CalendarEvent> currentEvents;

  const CalendarSyncing(this.currentEvents);

  @override
  List<Object> get props => [currentEvents];
}

class EventCreated extends CalendarState {
  final domain.CalendarEvent event;

  const EventCreated(this.event);

  @override
  List<Object> get props => [event];
}

class EventUpdated extends CalendarState {
  final domain.CalendarEvent event;

  const EventUpdated(this.event);

  @override
  List<Object> get props => [event];
}

class EventDeleted extends CalendarState {
  final String eventId;

  const EventDeleted(this.eventId);

  @override
  List<Object> get props => [eventId];
}

class GoogleAuthSuccess extends CalendarState {}

class GoogleAuthFailed extends CalendarState {
  final String message;

  const GoogleAuthFailed(this.message);

  @override
  List<Object> get props => [message];
}

class GoogleSignedOut extends CalendarState {}
