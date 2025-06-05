// lib/features/calendar/presentation/widgets/date_picker_widget.dart
// FIXED VERSION - Overlay GestureDetector di atas MonthViewWidget untuk auto-close

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

  // ✅ Calculate which date was tapped based on position
  DateTime? _getDateFromPosition(Offset localPosition, Size size) {
    try {
      // MonthViewWidget structure:
      // - Weekday headers (height: ~40px)
      // - Grid 6x7 (remaining height)

      const weekdayHeaderHeight = 40.0; // Approximate header height

      // Check if tap is in grid area (not header)
      if (localPosition.dy <= weekdayHeaderHeight) return null;

      // Calculate grid position
      final gridY = localPosition.dy - weekdayHeaderHeight;
      final gridHeight = size.height - weekdayHeaderHeight;

      final cellWidth = size.width / 7;
      final cellHeight = gridHeight / 6;

      final col = (localPosition.dx / cellWidth).floor();
      final row = (gridY / cellHeight).floor();

      // Validate bounds
      if (col < 0 || col >= 7 || row < 0 || row >= 6) return null;

      // Calculate date index (0-41)
      final index = row * 7 + col;

      // Calculate actual date
      final firstDayOfMonth =
          DateTime(_currentMonth.year, _currentMonth.month, 1);
      final firstWeekdayOffset = (firstDayOfMonth.weekday + 6) % 7;
      final startDate =
          firstDayOfMonth.subtract(Duration(days: firstWeekdayOffset));
      final selectedDate = startDate.add(Duration(days: index));

      print(
          '🎯 Tap at: ${localPosition.dx.toInt()}, ${localPosition.dy.toInt()}');
      print('📱 Grid: col=$col, row=$row, index=$index');
      print('📅 Date: ${selectedDate.day}/${selectedDate.month}');

      return selectedDate;
    } catch (e) {
      print('❌ Error calculating date from position: $e');
      return null;
    }
  }

  void _onDateTap(DateTime date) {
    // ✅ Validasi tidak bisa pilih tanggal sebelum hari ini
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final selectedStart = DateTime(date.year, date.month, date.day);

    if (selectedStart.isBefore(todayStart)) {
      return; // Jangan lakukan apa-apa jika tanggal sebelum hari ini
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

    // ✅ LANGSUNG TUTUP DIALOG SAAT PILIH TANGGAL
    Navigator.pop(context, date);
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

            // ✅ MonthViewWidget dengan overlay GestureDetector
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
                    return _buildMonthViewWithOverlay(month);
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

  Widget _buildMonthViewWithOverlay(DateTime month) {
    return Stack(
      children: [
        // ✅ MonthViewWidget ASLI (tampilan sama persis)
        MonthViewWidget(
          month: month,
          onDateTap: (_) {}, // Empty callback - akan di-override oleh overlay
          onDateLongPress: null,
        ),

        // ✅ Transparent overlay untuk intercept taps
        Positioned.fill(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return GestureDetector(
                behavior:
                    HitTestBehavior.translucent, // Penting untuk detect taps
                onTapDown: (details) {
                  // Calculate which date was tapped using LayoutBuilder size
                  final date = _getDateFromPosition(
                      details.localPosition, constraints.biggest);
                  if (date != null) {
                    print(
                        '🎯 Tapped date: ${date.day}/${date.month}/${date.year}');
                    _onDateTap(date);
                  } else {
                    print('❌ No valid date found for tap position');
                  }
                },
                child: Container(
                  color: Colors.transparent, // Transparent overlay
                  width: double.infinity,
                  height: double.infinity,
                ),
              );
            },
          ),
        ),

        // ✅ Selection overlay untuk highlight tanggal terpilih
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

    // ✅ Use same calculation as tap detection
    const weekdayHeaderHeight = 40.0;
    final gridHeight = size.height - weekdayHeaderHeight;
    final cellWidth = size.width / 7;
    final cellHeight = gridHeight / 6;

    final row = selectedIndex ~/ 7;
    final col = selectedIndex % 7;

    final cellRect = Rect.fromLTWH(
      col * cellWidth,
      weekdayHeaderHeight + row * cellHeight,
      cellWidth,
      cellHeight,
    );

    // ✅ Background kuning muda untuk selected tapi lebih transparan
    final highlightPaint = Paint()
      ..color = const Color(0xFFFFF9C4).withOpacity(0.7)
      ..style = PaintingStyle.fill;

    canvas.drawRect(cellRect, highlightPaint);

    // ✅ Border biru muda tapi lebih tipis
    final borderPaint = Paint()
      ..color = const Color(0xFF4FC3F7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawRect(
      cellRect.deflate(0.5), // ✅ Deflate lebih kecil untuk border yang pas
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
