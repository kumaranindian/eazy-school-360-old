import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../data/repositories/student_attendance_repository.dart';
import '../../../domain/entities/student.dart';
import '../../../domain/entities/student_attendance.dart';

class StudentAttendanceViewScreen extends ConsumerStatefulWidget {
  final Student student;
  final String schoolId;

  const StudentAttendanceViewScreen({super.key, required this.student, required this.schoolId});

  @override
  ConsumerState<StudentAttendanceViewScreen> createState() => _StudentAttendanceViewScreenState();
}

class _StudentAttendanceViewScreenState extends ConsumerState<StudentAttendanceViewScreen> {
  late int _selectedMonth;
  late int _selectedYear;
  List<StudentAttendanceRecord> _records = [];
  MonthlyAttendanceSummary? _summary;
  bool _isLoading = true;

  static const Color _bgDark = Color(0xFF0D1117);
  static const Color _cardDark = Color(0xFF161B22);
  static const Color _accentBlue = Color(0xFF4CAF50);
  static const Color _textPrimary = Color(0xFFE6EDF3);
  static const Color _textSecondary = Color(0xFF8B949E);
  static const Color _borderColor = Color(0xFF30363D);

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = now.month;
    _selectedYear = now.year;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(studentAttendanceRepositoryProvider);
      final records = await repo.getStudentMonthlyAttendance(
        widget.schoolId, widget.student.id, _selectedMonth, _selectedYear,
      );
      final summary = await repo.getMonthlyStudentSummary(
        widget.schoolId, widget.student.id, widget.student.name, _selectedMonth, _selectedYear,
      );
      if (mounted) {
        setState(() {
          _records = records;
          _summary = summary;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 1024;

    return Container(
      color: _bgDark,
      child: Column(
        children: [
          _buildMonthSelector(),
          if (_summary != null) _buildSummaryBar(isDesktop),
          Expanded(child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: _accentBlue))
            : _buildCalendarView(isDesktop),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(color: _cardDark, border: Border(bottom: BorderSide(color: _borderColor))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded, color: _textPrimary),
            onPressed: () {
              setState(() {
                if (_selectedMonth == 1) { _selectedMonth = 12; _selectedYear--; }
                else { _selectedMonth--; }
              });
              _loadData();
            },
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(color: _accentBlue.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
            child: Text(
              DateFormat('MMMM yyyy').format(DateTime(_selectedYear, _selectedMonth)),
              style: const TextStyle(color: _accentBlue, fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded, color: _textPrimary),
            onPressed: () {
              final now = DateTime.now();
              if (_selectedYear < now.year || (_selectedYear == now.year && _selectedMonth < now.month)) {
                setState(() {
                  if (_selectedMonth == 12) { _selectedMonth = 1; _selectedYear++; }
                  else { _selectedMonth++; }
                });
                _loadData();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryBar(bool isDesktop) {
    final s = _summary!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(color: _cardDark, border: Border(bottom: BorderSide(color: _borderColor))),
      child: Column(children: [
        Row(children: [
          _summaryChip('Working\nDays', '${s.totalWorkingDays}', const Color(0xFF3B82F6)),
          _summaryChip('Present', '${s.presentDays}', const Color(0xFF10B981)),
          _summaryChip('Absent', '${s.absentDays}', Colors.red),
          _summaryChip('Late', '${s.lateDays}', const Color(0xFFF59E0B)),
          _summaryChip('Permission', '${s.permissionDays}', const Color(0xFF8B5CF6)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: s.totalWorkingDays > 0 ? s.presentDays / s.totalWorkingDays : 0,
              backgroundColor: _borderColor,
              valueColor: AlwaysStoppedAnimation<Color>(
                s.attendancePercentage >= 75 ? const Color(0xFF10B981) : Colors.red,
              ),
              minHeight: 6,
            ),
          )),
          const SizedBox(width: 12),
          Text('${s.attendancePercentage.toStringAsFixed(1)}%', style: TextStyle(
            color: s.attendancePercentage >= 75 ? const Color(0xFF10B981) : Colors.red,
            fontSize: 14, fontWeight: FontWeight.bold,
          )),
        ]),
      ]),
    );
  }

  Widget _summaryChip(String label, String value, Color color) {
    return Expanded(child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Column(children: [
        Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: _textSecondary, fontSize: 9), textAlign: TextAlign.center),
      ]),
    ));
  }

  Widget _buildCalendarView(bool isDesktop) {
    final firstDayOfMonth = DateTime(_selectedYear, _selectedMonth, 1);
    final lastDayOfMonth = DateTime(_selectedYear, _selectedMonth + 1, 0);
    final startWeekday = firstDayOfMonth.weekday; // 1=Mon, 7=Sun
    final daysInMonth = lastDayOfMonth.day;

    // Map records by day
    final dayMap = <int, StudentAttendanceRecord>{};
    for (final r in _records) {
      dayMap[r.date.day] = r;
    }

    final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final cellSize = isDesktop ? 56.0 : (MediaQuery.of(context).size.width - 32) / 7;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Day name headers
        Row(children: dayNames.map((d) => SizedBox(
          width: cellSize,
          child: Center(child: Text(d, style: const TextStyle(color: _textSecondary, fontSize: 11, fontWeight: FontWeight.w600))),
        )).toList()),
        const SizedBox(height: 8),
        // Calendar grid
        Wrap(
          children: List.generate(startWeekday - 1 + daysInMonth, (index) {
            if (index < startWeekday - 1) {
              return SizedBox(width: cellSize, height: cellSize);
            }
            final day = index - startWeekday + 2;
            final record = dayMap[day];
            final isFuture = DateTime(_selectedYear, _selectedMonth, day).isAfter(DateTime.now());

            Color bgColor = Colors.transparent;
            Color textColor = _textSecondary;
            IconData? icon;

            if (record != null) {
              switch (record.status) {
                case AttendanceStatus.PRESENT:
                  bgColor = const Color(0xFF10B981).withOpacity(0.15);
                  textColor = const Color(0xFF10B981);
                  icon = Icons.check_rounded;
                  break;
                case AttendanceStatus.ABSENT:
                  bgColor = Colors.red.withOpacity(0.15);
                  textColor = Colors.red;
                  icon = Icons.close_rounded;
                  break;
                case AttendanceStatus.LATE:
                  bgColor = const Color(0xFFF59E0B).withOpacity(0.15);
                  textColor = const Color(0xFFF59E0B);
                  icon = Icons.watch_later_rounded;
                  break;
                case AttendanceStatus.PERMISSION:
                  bgColor = const Color(0xFF3B82F6).withOpacity(0.15);
                  textColor = const Color(0xFF3B82F6);
                  icon = Icons.event_available_rounded;
                  break;
                case AttendanceStatus.HOLIDAY:
                  bgColor = const Color(0xFF8B5CF6).withOpacity(0.15);
                  textColor = const Color(0xFF8B5CF6);
                  icon = Icons.celebration_rounded;
                  break;
                default:
                  break;
              }
            }

            return SizedBox(
              width: cellSize,
              height: cellSize,
              child: Container(
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: isFuture ? Colors.transparent : bgColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isFuture ? _borderColor.withOpacity(0.3) : _borderColor),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('$day', style: TextStyle(color: isFuture ? _textSecondary.withOpacity(0.4) : textColor, fontSize: 12, fontWeight: FontWeight.w600)),
                    if (icon != null) Icon(icon, color: textColor, size: 14),
                  ],
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 20),
        // Legend
        Wrap(spacing: 16, runSpacing: 8, children: [
          _legendItem(const Color(0xFF10B981), 'Present'),
          _legendItem(Colors.red, 'Absent'),
          _legendItem(const Color(0xFFF59E0B), 'Late'),
          _legendItem(const Color(0xFF3B82F6), 'Permission'),
          _legendItem(const Color(0xFF8B5CF6), 'Holiday'),
        ]),
        const SizedBox(height: 20),
        // Daily list
        if (_records.isNotEmpty) ...[
          const Text('Day-wise Details', style: TextStyle(color: _textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          ...(_records.reversed.map((r) => Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(color: _cardDark, borderRadius: BorderRadius.circular(8), border: Border.all(color: _borderColor)),
            child: Row(children: [
              Text(DateFormat('dd MMM, EEE').format(r.date), style: const TextStyle(color: _textPrimary, fontSize: 12, fontWeight: FontWeight.w500)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: _getStatusColor(r.status).withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                child: Text(r.status.name, style: TextStyle(color: _getStatusColor(r.status), fontSize: 10, fontWeight: FontWeight.bold)),
              ),
              if (r.remarks != null && r.remarks!.isNotEmpty) ...[
                const SizedBox(width: 8),
                Tooltip(message: r.remarks!, child: const Icon(Icons.info_outline_rounded, color: _textSecondary, size: 14)),
              ],
            ]),
          ))),
        ],
      ]),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 12, height: 12, decoration: BoxDecoration(color: color.withOpacity(0.3), borderRadius: BorderRadius.circular(3), border: Border.all(color: color, width: 1.5))),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(color: _textSecondary, fontSize: 11)),
    ]);
  }

  Color _getStatusColor(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.PRESENT: return const Color(0xFF10B981);
      case AttendanceStatus.ABSENT: return Colors.red;
      case AttendanceStatus.LATE: return const Color(0xFFF59E0B);
      case AttendanceStatus.PERMISSION: return const Color(0xFF3B82F6);
      case AttendanceStatus.HOLIDAY: return const Color(0xFF8B5CF6);
      default: return _textSecondary;
    }
  }
}
