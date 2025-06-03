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

// ✅ FIXED: Define EventGroup class di luar MonthViewWidget
class EventGroup {
  DateTime startTime;
  DateTime endTime;
  List<CalendarEvent> events;

  EventGroup({
    required this.startTime,
    required this.endTime,
    required this.events,
  });
}

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

  // ✅ IMPROVED: Constants untuk tampilkan lebih banyak events
  final int _displayStartTimeHour = 8;
  final int _displayEndTimeHour = 15;
  final int _maxEventColumnsInMiniView =
      6; // ✅ INCREASED: Lebih banyak kolom untuk 4+ events
  final int _maxVisibleFullDayEvents = 3;
  final double _fullDayEventHeight = 3.0;
  final double _minTimedEventHeight =
      1.5; // ✅ REDUCED: Lebih kecil agar muat lebih banyak

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

    // ✅ IMPROVED: Separasi events
    List<CalendarEvent> fullDayTypeEvents = [];
    List<CalendarEvent> timedEvents = [];

    if (hasAnyEvents) {
      for (var event in dayEvents) {
        if (event.isAllDay ||
            (event.startTime.hour == 0 &&
                event.startTime.minute == 0 &&
                event.endTime.hour == 23 &&
                event.endTime.minute == 59 &&
                AppDateUtils.isSameDay(event.startTime, event.endTime))) {
          fullDayTypeEvents.add(event);
        } else {
          timedEvents.add(event);
        }
      }
      timedEvents.sort((a, b) => a.startTime.compareTo(b.startTime));
    }

    Color cellBackgroundColor = Colors.transparent;
    if (isActualToday) {
      cellBackgroundColor = Colors.yellow.shade300;
    }

    return GestureDetector(
      onTap: () {
        // Single click: popup jadwal (jika ada events)
        if (hasAnyEvents) {
          _showEventPreviewPopup(context, date, dayEvents);
        }
      },
      onLongPress: () => onDateLongPress?.call(date),
      onDoubleTap: () {
        // Double click: navigasi ke day view
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
            // ✅ IMPROVED: Full day events - tampilkan lebih banyak TANPA TEXT
            if (isCurrentMonth && fullDayTypeEvents.isNotEmpty)
              ...fullDayTypeEvents.take(_maxVisibleFullDayEvents).map(
                    (event) => Container(
                      height: _fullDayEventHeight,
                      margin: const EdgeInsets.only(
                          left: 2, right: 2, top: 1, bottom: 0.5),
                      decoration: BoxDecoration(
                        color: event.color,
                        borderRadius: BorderRadius.circular(1.5),
                        // ✅ ADDED: Border putih untuk full day events juga
                        border: Border.all(
                          color: Colors.white,
                          width: 0.3,
                        ),
                        // ✅ ADDED: Shadow untuk kedalaman
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 0.3,
                            offset: const Offset(0, 0.3),
                          ),
                        ],
                      ),
                      // ✅ REMOVED: Text content - tidak tampilkan text pada full day events
                    ),
                  ),

            // ✅ IMPROVED: Indicator untuk sisa full day events
            if (isCurrentMonth &&
                fullDayTypeEvents.length > _maxVisibleFullDayEvents)
              Container(
                height: _fullDayEventHeight,
                margin: const EdgeInsets.only(
                    left: 2, right: 2, top: 0.5, bottom: 0.5),
                decoration: BoxDecoration(
                  color: Colors.grey.shade500,
                  borderRadius: BorderRadius.circular(1.5),
                ),
                child: Center(
                  child: Text(
                    '+${fullDayTypeEvents.length - _maxVisibleFullDayEvents} more',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 5,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
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
                        const EdgeInsets.only(top: 2.0, left: 3.0, right: 2.0),
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

                  // ✅ MEGA IMPROVED: Mini schedule area - tampilkan SEMUA events sebagai blok
                  if (isCurrentMonth && timedEvents.isNotEmpty)
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          double miniDayViewHeight = constraints.maxHeight;
                          if (miniDayViewHeight <= 10)
                            return const SizedBox.shrink();

                          // ✅ KUNCI: Layout SEMUA timed events tanpa batasan
                          List<List<CalendarEvent>> eventColumns =
                              _calculateEventLayoutForMiniView(
                                  timedEvents, _maxEventColumnsInMiniView);

                          List<Widget> positionedEventBlocks = [];
                          double totalWindowHours =
                              (_displayEndTimeHour - _displayStartTimeHour)
                                  .toDouble();

                          if (totalWindowHours <= 0) {
                            totalWindowHours = 24.0; // Fallback
                          }

                          double drawableHeight =
                              miniDayViewHeight - 2; // Sedikit margin

                          // ✅ FIXED: Render dengan width adaptif berdasarkan overlap
                          for (int colIdx = 0;
                              colIdx < eventColumns.length;
                              colIdx++) {
                            for (CalendarEvent event in eventColumns[colIdx]) {
                              // ✅ KUNCI: Ambil layout info dari event
                              Map<String, dynamic>? layoutInfo =
                                  event.additionalData?['layoutInfo']
                                      as Map<String, dynamic>?;

                              double widthFraction =
                                  layoutInfo?['widthFraction'] ??
                                      (1.0 / eventColumns.length);
                              int columnIndex =
                                  layoutInfo?['columnIndex'] ?? colIdx;
                              int totalColumns = layoutInfo?['totalColumns'] ??
                                  eventColumns.length;

                              // ✅ Hitung posisi berdasarkan jam aktual
                              double eventStartHour = event.startTime.hour +
                                  event.startTime.minute / 60.0;
                              double eventEndHour = event.endTime.hour +
                                  event.endTime.minute / 60.0;

                              if (eventEndHour <= eventStartHour) {
                                eventEndHour = eventStartHour + 0.5;
                              }

                              double windowStartHour =
                                  _displayStartTimeHour.toDouble();
                              double windowEndHour =
                                  _displayEndTimeHour.toDouble();

                              double displayStartHour =
                                  max(eventStartHour, windowStartHour);
                              double displayEndHour =
                                  min(eventEndHour, windowEndHour);

                              if (displayEndHour <= displayStartHour) continue;

                              double relativeStart =
                                  (displayStartHour - windowStartHour) /
                                      totalWindowHours;
                              double relativeEnd =
                                  (displayEndHour - windowStartHour) /
                                      totalWindowHours;

                              double top = relativeStart * drawableHeight;
                              double height = (relativeEnd - relativeStart) *
                                  drawableHeight;
                              height = max(_minTimedEventHeight, height);

                              if (top < 0) {
                                height += top;
                                top = 0;
                              }
                              if (top + height > drawableHeight) {
                                height = drawableHeight - top;
                              }
                              if (height <= 0) continue;

                              // ✅ KUNCI: Width dan position berdasarkan overlap group
                              double totalAvailableWidth =
                                  constraints.maxWidth - 1;
                              double eventWidth =
                                  totalAvailableWidth * widthFraction;
                              double eventLeft = totalAvailableWidth *
                                  (columnIndex * widthFraction);

                              positionedEventBlocks.add(
                                Positioned(
                                  top: top,
                                  left: eventLeft,
                                  width: eventWidth -
                                      0.5, // Gap kecil antar events
                                  height: height,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: event.color.withOpacity(0.9),
                                      borderRadius: BorderRadius.circular(1),
                                      // ✅ IMPROVED: Border yang lebih tajam dan jelas
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 0.5,
                                      ),
                                      // ✅ ADDED: Shadow untuk kedalaman
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.15),
                                          blurRadius: 0.5,
                                          offset: const Offset(0, 0.5),
                                        ),
                                      ],
                                    ),
                                    // ✅ REMOVED: Text content - tidak tampilkan text
                                  ),
                                ),
                              );
                            }
                          }

                          return Container(
                            margin: const EdgeInsets.only(
                                top: 1, right: 1, bottom: 1),
                            width: double.infinity,
                            child: Stack(
                              children: positionedEventBlocks,
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

  // ✅ FIXED: Layout algorithm yang adaptive - lebar berdasarkan overlap
  List<List<CalendarEvent>> _calculateEventLayoutForMiniView(
      List<CalendarEvent> events, int maxColumns) {
    if (events.isEmpty) return [];

    List<CalendarEvent> sortedEvents = List.from(events)
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    // ✅ KUNCI: Group events berdasarkan time slots yang overlap
    List<EventGroup> eventGroups = _groupOverlappingEvents(sortedEvents);

    List<List<CalendarEvent>> finalColumns = [];

    // ✅ Process setiap group secara terpisah
    for (EventGroup group in eventGroups) {
      List<List<CalendarEvent>> groupColumns = [];

      for (CalendarEvent event in group.events) {
        bool placed = false;

        // Coba tempatkan di kolom existing tanpa overlap dalam group ini
        for (int i = 0; i < groupColumns.length; i++) {
          bool canPlace = true;
          for (CalendarEvent existing in groupColumns[i]) {
            if (_eventsOverlap(event, existing)) {
              canPlace = false;
              break;
            }
          }
          if (canPlace) {
            groupColumns[i].add(event);
            placed = true;
            break;
          }
        }

        // Jika tidak bisa ditempatkan, buat kolom baru
        if (!placed) {
          groupColumns.add([event]);
        }
      }

      // ✅ KUNCI: Set width fraction berdasarkan jumlah kolom dalam group
      double widthFraction = 1.0 / groupColumns.length;
      for (int i = 0; i < groupColumns.length; i++) {
        for (CalendarEvent event in groupColumns[i]) {
          // Simpan info layout dalam event (gunakan additionalData)
          Map<String, dynamic> layoutInfo = {
            'widthFraction': widthFraction,
            'columnIndex': i,
            'totalColumns': groupColumns.length,
            'groupStartTime': group.startTime,
            'groupEndTime': group.endTime,
          };

          // Update additionalData untuk setiap event
          CalendarEvent updatedEvent = event.copyWith(
            additionalData: {
              ...(event.additionalData ?? {}),
              'layoutInfo': layoutInfo
            },
          );

          // Tambahkan ke final columns
          if (finalColumns.length <= i) {
            finalColumns.add([]);
          }
          finalColumns[i].add(updatedEvent);
        }
      }
    }

    return finalColumns;
  }

  // ✅ NEW: Group events yang overlap dalam time slots
  List<EventGroup> _groupOverlappingEvents(List<CalendarEvent> events) {
    List<EventGroup> groups = [];

    for (CalendarEvent event in events) {
      bool addedToGroup = false;

      for (EventGroup group in groups) {
        // Cek apakah event ini overlap dengan group
        if (event.startTime.isBefore(group.endTime) &&
            event.endTime.isAfter(group.startTime)) {
          group.events.add(event);
          // Update group time range
          if (event.startTime.isBefore(group.startTime)) {
            group.startTime = event.startTime;
          }
          if (event.endTime.isAfter(group.endTime)) {
            group.endTime = event.endTime;
          }
          addedToGroup = true;
          break;
        }
      }

      if (!addedToGroup) {
        groups.add(EventGroup(
          startTime: event.startTime,
          endTime: event.endTime,
          events: [event],
        ));
      }
    }

    return groups;
  }

  int _countOverlaps(CalendarEvent event, List<CalendarEvent> columnEvents) {
    int count = 0;
    for (CalendarEvent existing in columnEvents) {
      if (_eventsOverlap(event, existing)) count++;
    }
    return count;
  }

  bool _eventsOverlap(CalendarEvent event1, CalendarEvent event2) {
    // ✅ FIXED: Deteksi overlap yang lebih akurat
    // Events overlap jika ada irisan waktu apapun
    DateTime start1 = event1.startTime;
    DateTime end1 = event1.endTime;
    DateTime start2 = event2.startTime;
    DateTime end2 = event2.endTime;

    // Debug print untuk tracking overlap detection
    bool overlaps = start1.isBefore(end2) && start2.isBefore(end1);

    if (overlaps) {
      print(
          '🔄 Overlap detected: ${event1.title} (${start1.hour}:${start1.minute}-${end1.hour}:${end1.minute}) overlaps with ${event2.title} (${start2.hour}:${start2.minute}-${end2.hour}:${end2.minute})');
    }

    return overlaps;
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
          title: Row(
            children: [
              Icon(Icons.calendar_today, color: Colors.blue, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "${DateFormat('EEE, d MMM yy').format(date)} (${events.length} events)",
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
          contentPadding: const EdgeInsets.fromLTRB(12.0, 16.0, 12.0, 8.0),
          content: SizedBox(
            width: double.maxFinite,
            height: MediaQuery.of(context).size.height * 0.4,
            child: ListView.builder(
              itemCount: events.length,
              itemBuilder: (BuildContext context, int index) {
                CalendarEvent event = events[index];
                bool isFullDay = event.isAllDay ||
                    (event.startTime.hour == 0 &&
                        event.startTime.minute == 0 &&
                        event.endTime.hour == 23 &&
                        event.endTime.minute == 59 &&
                        AppDateUtils.isSameDay(event.startTime, event.endTime));

                return Card(
                  elevation: 1.0,
                  margin: const EdgeInsets.symmetric(vertical: 3.0),
                  color: event.color.withOpacity(0.1),
                  child: ListTile(
                    dense: true,
                    leading: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: event.color,
                        shape: BoxShape.circle,
                      ),
                    ),
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
                    trailing: event.isFromGoogle
                        ? Icon(Icons.cloud,
                            size: 16, color: Colors.grey.shade600)
                        : null,
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
