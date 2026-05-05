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
import '../../../data/repositories/leave_configuration_repository.dart';
import '../../../domain/entities/leave_type_config.dart';
import '../../../domain/entities/permission_type.dart';
import '../../../domain/entities/leave_application.dart';
import '../../../domain/entities/permission_request.dart';
import '../../staff/screens/apply_leave_screen.dart';
import '../../staff/screens/request_permission_screen.dart';
import '../../staff/screens/staff_profile_screen.dart';
import '../../auth/screens/enhanced_login_screen.dart';
import '../../shared/screens/holiday_calendar_screen.dart';
import '../../staff/screens/my_payslips_screen.dart';
import '../../staff/screens/class_teacher_leave_screen.dart';
import '../../widgets/theme_toggle_button.dart';

class StaffDashboardScreen extends ConsumerStatefulWidget {
  const StaffDashboardScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<StaffDashboardScreen> createState() =>
      _StaffDashboardScreenState();
}

class _StaffDashboardScreenState extends ConsumerState<StaffDashboardScreen> {
  int _selectedIndex = 0;

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
      body: Row(
        children: [
          if (isDesktop) _buildSideNavigation(context, session),
          Expanded(
            child: Column(
              children: [
                _buildTopBar(context, session, isDesktop),
                Expanded(
                    child:
                        _buildContent(context, session, isDesktop, isTablet)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer(BuildContext context, dynamic session) {
    return Drawer(
      backgroundColor: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset('assets/images/eazyschool.png',
                        width: 40, height: 40, fit: BoxFit.contain),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Eazy School',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color:
                                    Theme.of(context).colorScheme.onSurface)),
                        Text('Staff Portal',
                            style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(height: 1, color: Theme.of(context).colorScheme.outline),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _buildDrawerNavItem(
                      context, Icons.dashboard_rounded, 'Dashboard', 0),
                  _buildDrawerNavItem(
                      context, Icons.event_note_rounded, 'Apply Leave', 1),
                  _buildDrawerNavItem(context, Icons.access_time_rounded,
                      'Request Permission', 2),
                  _buildDrawerNavItem(
                      context, Icons.history_rounded, 'My Leaves', 4),
                  _buildDrawerNavItem(
                      context, Icons.fact_check_rounded, 'My Permissions', 5),
                  _buildDrawerNavItem(context, Icons.calendar_month_rounded,
                      'Holiday Calendar', 6),
                  _buildDrawerNavItem(
                      context, Icons.payments_rounded, 'My Payslips', 7),
                  _buildDrawerNavItem(
                      context, Icons.school_rounded, 'Student Leaves', 8),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Divider(color: Color(0xFF30363D)),
                  ),
                  _buildDrawerNavItem(
                      context, Icons.category_rounded, 'Leave Types', 9),
                  _buildDrawerNavItem(
                      context, Icons.rule_rounded, 'Permission Types', 10),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Divider(color: Color(0xFF30363D)),
                  ),
                  _buildDrawerNavItem(
                      context, Icons.person_rounded, 'My Profile', 3),
                ],
              ),
            ),
            Container(height: 1, color: Theme.of(context).colorScheme.outline),
            Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color: Theme.of(context).colorScheme.outline)),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: const Color(0xFF4CAF50),
                    radius: 18,
                    child: Text(
                        (session.displayName as String? ?? 'S')[0]
                            .toUpperCase(),
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(session.displayName as String? ?? 'Staff',
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontWeight: FontWeight.w600,
                                fontSize: 13),
                            overflow: TextOverflow.ellipsis),
                        Text(session.email as String? ?? '',
                            style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                                fontSize: 10),
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.logout_rounded,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        size: 18),
                    onPressed: () async {
                      Navigator.pop(context);
                      await ref.read(authProvider.notifier).signOut();
                      if (mounted) {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                              builder: (_) => const EnhancedLoginScreen()),
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

  Widget _buildDrawerNavItem(
      BuildContext context, IconData icon, String label, int index) {
    final isSelected = _selectedIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Material(
        color: isSelected
            ? const Color(0xFF4CAF50).withOpacity(0.15)
            : Colors.transparent,
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
                Icon(icon,
                    color: isSelected
                        ? const Color(0xFF4CAF50)
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                    size: 20),
                const SizedBox(width: 12),
                Text(label,
                    style: TextStyle(
                        color: isSelected
                            ? Theme.of(context).colorScheme.onSurface
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w500,
                        fontSize: 13)),
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
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          // Logo Header
          Container(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset('assets/images/eazyschool.png',
                      width: 42, height: 42, fit: BoxFit.contain),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Eazy School',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface)),
                      Text('Staff Portal',
                          style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant)),
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
                _buildNavItem(
                    Icons.access_time_rounded, 'Request Permission', 2),
                _buildNavItem(Icons.history_rounded, 'My Leaves', 4),
                _buildNavItem(Icons.fact_check_rounded, 'My Permissions', 5),
                _buildNavItem(
                    Icons.calendar_month_rounded, 'Holiday Calendar', 6),
                _buildNavItem(Icons.payments_rounded, 'My Payslips', 7),
                _buildNavItem(Icons.school_rounded, 'Student Leaves', 8),
                const SizedBox(height: 8),
                _buildNavItem(Icons.category_rounded, 'Leave Types', 9),
                _buildNavItem(Icons.rule_rounded, 'Permission Types', 10),
                const SizedBox(height: 8),
                _buildNavItem(Icons.person_rounded, 'My Profile', 3),
              ],
            ),
          ),

          // User Info
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: Theme.of(context).colorScheme.outline)),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFF4CAF50),
                  radius: 18,
                  child: Text(
                      (session.displayName as String? ?? 'S')[0].toUpperCase(),
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(session.displayName as String? ?? 'Staff',
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                              fontSize: 13),
                          overflow: TextOverflow.ellipsis),
                      Text(session.email as String? ?? '',
                          style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              fontSize: 10),
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.logout_rounded,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      size: 18),
                  onPressed: () async {
                    await ref.read(authRepositoryProvider).signOut();
                    if (mounted) {
                      Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (context) =>
                                  const EnhancedLoginScreen()));
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
      return Center(child: Text('No school selected', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)));
    }

    final leavesAsync = ref.watch(staffLeaveApplicationsProvider((
      schoolId: schoolId,
      applicantId: session.uid as String,
    )));

    final cs = Theme.of(context).colorScheme;

    return leavesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, __) => Center(child: Text('Failed to load leave history: $e', style: TextStyle(color: cs.onSurfaceVariant))),
      data: (leaves) {
        if (leaves.isEmpty) {
          return Center(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: cs.surfaceContainerHighest, shape: BoxShape.circle),
                child: Icon(Icons.event_note_rounded, size: 56, color: cs.onSurfaceVariant)),
              const SizedBox(height: 20),
              Text('No Leave Applications', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: cs.onSurface)),
              const SizedBox(height: 8),
              Text('Your leave history will appear here', style: TextStyle(color: cs.onSurfaceVariant)),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => setState(() => _selectedIndex = 1),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Apply Leave'),
                style: ElevatedButton.styleFrom(backgroundColor: cs.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              ),
            ]),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(isDesktop ? 28 : 16, isDesktop ? 28 : 16, isDesktop ? 28 : 16, 8),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('My Leave Applications', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: cs.onSurface)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: cs.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                  child: Text('${leaves.length} records', style: TextStyle(color: cs.primary, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ]),
            ),
            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.fromLTRB(isDesktop ? 28 : 16, 0, isDesktop ? 28 : 16, isDesktop ? 28 : 16),
                itemCount: leaves.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final leave = leaves[index];
                  final title = (leave.metadata?['leaveTypeName'] as String?) ?? leave.leaveTypeCode;
                  final startText = '${leave.startDate.day.toString().padLeft(2, '0')}/${leave.startDate.month.toString().padLeft(2, '0')}/${leave.startDate.year}';
                  final endText = '${leave.endDate.day.toString().padLeft(2, '0')}/${leave.endDate.month.toString().padLeft(2, '0')}/${leave.endDate.year}';
                  final isPending = leave.status == LeaveApplicationStatus.PENDING;

                  return Container(
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: cs.outline.withOpacity(0.5)),
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(color: const Color(0xFF3B82F6).withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                                child: const Icon(Icons.event_note_rounded, color: Color(0xFF3B82F6), size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(child: Text(title, style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w700, fontSize: 15), overflow: TextOverflow.ellipsis)),
                                        const SizedBox(width: 8),
                                        _buildLeaveStatusChip(leave.status),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(children: [
                                      Icon(Icons.calendar_today_rounded, size: 13, color: cs.onSurfaceVariant),
                                      const SizedBox(width: 4),
                                      Text('$startText  →  $endText', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                                      const SizedBox(width: 12),
                                      Icon(Icons.today_rounded, size: 13, color: cs.onSurfaceVariant),
                                      const SizedBox(width: 4),
                                      Text('${leave.totalDays} day${leave.totalDays != 1 ? 's' : ''}', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                                    ]),
                                    if (leave.reason.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                        Icon(Icons.notes_rounded, size: 13, color: cs.onSurfaceVariant),
                                        const SizedBox(width: 4),
                                        Expanded(child: Text(leave.reason, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis)),
                                      ]),
                                    ],
                                    if (leave.rejectionReason != null && leave.rejectionReason!.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(color: cs.error.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
                                        child: Row(children: [
                                          Icon(Icons.info_outline_rounded, size: 13, color: cs.error),
                                          const SizedBox(width: 6),
                                          Expanded(child: Text('Reason: ${leave.rejectionReason}', style: TextStyle(color: cs.error, fontSize: 11))),
                                        ]),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isPending) ...[
                          Divider(height: 1, color: cs.outline.withOpacity(0.4)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                              TextButton.icon(
                                onPressed: () => _cancelLeave(schoolId, leave.id, session.uid as String),
                                icon: const Icon(Icons.cancel_outlined, size: 16),
                                label: const Text('Cancel Application'),
                                style: TextButton.styleFrom(foregroundColor: cs.error, textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                              ),
                            ]),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _cancelLeave(String schoolId, String leaveId, String applicantId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('Cancel Leave?', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to cancel this leave application?', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error, foregroundColor: Colors.white),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(leaveApplicationRepositoryProvider).cancelLeaveApplication(schoolId, leaveId, applicantId);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Leave application cancelled'), backgroundColor: Colors.orange));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to cancel: $e'), backgroundColor: Colors.red));
    }
  }

  Widget _buildMyPermissions(BuildContext context, dynamic session, bool isDesktop) {
    final schoolId = session.schoolId as String?;
    if (schoolId == null) {
      return Center(child: Text('No school selected', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)));
    }

    final permissionsAsync = ref.watch(staffPermissionRequestsProvider((schoolId: schoolId, applicantId: session.uid)));
    final typesAsync = ref.watch(activePermissionTypesProvider(schoolId));
    final cs = Theme.of(context).colorScheme;

    return permissionsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, __) => Center(child: Text('Failed to load permission history: $e', style: TextStyle(color: cs.onSurfaceVariant))),
      data: (permissions) {
        if (permissions.isEmpty) {
          return Center(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: cs.surfaceContainerHighest, shape: BoxShape.circle),
                child: Icon(Icons.fact_check_rounded, size: 56, color: cs.onSurfaceVariant)),
              const SizedBox(height: 20),
              Text('No Permission Requests', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: cs.onSurface)),
              const SizedBox(height: 8),
              Text('Your permission history will appear here', style: TextStyle(color: cs.onSurfaceVariant)),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => setState(() => _selectedIndex = 2),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Request Permission'),
                style: ElevatedButton.styleFrom(backgroundColor: cs.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              ),
            ]),
          );
        }

        final types = typesAsync.maybeWhen(data: (v) => v, orElse: () => const <PermissionType>[]);
        final typeMap = <String, String>{for (final t in types) t.id: t.name};

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(isDesktop ? 28 : 16, isDesktop ? 28 : 16, isDesktop ? 28 : 16, 8),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('My Permission Requests', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: cs.onSurface)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: const Color(0xFF8B5CF6).withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                  child: Text('${permissions.length} records', style: const TextStyle(color: Color(0xFF8B5CF6), fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ]),
            ),
            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.fromLTRB(isDesktop ? 28 : 16, 0, isDesktop ? 28 : 16, isDesktop ? 28 : 16),
                itemCount: permissions.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final p = permissions[index];
                  final typeName = typeMap[p.permissionTypeId] ?? (p.metadata?['permissionTypeName'] as String?) ?? 'Permission';
                  final dateText = '${p.requestDate.day.toString().padLeft(2, '0')}/${p.requestDate.month.toString().padLeft(2, '0')}/${p.requestDate.year}';
                  final startTimeText = '${p.startTime.hour.toString().padLeft(2, '0')}:${p.startTime.minute.toString().padLeft(2, '0')}';
                  final endTimeText = '${p.endTime.hour.toString().padLeft(2, '0')}:${p.endTime.minute.toString().padLeft(2, '0')}';
                  final isPending = p.status == PermissionRequestStatus.PENDING;

                  return Container(
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: cs.outline.withOpacity(0.5)),
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(color: const Color(0xFF8B5CF6).withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                                child: const Icon(Icons.access_time_rounded, color: Color(0xFF8B5CF6), size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(children: [
                                      Expanded(child: Text(typeName, style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w700, fontSize: 15), overflow: TextOverflow.ellipsis)),
                                      const SizedBox(width: 8),
                                      _buildPermissionStatusChip(p.status),
                                    ]),
                                    const SizedBox(height: 8),
                                    Row(children: [
                                      Icon(Icons.calendar_today_rounded, size: 13, color: cs.onSurfaceVariant),
                                      const SizedBox(width: 4),
                                      Text(dateText, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                                      const SizedBox(width: 12),
                                      Icon(Icons.schedule_rounded, size: 13, color: cs.onSurfaceVariant),
                                      const SizedBox(width: 4),
                                      Text('$startTimeText - $endTimeText', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                                      const SizedBox(width: 8),
                                      Text('(${p.durationDisplayText})', style: TextStyle(color: cs.primary, fontSize: 12, fontWeight: FontWeight.w600)),
                                    ]),
                                    if (p.reason.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                        Icon(Icons.notes_rounded, size: 13, color: cs.onSurfaceVariant),
                                        const SizedBox(width: 4),
                                        Expanded(child: Text(p.reason, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis)),
                                      ]),
                                    ],
                                    if (p.rejectionReason != null && p.rejectionReason!.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(color: cs.error.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
                                        child: Row(children: [
                                          Icon(Icons.info_outline_rounded, size: 13, color: cs.error),
                                          const SizedBox(width: 6),
                                          Expanded(child: Text('Reason: ${p.rejectionReason}', style: TextStyle(color: cs.error, fontSize: 11))),
                                        ]),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isPending) ...[
                          Divider(height: 1, color: cs.outline.withOpacity(0.4)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                              TextButton.icon(
                                onPressed: () => _cancelPermission(schoolId, p.id, session.uid as String),
                                icon: const Icon(Icons.cancel_outlined, size: 16),
                                label: const Text('Cancel Request'),
                                style: TextButton.styleFrom(foregroundColor: cs.error, textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                              ),
                            ]),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _cancelPermission(String schoolId, String permissionId, String applicantId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('Cancel Request?', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to cancel this permission request?', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error, foregroundColor: Colors.white),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(permissionRequestRepositoryProvider).cancelPermissionRequest(schoolId, permissionId, applicantId);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Permission request cancelled'), backgroundColor: Colors.orange));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to cancel: $e'), backgroundColor: Colors.red));
    }
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
      decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: fg.withOpacity(0.3))),
      child: Text(status.name,
          style:
              TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w600)),
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
      decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: fg.withOpacity(0.3))),
      child: Text(status.name,
          style:
              TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isSelected = _selectedIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Material(
        color: isSelected
            ? const Color(0xFF4CAF50).withOpacity(0.15)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () => setState(() => _selectedIndex = index),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              children: [
                Icon(icon,
                    color: isSelected
                        ? const Color(0xFF4CAF50)
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                    size: 20),
                const SizedBox(width: 12),
                Text(label,
                    style: TextStyle(
                        color: isSelected
                            ? Theme.of(context).colorScheme.onSurface
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w500,
                        fontSize: 13)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, dynamic session, bool isDesktop) {
    return Container(
      padding:
          EdgeInsets.symmetric(horizontal: isDesktop ? 28 : 16, vertical: 14),
      decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(
              bottom: BorderSide(
                  color: Theme.of(context).colorScheme.outline, width: 1))),
      child: Row(
        children: [
          if (!isDesktop) ...[
            Builder(
              builder: (ctx) => IconButton(
                icon: Icon(Icons.menu_rounded,
                    color: Theme.of(context).colorScheme.onSurface, size: 24),
                onPressed: () => Scaffold.of(ctx).openDrawer(),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ),
            const SizedBox(width: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset('assets/images/eazyschool.png',
                  width: 36, height: 36, fit: BoxFit.contain),
            ),
            const SizedBox(width: 12),
          ],

          Text(_getPageTitle(),
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface)),

          const Spacer(),

          // Theme toggle button
          const ThemeToggleButton(),
          const SizedBox(width: 12),

          // Notifications
          Stack(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: Theme.of(context).colorScheme.outline)),
                child: Icon(Icons.notifications_outlined,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    size: 20),
              ),
              Positioned(
                  right: 4,
                  top: 4,
                  child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                          color: Colors.red, shape: BoxShape.circle))),
            ],
          ),

          const SizedBox(width: 12),

          // User Menu
          PopupMenuButton<String>(
            offset: const Offset(0, 46),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            onSelected: (value) async {
              if (value == 'logout') {
                await ref.read(authProvider.notifier).signOut();
                if (!context.mounted) return;
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                      builder: (_) => const EnhancedLoginScreen()),
                  (route) => false,
                );
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                  value: 'logout',
                  child: Text('Logout',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface))),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: Theme.of(context).colorScheme.outline)),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: const Color(0xFF4CAF50),
                    radius: 14,
                    child: Text(
                        (session.displayName as String? ?? 'S')[0]
                            .toUpperCase(),
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
                  ),
                  if (isDesktop) ...[
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(session.displayName as String? ?? 'Staff',
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontWeight: FontWeight.w600,
                                fontSize: 12)),
                        Text('Staff Member',
                            style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                                fontSize: 10)),
                      ],
                    ),
                  ],
                  const SizedBox(width: 6),
                  Icon(Icons.keyboard_arrow_down_rounded,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      size: 18),
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
      case 0:
        return 'Dashboard';
      case 1:
        return 'Apply Leave';
      case 2:
        return 'Request Permission';
      case 5:
        return 'My Permissions';
      case 6:
        return 'Holiday Calendar';
      case 7:
        return 'My Payslips';
      case 3:
        return 'My Profile';
      case 4:
        return 'My Leaves';
      case 9:
        return 'Leave Types';
      case 10:
        return 'Permission Types';
      default:
        return 'Dashboard';
    }
  }

  Widget _buildContent(
      BuildContext context, dynamic session, bool isDesktop, bool isTablet) {
    switch (_selectedIndex) {
      case 0:
        return _buildDashboardHome(context, session, isDesktop, isTablet);
      case 1:
        return const ApplyLeaveScreen();
      case 2:
        return const RequestPermissionScreen();
      case 3:
        return const StaffProfileScreen();
      case 4:
        return _buildMyLeaves(context, session, isDesktop);
      case 5:
        return _buildMyPermissions(context, session, isDesktop);
      case 6:
        return const HolidayCalendarScreen();
      case 7:
        return const MyPayslipsScreen();
      case 8:
        return const ClassTeacherLeaveScreen();
      case 9:
        return _buildConfiguredLeaveTypes(context, session, isDesktop);
      case 10:
        return _buildConfiguredPermissionTypes(context, session, isDesktop);
      default:
        return _buildDashboardHome(context, session, isDesktop, isTablet);
    }
  }

  Widget _buildDashboardHome(
      BuildContext context, dynamic session, bool isDesktop, bool isTablet) {
    final padding = isDesktop ? 28.0 : 16.0;
    final now = DateTime.now();
    final greeting = now.hour < 12 ? 'Good Morning' : now.hour < 17 ? 'Good Afternoon' : 'Good Evening';
    final displayName = session.displayName as String? ?? session.email as String? ?? 'Staff';
    final firstName = displayName.contains('@') ? displayName.split('@').first : displayName.split(' ').first;

    return SingleChildScrollView(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Welcome Banner ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFF4CAF50), const Color(0xFF2E7D32)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$greeting, $firstName! 👋',
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                      const SizedBox(height: 6),
                      Text("Here's your leave & permission overview for today.",
                          style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.school_rounded, color: Colors.white, size: 32),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Leave Balance Cards ──
          _buildSectionLabel('Leave Balances'),
          const SizedBox(height: 12),
          _buildLeaveBalanceRow(isDesktop, isTablet),

          const SizedBox(height: 24),

          // ── Permission Metrics ──
          _buildPermissionMetricsRow(isDesktop),

          const SizedBox(height: 24),

          // ── Bottom Row: Quick Actions + Recent Activity ──
          if (isDesktop)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: _buildQuickActions()),
                const SizedBox(width: 20),
                Expanded(flex: 2, child: _buildTodayInfo(session)),
              ],
            )
          else ...[
            _buildQuickActions(),
            const SizedBox(height: 20),
            _buildTodayInfo(session),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(label,
        style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
            letterSpacing: 0.3));
  }

  Widget _buildTodayInfo(dynamic session) {
    final now = DateTime.now();
    final dayName = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'][now.weekday - 1];
    final monthName = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][now.month - 1];
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.today_rounded, color: cs.primary, size: 18),
            const SizedBox(width: 8),
            Text('Today', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: cs.onSurface)),
          ]),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [const Color(0xFF4CAF50).withOpacity(0.1), const Color(0xFF4CAF50).withOpacity(0.05)]),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF4CAF50).withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(dayName, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: cs.onSurface)),
                  const SizedBox(height: 2),
                  Text('${now.day} $monthName ${now.year}', style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
                ]),
                const Spacer(),
                Icon(Icons.calendar_month_rounded, color: const Color(0xFF4CAF50), size: 36),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoTile(Icons.event_note_rounded, 'Apply Leave', 'Request time off', const Color(0xFF3B82F6), 1),
          const SizedBox(height: 8),
          _buildInfoTile(Icons.access_time_rounded, 'Request Permission', 'Short-time permission', const Color(0xFF8B5CF6), 2),
          const SizedBox(height: 8),
          _buildInfoTile(Icons.payments_rounded, 'My Payslips', 'View salary details', const Color(0xFF10B981), 7),
        ],
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String title, String subtitle, Color color, int navIndex) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => setState(() => _selectedIndex = navIndex),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: cs.outline.withOpacity(0.4)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurface)),
                Text(subtitle, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
              ],
            )),
            Icon(Icons.arrow_forward_ios_rounded, size: 12, color: cs.onSurfaceVariant),
          ],
        ),
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
      loading: () => Center(
          child: CircularProgressIndicator(color: const Color(0xFF4CAF50))),
      error: (_, __) => const SizedBox.shrink(),
      data: (staff) {
        if (staff == null) return const SizedBox.shrink();

        final now = DateTime.now();
        final month = '${now.year}-${now.month.toString().padLeft(2, '0')}';
        final typesAsync =
            ref.watch(activePermissionTypesProvider(session.schoolId!));
        final usageByTypeAsync =
            ref.watch(monthlyPermissionUsageByTypeProvider((
          schoolId: session.schoolId!,
          month: month,
          staffId: staff.id,
        )));

        return typesAsync.when(
          loading: () => Center(
              child: CircularProgressIndicator(color: const Color(0xFF4CAF50))),
          error: (_, __) => const SizedBox.shrink(),
          data: (types) {
            if (types.isEmpty) return const SizedBox.shrink();

            final usageByType =
                usageByTypeAsync.valueOrNull ?? const <String, int>{};

            final permColors = [
              const Color(0xFF8B5CF6),
              const Color(0xFFEC4899),
              const Color(0xFF06B6D4),
              const Color(0xFFF59E0B),
            ];
            final sw0 = MediaQuery.of(context).size.width;
            final permCrossCount = sw0 > 1024 ? 4 : (sw0 > 600 ? 3 : 2);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionLabel('Permission Overview'),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: types.asMap().entries.map((entry) {
                    final index = entry.key;
                    final type = entry.value;
                    final used = usageByType[type.id] ?? 0;
                    final total = type.defaultLimit;
                    final remaining = total - used;
                    final color = permColors[index % permColors.length];
                    final sw = MediaQuery.of(context).size.width;
                    final sw2 = sw > 1024 ? 260.0 : 0.0;
                    final op = sw > 1024 ? 56.0 : 32.0;
                    final cardWidth = (sw - sw2 - op - (12.0 * (permCrossCount - 1))) / permCrossCount;
                    return SizedBox(
                      width: cardWidth.clamp(140.0, 260.0),
                      child: _buildPermissionCard(type.name, used, total, remaining, color),
                    );
                  }).toList(),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildPermissionCard(
      String type, int used, int total, int remaining, Color color) {
    final safeTotal = total <= 0 ? 1 : total;
    final progress = (used / safeTotal).clamp(0.0, 1.0);
    final cs = Theme.of(context).colorScheme;

    return Container(
      height: 120,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outline.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(type, style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600, fontSize: 11), overflow: TextOverflow.ellipsis),
              ),
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                child: Icon(Icons.access_time_rounded, color: color, size: 11),
              ),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$remaining', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
              const SizedBox(width: 3),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text('/ $total left', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11)),
              ),
            ],
          ),
          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Used: $used', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 10)),
                  Text('${(progress * 100).toStringAsFixed(0)}%', style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: color.withOpacity(0.12),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  minHeight: 4,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLeaveBalanceRow(bool isDesktop, bool isTablet) {
    final session = ref.watch(currentSessionProvider);
    if (session?.schoolId == null) {
      return Center(
          child: Text('No school selected',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)));
    }

    // Get staff profile first to get staffId
    final staffAsync = ref.watch(staffByUserIdProvider((
      schoolId: session!.schoolId!,
      userId: session.uid,
    )));

    return staffAsync.when(
      loading: () {
        debugPrint('🔄 Loading staff profile for userId: ${session.uid}');
        return Center(
            child: CircularProgressIndicator(color: const Color(0xFF4CAF50)));
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
              Text('Error loading profile',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('$e',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12),
                  textAlign: TextAlign.center),
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
                Icon(Icons.person_off_outlined,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    size: 48),
                const SizedBox(height: 16),
                Text('Staff profile not found',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('User ID: ${session.uid}',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 12)),
                const SizedBox(height: 8),
                Text('Contact your administrator',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 12)),
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
            return Center(
                child:
                    CircularProgressIndicator(color: const Color(0xFF4CAF50)));
          },
          error: (e, stack) {
            debugPrint('❌ Error loading balances: $e');
            return Center(
                child: Text('Error loading balances: $e',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 12),
                    textAlign: TextAlign.center));
          },
          data: (balances) {
            if (balances.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Theme.of(context).colorScheme.outline)),
                child: Center(
                    child: Text('No leave balances configured',
                        style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant))),
              );
            }

            final colors = [
              const Color(0xFF3B82F6),
              const Color(0xFFF59E0B),
              const Color(0xFF10B981),
              const Color(0xFF8B5CF6),
              const Color(0xFFEC4899),
              const Color(0xFF06B6D4),
            ];

            final crossCount = isDesktop ? 4 : (isTablet ? 3 : 2);

            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: balances.asMap().entries.map((entry) {
                final index = entry.key;
                final balance = entry.value;
                final color = colors[index % colors.length];
                final derivedUsed = (balance.totalAllowed + balance.carriedForward) - balance.available - balance.pending;
                final usedRaw = balance.used > 0 ? balance.used : derivedUsed;
                final used = usedRaw < 0 ? 0 : usedRaw;
                final screenWidth = MediaQuery.of(context).size.width;
                final sidebarWidth = screenWidth > 1024 ? 260.0 : 0.0;
                final outerPadding = screenWidth > 1024 ? 56.0 : 32.0;
                final cardWidth = (screenWidth - sidebarWidth - outerPadding - (12.0 * (crossCount - 1))) / crossCount;
                return SizedBox(
                  width: cardWidth.clamp(140.0, 260.0),
                  child: _buildLeaveCard(
                    balance.metadata?['leaveTypeName'] as String? ?? balance.leaveTypeCode,
                    used,
                    balance.totalAllowed,
                    color,
                  ),
                );
              }).toList(),
            );
          },
        );
      },
    );
  }

  Widget _buildLeaveCard(String type, int used, int total, Color color) {
    final remaining = (total - used).clamp(0, total);
    final progress = total > 0 ? (used / total).clamp(0.0, 1.0) : 0.0;
    final cs = Theme.of(context).colorScheme;

    return Container(
      height: 120,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outline.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(type, style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600, fontSize: 11), overflow: TextOverflow.ellipsis),
              ),
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                child: Icon(Icons.calendar_today_rounded, color: color, size: 11),
              ),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$remaining', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
              const SizedBox(width: 3),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text('/ $total left', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11)),
              ),
            ],
          ),
          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Used: $used', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 10)),
                  Text('${(progress * 100).toStringAsFixed(0)}%', style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: color.withOpacity(0.12),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  minHeight: 4,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    final cs = Theme.of(context).colorScheme;
    final actions = [
      (Icons.event_note_rounded, 'Apply Leave', 'Apply for time off', const Color(0xFF3B82F6), 1),
      (Icons.access_time_rounded, 'Request Permission', 'Short-time request', const Color(0xFF8B5CF6), 2),
      (Icons.history_rounded, 'My Leaves', 'View leave history', const Color(0xFF10B981), 4),
      (Icons.fact_check_rounded, 'My Permissions', 'Permission history', const Color(0xFFEC4899), 5),
      (Icons.calendar_month_rounded, 'Holiday Calendar', 'View holidays', const Color(0xFFF59E0B), 6),
      (Icons.payments_rounded, 'My Payslips', 'View salary slips', const Color(0xFF06B6D4), 7),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.flash_on_rounded, color: cs.primary, size: 18),
            const SizedBox(width: 8),
            Text('Quick Actions', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: cs.onSurface)),
          ]),
          const SizedBox(height: 16),
          ...actions.map((a) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _buildQuickActionItem(a.$1, a.$2, a.$3, a.$4, a.$5),
          )),
        ],
      ),
    );
  }

  Widget _buildQuickActionItem(IconData icon, String title, String subtitle, Color color, int index) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: () => setState(() => _selectedIndex = index),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: cs.outline.withOpacity(0.4)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(9)),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurface)),
                  Text(subtitle, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                ],
              )),
              Icon(Icons.arrow_forward_ios_rounded, size: 12, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConfiguredLeaveTypes(BuildContext context, dynamic session, bool isDesktop) {
    final schoolId = session.schoolId as String?;
    if (schoolId == null) {
      return Center(child: Text('No school selected', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)));
    }

    final leaveTypesAsync = ref.watch(activeSchoolLeaveTypesProvider(schoolId));
    final cs = Theme.of(context).colorScheme;

    return leaveTypesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, __) => Center(child: Text('Failed to load leave types: $e', style: TextStyle(color: cs.onSurfaceVariant))),
      data: (leaveTypes) {
        if (leaveTypes.isEmpty) {
          return Center(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: cs.surfaceContainerHighest, shape: BoxShape.circle),
                child: Icon(Icons.category_rounded, size: 56, color: cs.onSurfaceVariant)),
              const SizedBox(height: 20),
              Text('No Leave Types Configured', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: cs.onSurface)),
              const SizedBox(height: 8),
              Text('Contact your administrator to configure leave types', style: TextStyle(color: cs.onSurfaceVariant)),
            ]),
          );
        }

        return SingleChildScrollView(
          padding: EdgeInsets.all(isDesktop ? 28 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Configured Leave Types', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: cs.onSurface)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: const Color(0xFF4CAF50).withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                  child: Text('${leaveTypes.length} types', style: const TextStyle(color: Color(0xFF4CAF50), fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ]),
              const SizedBox(height: 16),
              ...leaveTypes.map((type) => _buildLeaveTypeInfoCard(type, cs)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLeaveTypeInfoCard(LeaveTypeConfig type, ColorScheme cs) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outline.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFF3B82F6).withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.event_note_rounded, color: Color(0xFF3B82F6), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(type.name, style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 4),
                if (type.description.isNotEmpty)
                  Text(type.description, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    _buildInfoChip('${type.code}', const Color(0xFF6B7280)),
                    _buildInfoChip('${type.annualQuota} days/year', const Color(0xFF3B82F6)),
                    if (type.isPaid) _buildInfoChip('Paid', const Color(0xFF10B981)),
                    if (!type.isPaid) _buildInfoChip('Unpaid', const Color(0xFFF59E0B)),
                    if (type.carryForwardAllowed) _buildInfoChip('Carry Forward', const Color(0xFF8B5CF6)),
                    _buildInfoChip('Max ${type.maxDaysPerRequest} days/request', const Color(0xFFEC4899)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfiguredPermissionTypes(BuildContext context, dynamic session, bool isDesktop) {
    final schoolId = session.schoolId as String?;
    if (schoolId == null) {
      return Center(child: Text('No school selected', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)));
    }

    final permissionTypesAsync = ref.watch(activePermissionTypesProvider(schoolId));
    final cs = Theme.of(context).colorScheme;

    return permissionTypesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, __) => Center(child: Text('Failed to load permission types: $e', style: TextStyle(color: cs.onSurfaceVariant))),
      data: (permissionTypes) {
        if (permissionTypes.isEmpty) {
          return Center(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: cs.surfaceContainerHighest, shape: BoxShape.circle),
                child: Icon(Icons.rule_rounded, size: 56, color: cs.onSurfaceVariant)),
              const SizedBox(height: 20),
              Text('No Permission Types Configured', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: cs.onSurface)),
              const SizedBox(height: 8),
              Text('Contact your administrator to configure permission types', style: TextStyle(color: cs.onSurfaceVariant)),
            ]),
          );
        }

        return SingleChildScrollView(
          padding: EdgeInsets.all(isDesktop ? 28 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Configured Permission Types', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: cs.onSurface)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: const Color(0xFF8B5CF6).withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                  child: Text('${permissionTypes.length} types', style: const TextStyle(color: Color(0xFF8B5CF6), fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ]),
              const SizedBox(height: 16),
              ...permissionTypes.map((type) => _buildPermissionTypeInfoCard(type, cs)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPermissionTypeInfoCard(PermissionType type, ColorScheme cs) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outline.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFF8B5CF6).withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.access_time_rounded, color: Color(0xFF8B5CF6), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(type.name, style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    _buildInfoChip('Default: ${type.defaultLimit} times', const Color(0xFF8B5CF6)),
                    _buildInfoChip('Active', const Color(0xFF10B981)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }

}
