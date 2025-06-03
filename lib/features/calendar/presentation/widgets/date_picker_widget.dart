// lib/features/calendar/presentation/widgets/date_picker_widget.dart
// MENGGUNAKAN MonthViewWidget ASLI dengan parameter untuk disable popup

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/utils/date_utils.dart';
import '../../domain/entities/calendar_date_range.dart';
import '../bloc/calendar_bloc.dart';
import '../bloc/calendar_event.dart' as calendar_events;
import 'month_view_widget.dart';

class DatePickerWidget extends StatefulWidget {
  final DateTime initialDate;
  final String title;
  final bool showEvents;
  final Function(DateTime)? onDateSelected;
  final DateTime? minDate;
  final DateTime? maxDate;

  const DatePickerWidget({
    super.key,
    required this.initialDate,
    required this.title,
    this.showEvents = true,
    this.onDateSelected,
    this.minDate,
    this.maxDate,
  });

  @override
  State<DatePickerWidget> createState() => _DatePickerWidgetState();
}

class _DatePickerWidgetState extends State<DatePickerWidget> {
  late DateTime _selectedDate;
  late DateTime _currentMonth;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
    _currentMonth = DateTime(widget.initialDate.year, widget.initialDate.month);
    _pageController = PageController(initialPage: 1000);

    // Load events untuk bulan ini
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
    // ✅ Validasi tidak bisa pilih tanggal sebelum hari ini
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final selectedStart = DateTime(date.year, date.month, date.day);

    if (selectedStart.isBefore(todayStart)) {
      // Jangan lakukan apa-apa jika tanggal sebelum hari ini
      return;
    }

    // Cek apakah tanggal dalam range yang diizinkan
    if (widget.minDate != null && date.isBefore(widget.minDate!)) {
      return;
    }

    if (widget.maxDate != null && date.isAfter(widget.maxDate!)) {
      return;
    }

    setState(() {
      _selectedDate = date;
    });

    // Callback untuk notifikasi pemilihan tanggal
    widget.onDateSelected?.call(date);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      backgroundColor: Colors.transparent,
      child: Container(
        width: double.maxFinite,
        height: MediaQuery.of(context).size.height - 20,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            // ✅ HEADER sederhana - hanya nama bulan tahun
            _buildCleanHeader(),

            // ✅ MonthViewWidget ASLI dengan parameter untuk disable popup
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
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
                    return _buildMonthViewWithSelection(month);
                  },
                ),
              ),
            ),

            // ✅ BOTTOM BUTTONS rapat
            _buildCleanButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildCleanHeader() {
    final monthYear =
        "${_getMonthName(_currentMonth.month)} ${_currentMonth.year}";

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFB8E6E6),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Center(
        child: Text(
          monthYear,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _buildMonthViewWithSelection(DateTime month) {
    return Stack(
      children: [
        // ✅ MonthViewWidget ASLI dengan parameter showEventPreview: false
        MonthViewWidget(
          month: month,
          onDateTap: _onDateTap,
          onDateLongPress: null, // Disable long press
          showEventPreview:
              false, // ✅ PARAMETER BARU untuk disable popup preview
        ),

        // ✅ Selection overlay
        _buildSelectionOverlay(),
      ],
    );
  }

  Widget _buildSelectionOverlay() {
    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(
          painter: CleanSelectionPainter(
            month: _currentMonth,
            selectedDate: _selectedDate,
          ),
        ),
      ),
    );
  }

  Widget _buildCleanButtons() {
    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 20, bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              minimumSize: const Size(70, 28),
            ),
            child: const Text(
              'CANCEL',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black54,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(width: 12),
          TextButton(
            onPressed: () => Navigator.pop(context, _selectedDate),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              minimumSize: const Size(70, 28),
            ),
            child: const Text(
              'OK',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black54,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getMonthName(int month) {
    const months = [
      '',
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return months[month];
  }
}

// ✅ SELECTION PAINTER untuk highlight tanggal yang dipilih
class CleanSelectionPainter extends CustomPainter {
  final DateTime month;
  final DateTime selectedDate;

  const CleanSelectionPainter({
    required this.month,
    required this.selectedDate,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final firstDayOfMonth = DateTime(month.year, month.month, 1);
    final firstWeekdayOffset = (firstDayOfMonth.weekday + 6) % 7;
    final startDate =
        firstDayOfMonth.subtract(Duration(days: firstWeekdayOffset));

    int? selectedIndex;
    for (int i = 0; i < 42; i++) {
      final date = startDate.add(Duration(days: i));
      if (AppDateUtils.isSameDay(date, selectedDate)) {
        selectedIndex = i;
        break;
      }
    }

    if (selectedIndex == null) return;

    final headerHeight = size.height * 0.08;
    final gridHeight = size.height - headerHeight;
    final cellWidth = size.width / 7;
    final cellHeight = gridHeight / 6;

    final row = selectedIndex ~/ 7;
    final col = selectedIndex % 7;

    final cellRect = Rect.fromLTWH(
      col * cellWidth,
      headerHeight + row * cellHeight,
      cellWidth,
      cellHeight,
    );

    // ✅ Background kuning muda untuk selected
    final highlightPaint = Paint()
      ..color = const Color(0xFFFFF9C4)
      ..style = PaintingStyle.fill;

    canvas.drawRect(cellRect, highlightPaint);

    // ✅ Border biru muda
    final borderPaint = Paint()
      ..color = const Color(0xFF4FC3F7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawRect(
      cellRect.deflate(1),
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
