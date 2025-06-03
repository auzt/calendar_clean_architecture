// lib/features/calendar/presentation/pages/add_event_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/validators.dart';
import '../../domain/entities/calendar_event.dart';
import '../bloc/calendar_bloc.dart';
import '../bloc/calendar_event.dart' as calendar_events;
import '../bloc/calendar_state.dart';
import '../widgets/date_picker_widget.dart';

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
  Color _selectedColor = Colors.blue;
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
      _notifications = event.attendees; // Simplified for this example
    } else {
      _startDate = DateTime(
        widget.initialDate.year,
        widget.initialDate.month,
        widget.initialDate.day,
      );
      _startTime = TimeOfDay.now();
      _endDate = _startDate;
      _endTime = TimeOfDay(
        hour: (_startTime.hour + 1) % 24,
        minute: _startTime.minute,
      );
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
        backgroundColor: Colors.white,
        elevation: 1,
        actions: [
          BlocListener<CalendarBloc, CalendarState>(
            listener: (context, state) {
              if (state is EventCreated || state is EventUpdated) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      _isEditing
                          ? 'Event berhasil diupdate'
                          : 'Event berhasil dibuat',
                    ),
                    backgroundColor: Colors.green,
                  ),
                );
              } else if (state is CalendarError) {
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
                  backgroundColor: Colors.blue,
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
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTitleSection(),
                  const SizedBox(height: 20),
                  _buildEventTypeSelection(),
                  const SizedBox(height: 30),
                  _buildDateTimeSection(),
                  const SizedBox(height: 20),
                  _buildLocationSection(),
                  const SizedBox(height: 20),
                  _buildDescriptionSection(),
                  const SizedBox(height: 20),
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
    return Row(
      children: [
        Icon(
          _selectedEventType == 'Birthday'
              ? Icons.cake
              : _selectedEventType == 'Task'
                  ? Icons.check_circle_outline
                  : Icons.event,
          color: Colors.grey[600],
          size: 24,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextFormField(
            controller: _titleController,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w400),
            decoration: InputDecoration(
              hintText: _selectedEventType == 'Birthday'
                  ? 'Nama ulang tahun'
                  : _selectedEventType == 'Task'
                      ? 'Judul task'
                      : 'Judul event',
              hintStyle: TextStyle(color: Colors.grey[600], fontSize: 20),
              border: InputBorder.none,
            ),
            validator: Validators.validateTitle,
          ),
        ),
      ],
    );
  }

  Widget _buildEventTypeSelection() {
    return Row(
      children: _eventTypes.map((type) {
        final isSelected = _selectedEventType == type;
        return Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: ChoiceChip(
            label: Text(type),
            selected: isSelected,
            onSelected: (selected) {
              setState(() {
                _selectedEventType = type;
                if (type == 'Birthday') {
                  _isAllDay = true;
                  _repeatOption = 'Tahunan';
                  _selectedColor = Colors.green;
                  _notifications = ['1 minggu sebelum', 'Hari ini'];
                } else if (type == 'Task') {
                  _repeatOption = 'Tidak berulang';
                  _selectedColor = Colors.orange;
                  _isAllDay = false;
                  _notifications = ['30 menit sebelum'];
                } else {
                  _selectedColor = Colors.blue;
                  _notifications = ['30 menit sebelum'];
                }
              });
            },
            selectedColor: Colors.blue[100],
            backgroundColor: Colors.grey[100],
            labelStyle: TextStyle(
              color: isSelected ? Colors.blue[800] : Colors.grey[700],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDateTimeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // All-day toggle
        _buildOptionRow(
          icon: Icons.access_time,
          title: 'Sepanjang hari',
          trailing: Switch(
            value: _isAllDay,
            onChanged: (value) {
              setState(() {
                _isAllDay = value;
              });
            },
            activeColor: Colors.blue,
          ),
        ),
        const SizedBox(height: 16),

        // Start date/time
        _buildDateTimeRow('Mulai', _startDate, _startTime, true),
        const SizedBox(height: 8),

        // End date/time
        _buildDateTimeRow('Selesai', _endDate, _endTime, false),
        const SizedBox(height: 16),

        // Repeat option
        _buildOptionRow(
          icon: Icons.repeat,
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
    return Row(
      children: [
        SizedBox(
          width: 60,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: GestureDetector(
            onTap: () => _selectDateWithEnhancedPicker(isStart),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today,
                      size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      AppDateUtils.formatDisplayDate(date),
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (!_isAllDay) ...[
          const SizedBox(width: 12),
          Expanded(
            flex: 1,
            child: GestureDetector(
              onTap: () => _selectTime(isStart),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.access_time,
                        size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        time.format(context),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLocationSection() {
    return _buildOptionRow(
      icon: Icons.location_on,
      title: _locationController.text.isEmpty
          ? 'Tambah lokasi'
          : _locationController.text,
      onTap: _editLocation,
    );
  }

  Widget _buildDescriptionSection() {
    return _buildOptionRow(
      icon: Icons.subject,
      title: _descriptionController.text.isEmpty
          ? 'Tambah deskripsi'
          : _descriptionController.text,
      onTap: _editDescription,
    );
  }

  Widget _buildOptionsSection() {
    return Column(
      children: [
        // Color selection
        _buildOptionRow(
          icon: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: _selectedColor,
              shape: BoxShape.circle,
            ),
          ),
          title: _getColorName(_selectedColor),
          onTap: _selectColor,
        ),
        const SizedBox(height: 16),

        // Notifications
        _buildNotificationsSection(),
      ],
    );
  }

  Widget _buildNotificationsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Notifikasi',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        ..._notifications.map(
          (notification) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                const Icon(Icons.notifications, color: Colors.grey),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    notification,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _notifications.remove(notification);
                    });
                  },
                  icon: const Icon(Icons.close, size: 20),
                  tooltip: 'Hapus notifikasi',
                ),
              ],
            ),
          ),
        ),
        TextButton.icon(
          onPressed: _addNotification,
          icon: const Icon(Icons.add),
          label: const Text('Tambah notifikasi'),
        ),
      ],
    );
  }

  Widget _buildOptionRow({
    required dynamic icon,
    required String title,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child:
                  icon is IconData ? Icon(icon, color: Colors.grey[700]) : icon,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 16),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (trailing != null)
              trailing
            else if (onTap != null)
              Icon(Icons.edit, size: 16, color: Colors.grey.shade600),
          ],
        ),
      ),
    );
  }

  // ✅ FIXED: Enhanced Date Picker dengan MonthViewWidget LENGKAP
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
          showEvents:
              true, // ✅ Menampilkan events dalam bentuk blok seperti di home
          minDate: isStart
              ? null
              : _startDate, // End date tidak boleh sebelum start date
          maxDate: isStart
              ? _endDate
              : null, // Start date tidak boleh setelah end date
          onDateSelected: (selectedDate) {
            // Real-time callback untuk preview tanggal yang dipilih
            print(
                '📅 Date selected: ${AppDateUtils.formatDisplayDate(selectedDate)}');
          },
        ),
      ),
    );

    if (result != null) {
      setState(() {
        if (isStart) {
          _startDate = result;
          // Auto adjust end date jika sebelum start date
          if (_endDate.isBefore(_startDate)) {
            _endDate = _startDate;
            // Show info message untuk user
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content:
                    Text('Tanggal selesai disesuaikan dengan tanggal mulai'),
                backgroundColor: Colors.blue,
                duration: Duration(seconds: 2),
              ),
            );
          }
        } else {
          _endDate = result;
          // Auto adjust start date jika setelah end date
          if (_startDate.isAfter(_endDate)) {
            _startDate = _endDate;
            // Show info message untuk user
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content:
                    Text('Tanggal mulai disesuaikan dengan tanggal selesai'),
                backgroundColor: Colors.blue,
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
      });

      // Success feedback dengan tanggal yang dipilih
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '${isStart ? 'Tanggal mulai' : 'Tanggal selesai'} berhasil dipilih: ${AppDateUtils.formatDisplayDate(result)}'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _selectTime(bool isStart) async {
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
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
          // Auto adjust end time to 1 hour later
          final newEndTime = TimeOfDay(
            hour: (picked.hour + 1) % 24,
            minute: picked.minute,
          );
          _endTime = newEndTime;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  void _editLocation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Lokasi'),
        content: TextFormField(
          controller: _locationController,
          decoration: const InputDecoration(
            hintText: 'Masukkan lokasi',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.location_on),
          ),
          validator: Validators.validateLocation,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              setState(() {});
              Navigator.pop(context);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _editDescription() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deskripsi'),
        content: TextFormField(
          controller: _descriptionController,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Masukkan deskripsi',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.description),
          ),
          validator: Validators.validateDescription,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              setState(() {});
              Navigator.pop(context);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _selectColor() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pilih Warna'),
        content: SizedBox(
          width: double.maxFinite,
          child: GridView.builder(
            shrinkWrap: true,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1,
            ),
            itemCount: _colorOptions.length,
            itemBuilder: (context, index) {
              final colorOption = _colorOptions[index];
              final isSelected = _selectedColor == colorOption['color'];

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
                      color: isSelected ? Colors.black : Colors.grey.shade300,
                      width: isSelected ? 3 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: colorOption['color'].withOpacity(0.3),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
                  ),
                  child: isSelected
                      ? const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 24,
                        )
                      : null,
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  void _showRepeatDialog() {
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
                setState(() {
                  _repeatOption = value!;
                });
                Navigator.pop(context);
              },
              activeColor: Colors.blue,
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  void _addNotification() {
    final notificationOptions = [
      '5 menit sebelum',
      '10 menit sebelum',
      '15 menit sebelum',
      '30 menit sebelum',
      '1 jam sebelum',
      '2 jam sebelum',
      '1 hari sebelum',
      '1 minggu sebelum',
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tambah Notifikasi'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: notificationOptions.length,
            itemBuilder: (context, index) {
              final option = notificationOptions[index];
              final isAlreadyAdded = _notifications.contains(option);

              return ListTile(
                title: Text(option),
                trailing: isAlreadyAdded
                    ? const Icon(Icons.check, color: Colors.green)
                    : null,
                enabled: !isAlreadyAdded,
                onTap: isAlreadyAdded
                    ? null
                    : () {
                        setState(() {
                          _notifications.add(option);
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
            child: const Text('Tutup'),
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
    return 'Warna custom';
  }

  void _saveEvent() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validasi title tidak boleh kosong
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Judul event tidak boleh kosong'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final startDateTime = DateTime(
      _startDate.year,
      _startDate.month,
      _startDate.day,
      _isAllDay ? 0 : _startTime.hour,
      _isAllDay ? 0 : _startTime.minute,
    );

    final endDateTime = DateTime(
      _endDate.year,
      _endDate.month,
      _endDate.day,
      _isAllDay ? 23 : _endTime.hour,
      _isAllDay ? 59 : _endTime.minute,
    );

    final validationError = Validators.validateDateRange(
      startDateTime,
      endDateTime,
    );
    if (validationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(validationError), backgroundColor: Colors.red),
      );
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
      attendees: _notifications,
      recurrence: _repeatOption == 'Tidak berulang' ? null : _repeatOption,
      lastModified: DateTime.now(),
    );

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Menyimpan event...'),
          ],
        ),
      ),
    );

    // Save event
    if (_isEditing) {
      context.read<CalendarBloc>().add(calendar_events.UpdateEvent(event));
    } else {
      context.read<CalendarBloc>().add(calendar_events.CreateEvent(event));
    }

    // Close loading dialog after a brief delay
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
      }
    });
  }
}
