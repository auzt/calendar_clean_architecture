// lib/features/calendar/data/models/google_event_model.dart
// FIXED VERSION - toDateTime() method dengan proper format handling

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

  factory GoogleEventModel.fromMap(Map<String, dynamic> map) {
    try {
      return GoogleEventModel(
        id: map['id']?.toString(),
        summary: map['summary']?.toString(),
        description: map['description']?.toString(),
        location: map['location']?.toString(),
        start: _parseEventDateTime(map['start']),
        end: _parseEventDateTime(map['end']),
        attendees: null,
        recurrence: _parseRecurrence(map['recurrence']),
        created: null,
        updated: null,
        colorId: map['colorId']?.toString(),
        creator: null,
      );
    } catch (e) {
      print('❌ Error creating GoogleEventModel from map: $e');
      rethrow;
    }
  }

  static GoogleEventDateTime? _parseEventDateTime(dynamic dateTimeData) {
    if (dateTimeData == null) return null;

    if (dateTimeData is Map<String, dynamic>) {
      return GoogleEventDateTime(
        date: dateTimeData['date']?.toString(),
        dateTime: dateTimeData['dateTime']?.toString(),
        timeZone: dateTimeData['timeZone']?.toString(),
        originalDateTime: dateTimeData['originalDateTime']?.toString(),
        originalTimeZone: dateTimeData['originalTimeZone']?.toString(),
      );
    }

    return null;
  }

  static List<String>? _parseRecurrence(dynamic recurrenceData) {
    if (recurrenceData == null) return null;

    if (recurrenceData is List) {
      return recurrenceData.map((item) => item.toString()).toList();
    }

    return null;
  }

  CalendarEventModel toCalendarEventModel() {
    try {
      final startDateTime = start?.toDateTime() ?? DateTime.now();
      final endDateTime =
          end?.toDateTime() ?? startDateTime.add(const Duration(hours: 1));
      final isAllDay = start?.date != null && start?.dateTime == null;

      print('🔄 Converting: ${summary ?? 'No title'}');
      print('📅 Start: $startDateTime');
      print('📅 End: $endDateTime');
      print('📅 All day: $isAllDay');

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
        attendees: const [],
        recurrence: recurrence?.join(', '),
        isFromGoogle: true,
        lastModified: DateTime.now(),
        createdBy: null,
      );
    } catch (e) {
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

// ✅ FIXED GoogleEventDateTime dengan robust DateTime parsing
class GoogleEventDateTime {
  final String? date;
  final String? dateTime;
  final String? timeZone;
  final String? originalDateTime;
  final String? originalTimeZone;

  GoogleEventDateTime({
    this.date,
    this.dateTime,
    this.timeZone,
    this.originalDateTime,
    this.originalTimeZone,
  });

  static const int _jakartaOffsetHours = 7; // GMT+7

  DateTime toDateTime() {
    try {
      print('🔍 Parsing DateTime:');
      print('   date: $date');
      print('   dateTime: $dateTime');
      print('   timeZone: $timeZone');

      if (date != null && date!.isNotEmpty) {
        // ✅ FIX: All-day event parsing dengan format yang benar
        return _parseAllDayDate(date!);
      } else if (dateTime != null && dateTime!.isNotEmpty) {
        // ✅ FIX: Timed event parsing dengan timezone handling
        return _parseTimedDateTime(dateTime!, timeZone);
      } else {
        print('⚠️ No valid date/dateTime, using current time');
        return DateTime.now();
      }
    } catch (e) {
      print('❌ Error parsing DateTime: $e');
      print('   Raw data - date: $date, dateTime: $dateTime');

      // ✅ FALLBACK: Coba parse dengan berbagai format
      return _attemptFallbackParsing();
    }
  }

  // ✅ Parse all-day date dengan berbagai format
  DateTime _parseAllDayDate(String dateStr) {
    try {
      print('📅 Parsing all-day date: $dateStr');

      // Remove any time component yang tidak diperlukan
      String cleanDateStr = dateStr;

      // Jika ada "T00:00:00.000" di akhir, hapus
      if (cleanDateStr.contains('T')) {
        cleanDateStr = cleanDateStr.split('T')[0];
      }

      // Jika format "2025-06-02 00:00:00.000", ambil bagian tanggal saja
      if (cleanDateStr.contains(' ')) {
        cleanDateStr = cleanDateStr.split(' ')[0];
      }

      print('📅 Cleaned date string: $cleanDateStr');

      // Parse dengan format YYYY-MM-DD
      if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(cleanDateStr)) {
        final parts = cleanDateStr.split('-');
        final year = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final day = int.parse(parts[2]);

        final parsed = DateTime(year, month, day);
        print('✅ All-day parsed: $parsed');
        return parsed;
      }

      // Fallback: coba parse langsung
      final parsed = DateTime.parse(cleanDateStr);
      print('✅ Fallback all-day parsed: $parsed');
      return parsed;
    } catch (e) {
      print('❌ All-day parsing failed: $e');
      return DateTime.now();
    }
  }

  // ✅ Parse timed datetime dengan timezone handling
  DateTime _parseTimedDateTime(String dateTimeStr, String? tz) {
    try {
      print('🕐 Parsing timed datetime: $dateTimeStr (tz: $tz)');

      // ✅ FIX: Handle invalid format seperti "2025-06-02 00:00:00.000T00:00:00.000"
      String cleanDateTimeStr = dateTimeStr;

      // Jika ada double time format, ambil yang pertama
      if (cleanDateTimeStr.contains('.000T')) {
        final parts = cleanDateTimeStr.split('.000T');
        cleanDateTimeStr = parts[0];
        print('🔧 Fixed double time format: $cleanDateTimeStr');
      }

      // Parse the cleaned string
      DateTime parsedDateTime;

      if (cleanDateTimeStr.endsWith('Z')) {
        // UTC format
        parsedDateTime = DateTime.parse(cleanDateTimeStr);
        print('🌐 Parsed as UTC: $parsedDateTime');
      } else if (cleanDateTimeStr.contains('T')) {
        // ISO format
        parsedDateTime = DateTime.parse(cleanDateTimeStr);
        print('📅 Parsed as ISO: $parsedDateTime');
      } else {
        // Custom format handling
        parsedDateTime = _parseCustomFormat(cleanDateTimeStr);
        print('🔧 Parsed with custom format: $parsedDateTime');
      }

      // ✅ TIMEZONE CORRECTION
      final correctedDateTime = _applyTimezoneCorrection(parsedDateTime, tz);
      print('✅ Final corrected time: $correctedDateTime');

      return correctedDateTime;
    } catch (e) {
      print('❌ Timed parsing failed: $e');
      return _attemptFallbackParsing();
    }
  }

  // ✅ Parse custom datetime formats
  DateTime _parseCustomFormat(String dateTimeStr) {
    try {
      // Handle format: "2025-06-02 14:30:00"
      if (RegExp(r'^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}')
          .hasMatch(dateTimeStr)) {
        return DateTime.parse(dateTimeStr.replaceFirst(' ', 'T'));
      }

      // Handle format: "2025-06-02 14:30"
      if (RegExp(r'^\d{4}-\d{2}-\d{2} \d{2}:\d{2}$').hasMatch(dateTimeStr)) {
        return DateTime.parse('${dateTimeStr.replaceFirst(' ', 'T')}:00');
      }

      // Default fallback
      return DateTime.parse(dateTimeStr);
    } catch (e) {
      print('❌ Custom format parsing failed: $e');
      throw e;
    }
  }

  // ✅ Apply timezone correction
  DateTime _applyTimezoneCorrection(DateTime parsedDateTime, String? tz) {
    // If UTC, convert to Jakarta time
    if (parsedDateTime.isUtc || tz == 'UTC' || tz == 'GMT') {
      final jakartaTime =
          parsedDateTime.add(Duration(hours: _jakartaOffsetHours));
      print('🌏 UTC -> Jakarta: $parsedDateTime -> $jakartaTime');
      return jakartaTime;
    }

    // If already Jakarta timezone, keep as is
    if (tz != null && (tz.contains('Jakarta') || tz.contains('+07'))) {
      print('🏠 Already Jakarta timezone: $parsedDateTime');
      return parsedDateTime;
    }

    // Heuristic check: if time seems wrong, try correction
    final now = DateTime.now();
    final diff = parsedDateTime.difference(now).inHours.abs();

    if (diff >= 5 && diff <= 9) {
      // Likely timezone offset issue
      final corrected =
          parsedDateTime.subtract(Duration(hours: _jakartaOffsetHours));
      print('🔧 Applied timezone correction: $parsedDateTime -> $corrected');
      return corrected;
    }

    print('✅ No timezone correction needed: $parsedDateTime');
    return parsedDateTime;
  }

  // ✅ Attempt various fallback parsing methods
  DateTime _attemptFallbackParsing() {
    try {
      print('🆘 Attempting fallback parsing...');

      // Try parsing original data in different ways
      final attempts = <String>[];

      if (dateTime != null) attempts.add(dateTime!);
      if (date != null) attempts.add(date!);
      if (originalDateTime != null) attempts.add(originalDateTime!);

      for (String attempt in attempts) {
        try {
          // Clean and try parse
          String cleaned = attempt
              .replaceAll(RegExp(r'\.000T.*$'), '') // Remove invalid suffix
              .replaceAll(' ', 'T'); // Convert space to T

          if (!cleaned.contains('T') && cleaned.contains('-')) {
            // Date only, add time
            cleaned = '${cleaned}T00:00:00';
          }

          final parsed = DateTime.parse(cleaned);
          print('✅ Fallback successful: $attempt -> $parsed');
          return parsed;
        } catch (e) {
          print('⚠️ Fallback attempt failed for: $attempt');
          continue;
        }
      }

      // Ultimate fallback
      print('🆘 All parsing failed, using current time');
      return DateTime.now();
    } catch (e) {
      print('❌ Even fallback failed: $e');
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
