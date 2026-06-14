// lib/create_activity_sheet.dart
import 'package:flutter/material.dart';

class CreateActivitySheet extends StatefulWidget {
  final Future<void> Function({
    required String title,
    required String description,
    required String city,
    required String locationDetails,
    required DateTime startTimeLocal,
    required DateTime endTimeLocal,
    required bool isPublic,
  }) onCreate;

  const CreateActivitySheet({super.key, required this.onCreate});

  @override
  State<CreateActivitySheet> createState() => _CreateActivitySheetState();
}

class _CreateActivitySheetState extends State<CreateActivitySheet> {
  final _formKey = GlobalKey<FormState>();

  String _title = '';
  String _description = '';
  String _city = '';
  String _locationDetails = '';
  DateTime? _start;
  DateTime? _end;
  bool _isPublic = true;
  bool _submitting = false;

  bool get _canSubmit =>
      _title.trim().isNotEmpty &&
      _city.trim().isNotEmpty &&
      _start != null &&
      _end != null;

  Future<void> _pickStart() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (!mounted) return;
    if (date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now),
    );
    if (!mounted) return;
    if (time == null) return;

    setState(() {
      _start =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _pickEnd() async {
    final base = _start ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: base,
      lastDate: base.add(const Duration(days: 365)),
    );
    if (!mounted) return;
    if (date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base.add(const Duration(hours: 1))),
    );
    if (!mounted) return;
    if (time == null) return;

    setState(() {
      _end =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _submit() async {
    if (!_canSubmit || _submitting) return;
    if (_end!.isBefore(_start!)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('End time must be after start time.'),
        ),
      );
      return;
    }

    setState(() {
      _submitting = true;
    });

    await widget.onCreate(
      title: _title.trim(),
      description: _description.trim(),
      city: _city.trim(),
      locationDetails: _locationDetails.trim(),
      startTimeLocal: _start!,
      endTimeLocal: _end!,
      isPublic: _isPublic,
    );

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    const brandBorder = Color(0xFFD8E9E6);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'New activity',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Activity title',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => setState(() => _title = v),
              ),
              const SizedBox(height: 8),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
                onChanged: (v) => setState(() => _description = v),
              ),
              const SizedBox(height: 8),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'City',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => setState(() => _city = v),
              ),
              const SizedBox(height: 8),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Location details (optional)',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => setState(() => _locationDetails = v),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _pickStart,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: brandBorder),
                      ),
                      child: Text(
                        _start == null
                            ? 'Pick start'
                            : 'Start: ${_start!.toLocal()}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _pickEnd,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: brandBorder),
                      ),
                      child: Text(
                        _end == null
                            ? 'Pick end'
                            : 'End: ${_end!.toLocal()}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Switch(
                    value: _isPublic,
                    onChanged: (v) => setState(() => _isPublic = v),
                  ),
                  const Text(
                    'Public activity (visible to others)',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: _canSubmit && !_submitting ? _submit : null,
                  child: Text(_submitting ? 'Creating...' : 'Create'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}