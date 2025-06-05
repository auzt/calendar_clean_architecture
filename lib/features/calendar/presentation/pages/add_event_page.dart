// lib/features/calendar/presentation/pages/add_event_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart'; // <-- PASTIKAN IMPORT INI ADA
import 'package:uuid/uuid.dart';

import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/validators.dart';
import '../../domain/entities/calendar_event.dart';
import '../bloc/calendar_bloc.dart';
import '../bloc/calendar_event.dart' as calendar_events_bloc; // Aliased
import '../bloc/calendar_state.dart';
import '../widgets/date_picker_widget.dart'; // Asumsikan path ini benar

class AddEventPage extends StatefulWidget {
  final DateTime initialDate;
  final CalendarEvent? existingEvent;

  const AddEventPage(
      {super.key, required this.initialDate, this.existingEvent});

  @override
  State<AddEventPage> createState() => _AddEventPageState();
}

class _AddEventPageState extends State<AddEventPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();

  late DateTime _startDate;
  late TimeOfDay _startTime;
  late DateTime _endDate;
  late TimeOfDay _endTime;
  bool _isAllDay = false;
  Color _selectedColor = Colors.blue; // Warna default awal
  String _selectedEventType = 'Event';
  String _repeatOption = 'Tidak berulang';
  List<String> _notifications = ['30 menit sebelum'];

  final List<String> _eventTypes = ['Event', 'Task', 'Birthday'];
  final List<String> _repeatOptions = [
    'Tidak berulang',
    'Harian',
    'Mingguan',
    'Bulanan',
    'Tahunan',
  ];

  final List<Map<String, dynamic>> _colorOptions = [
    {'name': 'Biru', 'color': Colors.blue},
    {'name': 'Hijau', 'color': Colors.green},
    {'name': 'Merah', 'color': Colors.red},
    {'name': 'Oranye', 'color': Colors.orange},
    {'name': 'Ungu', 'color': Colors.purple},
    {'name': 'Teal', 'color': Colors.teal},
    {'name': 'Pink', 'color': Colors.pink},
    {'name': 'Indigo', 'color': Colors.indigo},
  ];

  bool get _isEditing => widget.existingEvent != null;

  @override
  void initState() {
    super.initState();
    _initializeForm();
  }

  void _initializeForm() {
    if (_isEditing) {
      final event = widget.existingEvent!;
      _titleController.text = event.title;
      _descriptionController.text = event.description ?? '';
      _locationController.text = event.location ?? '';
      _startDate = DateTime(
        event.startTime.year,
        event.startTime.month,
        event.startTime.day,
      );
      _startTime = TimeOfDay.fromDateTime(event.startTime);
      _endDate = DateTime(
        event.endTime.year,
        event.endTime.month,
        event.endTime.day,
      );
      _endTime = TimeOfDay.fromDateTime(event.endTime);
      _isAllDay = event.isAllDay;
      _selectedColor = event.color;
      _notifications = List<String>.from(event.attendees);
      _repeatOption = event.recurrence ?? 'Tidak berulang';
      // Anda mungkin perlu memuat _selectedEventType dari event jika disimpan
    } else {
      _startDate = DateTime(
        widget.initialDate.year,
        widget.initialDate.month,
        widget.initialDate.day,
      );
      _startTime = TimeOfDay.fromDateTime(widget.initialDate);
      _endDate = _startDate;
      _endTime = TimeOfDay(
        hour: (_startTime.hour + 1) % 24,
        minute: _startTime.minute,
      );
      // Set default saat membuat event baru berdasarkan _selectedEventType awal
      if (_selectedEventType == 'Birthday') {
        _isAllDay = true;
        _repeatOption = 'Tahunan';
        _selectedColor = Colors.green;
        _notifications = ['1 minggu sebelum', 'Hari ini'];
      } else if (_selectedEventType == 'Task') {
        _isAllDay = false; // Atau biarkan state _isAllDay sebelumnya
        _repeatOption = 'Tidak berulang';
        _selectedColor = Colors.orange;
        _notifications = ['30 menit sebelum'];
      } else {
        // Event
        _isAllDay = false; // Atau biarkan state _isAllDay sebelumnya
        _selectedColor = Colors.blue;
        _notifications = ['30 menit sebelum'];
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Event' : 'Tambah Event'),
        // Biarkan AppBar default dari kode Anda jika itu preferensi
        // atau gunakan _selectedColor jika ingin dinamis:
        // backgroundColor: _selectedColor,
        // iconTheme: IconThemeData(color: Colors.white),
        // titleTextStyle: TextStyle(color: Colors.white),
        backgroundColor:
            const Color.fromARGB(255, 89, 6, 223), // Sesuai kode asli Anda
        elevation: 1,
        actions: [
          BlocListener<CalendarBloc, CalendarState>(
            listener: (context, state) {
              // Logika listener tetap sama
              if (state is EventCreated || state is EventUpdated) {
                // Pop loading dialog jika ada
                if (Navigator.of(context, rootNavigator: true).canPop()) {
                  // Anda mungkin perlu cara lebih baik untuk cek apakah ini dialog loading
                  // Untuk sekarang, kita pop saja jika bisa.
                  Navigator.of(context, rootNavigator: true).pop();
                }
                Navigator.pop(context); // Pop AddEventPage
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(_isEditing
                        ? 'Event berhasil diupdate'
                        : 'Event berhasil dibuat'),
                    backgroundColor: Colors.green,
                  ),
                );
              } else if (state is CalendarError) {
                if (Navigator.of(context, rootNavigator: true).canPop()) {
                  Navigator.of(context, rootNavigator: true).pop();
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(state.message),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: ElevatedButton(
                onPressed: _saveEvent,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue, // Sesuai kode asli Anda
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text('Simpan'),
              ),
            ),
          ),
        ],
      ),
      body: BlocBuilder<CalendarBloc, CalendarState>(
        builder: (context, state) {
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
                horizontal: 16.0, vertical: 8.0), // Padding utama
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTitleSection(),
                  const SizedBox(height: 20),
                  _buildEventTypeSelection(),
                  const SizedBox(height: 20), // Mengurangi spasi
                  _buildDateTimeSection(), // Bagian yang diubah tampilannya
                  // Garis pemisah antar section utama
                  const Divider(height: 20, thickness: 0.5),
                  _buildLocationSection(),
                  const Divider(height: 20, thickness: 0.5),
                  _buildDescriptionSection(),
                  const Divider(height: 20, thickness: 0.5),
                  _buildOptionsSection(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTitleSection() {
    // Menggunakan versi dari kode asli Anda
    return Row(
      children: [
        Icon(
          _selectedEventType == 'Birthday'
              ? Icons.cake_outlined // Menggunakan ikon outline
              : _selectedEventType == 'Task'
                  ? Icons.check_circle_outline
                  : Icons.event_outlined, // Menggunakan ikon outline
          color: Colors.grey[700], // Warna ikon disesuaikan
          size: 24,
        ),
        const SizedBox(width: 16), // Jarak disesuaikan
        Expanded(
          child: TextFormField(
            controller: _titleController,
            style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.normal), // Font sedikit lebih besar
            decoration: InputDecoration(
              hintText: _selectedEventType == 'Birthday'
                  ? 'Nama ulang tahun'
                  : _selectedEventType == 'Task'
                      ? 'Judul task'
                      : 'Judul event',
              hintStyle: TextStyle(color: Colors.grey[500], fontSize: 22),
              border: InputBorder.none, // Tanpa border
            ),
            validator: Validators.validateTitle,
          ),
        ),
      ],
    );
  }

  Widget _buildEventTypeSelection() {
    // Menggunakan versi dari kode asli Anda
    return Row(
      children: _eventTypes.map((type) {
        final isSelected = _selectedEventType == type;
        return Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: ChoiceChip(
            label: Text(type),
            selected: isSelected,
            onSelected: (selected) {
              if (selected) {
                setState(() {
                  _selectedEventType = type;
                  if (type == 'Birthday') {
                    _isAllDay = true;
                    _repeatOption = 'Tahunan';
                    _selectedColor = Colors.green;
                    _notifications = ['1 minggu sebelum', 'Hari ini'];
                  } else if (type == 'Task') {
                    _isAllDay = false;
                    _repeatOption = 'Tidak berulang';
                    _selectedColor = Colors.orange;
                    _notifications = ['30 menit sebelum'];
                  } else {
                    // Event
                    _isAllDay = false;
                    _selectedColor = Colors.blue;
                    _notifications = ['30 menit sebelum'];
                  }
                });
              }
            },
            selectedColor:
                _selectedColor.withOpacity(0.15), // Warna lebih lembut
            backgroundColor: Colors.grey[100],
            labelStyle: TextStyle(
              color: isSelected ? _selectedColor : Colors.grey[700],
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
            shape: RoundedRectangleBorder(
                // Bentuk chip lebih modern
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(
                  color: isSelected
                      ? _selectedColor.withOpacity(0.5)
                      : Colors.grey.shade300,
                  width: 1,
                )),
          ),
        );
      }).toList(),
    );
  }

  // --- BAGIAN YANG DIMODIFIKASI UNTUK TAMPILAN TANGGAL BARU ---
  Widget _buildOptionRow({
    required dynamic icon,
    required String title,
    Widget? trailing,
    VoidCallback? onTap,
    TextStyle? textStyle, // textStyle opsional
  }) {
    Widget iconWidget;
    if (icon is IconData) {
      iconWidget = Icon(icon, color: Colors.grey[700], size: 22);
    } else if (icon is Widget) {
      iconWidget =
          icon; // Jika icon sudah berupa Widget (misal Container warna)
    } else {
      iconWidget = const SizedBox(width: 22); // Fallback
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              vertical: 14.0), // Padding vertikal untuk setiap baris
          child: Row(
            children: [
              SizedBox(
                width: 24, // Area untuk ikon
                height: 24,
                child: Align(alignment: Alignment.center, child: iconWidget),
              ),
              const SizedBox(width: 20), // Jarak ikon ke teks
              Expanded(
                child: Text(
                  title,
                  style: textStyle ??
                      const TextStyle(fontSize: 16, color: Colors.black87),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (trailing != null)
                trailing
              else if (onTap != null) // Default trailing jika bisa di-tap
                Icon(Icons.chevron_right,
                    size: 22, color: Colors.grey.shade500),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateTimeSection() {
    return Column(
      children: [
        _buildOptionRow(
          icon: Icons.access_time_outlined,
          title: 'Sepanjang hari',
          trailing: Switch(
            value: _isAllDay,
            onChanged: (value) {
              setState(() {
                _isAllDay = value;
              });
            },
            activeColor: _selectedColor,
          ),
        ),
        _buildDateTimeRow('Mulai', _startDate, _startTime, true),
        AnimatedCrossFade(
          firstChild: _buildDateTimeRow('Selesai', _endDate, _endTime, false),
          secondChild: const SizedBox.shrink(),
          crossFadeState: _isAllDay && _selectedEventType == 'Birthday'
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
        // Garis pemisah tipis sebelum pengulangan, bisa dihilangkan jika tidak mau
        const Divider(height: 1, thickness: 0.5, indent: 0, endIndent: 0),
        _buildOptionRow(
          icon: Icons.repeat_outlined,
          title: _repeatOption,
          onTap: _showRepeatDialog,
        ),
      ],
    );
  }

  Widget _buildDateTimeRow(
    String label,
    DateTime date,
    TimeOfDay time,
    bool isStart,
  ) {
    final String dateFormatPattern =
        date.year == DateTime.now().year ? 'EEE, d MMM' : 'EEE, d MMM yy';
    final String formattedDate =
        DateFormat(dateFormatPattern, 'id_ID').format(date);
    final String formattedTime = time.format(context);

    TextStyle clickableTextStyle = const TextStyle(
        fontSize: 16, color: Colors.black87, fontWeight: FontWeight.normal);
    Color iconColor = Colors.grey.shade700;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ),
          const SizedBox(width: 4),

          Expanded(
            flex: 5,
            child: InkWell(
              onTap: () => _selectDateWithEnhancedPicker(isStart),
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 8.0, horizontal: 6.0),
                child: Row(
                  children: [
                    Icon(Icons.calendar_month_outlined,
                        size: 20, color: iconColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        formattedDate,
                        style: clickableTextStyle,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          if (!_isAllDay) const SizedBox(width: 4),

          if (!_isAllDay)
            Expanded(
              flex: 4,
              child: InkWell(
                onTap: () => _selectTime(isStart),
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      vertical: 8.0, horizontal: 6.0),
                  child: Row(
                    children: [
                      Icon(Icons.access_time_outlined,
                          size: 20, color: iconColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          formattedTime,
                          style: clickableTextStyle,
                          textAlign: TextAlign.start,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (_isAllDay)
            const Spacer(flex: 4), // Menjaga layout jika waktu disembunyikan
        ],
      ),
    );
  }
  // --- AKHIR BAGIAN YANG DIMODIFIKASI UNTUK TAMPILAN TANGGAL BARU ---

  Widget _buildLocationSection() {
    // Menggunakan _buildOptionRow yang sudah diupdate
    return _buildOptionRow(
      icon: Icons.location_on_outlined, // Ikon outline
      title: _locationController.text.isEmpty
          ? 'Tambah lokasi'
          : _locationController.text,
      onTap: _editLocation,
      textStyle: _locationController.text.isEmpty
          ? TextStyle(fontSize: 16, color: Colors.grey[600])
          : null,
    );
  }

  Widget _buildDescriptionSection() {
    // Menggunakan _buildOptionRow yang sudah diupdate
    return _buildOptionRow(
      icon: Icons.subject_outlined, // Ikon outline
      title: _descriptionController.text.isEmpty
          ? 'Tambah deskripsi'
          : _descriptionController.text,
      onTap: _editDescription,
      textStyle: _descriptionController.text.isEmpty
          ? TextStyle(fontSize: 16, color: Colors.grey[600])
          : null,
    );
  }

  Widget _buildOptionsSection() {
    // Menggunakan _buildOptionRow yang sudah diupdate
    return Column(
      children: [
        _buildOptionRow(
          icon: Container(
            // Widget ikon warna
            width: 22,
            height: 22,
            decoration: BoxDecoration(
                color: _selectedColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade300, width: 0.5)),
          ),
          title: _getColorName(_selectedColor),
          onTap: _selectColor,
        ),
        const Divider(height: 1, thickness: 0.5), // Pemisah
        _buildNotificationsSection(),
      ],
    );
  }

  Widget _buildNotificationsSection() {
    // Menggunakan _buildOptionRow yang sudah diupdate
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_notifications.isEmpty)
          _buildOptionRow(
              icon: Icons.notifications_none_outlined,
              title: 'Tidak ada notifikasi',
              onTap: _addNotification,
              textStyle: TextStyle(fontSize: 16, color: Colors.grey[600]))
        else
          ..._notifications.map(
            (notification) => _buildOptionRow(
              icon: Icons.notifications_active_outlined,
              title: notification,
              trailing: IconButton(
                icon: Icon(Icons.close, size: 20, color: Colors.grey[600]),
                onPressed: () {
                  setState(() {
                    _notifications.remove(notification);
                  });
                },
                tooltip: 'Hapus notifikasi',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ),
          ),
        if (_notifications
            .isNotEmpty) // Tombol tambah hanya jika sudah ada notifikasi, atau selalu?
          Align(
            // Untuk indentasi tombol tambah
            alignment: Alignment.centerLeft,
            child: Padding(
              padding:
                  const EdgeInsets.only(left: 44.0), // (Lebar ikon + SizedBox)
              child: TextButton.icon(
                onPressed: _addNotification,
                icon: Icon(Icons.add, color: _selectedColor, size: 20),
                label: Text('Tambah notifikasi',
                    style: TextStyle(color: _selectedColor)),
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
          ),
      ],
    );
  }

  // Method yang perlu di-update di AddEventPage untuk auto-adjust tanggal
  Future<void> _selectDateWithEnhancedPicker(bool isStart) async {
    final currentDate = isStart ? _startDate : _endDate;

    final result = await showDialog<DateTime>(
      context: context,
      barrierDismissible: true,
      builder: (context) => BlocProvider.value(
        value: BlocProvider.of<CalendarBloc>(context),
        child: DatePickerWidget(
          initialDate: currentDate,
          title: isStart ? 'Pilih Tanggal Mulai' : 'Pilih Tanggal Selesai',
          showEvents: true,
          minDate: isStart ? null : _startDate,
          maxDate: isStart ? _endDate : null,
          onDateSelected: (selectedDate) {
            // print('📅 Date selected: ${AppDateUtils.formatDisplayDate(selectedDate)}');
          },
        ),
      ),
    );

    if (result != null) {
      setState(() {
        if (isStart) {
          _startDate = result;
          // ✅ AUTO-ADJUST: Jika tanggal mulai lebih besar dari tanggal selesai, sesuaikan tanggal selesai
          if (_endDate.isBefore(_startDate)) {
            _endDate = _startDate;
            // Jika waktu selesai sekarang sebelum waktu mulai di hari yang sama
            if (_startDate.isAtSameMomentAs(_endDate) &&
                (_startTime.hour > _endTime.hour ||
                    (_startTime.hour == _endTime.hour &&
                        _startTime.minute > _endTime.minute))) {
              _endTime = TimeOfDay(
                  hour: (_startTime.hour + 1) % 24, minute: _startTime.minute);
            }
            _showAdjustmentSnackBar(
                'Tanggal selesai disesuaikan mengikuti tanggal mulai');
          }
        } else {
          // Memilih tanggal selesai
          _endDate = result;
          if (_startDate.isAfter(_endDate)) {
            _startDate = _endDate;
            // Jika waktu mulai sekarang setelah waktu selesai di hari yang sama
            if (_startDate.isAtSameMomentAs(_endDate) &&
                (_startTime.hour > _endTime.hour ||
                    (_startTime.hour == _endTime.hour &&
                        _startTime.minute > _endTime.minute))) {
              _startTime = TimeOfDay(
                  hour: (_endTime.hour - 1 + 24) % 24, minute: _endTime.minute);
            }
            _showAdjustmentSnackBar('Tanggal mulai disesuaikan');
          }
        }
      });
    }
  }

  void _showAdjustmentSnackBar(String message) {
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _selectedColor,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _selectTime(bool isStart) async {
    // Logika _selectTime tetap sama, termasuk theming time picker
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
              timePickerTheme: TimePickerThemeData(
                backgroundColor: Colors.white,
                hourMinuteShape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
                dayPeriodBorderSide: BorderSide(color: Colors.grey.shade300),
                dayPeriodShape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
                dayPeriodColor: MaterialStateColor.resolveWith((states) =>
                    states.contains(MaterialState.selected)
                        ? _selectedColor.withOpacity(0.1)
                        : Colors.grey.shade200),
                dayPeriodTextColor: MaterialStateColor.resolveWith((states) =>
                    states.contains(MaterialState.selected)
                        ? _selectedColor
                        : Colors.black87),
                hourMinuteColor: MaterialStateColor.resolveWith((states) =>
                    states.contains(MaterialState.selected)
                        ? _selectedColor.withOpacity(0.1)
                        : Colors.grey.shade200),
                hourMinuteTextColor: MaterialStateColor.resolveWith((states) =>
                    states.contains(MaterialState.selected)
                        ? _selectedColor
                        : Colors.black87),
                dialHandColor: _selectedColor,
                dialBackgroundColor: _selectedColor.withOpacity(0.1),
                entryModeIconColor: _selectedColor,
                helpTextStyle: TextStyle(
                    color: _selectedColor, fontWeight: FontWeight.bold),
              ),
              textButtonTheme: TextButtonThemeData(
                  style:
                      TextButton.styleFrom(foregroundColor: _selectedColor))),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        DateTime currentStartDateTime = DateTime(
            _startDate.year,
            _startDate.month,
            _startDate.day,
            isStart ? picked.hour : _startTime.hour,
            isStart ? picked.minute : _startTime.minute);
        DateTime currentEndDateTime = DateTime(
            _endDate.year,
            _endDate.month,
            _endDate.day,
            !isStart ? picked.hour : _endTime.hour,
            !isStart ? picked.minute : _endTime.minute);

        if (isStart) {
          _startTime = picked;
          currentStartDateTime = DateTime(_startDate.year, _startDate.month,
              _startDate.day, _startTime.hour, _startTime.minute);
          if (_endDate.year == _startDate.year &&
              _endDate.month == _startDate.month &&
              _endDate.day == _startDate.day) {
            if (currentEndDateTime.isBefore(currentStartDateTime)) {
              _endTime = TimeOfDay(
                  hour: (_startTime.hour + 1) % 24, minute: _startTime.minute);
              _showAdjustmentSnackBar('Waktu selesai disesuaikan');
            }
          }
        } else {
          _endTime = picked;
          currentEndDateTime = DateTime(_endDate.year, _endDate.month,
              _endDate.day, _endTime.hour, _endTime.minute);
          if (_startDate.year == _endDate.year &&
              _startDate.month == _endDate.month &&
              _startDate.day == _endDate.day) {
            if (currentStartDateTime.isAfter(currentEndDateTime)) {
              _startTime = TimeOfDay(
                  hour: (_endTime.hour - 1 + 24) % 24, minute: _endTime.minute);
              _showAdjustmentSnackBar('Waktu mulai disesuaikan');
            }
          }
        }

        final finalStartDT = DateTime(_startDate.year, _startDate.month,
            _startDate.day, _startTime.hour, _startTime.minute);
        final finalEndDT = DateTime(_endDate.year, _endDate.month, _endDate.day,
            _endTime.hour, _endTime.minute);

        if (finalEndDT.isBefore(finalStartDT)) {
          if (isStart) {
            _endDate = _startDate;
            _endTime = TimeOfDay(
                hour: (_startTime.hour + 1) % 24, minute: _startTime.minute);
          } else {
            _startDate = _endDate;
            _startTime = TimeOfDay(
                hour: (_endTime.hour - 1 + 24) % 24, minute: _endTime.minute);
          }
          _showAdjustmentSnackBar(
              'Rentang waktu tidak valid, telah disesuaikan');
        }
      });
    }
  }

  void _editLocation() {
    // Logika _editLocation tetap sama
    final tempLocationController =
        TextEditingController(text: _locationController.text);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Lokasi'),
        content: TextFormField(
          controller: tempLocationController,
          decoration: const InputDecoration(
            hintText: 'Masukkan lokasi',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.location_on_outlined),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal', style: TextStyle(color: _selectedColor)),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _locationController.text = tempLocationController.text;
              });
              Navigator.pop(context);
            },
            child: Text('Simpan', style: TextStyle(color: _selectedColor)),
          ),
        ],
      ),
    );
  }

  void _editDescription() {
    // Logika _editDescription tetap sama
    final tempDescriptionController =
        TextEditingController(text: _descriptionController.text);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deskripsi'),
        content: TextFormField(
          controller: tempDescriptionController,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Masukkan deskripsi',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.subject_outlined),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal', style: TextStyle(color: _selectedColor)),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _descriptionController.text = tempDescriptionController.text;
              });
              Navigator.pop(context);
            },
            child: Text('Simpan', style: TextStyle(color: _selectedColor)),
          ),
        ],
      ),
    );
  }

  void _selectColor() {
    // Logika _selectColor tetap sama
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pilih Warna Event'),
        content: SizedBox(
          width: double.maxFinite,
          child: GridView.builder(
            shrinkWrap: true,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1,
            ),
            itemCount: _colorOptions.length,
            itemBuilder: (context, index) {
              final colorOption = _colorOptions[index];
              final isSelectedColor = _selectedColor == colorOption['color'];
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedColor = colorOption['color'];
                  });
                  Navigator.pop(context);
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: colorOption['color'],
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelectedColor
                          ? (Theme.of(context).brightness == Brightness.dark
                              ? Colors.white70
                              : Colors.black87)
                          : Colors.grey.shade300,
                      width: isSelectedColor ? 2.5 : 1,
                    ),
                  ),
                  child: isSelectedColor
                      ? const Icon(Icons.check, color: Colors.white, size: 20)
                      : null,
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Tutup', style: TextStyle(color: _selectedColor)),
          ),
        ],
      ),
    );
  }

  void _showRepeatDialog() {
    // Logika _showRepeatDialog tetap sama
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pengulangan'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _repeatOptions.map((option) {
            return RadioListTile<String>(
              title: Text(option),
              value: option,
              groupValue: _repeatOption,
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _repeatOption = value;
                  });
                }
                Navigator.pop(context);
              },
              activeColor: _selectedColor,
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Tutup', style: TextStyle(color: _selectedColor)),
          ),
        ],
      ),
    );
  }

  void _addNotification() {
    // Logika _addNotification tetap sama
    final notificationOptions = [
      'Pada waktunya',
      '5 menit sebelum',
      '10 menit sebelum',
      '15 menit sebelum',
      '30 menit sebelum',
      '1 jam sebelum',
      '2 jam sebelum',
      '1 hari sebelum',
      '2 hari sebelum',
      '1 minggu sebelum',
    ];
    final availableOptions = notificationOptions
        .where((opt) => !_notifications.contains(opt))
        .toList();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tambah Notifikasi'),
        content: SizedBox(
          width: double.maxFinite,
          child: availableOptions.isEmpty
              ? const Center(
                  child:
                      Text('Semua opsi notifikasi standar sudah ditambahkan.'))
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: availableOptions.length,
                  itemBuilder: (context, index) {
                    final option = availableOptions[index];
                    return ListTile(
                      title: Text(option),
                      onTap: () {
                        setState(() {
                          _notifications.add(option);
                          // Logika sortir bisa ditambahkan di sini jika diperlukan
                          // _notifications.sort(...);
                        });
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Tutup', style: TextStyle(color: _selectedColor)),
          ),
        ],
      ),
    );
  }

  String _getColorName(Color color) {
    for (var colorOption in _colorOptions) {
      if (colorOption['color'] == color) {
        return colorOption['name'];
      }
    }
    return 'Warna Event';
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _saveEvent() {
    // Logika _saveEvent tetap sama
    if (!_formKey.currentState!.validate()) {
      _showErrorSnackBar('Harap periksa kembali input Anda.');
      return;
    }
    if (_titleController.text.trim().isEmpty) {
      _showErrorSnackBar('Judul event tidak boleh kosong.');
      return;
    }

    final startDateTime = DateTime(
      _startDate.year,
      _startDate.month,
      _startDate.day,
      _isAllDay ? 0 : _startTime.hour,
      _isAllDay ? 0 : _startTime.minute,
    );
    DateTime endDateTime;
    if (_isAllDay) {
      endDateTime =
          DateTime(_endDate.year, _endDate.month, _endDate.day, 23, 59, 59);
    } else {
      endDateTime = DateTime(
        _endDate.year,
        _endDate.month,
        _endDate.day,
        _endTime.hour,
        _endTime.minute,
      );
    }

    if (!_isAllDay && endDateTime.isBefore(startDateTime)) {
      _showErrorSnackBar('Waktu selesai tidak boleh sebelum waktu mulai.');
      return;
    }
    if (_isAllDay && _endDate.isBefore(_startDate)) {
      // Untuk all-day, cukup cek tanggalnya
      _showErrorSnackBar('Tanggal selesai tidak boleh sebelum tanggal mulai.');
      return;
    }

    final event = CalendarEvent(
      id: _isEditing ? widget.existingEvent!.id : const Uuid().v4(),
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      startTime: startDateTime,
      endTime: endDateTime,
      location: _locationController.text.trim().isEmpty
          ? null
          : _locationController.text.trim(),
      isAllDay: _isAllDay,
      color: _selectedColor,
      attendees: List<String>.from(_notifications),
      recurrence: _repeatOption == 'Tidak berulang' ? null : _repeatOption,
      lastModified: DateTime.now(),
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('Menyimpan event...'),
          ],
        ),
      ),
    );

    if (_isEditing) {
      context.read<CalendarBloc>().add(calendar_events_bloc.UpdateEvent(event));
    } else {
      context.read<CalendarBloc>().add(calendar_events_bloc.CreateEvent(event));
    }
    // Future.delayed tidak diperlukan jika BlocListener menangani pop dialog loading
  }
}
