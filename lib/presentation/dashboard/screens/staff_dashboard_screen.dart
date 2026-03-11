import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/security/route_guard.dart';
import '../../../core/security/role_policy.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/leave_application_repository.dart';
import '../../../data/repositories/permission_request_repository.dart';
import '../../../data/repositories/staff_management_repository.dart';
import '../../../data/services/leave_balance_service.dart';
import '../../../data/repositories/permission_type_repository.dart';
import '../../../domain/entities/leave_application.dart';
import '../../../domain/entities/permission_request.dart';
import '../../../domain/entities/permission_type.dart';
import '../../staff/screens/apply_leave_screen.dart';
import '../../staff/screens/request_permission_screen.dart';
import '../../staff/screens/staff_profile_screen.dart';
import '../../auth/screens/enhanced_login_screen.dart';
import '../../shared/screens/holiday_calendar_screen.dart';
import '../../staff/screens/my_payslips_screen.dart';
import '../../staff/screens/class_teacher_leave_screen.dart';

class StaffDashboardScreen extends ConsumerStatefulWidget {
  const StaffDashboardScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<StaffDashboardScreen> createState() => _StaffDashboardScreenState();
}

class _StaffDashboardScreenState extends ConsumerState<StaffDashboardScreen> {
  int _selectedIndex = 0;

  // Dark theme colors - same as Admin dashboard
  static const Color _bgDark = Color(0xFF0D1117);
  static const Color _cardDark = Color(0xFF161B22);
  static const Color _accentBlue = Color(0xFF4CAF50);
  static const Color _textPrimary = Color(0xFFE6EDF3);
  static const Color _textSecondary = Color(0xFF8B949E);
  static const Color _borderColor = Color(0xFF30363D);

  @override
  Widget build(BuildContext context) {
    return RouteGuard(
      route: '/staff-dashboard',
      requiredModule: UIModule.staffDashboard,
      child: _buildDashboard(context),
    );
  }

