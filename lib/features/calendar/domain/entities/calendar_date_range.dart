// lib/features/calendar/domain/entities/calendar_date_range.dart
import 'package:equatable/equatable.dart';

class CalendarDateRange extends Equatable {
  final DateTime startDate;
  final DateTime endDate;

  const CalendarDateRange({required this.startDate, required this.endDate});

  bool contains(DateTime date) {
    return date.isAfter(startDate.subtract(const Duration(days: 1))) &&
        date.isBefore(endDate.add(const Duration(days: 1)));
  }

  List<DateTime> getDaysInRange() {
    final days = <DateTime>[];
    var current = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);

    while (current.isBefore(end) || current.isAtSameMomentAs(end)) {
      days.add(current);
      current = current.add(const Duration(days: 1));
    }

    return days;
  }

  Duration get duration => endDate.difference(startDate);

  int get daysCount => duration.inDays + 1;

  bool overlaps(CalendarDateRange other) {
    return startDate.isBefore(other.endDate) &&
        other.startDate.isBefore(endDate);
  }

  CalendarDateRange copyWith({DateTime? startDate, DateTime? endDate}) {
    return CalendarDateRange(
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
    );
  }

  @override
  List<Object> get props => [startDate, endDate];
}
