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

  factory GoogleEventModel.fromJson(Map<String, dynamic> json) {
    try {
      // ✅ FIX: Safe JSON parsing dengan type checking
      return GoogleEventModel(
        id: _safeString(json['id']),
        summary: _safeString(json['summary']),
        description: _safeString(json['description']),
        location: _safeString(json['location']),
        start: _safeGoogleEventDateTime(json['start']),
        end: _safeGoogleEventDateTime(json['end']),
        attendees: _safeAttendeesList(json['attendees']),
        recurrence: _safeStringList(json['recurrence']),
        created: _safeGoogleEventDateTime(json['created']),
        updated: _safeGoogleEventDateTime(json['updated']),
        colorId: _safeString(json['colorId']),
        creator: _safeGoogleEventCreator(json['creator']),
      );
    } catch (e) {
      print('❌ Error parsing GoogleEventModel: $e');
      print('📄 JSON data: $json');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() => _$GoogleEventModelToJson(this);

  // ✅ SAFE PARSING HELPERS
  static String? _safeString(dynamic value) {
    if (value == null) return null;
    return value.toString();
  }

  static List<String>? _safeStringList(dynamic value) {
    if (value == null) return null;
    if (value is List) {
      return value.map((item) => item.toString()).toList();
    }
    return null;
  }

  static GoogleEventDateTime? _safeGoogleEventDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Map<String, dynamic>) {
      return GoogleEventDateTime.fromJson(value);
    }
    return null;
  }

  static List<GoogleEventAttendee>? _safeAttendeesList(dynamic value) {
    if (value == null) return null;
    if (value is List) {
      return value
          .where((item) => item is Map<String, dynamic>)
          .map((item) =>
              GoogleEventAttendee.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    return null;
  }

  static GoogleEventCreator? _safeGoogleEventCreator(dynamic value) {
    if (value == null) return null;
    if (value is Map<String, dynamic>) {
      return GoogleEventCreator.fromJson(value);
    }
    return null;
  }

  CalendarEventModel toCalendarEventModel() {
    try {
      final startDateTime = start?.toDateTime() ?? DateTime.now();
      final endDateTime =
          end?.toDateTime() ?? startDateTime.add(const Duration(hours: 1));
      final isAllDay = start?.date != null;

      print('🔄 Converting Google event to Calendar event:');
      print('   ID: $id');
      print('   Title: $summary');
      print('   Start: $startDateTime');
      print('   End: $endDateTime');
      print('   All Day: $isAllDay');

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
        attendees: attendees
                ?.map((a) => a.email ?? '')
                .where((e) => e.isNotEmpty)
                .toList() ??
            [],
        recurrence: recurrence?.join(', '),
        isFromGoogle: true,
        lastModified: updated?.toDateTime(),
        createdBy: creator?.email,
      );
    } catch (e) {
      print('❌ Error converting to CalendarEventModel: $e');
      print('   Event ID: $id');
      print('   Event Summary: $summary');
      rethrow;
    }
  }

  static GoogleEventModel fromCalendarEventModel(CalendarEventModel event) {
    try {
      return GoogleEventModel(
        id: event.googleEventId,
        summary: event.title,
        description: event.description,
        location: event.location,
        start:
            GoogleEventDateTime.fromDateTime(event.startTime, event.isAllDay),
        end: GoogleEventDateTime.fromDateTime(event.endTime, event.isAllDay),
        attendees: event.attendees
            .map((email) => GoogleEventAttendee(email: email))
            .toList(),
        recurrence: event.recurrence?.split(', '),
        colorId: _getIdFromColor(event.color),
      );
    } catch (e) {
      print('❌ Error converting from CalendarEventModel: $e');
      print('   Event ID: ${event.id}');
      print('   Event Title: ${event.title}');
      rethrow;
    }
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

  factory GoogleEventDateTime.fromJson(Map<String, dynamic> json) {
    try {
      return GoogleEventDateTime(
        date: json['date']?.toString(),
        dateTime: json['dateTime']?.toString(),
        timeZone: json['timeZone']?.toString(),
      );
    } catch (e) {
      print('❌ Error parsing GoogleEventDateTime: $e');
      print('📄 JSON: $json');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() => _$GoogleEventDateTimeToJson(this);

  static GoogleEventDateTime fromDateTime(DateTime dateTime, bool isAllDay) {
    try {
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
    } catch (e) {
      print('❌ Error creating GoogleEventDateTime: $e');
      rethrow;
    }
  }

  DateTime toDateTime() {
    try {
      if (date != null) {
        return DateTime.parse(date!);
      } else if (dateTime != null) {
        return DateTime.parse(dateTime!);
      } else {
        print('⚠️ No date/dateTime found, using current time');
        return DateTime.now();
      }
    } catch (e) {
      print('❌ Error parsing DateTime: $e');
      print('   Date: $date');
      print('   DateTime: $dateTime');
      return DateTime.now(); // Fallback
    }
  }
}

@JsonSerializable()
class GoogleEventAttendee {
  final String? email;
  final String? displayName;
  final String? responseStatus;

  GoogleEventAttendee({this.email, this.displayName, this.responseStatus});

  factory GoogleEventAttendee.fromJson(Map<String, dynamic> json) {
    try {
      return GoogleEventAttendee(
        email: json['email']?.toString(),
        displayName: json['displayName']?.toString(),
        responseStatus: json['responseStatus']?.toString(),
      );
    } catch (e) {
      print('❌ Error parsing GoogleEventAttendee: $e');
      print('📄 JSON: $json');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() => _$GoogleEventAttendeeToJson(this);
}

@JsonSerializable()
class GoogleEventCreator {
  final String? email;
  final String? displayName;

  GoogleEventCreator({this.email, this.displayName});

  factory GoogleEventCreator.fromJson(Map<String, dynamic> json) {
    try {
      return GoogleEventCreator(
        email: json['email']?.toString(),
        displayName: json['displayName']?.toString(),
      );
    } catch (e) {
      print('❌ Error parsing GoogleEventCreator: $e');
      print('📄 JSON: $json');
      rethrow;
    }
  }

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

  factory GoogleCalendarResponse.fromJson(Map<String, dynamic> json) {
    try {
      return GoogleCalendarResponse(
        kind: json['kind']?.toString(),
        etag: json['etag']?.toString(),
        summary: json['summary']?.toString(),
        description: json['description']?.toString(),
        items: _safeEventsList(json['items']),
        nextPageToken: json['nextPageToken']?.toString(),
      );
    } catch (e) {
      print('❌ Error parsing GoogleCalendarResponse: $e');
      print('📄 JSON: $json');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() => _$GoogleCalendarResponseToJson(this);

  static List<GoogleEventModel>? _safeEventsList(dynamic value) {
    if (value == null) return null;
    if (value is List) {
      return value
          .where((item) => item is Map<String, dynamic>)
          .map(
              (item) => GoogleEventModel.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    return null;
  }
}
