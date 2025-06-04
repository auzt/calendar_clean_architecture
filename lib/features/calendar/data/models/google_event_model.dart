// lib/features/calendar/data/models/google_event_model.dart
// ✅ Map-based approach to completely avoid type conflicts

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'calendar_event_model.dart';

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

  // ✅ Create from Map to avoid any type casting issues
  factory GoogleEventModel.fromMap(Map<String, dynamic> map) {
    try {
      return GoogleEventModel(
        id: map['id']?.toString(),
        summary: map['summary']?.toString(),
        description: map['description']?.toString(),
        location: map['location']?.toString(),
        start: _parseEventDateTime(map['start']),
        end: _parseEventDateTime(map['end']),
        attendees: null, // Simplified
        recurrence: _parseRecurrence(map['recurrence']),
        created: null, // Simplified
        updated: null, // Simplified
        colorId: map['colorId']?.toString(),
        creator: null, // Simplified
      );
    } catch (e) {
      // ignore: avoid_print
      print('❌ Error creating GoogleEventModel from map: $e');
      rethrow;
    }
  }

  // ✅ Safe parsing of event date time from Map
  static GoogleEventDateTime? _parseEventDateTime(dynamic dateTimeData) {
    if (dateTimeData == null) return null;

    if (dateTimeData is Map<String, dynamic>) {
      return GoogleEventDateTime(
        date: dateTimeData['date']?.toString(),
        dateTime: dateTimeData['dateTime']?.toString(),
        timeZone: dateTimeData['timeZone']?.toString(),
      );
    }

    return null;
  }

  // ✅ Safe parsing of recurrence
  static List<String>? _parseRecurrence(dynamic recurrenceData) {
    if (recurrenceData == null) return null;

    if (recurrenceData is List) {
      return recurrenceData.map((item) => item.toString()).toList();
    }

    return null;
  }

  // ✅ Convert to CalendarEventModel
  CalendarEventModel toCalendarEventModel() {
    try {
      final startDateTime = start?.toDateTime() ?? DateTime.now();
      final endDateTime =
          end?.toDateTime() ?? startDateTime.add(const Duration(hours: 1));
      final isAllDay = start?.date != null && start?.dateTime == null;

      // ignore: avoid_print
      print('🔄 Converting: ${summary ?? 'No title'}');

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
        attendees: const [], // Simplified
        recurrence: recurrence?.join(', '),
        isFromGoogle: true,
        lastModified: DateTime.now(),
        createdBy: null,
      );
    } catch (e) {
      // ignore: avoid_print
      print('❌ Error converting to CalendarEventModel: $e');
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
}

// ✅ Simple EventDateTime class - no conflicts with googleapis
class GoogleEventDateTime {
  final String? date;
  final String? dateTime;
  final String? timeZone;

  GoogleEventDateTime({this.date, this.dateTime, this.timeZone});

  DateTime toDateTime() {
    try {
      if (date != null && date!.isNotEmpty) {
        // Parse date-only: "2024-01-20"
        return DateTime.parse('${date!}T00:00:00.000');
      } else if (dateTime != null && dateTime!.isNotEmpty) {
        // Parse full datetime
        return DateTime.parse(dateTime!);
      } else {
        // ignore: avoid_print
        print('⚠️ No valid date/dateTime, using current time');
        return DateTime.now();
      }
    } catch (e) {
      // ignore: avoid_print
      print('❌ Error parsing DateTime: $e');
      return DateTime.now();
    }
  }

  factory GoogleEventDateTime.fromDateTime(DateTime dateTime, bool isAllDay) {
    if (isAllDay) {
      return GoogleEventDateTime(
        date: _formatDateOnly(dateTime),
      );
    } else {
      return GoogleEventDateTime(
        dateTime: dateTime.toIso8601String(),
        timeZone: 'Asia/Jakarta',
      );
    }
  }

  static String _formatDateOnly(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}';
  }
}

class GoogleEventAttendee {
  final String? email;
  final String? displayName;
  final String? responseStatus;

  GoogleEventAttendee({this.email, this.displayName, this.responseStatus});
}

class GoogleEventCreator {
  final String? email;
  final String? displayName;

  GoogleEventCreator({this.email, this.displayName});
}
