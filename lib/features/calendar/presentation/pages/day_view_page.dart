// lib/features/calendar/presentation/pages/day_view_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/utils/date_utils.dart';
import '../../domain/entities/calendar_event.dart';
import '../../domain/entities/calendar_date_range.dart';
import '../bloc/calendar_bloc.dart';
import '../bloc/calendar_event.dart' as calendar_events;
import '../bloc/calendar_state.dart';
import '../widgets/day_view_widget.dart';
import 'add_event_page.dart';

class DayViewPage extends StatefulWidget {
  final DateTime initialDate;

  const DayViewPage({Key? key, required this.initialDate}) : super(key: key);

  @override
  State<DayViewPage> createState() => _DayViewPageState();
}

class _DayViewPageState extends State<DayViewPage> {
  late DateTime _selectedDate;
  late PageController _pageController;

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
    _pageController.dispose();
    super.dispose();
  }

  void _loadEventsForDate(DateTime date) {
    context.read<CalendarBloc>().add(
      calendar_events.LoadEventsForDate(date: date),
    );
  }

  void _changeDate(int dayOffset) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: dayOffset));
    });
    _loadEventsForDate(_selectedDate);
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
        ],
      ),
      body: BlocListener<CalendarBloc, CalendarState>(
        listener: (context, state) {
          if (state is CalendarError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
                action: SnackBarAction(
                  label: 'RETRY',
                  textColor: Colors.white,
                  onPressed: () => _loadEventsForDate(_selectedDate),
                ),
              ),
            );
          } else if (state is EventDeleted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Event berhasil dihapus'),
                backgroundColor: Colors.green,
              ),
            );
          }
        },
        child: BlocBuilder<CalendarBloc, CalendarState>(
          builder: (context, state) {
            if (state is CalendarLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            List<CalendarEvent> events = [];
            if (state is CalendarLoaded) {
              events =
                  state.events.where((event) {
                    return AppDateUtils.isSameDay(
                          event.startTime,
                          _selectedDate,
                        ) ||
                        (event.isMultiDay &&
                            _selectedDate.isAfter(
                              event.startTime.subtract(const Duration(days: 1)),
                            ) &&
                            _selectedDate.isBefore(
                              event.endTime.add(const Duration(days: 1)),
                            ));
                  }).toList();
            }

            return GestureDetector(
              onHorizontalDragEnd: (details) {
                if (details.primaryVelocity != null) {
                  if (details.primaryVelocity! > 0) {
                    _changeDate(-1); // Swipe right = previous day
                  } else if (details.primaryVelocity! < 0) {
                    _changeDate(1); // Swipe left = next day
                  }
                }
              },
              child: DayViewWidget(
                date: _selectedDate,
                events: events,
                onEventTap: _showEventDetails,
                onTimeSlotTap: _createEventAtTime,
                onEventMove: _moveEvent,
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToAddEvent(),
        child: const Icon(Icons.add),
        tooltip: 'Tambah Event',
      ),
    );
  }

  void _navigateToAddEvent([DateTime? time]) {
    final eventTime =
        time ??
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder:
          (context) => DraggableScrollableSheet(
            expand: false,
            builder:
                (context, scrollController) => Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
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
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      _buildDetailRow(
                        Icons.access_time,
                        event.isAllDay
                            ? 'Sepanjang hari'
                            : '${AppDateUtils.formatTime(event.startTime)} - ${AppDateUtils.formatTime(event.endTime)}',
                      ),

                      if (event.location != null) ...[
                        const SizedBox(height: 8),
                        _buildDetailRow(Icons.location_on, event.location!),
                      ],

                      if (event.description != null) ...[
                        const SizedBox(height: 8),
                        _buildDetailRow(Icons.subject, event.description!),
                      ],

                      const SizedBox(height: 24),

                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (context) => AddEventPage(
                                          initialDate: event.startTime,
                                          existingEvent: event,
                                        ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.edit),
                              label: const Text('Edit'),
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
                              ),
                            ),
                          ),
                        ],
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
        Icon(icon, color: Colors.grey.shade600, size: 20),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 16))),
      ],
    );
  }

  void _createEventAtTime(DateTime time) {
    _navigateToAddEvent(time);
  }

  void _moveEvent(CalendarEvent event, DateTime newTime) {
    final duration = event.endTime.difference(event.startTime);
    final updatedEvent = event.copyWith(
      startTime: newTime,
      endTime: newTime.add(duration),
    );

    context.read<CalendarBloc>().add(calendar_events.UpdateEvent(updatedEvent));
  }

  void _deleteEvent(CalendarEvent event) {
    Navigator.pop(context); // Close bottom sheet

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
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
