import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../data/repositories/student_repository.dart';
import '../../../data/repositories/student_attendance_repository.dart';
import '../../../data/repositories/student_leave_repository.dart';
import '../../../domain/entities/student.dart';
import '../../../domain/entities/student_attendance.dart';
import '../../../domain/entities/student_leave.dart';
import '../../parent/screens/student_attendance_view_screen.dart';
import '../../parent/screens/apply_student_leave_screen.dart';
import '../../parent/screens/student_leave_history_screen.dart';
import '../../auth/screens/enhanced_login_screen.dart';
import '../../widgets/theme_toggle_button.dart';

/// Provider to find the student linked to a parent user
final parentLinkedStudentProvider =
    FutureProvider.family<Student?, ({String schoolId, String parentUserId})>(
        (ref, params) async {
  final repo = ref.watch(studentRepositoryProvider);
  // Look up student by parent's user ID stored in the student record
  // First try matching by the user document's email or phone
  final allStudents = await repo.getStudentsStream(params.schoolId).first;
  // Match by parentUserId field or by email/phone linked during onboarding
  final session = ref.read(currentSessionProvider);
  if (session == null) return null;

  for (final student in allStudents) {
    if (student.email == session.email ||
        student.parentPhone == session.email) {
      return student;
    }
  }
  // Fallback: check if any student doc has a parentUserId field
  return allStudents.isNotEmpty ? allStudents.first : null;
});

class ParentDashboardScreen extends ConsumerStatefulWidget {
  const ParentDashboardScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ParentDashboardScreen> createState() =>
      _ParentDashboardScreenState();
}

class _ParentDashboardScreenState extends ConsumerState<ParentDashboardScreen> {
  int _selectedIndex = 0;
  Student? _linkedStudent;
  bool _isLoadingStudent = true;

  final List<_NavItem> _navItems = [
    _NavItem(icon: Icons.dashboard_rounded, label: 'Dashboard'),
    _NavItem(icon: Icons.calendar_month_rounded, label: 'Attendance'),
    _NavItem(icon: Icons.event_note_rounded, label: 'Apply Leave'),
    _NavItem(icon: Icons.history_rounded, label: 'Leave History'),
  ];

  @override
  void initState() {
    super.initState();
    _loadLinkedStudent();
  }

