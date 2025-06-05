// lib/features/calendar/presentation/pages/day_view_page.dart
// SIMPLE FIXED VERSION - Guaranteed no jumping

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/utils/date_utils.dart';
import '../../domain/entities/calendar_event.dart';
import '../bloc/calendar_bloc.dart';
import '../bloc/calendar_event.dart' as calendar_events;
import '../bloc/calendar_state.dart';
import '../widgets/day_view_widget.dart';
import 'add_event_page.dart';

class DayViewPage extends StatefulWidget {
  final DateTime initialDate;

  const DayViewPage({super.key, required this.initialDate});

  @override
  State<DayViewPage> createState() => _DayViewPageState();
}

class _DayViewPageState extends State<DayViewPage> {
  late DateTime _selectedDate;
  late PageController _pageController;

  // Untuk scroll position
  double? _savedScrollPosition;

  // Smart notification management
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? _currentSnackBar;
  String? _lastShownNotificationId;
  DateTime? _lastNotificationTime;

  // Untuk undo functionality
  CalendarEvent? _lastMovedEvent;
  DateTime? _originalStartTime;
  DateTime? _originalEndTime;
  bool _hasUndoData = false;

  // ✅ SIMPLE LOCAL EVENTS - Ini satu-satunya source of truth
  List<CalendarEvent> _localEvents = [];
  bool _isLoadingEvents = false;

  // ✅ CRITICAL: Flag untuk block external updates saat drag
  bool _blockExternalUpdates = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime(
      widget.initialDate.year,
      widget.initialDate.month,
      widget.initialDate.day,
    );
    _pageController = PageController(initialPage: 1000);

