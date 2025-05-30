// lib/features/calendar/presentation/widgets/event_form_widget.dart
import 'package:flutter/material.dart';
import '../../../../core/utils/validators.dart';
import '../../domain/entities/calendar_event.dart';

class EventFormWidget extends StatefulWidget {
  final CalendarEvent? initialEvent;
  final Function(CalendarEvent) onSave;
  final VoidCallback? onCancel;

  const EventFormWidget({
    Key? key,
    this.initialEvent,
    required this.onSave,
    this.onCancel,
  }) : super(key: key);

  @override
  State<EventFormWidget> createState() => _EventFormWidgetState();
}

class _EventFormWidgetState extends State<EventFormWidget> {
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

  @override
  void initState() {
    super.initState();
    _initializeForm();
  }

  void _initializeForm() {
    if (widget.initialEvent != null) {
      final event = widget.initialEvent!;
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
    } else {
      final now = DateTime.now();
      _startDate = DateTime(now.year, now.month, now.day);
      _startTime = TimeOfDay.now();
      _endDate = _startDate;
      _endTime = TimeOfDay(
        hour: _startTime.hour + 1,
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
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Title Field
          TextFormField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Judul Event',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.title),
            ),
            validator: Validators.validateTitle,
          ),
          const SizedBox(height: 16),

          // All Day Switch
          SwitchListTile(
            title: const Text('Sepanjang Hari'),
            value: _isAllDay,
            onChanged: (value) {
              setState(() {
                _isAllDay = value;
              });
            },
          ),
          const SizedBox(height: 16),

          // Date and Time Selection
          Row(
            children: [
              Expanded(
                child: _buildDateTimeField(
                  label: 'Mulai',
                  date: _startDate,
                  time: _startTime,
                  onDateTap: () => _selectDate(true),
                  onTimeTap: () => _selectTime(true),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildDateTimeField(
                  label: 'Selesai',
                  date: _endDate,
                  time: _endTime,
                  onDateTap: () => _selectDate(false),
                  onTimeTap: () => _selectTime(false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Location Field
          TextFormField(
            controller: _locationController,
            decoration: const InputDecoration(
              labelText: 'Lokasi (Opsional)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.location_on),
            ),
            validator: Validators.validateLocation,
          ),
          const SizedBox(height: 16),

          // Description Field
          TextFormField(
            controller: _descriptionController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Deskripsi (Opsional)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.description),
            ),
            validator: Validators.validateDescription,
          ),
          const SizedBox(height: 16),

          // Color Selection
          _buildColorSelector(),
          const SizedBox(height: 24),

          // Action Buttons
          Row(
            children: [
              if (widget.onCancel != null)
                Expanded(
                  child: OutlinedButton(
                    onPressed: widget.onCancel,
                    child: const Text('Batal'),
                  ),
                ),
              if (widget.onCancel != null) const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _saveEvent,
                  child: Text(
                    widget.initialEvent != null ? 'Update' : 'Simpan',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateTimeField({
    required String label,
    required DateTime date,
    required TimeOfDay time,
    required VoidCallback onDateTap,
    required VoidCallback onTimeTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onDateTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '${date.day}/${date.month}/${date.year}',
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ),
        if (!_isAllDay) ...[
          const SizedBox(height: 8),
          GestureDetector(
            onTap: onTimeTap,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                time.format(context),
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildColorSelector() {
    final colors = [
      Colors.blue,
      Colors.red,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Warna', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children:
              colors.map((color) {
                final isSelected = color == _selectedColor;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedColor = color;
                    });
                  },
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border:
                          isSelected
                              ? Border.all(color: Colors.black, width: 3)
                              : Border.all(color: Colors.grey, width: 1),
                    ),
                    child:
                        isSelected
                            ? const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 16,
                            )
                            : null,
                  ),
                );
              }).toList(),
        ),
      ],
    );
  }

  Future<void> _selectDate(bool isStart) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_startDate.isAfter(_endDate)) {
            _endDate = _startDate;
          }
        } else {
          _endDate = picked;
          if (_endDate.isBefore(_startDate)) {
            _startDate = _endDate;
          }
        }
      });
    }
  }

  Future<void> _selectTime(bool isStart) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
          // Auto adjust end time
          final newEndTime = TimeOfDay(
            hour: picked.hour + 1,
            minute: picked.minute,
          );
          if (newEndTime.hour < 24) {
            _endTime = newEndTime;
          }
        } else {
          _endTime = picked;
        }
      });
    }
  }

  void _saveEvent() {
    if (!_formKey.currentState!.validate()) {
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
      id:
          widget.initialEvent?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      title: _titleController.text.trim(),
      description:
          _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
      startTime: startDateTime,
      endTime: endDateTime,
      location:
          _locationController.text.trim().isEmpty
              ? null
              : _locationController.text.trim(),
      isAllDay: _isAllDay,
      color: _selectedColor,
      lastModified: DateTime.now(),
    );

    widget.onSave(event);
  }
}
