import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../domain/entities/staff_attendance.dart';
import '../../../data/repositories/staff_attendance_repository.dart';
import '../widgets/attendance_statistics_card.dart';
import '../widgets/attendance_detail_dialog.dart';
import '../../leave/screens/apply_leave_screen.dart';
import '../../permission/screens/apply_permission_screen.dart';

class StaffAttendanceDashboardScreen extends StatefulWidget {
  final String schoolId;
  final String staffId;

  const StaffAttendanceDashboardScreen({
    Key? key,
    required this.schoolId,
    required this.staffId,
  }) : super(key: key);

  @override
  State<StaffAttendanceDashboardScreen> createState() =>
      _StaffAttendanceDashboardScreenState();
}

class _StaffAttendanceDashboardScreenState
    extends State<StaffAttendanceDashboardScreen> {
  final _repository = StaffAttendanceRepository();
  
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  Map<DateTime, StaffAttendance> _attendanceMap = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMonthlyAttendance();
  }

  Future<void> _loadMonthlyAttendance() async {
    setState(() => _isLoading = true);
    
    try {
      final startDate = DateTime(_focusedDay.year, _focusedDay.month, 1);
      final endDate = DateTime(_focusedDay.year, _focusedDay.month + 1, 0);

      final attendanceList = await _repository
          .getStaffAttendance(
            schoolId: widget.schoolId,
            staffId: widget.staffId,
            startDate: startDate,
            endDate: endDate,
          )
          .first;

      final Map<DateTime, StaffAttendance> map = {};
      for (final attendance in attendanceList) {
        final date = DateTime(
          attendance.date.year,
          attendance.date.month,
          attendance.date.day,
        );
        map[date] = attendance;
      }

      setState(() {
        _attendanceMap = map;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading attendance: $e')),
        );
      }
    }
  }

  Color _getColorForStatus(StaffAttendanceStatus status) {
    switch (status) {
      case StaffAttendanceStatus.PRESENT:
        return Colors.green;
      case StaffAttendanceStatus.ABSENT:
        return Colors.orange;
      case StaffAttendanceStatus.LEAVE:
        return Colors.yellow.shade700;
      case StaffAttendanceStatus.PERMISSION:
        return Colors.blue;
      case StaffAttendanceStatus.LOP:
        return Colors.red;
      case StaffAttendanceStatus.HOLIDAY:
        return Colors.grey;
      case StaffAttendanceStatus.PARTIAL:
        return Colors.amber;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Attendance'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMonthlyAttendance,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  _buildStatisticsSection(),
                  const Divider(),
                  _buildCalendarSection(),
                  const Divider(),
                  _buildLegendSection(),
                  const SizedBox(height: 16),
                  _buildQuickActionsSection(),
                  const SizedBox(height: 80),
                ],
              ),
            ),
    );
  }

  Widget _buildStatisticsSection() {
    return FutureBuilder<AttendanceStatistics>(
      future: _repository.getAttendanceStatistics(
        schoolId: widget.schoolId,
        staffId: widget.staffId,
        startDate: DateTime(_focusedDay.year, _focusedDay.month, 1),
        endDate: DateTime(_focusedDay.year, _focusedDay.month + 1, 0),
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(height: 120);
        }

        final stats = snapshot.data!;
        return AttendanceStatisticsCard(statistics: stats);
      },
    );
  }

  Widget _buildCalendarSection() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: TableCalendar(
        firstDay: DateTime.utc(2020, 1, 1),
        lastDay: DateTime.utc(2030, 12, 31),
        focusedDay: _focusedDay,
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        calendarFormat: CalendarFormat.month,
        startingDayOfWeek: StartingDayOfWeek.monday,
        onDaySelected: (selectedDay, focusedDay) {
          setState(() {
            _selectedDay = selectedDay;
            _focusedDay = focusedDay;
          });
          _showAttendanceDetail(selectedDay);
        },
        onPageChanged: (focusedDay) {
          _focusedDay = focusedDay;
          _loadMonthlyAttendance();
        },
        calendarStyle: CalendarStyle(
          todayDecoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.3),
            shape: BoxShape.circle,
          ),
          selectedDecoration: const BoxDecoration(
            color: Colors.blue,
            shape: BoxShape.circle,
          ),
        ),
        calendarBuilders: CalendarBuilders(
          defaultBuilder: (context, day, focusedDay) {
            return _buildCalendarDay(day);
          },
          todayBuilder: (context, day, focusedDay) {
            return _buildCalendarDay(day, isToday: true);
          },
        ),
      ),
    );
  }

  Widget _buildCalendarDay(DateTime day, {bool isToday = false}) {
    final dateKey = DateTime(day.year, day.month, day.day);
    final attendance = _attendanceMap[dateKey];

    if (attendance == null) {
      return Center(
        child: Text(
          '${day.day}',
          style: TextStyle(
            color: isToday ? Colors.blue : Colors.black87,
            fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      );
    }

    final color = _getColorForStatus(attendance.status);

    return Stack(
      children: [
        Container(
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.3),
            shape: BoxShape.circle,
            border: Border.all(
              color: color,
              width: 2,
            ),
          ),
          child: Center(
            child: Text(
              '${day.day}',
              style: TextStyle(
                color: Colors.black87,
                fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),
        if (attendance.isLate)
          Positioned(
            top: 2,
            right: 2,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLegendSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Legend',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _buildLegendItem('Present', Colors.green),
              _buildLegendItem('Absent', Colors.orange),
              _buildLegendItem('Leave', Colors.yellow.shade700),
              _buildLegendItem('Permission', Colors.blue),
              _buildLegendItem('LOP', Colors.red),
              _buildLegendItem('Holiday', Colors.grey),
              _buildLegendItem('Partial', Colors.amber),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              const Text('Red dot = Late arrival'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color.withOpacity(0.3),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
          ),
        ),
        const SizedBox(width: 4),
        Text(label),
      ],
    );
  }

  Widget _buildQuickActionsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ApplyLeaveScreen(
                          schoolId: widget.schoolId,
                          staffId: widget.staffId,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.event_busy),
                  label: const Text('Apply Leave'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ApplyPermissionScreen(
                          schoolId: widget.schoolId,
                          staffId: widget.staffId,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.access_time),
                  label: const Text('Apply Permission'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAttendanceDetail(DateTime date) {
    final dateKey = DateTime(date.year, date.month, date.day);
    final attendance = _attendanceMap[dateKey];

    if (attendance == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No attendance record for this date')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AttendanceDetailDialog(attendance: attendance),
    );
  }
}