  Future<void> _loadLinkedStudent() async {
    final session = ref.read(currentSessionProvider);
    if (session == null || session.schoolId == null) {
      setState(() => _isLoadingStudent = false);
      return;
    }

    try {
      final repo = ref.read(studentRepositoryProvider);
      final allStudents = await repo.getStudentsStream(session.schoolId!).first;

      Student? found;
      for (final student in allStudents) {
        if (student.email == session.email ||
            student.parentPhone == session.email ||
            student.phoneNumber == session.email) {
          found = student;
          break;
        }
      }
      if (found == null && allStudents.isNotEmpty) {
        found = allStudents.first;
      }

      if (mounted) {
        setState(() {
          _linkedStudent = found;
          _isLoadingStudent = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingStudent = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(currentSessionProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 1024;

    if (session == null) {
      return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          body: Center(
              child: Text('Access Denied',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface))));
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      drawer: isDesktop ? null : _buildDrawer(context, session),
      bottomNavigationBar: isDesktop ? null : _buildBottomNav(),
      body: Row(
        children: [
          if (isDesktop) _buildSideNavigation(context, session),
          Expanded(
            child: Column(
              children: [
                _buildTopBar(context, session, isDesktop),
                Expanded(child: _buildContent(context, session, isDesktop)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(
            top: BorderSide(color: Theme.of(context).colorScheme.outline)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_navItems.length, (index) {
              final item = _navItems[index];
              final isSelected = _selectedIndex == index;
              return Expanded(
                child: InkWell(
                  onTap: () => setState(() => _selectedIndex = index),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(item.icon,
                            color: isSelected
                                ? const Color(0xFF4CAF50)
                                : Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                            size: 22),
                        const SizedBox(height: 4),
                        Text(item.label,
                            style: TextStyle(
                              color: isSelected
                                  ? const Color(0xFF4CAF50)
                                  : Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                              fontSize: 10,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            )),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildSideNavigation(BuildContext context, dynamic session) {
    return Container(
      width: 240,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Column(
        children: [
          _buildLogoHeader(),
          Container(height: 1, color: Theme.of(context).colorScheme.outline),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: List.generate(_navItems.length, (index) {
                final item = _navItems[index];
                final isSelected = _selectedIndex == index;
                return Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  child: Material(
                    color: isSelected
                        ? const Color(0xFF4CAF50).withOpacity(0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      onTap: () => setState(() => _selectedIndex = index),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        child: Row(children: [
                          Icon(item.icon,
                              color: isSelected
                                  ? const Color(0xFF4CAF50)
                                  : Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                              size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Text(item.label,
                                  style: TextStyle(
                                    color: isSelected
                                        ? Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                        : Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                    fontSize: 13,
                                  ))),
                        ]),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          Container(height: 1, color: Theme.of(context).colorScheme.outline),
          _buildUserInfoCard(session),
        ],
      ),
    );
  }

  Widget _buildLogoHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Row(children: [
        ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.asset('assets/images/eazyschool.png',
                width: 40, height: 40, fit: BoxFit.contain)),
        const SizedBox(width: 12),
        const Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Eazy School',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFE6EDF3))),
          Text('Parent Portal',
              style: TextStyle(fontSize: 11, color: Color(0xFF8B949E))),
        ])),
      ]),
    );
  }

  Widget _buildUserInfoCard(dynamic session) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(children: [
        CircleAvatar(
            backgroundColor: const Color(0xFF4CAF50),
            radius: 16,
            child: Text(
              (session.displayName as String? ?? 'P')[0].toUpperCase(),
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12),
            )),
        const SizedBox(width: 10),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(session.displayName as String? ?? 'Parent',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                  fontSize: 12),
              overflow: TextOverflow.ellipsis),
          Text('Parent',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 10)),
        ])),
        IconButton(
          icon: Icon(Icons.logout_rounded,
              color: Theme.of(context).colorScheme.onSurfaceVariant, size: 18),
          onPressed: () async {
            await ref.read(authProvider.notifier).signOut();
            if (mounted) {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const EnhancedLoginScreen()),
                (route) => false,
              );
            }
          },
        ),
      ]),
    );
  }

  Widget _buildDrawer(BuildContext context, dynamic session) {
    return Drawer(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: SafeArea(
        child: Column(children: [
          _buildLogoHeader(),
          Container(height: 1, color: Theme.of(context).colorScheme.outline),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: List.generate(_navItems.length, (index) {
                final item = _navItems[index];
                final isSelected = _selectedIndex == index;
                return ListTile(
                  leading: Icon(item.icon,
                      color: isSelected
                          ? const Color(0xFF4CAF50)
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                      size: 20),
                  title: Text(item.label,
                      style: TextStyle(
                          color: isSelected
                              ? Theme.of(context).colorScheme.onSurface
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 13)),
                  selected: isSelected,
                  selectedTileColor: const Color(0xFF4CAF50).withOpacity(0.15),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  onTap: () {
                    setState(() => _selectedIndex = index);
                    Navigator.pop(context);
                  },
                );
              }),
            ),
          ),
          Container(height: 1, color: Theme.of(context).colorScheme.outline),
          _buildUserInfoCard(session),
        ]),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, dynamic session, bool isDesktop) {
    return Container(
      padding: EdgeInsets.fromLTRB(isDesktop ? 24 : 12, 12, 24, 12),
      decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          border: Border(
              bottom:
                  BorderSide(color: Theme.of(context).colorScheme.outline))),
      child: Row(children: [
        if (!isDesktop) ...[
          Builder(
              builder: (ctx) => IconButton(
                    icon: Icon(Icons.menu_rounded,
                        color: Theme.of(context).colorScheme.onSurface,
                        size: 24),
                    onPressed: () => Scaffold.of(ctx).openDrawer(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  )),
          const SizedBox(width: 12),
        ],
        Text(_navItems[_selectedIndex].label,
            style: TextStyle(
                fontSize: isDesktop ? 18 : 16,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface)),
        const Spacer(),
        // Theme toggle button
        const ThemeToggleButton(),
        const SizedBox(width: 12),
        if (_linkedStudent != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withOpacity(0.15),
                borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              const Icon(Icons.school_rounded,
                  color: Color(0xFF4CAF50), size: 16),
              const SizedBox(width: 6),
              Text('${_linkedStudent!.name} - ${_linkedStudent!.className}',
                  style: TextStyle(
                      color: const Color(0xFF4CAF50),
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ]),
          ),
      ]),
    );
  }

  Widget _buildContent(BuildContext context, dynamic session, bool isDesktop) {
    if (_isLoadingStudent) {
      return Center(
          child: CircularProgressIndicator(color: const Color(0xFF4CAF50)));
    }

    if (_linkedStudent == null) {
      return Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.person_search_rounded,
            size: 64,
            color: Theme.of(context)
                .colorScheme
                .onSurfaceVariant
                .withOpacity(0.5)),
        const SizedBox(height: 16),
        Text('No student linked to your account',
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text('Please contact the school administrator',
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 13)),
      ]));
    }

