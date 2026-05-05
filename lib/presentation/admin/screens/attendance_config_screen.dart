import 'package:flutter/material.dart';
import '../../../domain/entities/staff_attendance.dart';
import '../../../data/repositories/staff_attendance_repository.dart';

class AttendanceConfigScreen extends StatefulWidget {
  final String schoolId;

  const AttendanceConfigScreen({
    Key? key,
    required this.schoolId,
  }) : super(key: key);

  @override
  State<AttendanceConfigScreen> createState() => _AttendanceConfigScreenState();
}

class _AttendanceConfigScreenState extends State<AttendanceConfigScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repository = StaffAttendanceRepository();
  final _graceMinutesController = TextEditingController();

  String _lateThresholdTime = '09:30';
  int _lateGraceMinutes = 5;
  List<String> _workingDays = [
    'MONDAY',
    'TUESDAY',
    'WEDNESDAY',
    'THURSDAY',
    'FRIDAY'
  ];
  bool _autoMarkAbsent = true;
  bool _requireBothSwipes = true;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void dispose() {
    _graceMinutesController.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    try {
      final config = await _repository.getAttendanceConfig(widget.schoolId);
      
      if (config != null) {
        setState(() {
          _lateThresholdTime = config.lateThresholdTime;
          _lateGraceMinutes = config.lateGraceMinutes;
          _workingDays = List.from(config.workingDays);
          _autoMarkAbsent = config.autoMarkAbsent;
          _requireBothSwipes = config.requireBothSwipes;
          _graceMinutesController.text = _lateGraceMinutes.toString();
          _isLoading = false;
        });
      } else {
        setState(() {
          _graceMinutesController.text = _lateGraceMinutes.toString();
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Error loading configuration: $e');
    }
  }

  Future<void> _saveConfig() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      await _repository.createAttendanceConfig(
        schoolId: widget.schoolId,
        lateThresholdTime: _lateThresholdTime,
        lateGraceMinutes: _lateGraceMinutes,
        workingDays: _workingDays,
        autoMarkAbsent: _autoMarkAbsent,
        requireBothSwipes: _requireBothSwipes,
        createdBy: 'admin', // TODO: Get from auth
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Configuration saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _isSaving = false);
      _showError('Error saving configuration: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Attendance Configuration')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Configuration'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildLateThresholdSection(),
            const SizedBox(height: 24),
            _buildGracePeriodSection(),
            const SizedBox(height: 24),
            _buildWorkingDaysSection(),
            const SizedBox(height: 24),
            _buildSettingsSection(),
            const SizedBox(height: 32),
            _buildSaveButton(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildLateThresholdSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Late Threshold Time',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Staff arriving after this time will be marked as late',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _selectLateThreshold,
              child: InputDecorator(
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.access_time),
                  labelText: 'Threshold Time',
                ),
                child: Text(
                  _lateThresholdTime,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGracePeriodSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Grace Period',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Additional minutes allowed before marking as late',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _graceMinutesController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Grace Period (minutes)',
                suffixText: 'min',
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter grace period';
                }
                final minutes = int.tryParse(value);
                if (minutes == null || minutes < 0 || minutes > 60) {
                  return 'Please enter a valid number (0-60)';
                }
                return null;
              },
              onChanged: (value) {
                final minutes = int.tryParse(value);
                if (minutes != null) {
                  setState(() => _lateGraceMinutes = minutes);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkingDaysSection() {
    final allDays = [
      'MONDAY',
      'TUESDAY',
      'WEDNESDAY',
      'THURSDAY',
      'FRIDAY',
      'SATURDAY',
      'SUNDAY'
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Working Days',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Select the days when attendance is required',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 12),
            ...allDays.map((day) {
              return CheckboxListTile(
                title: Text(_formatDayName(day)),
                value: _workingDays.contains(day),
                onChanged: (value) {
                  setState(() {
                    if (value == true) {
                      _workingDays.add(day);
                    } else {
                      _workingDays.remove(day);
                    }
                  });
                },
                contentPadding: EdgeInsets.zero,
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Additional Settings',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('Auto-mark Absent'),
              subtitle: const Text(
                'Automatically mark staff as absent if no RFID swipe',
                style: TextStyle(fontSize: 12),
              ),
              value: _autoMarkAbsent,
              onChanged: (value) {
                setState(() => _autoMarkAbsent = value);
              },
              contentPadding: EdgeInsets.zero,
            ),
            const Divider(),
            SwitchListTile(
              title: const Text('Require Both Swipes'),
              subtitle: const Text(
                'Mark as partial if only login or logout is recorded',
                style: TextStyle(fontSize: 12),
              ),
              value: _requireBothSwipes,
              onChanged: (value) {
                setState(() => _requireBothSwipes = value);
              },
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return ElevatedButton(
      onPressed: _isSaving ? null : _saveConfig,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.all(16),
        backgroundColor: Colors.blue,
      ),
      child: _isSaving
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : const Text(
              'Save Configuration',
              style: TextStyle(fontSize: 16, color: Colors.white),
            ),
    );
  }

  Future<void> _selectLateThreshold() async {
    final parts = _lateThresholdTime.split(':');
    final initialTime = TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );

    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (picked != null) {
      setState(() {
        _lateThresholdTime =
            '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      });
    }
  }

  String _formatDayName(String day) {
    return day.substring(0, 1) + day.substring(1).toLowerCase();
  }
}
