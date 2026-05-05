import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../domain/entities/permission_request.dart';
import '../../../data/repositories/permission_request_repository.dart';

class ApplyPermissionScreen extends StatefulWidget {
  final String schoolId;
  final String staffId;

  const ApplyPermissionScreen({
    Key? key,
    required this.schoolId,
    required this.staffId,
  }) : super(key: key);

  @override
  State<ApplyPermissionScreen> createState() => _ApplyPermissionScreenState();
}

class _ApplyPermissionScreenState extends State<ApplyPermissionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  final _remarksController = TextEditingController();
  final _repository = PermissionRequestRepository(widget.schoolId, widget.staffId);

  DateTime? _requestDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  String? _selectedPermissionTypeId;
  List<PermissionType> _permissionTypes = [];
  PermissionConfig? _config;
  MonthlyPermissionUsage? _monthlyUsage;
  bool _isSubmitting = false;
  int? _calculatedDuration;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _requestDate = DateTime.now();
    _loadPermissionTypes();
    _loadConfig();
    _loadMonthlyUsage();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _loadPermissionTypes() async {
    try {
      final types = await _repository.getPermissionTypes().first;
      setState(() {
        _permissionTypes = types;
        if (types.isNotEmpty) {
          _selectedPermissionTypeId = types.first.id;
        }
      });
    } catch (e) {
      _showError('Error loading permission types: $e');
    }
  }

  Future<void> _loadConfig() async {
    try {
      final config = await _repository.getPermissionConfig();
      setState(() => _config = config);
    } catch (e) {
      _showError('Error loading configuration: $e');
    }
  }

  Future<void> _loadMonthlyUsage() async {
    try {
      final month = PermissionCalculator.getCurrentMonth();
      final usage = await _repository.getMonthlyUsage(month);
      setState(() => _monthlyUsage = usage);
    } catch (e) {
      // Usage might not exist yet, that's okay
    }
  }

  void _calculateDuration() {
    if (_requestDate == null || _startTime == null || _endTime == null) {
      setState(() {
        _calculatedDuration = null;
        _validationError = null;
      });
      return;
    }

    final startDateTime = DateTime(
      _requestDate!.year,
      _requestDate!.month,
      _requestDate!.day,
      _startTime!.hour,
      _startTime!.minute,
    );

    final endDateTime = DateTime(
      _requestDate!.year,
      _requestDate!.month,
      _requestDate!.day,
      _endTime!.hour,
      _endTime!.minute,
    );

    final duration = PermissionCalculator.calculateDurationMinutes(
      startDateTime,
      endDateTime,
    );

    String? error;
    if (_config != null) {
      error = PermissionCalculator.validatePermissionTiming(
        _requestDate!,
        startDateTime,
        endDateTime,
        _config!,
      );
    }

    setState(() {
      _calculatedDuration = duration;
      _validationError = error;
    });
  }

  Future<void> _submitPermissionRequest() async {
    if (!_formKey.currentState!.validate()) return;
    if (_requestDate == null || _startTime == null || _endTime == null) {
      _showError('Please select date and time');
      return;
    }
    if (_selectedPermissionTypeId == null) {
      _showError('Please select permission type');
      return;
    }
    if (_validationError != null) {
      _showError(_validationError!);
      return;
    }

    // Check monthly limit
    if (_config != null && _monthlyUsage != null) {
      if (_monthlyUsage!.approvedRequests >= _config!.monthlyLimit) {
        _showError(
          'Monthly limit exceeded. You have used ${_monthlyUsage!.approvedRequests}/${_config!.monthlyLimit} permissions this month.',
        );
        return;
      }
    }

    setState(() => _isSubmitting = true);

    try {
      final startDateTime = DateTime(
        _requestDate!.year,
        _requestDate!.month,
        _requestDate!.day,
        _startTime!.hour,
        _startTime!.minute,
      );

      final endDateTime = DateTime(
        _requestDate!.year,
        _requestDate!.month,
        _requestDate!.day,
        _endTime!.hour,
        _endTime!.minute,
      );

      await _repository.createPermissionRequest(
        CreatePermissionRequest(
          requestDate: _requestDate!,
          startTime: startDateTime,
          endTime: endDateTime,
          permissionTypeId: _selectedPermissionTypeId!,
          reason: _reasonController.text.trim(),
          remarks: _remarksController.text.trim().isEmpty
              ? null
              : _remarksController.text.trim(),
        ),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Permission request submitted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      _showError('Error submitting permission request: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Apply for Permission'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildUsageSummaryCard(),
            const SizedBox(height: 16),
            _buildPermissionTypeDropdown(),
            const SizedBox(height: 16),
            _buildDateSelectionCard(),
            const SizedBox(height: 16),
            _buildTimeSelectionCard(),
            const SizedBox(height: 16),
            if (_calculatedDuration != null) ...[
              _buildDurationCard(),
              const SizedBox(height: 16),
            ],
            if (_validationError != null) ...[
              _buildValidationErrorCard(),
              const SizedBox(height: 16),
            ],
            _buildReasonField(),
            const SizedBox(height: 16),
            _buildRemarksField(),
            const SizedBox(height: 24),
            _buildSubmitButton(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildUsageSummaryCard() {
    if (_config == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final used = _monthlyUsage?.approvedRequests ?? 0;
    final total = _config!.monthlyLimit;
    final remaining = total - used;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Monthly Permission Usage',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Used: $used',
                      style: const TextStyle(fontSize: 14),
                    ),
                    Text(
                      'Remaining: $remaining',
                      style: TextStyle(
                        fontSize: 14,
                        color: remaining > 0 ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                CircularProgressIndicator(
                  value: total > 0 ? used / total : 0,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    remaining > 0 ? Colors.blue : Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Max duration per request: ${_config!.maxDurationDisplayText}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionTypeDropdown() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Permission Type *',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedPermissionTypeId,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: _permissionTypes.map((type) {
                return DropdownMenuItem(
                  value: type.id,
                  child: Text(type.name),
                );
              }).toList(),
              onChanged: (value) {
                setState(() => _selectedPermissionTypeId = value);
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please select permission type';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateSelectionCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Permission Date *',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: _selectDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                child: Text(
                  _requestDate != null
                      ? DateFormat('EEEE, MMM d, y').format(_requestDate!)
                      : 'Select date',
                  style: TextStyle(
                    color: _requestDate != null ? Colors.black87 : Colors.grey,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeSelectionCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Time Period *',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildTimeField(
                    label: 'Start Time',
                    time: _startTime,
                    onTap: () => _selectTime(isStartTime: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTimeField(
                    label: 'End Time',
                    time: _endTime,
                    onTap: () => _selectTime(isStartTime: false),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeField({
    required String label,
    required TimeOfDay? time,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.access_time),
        ),
        child: Text(
          time != null ? time.format(context) : 'Select',
          style: TextStyle(
            color: time != null ? Colors.black87 : Colors.grey,
          ),
        ),
      ),
    );
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _requestDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );

    if (picked != null) {
      setState(() => _requestDate = picked);
      _calculateDuration();
    }
  }

  Future<void> _selectTime({required bool isStartTime}) async {
    final initialTime = isStartTime
        ? (_startTime ?? TimeOfDay.now())
        : (_endTime ?? _startTime ?? TimeOfDay.now());

    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (picked != null) {
      setState(() {
        if (isStartTime) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
      _calculateDuration();
    }
  }

  Widget _buildDurationCard() {
    final hours = _calculatedDuration! ~/ 60;
    final minutes = _calculatedDuration! % 60;

    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.timer, color: Colors.blue),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Duration',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                Text(
                  hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildValidationErrorCard() {
    return Card(
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _validationError!,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReasonField() {
    return TextFormField(
      controller: _reasonController,
      decoration: const InputDecoration(
        labelText: 'Reason *',
        hintText: 'Enter reason for permission',
        border: OutlineInputBorder(),
      ),
      maxLines: 3,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please enter reason';
        }
        if (value.trim().length < 10) {
          return 'Reason must be at least 10 characters';
        }
        return null;
      },
    );
  }

  Widget _buildRemarksField() {
    return TextFormField(
      controller: _remarksController,
      decoration: const InputDecoration(
        labelText: 'Additional Remarks (Optional)',
        hintText: 'Any additional information',
        border: OutlineInputBorder(),
      ),
      maxLines: 2,
    );
  }

  Widget _buildSubmitButton() {
    return ElevatedButton(
      onPressed: _isSubmitting || _validationError != null
          ? null
          : _submitPermissionRequest,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.all(16),
        backgroundColor: Colors.blue,
        disabledBackgroundColor: Colors.grey,
      ),
      child: _isSubmitting
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : const Text(
              'Submit Permission Request',
              style: TextStyle(fontSize: 16, color: Colors.white),
            ),
    );
  }
}