  Widget _buildDashboard(BuildContext context) {
    final session = ref.watch(currentSessionProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 1024;
    final isTablet = screenWidth > 600 && screenWidth <= 1024;
    
    if (session == null || !session.isStaff) {
      return const Scaffold(backgroundColor: _bgDark, body: Center(child: Text('Access Denied', style: TextStyle(color: _textPrimary))));
    }

    return Scaffold(
      backgroundColor: _bgDark,
      drawer: isDesktop ? null : _buildDrawer(context, session),
      body: Row(
        children: [
          if (isDesktop) _buildSideNavigation(context, session),
          Expanded(
            child: Column(
              children: [
                _buildTopBar(context, session, isDesktop),
                Expanded(child: _buildContent(context, session, isDesktop, isTablet)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer(BuildContext context, dynamic session) {
    return Drawer(
      backgroundColor: _bgDark,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset('assets/images/eazyschool.png', width: 40, height: 40, fit: BoxFit.contain),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Eazy School', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _textPrimary)),
                        Text('Staff Portal', style: TextStyle(fontSize: 11, color: _textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(height: 1, color: _borderColor),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _buildDrawerNavItem(context, Icons.dashboard_rounded, 'Dashboard', 0),
                  _buildDrawerNavItem(context, Icons.event_note_rounded, 'Apply Leave', 1),
                  _buildDrawerNavItem(context, Icons.access_time_rounded, 'Request Permission', 2),
                  _buildDrawerNavItem(context, Icons.history_rounded, 'My Leaves', 4),
                  _buildDrawerNavItem(context, Icons.fact_check_rounded, 'My Permissions', 5),
                  _buildDrawerNavItem(context, Icons.calendar_month_rounded, 'Holiday Calendar', 6),
                  _buildDrawerNavItem(context, Icons.payments_rounded, 'My Payslips', 7),
                  _buildDrawerNavItem(context, Icons.school_rounded, 'Student Leaves', 8),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Divider(color: Color(0xFF30363D)),
                  ),
                  _buildDrawerNavItem(context, Icons.person_rounded, 'My Profile', 3),
                ],
              ),
            ),
            Container(height: 1, color: _borderColor),
            Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: _cardDark, borderRadius: BorderRadius.circular(10), border: Border.all(color: _borderColor)),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: _accentBlue,
                    radius: 18,
                    child: Text((session.displayName as String? ?? 'S')[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(session.displayName as String? ?? 'Staff', style: const TextStyle(color: _textPrimary, fontWeight: FontWeight.w600, fontSize: 13), overflow: TextOverflow.ellipsis),
                        Text(session.email as String? ?? '', style: const TextStyle(color: _textSecondary, fontSize: 10), overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout_rounded, color: _textSecondary, size: 18),
                    onPressed: () async {
                      Navigator.pop(context);
                      await ref.read(authProvider.notifier).signOut();
                      if (mounted) {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => const EnhancedLoginScreen()),
                          (route) => false,
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerNavItem(BuildContext context, IconData icon, String label, int index) {
    final isSelected = _selectedIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Material(
        color: isSelected ? _accentBlue.withOpacity(0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () {
            setState(() => _selectedIndex = index);
            Navigator.pop(context);
          },
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(icon, color: isSelected ? _accentBlue : _textSecondary, size: 20),
                const SizedBox(width: 12),
                Text(label, style: TextStyle(color: isSelected ? _textPrimary : _textSecondary, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500, fontSize: 13)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSideNavigation(BuildContext context, dynamic session) {
    return Container(
      width: 260,
      color: _bgDark,
      child: Column(
        children: [
          // Logo Header
          Container(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset('assets/images/eazyschool.png', width: 42, height: 42, fit: BoxFit.contain),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Eazy School', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _textPrimary)),
                      Text('Staff Portal', style: TextStyle(fontSize: 11, color: _textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Navigation Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _buildNavItem(Icons.dashboard_rounded, 'Dashboard', 0),
                _buildNavItem(Icons.event_note_rounded, 'Apply Leave', 1),
                _buildNavItem(Icons.access_time_rounded, 'Request Permission', 2),
                _buildNavItem(Icons.history_rounded, 'My Leaves', 4),
                _buildNavItem(Icons.fact_check_rounded, 'My Permissions', 5),
                _buildNavItem(Icons.calendar_month_rounded, 'Holiday Calendar', 6),
                _buildNavItem(Icons.payments_rounded, 'My Payslips', 7),
                _buildNavItem(Icons.school_rounded, 'Student Leaves', 8),
                const SizedBox(height: 8),
                _buildNavItem(Icons.person_rounded, 'My Profile', 3),
              ],
            ),
          ),
          
          // User Info
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: _cardDark, borderRadius: BorderRadius.circular(10), border: Border.all(color: _borderColor)),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: _accentBlue,
                  radius: 18,
                  child: Text((session.displayName as String? ?? 'S')[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(session.displayName as String? ?? 'Staff', style: const TextStyle(color: _textPrimary, fontWeight: FontWeight.w600, fontSize: 13), overflow: TextOverflow.ellipsis),
                      Text(session.email as String? ?? '', style: const TextStyle(color: _textSecondary, fontSize: 10), overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.logout_rounded, color: _textSecondary, size: 18),
                  onPressed: () async {
                    await ref.read(authRepositoryProvider).signOut();
                    if (mounted) {
                      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const EnhancedLoginScreen()));
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyLeaves(BuildContext context, dynamic session, bool isDesktop) {
    final schoolId = session.schoolId as String?;
    if (schoolId == null) {
      return const Center(child: Text('No school selected', style: TextStyle(color: _textSecondary)));
    }

    final leavesAsync = ref.watch(staffLeaveApplicationsProvider((
      schoolId: schoolId,
      applicantId: session.uid as String,
    )));

    return Padding(
      padding: EdgeInsets.all(isDesktop ? 28 : 16),
      child: leavesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: _accentBlue)),
        error: (e, __) => Center(child: Text('Failed to load leave history: $e', style: const TextStyle(color: _textSecondary))),
        data: (leaves) {
          if (leaves.isEmpty) {
            return _buildMyLeavesPlaceholder();
          }

          return ListView.separated(
            itemCount: leaves.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final leave = leaves[index];
              final title = (leave.metadata?['leaveTypeName'] as String?) ?? leave.leaveTypeCode;
              final dateText = '${leave.startDate.day.toString().padLeft(2, '0')}/${leave.startDate.month.toString().padLeft(2, '0')}/${leave.startDate.year}'
                  ' - '
                  '${leave.endDate.day.toString().padLeft(2, '0')}/${leave.endDate.month.toString().padLeft(2, '0')}/${leave.endDate.year}';

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: _cardDark, borderRadius: BorderRadius.circular(12), border: Border.all(color: _borderColor)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: _accentBlue.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.event_note_rounded, color: _accentBlue, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(title, style: const TextStyle(color: _textPrimary, fontWeight: FontWeight.w600, fontSize: 14), overflow: TextOverflow.ellipsis),
                              ),
                              const SizedBox(width: 8),
                              _buildLeaveStatusChip(leave.status),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(dateText, style: const TextStyle(color: _textSecondary, fontSize: 12)),
                          const SizedBox(height: 6),
                          Text('Days: ${leave.totalDays}', style: const TextStyle(color: _textSecondary, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildMyPermissions(BuildContext context, dynamic session, bool isDesktop) {
    final schoolId = session.schoolId as String?;
    if (schoolId == null) {
      return const Center(child: Text('No school selected', style: TextStyle(color: _textSecondary)));
    }

    final permissionsAsync = ref.watch(staffPermissionRequestsProvider((schoolId: schoolId, applicantId: session.uid)));
    final typesAsync = ref.watch(activePermissionTypesProvider(schoolId));

    return Padding(
      padding: EdgeInsets.all(isDesktop ? 28 : 16),
      child: permissionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: _accentBlue)),
        error: (e, __) => Center(child: Text('Failed to load permission history: $e', style: const TextStyle(color: _textSecondary))),
        data: (permissions) {
          if (permissions.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(color: _cardDark, shape: BoxShape.circle),
                    child: const Icon(Icons.fact_check_rounded, size: 56, color: _textSecondary),
                  ),
                  const SizedBox(height: 20),
                  const Text('My Permissions', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _textPrimary)),
                  const SizedBox(height: 8),
                  const Text('No permission requests yet', style: TextStyle(color: _textSecondary)),
                ],
              ),
            );
          }

          final types = typesAsync.maybeWhen(
            data: (value) => value,
            orElse: () => const <PermissionType>[],
          );
          final typeMap = <String, String>{
            for (final t in types) t.id: t.name,
          };

          return ListView.separated(
            itemCount: permissions.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final p = permissions[index];
              final typeName = typeMap[p.permissionTypeId] ?? (p.metadata?['permissionTypeName'] as String?) ?? 'Permission';
              final dateText = '${p.requestDate.day.toString().padLeft(2, '0')}/${p.requestDate.month.toString().padLeft(2, '0')}/${p.requestDate.year}';

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: _cardDark, borderRadius: BorderRadius.circular(12), border: Border.all(color: _borderColor)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: const Color(0xFF8B5CF6).withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.access_time_rounded, color: Color(0xFF8B5CF6), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(typeName, style: const TextStyle(color: _textPrimary, fontWeight: FontWeight.w600, fontSize: 14), overflow: TextOverflow.ellipsis),
                              ),
                              const SizedBox(width: 8),
                              _buildPermissionStatusChip(p.status),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(dateText, style: const TextStyle(color: _textSecondary, fontSize: 12)),
                          const SizedBox(height: 6),
                          Text('Duration: ${p.durationDisplayText}', style: const TextStyle(color: _textSecondary, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildLeaveStatusChip(LeaveApplicationStatus status) {
    late final Color bg;
    late final Color fg;
    switch (status) {
      case LeaveApplicationStatus.APPROVED:
        bg = const Color(0xFF10B981).withOpacity(0.15);
        fg = const Color(0xFF10B981);
        break;
      case LeaveApplicationStatus.REJECTED:
        bg = const Color(0xFFEF4444).withOpacity(0.15);
        fg = const Color(0xFFEF4444);
        break;
      case LeaveApplicationStatus.CANCELLED:
        bg = const Color(0xFF8B949E).withOpacity(0.15);
        fg = const Color(0xFF8B949E);
        break;
      case LeaveApplicationStatus.PENDING:
        bg = const Color(0xFFF59E0B).withOpacity(0.15);
        fg = const Color(0xFFF59E0B);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999), border: Border.all(color: fg.withOpacity(0.3))),
      child: Text(status.name, style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildPermissionStatusChip(PermissionRequestStatus status) {
    late final Color bg;
    late final Color fg;
    switch (status) {
      case PermissionRequestStatus.APPROVED:
        bg = const Color(0xFF10B981).withOpacity(0.15);
        fg = const Color(0xFF10B981);
        break;
      case PermissionRequestStatus.REJECTED:
        bg = const Color(0xFFEF4444).withOpacity(0.15);
        fg = const Color(0xFFEF4444);
        break;
      case PermissionRequestStatus.CANCELLED:
        bg = const Color(0xFF8B949E).withOpacity(0.15);
        fg = const Color(0xFF8B949E);
        break;
      case PermissionRequestStatus.PENDING:
        bg = const Color(0xFFF59E0B).withOpacity(0.15);
        fg = const Color(0xFFF59E0B);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999), border: Border.all(color: fg.withOpacity(0.3))),
      child: Text(status.name, style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isSelected = _selectedIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Material(
        color: isSelected ? _accentBlue.withOpacity(0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () => setState(() => _selectedIndex = index),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              children: [
                Icon(icon, color: isSelected ? _accentBlue : _textSecondary, size: 20),
                const SizedBox(width: 12),
                Text(label, style: TextStyle(color: isSelected ? _textPrimary : _textSecondary, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500, fontSize: 13)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, dynamic session, bool isDesktop) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 28 : 16, vertical: 14),
      decoration: const BoxDecoration(color: _bgDark, border: Border(bottom: BorderSide(color: _borderColor, width: 1))),
      child: Row(
        children: [
          if (!isDesktop) ...[
            Builder(
              builder: (ctx) => IconButton(
                icon: const Icon(Icons.menu_rounded, color: _textPrimary, size: 24),
                onPressed: () => Scaffold.of(ctx).openDrawer(),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ),
            const SizedBox(width: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset('assets/images/eazyschool.png', width: 36, height: 36, fit: BoxFit.contain),
            ),
            const SizedBox(width: 12),
          ],
          
          Text(_getPageTitle(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _textPrimary)),
          
          const Spacer(),
          
          // Notifications
          Stack(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: _cardDark, borderRadius: BorderRadius.circular(8), border: Border.all(color: _borderColor)),
                child: const Icon(Icons.notifications_outlined, color: _textSecondary, size: 20),
              ),
              Positioned(right: 4, top: 4, child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle))),
            ],
          ),
          
          const SizedBox(width: 12),
          
          // User Menu
          PopupMenuButton<String>(
            offset: const Offset(0, 46),
            color: _cardDark,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            onSelected: (value) async {
              if (value == 'logout') {
                await ref.read(authProvider.notifier).signOut();
                if (!context.mounted) return;
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const EnhancedLoginScreen()),
                  (route) => false,
                );
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'logout', child: Text('Logout', style: TextStyle(color: _textPrimary))),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: _cardDark, borderRadius: BorderRadius.circular(8), border: Border.all(color: _borderColor)),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: _accentBlue,
                    radius: 14,
                    child: Text((session.displayName as String? ?? 'S')[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                  if (isDesktop) ...[
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(session.displayName as String? ?? 'Staff', style: const TextStyle(color: _textPrimary, fontWeight: FontWeight.w600, fontSize: 12)),
                        const Text('Staff Member', style: TextStyle(color: _textSecondary, fontSize: 10)),
                      ],
                    ),
                  ],
                  const SizedBox(width: 6),
                  const Icon(Icons.keyboard_arrow_down_rounded, color: _textSecondary, size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getPageTitle() {
    switch (_selectedIndex) {
      case 0: return 'Dashboard';
      case 1: return 'Apply Leave';
      case 2: return 'Request Permission';
      case 5: return 'My Permissions';
      case 6: return 'Holiday Calendar';
      case 7: return 'My Payslips';
      case 3: return 'My Profile';
      case 4: return 'My Leaves';
      default: return 'Dashboard';
    }
  }

  Widget _buildContent(BuildContext context, dynamic session, bool isDesktop, bool isTablet) {
    switch (_selectedIndex) {
      case 0: return _buildDashboardHome(context, session, isDesktop, isTablet);
      case 1: return const ApplyLeaveScreen();
      case 2: return const RequestPermissionScreen();
      case 3: return const StaffProfileScreen();
      case 4: return _buildMyLeaves(context, session, isDesktop);
      case 5: return _buildMyPermissions(context, session, isDesktop);
      case 6: return const HolidayCalendarScreen();
      case 7: return const MyPayslipsScreen();
      case 8: return const ClassTeacherLeaveScreen();
      default: return _buildDashboardHome(context, session, isDesktop, isTablet);
    }
  }

  Widget _buildDashboardHome(BuildContext context, dynamic session, bool isDesktop, bool isTablet) {
    final padding = isDesktop ? 28.0 : 16.0;
    
    return SingleChildScrollView(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome
          Text('Welcome back, ${session.displayName ?? 'Staff'}!', style: TextStyle(fontSize: isDesktop ? 24 : 20, fontWeight: FontWeight.bold, color: _textPrimary)),
          const SizedBox(height: 4),
          const Text('Here\'s your leave and permission overview.', style: TextStyle(color: _textSecondary, fontSize: 14)),
          
          const SizedBox(height: 24),
          
          // Leave Balance Cards
          _buildLeaveBalanceRow(isDesktop, isTablet),
          
          const SizedBox(height: 24),

          // Permission Metrics Cards
          _buildPermissionMetricsRow(isDesktop),
          
          const SizedBox(height: 24),
          
          // Quick Actions and Recent
          _buildQuickActions(),
        ],
      ),
    );
  }

  Widget _buildPermissionMetricsRow(bool isDesktop) {
    final session = ref.watch(currentSessionProvider);
    if (session?.schoolId == null) {
      return const SizedBox.shrink();
    }

    final staffAsync = ref.watch(staffByUserIdProvider((
      schoolId: session!.schoolId!,
      userId: session.uid,
    )));

    return staffAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: _accentBlue)),
      error: (_, __) => const SizedBox.shrink(),
      data: (staff) {
        if (staff == null) return const SizedBox.shrink();

        final now = DateTime.now();
        final month = '${now.year}-${now.month.toString().padLeft(2, '0')}';
        final typesAsync = ref.watch(activePermissionTypesProvider(session.schoolId!));
        final usageByTypeAsync = ref.watch(monthlyPermissionUsageByTypeProvider((
          schoolId: session.schoolId!,
          staffId: staff.id,
          month: month,
        )));

        return typesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: _accentBlue)),
          error: (_, __) => const SizedBox.shrink(),
          data: (types) {
            if (types.isEmpty) return const SizedBox.shrink();

            final usageByType = usageByTypeAsync.valueOrNull ?? const <String, int>{};

            return Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: _cardDark, borderRadius: BorderRadius.circular(12), border: Border.all(color: _borderColor)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Permission Metrics', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _textPrimary)),
                  const SizedBox(height: 16),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: types.asMap().entries.map((entry) {
                        final index = entry.key;
                        final type = entry.value;
                        final used = usageByType[type.id] ?? 0;
                        final total = type.defaultLimit;
                        final remaining = total - used;
                        final color = const Color(0xFF8B5CF6);
                        return Padding(
                          padding: EdgeInsets.only(right: index == types.length - 1 ? 0 : 12),
                          child: SizedBox(
                            width: isDesktop ? 220 : 180,
                            child: _buildPermissionCard(type.name, used, total, remaining, color),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPermissionCard(String type, int used, int total, int remaining, Color color) {
    final safeTotal = total <= 0 ? 1 : total;
    final progress = used / safeTotal;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _bgDark, borderRadius: BorderRadius.circular(10), border: Border.all(color: _borderColor)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(type, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12), overflow: TextOverflow.ellipsis),
              ),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                child: Icon(Icons.access_time_rounded, color: color, size: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$remaining', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('/ $total', style: const TextStyle(color: _textSecondary, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('Availed: $used', style: const TextStyle(color: _textSecondary, fontSize: 12)),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              backgroundColor: color.withOpacity(0.15),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaveBalanceRow(bool isDesktop, bool isTablet) {
    final session = ref.watch(currentSessionProvider);
    if (session?.schoolId == null) {
      return const Center(child: Text('No school selected', style: TextStyle(color: _textSecondary)));
    }

    // Get staff profile first to get staffId
    final staffAsync = ref.watch(staffByUserIdProvider((
      schoolId: session!.schoolId!,
      userId: session.uid,
    )));

    return staffAsync.when(
      loading: () {
        debugPrint('🔄 Loading staff profile for userId: ${session.uid}');
        return const Center(child: CircularProgressIndicator(color: _accentBlue));
      },
      error: (e, stack) {
        debugPrint('❌ Error loading staff profile: $e');
        debugPrint('Stack: $stack');
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text('Error loading profile', style: const TextStyle(color: _textPrimary, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('$e', style: const TextStyle(color: _textSecondary, fontSize: 12), textAlign: TextAlign.center),
            ],
          ),
        );
      },
      data: (staff) {
        if (staff == null) {
          debugPrint('⚠️ Staff profile not found for userId: ${session.uid}');
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.person_off_outlined, color: _textSecondary, size: 48),
                const SizedBox(height: 16),
                const Text('Staff profile not found', style: TextStyle(color: _textPrimary, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('User ID: ${session.uid}', style: const TextStyle(color: _textSecondary, fontSize: 12)),
                const SizedBox(height: 8),
                const Text('Contact your administrator', style: TextStyle(color: _textSecondary, fontSize: 12)),
              ],
            ),
          );
        }

        debugPrint('✅ Staff profile loaded: ${staff.id}');
        final balancesAsync = ref.watch(staffLeaveBalancesProvider((
          schoolId: session.schoolId!,
          staffId: staff.id,
        )));

        return balancesAsync.when(
          loading: () {
            debugPrint('🔄 Loading leave balances for staffId: ${staff.id}');
            return const Center(child: CircularProgressIndicator(color: _accentBlue));
          },
          error: (e, stack) {
            debugPrint('❌ Error loading balances: $e');
            return Center(child: Text('Error loading balances: $e', style: const TextStyle(color: _textSecondary, fontSize: 12), textAlign: TextAlign.center));
          },
          data: (balances) {
            if (balances.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: _cardDark, borderRadius: BorderRadius.circular(12), border: Border.all(color: _borderColor)),
                child: const Center(child: Text('No leave balances configured', style: TextStyle(color: _textSecondary))),
              );
            }

            // Assign colors to leave types
            final colors = [
              const Color(0xFF3B82F6),
              const Color(0xFFF59E0B),
              const Color(0xFF10B981),
              const Color(0xFF8B5CF6),
              const Color(0xFFEC4899),
              const Color(0xFF06B6D4),
            ];

            return Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: _cardDark, borderRadius: BorderRadius.circular(12), border: Border.all(color: _borderColor)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Leave Metrics', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _textPrimary)),
                  const SizedBox(height: 16),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: balances.asMap().entries.map((entry) {
                        final index = entry.key;
                        final balance = entry.value;
                        final color = colors[index % colors.length];
                        final derivedUsed = (balance.totalAllowed + balance.carriedForward) - balance.available - balance.pending;
                        final usedRaw = balance.used > 0 ? balance.used : derivedUsed;
                        final used = usedRaw < 0 ? 0 : usedRaw;
                        return Padding(
                          padding: EdgeInsets.only(right: index == balances.length - 1 ? 0 : 12),
                          child: SizedBox(
                            width: isDesktop ? 220 : 180,
                            child: _buildLeaveCard(
                              balance.metadata?['leaveTypeName'] as String? ?? balance.leaveTypeCode,
                              used,
                              balance.totalAllowed,
                              color,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLeaveCard(String type, int used, int total, Color color) {
    final remaining = total - used;
    final progress = used / total;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _bgDark, borderRadius: BorderRadius.circular(10), border: Border.all(color: _borderColor)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(type, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                child: Icon(Icons.calendar_today, color: color, size: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$remaining', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
              const SizedBox(width: 4),
              Padding(padding: const EdgeInsets.only(bottom: 4), child: Text('/ $total', style: const TextStyle(color: _textSecondary, fontSize: 12))),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(value: progress, backgroundColor: color.withOpacity(0.15), valueColor: AlwaysStoppedAnimation<Color>(color), minHeight: 4),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: _cardDark, borderRadius: BorderRadius.circular(12), border: Border.all(color: _borderColor)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Quick Actions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _textPrimary)),
          const SizedBox(height: 16),
          _buildQuickActionItem('Apply for Leave', Icons.event_note_rounded, 1),
          _buildQuickActionItem('Request Permission', Icons.access_time_rounded, 2),
          _buildQuickActionItem('View Leave History', Icons.history_rounded, 4),
          _buildQuickActionItem('View Permission History', Icons.fact_check_rounded, 5),
          _buildQuickActionItem('My Profile', Icons.person_rounded, 3),
        ],
      ),
    );
  }

  Widget _buildQuickActionItem(String title, IconData icon, int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: _bgDark,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () => setState(() => _selectedIndex = index),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(icon, color: _accentBlue, size: 18),
                const SizedBox(width: 12),
                Text(title, style: const TextStyle(color: _textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMyLeavesPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: _cardDark, shape: BoxShape.circle),
            child: const Icon(Icons.history_rounded, size: 56, color: _textSecondary),
          ),
          const SizedBox(height: 20),
          const Text('My Leaves', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _textPrimary)),
          const SizedBox(height: 8),
          const Text('Leave history coming soon', style: TextStyle(color: _textSecondary)),
        ],
      ),
    );
  }

}
