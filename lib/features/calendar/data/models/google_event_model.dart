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
    final endDateTime =
        end?.toDateTime() ?? startDateTime.add(const Duration(hours: 1));
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
      attendees:
          attendees
              ?.map((a) => a.email ?? '')
              .where((e) => e.isNotEmpty)
              .toList() ??
          [],
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
      attendees:
          event.attendees
              .map((email) => GoogleEventAttendee(email: email))
              .toList(),
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

  GoogleEventDateTime({this.date, this.dateTime, this.timeZone});

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

  GoogleEventAttendee({this.email, this.displayName, this.responseStatus});

  factory GoogleEventAttendee.fromJson(Map<String, dynamic> json) =>
      _$GoogleEventAttendeeFromJson(json);

  Map<String, dynamic> toJson() => _$GoogleEventAttendeeToJson(this);
}

@JsonSerializable()
class GoogleEventCreator {
  final String? email;
  final String? displayName;

  GoogleEventCreator({this.email, this.displayName});

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
