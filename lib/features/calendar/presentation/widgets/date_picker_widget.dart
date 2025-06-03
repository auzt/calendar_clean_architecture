// lib/features/calendar/presentation/widgets/date_picker_widget.dart
// SIMPLE VERSION - Hanya MonthView asli + CANCEL/OK buttons

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/utils/date_utils.dart';
import '../../domain/entities/calendar_date_range.dart';
import '../bloc/calendar_bloc.dart';
import '../bloc/calendar_event.dart' as calendar_events;
import '../bloc/calendar_state.dart';
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
    // Cek apakah tanggal dalam range yang diizinkan
    if (widget.minDate != null && date.isBefore(widget.minDate!)) {
      return; // Silent fail untuk date yang tidak valid
    }

    if (widget.maxDate != null && date.isAfter(widget.maxDate!)) {
      return; // Silent fail untuk date yang tidak valid
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
      insetPadding:
          const EdgeInsets.all(16), // Kurangi padding untuk popup lebih besar
      child: Container(
        width: double.maxFinite,
        height: MediaQuery.of(context).size.height *
            0.85, // ✅ POPUP LEBIH TINGGI (85%)
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            // ✅ HEADER BULAN/TAHUN dengan navigation
            _buildMonthYearHeader(),

            // ✅ MONTH VIEW EXPANDED - Grid full ke bawah
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
                  return _buildPureMonthView(month);
                },
              ),
            ),

            // ✅ SIMPLE BUTTONS - CANCEL & OK
            _buildSimpleButtons(),
          ],
        ),
      ),
    );
  }

  // ✅ HEADER dengan bulan/tahun dan navigation
  Widget _buildMonthYearHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(8),
          topRight: Radius.circular(8),
        ),
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () {
              _pageController.previousPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            },
            icon: const Icon(Icons.chevron_left, size: 24),
            tooltip: 'Bulan Sebelumnya',
          ),
          Text(
            AppDateUtils.formatDisplayDate(_currentMonth).split(',')[1].trim(),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          IconButton(
            onPressed: () {
              _pageController.nextPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            },
            icon: const Icon(Icons.chevron_right, size: 24),
            tooltip: 'Bulan Selanjutnya',
          ),
        ],
      ),
    );
  }

  // ✅ MonthView MURNI tanpa modifikasi apapun
  Widget _buildPureMonthView(DateTime month) {
    return SimpleMonthViewWrapper(
      month: month,
      selectedDate: _selectedDate,
      onDateTap: _onDateTap,
      showEvents: widget.showEvents,
    );
  }

  Widget _buildSimpleButtons() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey.shade300),
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(8),
          bottomRight: Radius.circular(8),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              minimumSize: const Size(80, 40),
            ),
            child: const Text(
              'CANCEL',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(width: 16),
          TextButton(
            onPressed: () => Navigator.pop(context, _selectedDate),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              minimumSize: const Size(80, 40),
            ),
            child: const Text(
              'OK',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.blue,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ✅ WRAPPER sederhana untuk MonthViewWidget
class SimpleMonthViewWrapper extends StatelessWidget {
  final DateTime month;
  final DateTime selectedDate;
  final Function(DateTime) onDateTap;
  final bool showEvents;

  const SimpleMonthViewWrapper({
    super.key,
    required this.month,
    required this.selectedDate,
    required this.onDateTap,
    this.showEvents = true,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // ✅ MonthViewWidget ASLI 100% tanpa perubahan
        MonthViewWidget(
          month: month,
          onDateTap: onDateTap,
          onDateLongPress: null, // Disable long press
        ),

        // ✅ Selection indicator yang sangat minimal
        _buildVeryMinimalSelection(),
      ],
    );
  }

  Widget _buildVeryMinimalSelection() {
    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(
          painter: VeryMinimalSelectionPainter(
            month: month,
            selectedDate: selectedDate,
          ),
        ),
      ),
    );
  }
}

// ✅ PAINTER yang sangat minimal untuk selected date
class VeryMinimalSelectionPainter extends CustomPainter {
  final DateTime month;
  final DateTime selectedDate;

  VeryMinimalSelectionPainter({
    required this.month,
    required this.selectedDate,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Cari posisi tanggal yang dipilih
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

    // ✅ Kalkulasi posisi grid yang tepat - sesuai dengan MonthViewWidget
    final headerHeight = size.height * 0.08; // Header weekdays yang lebih kecil
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

    // ✅ Highlight background biru transparan
    final highlightPaint = Paint()
      ..color = Colors.blue.withOpacity(0.15)
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        cellRect.deflate(3),
        const Radius.circular(6),
      ),
      highlightPaint,
    );

    // ✅ Border biru solid seperti di screenshot
    final borderPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        cellRect.deflate(3),
        const Radius.circular(6),
      ),
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
