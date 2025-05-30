// lib/features/calendar/domain/entities/calendar_event.dart
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

class CalendarEvent extends Equatable {
  final String id;
  final String title;
  final String? description;
  final DateTime startTime;
  final DateTime endTime;
  final String? location;
  final bool isAllDay;
  final Color color;
  final String? googleEventId;
  final List<String> attendees;
  final String? recurrence;
  final bool isFromGoogle;
  final DateTime? lastModified;
  final String? createdBy;
  final Map<String, dynamic>? additionalData;

  const CalendarEvent({
    required this.id,
    required this.title,
    required this.startTime,
    required this.endTime,
    this.description,
    this.location,
    this.isAllDay = false,
    this.color = Colors.blue,
    this.googleEventId,
    this.attendees = const [],
    this.recurrence,
    this.isFromGoogle = false,
    this.lastModified,
    this.createdBy,
    this.additionalData,
  });

  Duration get duration => endTime.difference(startTime);

  bool get isMultiDay {
    return !_isSameDay(startTime, endTime);
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool conflictsWith(CalendarEvent other) {
    return startTime.isBefore(other.endTime) &&
        other.startTime.isBefore(endTime);
  }

  CalendarEvent copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? startTime,
    DateTime? endTime,
    String? location,
    bool? isAllDay,
    Color? color,
    String? googleEventId,
    List<String>? attendees,
    String? recurrence,
    bool? isFromGoogle,
    DateTime? lastModified,
    String? createdBy,
    Map<String, dynamic>? additionalData,
  }) {
    return CalendarEvent(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      location: location ?? this.location,
      isAllDay: isAllDay ?? this.isAllDay,
      color: color ?? this.color,
      googleEventId: googleEventId ?? this.googleEventId,
      attendees: attendees ?? this.attendees,
      recurrence: recurrence ?? this.recurrence,
      isFromGoogle: isFromGoogle ?? this.isFromGoogle,
      lastModified: lastModified ?? this.lastModified,
      createdBy: createdBy ?? this.createdBy,
      additionalData: additionalData ?? this.additionalData,
    );
  }

  @override
  List<Object?> get props => [
    id,
    title,
    description,
    startTime,
    endTime,
    location,
    isAllDay,
    color,
    googleEventId,
    attendees,
    recurrence,
    isFromGoogle,
    lastModified,
    createdBy,
    additionalData,
  ];
}
