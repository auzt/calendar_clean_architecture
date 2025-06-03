// lib/features/calendar/presentation/widgets/enhanced_date_picker_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/utils/date_utils.dart';
import '../../domain/entities/calendar_date_range.dart';
import '../bloc/calendar_bloc.dart';
import '../bloc/calendar_event.dart' as calendar_events;
import '../bloc/calendar_state.dart';
import 'month_view_widget.dart';

class EnhancedDatePickerWidget extends StatefulWidget {
  final DateTime initialDate;
  final String title;
  final bool showEvents;
  final Function(DateTime)? onDateSelected;
  final DateTime? minDate;
  final DateTime? maxDate;

  const EnhancedDatePickerWidget({
    super.key,
    required this.initialDate,
    required this.title,
    this.showEvents = true,
    this.onDateSelected,
    this.minDate,
    this.maxDate,
  });

  @override
  State<EnhancedDatePickerWidget> createState() =>
      _EnhancedDatePickerWidgetState();
}

class _EnhancedDatePickerWidgetState extends State<EnhancedDatePickerWidget> {
  late DateTime _selectedDate;
  late DateTime _currentMonth;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
    _currentMonth = DateTime(widget.initialDate.year, widget.initialDate.month);
    _pageController = PageController(initialPage: 1000);

    // Load events untuk bulan ini jika showEvents true
    if (widget.showEvents) {
      _loadEventsForMonth(_currentMonth);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _loadEventsForMonth(DateTime month) {
    if (!widget.showEvents) return;

    final startDate = AppDateUtils.getStartOfMonth(month);
    final endDate = AppDateUtils.getEndOfMonth(month);
    final dateRange = CalendarDateRange(startDate: startDate, endDate: endDate);

    context.read<CalendarBloc>().add(
          calendar_events.LoadCalendarEvents(
            dateRange: dateRange,
            forceRefresh: false,
          ),
        );
  }

  void _onMonthChanged(DateTime newMonth) {
    setState(() {
      _currentMonth = newMonth;
    });
    if (widget.showEvents) {
      _loadEventsForMonth(newMonth);
    }
  }

  void _onDateTap(DateTime date) {
    // Cek apakah tanggal dalam range yang diizinkan
    if (widget.minDate != null && date.isBefore(widget.minDate!)) {
      _showDateNotAllowedMessage(
          'Tanggal tidak boleh sebelum ${AppDateUtils.formatDisplayDate(widget.minDate!)}');
      return;
    }

    if (widget.maxDate != null && date.isAfter(widget.maxDate!)) {
      _showDateNotAllowedMessage(
          'Tanggal tidak boleh setelah ${AppDateUtils.formatDisplayDate(widget.maxDate!)}');
      return;
    }

    setState(() {
      _selectedDate = date;
    });

    // Callback untuk notifikasi pemilihan tanggal
    widget.onDateSelected?.call(date);
  }

  void _showDateNotAllowedMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _navigateToToday() {
    final today = DateTime.now();
    final todayMonth = DateTime(today.year, today.month);

    if (todayMonth != _currentMonth) {
      setState(() {
        _currentMonth = todayMonth;
      });
      _pageController.animateToPage(
        1000,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      if (widget.showEvents) {
        _loadEventsForMonth(todayMonth);
      }
    }

    // Set selected date ke hari ini jika diizinkan
    if ((widget.minDate == null || !today.isBefore(widget.minDate!)) &&
        (widget.maxDate == null || !today.isAfter(widget.maxDate!))) {
      setState(() {
        _selectedDate = today;
      });
      widget.onDateSelected?.call(today);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: double.maxFinite,
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Header
            _buildHeader(),
            const SizedBox(height: 16),

            // Month Navigation dan Info
            _buildMonthNavigation(),
            const SizedBox(height: 8),

            // Loading indicator untuk events
            if (widget.showEvents) _buildLoadingIndicator(),

            // Calendar Month View
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  final monthOffset = index - 1000;
                  final newMonth = DateTime(
                    DateTime.now().year,
                    DateTime.now().month + monthOffset,
                  );
                  _onMonthChanged(newMonth);
                },
                itemBuilder: (context, index) {
                  final monthOffset = index - 1000;
                  final month = DateTime(
                    DateTime.now().year,
                    DateTime.now().month + monthOffset,
                  );
                  return _buildMonthView(month);
                },
              ),
            ),

            const SizedBox(height: 16),

            // Selected Date Info
            _buildSelectedDateInfo(),
            const SizedBox(height: 16),

            // Action Buttons
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Icon(Icons.calendar_today, color: Colors.blue),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            widget.title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        IconButton(
          onPressed: _navigateToToday,
          icon: const Icon(Icons.today),
          tooltip: 'Hari Ini',
        ),
      ],
    );
  }

  Widget _buildMonthNavigation() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          onPressed: () {
            _pageController.previousPage(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          },
          icon: const Icon(Icons.chevron_left),
          tooltip: 'Bulan Sebelumnya',
        ),
        Expanded(
          child: Text(
            AppDateUtils.formatDisplayDate(_currentMonth).split(',')[1].trim(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        IconButton(
          onPressed: () {
            _pageController.nextPage(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          },
          icon: const Icon(Icons.chevron_right),
          tooltip: 'Bulan Selanjutnya',
        ),
      ],
    );
  }

  Widget _buildLoadingIndicator() {
    return BlocBuilder<CalendarBloc, CalendarState>(
      builder: (context, state) {
        if (state is CalendarLoading) {
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 8),
                Text(
                  'Memuat events...',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildMonthView(DateTime month) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: CustomMonthView(
        month: month,
        selectedDate: _selectedDate,
        onDateTap: _onDateTap,
        showEvents: widget.showEvents,
        minDate: widget.minDate,
        maxDate: widget.maxDate,
      ),
    );
  }

  Widget _buildSelectedDateInfo() {
    final isToday = AppDateUtils.isSameDay(_selectedDate, DateTime.now());

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          Icon(
            isToday ? Icons.today : Icons.calendar_today,
            color: Colors.blue,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tanggal Dipilih:',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                Text(
                  '${AppDateUtils.formatDisplayDate(_selectedDate)}${isToday ? ' (Hari Ini)' : ''}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context, _selectedDate),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Pilih'),
          ),
        ),
      ],
    );
  }
}

