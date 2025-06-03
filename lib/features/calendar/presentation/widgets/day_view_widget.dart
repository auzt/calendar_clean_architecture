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
  final double _hourHeight = 60.0;
  final double _timeColumnWidth = 80.0;
  final int _minuteInterval = 5;

  // Drag state
  bool _isDragging = false;
  DateTime? _dragTargetTime;
  CalendarEvent? _draggedEvent;
  DateTime? _lastUpdateTime;

  // Auto-scroll variables
  Timer? _autoScrollTimer;
  bool _isAutoScrolling = false;
  final double _baseAutoScrollZone = 80.0;
  final double _autoScrollSpeed = 2.5;
  double _currentAutoScrollZone = 80.0;

  // Separate events
  List<CalendarEvent> _fullDayEvents = [];
  List<CalendarEvent> _timedEvents = [];

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _separateEvents();

    // Add listener untuk scroll position
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
    _autoScrollTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _separateEvents() {
    _fullDayEvents = [];
    _timedEvents = [];

    for (var event in widget.events) {
      if (event.isAllDay ||
          (event.startTime.hour == 0 &&
              event.startTime.minute == 0 &&
              event.endTime.hour == 23 &&
              event.endTime.minute == 59 &&
              AppDateUtils.isSameDay(event.startTime, event.endTime))) {
        _fullDayEvents.add(event);
      } else {
        _timedEvents.add(event);
      }
    }
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

  void _startAutoScroll(double globalY) {
    if (_isAutoScrolling) return;

    _autoScrollTimer?.cancel();

    _calculateAutoScrollZone();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      double appBarHeight = kToolbarHeight;
      double statusBarHeight = MediaQuery.of(context).padding.top;
      double fullDayEventsHeight = _fullDayEvents.isNotEmpty
          ? (_fullDayEvents.length * 25.0) + 40.0
          : 0.0;

      double effectiveTop =
          statusBarHeight + appBarHeight + fullDayEventsHeight;
      double effectiveBottom = MediaQuery.of(context).size.height - 100;

      bool shouldScrollUp = globalY < (effectiveTop + _currentAutoScrollZone);
      bool shouldScrollDown =
          globalY > (effectiveBottom - _currentAutoScrollZone);

      if (!shouldScrollUp && !shouldScrollDown) {
        _stopAutoScroll();
        return;
      }

      _isAutoScrolling = true;

      _autoScrollTimer =
          Timer.periodic(const Duration(milliseconds: 16), (timer) {
        if (!_scrollController.hasClients || !_isDragging || !mounted) {
          _stopAutoScroll();
          return;
        }

        double currentOffset = _scrollController.offset;
        double newOffset;

        if (shouldScrollUp) {
          newOffset = (currentOffset - _autoScrollSpeed)
              .clamp(0.0, _scrollController.position.maxScrollExtent);
        } else {
          newOffset = (currentOffset + _autoScrollSpeed)
              .clamp(0.0, _scrollController.position.maxScrollExtent);
        }

        if (newOffset != currentOffset) {
          _scrollController.jumpTo(newOffset);
        } else {
          _stopAutoScroll();
        }
      });
    });
  }

  void _calculateAutoScrollZone() {
    double adjustment = _fullDayEvents.length * 5.0;
    _currentAutoScrollZone =
        (_baseAutoScrollZone + adjustment).clamp(60.0, 120.0);
  }

  void _stopAutoScroll() {
    if (_autoScrollTimer != null) {
      _autoScrollTimer?.cancel();
      _autoScrollTimer = null;
      _isAutoScrolling = false;
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
                  controller: _scrollController,
                  child: SizedBox(
                    height: 24 * _hourHeight,
                    child: Row(
                      children: [
                        _buildTimeColumn(),
                        Expanded(child: _buildEventColumn()),
                      ],
                    ),
                  ),
                ),
                // Drag indicator
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
        child: Row(
          children: [
            Expanded(
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
            if (event.location != null) ...[
              const SizedBox(width: 8),
              Icon(
                Icons.location_on,
                color: Colors.white.withOpacity(0.8),
                size: 14,
              ),
            ],
          ],
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
    );
  }

  Widget _buildEventColumn() {
    return SizedBox(
      height: 24 * _hourHeight,
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
      double top = hour * _hourHeight;

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
    double hours = yPosition / _hourHeight;
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

                if (_isDragging) {
                  double globalY = details.offset.dy;
                  _startAutoScroll(globalY);
                }

                RenderBox? renderBox = context.findRenderObject() as RenderBox?;
                if (renderBox != null) {
                  Offset localOffset = renderBox.globalToLocal(details.offset);
                  double localY = localOffset.dy;

                  double hours = localY / _hourHeight;
                  int targetHour = hours.floor();
                  int targetMinute = ((hours - targetHour) * 60).round();

                  targetMinute =
                      (targetMinute ~/ _minuteInterval) * _minuteInterval;

                  if (targetMinute >= 60) {
                    targetHour += 1;
                    targetMinute = 0;
                  }

                  if (targetHour >= 0 &&
                      targetHour < 24 &&
                      targetMinute >= 0 &&
                      targetMinute < 60) {
                    DateTime baseDate = DateTime(
                      widget.date.year,
                      widget.date.month,
                      widget.date.day,
                    );
                    setState(() {
                      _dragTargetTime = baseDate.copyWith(
                        hour: targetHour,
                        minute: targetMinute,
                      );
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
              try {
                _stopAutoScroll();

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
              _stopAutoScroll();

              setState(() {
                _isDragging = false;
                _dragTargetTime = null;
                _draggedEvent = null;
                _lastUpdateTime = null;
              });
            },
            builder: (context, candidateData, rejectedData) {
              bool isHighlighted = candidateData.isNotEmpty;

              return IgnorePointer(
                ignoring: !isHighlighted,
                child: Container(
                  color: isHighlighted
                      ? Colors.orange.withOpacity(0.08)
                      : Colors.transparent,
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

  void _createEventAtPosition(double yPosition) {
    double hours = yPosition / _hourHeight;
    int targetHour = hours.floor();
    int targetMinute = 0; // Set to 0 for full hour

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

  List<Widget> _buildLayoutedEvents() {
    final layouts = _calculateEventLayouts();
    return layouts.map((layout) => _buildDraggableEvent(layout)).toList();
  }

  List<EventLayout> _calculateEventLayouts() {
    List<CalendarEvent> events = _timedEvents;
    if (events.isEmpty) return [];

    List<CalendarEvent> sortedEvents = List.from(events);
    sortedEvents.sort((a, b) => a.startTime.compareTo(b.startTime));

    List<EventLayout> layouts = [];
    List<List<CalendarEvent>> eventGroups = [];

    for (CalendarEvent event in sortedEvents) {
      bool addedToGroup = false;

      for (List<CalendarEvent> group in eventGroups) {
        bool hasOverlap = false;
        for (CalendarEvent groupEvent in group) {
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

    for (List<CalendarEvent> group in eventGroups) {
      if (group.length == 1) {
        layouts.add(
          EventLayout(
            event: group[0],
            left: 0.0,
            width: 1.0,
            column: 0,
            totalColumns: 1,
          ),
        );
      } else {
        List<List<CalendarEvent>> columns = [];

        for (CalendarEvent event in group) {
          int targetColumn = -1;

          for (int i = 0; i < columns.length; i++) {
            bool canPlace = true;
            for (CalendarEvent existingEvent in columns[i]) {
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

        int totalColumns = columns.length;
        double columnWidth = 1.0 / totalColumns;

        for (int columnIndex = 0; columnIndex < columns.length; columnIndex++) {
          for (CalendarEvent event in columns[columnIndex]) {
            layouts.add(
              EventLayout(
                event: event,
                left: columnIndex * columnWidth,
                width: columnWidth,
                column: columnIndex,
                totalColumns: totalColumns,
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

  Widget _buildDraggableEvent(EventLayout layout) {
    CalendarEvent event = layout.event;
    double top = _getEventTopPosition(event);
    double height = _getEventHeight(event);
    double leftPadding = 8;
    double rightPadding = 8;

    return LayoutBuilder(
      builder: (context, constraints) {
        double screenWidth = MediaQuery.of(context).size.width;
        double availableWidth =
            screenWidth - _timeColumnWidth - leftPadding - rightPadding;

        double eventWidth = (availableWidth * layout.width).clamp(
          80.0,
          availableWidth,
        );
        double eventLeft = leftPadding + (availableWidth * layout.left);

        if (eventLeft + eventWidth > screenWidth - rightPadding) {
          eventLeft = screenWidth - rightPadding - eventWidth;
        }

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
              });
            },
            onDragEnd: (details) {
              _stopAutoScroll();

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
      },
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Container(
                constraints: BoxConstraints(
                  maxWidth:
                      MediaQuery.of(context).size.width - _timeColumnWidth - 40,
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
              );
            },
          ),
        ),
      ),
    );
  }

  double _getEventTopPosition(CalendarEvent event) {
    int hour = event.startTime.hour;
    int minute = event.startTime.minute;
    return (hour * _hourHeight) + (minute * _hourHeight / 60);
  }

  double _getEventHeight(CalendarEvent event) {
    Duration duration = event.endTime.difference(event.startTime);
    return (duration.inMinutes * _hourHeight / 60).clamp(20.0, double.infinity);
  }
}

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
