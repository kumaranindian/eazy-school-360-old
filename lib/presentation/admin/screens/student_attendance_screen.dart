import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../data/repositories/student_repository.dart';
import '../../../data/repositories/student_attendance_repository.dart';
import '../../../domain/entities/student.dart';
import '../../../domain/entities/student_attendance.dart';
import '../../../data/services/whatsapp_notification_service.dart';

class StudentAttendanceScreen extends ConsumerStatefulWidget {
  const StudentAttendanceScreen({super.key});

  @override
  ConsumerState<StudentAttendanceScreen> createState() => _StudentAttendanceScreenState();
}

class _StudentAttendanceScreenState extends ConsumerState<StudentAttendanceScreen> {
  DateTime _selectedDate = DateTime.now();
  String? _selectedClass;
  String? _selectedSection;
  List<String> _classes = [];
  List<String> _sections = [];
  List<Student> _students = [];
  Map<String, AttendanceStatus> _attendanceMap = {};
  Map<String, String> _remarksMap = {};
  bool _isLoadingClasses = true;
  bool _isLoadingStudents = false;
  bool _isSaving = false;
  bool _isSendingNotifications = false;

  static const Color _bgDark = Color(0xFF0D1117);
  static const Color _cardDark = Color(0xFF161B22);
  static const Color _accentBlue = Color(0xFF4CAF50);
  static const Color _textPrimary = Color(0xFFE6EDF3);
  static const Color _textSecondary = Color(0xFF8B949E);
  static const Color _borderColor = Color(0xFF30363D);

  @override
  void initState() {
    super.initState();
    _loadClasses();
  }

