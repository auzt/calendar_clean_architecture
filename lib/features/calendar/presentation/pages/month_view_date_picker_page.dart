// lib/features/calendar/presentation/pages/month_view_date_picker_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../core/utils/date_utils.dart'
    as app_date_utils; // Menggunakan alias
import '../widgets/month_view_widget.dart';
import '../bloc/calendar_bloc.dart';
import '../bloc/calendar_event.dart' as cal_event;
import '../../domain/entities/calendar_date_range.dart';

class MonthViewDatePickerPage extends StatefulWidget {
  final DateTime initialDate;
  final DateTime currentDisplayMonth;

  const MonthViewDatePickerPage({
    super.key,
    required this.initialDate,
    required this.currentDisplayMonth,
  });

  @override
  State<MonthViewDatePickerPage> createState() =>
      _MonthViewDatePickerPageState();
}

class _MonthViewDatePickerPageState extends State<MonthViewDatePickerPage> {
  late DateTime _selectedDate;
  late DateTime _displayMonth;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
    _displayMonth = DateTime(
        widget.currentDisplayMonth.year, widget.currentDisplayMonth.month, 1);
    _loadEventsForMonth(_displayMonth);
  }

  void _loadEventsForMonth(DateTime month) {
    final startDate = app_date_utils.AppDateUtils.getStartOfMonth(month);
    final endDate = app_date_utils.AppDateUtils.getEndOfMonth(month);
    final dateRange = CalendarDateRange(startDate: startDate, endDate: endDate);
    context.read<CalendarBloc>().add(
          cal_event.LoadCalendarEvents(dateRange: dateRange),
        );
  }

  void _onDateTapped(DateTime date) {
    Navigator.pop(context, date);
  }

  void _changeMonth(int monthOffset) {
    setState(() {
      _displayMonth =
          DateTime(_displayMonth.year, _displayMonth.month + monthOffset, 1);
    });
    _loadEventsForMonth(_displayMonth);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(DateFormat('MMMM yyyy', 'id_ID').format(_displayMonth)),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => _changeMonth(-1),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => _changeMonth(1),
          ),
        ],
      ),
      body: MonthViewWidget(
        month: _displayMonth,
        onDateTap: _onDateTapped,
        // onDateLongPress tidak diperlukan untuk picker, bisa dikosongkan atau null
        onDateLongPress: (date) {
          // Aksi long press bisa di-handle jika diperlukan, misal langsung pilih tanggal
          _onDateTapped(date);
        },
      ),
    );
  }
}
