// lib/features/calendar/data/models/calendar_event_model.dart
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';
import '../../domain/entities/calendar_event.dart';

part 'calendar_event_model.g.dart';

@HiveType(typeId: 0)
@JsonSerializable()
class CalendarEventModel extends CalendarEvent {
  @HiveField(0)
  @override
  final String id;

  @HiveField(1)
  @override
  final String title;

  @HiveField(2)
  @override
  final String? description;

  @HiveField(3)
  @override
  final DateTime startTime;

  @HiveField(4)
  @override
  final DateTime endTime;

  @HiveField(5)
  @override
  final String? location;

  @HiveField(6)
  @override
  final bool isAllDay;

  @HiveField(7)
  @JsonKey(fromJson: _colorFromJson, toJson: _colorToJson)
  @override
  final Color color;

  @HiveField(8)
  @override
  final String? googleEventId;

  @HiveField(9)
  @override
  final List<String> attendees;

  @HiveField(10)
  @override
  final String? recurrence;

  @HiveField(11)
  @override
  final bool isFromGoogle;

  @HiveField(12)
  @override
  final DateTime? lastModified;

  @HiveField(13)
  @override
  final String? createdBy;

  @HiveField(14)
  @override
  final Map<String, dynamic>? additionalData;

  const CalendarEventModel({
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
  }) : super(
          id: id,
          title: title,
          startTime: startTime,
          endTime: endTime,
          description: description,
          location: location,
          isAllDay: isAllDay,
          color: color,
          googleEventId: googleEventId,
          attendees: attendees,
          recurrence: recurrence,
          isFromGoogle: isFromGoogle,
          lastModified: lastModified,
          createdBy: createdBy,
          additionalData: additionalData,
        );

  factory CalendarEventModel.fromJson(Map<String, dynamic> json) =>
      _$CalendarEventModelFromJson(json);

  Map<String, dynamic> toJson() => _$CalendarEventModelToJson(this);

  factory CalendarEventModel.fromEntity(CalendarEvent event) {
    return CalendarEventModel(
      id: event.id,
      title: event.title,
      description: event.description,
      startTime: event.startTime,
      endTime: event.endTime,
      location: event.location,
      isAllDay: event.isAllDay,
      color: event.color,
      googleEventId: event.googleEventId,
      attendees: event.attendees,
      recurrence: event.recurrence,
      isFromGoogle: event.isFromGoogle,
      lastModified: event.lastModified,
      createdBy: event.createdBy,
      additionalData: event.additionalData,
    );
  }

  CalendarEvent toEntity() {
    return CalendarEvent(
      id: id,
      title: title,
      description: description,
      startTime: startTime,
      endTime: endTime,
      location: location,
      isAllDay: isAllDay,
      color: color,
      googleEventId: googleEventId,
      attendees: attendees,
      recurrence: recurrence,
      isFromGoogle: isFromGoogle,
      lastModified: lastModified,
      createdBy: createdBy,
      additionalData: additionalData,
    );
  }

  static Color _colorFromJson(int colorValue) {
    return Color(colorValue);
  }

  static int _colorToJson(Color color) {
    return color.value; // Keep for backward compatibility
    // TODO: Update to color.toARGB32() when minimum Flutter version is 3.19+
  }

  @override
  CalendarEventModel copyWith({
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
    return CalendarEventModel(
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
}