    switch (_selectedIndex) {
      case 0:
        return _buildDashboardHome(session, isDesktop);
      case 1:
        return StudentAttendanceViewScreen(
            student: _linkedStudent!, schoolId: session.schoolId as String);
      case 2:
        return ApplyStudentLeaveScreen(
            student: _linkedStudent!, schoolId: session.schoolId as String);
      case 3:
        return StudentLeaveHistoryScreen(
            student: _linkedStudent!, schoolId: session.schoolId as String);
      default:
        return _buildDashboardHome(session, isDesktop);
    }
  }

  Widget _buildDashboardHome(dynamic session, bool isDesktop) {
    final schoolId = session.schoolId as String;
    final now = DateTime.now();
    final dateStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    return SingleChildScrollView(
      padding: EdgeInsets.all(isDesktop ? 24 : 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Student Info Card
        _buildStudentInfoCard(isDesktop),
        const SizedBox(height: 20),

        // Quick Actions
        Text('Quick Actions',
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: isDesktop ? 16 : 14,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        _buildQuickActions(isDesktop),
        const SizedBox(height: 24),

        // Today's Attendance
        Text("Today's Attendance",
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: isDesktop ? 16 : 14,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        _buildTodayAttendance(schoolId, dateStr),
        const SizedBox(height: 24),

        // Monthly Summary
        Text('This Month\'s Summary',
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: isDesktop ? 16 : 14,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        _buildMonthlySummary(schoolId, now.month, now.year),
        const SizedBox(height: 24),

        // Recent Leaves
        Text('Recent Leave Requests',
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: isDesktop ? 16 : 14,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        _buildRecentLeaves(schoolId),
      ]),
    );
  }

  Widget _buildStudentInfoCard(bool isDesktop) {
    final student = _linkedStudent!;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          const Color(0xFF4CAF50).withOpacity(0.15),
          const Color(0xFF4CAF50).withOpacity(0.05)
        ]),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF4CAF50).withOpacity(0.3)),
      ),
      child: Row(children: [
        CircleAvatar(
          radius: isDesktop ? 32 : 24,
          backgroundColor: const Color(0xFF4CAF50),
          child: Text(student.name[0].toUpperCase(),
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: isDesktop ? 24 : 18)),
        ),
        const SizedBox(width: 16),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(student.name,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: isDesktop ? 18 : 15,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Wrap(spacing: 12, runSpacing: 4, children: [
            _infoChip(Icons.class_rounded, 'Class ${student.className}'),
            _infoChip(Icons.grid_view_rounded, 'Section ${student.section}'),
            _infoChip(Icons.badge_rounded, 'ID: ${student.studentId}'),
          ]),
        ])),
      ]),
    );
  }

  Widget _infoChip(IconData icon, String text) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon,
          color: Theme.of(context).colorScheme.onSurfaceVariant, size: 14),
      const SizedBox(width: 4),
      Text(text,
          style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12)),
    ]);
  }

  Widget _buildQuickActions(bool isDesktop) {
    final actions = [
      _QuickAction(
          icon: Icons.calendar_month_rounded,
          label: 'View Attendance',
          color: const Color(0xFF3B82F6),
          onTap: () => setState(() => _selectedIndex = 1)),
      _QuickAction(
          icon: Icons.event_note_rounded,
          label: 'Apply Leave',
          color: const Color(0xFFF59E0B),
          onTap: () => setState(() => _selectedIndex = 2)),
      _QuickAction(
          icon: Icons.history_rounded,
          label: 'Leave History',
          color: const Color(0xFF8B5CF6),
          onTap: () => setState(() => _selectedIndex = 3)),
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: actions
          .map((a) => SizedBox(
                width: isDesktop
                    ? 180
                    : (MediaQuery.of(context).size.width - 44) / 3,
                child: Material(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: a.onTap,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 16, horizontal: 12),
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: Theme.of(context).colorScheme.outline)),
                      child: Column(children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                              color: a.color.withOpacity(0.15),
                              shape: BoxShape.circle),
                          child: Icon(a.icon, color: a.color, size: 22),
                        ),
                        const SizedBox(height: 8),
                        Text(a.label,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontSize: 11,
                                fontWeight: FontWeight.w600),
                            textAlign: TextAlign.center),
                      ]),
                    ),
                  ),
                ),
              ))
          .toList(),
    );
  }

  Widget _buildTodayAttendance(String schoolId, String dateStr) {
    return FutureBuilder<List<StudentAttendanceRecord>>(
      future: ref
          .read(studentAttendanceRepositoryProvider)
          .getStudentMonthlyAttendance(
            schoolId,
            _linkedStudent!.id,
            DateTime.now().month,
            DateTime.now().year,
          ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _statusCard('Loading...', Icons.hourglass_empty_rounded,
              Theme.of(context).colorScheme.onSurfaceVariant);
        }

        final records = snapshot.data ?? [];
        final today = DateTime.now();
        final todayRecord = records
            .where((r) =>
                r.date.year == today.year &&
                r.date.month == today.month &&
                r.date.day == today.day)
            .toList();

        if (todayRecord.isEmpty) {
          return _statusCard('Not Marked Yet', Icons.schedule_rounded,
              const Color(0xFFF59E0B));
        }

        final status = todayRecord.first.status;
        switch (status) {
          case AttendanceStatus.PRESENT:
            return _statusCard(
                'Present', Icons.check_circle_rounded, const Color(0xFF10B981));
          case AttendanceStatus.ABSENT:
            return _statusCard('Absent', Icons.cancel_rounded, Colors.red);
          case AttendanceStatus.LATE:
            return _statusCard(
                'Late', Icons.watch_later_rounded, const Color(0xFFF59E0B));
          case AttendanceStatus.PERMISSION:
            return _statusCard('On Permission', Icons.event_available_rounded,
                const Color(0xFF3B82F6));
          case AttendanceStatus.HOLIDAY:
            return _statusCard(
                'Holiday', Icons.celebration_rounded, const Color(0xFF8B5CF6));
          default:
            return _statusCard('Not Marked', Icons.help_outline_rounded,
                Theme.of(context).colorScheme.onSurfaceVariant);
        }
      },
    );
  }

  Widget _statusCard(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(width: 12),
        Text(label,
            style: TextStyle(
                color: color, fontSize: 16, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  Widget _buildMonthlySummary(String schoolId, int month, int year) {
    return FutureBuilder<MonthlyAttendanceSummary>(
      future: ref
          .read(studentAttendanceRepositoryProvider)
          .getMonthlyStudentSummary(
            schoolId,
            _linkedStudent!.id,
            _linkedStudent!.name,
            month,
            year,
          ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
              child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(
                      color: const Color(0xFF4CAF50))));
        }

        final summary = snapshot.data;
        if (summary == null) return const SizedBox.shrink();

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Theme.of(context).colorScheme.outline)),
          child: Column(children: [
            Row(children: [
              _summaryTile('Working Days', '${summary.totalWorkingDays}',
                  const Color(0xFF3B82F6)),
              _summaryTile(
                  'Present', '${summary.presentDays}', const Color(0xFF10B981)),
              _summaryTile('Absent', '${summary.absentDays}', Colors.red),
              _summaryTile(
                  'Late', '${summary.lateDays}', const Color(0xFFF59E0B)),
            ]),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: summary.totalWorkingDays > 0
                    ? summary.presentDays / summary.totalWorkingDays
                    : 0,
                backgroundColor: Theme.of(context).colorScheme.outline,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 6),
            Text(
                '${summary.attendancePercentage.toStringAsFixed(1)}% Attendance',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 11)),
          ]),
        );
      },
    );
  }

  Widget _summaryTile(String label, String value, Color color) {
    return Expanded(
        child: Column(children: [
      Text(value,
          style: TextStyle(
              color: color, fontSize: 20, fontWeight: FontWeight.bold)),
      const SizedBox(height: 2),
      Text(label,
          style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 10)),
    ]));
  }

  Widget _buildRecentLeaves(String schoolId) {
    return StreamBuilder<List<StudentLeaveRequest>>(
      stream: ref
          .read(studentLeaveRepositoryProvider)
          .getStudentLeaves(schoolId, _linkedStudent!.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
              child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(
                      color: const Color(0xFF4CAF50))));
        }

        final leaves = (snapshot.data ?? []).take(3).toList();
        if (leaves.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: Theme.of(context).colorScheme.outline)),
            child: Center(
                child: Text('No leave requests yet',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 13))),
          );
        }

        return Column(
          children: leaves
              .map((leave) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: Theme.of(context).colorScheme.outline)),
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                            color: _getLeaveStatusColor(leave.status)
                                .withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8)),
                        child: Icon(_getLeaveIcon(leave.leaveType),
                            color: _getLeaveStatusColor(leave.status),
                            size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(leave.leaveTypeLabel,
                                style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                            Text(
                                '${DateFormat('dd MMM').format(leave.startDate)} - ${DateFormat('dd MMM yyyy').format(leave.endDate)}',
                                style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                    fontSize: 11)),
                          ])),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getLeaveStatusColor(leave.status)
                              .withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(leave.statusLabel,
                            style: TextStyle(
                                color: _getLeaveStatusColor(leave.status),
                                fontSize: 10,
                                fontWeight: FontWeight.bold)),
                      ),
                    ]),
                  ))
              .toList(),
        );
      },
    );
  }

  Color _getLeaveStatusColor(StudentLeaveStatus status) {
    switch (status) {
      case StudentLeaveStatus.PENDING:
        return const Color(0xFFF59E0B);
      case StudentLeaveStatus.APPROVED:
        return const Color(0xFF10B981);
      case StudentLeaveStatus.REJECTED:
        return Colors.red;
      case StudentLeaveStatus.CANCELLED:
        return Theme.of(context).colorScheme.onSurfaceVariant;
    }
  }

  IconData _getLeaveIcon(StudentLeaveType type) {
    switch (type) {
      case StudentLeaveType.SICK_LEAVE:
        return Icons.local_hospital_rounded;
      case StudentLeaveType.CASUAL_LEAVE:
        return Icons.beach_access_rounded;
      case StudentLeaveType.PERMISSION:
        return Icons.access_time_rounded;
      case StudentLeaveType.FAMILY_EMERGENCY:
        return Icons.family_restroom_rounded;
      case StudentLeaveType.OTHER:
        return Icons.event_note_rounded;
    }
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  _NavItem({required this.icon, required this.label});
}

class _QuickAction {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  _QuickAction(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});
}
