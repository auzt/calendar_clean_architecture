// lib/features/calendar/presentation/widgets/day_view_widget.dart
import 'package:flutter/material.dart';
import '../../../../core/utils/date_utils.dart';
import '../../domain/entities/calendar_event.dart';

class DayViewWidget extends StatefulWidget {
  final DateTime date;
  final List<CalendarEvent> events;
  final Function(CalendarEvent) onEventTap;
  final Function(DateTime) onTimeSlotTap;
  final Function(CalendarEvent, DateTime)? onEventMove;

  const DayViewWidget({
    super.key,
    required this.date,
    required this.events,
    required this.onEventTap,
    required this.onTimeSlotTap,
    this.onEventMove,
  });

  @override
  State<DayViewWidget> createState() => _DayViewWidgetState();
}

class _DayViewWidgetState extends State<DayViewWidget> {
  late ScrollController _scrollController;
  final double _hourHeight = 60.0;
  final double _timeColumnWidth = 80.0;
  final int _minuteInterval = 5;

  // Drag & Drop state
  bool _isDragging = false;
  DateTime? _dragTargetTime;
  CalendarEvent? _draggedEvent;
  DateTime? _lastUpdateTime;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCurrentTime();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToCurrentTime() {
    final now = DateTime.now();
    final isToday = AppDateUtils.isSameDay(widget.date, now);

    double targetPosition;
    if (isToday) {
      targetPosition = (now.hour * _hourHeight) - 100;
    } else {
      targetPosition = (8 * _hourHeight) - 100; // 8 AM for other days
    }

    if (targetPosition < 0) targetPosition = 0;

    _scrollController.animateTo(
      targetPosition,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Row(
          children: [
            _buildTimeColumn(),
            Expanded(child: _buildEventColumn()),
          ],
        ),
        if (_isDragging && _dragTargetTime != null) _buildDragTimeIndicator(),
        _buildSwipeIndicator(),
      ],
    );
  }

  Widget _buildSwipeIndicator() {
    return Positioned(
      bottom: 16,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.drag_handle, color: Colors.white, size: 14),
              SizedBox(width: 4),
              Flexible(
                child: Text(
                  'Long press event untuk drag • Tap area kosong untuk tambah event',
                  style: TextStyle(color: Colors.white, fontSize: 9),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeColumn() {
    return Container(
      width: _timeColumnWidth,
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(
          right: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
      ),
      child: SingleChildScrollView(
        controller: _scrollController,
        child: Column(
          children: List.generate(24, (hour) {
            return Container(
              height: _hourHeight,
              alignment: Alignment.topLeft,
              padding: const EdgeInsets.only(top: 4, left: 8),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Text(
                '${hour.toString().padLeft(2, '0')}:00',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildEventColumn() {
    return SingleChildScrollView(
      controller: _scrollController,
      child: SizedBox(
        height: 24 * _hourHeight,
        child: Stack(
          children: [
            _buildGridLines(),
            _buildCurrentTimeIndicator(),
            _buildTapDetector(),
            _buildOverlayDragTarget(),
            ..._buildEventWidgets(),
          ],
        ),
      ),
    );
  }

  Widget _buildGridLines() {
    return Column(
      children: List.generate(24, (hour) {
        final isCurrentHour =
            AppDateUtils.isSameDay(widget.date, DateTime.now()) &&
                hour == DateTime.now().hour;

        return Container(
          height: _hourHeight,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isCurrentHour ? Colors.blue : Colors.grey.shade300,
                width: isCurrentHour ? 2 : 1,
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildCurrentTimeIndicator() {
    if (!AppDateUtils.isSameDay(widget.date, DateTime.now())) {
      return const SizedBox.shrink();
    }

    final now = DateTime.now();
    final topPosition =
        (now.hour * _hourHeight) + ((now.minute / 60) * _hourHeight);

    return Positioned(
      top: topPosition,
      left: 0,
      right: 0,
      child: Container(
        height: 2,
        color: Colors.red,
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
            ),
            Expanded(child: Container(height: 2, color: Colors.red)),
          ],
        ),
      ),
    );
  }

  Widget _buildTapDetector() {
    return Positioned.fill(
      child: GestureDetector(
        onTapDown: (details) {
          final yPosition = details.localPosition.dy;
          if (!_isPositionOccupied(yPosition)) {
            final hour = (yPosition / _hourHeight).floor();
            final minute =
                (((yPosition % _hourHeight) / _hourHeight) * 60).round();
            final targetMinute = (minute ~/ _minuteInterval) * _minuteInterval;

            final tappedTime = DateTime(
              widget.date.year,
              widget.date.month,
              widget.date.day,
              hour.clamp(0, 23),
              targetMinute.clamp(0, 59),
            );

            widget.onTimeSlotTap(tappedTime);
          }
        },
        child: Container(color: Colors.transparent),
      ),
    );
  }

  Widget _buildOverlayDragTarget() {
    return Positioned.fill(
      child: DragTarget<CalendarEvent>(
        onMove: (details) {
          try {
            // Throttling untuk smooth update
            DateTime now = DateTime.now();
            if (_lastUpdateTime != null &&
                now.difference(_lastUpdateTime!).inMilliseconds < 16) {
              return;
            }
            _lastUpdateTime = now;

            // Get the render box untuk konversi koordinat yang akurat
            RenderBox? renderBox = context.findRenderObject() as RenderBox?;
            if (renderBox != null) {
              // Konversi global position ke local position
              Offset localOffset = renderBox.globalToLocal(details.offset);
              final yPosition = localOffset.dy;

              final hours = yPosition / _hourHeight;
              final targetHour = hours.floor().clamp(0, 23);
              final targetMinute = ((hours - targetHour) * 60).round();
              final snappedMinute =
                  (targetMinute ~/ _minuteInterval) * _minuteInterval;

              final baseDate = DateTime(
                widget.date.year,
                widget.date.month,
                widget.date.day,
              );

              setState(() {
                _dragTargetTime = baseDate.copyWith(
                  hour: targetHour,
                  minute: snappedMinute.clamp(0, 59),
                );
              });
            }
          } catch (e) {
            debugPrint('Error in drag calculation: $e');
          }
        },
        onWillAcceptWithDetails: (data) {
          setState(() {
            _isDragging = true;
            _draggedEvent = data.data;
          });
          return true;
        },
        onAcceptWithDetails: (details) {
          if (_dragTargetTime != null && widget.onEventMove != null) {
            widget.onEventMove!(details.data, _dragTargetTime!);
          }

          setState(() {
            _isDragging = false;
            _dragTargetTime = null;
            _draggedEvent = null;
          });
        },
        onLeave: (data) {
          setState(() {
            _isDragging = false;
            _dragTargetTime = null;
            _draggedEvent = null;
          });
        },
        builder: (context, candidateData, rejectedData) {
          final isHighlighted = candidateData.isNotEmpty;

          return Container(
            color: isHighlighted
                ? Colors.orange.withValues(alpha: 0.1)
                : Colors.transparent,
            child: isHighlighted
                ? Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.orange.withValues(alpha: 0.6),
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  )
                : null,
          );
        },
      ),
    );
  }

  bool _isPositionOccupied(double yPosition) {
    final hour = (yPosition / _hourHeight).floor();
    final minute = (((yPosition % _hourHeight) / _hourHeight) * 60).round();

    final tappedTime = DateTime(
      widget.date.year,
      widget.date.month,
      widget.date.day,
      hour,
      minute,
    );

    for (final event in widget.events) {
      if (tappedTime.isAfter(event.startTime) &&
          tappedTime.isBefore(event.endTime)) {
        return true;
      }
    }
    return false;
  }

  List<Widget> _buildEventWidgets() {
    final layoutedEvents = _calculateEventLayouts();
    return layoutedEvents.map(_buildEventWidget).toList();
  }

  List<EventLayout> _calculateEventLayouts() {
    if (widget.events.isEmpty) return [];

    final sortedEvents = List<CalendarEvent>.from(widget.events)
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    final layouts = <EventLayout>[];
    final eventGroups = <List<CalendarEvent>>[];

    // Group overlapping events
    for (final event in sortedEvents) {
      bool addedToGroup = false;

      for (final group in eventGroups) {
        bool hasOverlap = false;
        for (final groupEvent in group) {
          if (_eventsOverlap(event, groupEvent)) {
            hasOverlap = true;
            break;
          }
        }
        if (hasOverlap) {
          group.add(event);
          addedToGroup = true;
          break;
        }
      }

      if (!addedToGroup) {
        eventGroups.add([event]);
      }
    }

    // Calculate layouts for each group
    for (final group in eventGroups) {
      if (group.length == 1) {
        layouts.add(EventLayout(event: group[0], left: 0.0, width: 1.0));
      } else {
        final columns = <List<CalendarEvent>>[];

        for (final event in group) {
          int targetColumn = -1;

          for (int i = 0; i < columns.length; i++) {
            bool canPlace = true;
            for (final existingEvent in columns[i]) {
              if (_eventsOverlap(event, existingEvent)) {
                canPlace = false;
                break;
              }
            }
            if (canPlace) {
              targetColumn = i;
              break;
            }
          }

          if (targetColumn == -1) {
            columns.add([]);
            targetColumn = columns.length - 1;
          }

          columns[targetColumn].add(event);
        }

        final columnWidth = 1.0 / columns.length;
        for (int columnIndex = 0; columnIndex < columns.length; columnIndex++) {
          for (final event in columns[columnIndex]) {
            layouts.add(
              EventLayout(
                event: event,
                left: columnIndex * columnWidth,
                width: columnWidth,
              ),
            );
          }
        }
      }
    }

    return layouts;
  }

  bool _eventsOverlap(CalendarEvent event1, CalendarEvent event2) {
    return event1.startTime.isBefore(event2.endTime) &&
        event2.startTime.isBefore(event1.endTime);
  }

  Widget _buildEventWidget(EventLayout layout) {
    final event = layout.event;
    final top = _getEventTop(event);
    final height = _getEventHeight(event);

    final screenWidth = MediaQuery.of(context).size.width - _timeColumnWidth;
    final eventWidth = screenWidth * layout.width * 0.95;
    final eventLeft = screenWidth * layout.left;

    return Positioned(
      top: top,
      left: eventLeft + 4,
      width: eventWidth,
      height: height,
      child: LongPressDraggable<CalendarEvent>(
        data: event,
        onDragStarted: () {
          setState(() {
            _isDragging = true;
            _draggedEvent = event;
          });
        },
        onDragEnd: (details) {
          setState(() {
            _isDragging = false;
            _dragTargetTime = null;
            _draggedEvent = null;
          });
        },
        feedback: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: eventWidth,
            height: height,
            decoration: BoxDecoration(
              color: event.color.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white, width: 2),
            ),
            padding: const EdgeInsets.all(6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    event.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                if (height > 30)
                  Flexible(
                    child: Text(
                      '${AppDateUtils.formatTime(event.startTime)} - ${AppDateUtils.formatTime(event.endTime)}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
        ),
        childWhenDragging: Container(
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade400, width: 2),
          ),
          child: Center(
            child: Icon(
              Icons.drag_handle,
              color: Colors.grey.shade600,
              size: 24,
            ),
          ),
        ),
        child: GestureDetector(
          onTap: () => widget.onEventTap(event),
          child: Container(
            decoration: BoxDecoration(
              color: event.color,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.all(6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    event.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (height > 30)
                  Flexible(
                    child: Text(
                      '${AppDateUtils.formatTime(event.startTime)} - ${AppDateUtils.formatTime(event.endTime)}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 9,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDragTimeIndicator() {
    if (_dragTargetTime == null) {
      return const SizedBox.shrink();
    }

    double startTimeY = (_dragTargetTime!.hour * _hourHeight) +
        (_dragTargetTime!.minute * _hourHeight / 60);

    if (_scrollController.hasClients) {
      startTimeY -= _scrollController.offset;
    }

    String timeText = AppDateUtils.formatTime(_dragTargetTime!);
    if (_draggedEvent != null) {
      Duration eventDuration = _draggedEvent!.endTime.difference(
        _draggedEvent!.startTime,
      );
      DateTime newEndTime = _dragTargetTime!.add(eventDuration);
      timeText =
          '${AppDateUtils.formatTime(_dragTargetTime!)} - ${AppDateUtils.formatTime(newEndTime)}';
    }

    return Positioned(
      left: _timeColumnWidth + 10,
      top: startTimeY - 25,
      child: IgnorePointer(
        child: Material(
          color: Colors.transparent,
          elevation: 8,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            constraints: BoxConstraints(
              maxWidth:
                  MediaQuery.of(context).size.width - _timeColumnWidth - 40,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.schedule, color: Colors.white, size: 14),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    timeText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  double _getEventTop(CalendarEvent event) {
    final hour = event.startTime.hour;
    final minute = event.startTime.minute;
    return (hour * _hourHeight) + (minute * _hourHeight / 60);
  }

  double _getEventHeight(CalendarEvent event) {
    final duration = event.endTime.difference(event.startTime);
    return (duration.inMinutes * _hourHeight / 60).clamp(20.0, double.infinity);
  }
}

class EventLayout {
  final CalendarEvent event;
  final double left;
  final double width;

  EventLayout({required this.event, required this.left, required this.width});
}
