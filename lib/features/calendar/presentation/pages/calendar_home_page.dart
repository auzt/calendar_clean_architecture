// lib/features/calendar/presentation/pages/day_view_page.dart
import 'package:flutter/material.dart';
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

  // Untuk undo functionality
  CalendarEvent? _lastMovedEvent;
  DateTime? _originalStartTime;
  DateTime? _originalEndTime;
  bool _hasUndoData = false;

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
      // Reset saved scroll position ketika ganti hari (bukan untuk drag)
      _savedScrollPosition = null;
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
                  // Reset saved scroll position ketika ke today
                  _savedScrollPosition = null;
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
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'help':
                  _showHelpDialog();
                  break;
                case 'refresh':
                  // Reset saved scroll position saat manual refresh
                  _savedScrollPosition = null;
                  _loadEventsForDate(_selectedDate);
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'refresh',
                child: ListTile(
                  leading: Icon(Icons.refresh),
                  title: Text('Refresh'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'help',
                child: ListTile(
                  leading: Icon(Icons.help_outline),
                  title: Text('Bantuan'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
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
          } else if (state is EventUpdated) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${state.event.title} berhasil dipindah'),
                backgroundColor: Colors.green,
                action: SnackBarAction(
                  label: 'BATALKAN',
                  textColor: Colors.white,
                  onPressed: () => _undoMoveEvent(),
                ),
                duration: const Duration(seconds: 5),
              ),
            );

            // Minimal delay refresh untuk memastikan state update
            Future.delayed(const Duration(milliseconds: 100), () {
              if (mounted) {
                _loadEventsForDate(_selectedDate);
              }
            });
          } else if (state is EventCreated) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${state.event.title} berhasil dibuat'),
                backgroundColor: Colors.green,
              ),
            );

            // Refresh tampilan setelah create
            Future.delayed(const Duration(milliseconds: 100), () {
              if (mounted) {
                _loadEventsForDate(_selectedDate);
              }
            });
          }
        },
        child: GestureDetector(
          onHorizontalDragEnd: (details) {
            if (details.primaryVelocity != null) {
              if (details.primaryVelocity! > 0) {
                _changeDate(-1); // Swipe right = previous day
              } else if (details.primaryVelocity! < 0) {
                _changeDate(1); // Swipe left = next day
              }
            }
          },
          child: BlocBuilder<CalendarBloc, CalendarState>(
            builder: (context, state) {
              if (state is CalendarLoading) {
                return const Center(child: CircularProgressIndicator());
              }

              List<CalendarEvent> events = [];
              if (state is CalendarLoaded) {
                events = state.events.where((event) {
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
              }

              return DayViewWidget(
                date: _selectedDate,
                events: events,
                onEventTap: _showEventDetails,
                onTimeSlotTap: _createEventAtTime,
                onEventMove: _moveEvent,
                // Pass callback untuk save scroll position
                onScrollPositionChanged: (position) {
                  _savedScrollPosition = position;
                },
                // Pass saved scroll position
                initialScrollPosition: _savedScrollPosition,
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

  void _navigateToAddEvent([DateTime? time]) {
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle indicator
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Event title dengan color indicator
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

              // Event details
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

              if (event.isFromGoogle) ...[
                const SizedBox(height: 8),
                _buildDetailRow(
                  Icons.cloud,
                  'Disinkronkan dengan Google Calendar',
                ),
              ],

              const SizedBox(height: 24),

              // Help text for drag & drop with AUTO-SCROLL
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline,
                            color: Colors.blue.shade700, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          '✨ Tips: Drag & Drop dengan Auto-Scroll',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• Long press event lalu drag untuk memindah\n'
                      '• 🆕 AUTO-SCROLL: Drag ke tepi atas/bawah layar untuk scroll otomatis!\n'
                      '• Bisa drop ke SEMUA jam (0-24) meski tidak terlihat\n'
                      '• Preview waktu akurat muncul saat drag\n'
                      '• Precision 5 menit (snap ke 10:00, 10:05, dst)\n'
                      '• Events yang overlap akan otomatis tersusun\n'
                      '• Tombol "BATALKAN" untuk undo (5 detik)',
                      style: TextStyle(
                        color: Colors.blue.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Action buttons
              Row(
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

  // Simplified moveEvent method
  void _moveEvent(CalendarEvent event, DateTime newTime) {
    // Simpan data undo SEBELUM update
    _lastMovedEvent = CalendarEvent(
      id: event.id,
      title: event.title,
      description: event.description,
      startTime: event.startTime, // Original time
      endTime: event.endTime, // Original time
      location: event.location,
      isAllDay: event.isAllDay,
      color: event.color,
      googleEventId: event.googleEventId,
      attendees: event.attendees,
      recurrence: event.recurrence,
      isFromGoogle: event.isFromGoogle,
      lastModified: event.lastModified,
      createdBy: event.createdBy,
      additionalData: event.additionalData,
    );

    _originalStartTime = event.startTime;
    _originalEndTime = event.endTime;
    _hasUndoData = true;

    print('🔄 Saving undo data:');
    print('   Original: ${_originalStartTime} - ${_originalEndTime}');
    print('   Event ID: ${_lastMovedEvent?.id}');

    // Calculate new end time maintaining duration
    final duration = event.endTime.difference(event.startTime);
    final updatedEvent = event.copyWith(
      startTime: newTime,
      endTime: newTime.add(duration),
      lastModified: DateTime.now(),
    );

    print('   New: ${updatedEvent.startTime} - ${updatedEvent.endTime}');

    // Update via bloc
    context.read<CalendarBloc>().add(
          calendar_events.UpdateEvent(updatedEvent),
        );
  }

  // Simplified undo method
  void _undoMoveEvent() {
    print('🔙 Attempting undo...');

    if (!_hasUndoData ||
        _lastMovedEvent == null ||
        _originalStartTime == null ||
        _originalEndTime == null) {
      print('❌ No undo data available');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tidak ada data untuk dibatalkan'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    print('✅ Restoring event to original position');
    print('   Event: ${_lastMovedEvent!.title}');
    print('   Original: ${_originalStartTime} - ${_originalEndTime}');

    // Create event with original times
    final originalEvent = _lastMovedEvent!.copyWith(
      startTime: _originalStartTime!,
      endTime: _originalEndTime!,
      lastModified: DateTime.now(),
    );

    // Update via bloc
    context.read<CalendarBloc>().add(
          calendar_events.UpdateEvent(originalEvent),
        );

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text('${_lastMovedEvent!.title} dikembalikan ke posisi semula'),
        backgroundColor: Colors.orange,
      ),
    );

    // Clear undo data
    _clearUndoData();
  }

  // Helper method untuk clear undo data
  void _clearUndoData() {
    setState(() {
      _lastMovedEvent = null;
      _originalStartTime = null;
      _originalEndTime = null;
      _hasUndoData = false;
    });
    print('🧹 Undo data cleared');
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

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.help_outline, color: Colors.blue),
            SizedBox(width: 8),
            Text('Panduan Day View'),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '📅 Navigasi:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('• Swipe kiri/kanan untuk ganti hari'),
              Text('• Gunakan tombol ← hari ini → di AppBar'),
              SizedBox(height: 12),
              Text(
                '➕ Menambah Event:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('• Tap area kosong di kalender'),
              Text('• Atau gunakan tombol + di kanan bawah'),
              SizedBox(height: 12),
              Text(
                '✨ Drag & Drop Event dengan AUTO-SCROLL:',
                style:
                    TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
              ),
              Text('• Long press event lalu drag ke waktu yang diinginkan'),
              Text(
                  '• 🆕 FITUR BARU: Drag ke tepi atas layar = scroll otomatis ke atas'),
              Text(
                  '• 🆕 FITUR BARU: Drag ke tepi bawah layar = scroll otomatis ke bawah'),
              Text('• Auto-scroll berhenti saat drop atau drag keluar area'),
              Text('• Bisa drop ke jam manapun (0-24) dengan auto-scroll'),
              Text('• Preview waktu akurat muncul saat drag'),
              Text('• Precision 5 menit (snap ke 10:00, 10:05, dst)'),
              Text('• Events yang overlap akan otomatis tersusun'),
              Text('• Tombol "BATALKAN" untuk undo (5 detik)'),
              SizedBox(height: 12),
              Text(
                '⚙️ Fitur Lainnya:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('• Tap event untuk lihat detail/edit/hapus'),
              Text('• Scroll vertikal manual untuk lihat jam lain'),
              Text('• Garis merah = waktu sekarang (hari ini)'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Mengerti'),
          ),
        ],
      ),
    );
  }
}