  Future<void> _loadClasses() async {
    final session = ref.read(currentSessionProvider);
    if (session == null || session.schoolId == null) return;
    try {
      final repo = ref.read(studentRepositoryProvider);
      final classes = await repo.getClasses(session.schoolId!);
      if (mounted) setState(() { _classes = classes; _isLoadingClasses = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoadingClasses = false);
    }
  }

  Future<void> _loadSections() async {
    if (_selectedClass == null) return;
    final session = ref.read(currentSessionProvider);
    if (session == null || session.schoolId == null) return;
    try {
      final repo = ref.read(studentRepositoryProvider);
      final sections = await repo.getSections(session.schoolId!, _selectedClass!);
      if (mounted) setState(() { _sections = sections; _selectedSection = sections.isNotEmpty ? sections.first : null; });
      if (_selectedSection != null) _loadStudents();
    } catch (_) {}
  }

  Future<void> _loadStudents() async {
    if (_selectedClass == null || _selectedSection == null) return;
    final session = ref.read(currentSessionProvider);
    if (session == null || session.schoolId == null) return;

    setState(() => _isLoadingStudents = true);
    try {
      final studentRepo = ref.read(studentRepositoryProvider);
      final attendanceRepo = ref.read(studentAttendanceRepositoryProvider);

      final students = await studentRepo.getStudentsByClassStream(session.schoolId!, _selectedClass!).first;
      final sectionStudents = students.where((s) => s.section == _selectedSection).toList();

      // Load existing attendance for this date
      final dateStr = _dateToString(_selectedDate);
      final classRecords = await attendanceRepo.getClassAttendanceStream(
        session.schoolId!, _selectedClass!, _selectedSection!, dateStr,
      ).first;

      final map = <String, AttendanceStatus>{};
      final remarks = <String, String>{};
      for (final r in classRecords) {
        map[r.studentId] = r.status;
        if (r.remarks != null && r.remarks!.isNotEmpty) remarks[r.studentId] = r.remarks!;
      }

      if (mounted) {
        setState(() {
          _students = sectionStudents;
          _attendanceMap = map;
          _remarksMap = remarks;
          _isLoadingStudents = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingStudents = false);
    }
  }

  Future<void> _saveAttendance() async {
    final session = ref.read(currentSessionProvider);
    if (session == null || session.schoolId == null) return;
    if (_students.isEmpty) return;

    // Validate all marked
    final unmarked = _students.where((s) => !_attendanceMap.containsKey(s.id)).toList();
    if (unmarked.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${unmarked.length} student(s) not marked yet'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final repo = ref.read(studentAttendanceRepositoryProvider);
      final records = _students.map((s) => StudentAttendanceRecord(
        id: '',
        schoolId: session.schoolId!,
        studentId: s.id,
        studentName: s.name,
        studentNumericId: s.studentId,
        className: s.className,
        section: s.section,
        date: _selectedDate,
        status: _attendanceMap[s.id] ?? AttendanceStatus.NOT_MARKED,
        remarks: _remarksMap[s.id],
        markedBy: session.uid,
        markedAt: DateTime.now(),
        parentPhone: s.parentPhone,
      )).toList();

      await repo.bulkMarkAttendance(session.schoolId!, records);

      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Attendance saved successfully!'), backgroundColor: Color(0xFF10B981)),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _sendNotifications() async {
    final session = ref.read(currentSessionProvider);
    if (session == null || session.schoolId == null) return;

    setState(() => _isSendingNotifications = true);
    try {
      final absentStudents = _students.where((s) =>
        _attendanceMap[s.id] == AttendanceStatus.ABSENT
      ).toList();

      if (absentStudents.isEmpty) {
        if (mounted) {
          setState(() => _isSendingNotifications = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No absent students to notify'), backgroundColor: Color(0xFF3B82F6)),
          );
        }
        return;
      }

      int sent = 0;
      int failed = 0;
      for (final s in absentStudents) {
        if (s.parentPhone != null && s.parentPhone!.isNotEmpty) {
          try {
            await WhatsAppNotificationService.sendAttendanceNotification(
              parentPhone: s.parentPhone!,
              studentName: s.name,
              className: s.className,
              date: _selectedDate,
              status: AttendanceStatus.ABSENT,
              schoolId: session.schoolId!,
            );
            sent++;
          } catch (_) {
            failed++;
          }
        } else {
          failed++;
        }
      }

      if (mounted) {
        setState(() => _isSendingNotifications = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Notifications: $sent sent, $failed failed'),
            backgroundColor: failed == 0 ? const Color(0xFF10B981) : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSendingNotifications = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _markAll(AttendanceStatus status) {
    setState(() {
      for (final s in _students) {
        _attendanceMap[s.id] = status;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 1024;
    final isTablet = screenWidth > 600;

    return Container(
      color: _bgDark,
      child: Column(children: [
        _buildFilterBar(isDesktop),
        if (_selectedClass != null && _selectedSection != null && _students.isNotEmpty)
          _buildActionBar(isDesktop),
        Expanded(child: _buildBody(isDesktop, isTablet)),
      ]),
    );
  }

  Widget _buildFilterBar(bool isDesktop) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 20 : 12, vertical: 12),
      decoration: const BoxDecoration(color: _cardDark, border: Border(bottom: BorderSide(color: _borderColor))),
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Date picker
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime.now().subtract(const Duration(days: 365)),
                lastDate: DateTime.now(),
                builder: (context, child) => Theme(
                  data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: _accentBlue, surface: _cardDark)),
                  child: child!,
                ),
              );
              if (picked != null) {
                setState(() => _selectedDate = picked);
                if (_selectedClass != null && _selectedSection != null) _loadStudents();
              }
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(color: _bgDark, borderRadius: BorderRadius.circular(8), border: Border.all(color: _borderColor)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.calendar_today_rounded, color: _accentBlue, size: 16),
                const SizedBox(width: 8),
                Text(DateFormat('dd MMM yyyy, EEE').format(_selectedDate),
                  style: const TextStyle(color: _textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),

          // Class dropdown
          if (_isLoadingClasses)
            const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: _accentBlue))
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(color: _bgDark, borderRadius: BorderRadius.circular(8), border: Border.all(color: _borderColor)),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedClass,
                  hint: const Text('Select Class', style: TextStyle(color: _textSecondary, fontSize: 13)),
                  dropdownColor: _cardDark,
                  style: const TextStyle(color: _textPrimary, fontSize: 13),
                  items: _classes.map((c) => DropdownMenuItem(value: c, child: Text('Class $c'))).toList(),
                  onChanged: (val) {
                    setState(() { _selectedClass = val; _selectedSection = null; _students = []; _attendanceMap = {}; });
                    _loadSections();
                  },
                ),
              ),
            ),

          // Section dropdown
          if (_sections.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(color: _bgDark, borderRadius: BorderRadius.circular(8), border: Border.all(color: _borderColor)),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedSection,
                  hint: const Text('Section', style: TextStyle(color: _textSecondary, fontSize: 13)),
                  dropdownColor: _cardDark,
                  style: const TextStyle(color: _textPrimary, fontSize: 13),
                  items: _sections.map((s) => DropdownMenuItem(value: s, child: Text('Section $s'))).toList(),
                  onChanged: (val) {
                    setState(() { _selectedSection = val; _students = []; _attendanceMap = {}; });
                    _loadStudents();
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionBar(bool isDesktop) {
    final marked = _attendanceMap.length;
    final total = _students.length;
    final presentCount = _attendanceMap.values.where((s) => s == AttendanceStatus.PRESENT).length;
    final absentCount = _attendanceMap.values.where((s) => s == AttendanceStatus.ABSENT).length;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 20 : 12, vertical: 10),
      decoration: const BoxDecoration(color: _cardDark, border: Border(bottom: BorderSide(color: _borderColor))),
      child: Wrap(
        spacing: 10,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _miniChip('Total: $total', const Color(0xFF3B82F6)),
          _miniChip('Marked: $marked', _accentBlue),
          _miniChip('Present: $presentCount', const Color(0xFF10B981)),
          _miniChip('Absent: $absentCount', Colors.red),
          const SizedBox(width: 8),
          // Bulk actions
          _actionButton('All Present', Icons.check_circle_rounded, const Color(0xFF10B981), () => _markAll(AttendanceStatus.PRESENT)),
          _actionButton('All Absent', Icons.cancel_rounded, Colors.red, () => _markAll(AttendanceStatus.ABSENT)),
          const SizedBox(width: 8),
          // Save
          ElevatedButton.icon(
            onPressed: _isSaving ? null : _saveAttendance,
            icon: _isSaving
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save_rounded, size: 16),
            label: Text(_isSaving ? 'Saving...' : 'Save', style: const TextStyle(fontSize: 12)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          // Send notifications
          ElevatedButton.icon(
            onPressed: _isSendingNotifications ? null : _sendNotifications,
            icon: _isSendingNotifications
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send_rounded, size: 16),
            label: Text(_isSendingNotifications ? 'Sending...' : 'Notify Parents', style: const TextStyle(fontSize: 12)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
      child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  Widget _actionButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withOpacity(0.3))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  Widget _buildBody(bool isDesktop, bool isTablet) {
    if (_selectedClass == null) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.class_rounded, size: 56, color: _textSecondary.withOpacity(0.4)),
        const SizedBox(height: 16),
        const Text('Select a class and section to mark attendance', style: TextStyle(color: _textSecondary, fontSize: 14)),
      ]));
    }

    if (_isLoadingStudents) {
      return const Center(child: CircularProgressIndicator(color: _accentBlue));
    }

    if (_students.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.people_outline_rounded, size: 56, color: _textSecondary.withOpacity(0.4)),
        const SizedBox(height: 16),
        const Text('No students found in this class/section', style: TextStyle(color: _textSecondary, fontSize: 14)),
      ]));
    }

    return ListView.builder(
      padding: EdgeInsets.all(isDesktop ? 20 : 12),
      itemCount: _students.length,
      itemBuilder: (context, index) => _buildStudentRow(_students[index], index, isDesktop),
    );
  }

  Widget _buildStudentRow(Student student, int index, bool isDesktop) {
    final currentStatus = _attendanceMap[student.id];

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: currentStatus != null
            ? (currentStatus == AttendanceStatus.PRESENT
                ? const Color(0xFF10B981).withOpacity(0.05)
                : currentStatus == AttendanceStatus.ABSENT
                    ? Colors.red.withOpacity(0.05)
                    : _cardDark)
            : _cardDark,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: currentStatus != null
            ? _getStatusColor(currentStatus).withOpacity(0.3)
            : _borderColor),
      ),
      child: Row(children: [
        // Index
        SizedBox(
          width: 28,
          child: Text('${index + 1}', style: const TextStyle(color: _textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
        ),
        // Student info
        Expanded(
          flex: 3,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(student.name, style: const TextStyle(color: _textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
            Text('ID: ${student.studentId}${student.parentPhone != null ? ' • ${student.parentPhone}' : ''}',
              style: const TextStyle(color: _textSecondary, fontSize: 10)),
          ]),
        ),
        // Status buttons
        Expanded(
          flex: isDesktop ? 4 : 3,
          child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            _statusButton(student.id, AttendanceStatus.PRESENT, 'P', const Color(0xFF10B981)),
            const SizedBox(width: 6),
            _statusButton(student.id, AttendanceStatus.ABSENT, 'A', Colors.red),
            const SizedBox(width: 6),
            _statusButton(student.id, AttendanceStatus.LATE, 'L', const Color(0xFFF59E0B)),
            const SizedBox(width: 6),
            _statusButton(student.id, AttendanceStatus.PERMISSION, 'PM', const Color(0xFF3B82F6)),
          ]),
        ),
      ]),
    );
  }

  Widget _statusButton(String studentId, AttendanceStatus status, String label, Color color) {
    final isSelected = _attendanceMap[studentId] == status;
    return InkWell(
      onTap: () => setState(() => _attendanceMap[studentId] = status),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? color : color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isSelected ? color : color.withOpacity(0.3), width: isSelected ? 2 : 1),
        ),
        child: Text(label, style: TextStyle(
          color: isSelected ? Colors.white : color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        )),
      ),
    );
  }

  Color _getStatusColor(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.PRESENT: return const Color(0xFF10B981);
      case AttendanceStatus.ABSENT: return Colors.red;
      case AttendanceStatus.LATE: return const Color(0xFFF59E0B);
      case AttendanceStatus.PERMISSION: return const Color(0xFF3B82F6);
      default: return _textSecondary;
    }
  }

  static String _dateToString(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
