// lib/features/calendar/presentation/pages/day_view_page.dart
// FIXED VERSION - Mengatasi 3 masalah utama

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

class _DayViewPageState extends State<DayViewPage> with WidgetsBindingObserver {
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

  // ✅ LOCAL EVENTS - Source of truth
  List<CalendarEvent> _localEvents = [];
  bool _isLoadingEvents = false;

  // ✅ DRAG STATE - Prevent external updates during drag
  bool _blockExternalUpdates = false;

  // ✅ AUTO-REFRESH TIMER untuk sync periodic
  Timer? _autoRefreshTimer;
  static const Duration _autoRefreshInterval = Duration(minutes: 2);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _selectedDate = DateTime(
      widget.initialDate.year,
      widget.initialDate.month,
      widget.initialDate.day,
    );
    _pageController = PageController(initialPage: 1000);

    // Load events for the selected date
    _loadEventsForDate(_selectedDate);

    // ✅ Start auto-refresh timer untuk sync berkala
    _startAutoRefreshTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _dismissCurrentSnackBar();
    _pageController.dispose();
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  // ✅ Handle app lifecycle changes
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed) {
      // App kembali ke foreground - refresh events
      print('📱 App resumed - refreshing day view');
      _refreshEventsQuietly();
    }
  }

  // ✅ START AUTO-REFRESH TIMER
  void _startAutoRefreshTimer() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(_autoRefreshInterval, (timer) {
      if (mounted && !_blockExternalUpdates) {
        print('🔄 Auto-refresh triggered');
        _refreshEventsQuietly();
      }
    });
  }

  // ✅ QUIET REFRESH - Tidak mengganggu UI
  void _refreshEventsQuietly() {
    if (_blockExternalUpdates) {
      print('🚧 Skipping auto-refresh - drag in progress');
      return;
    }

    // Refresh tanpa loading indicator
    context.read<CalendarBloc>().add(
          calendar_events.LoadEventsForDate(
            date: _selectedDate,
            forceRefresh: true,
          ),
        );
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
      _savedScrollPosition = null; // Reset scroll when changing date
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
              print('🔄 Manual refresh with preserved scroll position');
              _localEvents = []; // Clear untuk fresh load
              _blockExternalUpdates = false;

              // Show loading indicator untuk manual refresh
              setState(() {
                _isLoadingEvents = true;
              });

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
            setState(() {
              _isLoadingEvents = false;
            });
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
            }
          } else if (state is CalendarLoaded) {
            print(
                '📡 CalendarLoaded received with ${state.events.length} events');

            setState(() {
              _isLoadingEvents = false;
            });

            // ✅ CRITICAL: Only update if external updates are NOT blocked
            if (!_blockExternalUpdates) {
              print('✅ Applying CalendarLoaded update');
              setState(() {
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
                    '📋 Updating local events: ${_localEvents.length} -> ${newEvents.length}');
                _localEvents = newEvents;
                _localEvents.sort((a, b) => a.startTime.compareTo(b.startTime));
              });
              print(
                  '✅ CalendarLoaded update applied - ${_localEvents.length} events');
            } else {
              print(
                  '🚧 BLOCKED CalendarLoaded update - preserving ${_localEvents.length} local events');
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
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Memuat events...'),
                    ],
                  ),
                )
              : DayViewWidget(
                  date: _selectedDate,
                  events: _localEvents,
                  onEventTap: _showEventDetails,
                  onTimeSlotTap: _createEventAtTime,
                  onEventMove: _moveEvent,
                  onScrollPositionChanged: (position) {
                    _savedScrollPosition = position;
                  },
                  initialScrollPosition: _savedScrollPosition,
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

  // ✅ FIX 1: IMPROVED MOVE EVENT - UI langsung update, tidak kembali ke posisi awal
  void _moveEvent(CalendarEvent event, DateTime newTime) {
    print('===== MOVE EVENT START =====');
    print('🔄 Moving ${event.title} from ${event.startTime} to $newTime');

    // ✅ CRITICAL: Save scroll position
    print('💾 Saving scroll position: $_savedScrollPosition');

    // ✅ STEP 1: Block external updates IMMEDIATELY
    setState(() {
      _blockExternalUpdates = true;
    });
    print('🚧 External updates BLOCKED');

    // ✅ STEP 2: Save undo data
    _lastMovedEvent = event.copyWith();
    _originalStartTime = event.startTime;
    _originalEndTime = event.endTime;
    _hasUndoData = true;

    // ✅ STEP 3: Calculate new event times
    final duration = event.endTime.difference(event.startTime);
    final updatedEvent = event.copyWith(
      startTime: newTime,
      endTime: newTime.add(duration),
      lastModified: DateTime.now(),
    );

    // ✅ STEP 4: Update local events IMMEDIATELY untuk UI responsif
    setState(() {
      final index = _localEvents.indexWhere((e) => e.id == event.id);
      if (index != -1) {
        print('🔄 Updating local event at index $index');
        _localEvents[index] = updatedEvent;
        _localEvents.sort((a, b) => a.startTime.compareTo(b.startTime));
        print('✅ Local event updated immediately');
      }
    });

    // ✅ STEP 5: Show success message with undo option
    _showSmartSnackBar(
      message:
          '${event.title} berhasil dipindah ke ${AppDateUtils.formatTime(newTime)}',
      backgroundColor: Colors.green,
      duration: const Duration(seconds: 5),
      actionLabel: 'BATALKAN',
      actionCallback: () => _undoMoveEvent(),
      notificationId: 'moved_${event.id}_${newTime.millisecondsSinceEpoch}',
    );

    // ✅ STEP 6: Background sync ke server
    context.read<CalendarBloc>().add(
          calendar_events.UpdateEvent(updatedEvent),
        );

    // ✅ STEP 7: Unblock external updates after delay
    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _blockExternalUpdates = false;
        });
        print('🔓 External updates UNBLOCKED');

        // Quiet refresh untuk sync dengan server
        _refreshEventsQuietly();
      }
    });

    print('✅ Move event completed - UI updated immediately');
    print('===== MOVE EVENT END =====');
  }

  // ✅ LOCAL EVENT MANAGEMENT
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

  // ✅ FIX 3: TIME SLOT TAP - Gunakan jam bulat, tidak menit
  void _createEventAtTime(DateTime time) {
    // ✅ Round ke jam terdekat
    final roundedHour = time.hour;
    final roundedTime = DateTime(
      time.year,
      time.month,
      time.day,
      roundedHour,
      0, // ✅ Selalu gunakan menit 00
    );

    print('⏰ Time slot tapped: ${AppDateUtils.formatTime(time)}');
    print('⏰ Rounded to: ${AppDateUtils.formatTime(roundedTime)}');

    _navigateToAddEvent(roundedTime);
  }

  void _navigateToAddEvent([DateTime? time]) {
    _dismissCurrentSnackBar();

    final eventTime = time ??
        DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
          DateTime.now().hour,
          0, // ✅ Default ke menit 00
        );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEventPage(initialDate: eventTime),
      ),
    ).then((_) {
      // ✅ FIX 2: Auto refresh saat kembali dari add event
      print('🔙 Returned from add event - refreshing');
      _refreshEventsQuietly();
    });
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
                          ).then((_) {
                            // ✅ FIX 2: Auto refresh saat kembali dari edit
                            print('🔙 Returned from edit event - refreshing');
                            _refreshEventsQuietly();
                          });
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
