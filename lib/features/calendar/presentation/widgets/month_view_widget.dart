// lib/features/calendar/presentation/widgets/month_view_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/utils/date_utils.dart';
import '../../domain/entities/calendar_event.dart';
import '../bloc/calendar_bloc.dart';
import '../bloc/calendar_state.dart';

class MonthViewWidget extends StatelessWidget {
  final DateTime month;
  final Function(DateTime) onDateTap;
  final Function(DateTime)? onDateLongPress;

  const MonthViewWidget({
    super.key,
    required this.month,
    required this.onDateTap,
    this.onDateLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildWeekdayHeaders(),
        Expanded(child: _buildCalendarGrid(context)),
      ],
    );
  }

  Widget _buildWeekdayHeaders() {
    const weekdays = ['Min', 'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab'];

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children:
            weekdays.map((day) {
              return Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    day,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade700,
                      fontSize: 12,
                    ),
                  ),
                ),
              );
            }).toList(),
      ),
    );
  }

  Widget _buildCalendarGrid(BuildContext context) {
    return BlocBuilder<CalendarBloc, CalendarState>(
      builder: (context, state) {
        List<CalendarEvent> events = [];
        if (state is CalendarLoaded) {
          events = state.events;
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final cellHeight = constraints.maxHeight / 6;

            return GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: constraints.maxWidth / 7 / cellHeight,
              ),
              itemCount: 42, // 6 weeks * 7 days
              itemBuilder: (context, index) {
                final date = _getDateForIndex(index);
                final dayEvents = _getEventsForDate(events, date);

                return _buildDateCell(context, date, dayEvents);
              },
            );
          },
        );
      },
    );
  }

  DateTime _getDateForIndex(int index) {
    final firstDayOfMonth = DateTime(month.year, month.month, 1);
    final weekdayOfFirst = firstDayOfMonth.weekday % 7; // 0 = Sunday
    final startDate = firstDayOfMonth.subtract(Duration(days: weekdayOfFirst));

    return startDate.add(Duration(days: index));
  }

  List<CalendarEvent> _getEventsForDate(
    List<CalendarEvent> allEvents,
    DateTime date,
  ) {
    return allEvents.where((event) {
      return AppDateUtils.isSameDay(event.startTime, date) ||
          (event.isMultiDay &&
              date.isAfter(event.startTime.subtract(const Duration(days: 1))) &&
              date.isBefore(event.endTime.add(const Duration(days: 1))));
    }).toList();
  }

  Widget _buildDateCell(
    BuildContext context,
    DateTime date,
    List<CalendarEvent> dayEvents,
  ) {
    final isCurrentMonth = date.month == month.month;
    final isToday = AppDateUtils.isSameDay(date, DateTime.now());
    final hasEvents = dayEvents.isNotEmpty;

    return GestureDetector(
      onTap: () => onDateTap(date),
      onLongPress: () => onDateLongPress?.call(date),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300, width: 0.5),
          color:
              isToday
                  ? Colors.blue.shade100
                  : isCurrentMonth
                  ? Colors.white
                  : Colors.grey.shade50,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date number
            Container(
              padding: const EdgeInsets.all(4),
              child: Text(
                '${date.day}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                  color:
                      isCurrentMonth
                          ? isToday
                              ? Colors.blue.shade700
                              : Colors.black87
                          : Colors.grey.shade500,
                ),
              ),
            ),

            // Events indicators
            if (hasEvents)
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: _buildEventIndicators(dayEvents),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventIndicators(List<CalendarEvent> events) {
    // Sort events by start time
    events.sort((a, b) => a.startTime.compareTo(b.startTime));

    // Show max 3 events, with "more" indicator if needed
    final visibleEvents = events.take(3).toList();
    final hasMore = events.length > 3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...visibleEvents.map(
          (event) => Container(
            margin: const EdgeInsets.only(bottom: 1),
            height: 12,
            child: Container(
              decoration: BoxDecoration(
                color: event.color,
                borderRadius: BorderRadius.circular(2),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Text(
                event.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),

        if (hasMore)
          Container(
            margin: const EdgeInsets.only(top: 1),
            child: Text(
              '+${events.length - 3} lagi',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 8,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }
}