// Custom Month View khusus untuk date picker
class CustomMonthView extends StatelessWidget {
  final DateTime month;
  final DateTime selectedDate;
  final Function(DateTime) onDateTap;
  final bool showEvents;
  final DateTime? minDate;
  final DateTime? maxDate;

  const CustomMonthView({
    super.key,
    required this.month,
    required this.selectedDate,
    required this.onDateTap,
    this.showEvents = true,
    this.minDate,
    this.maxDate,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildWeekdayHeaders(),
        Expanded(
          child: _buildMonthGrid(context),
        ),
      ],
    );
  }

  Widget _buildWeekdayHeaders() {
    const weekdays = ['SEN', 'SEL', 'RAB', 'KAM', 'JUM', 'SAB', 'MIN'];
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: weekdays.map((day) {
          return Expanded(
            child: Text(
              day,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
                fontSize: 12,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMonthGrid(BuildContext context) {
    return showEvents
        ? BlocBuilder<CalendarBloc, CalendarState>(
            builder: (context, state) {
              return MonthViewWidget(
                month: month,
                onDateTap: (date) {
                  // Override date tap untuk date picker
                  onDateTap(date);
                },
              );
            },
          )
        : _buildSimpleMonthGrid();
  }

  Widget _buildSimpleMonthGrid() {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 1.2,
      ),
      itemCount: 42,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        final date = _getDateForIndex(index);
        final isCurrentMonth = AppDateUtils.isSameMonth(date, month);
        final isSelected = AppDateUtils.isSameDay(date, selectedDate);
        final isToday = AppDateUtils.isSameDay(date, DateTime.now());
        final isDisabled = _isDateDisabled(date);

        return GestureDetector(
          onTap: isDisabled ? null : () => onDateTap(date),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.blue
                  : isToday
                      ? Colors.blue.shade100
                      : Colors.transparent,
              border: Border.all(
                color: isSelected ? Colors.blue : Colors.grey.shade300,
                width: isSelected ? 2 : 0.5,
              ),
            ),
            child: Center(
              child: Text(
                '${date.day}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isSelected || isToday
                      ? FontWeight.bold
                      : FontWeight.normal,
                  color: isDisabled
                      ? Colors.grey.shade400
                      : isSelected
                          ? Colors.white
                          : isCurrentMonth
                              ? Colors.black87
                              : Colors.grey.shade500,
                ),
              ),
            ),
          ),
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

  bool _isDateDisabled(DateTime date) {
    if (minDate != null && date.isBefore(minDate!)) return true;
    if (maxDate != null && date.isAfter(maxDate!)) return true;
    return false;
  }
}
