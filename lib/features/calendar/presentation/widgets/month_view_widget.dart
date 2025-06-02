// lib/features/calendar/presentation/widgets/month_view_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import '../../../../core/utils/date_utils.dart';
import '../../domain/entities/calendar_event.dart';
import '../bloc/calendar_bloc.dart';
import '../bloc/calendar_state.dart';
import '../pages/day_view_page.dart';

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

  // Constants for mini day view
  final int _displayStartTimeHour = 8;
  final int _displayEndTimeHour = 17;
  final int _maxEventColumnsInMiniView = 2;

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
    const weekdays = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: weekdays.map((day) {
          return Expanded(
            child: Text(
              day,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.normal,
                color: Colors.grey.shade700,
                fontSize: 12,
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
            double availableHeight = constraints.maxHeight;
            double cellHeight = availableHeight / 6.0;
            double screenWidth = MediaQuery.of(context).size.width;
            double cellWidth = screenWidth / 7.0;
            double calculatedAspectRatio = cellWidth / cellHeight;

            if (cellHeight <= 0 ||
                cellWidth <= 0 ||
                calculatedAspectRatio.isNaN ||
                calculatedAspectRatio.isInfinite) {
              calculatedAspectRatio = 0.6;
            }

            return GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: calculatedAspectRatio,
              ),
              itemCount: 42, // 6 weeks * 7 days
              physics: const NeverScrollableScrollPhysics(),
              itemBuilder: (context, index) {
                final date = _getDateForIndex(index);
                final dayEvents = _getEventsForDate(events, date);

                if (index % 7 == 0) {
                  // Add week number for first column
                  return Stack(
                    children: [
                      _buildDateCell(context, date, dayEvents),
                      Positioned(
                        left: 3,
                        bottom: 3,
                        child: Text(
                          '${_getWeekNumber(date)}',
                          style: TextStyle(
                            fontSize: 9,
                            color: Colors.grey.shade400,
                          ),
                        ),
                      ),
                    ],
                  );
                }
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
    final firstWeekdayOffset = (firstDayOfMonth.weekday + 6) % 7;
    final startDate =
        firstDayOfMonth.subtract(Duration(days: firstWeekdayOffset));
    return startDate.add(Duration(days: index));
  }

  List<CalendarEvent> _getEventsForDate(
      List<CalendarEvent> allEvents, DateTime date) {
    return allEvents.where((event) {
      return AppDateUtils.isSameDay(event.startTime, date) ||
          (event.isMultiDay &&
              date.isAfter(event.startTime.subtract(const Duration(days: 1))) &&
              date.isBefore(event.endTime.add(const Duration(days: 1))));
    }).toList();
  }

  Widget _buildDateCell(
      BuildContext context, DateTime date, List<CalendarEvent> dayEvents) {
    final isActualToday = AppDateUtils.isSameDay(date, DateTime.now());
    final isCurrentMonth = AppDateUtils.isSameMonth(date, month);
    final hasAnyEvents = dayEvents.isNotEmpty;

    List<CalendarEvent> fullDayTypeEvents = [];
    List<CalendarEvent> timedEvents = [];

    if (hasAnyEvents) {
      for (var event in dayEvents) {
        if (event.startTime.hour == 0 &&
            event.startTime.minute == 0 &&
            event.endTime.hour == 23 &&
            event.endTime.minute == 59 &&
            AppDateUtils.isSameDay(event.startTime, event.endTime)) {
          fullDayTypeEvents.add(event);
        } else {
          timedEvents.add(event);
        }
      }
      timedEvents.sort((a, b) => a.startTime.compareTo(b.startTime));
    }

    bool hasEventsBeforeDisplayWindow = false;
    bool hasEventsAfterDisplayWindow = false;
    if (isCurrentMonth && hasAnyEvents) {
      for (var event in timedEvents) {
        if (event.startTime
            .isBefore(date.copyWith(hour: _displayStartTimeHour))) {
          hasEventsBeforeDisplayWindow = true;
        }
        if (event.endTime.isAfter(date.copyWith(hour: _displayEndTimeHour))) {
          hasEventsAfterDisplayWindow = true;
        }
      }
    }

    Color cellBackgroundColor = Colors.transparent;
    if (isActualToday) {
      cellBackgroundColor = Colors.yellow.shade300;
    }

    return GestureDetector(
      onTap: () {
        // Single click: HANYA popup jadwal (jika ada events)
        // TIDAK panggil onDateTap untuk menghindari navigasi
        if (hasAnyEvents) {
          _showEventPreviewPopup(context, date, dayEvents);
        }
      },
      onLongPress: () => onDateLongPress?.call(date),
      onDoubleTap: () {
        // Double click: panggil onDateTap untuk navigasi ke day view
        onDateTap(date);
      },
      child: Container(
        decoration: BoxDecoration(
          color: cellBackgroundColor,
          border: Border(
            top: BorderSide(color: Colors.grey.shade300, width: 0.5),
            left: BorderSide(color: Colors.grey.shade300, width: 0.5),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Full day events
            if (isCurrentMonth && hasAnyEvents)
              ...fullDayTypeEvents.take(2).map(
                    (event) => Container(
                      height: 4,
                      margin: const EdgeInsets.only(
                          left: 2, right: 2, top: 1, bottom: 1),
                      decoration: BoxDecoration(
                        color: event.color,
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),

            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date number
                  Padding(
                    padding:
                        const EdgeInsets.only(top: 3.0, left: 3.0, right: 2.0),
                    child: Text(
                      '${date.day}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isActualToday && isCurrentMonth
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isCurrentMonth
                            ? (isActualToday ? Colors.black : Colors.black87)
                            : Colors.grey.shade400,
                      ),
                    ),
                  ),

                  // Mini schedule area
                  if (isCurrentMonth && hasAnyEvents)
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          double miniDayViewHeight = constraints.maxHeight;
                          if (miniDayViewHeight <= 10)
                            return const SizedBox.shrink();

                          // Filter timed events dalam window waktu
                          List<CalendarEvent> eventsInWindow =
                              timedEvents.where((e) {
                            DateTime windowStartTime =
                                date.copyWith(hour: _displayStartTimeHour);
                            DateTime windowEndTime =
                                date.copyWith(hour: _displayEndTimeHour);
                            return e.startTime.isBefore(windowEndTime) &&
                                e.endTime.isAfter(windowStartTime);
                          }).toList();

                          if (eventsInWindow.isEmpty &&
                              !hasEventsBeforeDisplayWindow &&
                              !hasEventsAfterDisplayWindow) {
                            return const SizedBox.shrink();
                          }

                          List<List<CalendarEvent>> eventColumns =
                              _calculateEventLayoutForMiniView(
                                  eventsInWindow, _maxEventColumnsInMiniView);
                          List<Widget> positionedEventBlocks = [];
                          double totalWindowHours =
                              (_displayEndTimeHour - _displayStartTimeHour)
                                  .toDouble();

                          if (totalWindowHours <= 0 &&
                              eventsInWindow.isNotEmpty) {
                            return const SizedBox.shrink();
                          }

                          double arrowContainerHeight =
                              (hasEventsBeforeDisplayWindow ||
                                      hasEventsAfterDisplayWindow)
                                  ? 16.0
                                  : 0.0;
                          double drawableHeight =
                              max(0, miniDayViewHeight - arrowContainerHeight);

                          if (eventsInWindow.isNotEmpty &&
                              totalWindowHours > 0) {
                            for (int colIdx = 0;
                                colIdx < eventColumns.length;
                                colIdx++) {
                              double columnWidth =
                                  (constraints.maxWidth / eventColumns.length) -
                                      (eventColumns.length > 1 ? 0.5 : 0);

                              for (CalendarEvent event
                                  in eventColumns[colIdx]) {
                                DateTime eventStartClamped = event.startTime
                                        .isBefore(date.copyWith(
                                            hour: _displayStartTimeHour))
                                    ? date.copyWith(hour: _displayStartTimeHour)
                                    : event.startTime;
                                DateTime eventEndClamped = event.endTime
                                        .isAfter(date.copyWith(
                                            hour: _displayEndTimeHour))
                                    ? date.copyWith(hour: _displayEndTimeHour)
                                    : event.endTime;

                                if (eventStartClamped
                                        .isAfter(eventEndClamped) ||
                                    eventStartClamped.isAtSameMomentAs(
                                        eventEndClamped)) continue;

                                double startOffsetHours =
                                    (eventStartClamped.hour +
                                            eventStartClamped.minute / 60.0) -
                                        _displayStartTimeHour;
                                double endOffsetHours = (eventEndClamped.hour +
                                        eventEndClamped.minute / 60.0) -
                                    _displayStartTimeHour;
                                double top =
                                    (startOffsetHours / totalWindowHours) *
                                        drawableHeight;
                                double height =
                                    ((endOffsetHours - startOffsetHours) /
                                            totalWindowHours) *
                                        drawableHeight;

                                height = max(2.0, height);
                                if (top < 0) top = 0;
                                if (height < 0) height = 0;
                                if (top + height > drawableHeight)
                                  height = drawableHeight - top;
                                if (height < 0) height = 0;

                                positionedEventBlocks.add(
                                  Positioned(
                                    top: top,
                                    left: colIdx *
                                        (columnWidth +
                                            (eventColumns.length > 1
                                                ? 0.5
                                                : 0)),
                                    width: columnWidth,
                                    height: height,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: event.color.withOpacity(0.9),
                                        borderRadius:
                                            BorderRadius.circular(0.5),
                                      ),
                                    ),
                                  ),
                                );
                              }
                            }
                          }

                          return Container(
                            margin: const EdgeInsets.only(
                                top: 1, right: 1, bottom: 1),
                            width: double.infinity,
                            child: Stack(
                              children: [
                                ...positionedEventBlocks,
                                if (hasEventsBeforeDisplayWindow ||
                                    hasEventsAfterDisplayWindow)
                                  Positioned(
                                    bottom: 0,
                                    left: 0,
                                    right: 0,
                                    height: arrowContainerHeight,
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        if (hasEventsBeforeDisplayWindow)
                                          Icon(Icons.arrow_drop_up,
                                              size: 14,
                                              color: Colors.grey.shade600),
                                        if (hasEventsBeforeDisplayWindow &&
                                            hasEventsAfterDisplayWindow)
                                          const SizedBox(width: 2),
                                        if (hasEventsAfterDisplayWindow)
                                          Icon(Icons.arrow_drop_down,
                                              size: 14,
                                              color: Colors.grey.shade600),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    )
                  else
                    Expanded(child: Container()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<List<CalendarEvent>> _calculateEventLayoutForMiniView(
      List<CalendarEvent> events, int maxColumns) {
    if (events.isEmpty) return [];

    List<CalendarEvent> sortedEvents = List.from(events)
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    List<List<CalendarEvent>> columns = [];

    for (CalendarEvent event in sortedEvents) {
      bool placed = false;
      for (int i = 0; i < columns.length; i++) {
        bool canPlaceInThisColumn = true;
        for (CalendarEvent existingEvent in columns[i]) {
          if (_eventsOverlap(event, existingEvent)) {
            canPlaceInThisColumn = false;
            break;
          }
        }
        if (canPlaceInThisColumn) {
          columns[i].add(event);
          placed = true;
          break;
        }
      }
      if (!placed) {
        if (columns.length < maxColumns) {
          columns.add([event]);
        } else {
          if (columns.isNotEmpty) {
            columns.last.add(event);
          } else {
            columns.add([event]);
          }
        }
      }
    }
    return columns;
  }

  bool _eventsOverlap(CalendarEvent event1, CalendarEvent event2) {
    return event1.startTime.isBefore(event2.endTime) &&
        event2.startTime.isBefore(event1.endTime);
  }

  int _getWeekNumber(DateTime date) {
    int dayOfYear = int.parse(DateFormat("D").format(date));
    int weekOfYear = ((dayOfYear - date.weekday + 10) / 7).floor();
    if (weekOfYear == 0) {
      weekOfYear =
          ((dayOfYear + DateTime(date.year - 1, 12, 28).weekday - 1 + 10) / 7)
              .floor();
    }
    return weekOfYear;
  }

  void _showEventPreviewPopup(
      BuildContext context, DateTime date, List<CalendarEvent> events) {
    if (events.isEmpty) return;

    events.sort((a, b) => a.startTime.compareTo(b.startTime));

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Jadwal ${DateFormat('EEE, d MMM yy').format(date)}"),
          contentPadding: const EdgeInsets.fromLTRB(12.0, 16.0, 12.0, 8.0),
          content: SizedBox(
            width: double.maxFinite,
            height: MediaQuery.of(context).size.height * 0.35,
            child: ListView.builder(
              itemCount: events.length,
              itemBuilder: (BuildContext context, int index) {
                CalendarEvent event = events[index];
                bool isFullDay = event.startTime.hour == 0 &&
                    event.startTime.minute == 0 &&
                    event.endTime.hour == 23 &&
                    event.endTime.minute == 59 &&
                    AppDateUtils.isSameDay(event.startTime, event.endTime);

                return Card(
                  elevation: 1.0,
                  margin: const EdgeInsets.symmetric(vertical: 4.0),
                  color: event.color.withOpacity(0.1),
                  child: ListTile(
                    leading: Icon(Icons.circle, color: event.color, size: 12),
                    title: Text(
                      event.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w500, fontSize: 14),
                    ),
                    subtitle: Text(
                      isFullDay
                          ? "Sepanjang hari"
                          : "${DateFormat.Hm().format(event.startTime)} - ${DateFormat.Hm().format(event.endTime)}",
                      style: const TextStyle(fontSize: 12),
                    ),
                    dense: true,
                  ),
                );
              },
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text("Lihat Detail Hari"),
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DayViewPage(initialDate: date),
                  ),
                );
              },
            ),
            TextButton(
              child: const Text("Tutup"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}
