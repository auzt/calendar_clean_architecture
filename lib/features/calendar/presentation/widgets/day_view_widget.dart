// lib/features/calendar/presentation/widgets/day_view_widget.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/utils/date_utils.dart';
import '../../domain/entities/calendar_event.dart';

class DayViewWidget extends StatefulWidget {
  final DateTime date;
  final List<CalendarEvent> events;
  final Function(CalendarEvent) onEventTap;
  final Function(DateTime) onTimeSlotTap;
  final Function(CalendarEvent, DateTime)? onEventMove;
  final Function(double)? onScrollPositionChanged;
  final double? initialScrollPosition;

  const DayViewWidget({
    super.key,
    required this.date,
    required this.events,
    required this.onEventTap,
    required this.onTimeSlotTap,
    this.onEventMove,
    this.onScrollPositionChanged,
    this.initialScrollPosition,
  });

  @override
  State<DayViewWidget> createState() => _DayViewWidgetState();
}

class _DayViewWidgetState extends State<DayViewWidget> {
  late ScrollController _scrollController;
  final double hourHeight = 60.0;
  final double timeColumnWidth = 80.0;
  final int minuteInterval = 5;
  final GlobalKey _scrollKey = GlobalKey();

  // Drag state
  bool _isDragging = false;
  DateTime? _dragTargetTime;
  CalendarEvent? _draggedEvent;
  DateTime? _lastUpdateTime;

  // Auto-scroll variables
  Timer? _autoScrollTimer;
  double _autoScrollVelocity = 0.0;
  static const double _kAutoScrollPixelsPerTick = 8.0;
  static const Duration _kAutoScrollTimerDuration = Duration(milliseconds: 16);

  // Separate events
  List<CalendarEvent> _fullDayEvents = [];
  List<CalendarEvent> _timedEvents = [];

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _separateEvents();