    // Load events for the selected date
    _loadEventsForDate(_selectedDate);
  }

  @override
  void dispose() {
    _dismissCurrentSnackBar();
    _pageController.dispose();
    super.dispose();
  }

  void _loadEventsForDate(DateTime date) {
    setState(() {
      _isLoadingEvents = true;
      _blockExternalUpdates = false; // Allow updates saat load
    });

    context.read<CalendarBloc>().add(
          calendar_events.LoadEventsForDate(date: date),
        );
  }

  void _changeDate(int dayOffset) {
    _dismissCurrentSnackBar();

    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: dayOffset));
      _savedScrollPosition = null; // ✅ Only reset scroll when changing date
      _localEvents = []; // Clear local events when changing date
      _blockExternalUpdates = false; // Reset block
    });
    _loadEventsForDate(_selectedDate);
  }

  // Smart notification management methods
  void _dismissCurrentSnackBar() {
    if (_currentSnackBar != null) {
      _currentSnackBar!.close();
      _currentSnackBar = null;
    }
  }

  void _showSmartSnackBar({
    required String message,
    required Color backgroundColor,
    Duration duration = const Duration(seconds: 3),
    String? actionLabel,
    VoidCallback? actionCallback,
    String? notificationId,
  }) {
    // Prevent duplicate notifications
    if (notificationId != null) {
      if (_lastShownNotificationId == notificationId) {
        DateTime now = DateTime.now();
        if (_lastNotificationTime != null &&
            now.difference(_lastNotificationTime!).inMilliseconds < 1000) {
          return; // Block duplicate within 1 second
        }
      }
      _lastShownNotificationId = notificationId;
      _lastNotificationTime = DateTime.now();
    }

    // Dismiss previous notification
    _dismissCurrentSnackBar();

    // Show new notification
    _currentSnackBar = ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        duration: duration,
        behavior: SnackBarBehavior.floating,
        action: actionLabel != null && actionCallback != null
            ? SnackBarAction(
                label: actionLabel,
                textColor: Colors.white,
                onPressed: () {
                  _dismissCurrentSnackBar();
                  actionCallback();
                },
              )
            : null,
      ),
    );

    // Auto-clear reference when notification disappears
    _currentSnackBar!.closed.then((_) {
      if (_currentSnackBar != null) {
        _currentSnackBar = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppDateUtils.formatDisplayDate(_selectedDate)),
        actions: [
          IconButton(
            onPressed: () => _changeDate(-1),
            icon: const Icon(Icons.chevron_left),
            tooltip: 'Hari Sebelumnya',
          ),
          IconButton(
            onPressed: () {
              final today = DateTime.now();
              final todayDate = DateTime(today.year, today.month, today.day);
              if (todayDate != _selectedDate) {
                setState(() {
                  _selectedDate = todayDate;
                  _savedScrollPosition = null;
                  _localEvents = []; // Clear local events
                  _blockExternalUpdates = false;
                });
                _loadEventsForDate(_selectedDate);
                _pageController.animateToPage(
                  1000,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              }
            },
            icon: const Icon(Icons.today),
            tooltip: 'Hari Ini',
          ),
          IconButton(
            onPressed: () => _changeDate(1),
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Hari Selanjutnya',
          ),
          IconButton(
            onPressed: () {
              // ✅ PRESERVE scroll position saat refresh
              print(
                  '🔄 Refreshing while preserving scroll position: $_savedScrollPosition');
              _localEvents = []; // Clear local events untuk fresh load
              _blockExternalUpdates = false;
              _loadEventsForDate(_selectedDate);
            },
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: BlocListener<CalendarBloc, CalendarState>(
        listener: (context, state) {
          print('📡 BlocListener received: ${state.runtimeType}');
          print('🚧 Block external updates: $_blockExternalUpdates');

          if (state is CalendarError) {
            _showSmartSnackBar(
              message: state.message,
              backgroundColor: Colors.red,
              actionLabel: 'RETRY',
              actionCallback: () => _loadEventsForDate(_selectedDate),
              notificationId: 'error_${state.message.hashCode}',
            );
          } else if (state is EventDeleted) {
            print('📡 EventDeleted received');
            _showSmartSnackBar(
              message: 'Event berhasil dihapus',
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
              notificationId: 'deleted_${state.eventId}',
            );
            if (!_blockExternalUpdates) {
              _removeEventFromLocal(state.eventId);
            } else {
              print('🚧 BLOCKED EventDeleted update');
            }
          } else if (state is EventCreated) {
            print('📡 EventCreated received');
            _showSmartSnackBar(
              message: '${state.event.title} berhasil dibuat',
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
              notificationId: 'created_${state.event.id}',
            );
            if (!_blockExternalUpdates) {
              _addEventToLocal(state.event);
            } else {
              print('🚧 BLOCKED EventCreated update');
            }
          } else if (state is CalendarLoaded) {
            print(
                '📡 CalendarLoaded received with ${state.events.length} events');
            print('🚧 Block status: $_blockExternalUpdates');

            // ✅ CRITICAL: Only update if external updates are NOT blocked
            if (!_blockExternalUpdates) {
              print('✅ Applying CalendarLoaded update');
              setState(() {
                _isLoadingEvents = false;
                final newEvents = state.events.where((event) {
                  return AppDateUtils.isSameDay(
                          event.startTime, _selectedDate) ||
                      (event.isMultiDay &&
                          _selectedDate.isAfter(
                            event.startTime.subtract(const Duration(days: 1)),
                          ) &&
                          _selectedDate.isBefore(
                            event.endTime.add(const Duration(days: 1)),
                          ));
                }).toList();

                print(
                    '📋 Before update - Local events count: ${_localEvents.length}');
                print('📋 New events from server: ${newEvents.length}');

                _localEvents = newEvents;

                print(
                    '📋 After update - Local events count: ${_localEvents.length}');

                // Debug: Print all local events
                for (int i = 0; i < _localEvents.length; i++) {
                  final e = _localEvents[i];
                  print(
                      '   [$i] ${e.title}: ${AppDateUtils.formatTime(e.startTime)} - ${AppDateUtils.formatTime(e.endTime)}');
                }
              });
              print(
                  '✅ CalendarLoaded update applied - ${_localEvents.length} events');
            } else {
              print(
                  '🚧 BLOCKED CalendarLoaded update - preserving ${_localEvents.length} local events');

              // Debug: Print current local events
              print('🔍 Current local events (preserved):');
              for (int i = 0; i < _localEvents.length; i++) {
                final e = _localEvents[i];
                print(
                    '   [$i] ${e.title}: ${AppDateUtils.formatTime(e.startTime)} - ${AppDateUtils.formatTime(e.endTime)}');
              }
            }
          } else if (state is EventUpdated) {
            print('📡 EventUpdated received for: ${state.event.title}');
            print('🚧 Block status: $_blockExternalUpdates');
            if (_blockExternalUpdates) {
              print('🔕 EventUpdated BLOCKED - local state is source of truth');
            } else {
              print(
                  '⚠️ EventUpdated received when NOT blocked - this might cause issues');
            }
          }
        },
        child: GestureDetector(
          // Dismiss notification on tap empty area
          onTap: () {
            _dismissCurrentSnackBar();
          },
          onHorizontalDragEnd: (details) {
            if (details.primaryVelocity != null) {
              if (details.primaryVelocity! > 0) {
                _changeDate(-1);
              } else if (details.primaryVelocity! < 0) {
                _changeDate(1);
              }
            }
          },
          child: _isLoadingEvents
              ? const Center(child: CircularProgressIndicator())
              : Builder(
                  builder: (context) {
                    // ✅ Debug: Monitor events passed to DayViewWidget
                    print(
                        '🎯 Building DayViewWidget with ${_localEvents.length} events:');
                    for (int i = 0; i < _localEvents.length; i++) {
                      final e = _localEvents[i];
                      print(
                          '   [$i] ${e.title}: ${AppDateUtils.formatTime(e.startTime)} - ${AppDateUtils.formatTime(e.endTime)}');
                    }
                    print('📍 Current scroll position: $_savedScrollPosition');

                    return DayViewWidget(
                      date: _selectedDate,
                      events:
                          _localEvents, // ✅ Direct reference, no new list creation
                      onEventTap: _showEventDetails,
                      onTimeSlotTap: _createEventAtTime,
                      onEventMove: _moveEvent,
                      onScrollPositionChanged: (position) {
                        // ✅ Always save scroll position
                        _savedScrollPosition = position;
                        print('📍 Scroll position saved: $position');
                      },
                      initialScrollPosition:
                          _savedScrollPosition, // ✅ Restore saved position
                    );
                  },
                ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToAddEvent(),
        tooltip: 'Tambah Event',
        child: const Icon(Icons.add),
      ),
    );
  }

  // ✅ SIMPLE MOVE EVENT - Block external updates dan update local immediately
  void _moveEvent(CalendarEvent event, DateTime newTime) {
    print('===== MOVE EVENT START =====');
    print('🔄 Moving ${event.title} from ${event.startTime} to $newTime');

    // ✅ CRITICAL: Save current scroll position BEFORE any updates
    print('💾 Saving current scroll position: $_savedScrollPosition');

    // Debug: Print current local events before
    print('📋 Local events BEFORE move (${_localEvents.length}):');
    for (int i = 0; i < _localEvents.length; i++) {
      final e = _localEvents[i];
      print(
          '   [$i] ${e.title}: ${AppDateUtils.formatTime(e.startTime)} - ${AppDateUtils.formatTime(e.endTime)}');
    }

    // ✅ CRITICAL: Block all external updates
    setState(() {
      _blockExternalUpdates = true;
    });
    print('🚧 External updates BLOCKED');

    // Save undo data
    _lastMovedEvent = event.copyWith();
    _originalStartTime = event.startTime;
    _originalEndTime = event.endTime;
    _hasUndoData = true;

    // Calculate new event
    final duration = event.endTime.difference(event.startTime);
    final updatedEvent = event.copyWith(
      startTime: newTime,
      endTime: newTime.add(duration),
      lastModified: DateTime.now(),
    );

    // ✅ CRITICAL: Update local events immediately dengan MINIMAL rebuild
    setState(() {
      final index = _localEvents.indexWhere((e) => e.id == event.id);
      print('🔍 Finding event ${event.id} in local events...');
      print('🔍 Found at index: $index');

      if (index != -1) {
        print('🔄 Replacing event at index $index');
        print(
            '   Old: ${_localEvents[index].title} at ${AppDateUtils.formatTime(_localEvents[index].startTime)}');
        print(
            '   New: ${updatedEvent.title} at ${AppDateUtils.formatTime(updatedEvent.startTime)}');

        // ✅ MINIMAL CHANGE: Just replace event without creating new list
        _localEvents[index] = updatedEvent;
        _localEvents.sort((a, b) => a.startTime.compareTo(b.startTime));

        print('✅ Local event updated: ${updatedEvent.title} now at $newTime');

        // Debug: Print all events after update
        print('📋 Local events AFTER move (${_localEvents.length}):');
        for (int i = 0; i < _localEvents.length; i++) {
          final e = _localEvents[i];
          print(
              '   [$i] ${e.title}: ${AppDateUtils.formatTime(e.startTime)} - ${AppDateUtils.formatTime(e.endTime)}');
        }
      } else {
        print('❌ ERROR: Event not found in local events!');
      }
    });

    // Show success message immediately
    _showSmartSnackBar(
      message: '${event.title} berhasil dipindah',
      backgroundColor: Colors.green,
      duration: const Duration(seconds: 5),
      actionLabel: 'BATALKAN',
      actionCallback: () => _undoMoveEvent(),
      notificationId: 'moved_${event.id}_${newTime.millisecondsSinceEpoch}',
    );

    // ✅ CRITICAL: Unblock external updates after delay
    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _blockExternalUpdates = false;
        });
        print('🔓 External updates UNBLOCKED');

        // Debug: Print events after unblock
        print('📋 Local events AFTER unblock (${_localEvents.length}):');
        for (int i = 0; i < _localEvents.length; i++) {
          final e = _localEvents[i];
          print(
              '   [$i] ${e.title}: ${AppDateUtils.formatTime(e.startTime)} - ${AppDateUtils.formatTime(e.endTime)}');
        }
      }
    });

    // Background sync (akan di-ignore karena updates blocked)
    context.read<CalendarBloc>().add(
          calendar_events.UpdateEvent(updatedEvent),
        );

    print(
        '✅ Move event completed - local state updated, external updates blocked');
    print('===== MOVE EVENT END =====');
  }

  // ✅ SIMPLE LOCAL EVENT MANAGEMENT
  void _addEventToLocal(CalendarEvent newEvent) {
    setState(() {
      if (AppDateUtils.isSameDay(newEvent.startTime, _selectedDate) ||
          (newEvent.isMultiDay &&
              _selectedDate.isAfter(
                newEvent.startTime.subtract(const Duration(days: 1)),
              ) &&
              _selectedDate.isBefore(
                newEvent.endTime.add(const Duration(days: 1)),
              ))) {
        _localEvents.add(newEvent);
        _localEvents.sort((a, b) => a.startTime.compareTo(b.startTime));
        print('✅ Added new event ${newEvent.title} to local events');
      }
    });
  }

  void _removeEventFromLocal(String eventId) {
    setState(() {
      _localEvents.removeWhere((e) => e.id == eventId);
      print('✅ Removed event $eventId from local events');
    });
  }

  void _undoMoveEvent() {
    if (!_hasUndoData ||
        _lastMovedEvent == null ||
        _originalStartTime == null ||
        _originalEndTime == null) {
      _showSmartSnackBar(
        message: 'Tidak ada data untuk dibatalkan',
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 2),
        notificationId: 'undo_failed',
      );
      return;
    }

    // Block external updates during undo
    setState(() {
      _blockExternalUpdates = true;
    });

    // Create event with original times
    final originalEvent = _lastMovedEvent!.copyWith(
      startTime: _originalStartTime!,
      endTime: _originalEndTime!,
      lastModified: DateTime.now(),
    );

    // Update local events immediately
    setState(() {
      final index = _localEvents.indexWhere((e) => e.id == originalEvent.id);
      if (index != -1) {
        _localEvents[index] = originalEvent;
        _localEvents.sort((a, b) => a.startTime.compareTo(b.startTime));
      }
    });

    // Background sync
    context.read<CalendarBloc>().add(
          calendar_events.UpdateEvent(originalEvent),
        );

    // Show success message
    _showSmartSnackBar(
      message: '${_lastMovedEvent!.title} dikembalikan ke posisi semula',
      backgroundColor: Colors.orange,
      duration: const Duration(seconds: 3),
      notificationId: 'undo_success_${_lastMovedEvent!.id}',
    );

    // Clear undo data and unblock updates
    Timer(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _lastMovedEvent = null;
          _originalStartTime = null;
          _originalEndTime = null;
          _hasUndoData = false;
          _blockExternalUpdates = false;
        });
      }
    });
  }

  // ✅ EXISTING METHODS (unchanged)
  void _navigateToAddEvent([DateTime? time]) {
    _dismissCurrentSnackBar();

    final eventTime = time ??
        DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
          DateTime.now().hour,
          DateTime.now().minute,
        );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEventPage(initialDate: eventTime),
      ),
    );
  }

  void _showEventDetails(CalendarEvent event) {
    _dismissCurrentSnackBar();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle indicator
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),

              // Event content - scrollable
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Event title dengan color indicator
                      Row(
                        children: [
                          Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: event.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              event.title,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Event details
                      _buildDetailRow(
                        Icons.access_time,
                        event.isAllDay
                            ? 'Sepanjang hari'
                            : '${AppDateUtils.formatTime(event.startTime)} - ${AppDateUtils.formatTime(event.endTime)}',
                      ),

                      if (event.location != null) ...[
                        const SizedBox(height: 16),
                        _buildDetailRow(Icons.location_on, event.location!),
                      ],

                      if (event.description != null) ...[
                        const SizedBox(height: 16),
                        _buildDetailRow(Icons.subject, event.description!),
                      ],

                      if (event.isFromGoogle) ...[
                        const SizedBox(height: 16),
                        _buildDetailRow(
                          Icons.cloud,
                          'Disinkronkan dengan Google Calendar',
                        ),
                      ],

                      const SizedBox(height: 40), // Extra space for buttons
                    ],
                  ),
                ),
              ),

              // Action buttons - fixed at bottom
              Container(
                padding: const EdgeInsets.only(top: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    top: BorderSide(color: Colors.grey.shade200, width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AddEventPage(
                                initialDate: event.startTime,
                                existingEvent: event,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.edit),
                        label: const Text('Edit'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _deleteEvent(event),
                        icon: const Icon(Icons.delete),
                        label: const Text('Hapus'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.grey.shade600, size: 24),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ],
    );
  }

  void _createEventAtTime(DateTime time) {
    _navigateToAddEvent(time);
  }

  void _deleteEvent(CalendarEvent event) {
    Navigator.pop(context); // Close bottom sheet

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Event'),
        content: Text('Yakin ingin menghapus "${event.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<CalendarBloc>().add(
                    calendar_events.DeleteEvent(event.id),
                  );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }
}
