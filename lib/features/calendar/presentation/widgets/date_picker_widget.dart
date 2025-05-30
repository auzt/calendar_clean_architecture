// lib/features/calendar/presentation/widgets/date_picker_widget.dart
import 'package:flutter/material.dart';
import '../../../../core/utils/date_utils.dart';

class DatePickerWidget extends StatefulWidget {
  final DateTime initialDate;
  final String title;

  const DatePickerWidget({
    super.key,
    required this.initialDate,
    this.title = 'Pilih Tanggal',
  });

  @override
  State<DatePickerWidget> createState() => _DatePickerWidgetState();
}

class _DatePickerWidgetState extends State<DatePickerWidget> {
  late DateTime _selectedDate;
  late DateTime _focusedMonth;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
    _focusedMonth = DateTime(
      widget.initialDate.year,
      widget.initialDate.month,
      1,
    );
    _pageController = PageController(initialPage: 1000);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
                Expanded(
                  child: Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, _selectedDate),
                  child: const Text('PILIH'),
                ),
              ],
            ),

            // Month navigation
            Row(
              children: [
                IconButton(
                  onPressed: () => _changeMonth(-1),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    AppDateUtils.formatDisplayDate(
                      _focusedMonth,
                    ).split(',')[1].trim(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => _changeMonth(1),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),

            // Calendar
            Expanded(child: _buildMonthView()),

            // Today button
            TextButton(
              onPressed: () {
                setState(() {
                  _selectedDate = DateTime.now();
                  _focusedMonth = DateTime(
                    DateTime.now().year,
                    DateTime.now().month,
                    1,
                  );
                });
              },
              child: const Text('Hari Ini'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthView() {
    return Column(
      children: [
        // Weekday headers
        Row(
          children:
              ['Min', 'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab'].map((day) {
                return Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      day,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                );
              }).toList(),
        ),

        // Calendar grid
        Expanded(child: _buildCalendarGrid()),
      ],
    );
  }

  Widget _buildCalendarGrid() {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 1.0,
      ),
      itemCount: 42, // 6 weeks * 7 days
      itemBuilder: (context, index) {
        final date = _getDateForIndex(index);
        final isCurrentMonth = date.month == _focusedMonth.month;
        final isSelected = AppDateUtils.isSameDay(date, _selectedDate);
        final isToday = AppDateUtils.isSameDay(date, DateTime.now());

        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedDate = date;
            });
          },
          child: Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color:
                  isSelected
                      ? Colors.blue
                      : isToday
                      ? Colors.blue.shade100
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
              border:
                  isToday && !isSelected
                      ? Border.all(color: Colors.blue, width: 1)
                      : null,
            ),
            child: Center(
              child: Text(
                '${date.day}',
                style: TextStyle(
                  color:
                      isSelected
                          ? Colors.white
                          : isCurrentMonth
                          ? isToday
                              ? Colors.blue
                              : Colors.black87
                          : Colors.grey.shade400,
                  fontWeight:
                      isSelected || isToday
                          ? FontWeight.bold
                          : FontWeight.normal,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  DateTime _getDateForIndex(int index) {
    final firstDayOfMonth = _focusedMonth;
    final weekdayOfFirst = firstDayOfMonth.weekday % 7; // 0 = Sunday
    final startDate = firstDayOfMonth.subtract(Duration(days: weekdayOfFirst));
    return startDate.add(Duration(days: index));
  }

  void _changeMonth(int monthOffset) {
    setState(() {
      _focusedMonth = DateTime(
        _focusedMonth.year,
        _focusedMonth.month + monthOffset,
        1,
      );
    });
  }
}