    _scrollController.addListener(() {
      if (!_isDragging && widget.onScrollPositionChanged != null) {
        widget.onScrollPositionChanged!(_scrollController.offset);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialScrollPosition != null) {
        _scrollToPosition(widget.initialScrollPosition!);
      } else {
        _scrollToCurrentTime();
      }
    });
  }

  @override
  void didUpdateWidget(DayViewWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.events != widget.events) {
      _separateEvents();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _autoScrollTimer?.cancel();
    super.dispose();
  }

  void _separateEvents() {
    _fullDayEvents = [];
    _timedEvents = [];

    for (var event in widget.events) {
      if (event.isAllDay) {
        _fullDayEvents.add(event);
      } else {
        _timedEvents.add(event);
      }
    }

    // Sort timed events by start time
    _timedEvents.sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  void _scrollToPosition(double position) {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      position,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _scrollToCurrentTime() {
    if (!_scrollController.hasClients) return;

    final now = DateTime.now();
    final isToday = AppDateUtils.isSameDay(widget.date, now);

    double targetPosition;
    if (isToday) {
      targetPosition = (now.hour * hourHeight) - 100;
    } else {
      targetPosition = (8 * hourHeight) - 100; // 8 AM for other days
    }

    if (targetPosition < 0) targetPosition = 0;

    _scrollController.animateTo(
      targetPosition,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  void _manageAutoScrollTimer() {
    if (_autoScrollVelocity != 0.0 && _isDragging) {
      if (_autoScrollTimer == null || !_autoScrollTimer!.isActive) {
        _autoScrollTimer = Timer.periodic(_kAutoScrollTimerDuration, (timer) {
          if (!_isDragging || _autoScrollVelocity == 0.0) {
            timer.cancel();
            _autoScrollTimer = null;
            return;
          }

          if (_scrollController.hasClients) {
            double currentOffset = _scrollController.offset;
            double newOffset = (currentOffset + _autoScrollVelocity).clamp(
              _scrollController.position.minScrollExtent,
              _scrollController.position.maxScrollExtent,
            );

            if (currentOffset != newOffset) {
              _scrollController.jumpTo(newOffset);
            } else {
              // Mencapai batas scroll, hentikan timer untuk arah ini
              timer.cancel();
              _autoScrollTimer = null;
            }
          } else {
            // No clients, cancel timer
            timer.cancel();
            _autoScrollTimer = null;
          }
        });
      }
    } else {
      _autoScrollTimer?.cancel();
      _autoScrollTimer = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          // Full day events section
          if (_fullDayEvents.isNotEmpty) _buildFullDayEventsSection(),

          // Time-based events section
          Expanded(
            child: Stack(
              children: [
                SingleChildScrollView(
                  key: _scrollKey,
                  controller: _scrollController,
                  child: SizedBox(
                    height: 24 * hourHeight,
                    child: Row(
                      children: [
                        _buildTimeColumn(),
                        Expanded(child: _buildEventColumn()),
                      ],
                    ),
                  ),
                ),
                if (_isDragging && _dragTargetTime != null)
                  _buildDragTimeIndicator(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFullDayEventsSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sepanjang Hari',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          ...(_fullDayEvents.map((event) => _buildFullDayEventCard(event))),
        ],
      ),
    );
  }

  Widget _buildFullDayEventCard(CalendarEvent event) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: event.color,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: GestureDetector(
        onTap: () => widget.onEventTap(event),
        child: Text(
          event.title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildTimeColumn() {
    return Container(
      width: timeColumnWidth,
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(
          right: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
      ),
      child: Column(
        children: List.generate(24, (index) {
          return Container(
            height: hourHeight,
            alignment: Alignment.topLeft,
            padding: const EdgeInsets.only(top: 4, left: 8),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Text(
              '${index.toString().padLeft(2, '0')}:00',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildEventColumn() {
    return Container(
      height: 24 * hourHeight,
      width: double.infinity,
      child: Stack(
        children: [
          _buildGridLines(),
          _buildCurrentTimeIndicator(),
          _buildTapArea(),
          ..._buildLayoutedEvents(),
          _buildOverlayDragTarget(),
        ],
      ),
    );
  }

  Widget _buildGridLines() {
    DateTime now = DateTime.now();
    DateTime today = DateTime(now.year, now.month, now.day);
    DateTime currentSelectedDate = DateTime(
      widget.date.year,
      widget.date.month,
      widget.date.day,
    );
    bool isToday = currentSelectedDate.isAtSameMomentAs(today);
    List<Widget> gridLines = [];

    for (int hour = 0; hour < 24; hour++) {
      bool isCurrentHour = isToday && hour == now.hour;
      double top = hour * hourHeight;
      gridLines.add(
        Positioned(
          top: top,
          left: 0,
          right: 0,
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              color: isCurrentHour ? Colors.blue : Colors.grey.shade300,
            ),
          ),
        ),
      );
    }
    return Stack(children: gridLines);
  }

  Widget _buildCurrentTimeIndicator() {
    DateTime now = DateTime.now();
    DateTime today = DateTime(now.year, now.month, now.day);
    DateTime currentSelectedDate = DateTime(
      widget.date.year,
      widget.date.month,
      widget.date.day,
    );
    bool isToday = currentSelectedDate.isAtSameMomentAs(today);
    if (!isToday) return const SizedBox.shrink();

    double topPosition =
        (now.hour * hourHeight) + ((now.minute / 60) * hourHeight);
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

  Widget _buildTapArea() {
    return Positioned.fill(
      child: GestureDetector(
        onTapDown: (TapDownDetails details) {
          if (!_isPositionOccupied(details.localPosition.dy)) {
            _createEventAtPosition(details.localPosition.dy);
          }
        },
        child: Container(color: Colors.transparent),
      ),
    );
  }

  bool _isPositionOccupied(double yPosition) {
    double hours = yPosition / hourHeight;
    DateTime tapTime = DateTime(
      widget.date.year,
      widget.date.month,
      widget.date.day,
    ).add(Duration(minutes: (hours * 60).round()));

    for (CalendarEvent event in _timedEvents) {
      if (tapTime.isAfter(event.startTime) && tapTime.isBefore(event.endTime)) {
        return true;
      }
      if (tapTime.isAtSameMomentAs(event.startTime)) {
        return true;
      }
    }
    return false;
  }

  void _createEventAtPosition(double yPosition) {
    double hours = yPosition / hourHeight;
    int targetHour = hours.floor();
    int targetMinute = ((hours - targetHour) * 60).round();
    targetMinute = (targetMinute ~/ minuteInterval) * minuteInterval;
    if (targetMinute >= 60) {
      targetHour += 1;
      targetMinute = 0;
    }
    if (targetHour < 0) targetHour = 0;
    if (targetHour >= 24) targetHour = 23;

    DateTime baseDate = DateTime(
      widget.date.year,
      widget.date.month,
      widget.date.day,
    );
    DateTime startTime = baseDate.copyWith(
      hour: targetHour,
      minute: targetMinute,
    );

    widget.onTimeSlotTap(startTime);
  }

  Widget _buildOverlayDragTarget() {
    return Positioned.fill(
      child: Builder(
        builder: (context) {
          return DragTarget<CalendarEvent>(
            onMove: (details) {
              try {
                DateTime now = DateTime.now();
                if (_lastUpdateTime != null &&
                    now.difference(_lastUpdateTime!).inMilliseconds < 16) {
                  return;
                }
                _lastUpdateTime = now;

                Offset globalPosition = details.offset;

                // Auto Scroll Zone Detection
                RenderBox? scrollAreaRenderBox =
                    _scrollKey.currentContext?.findRenderObject() as RenderBox?;
                if (scrollAreaRenderBox != null &&
                    _scrollController.hasClients) {
                  Offset scrollAreaGlobalOffset =
                      scrollAreaRenderBox.localToGlobal(Offset.zero);
                  double viewportTopY = scrollAreaGlobalOffset.dy;
                  double viewportHeight = scrollAreaRenderBox.size.height;
                  double viewportBottomY = viewportTopY + viewportHeight;
                  const double scrollZoneHeight = 60.0;

                  if (globalPosition.dy < viewportTopY + scrollZoneHeight) {
                    _autoScrollVelocity = -_kAutoScrollPixelsPerTick;
                  } else if (globalPosition.dy >
                      viewportBottomY - scrollZoneHeight) {
                    _autoScrollVelocity = _kAutoScrollPixelsPerTick;
                  } else {
                    _autoScrollVelocity = 0.0;
                  }
                  _manageAutoScrollTimer();
                } else {
                  _autoScrollVelocity = 0.0;
                  _manageAutoScrollTimer();
                }

                RenderBox? dragTargetRenderBox =
                    context.findRenderObject() as RenderBox?;
                if (dragTargetRenderBox != null) {
                  Offset localOffset = dragTargetRenderBox.globalToLocal(
                    globalPosition,
                  );
                  double localY = localOffset.dy;
                  double hours = localY / hourHeight;
                  int targetHour = hours.floor();
                  int targetMinute = ((hours - targetHour) * 60).round();
                  targetMinute =
                      (targetMinute ~/ minuteInterval) * minuteInterval;
                  if (targetMinute >= 60) {
                    targetHour += 1;
                    targetMinute = 0;
                  }
                  DateTime? newDragTargetTime;
                  if (targetHour >= 0 &&
                      targetHour < 24 &&
                      targetMinute >= 0 &&
                      targetMinute < 60) {
                    DateTime baseDate = DateTime(
                      widget.date.year,
                      widget.date.month,
                      widget.date.day,
                    );
                    newDragTargetTime = baseDate.copyWith(
                      hour: targetHour,
                      minute: targetMinute,
                    );
                  }
                  if (_dragTargetTime != newDragTargetTime) {
                    setState(() {
                      _dragTargetTime = newDragTargetTime;
                    });
                  }
                }
              } catch (e) {
                print('Error in drag calculation: $e');
              }
            },
            onWillAcceptWithDetails: (data) {
              if (data.data != null) {
                setState(() {
                  _draggedEvent = data.data;
                  _isDragging = true;
                });
              }
              return data.data != null;
            },
            onAcceptWithDetails: (details) {
              _autoScrollTimer?.cancel();
              _autoScrollTimer = null;
              _autoScrollVelocity = 0.0;
              try {
                if (_dragTargetTime != null && widget.onEventMove != null) {
                  widget.onEventMove!(details.data, _dragTargetTime!);
                }
              } catch (e) {
                print('Error in drop: $e');
              }
              setState(() {
                _isDragging = false;
                _dragTargetTime = null;
                _draggedEvent = null;
                _lastUpdateTime = null;
              });
            },
            onLeave: (data) {
              _autoScrollTimer?.cancel();
              _autoScrollTimer = null;
              _autoScrollVelocity = 0.0;
              setState(() {
                _dragTargetTime = null;
              });
            },
            builder: (context, candidateData, rejectedData) {
              bool isHighlighted = candidateData.isNotEmpty;
              Color? backgroundColor;
              if (isHighlighted) {
                backgroundColor = Colors.orange.withOpacity(0.08);
              }
              return IgnorePointer(
                ignoring: !isHighlighted,
                child: Container(
                  color: backgroundColor ?? Colors.transparent,
                  child: isHighlighted
                      ? Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.orange.withOpacity(0.6),
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        )
                      : null,
                ),
              );
            },
          );
        },
      ),
    );
  }

  List<Widget> _buildLayoutedEvents() {
    List<EventLayout> layouts = _calculateEventLayouts();
    return layouts.map((layout) => _buildDraggableEvent(layout)).toList();
  }

  List<EventLayout> _calculateEventLayouts() {
    List<CalendarEvent> events = _timedEvents;
    if (events.isEmpty) return [];

    List<CalendarEvent> sortedEvents = List.from(events);
    sortedEvents.sort((a, b) => a.startTime.compareTo(b.startTime));

    List<EventLayout> layouts = [];
    List<CalendarEvent> processedEvents = [];

    for (CalendarEvent event in sortedEvents) {
      if (processedEvents.contains(event)) continue;

      List<CalendarEvent> overlappingGroup = [event];

      for (CalendarEvent otherEvent in sortedEvents) {
        if (event == otherEvent || processedEvents.contains(otherEvent))
          continue;
        if (overlappingGroup.contains(otherEvent)) continue;

        bool overlapsWithCurrentGroup = false;
        for (CalendarEvent groupEvent in overlappingGroup) {
          if (_eventsOverlap(groupEvent, otherEvent)) {
            overlapsWithCurrentGroup = true;
            break;
          }
        }
        if (overlapsWithCurrentGroup) {
          overlappingGroup.add(otherEvent);
        }
      }

      for (var e in overlappingGroup) {
        if (!processedEvents.contains(e)) processedEvents.add(e);
      }

      overlappingGroup.sort((a, b) {
        int comp = a.startTime.compareTo(b.startTime);
        if (comp == 0) {
          return a.endTime.compareTo(b.endTime);
        }
        return comp;
      });

      List<List<CalendarEvent>> columns = [];

      for (CalendarEvent currentEventInGroup in overlappingGroup) {
        int targetCol = -1;
        for (int i = 0; i < columns.length; i++) {
          bool canPlace = true;
          for (CalendarEvent placedEvent in columns[i]) {
            if (_eventsOverlap(currentEventInGroup, placedEvent)) {
              canPlace = false;
              break;
            }
          }
          if (canPlace) {
            targetCol = i;
            break;
          }
        }

        if (targetCol == -1) {
          columns.add([]);
          targetCol = columns.length - 1;
        }
        columns[targetCol].add(currentEventInGroup);
      }

      int totalColumnsInGroup = columns.isNotEmpty ? columns.length : 1;
      for (int colIdx = 0; colIdx < columns.length; colIdx++) {
        for (CalendarEvent ev in columns[colIdx]) {
          layouts.add(
            EventLayout(
              event: ev,
              left: colIdx.toDouble() / totalColumnsInGroup.toDouble(),
              width: 1.0 / totalColumnsInGroup.toDouble(),
              column: colIdx,
              totalColumns: totalColumnsInGroup,
            ),
          );
        }
      }
    }
    return layouts;
  }

  bool _eventsOverlap(CalendarEvent event1, CalendarEvent event2) {
    return event1.startTime.isBefore(event2.endTime) &&
        event2.startTime.isBefore(event1.endTime);
  }

  Widget _buildDraggableEvent(EventLayout layout) {
    CalendarEvent event = layout.event;
    double top = _getEventTopPosition(event);
    double height = _getEventHeight(event);
    double leftPadding = 4;
    double rightPadding = 4;

    double screenWidth = MediaQuery.of(context).size.width;
    double availableWidthForEvents =
        screenWidth - timeColumnWidth - leftPadding - rightPadding;

    double eventWidth = (availableWidthForEvents * layout.width).clamp(
          50.0,
          availableWidthForEvents,
        ) -
        (layout.totalColumns > 1 ? 2 : 0);
    double eventLeft = leftPadding + (availableWidthForEvents * layout.left);

    return Positioned(
      top: top,
      left: eventLeft,
      width: eventWidth,
      height: height,
      child: LongPressDraggable<CalendarEvent>(
        data: event,
        onDragStarted: () {
          setState(() {
            _isDragging = true;
            _draggedEvent = event;
            _lastUpdateTime = null;
            _autoScrollTimer?.cancel();
            _autoScrollTimer = null;
            _autoScrollVelocity = 0.0;
          });
        },
        onDragEnd: (details) {
          _autoScrollTimer?.cancel();
          _autoScrollTimer = null;
          _autoScrollVelocity = 0.0;
          setState(() {
            _isDragging = false;
            _dragTargetTime = null;
            _draggedEvent = null;
            _lastUpdateTime = null;
          });
        },
        feedback: Material(
          elevation: 6,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: eventWidth,
            height: height,
            decoration: BoxDecoration(
              color: event.color.withOpacity(0.9),
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
            color: Colors.grey.withOpacity(0.4),
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
                  color: Colors.black.withOpacity(0.15),
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
    if (_dragTargetTime == null || !_isDragging) {
      return const SizedBox.shrink();
    }

    double startTimeY = (_dragTargetTime!.hour * hourHeight) +
        (_dragTargetTime!.minute * hourHeight / 60);

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
      left: timeColumnWidth + 10,
      top: startTimeY - 25,
      child: IgnorePointer(
        child: Material(
          color: Colors.transparent,
          elevation: 8,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            constraints: BoxConstraints(
              maxWidth:
                  MediaQuery.of(context).size.width - timeColumnWidth - 40,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
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

  double _getEventTopPosition(CalendarEvent event) {
    int hour = event.startTime.hour;
    int minute = event.startTime.minute;
    return (hour * hourHeight) + (minute * hourHeight / 60);
  }

  double _getEventHeight(CalendarEvent event) {
    Duration duration = event.endTime.difference(event.startTime);
    return (duration.inMinutes * hourHeight / 60).clamp(20.0, double.infinity);
  }
}

// Event Layout class
class EventLayout {
  final CalendarEvent event;
  final double left;
  final double width;
  final int column;
  final int totalColumns;

  EventLayout({
    required this.event,
    required this.left,
    required this.width,
    required this.column,
    required this.totalColumns,
  });
}
