import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../data/repositories/student_leave_repository.dart';
import '../../../domain/entities/student.dart';
import '../../../domain/entities/student_leave.dart';
import '../../../core/providers/auth_provider.dart';

class ApplyStudentLeaveScreen extends ConsumerStatefulWidget {
  final Student student;
  final String schoolId;

  const ApplyStudentLeaveScreen({super.key, required this.student, required this.schoolId});

  @override
  ConsumerState<ApplyStudentLeaveScreen> createState() => _ApplyStudentLeaveScreenState();
}

class _ApplyStudentLeaveScreenState extends ConsumerState<ApplyStudentLeaveScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  StudentLeaveType _selectedType = StudentLeaveType.CASUAL_LEAVE;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isSubmitting = false;

  static const Color _bgDark = Color(0xFF0D1117);
  static const Color _cardDark = Color(0xFF161B22);
  static const Color _accentBlue = Color(0xFF4CAF50);
  static const Color _textPrimary = Color(0xFFE6EDF3);
  static const Color _textSecondary = Color(0xFF8B949E);
  static const Color _borderColor = Color(0xFF30363D);

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  int _calculateDays() {
    if (_startDate == null || _endDate == null) return 0;
    return _endDate!.difference(_startDate!).inDays + 1;
  }

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? (_startDate ?? DateTime.now()) : (_endDate ?? _startDate ?? DateTime.now()),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(primary: _accentBlue, surface: _cardDark),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_endDate != null && _endDate!.isBefore(picked)) _endDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _submitLeave() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select start and end dates'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final session = ref.read(currentSessionProvider);
      final repo = ref.read(studentLeaveRepositoryProvider);
      final now = DateTime.now();

      final request = StudentLeaveRequest(
        id: '',
        schoolId: widget.schoolId,
        studentId: widget.student.id,
        studentName: widget.student.name,
        studentNumericId: widget.student.studentId,
        className: widget.student.className,
        section: widget.student.section,
        parentName: widget.student.parentName,
        parentPhone: widget.student.parentPhone,
        appliedByUserId: session?.uid,
        leaveType: _selectedType,
        startDate: _startDate!,
        endDate: _endDate!,
        totalDays: _calculateDays(),
        reason: _reasonController.text.trim(),
        status: StudentLeaveStatus.PENDING,
        createdAt: now,
        updatedAt: now,
      );

      await repo.applyLeave(widget.schoolId, request);

      if (mounted) {
        _reasonController.clear();
        setState(() {
          _startDate = null;
          _endDate = null;
          _selectedType = StudentLeaveType.CASUAL_LEAVE;
          _isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Leave request submitted successfully!'), backgroundColor: Color(0xFF10B981)),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 1024;
    final formWidth = isDesktop ? 600.0 : double.infinity;

    return Container(
      color: _bgDark,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(isDesktop ? 24 : 16),
        child: Center(
          child: SizedBox(
            width: formWidth,
            child: Form(
              key: _formKey,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Student info header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _accentBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _accentBlue.withOpacity(0.3)),
                  ),
                  child: Row(children: [
                    CircleAvatar(backgroundColor: _accentBlue, radius: 20,
                      child: Text(widget.student.name[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                    const SizedBox(width: 12),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(widget.student.name, style: const TextStyle(color: _textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
                      Text('Class ${widget.student.className} - ${widget.student.section}', style: const TextStyle(color: _textSecondary, fontSize: 12)),
                    ]),
                  ]),
                ),
                const SizedBox(height: 24),

                // Leave Type
                const Text('Leave Type', style: TextStyle(color: _textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(color: _cardDark, borderRadius: BorderRadius.circular(10), border: Border.all(color: _borderColor)),
                  child: DropdownButtonFormField<StudentLeaveType>(
                    value: _selectedType,
                    dropdownColor: _cardDark,
                    style: const TextStyle(color: _textPrimary, fontSize: 13),
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: InputBorder.none,
                    ),
                    items: StudentLeaveType.values.map((type) {
                      return DropdownMenuItem(value: type, child: Text(_leaveTypeLabel(type)));
                    }).toList(),
                    onChanged: (val) { if (val != null) setState(() => _selectedType = val); },
                  ),
                ),
                const SizedBox(height: 20),

                // Date pickers
                Row(children: [
                  Expanded(child: _buildDateField('Start Date', _startDate, () => _pickDate(true))),
                  const SizedBox(width: 12),
                  Expanded(child: _buildDateField('End Date', _endDate, () => _pickDate(false))),
                ]),
                if (_startDate != null && _endDate != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: _accentBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                    child: Text('Duration: ${_calculateDays()} day(s)', style: const TextStyle(color: _accentBlue, fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ],
                const SizedBox(height: 20),

                // Reason
                const Text('Reason', style: TextStyle(color: _textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _reasonController,
                  maxLines: 4,
                  style: const TextStyle(color: _textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Please provide the reason for leave...',
                    hintStyle: TextStyle(color: _textSecondary.withOpacity(0.6)),
                    filled: true,
                    fillColor: _cardDark,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _borderColor)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _borderColor)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _accentBlue)),
                    contentPadding: const EdgeInsets.all(14),
                  ),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Please provide a reason' : null,
                ),
                const SizedBox(height: 28),

                // Submit button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitLeave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accentBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Submit Leave Request', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDateField(String label, DateTime? date, VoidCallback onTap) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: _textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(color: _cardDark, borderRadius: BorderRadius.circular(10), border: Border.all(color: _borderColor)),
          child: Row(children: [
            const Icon(Icons.calendar_today_rounded, color: _textSecondary, size: 16),
            const SizedBox(width: 8),
            Text(
              date != null ? DateFormat('dd MMM yyyy').format(date) : 'Select date',
              style: TextStyle(color: date != null ? _textPrimary : _textSecondary.withOpacity(0.6), fontSize: 13),
            ),
          ]),
        ),
      ),
    ]);
  }

  String _leaveTypeLabel(StudentLeaveType type) {
    switch (type) {
      case StudentLeaveType.SICK_LEAVE: return 'Sick Leave';
      case StudentLeaveType.CASUAL_LEAVE: return 'Casual Leave';
      case StudentLeaveType.PERMISSION: return 'Permission';
      case StudentLeaveType.FAMILY_EMERGENCY: return 'Family Emergency';
      case StudentLeaveType.OTHER: return 'Other';
    }
  }
}
