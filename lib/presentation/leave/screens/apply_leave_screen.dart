import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../domain/entities/leave_application.dart';
import '../../../domain/entities/leave_balance.dart';
import '../../../domain/entities/leave_type_config.dart';
import '../../../data/repositories/leave_application_repository.dart';
import '../../../data/repositories/leave_type_repository.dart';
import '../../../data/repositories/holiday_repository.dart';

class ApplyLeaveScreen extends StatefulWidget {
  final String schoolId;
  final String staffId;

  const ApplyLeaveScreen({
    Key? key,
    required this.schoolId,
    required this.staffId,
  }) : super(key: key);

  @override
  State<ApplyLeaveScreen> createState() => _ApplyLeaveScreenState();
}

class _ApplyLeaveScreenState extends State<ApplyLeaveScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  final _remarksController = TextEditingController();
  final _leaveRepository = LeaveApplicationRepository();
  final _leaveTypeRepository = LeaveTypeRepository();
  final _holidayRepository = HolidayRepository();

  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedLeaveTypeId;
  List<LeaveTypeConfig> _leaveTypes = [];
  LeaveBalance? _leaveBalance;
  bool _isLoading = false;
  bool _isSubmitting = false;
  List<DateTime> _calculatedLeaveDates = [];
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _loadLeaveTypes();
    _loadLeaveBalance();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _loadLeaveTypes() async {
    try {
      final types = await _repository.getActiveLeaveTypes(widget.schoolId).first;
      setState(() {
        _leaveTypes = types;
        if (types.isNotEmpty) {
          _selectedLeaveTypeId = types.first.id;
        }
      });
    } catch (e) {
      _showError('Error loading leave types: $e');
    }
  }

  Future<void> _loadLeaveBalance() async {
    try {
      final academicYear = _getAcademicYear(DateTime.now());
      final balance = await _repository.getLeaveBalance(
        widget.schoolId,
        widget.staffId,
        academicYear,
      );
      setState(() => _leaveBalance = balance);
    } catch (e) {
      _showError('Error loading leave balance: $e');
    }
  }

  String _getAcademicYear(DateTime date) {
    final year = date.year;
    final month = date.month;
    if (month >= 6) {
      return '$year-${year + 1}';
    } else {
      return '${year - 1}-$year';
    }
  }

  Future<void> _calculateLeaveDates() async {
    if (_startDate == null || _endDate == null) {
      setState(() {
        _calculatedLeaveDates = [];
        _validationError = null;
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Get holidays
      final holidays = await _repository.getHolidays(
        widget.schoolId,
        _startDate!,
        _endDate!,
      ).first;

      // Calculate leave dates
      final leaveDates = LeaveDateCalculator.calculateLeaveDates(
        _startDate!,
        _endDate!,
        holidays,
      );

      // Get existing applications
      final existingApplications = await _repository
          .getStaffLeaveApplications(
            widget.schoolId,
            widget.staffId,
          )
          .first;

      // Validate
      final error = LeaveDateCalculator.validateLeaveDates(
        _startDate!,
        _endDate!,
        holidays,
        existingApplications,
      );

      setState(() {
        _calculatedLeaveDates = leaveDates;
        _validationError = error;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _validationError = 'Error calculating leave dates: $e';
      });
    }
  }

  Future<void> _submitLeaveRequest() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startDate == null || _endDate == null) {
      _showError('Please select start and end dates');
      return;
    }
    if (_selectedLeaveTypeId == null) {
      _showError('Please select leave type');
      return;
    }
    if (_validationError != null) {
      _showError(_validationError!);
      return;
    }
    if (_calculatedLeaveDates.isEmpty) {
      _showError('No working days found in selected date range');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await _repository.createLeaveApplication(
        schoolId: widget.schoolId,
        staffId: widget.staffId,
        leaveTypeId: _selectedLeaveTypeId!,
        startDate: _startDate!,
        endDate: _endDate!,
        reason: _reasonController.text.trim(),
        remarks: _remarksController.text.trim().isEmpty
            ? null
            : _remarksController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Leave application submitted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      _showError('Error submitting leave request: $e');
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
        title: const Text('Apply for Leave'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildLeaveBalanceCard(),
            const SizedBox(height: 16),
            _buildLeaveTypeDropdown(),
            const SizedBox(height: 16),
            _buildDateSelectionCard(),
            const SizedBox(height: 16),
            if (_calculatedLeaveDates.isNotEmpty) ...[
              _buildLeaveSummaryCard(),
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

  Widget _buildLeaveBalanceCard() {
    if (_leaveBalance == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Leave Balance',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ..._leaveBalance!.leaveTypes.entries.map((entry) {
              final leaveType = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(entry.key),
                    Row(
                      children: [
                        Text(
                          '${leaveType.remaining}/${leaveType.allocated}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: leaveType.remaining > 0
                                ? Colors.green
                                : Colors.red,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'days',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaveTypeDropdown() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Leave Type *',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedLeaveTypeId,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: _leaveTypes.map((type) {
                return DropdownMenuItem(
                  value: type.id,
                  child: Text(type.name),
                );
              }).toList(),
              onChanged: (value) {
                setState(() => _selectedLeaveTypeId = value);
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please select leave type';
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
              'Leave Period *',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildDateField(
                    label: 'Start Date',
                    date: _startDate,
                    onTap: () => _selectDate(isStartDate: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDateField(
                    label: 'End Date',
                    date: _endDate,
                    onTap: () => _selectDate(isStartDate: false),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.calendar_today),
        ),
        child: Text(
          date != null ? DateFormat('MMM d, y').format(date) : 'Select',
          style: TextStyle(
            color: date != null ? Colors.black87 : Colors.grey,
          ),
        ),
      ),
    );
  }

  Future<void> _selectDate({required bool isStartDate}) async {
    final initialDate = isStartDate
        ? (_startDate ?? DateTime.now())
        : (_endDate ?? _startDate ?? DateTime.now());

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
          if (_endDate != null && _endDate!.isBefore(picked)) {
            _endDate = picked;
          }
        } else {
          _endDate = picked;
        }
      });
      _calculateLeaveDates();
    }
  }

  Widget _buildLeaveSummaryCard() {
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  'Leave Summary',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Total working days: ${_calculatedLeaveDates.length}',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            const Text(
              'Leave dates (excluding weekends & holidays):',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: _calculatedLeaveDates.map((date) {
                return Chip(
                  label: Text(
                    DateFormat('MMM d').format(date),
                    style: const TextStyle(fontSize: 11),
                  ),
                  backgroundColor: Colors.blue.shade100,
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                );
              }).toList(),
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
        hintText: 'Enter reason for leave',
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
          : _submitLeaveRequest,
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
              'Submit Leave Request',
              style: TextStyle(fontSize: 16, color: Colors.white),
            ),
    );
  }
}
