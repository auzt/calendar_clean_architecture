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
    return color.value;
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

// lib/features/calendar/data/models/google_event_model.dart
import 'package:json_annotation/json_annotation.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'calendar_event_model.dart';

part 'google_event_model.g.dart';

@JsonSerializable()
class GoogleEventModel {
  final String? id;
  final String? summary;
  final String? description;
  final String? location;
  final GoogleEventDateTime? start;
  final GoogleEventDateTime? end;
  final List<GoogleEventAttendee>? attendees;
  final List<String>? recurrence;
  final GoogleEventDateTime? created;
  final GoogleEventDateTime? updated;
  final String? colorId;
  final GoogleEventCreator? creator;

  GoogleEventModel({
    this.id,
    this.summary,
    this.description,
    this.location,
    this.start,
    this.end,
    this.attendees,
    this.recurrence,
    this.created,
    this.updated,
    this.colorId,
    this.creator,
  });

  factory GoogleEventModel.fromJson(Map<String, dynamic> json) =>
      _$GoogleEventModelFromJson(json);

  Map<String, dynamic> toJson() => _$GoogleEventModelToJson(this);

  CalendarEventModel toCalendarEventModel() {
    final startDateTime = start?.toDateTime() ?? DateTime.now();
    final endDateTime = end?.toDateTime() ?? startDateTime.add(const Duration(hours: 1));
    final isAllDay = start?.date != null;

    return CalendarEventModel(
      id: const Uuid().v4(),
      title: summary ?? 'Tanpa Judul',
      description: description,
      startTime: startDateTime,
      endTime: endDateTime,
      location: location,
      isAllDay: isAllDay,
      color: _getColorFromId(colorId),
      googleEventId: id,
      attendees: attendees?.map((a) => a.email ?? '').where((e) => e.isNotEmpty).toList() ?? [],
      recurrence: recurrence?.join(', '),
      isFromGoogle: true,
      lastModified: updated?.toDateTime(),
      createdBy: creator?.email,
    );
  }

  static GoogleEventModel fromCalendarEventModel(CalendarEventModel event) {
    return GoogleEventModel(
      id: event.googleEventId,
      summary: event.title,
      description: event.description,
      location: event.location,
      start: GoogleEventDateTime.fromDateTime(event.startTime, event.isAllDay),
      end: GoogleEventDateTime.fromDateTime(event.endTime, event.isAllDay),
      attendees: event.attendees.map((email) => GoogleEventAttendee(email: email)).toList(),
      recurrence: event.recurrence?.split(', '),
      colorId: _getIdFromColor(event.color),
    );
  }

  Color _getColorFromId(String? colorId) {
    switch (colorId) {
      case '1':
        return Colors.blue;
      case '2':
        return Colors.green;
      case '3':
        return Colors.purple;
      case '4':
        return Colors.red;
      case '5':
        return Colors.orange;
      case '6':
        return Colors.teal;
      case '7':
        return Colors.cyan;
      case '8':
        return Colors.grey;
      case '9':
        return Colors.indigo;
      case '10':
        return Colors.lime;
      case '11':
        return Colors.pink;
      default:
        return Colors.blue;
    }
  }

  static String _getIdFromColor(Color color) {
    if (color == Colors.blue) return '1';
    if (color == Colors.green) return '2';
    if (color == Colors.purple) return '3';
    if (color == Colors.red) return '4';
    if (color == Colors.orange) return '5';
    if (color == Colors.teal) return '6';
    if (color == Colors.cyan) return '7';
    if (color == Colors.grey) return '8';
    if (color == Colors.indigo) return '9';
    if (color == Colors.lime) return '10';
    if (color == Colors.pink) return '11';
    return '1';
  }
}

@JsonSerializable()
class GoogleEventDateTime {
  final String? date;
  final String? dateTime;
  final String? timeZone;

  GoogleEventDateTime({
    this.date,
    this.dateTime,
    this.timeZone,
  });

  factory GoogleEventDateTime.fromJson(Map<String, dynamic> json) =>
      _$GoogleEventDateTimeFromJson(json);

  Map<String, dynamic> toJson() => _$GoogleEventDateTimeToJson(this);

  static GoogleEventDateTime fromDateTime(DateTime dateTime, bool isAllDay) {
    if (isAllDay) {
      return GoogleEventDateTime(
        date: dateTime.toIso8601String().split('T')[0],
      );
    } else {
      return GoogleEventDateTime(
        dateTime: dateTime.toIso8601String(),
        timeZone: 'Asia/Jakarta',
      );
    }
  }

  DateTime toDateTime() {
    if (date != null) {
      return DateTime.parse(date!);
    } else if (dateTime != null) {
      return DateTime.parse(dateTime!);
    } else {
      return DateTime.now();
    }
  }
}

@JsonSerializable()
class GoogleEventAttendee {
  final String? email;
  final String? displayName;
  final String? responseStatus;

  GoogleEventAttendee({
    this.email,
    this.displayName,
    this.responseStatus,
  });

  factory GoogleEventAttendee.fromJson(Map<String, dynamic> json) =>
      _$GoogleEventAttendeeFromJson(json);

  Map<String, dynamic> toJson() => _$GoogleEventAttendeeToJson(this);
}

@JsonSerializable()
class GoogleEventCreator {
  final String? email;
  final String? displayName;

  GoogleEventCreator({
    this.email,
    this.displayName,
  });

  factory GoogleEventCreator.fromJson(Map<String, dynamic> json) =>
      _$GoogleEventCreatorFromJson(json);

  Map<String, dynamic> toJson() => _$GoogleEventCreatorToJson(this);
}

@JsonSerializable()
class GoogleCalendarResponse {
  final String? kind;
  final String? etag;
  final String? summary;
  final String? description;
  final List<GoogleEventModel>? items;
  final String? nextPageToken;

  GoogleCalendarResponse({
    this.kind,
    this.etag,
    this.summary,
    this.description,
    this.items,
    this.nextPageToken,
  });

  factory GoogleCalendarResponse.fromJson(Map<String, dynamic> json) =>
      _$GoogleCalendarResponseFromJson(json);

  Map<String, dynamic> toJson() => _$GoogleCalendarResponseToJson(this);
}