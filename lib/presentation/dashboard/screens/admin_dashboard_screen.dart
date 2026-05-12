import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/security/route_guard.dart';
import '../../../core/security/role_policy.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/fee_repository.dart';
import '../../../data/repositories/expense_repository.dart';
import '../../admin/screens/staff_management_screen.dart';
import '../../admin/screens/manage_finance_users_screen.dart';
import '../../admin/screens/leave_policy_config_screen.dart';
import '../../admin/screens/permission_policy_config_screen.dart';
import '../../admin/screens/leave_approval_screen.dart';
import '../../admin/screens/permission_approval_screen.dart';
import '../../admin/screens/holiday_management_screen.dart';
import '../../admin/screens/rfid_card_management_screen.dart';
import '../../admin/screens/communication_logs_screen.dart';
import '../../admin/screens/student_directory_screen.dart';
import '../../admin/screens/student_directory_with_ledger_screen.dart';
import '../../admin/screens/class_teacher_assignment_screen.dart';
import '../../admin/screens/academic_year_management_screen.dart';
import '../../admin/screens/whatsapp_settings_screen.dart';
import '../../admin/screens/uqi_settings_screen.dart';
import '../../finance/screens/expense_entry_screen.dart';
import '../../finance/screens/financial_reports_screen.dart';
import '../../finance/screens/bill_management_screen.dart';
import '../../finance/screens/delete_student_screen.dart';
import '../../finance/screens/upload_sheet_screen.dart';
import '../../finance/screens/student_fee_management_screen.dart';
import '../../finance/screens/fee_structure_list_screen.dart';
import '../../finance/screens/manage_fee_categories_screen.dart';
import '../../finance/screens/ad_hoc_fee_assignment_screen.dart';
import '../../admin/screens/payroll_management_screen.dart';
import '../../admin/screens/school_settings_screen.dart';
import '../../auth/screens/enhanced_login_screen.dart';
import '../../shared/widgets/school_switcher.dart';
import '../../widgets/theme_toggle_button.dart';

class MenuItem {
  final String id;
  final IconData icon;
  final String label;
  final List<MenuItem>? children;
  final bool isNew;
  final bool isComingSoon;
  final bool isSection;
  const MenuItem({
    required this.id,
    required this.icon,
    required this.label,
    this.children,
    this.isNew = false,
    this.isComingSoon = false,
    this.isSection = false,
  });
}

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({Key? key}) : super(key: key);
  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  String _selectedMenuId = 'dashboard';
  Set<String> _expandedMenus = {
    'leave_management',
    'permission_management',
    'student_ops',
    'finance_management',
    'reports_section',
  };
  bool _isSidebarCollapsed = false;
  String _chartPeriod = 'last_6_months';

  // Accent color for the app
  static const Color _accentBlue = Color(0xFF4CAF50);

  static const List<MenuItem> _adminMenuItems = [
    // ── Overview ────────────────────────────────────────────
    MenuItem(
        id: 'sec_overview',
        icon: Icons.remove,
        label: 'Overview',
        isSection: true),
    MenuItem(
        id: 'dashboard', icon: Icons.dashboard_rounded, label: 'Dashboard'),

    // ── Staff ───────────────────────────────────────────────
    MenuItem(
        id: 'sec_staff', icon: Icons.remove, label: 'Staff', isSection: true),
    MenuItem(
        id: 'staff_management',
        icon: Icons.people_alt_rounded,
        label: 'Staff Management'),
    MenuItem(
        id: 'finance_users',
        icon: Icons.manage_accounts_rounded,
        label: 'Finance Users'),
    MenuItem(
      id: 'leave_management',
      icon: Icons.event_note_rounded,
      label: 'Leave Management',
      children: [
        MenuItem(
            id: 'leave_requests',
            icon: Icons.pending_actions_rounded,
            label: 'Leave Requests'),
        MenuItem(
            id: 'leave_policy',
            icon: Icons.policy_rounded,
            label: 'Leave Policy'),
      ],
    ),
    MenuItem(
      id: 'permission_management',
      icon: Icons.access_time_rounded,
      label: 'Permissions',
      children: [
        MenuItem(
            id: 'permission_requests',
            icon: Icons.pending_rounded,
            label: 'Permission Requests'),
        MenuItem(
            id: 'permission_policy',
            icon: Icons.tune_rounded,
            label: 'Permission Policy'),
      ],
    ),
    MenuItem(
        id: 'holiday_management',
        icon: Icons.calendar_month_rounded,
        label: 'Holiday Management'),
    MenuItem(
        id: 'payroll_management',
        icon: Icons.payments_rounded,
        label: 'Payroll'),
    MenuItem(
        id: 'rfid_card_management',
        icon: Icons.nfc_rounded,
        label: 'RFID Attendance'),

    // ── Students ────────────────────────────────────────────
    MenuItem(
        id: 'sec_students',
        icon: Icons.remove,
        label: 'Students',
        isSection: true),
    MenuItem(
      id: 'students',
      icon: Icons.school_rounded,
      label: 'Students',
      children: [
        MenuItem(
            id: 'student_management',
            icon: Icons.format_list_bulleted_rounded,
            label: 'Student Directory'),
        MenuItem(
            id: 'student_ledgers',
            icon: Icons.account_balance_wallet_rounded,
            label: 'Fee Ledgers'),
        MenuItem(
            id: 'class_teacher_assign',
            icon: Icons.assignment_ind_rounded,
            label: 'Class Teacher Assignment'),
        MenuItem(
            id: 'student_leave_approval',
            icon: Icons.event_available_rounded,
            label: 'Student Leave Approval',
            isComingSoon: true),
        MenuItem(
            id: 'student-promotion',
            icon: Icons.trending_up_rounded,
            label: 'Student Promotion',
            isComingSoon: true),
      ],
    ),

    // ── Finance ─────────────────────────────────────────────
    MenuItem(
        id: 'sec_finance',
        icon: Icons.remove,
        label: 'Finance',
        isSection: true),
    MenuItem(
      id: 'finance_management',
      icon: Icons.account_balance_rounded,
      label: 'Fee Management',
      children: [
        MenuItem(
            id: 'student_fee_mgmt',
            icon: Icons.receipt_rounded,
            label: 'Fee Assignment'),
        MenuItem(
            id: 'fee_structures_v2',
            icon: Icons.receipt_long_outlined,
            label: 'Fee Structures'),
        MenuItem(
            id: 'fee_categories',
            icon: Icons.category_outlined,
            label: 'Fee Categories'),
        MenuItem(
            id: 'ad_hoc_fee_assignment',
            icon: Icons.add_card_rounded,
            label: 'Ad-Hoc Fee'),
      ],
    ),
    MenuItem(
      id: 'reports_section',
      icon: Icons.bar_chart_rounded,
      label: 'Reports & Expenses',
      children: [
        MenuItem(
            id: 'financial_reports',
            icon: Icons.insights_rounded,
            label: 'Financial Reports'),
        MenuItem(
            id: 'expenses',
            icon: Icons.money_off_rounded,
            label: 'Expense Entry'),
        MenuItem(
            id: 'bill_management',
            icon: Icons.receipt_long_rounded,
            label: 'Bill Management'),
      ],
    ),

    // ── Tools & Settings ────────────────────────────────────
    MenuItem(
        id: 'sec_tools',
        icon: Icons.remove,
        label: 'Tools & Settings',
        isSection: true),
    MenuItem(
        id: 'upload_sheet',
        icon: Icons.upload_file_rounded,
        label: 'Upload Sheet'),
    MenuItem(
        id: 'academic-year-mgmt',
        icon: Icons.calendar_today_rounded,
        label: 'Academic Year'),
    MenuItem(
        id: 'communication_logs',
        icon: Icons.forum_rounded,
        label: 'Communication Logs'),
    MenuItem(
        id: 'whatsapp_settings',
        icon: Icons.chat_rounded,
        label: 'WhatsApp Settings'),
    MenuItem(
        id: 'upi_settings',
        icon: Icons.qr_code_2_rounded,
        label: 'UPI Settings'),
    MenuItem(id: 'settings', icon: Icons.settings_rounded, label: 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    return RouteGuard(
      route: '/admin-dashboard',
      requiredModule: UIModule.adminDashboard,
      child: _buildDashboard(context),
    );
  }

  Widget _buildDashboard(BuildContext context) {
    final session = ref.watch(currentSessionProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 1024;
    final isTablet = screenWidth > 600 && screenWidth <= 1024;

    if (session == null || (!session.isAdmin && !session.isSuperAdmin)) {
      return const Scaffold(body: Center(child: Text('Access Denied')));
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
                  child: _buildContent(context, session, isDesktop, isTablet),
                ),
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
            _buildLogoHeader(isCollapsed: false, isDesktop: false),
            Container(height: 1, color: Theme.of(context).colorScheme.outline),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: _adminMenuItems
                    .map((item) => _buildDrawerMenuItem(context, item))
                    .toList(),
              ),
            ),
            Container(height: 1, color: Theme.of(context).colorScheme.outline),
            _buildUserInfoCard(session, true),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoHeader({
    required bool isCollapsed,
    required bool isDesktop,
  }) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        isCollapsed ? 22 : 20,
        20,
        isCollapsed ? 22 : 20,
        16,
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.asset(
              'assets/images/eazyschool.png',
              width: 40,
              height: 40,
              fit: BoxFit.contain,
            ),
          ),
          if (!isCollapsed) ...[
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Eazy School',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    '360 Admin Portal',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDrawerMenuItem(BuildContext context, MenuItem item) {
    if (item.isSection)
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(
          item.label.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color:
                Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.6),
            letterSpacing: 1.2,
          ),
        ),
      );
    final hasChildren = item.children != null && item.children!.isNotEmpty;
    final isExpanded = _expandedMenus.contains(item.id);
    final isSelected = _selectedMenuId == item.id ||
        (hasChildren &&
            item.children!.any((child) => child.id == _selectedMenuId));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          child: Material(
            color: isSelected && !hasChildren
                ? _accentBlue.withOpacity(0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              onTap: () {
                if (hasChildren) {
                  setState(
                    () => isExpanded
                        ? _expandedMenus.remove(item.id)
                        : _expandedMenus.add(item.id),
                  );
                } else {
                  setState(() => _selectedMenuId = item.id);
                  Navigator.pop(context);
                }
              },
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Icon(
                      item.icon,
                      color: isSelected
                          ? _accentBlue
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        item.label,
                        style: TextStyle(
                          color: isSelected
                              ? Theme.of(context).colorScheme.onSurface
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    if (item.isNew)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _accentBlue.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'New',
                          style: TextStyle(
                            color: _accentBlue,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    if (item.isComingSoon)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Coming Soon',
                          style: TextStyle(
                            color: const Color(0xFFF59E0B),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    if (hasChildren)
                      Icon(
                        isExpanded ? Icons.expand_less : Icons.expand_more,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        size: 20,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (hasChildren && isExpanded)
          ...item.children!.map((child) => _buildSubMenuItem(context, child)),
      ],
    );
  }

  Widget _buildSubMenuItem(BuildContext context, MenuItem item) {
    final isSelected = _selectedMenuId == item.id;
    return Padding(
      padding: const EdgeInsets.only(left: 32, right: 10, top: 2, bottom: 2),
      child: Material(
        color: isSelected ? _accentBlue.withOpacity(0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () {
            setState(() => _selectedMenuId = item.id);
            Navigator.pop(context);
          },
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Icon(
                  item.icon,
                  color: isSelected
                      ? _accentBlue
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.label,
                    style: TextStyle(
                      color: isSelected
                          ? Theme.of(context).colorScheme.onSurface
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w400,
                      fontSize: 12,
                    ),
                  ),
                ),
                if (item.isNew)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _accentBlue.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'New',
                      style: TextStyle(
                        color: _accentBlue,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                if (item.isComingSoon)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Coming Soon',
                      style: TextStyle(
                        color: Color(0xFFF59E0B),
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSideNavigation(BuildContext context, dynamic session) {
    return Container(
      width: _isSidebarCollapsed ? 84 : 260,
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          _buildDesktopSidebarHeader(session),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: _adminMenuItems
                  .map((item) => _buildSideNavMenuItem(item))
                  .toList(),
            ),
          ),
          _buildUserInfoCard(session, false),
        ],
      ),
    );
  }

  Widget _buildDesktopSidebarHeader(dynamic session) {
    return _buildLogoHeader(isCollapsed: _isSidebarCollapsed, isDesktop: true);
  }

  Widget _buildSideNavMenuItem(MenuItem item) {
    if (item.isSection) {
      if (_isSidebarCollapsed) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child:
              Divider(color: Theme.of(context).colorScheme.outline, height: 1),
        );
      }
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(
          item.label.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color:
                Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.6),
            letterSpacing: 1.2,
          ),
        ),
      );
    }
    final hasChildren = item.children != null && item.children!.isNotEmpty;
    final isExpanded = _expandedMenus.contains(item.id);
    final isSelected = _selectedMenuId == item.id ||
        (hasChildren &&
            item.children!.any((child) => child.id == _selectedMenuId));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          child: Material(
            color: isSelected && !hasChildren
                ? _accentBlue.withOpacity(0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              onTap: () {
                if (hasChildren) {
                  if (_isSidebarCollapsed) {
                    setState(() {
                      _isSidebarCollapsed = false;
                      _expandedMenus.add(item.id);
                    });
                  } else {
                    setState(
                      () => isExpanded
                          ? _expandedMenus.remove(item.id)
                          : _expandedMenus.add(item.id),
                    );
                  }
                } else {
                  setState(() => _selectedMenuId = item.id);
                }
              },
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
                child: Row(
                  children: [
                    Tooltip(
                      message: _isSidebarCollapsed ? item.label : '',
                      child: Icon(
                        item.icon,
                        color: isSelected
                            ? _accentBlue
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                        size: 20,
                      ),
                    ),
                    if (!_isSidebarCollapsed) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          item.label,
                          style: TextStyle(
                            color: isSelected
                                ? Theme.of(context).colorScheme.onSurface
                                : Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                            fontWeight:
                                isSelected ? FontWeight.w600 : FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      if (item.isNew)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _accentBlue.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'New',
                            style: TextStyle(
                              color: _accentBlue,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      if (item.isComingSoon)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Coming Soon',
                            style: TextStyle(
                              color: Color(0xFFF59E0B),
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      if (hasChildren)
                        Icon(
                          isExpanded ? Icons.expand_less : Icons.expand_more,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          size: 20,
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        if (hasChildren && isExpanded && !_isSidebarCollapsed)
          ...item.children!.map((child) => _buildSideNavSubMenuItem(child)),
      ],
    );
  }

  Widget _buildSideNavSubMenuItem(MenuItem item) {
    final isSelected = _selectedMenuId == item.id;
    return Padding(
      padding: const EdgeInsets.only(left: 32, right: 10, top: 2, bottom: 2),
      child: Material(
        color: isSelected ? _accentBlue.withOpacity(0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () => setState(() => _selectedMenuId = item.id),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Icon(
                  item.icon,
                  color: isSelected
                      ? _accentBlue
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.label,
                    style: TextStyle(
                      color: isSelected
                          ? Theme.of(context).colorScheme.onSurface
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w400,
                      fontSize: 12,
                    ),
                  ),
                ),
                if (item.isNew)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _accentBlue.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'New',
                      style: TextStyle(
                        color: _accentBlue,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                if (item.isComingSoon)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Coming Soon',
                      style: TextStyle(
                        color: Color(0xFFF59E0B),
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserInfoCard(dynamic session, bool isDrawer) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: _accentBlue,
            radius: 18,
            child: Text(
              (session.displayName as String? ?? 'A')[0].toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          if (isDrawer || !_isSidebarCollapsed) ...[
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.displayName as String? ?? 'Admin',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    session.email as String? ?? '',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 10,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(width: 6),
          ],
          IconButton(
            icon: Icon(
              Icons.logout_rounded,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              size: 18,
            ),
            onPressed: () async {
              if (isDrawer) Navigator.pop(context);
              await ref.read(authRepositoryProvider).signOut();
              if (mounted)
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const EnhancedLoginScreen(),
                  ),
                );
            },
          ),
        ],
      ),
    );
  }

  String _getPageTitle() {
    switch (_selectedMenuId) {
      case 'dashboard':
        return 'Dashboard';
      case 'staff_management':
        return 'Staff Management';
      case 'leave_requests':
        return 'Leave Requests';
      case 'leave_policy':
        return 'Leave Policy';
      case 'permission_requests':
        return 'Permission Requests';
      case 'permission_policy':
        return 'Permission Policy';
      case 'holiday_management':
        return 'Holiday Management';
      case 'payroll_management':
        return 'Payroll Management';
      case 'rfid_card_management':
        return 'RFID Card Management';
      case 'student_management':
        return 'Student Directory';
      case 'student_ledgers':
        return 'Student Ledgers & Payments';
      case 'class_teacher_assign':
        return 'Class Teacher Assignment';
      case 'student_leave_approval':
        return 'Student Leave Approval';
      case 'student_fee_mgmt':
        return 'Student Fee Management';
      case 'fee_structures_v2':
        return 'Fee Structures';
      case 'fee_categories':
        return 'Fee Categories';
      case 'ad_hoc_fee_assignment':
        return 'Ad-Hoc Fee Assignment';
      case 'delete_student':
        return 'Delete Student';
      case 'fee_collection':
        return 'Fee Collection';
      case 'expenses':
        return 'Expense Entry';
      case 'bill_management':
        return 'Bill Management';
      case 'financial_reports':
        return 'Financial Reports';
      case 'upload_sheet':
        return 'Upload Sheet';
      case 'communication_logs':
        return 'Communication Logs';
      case 'whatsapp_settings':
        return 'WhatsApp Settings';
      case 'upi_settings':
        return 'UPI Settings';
      case 'settings':
        return 'Settings';
      default:
        return 'Dashboard';
    }
  }

  Widget _buildTopBar(BuildContext context, dynamic session, bool isDesktop) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 28 : 16,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          if (isDesktop) ...[
            IconButton(
              icon: Icon(
                _isSidebarCollapsed
                    ? Icons.menu_open_rounded
                    : Icons.menu_rounded,
                color: Theme.of(context).colorScheme.onSurface,
                size: 24,
              ),
              onPressed: () =>
                  setState(() => _isSidebarCollapsed = !_isSidebarCollapsed),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 12),
          ] else ...[
            Builder(
              builder: (ctx) => IconButton(
                icon: Icon(
                  Icons.menu_rounded,
                  color: Theme.of(ctx).colorScheme.onSurface,
                  size: 24,
                ),
                onPressed: () => Scaffold.of(ctx).openDrawer(),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Text(
            _getPageTitle(),
            style: TextStyle(
              fontSize: isDesktop ? 18 : 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const Spacer(),
          const ThemeToggleButton(),
          const SizedBox(width: 12),
          SchoolSwitcher(textColor: Theme.of(context).colorScheme.onSurface),
          const SizedBox(width: 12),
          Stack(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
                child: Icon(
                  Icons.notifications_outlined,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  size: 20,
                ),
              ),
              Positioned(
                right: 4,
                top: 4,
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
          ),
          const SizedBox(width: 12),
          PopupMenuButton<String>(
            offset: const Offset(0, 46),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            onSelected: (value) async {
              if (value == 'logout') {
                await ref.read(authProvider.notifier).signOut();
                if (!context.mounted) return;
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (_) => const EnhancedLoginScreen(),
                  ),
                  (route) => false,
                );
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'logout',
                child: Text(
                  'Logout',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: _accentBlue,
                    radius: 14,
                    child: Text(
                      (session.displayName as String? ?? 'A')[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  if (isDesktop) ...[
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          session.displayName as String? ?? 'Admin',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          'Administrator',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(width: 6),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    dynamic session,
    bool isDesktop,
    bool isTablet,
  ) {
    switch (_selectedMenuId) {
      case 'dashboard':
        return _buildDashboardHome(context, session, isDesktop, isTablet);
      case 'staff_management':
        return const StaffManagementScreen();
      case 'finance_users':
        return const ManageFinanceUsersScreen();
      case 'leave_requests':
        return const LeaveApprovalScreen();
      case 'leave_policy':
        return const LeavePolicyConfigScreen();
      case 'permission_requests':
        return const PermissionApprovalScreen();
      case 'permission_policy':
        return const PermissionPolicyConfigScreen();
      case 'holiday_management':
        return const HolidayManagementScreen();
      case 'payroll_management':
        return const PayrollManagementScreen();
      case 'rfid_card_management':
        return const RfidCardManagementScreen();
      case 'communication_logs':
        return const CommunicationLogsScreen();
      case 'student_management':
        return const StudentDirectoryScreen();
      case 'student_ledgers':
        return const StudentDirectoryWithLedgerScreen();
      case 'class_teacher_assign':
        return const ClassTeacherAssignmentScreen();
      case 'student_leave_approval':
        return _buildComingSoonScreen('Student Leave Approval');
      case 'student-promotion':
        return _buildComingSoonScreen('Student Promotion');
      case 'academic-year-mgmt':
        return const AcademicYearManagementScreen();
      case 'student_fee_mgmt':
        return const StudentFeeManagementScreen();
      case 'fee_structures_v2':
        return const FeeStructureListScreen();
      case 'fee_categories':
        return const ManageFeeCategoriesScreen();
      case 'ad_hoc_fee_assignment':
        {
          final now = DateTime.now();
          final currentYear = now.year;
          final nextYear = currentYear + 1;
          final academicYear = now.month >= 4
              ? '$currentYear-$nextYear'
              : '${currentYear - 1}-$currentYear';
          return AdHocFeeAssignmentScreen(
            schoolId: (session?.schoolId as String?) ?? '',
            academicYear: academicYear,
            onSuccess: () {
              // Navigate back to dashboard after successful assignment
              setState(() => _selectedMenuId = 'dashboard');
            },
          );
        }
      case 'delete_student':
        return const DeleteStudentScreen();
      case 'expenses':
        return const ExpenseEntryScreen();
      case 'bill_management':
        return const BillManagementScreen();
      case 'financial_reports':
        return const FinancialReportsScreen();
      case 'upload_sheet':
        return const UploadSheetScreen();
      case 'whatsapp_settings':
        final schoolId = session?.schoolId as String?;
        if (schoolId == null) {
          return const Center(child: Text('School ID not found'));
        }
        return WhatsAppSettingsScreen(schoolId: schoolId);
      case 'upi_settings':
        final upiSchoolId = session?.schoolId as String?;
        if (upiSchoolId == null) {
          return const Center(child: Text('School ID not found'));
        }
        return UPISettingsScreen(schoolId: upiSchoolId);
      case 'settings':
        return const SchoolSettingsScreen();
      default:
        return _buildDashboardHome(context, session, isDesktop, isTablet);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // DASHBOARD HOME - Mock-matching UI
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildDashboardHome(
    BuildContext context,
    dynamic session,
    bool isDesktop,
    bool isTablet,
  ) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth <= 600;
    final padding = isDesktop ? 28.0 : (isMobile ? 12.0 : 16.0);
    final schoolId = session?.schoolId as String?;
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';

    return SingleChildScrollView(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Greeting + 4 stat cards  |  Revenue chart
          isDesktop
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 5,
                      child: _buildGreetingSection(
                        session,
                        greeting,
                        schoolId,
                        isDesktop,
                        isTablet,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(flex: 4, child: _buildRevenueChartCard(schoolId)),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildGreetingSection(
                      session,
                      greeting,
                      schoolId,
                      isDesktop,
                      isTablet,
                    ),
                    const SizedBox(height: 20),
                    _buildRevenueChartCard(schoolId),
                  ],
                ),
          const SizedBox(height: 20),
          // Row 2: Staff overview | Finance overview | Fee trend
          isDesktop
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: _buildStaffOverviewPanel(schoolId),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 3,
                      child: _buildFinanceOverviewPanel(schoolId),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 4,
                      child: _buildStudentOverviewPanel(schoolId),
                    ),
                  ],
                )
              : Column(
                  children: [
                    _buildStaffOverviewPanel(schoolId),
                    const SizedBox(height: 16),
                    _buildFinanceOverviewPanel(schoolId),
                    const SizedBox(height: 16),
                    _buildStudentOverviewPanel(schoolId),
                  ],
                ),
          const SizedBox(height: 20),
          // Row 3: Quick actions | Recent activity
          isDesktop
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 320,
                      child: _buildQuickActions(isMobile: false),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: _buildRecentActivity(schoolId, isMobile: false),
                    ),
                  ],
                )
              : Column(
                  children: [
                    _buildQuickActions(isMobile: isMobile),
                    const SizedBox(height: 20),
                    _buildRecentActivity(schoolId, isMobile: isMobile),
                  ],
                ),
        ],
      ),
    );
  }

  // ── Greeting + 4 top stat cards ──────────────────────────────────────────
  Widget _buildGreetingSection(
    dynamic session,
    String greeting,
    String? schoolId,
    bool isDesktop,
    bool isTablet,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$greeting, ${session.displayName ?? 'Admin'}!',
          style: TextStyle(
            fontSize: isDesktop ? 26 : 20,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          "Here's today's operational snapshot",
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 20),
        if (schoolId != null)
          FutureBuilder<Map<String, dynamic>>(
            future: _fetchTopStats(schoolId),
            builder: (context, snap) {
              final d = snap.data ?? {};
              final fmt = NumberFormat.currency(
                locale: 'en_IN',
                symbol: '₹',
                decimalDigits: 0,
              );
              final cards = [
                _topStatCard(
                  'Total Staff',
                  '${d['staff'] ?? 0}',
                  'active staff',
                  Icons.people_alt_rounded,
                  const Color(0xFF3B82F6),
                  [const Color(0xFF1E3A5F), const Color(0xFF0D1117)],
                ),
                _topStatCard(
                  'On Leave',
                  '${d['onLeave'] ?? 0}',
                  'on leave today',
                  Icons.event_note_rounded,
                  const Color(0xFF8B5CF6),
                  [const Color(0xFF2D1B69), const Color(0xFF0D1117)],
                ),
                _topStatCard(
                  'Students',
                  '${d['students'] ?? 0}',
                  'total students',
                  Icons.school_rounded,
                  const Color(0xFFEC4899),
                  [const Color(0xFF5B1A3A), const Color(0xFF0D1117)],
                ),
                _topStatCard(
                  'Revenue Today',
                  fmt.format(d['todayRevenue'] ?? 0.0),
                  '↑ vs yesterday',
                  Icons.trending_up_rounded,
                  const Color(0xFF10B981),
                  [const Color(0xFF064E3B), const Color(0xFF0D1117)],
                ),
              ];
              return LayoutBuilder(
                builder: (ctx, constraints) {
                  final cols = isDesktop ? 4 : (isTablet ? 4 : 2);
                  final spacing = 12.0;
                  final cardW =
                      (constraints.maxWidth - spacing * (cols - 1)) / cols;
                  final cardH = 130.0;
                  return Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children: cards
                        .map(
                          (c) =>
                              SizedBox(width: cardW, height: cardH, child: c),
                        )
                        .toList(),
                  );
                },
              );
            },
          ),
      ],
    );
  }

  Widget _topStatCard(
    String label,
    String value,
    String sub,
    IconData icon,
    Color color,
    List<Color> grad,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: grad,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const Spacer(),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          Container(
            height: 2,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [color, color.withOpacity(0.1)]),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            sub,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: color.withOpacity(0.8), fontSize: 10),
          ),
        ],
      ),
    );
  }

  // ── Revenue chart card ───────────────────────────────────────────────────
  static const Map<String, String> _periodLabels = {
    'this_month': 'This Month',
    'this_quarter': 'This Quarter',
    'last_3_months': 'Last 3 Months',
    'last_6_months': 'Last 6 Months',
    'this_year': 'This Year',
    'this_fiscal_year': 'This Fiscal Year',
    'last_year': 'Last Year',
    'last_fiscal_year': 'Last Fiscal Year',
  };

  ({DateTime start, DateTime end}) _getDateRange(String period) {
    final now = DateTime.now();
    switch (period) {
      case 'this_month':
        return (
          start: DateTime(now.year, now.month, 1),
          end: DateTime(now.year, now.month + 1, 1),
        );
      case 'this_quarter':
        final qStart = ((now.month - 1) ~/ 3) * 3 + 1;
        return (
          start: DateTime(now.year, qStart, 1),
          end: DateTime(now.year, qStart + 3, 1),
        );
      case 'last_3_months':
        return (
          start: DateTime(now.year, now.month - 2, 1),
          end: DateTime(now.year, now.month + 1, 1),
        );
      case 'last_6_months':
        return (
          start: DateTime(now.year, now.month - 5, 1),
          end: DateTime(now.year, now.month + 1, 1),
        );
      case 'this_year':
        return (
          start: DateTime(now.year, 1, 1),
          end: DateTime(now.year + 1, 1, 1),
        );
      case 'this_fiscal_year':
        final fyStart = now.month >= 4
            ? DateTime(now.year, 4, 1)
            : DateTime(now.year - 1, 4, 1);
        final fyEnd = now.month >= 4
            ? DateTime(now.year + 1, 4, 1)
            : DateTime(now.year, 4, 1);
        return (start: fyStart, end: fyEnd);
      case 'last_year':
        return (
          start: DateTime(now.year - 1, 1, 1),
          end: DateTime(now.year, 1, 1),
        );
      case 'last_fiscal_year':
        final lfyStart = now.month >= 4
            ? DateTime(now.year - 1, 4, 1)
            : DateTime(now.year - 2, 4, 1);
        final lfyEnd = now.month >= 4
            ? DateTime(now.year, 4, 1)
            : DateTime(now.year - 1, 4, 1);
        return (start: lfyStart, end: lfyEnd);
      default:
        return (
          start: DateTime(now.year, now.month - 5, 1),
          end: DateTime(now.year, now.month + 1, 1),
        );
    }
  }

  Widget _buildRevenueChartCard(String? schoolId) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Monthly Revenue vs Expense',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _chartPeriod,
                    isDense: true,
                    dropdownColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    icon: Icon(
                      Icons.keyboard_arrow_down,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      size: 14,
                    ),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 10,
                    ),
                    items: _periodLabels.entries
                        .map(
                          (e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(e.value),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _chartPeriod = v);
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _legendDot(const Color(0xFF10B981), 'Revenue'),
              const SizedBox(width: 12),
              _legendDot(const Color(0xFFF59E0B), 'Expense'),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: schoolId == null
                ? Center(
                    child: Text(
                      'No school',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : _RevenueExpenseBarChart(
                    schoolId: schoolId,
                    period: _chartPeriod,
                    getDateRange: _getDateRange,
                    feeRepo: ref.read(feeRepositoryProvider),
                    expenseRepo: ref.read(expenseRepositoryProvider),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color c, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: c, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 11,
            ),
          ),
        ],
      );

  // ── Staff Overview panel ─────────────────────────────────────────────────
  Widget _buildStaffOverviewPanel(String? schoolId) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Staff Overview',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 16),
          if (schoolId == null)
            Text(
              'No school',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            )
          else
            FutureBuilder<Map<String, int>>(
              future: _fetchHRStats(schoolId),
              builder: (ctx, snap) {
                final d = snap.data ?? {};
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _overviewMiniCard(
                            context,
                            Icons.people_alt_rounded,
                            'Total Staff',
                            '${d['staff'] ?? 0}',
                            const Color(0xFF3B82F6),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _overviewMiniCard(
                            context,
                            Icons.event_note_rounded,
                            'On Leave',
                            '${d['onLeave'] ?? 0}',
                            const Color(0xFF8B5CF6),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _overviewMiniCard(
                            context,
                            Icons.pending_actions_rounded,
                            'Pending Leaves',
                            '${d['pendingLeaves'] ?? 0}',
                            const Color(0xFF10B981),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _overviewMiniCard(
                            context,
                            Icons.access_time_rounded,
                            'Pending Perms',
                            '${d['pendingPermissions'] ?? 0}',
                            const Color(0xFFEC4899),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _overviewMiniCard(
    BuildContext context,
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Finance Overview panel ───────────────────────────────────────────────
  Widget _buildFinanceOverviewPanel(String? schoolId) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Finance Overview',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 16),
          if (schoolId == null)
            Text(
              'No school',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            )
          else
            FutureBuilder<Map<String, dynamic>>(
              future: _fetchFinanceStats(schoolId),
              builder: (ctx, snap) {
                final d = snap.data ?? {};
                final fmt = NumberFormat.currency(
                  locale: 'en_IN',
                  symbol: '₹',
                  decimalDigits: 0,
                );
                return Column(
                  children: [
                    _financeOverviewTile(
                      Icons.trending_up_rounded,
                      "Today's Collection",
                      fmt.format(d['todayCollection'] ?? 0.0),
                      const Color(0xFF10B981),
                      isUp: true,
                    ),
                    const SizedBox(height: 12),
                    _financeOverviewTile(
                      Icons.trending_down_rounded,
                      "Today's Expenses",
                      fmt.format(d['todayExpenses'] ?? 0.0),
                      const Color(0xFFEF4444),
                      isUp: false,
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _financeOverviewTile(
    IconData icon,
    String label,
    String value,
    Color color, {
    required bool isUp,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 60,
            height: 30,
            child: CustomPaint(
              painter: _SparklinePainter(color: color, isUp: isUp),
            ),
          ),
        ],
      ),
    );
  }

  // ── Student Overview panel ───────────────────────────────────────────────
  Widget _buildStudentOverviewPanel(String? schoolId) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Student Overview',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 16),
          if (schoolId == null)
            Text(
              'No school',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            )
          else
            FutureBuilder<Map<String, dynamic>>(
              future: _fetchStudentOverview(schoolId),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _accentBlue,
                      ),
                    ),
                  );
                }
                final d = snap.data ?? {};
                final total = d['total'] ?? 0;
                final active = d['active'] ?? 0;
                final withLogin = d['withLogin'] ?? 0;
                final withoutLogin = d['withoutLogin'] ?? 0;
                final classCounts =
                    (d['classCounts'] as Map<String, int>?) ?? {};
                final topClasses = classCounts.entries.toList()
                  ..sort((a, b) => b.value.compareTo(a.value));
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _overviewMiniCard(
                            context,
                            Icons.school_rounded,
                            'Total Students',
                            '$total',
                            const Color(0xFF3B82F6),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _overviewMiniCard(
                            context,
                            Icons.check_circle_rounded,
                            'Active',
                            '$active',
                            const Color(0xFF10B981),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _overviewMiniCard(
                            context,
                            Icons.person_rounded,
                            'With Login',
                            '$withLogin',
                            const Color(0xFF8B5CF6),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _overviewMiniCard(
                            context,
                            Icons.person_off_rounded,
                            'No Login',
                            '$withoutLogin',
                            const Color(0xFFF59E0B),
                          ),
                        ),
                      ],
                    ),
                    if (topClasses.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'By Class',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: topClasses
                            .take(8)
                            .map(
                              (e) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surface,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.outline,
                                  ),
                                ),
                                child: Text(
                                  '${e.key}: ${e.value}',
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  // ── Quick Actions 2×3 grid ───────────────────────────────────────────────
  Widget _buildQuickActions({bool isMobile = false}) {
    final actions = [
      {
        'title': 'Add Staff',
        'icon': Icons.person_add_rounded,
        'menuId': 'staff_management',
        'color': const Color(0xFF3B82F6),
      },
      {
        'title': 'Add Student',
        'icon': Icons.school_rounded,
        'menuId': 'student_management',
        'color': const Color(0xFF8B5CF6),
      },
      {
        'title': 'Collect Fee',
        'icon': Icons.payment_rounded,
        'menuId': 'student_fee_mgmt',
        'color': const Color(0xFF10B981),
      },
      {
        'title': 'Record Expense',
        'icon': Icons.money_off_rounded,
        'menuId': 'expenses',
        'color': const Color(0xFFEF4444),
      },
      {
        'title': 'Upload Sheet',
        'icon': Icons.upload_file_rounded,
        'menuId': 'upload_sheet',
        'color': const Color(0xFF8B5CF6),
      },
      {
        'title': 'Reports',
        'icon': Icons.insights_rounded,
        'menuId': 'financial_reports',
        'color': const Color(0xFFF59E0B),
      },
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Quick Actions',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {},
                child: const Text(
                  'View All',
                  style: TextStyle(color: _accentBlue, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (ctx, constraints) {
              const cols = 2;
              const spacing = 10.0;
              final tileW =
                  (constraints.maxWidth - spacing * (cols - 1)) / cols;
              const tileH = 52.0;
              final tiles = actions
                  .map(
                    (a) => SizedBox(
                      width: tileW,
                      height: tileH,
                      child: _quickActionTile(
                        a['icon'] as IconData,
                        a['title'] as String,
                        a['color'] as Color,
                        a['menuId'] as String,
                      ),
                    ),
                  )
                  .toList();
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: tiles,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _quickActionTile(
    IconData icon,
    String title,
    Color color,
    String menuId,
  ) {
    return Material(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: () => setState(() => _selectedMenuId = menuId),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                  maxLines: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Recent Activity two-column ───────────────────────────────────────────
  Widget _buildRecentActivity(String? schoolId, {bool isMobile = false}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Recent Activity',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () {},
                icon: const Text(
                  'View All',
                  style: TextStyle(color: _accentBlue, fontSize: 12),
                ),
                label: const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: _accentBlue,
                  size: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (schoolId == null)
            Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'No school selected',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('schools')
                  .doc(schoolId)
                  .collection('bills')
                  .where('isDeleted', isEqualTo: false)
                  .orderBy('createdAt', descending: true)
                  .limit(6)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        'No recent activity',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  );
                }
                final docs = snapshot.data!.docs;
                if (isMobile) {
                  return Column(
                    children: docs
                        .map(
                          (d) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _activityTile(
                              d.data() as Map<String, dynamic>,
                            ),
                          ),
                        )
                        .toList(),
                  );
                }
                final rows = <Widget>[];
                for (int i = 0; i < docs.length; i += 2) {
                  rows.add(
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _activityTile(
                            docs[i].data() as Map<String, dynamic>,
                          ),
                        ),
                        const SizedBox(width: 12),
                        i + 1 < docs.length
                            ? Expanded(
                                child: _activityTile(
                                  docs[i + 1].data() as Map<String, dynamic>,
                                ),
                              )
                            : const Expanded(child: SizedBox()),
                      ],
                    ),
                  );
                  if (i + 2 < docs.length) rows.add(const SizedBox(height: 10));
                }
                return Column(children: rows);
              },
            ),
        ],
      ),
    );
  }

  Widget _activityTile(Map<String, dynamic> data) {
    final isExpense = data['billType'] == 'Expense';
    final amount = isExpense
        ? (data['expenseAmount'] as num? ?? 0.0)
        : (data['revenueAmount'] as num? ?? 0.0);
    final name = isExpense
        ? (data['expenseType'] ?? 'Expense')
        : (data['stuName'] ?? 'Fee Payment');
    final date = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    final color = isExpense ? const Color(0xFFEF4444) : _accentBlue;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isExpense ? Icons.money_off_rounded : Icons.payment_rounded,
              color: color,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.toString(),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  DateFormat('dd MMM, hh:mm a').format(date),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${isExpense ? '-' : '+'}₹${amount.toStringAsFixed(0)}',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // DATA FETCHING
  // ══════════════════════════════════════════════════════════════════════════
  Future<Map<String, dynamic>> _fetchTopStats(String schoolId) async {
    try {
      final hrStats = await _fetchHRStats(schoolId);
      final financeStats = await _fetchFinanceStats(schoolId);
      return {
        'staff': hrStats['staff'],
        'onLeave': hrStats['onLeave'],
        'students': financeStats['totalStudents'],
        'todayRevenue': financeStats['todayCollection'],
      };
    } catch (e) {
      return {};
    }
  }

  Future<Map<String, int>> _fetchHRStats(String schoolId) async {
    final firestore = FirebaseFirestore.instance;
    try {
      final staffSnapshot = await firestore
          .collection('schools')
          .doc(schoolId)
          .collection('staff')
          .where('status', isEqualTo: 'ACTIVE')
          .count()
          .get();
      final pendingLeavesSnapshot = await firestore
          .collection('schools')
          .doc(schoolId)
          .collection('leaves')
          .where('status', isEqualTo: 'PENDING')
          .count()
          .get();
      final pendingPermissionsSnapshot = await firestore
          .collection('schools')
          .doc(schoolId)
          .collection('permissions')
          .where('status', isEqualTo: 'PENDING')
          .count()
          .get();
      final today = DateTime.now();
      final todayStart = DateTime(today.year, today.month, today.day);
      final todayEnd = todayStart.add(const Duration(days: 1));
      final onLeaveSnapshot = await firestore
          .collection('schools')
          .doc(schoolId)
          .collection('leaves')
          .where('status', isEqualTo: 'APPROVED')
          .where('startDate', isLessThanOrEqualTo: Timestamp.fromDate(todayEnd))
          .get();
      int onLeaveCount = 0;
      for (final doc in onLeaveSnapshot.docs) {
        final endDate = (doc.data()['endDate'] as Timestamp?)?.toDate();
        if (endDate != null && endDate.isAfter(todayStart)) onLeaveCount++;
      }
      return {
        'staff': staffSnapshot.count ?? 0,
        'pendingLeaves': pendingLeavesSnapshot.count ?? 0,
        'pendingPermissions': pendingPermissionsSnapshot.count ?? 0,
        'onLeave': onLeaveCount,
      };
    } catch (e) {
      debugPrint('Error fetching HR stats: $e');
      return {
        'staff': 0,
        'pendingLeaves': 0,
        'pendingPermissions': 0,
        'onLeave': 0,
      };
    }
  }

  Future<Map<String, dynamic>> _fetchStudentOverview(String schoolId) async {
    try {
      final firestore = FirebaseFirestore.instance;
      final snapshot = await firestore
          .collection('schools')
          .doc(schoolId)
          .collection('students')
          .get();

      int total = 0;
      int active = 0;
      int withLogin = 0;
      int withoutLogin = 0;
      final classCounts = <String, int>{};

      for (final doc in snapshot.docs) {
        final data = doc.data();
        // Skip system-seeded placeholder docs (legacy `_meta` seeds) so
        // they don't show up as phantom "Unknown: 1" entries with no
        // login on a freshly-provisioned school.
        if (data['__system'] == true || data['isPlaceholder'] == true) continue;
        total++;
        final status = (data['status'] as String?)?.toUpperCase() ?? 'ACTIVE';
        if (status == 'ACTIVE') active++;
        final parentUserId = data['parentUserId'] as String?;
        if (parentUserId != null && parentUserId.isNotEmpty) {
          withLogin++;
        } else {
          withoutLogin++;
        }
        final className = data['className'] as String? ?? 'Unknown';
        classCounts[className] = (classCounts[className] ?? 0) + 1;
      }

      return {
        'total': total,
        'active': active,
        'withLogin': withLogin,
        'withoutLogin': withoutLogin,
        'classCounts': classCounts,
      };
    } catch (e) {
      debugPrint('Error fetching student overview: $e');
      return {
        'total': 0,
        'active': 0,
        'withLogin': 0,
        'withoutLogin': 0,
        'classCounts': <String, int>{},
      };
    }
  }

  Future<Map<String, dynamic>> _fetchFinanceStats(String schoolId) async {
    try {
      final feeRepo = ref.read(feeRepositoryProvider);
      final expenseRepo = ref.read(expenseRepositoryProvider);
      final todayCollection = await feeRepo.getTodayCollection(schoolId);
      final todayExpenses = await expenseRepo.getTodayExpenses(schoolId);
      final feeSummary = await feeRepo.getFeeSummary(schoolId);
      return {
        'totalStudents': feeSummary.totalStudents,
        'todayCollection': todayCollection,
        'todayExpenses': todayExpenses,
        'outstandingFees': feeSummary.outstandingFees,
      };
    } catch (e) {
      debugPrint('Error fetching finance stats: $e');
      return {
        'totalStudents': 0,
        'todayCollection': 0.0,
        'todayExpenses': 0.0,
        'outstandingFees': 0.0,
      };
    }
  }

  Widget _buildComingSoonScreen(String title) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.construction,
              size: 80,
              color: Colors.amber.withOpacity(0.8),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Coming Soon',
              style: TextStyle(
                fontSize: 20,
                color: Colors.amber,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'This feature is currently under development and will be available in a future update.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// CHART WIDGETS
// ══════════════════════════════════════════════════════════════════════════

/// Real DB-powered Revenue vs Expense bar chart
class _RevenueExpenseBarChart extends StatefulWidget {
  final String schoolId;
  final String period;
  final ({DateTime start, DateTime end}) Function(String) getDateRange;
  final FeeRepository feeRepo;
  final ExpenseRepository expenseRepo;

  const _RevenueExpenseBarChart({
    required this.schoolId,
    required this.period,
    required this.getDateRange,
    required this.feeRepo,
    required this.expenseRepo,
  });

  @override
  State<_RevenueExpenseBarChart> createState() =>
      _RevenueExpenseBarChartState();
}

class _RevenueExpenseBarChartState extends State<_RevenueExpenseBarChart> {
  Map<String, double> _revenue = {};
  Map<String, double> _expense = {};
  List<String> _monthKeys = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(_RevenueExpenseBarChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.period != widget.period ||
        oldWidget.schoolId != widget.schoolId) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final range = widget.getDateRange(widget.period);
      final revenueData = await widget.feeRepo.getMonthlyRevenue(
        widget.schoolId,
        range.start,
        range.end,
      );
      final expenseData = await widget.expenseRepo.getMonthlyExpensesByRange(
        widget.schoolId,
        range.start,
        range.end,
      );

      // Build sorted month keys for the range
      final keys = <String>[];
      var cursor = DateTime(range.start.year, range.start.month);
      while (cursor.isBefore(range.end)) {
        keys.add('${cursor.year}-${cursor.month.toString().padLeft(2, '0')}');
        cursor = DateTime(cursor.year, cursor.month + 1);
      }

      if (mounted) {
        setState(() {
          _monthKeys = keys;
          _revenue = revenueData;
          _expense = expenseData;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  String _formatKey(String key) {
    final parts = key.split('-');
    if (parts.length == 2) {
      final m = int.tryParse(parts[1]);
      if (m != null && m >= 1 && m <= 12) {
        return '${_months[m - 1]}\'${parts[0].substring(2)}';
      }
    }
    return key;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Color(0xFF10B981),
        ),
      );
    }
    if (_monthKeys.isEmpty) {
      return const Center(
        child: Text(
          'No data for selected period',
          style: TextStyle(color: Color(0xFF8B949E), fontSize: 12),
        ),
      );
    }

    final allValues = <double>[];
    for (final k in _monthKeys) {
      allValues.add(_revenue[k] ?? 0);
      allValues.add(_expense[k] ?? 0);
    }
    final maxVal =
        allValues.isEmpty ? 1.0 : (allValues.reduce((a, b) => a > b ? a : b));
    final maxH = maxVal == 0 ? 1.0 : maxVal;
    final barAreaHeight = 120.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final availWidth = constraints.maxWidth;
        final barGroupWidth = (availWidth / _monthKeys.length).clamp(
          30.0,
          60.0,
        );

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: _monthKeys.map((key) {
              final rev = _revenue[key] ?? 0;
              final exp = _expense[key] ?? 0;
              final revH = (rev / maxH * barAreaHeight).clamp(
                2.0,
                barAreaHeight,
              );
              final expH = (exp / maxH * barAreaHeight).clamp(
                2.0,
                barAreaHeight,
              );
              return SizedBox(
                width: barGroupWidth,
                child: Tooltip(
                  message:
                      'Revenue: ₹${rev.toStringAsFixed(0)}\nExpense: ₹${exp.toStringAsFixed(0)}',
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            width: 10,
                            height: revH,
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(width: 3),
                          Container(
                            width: 10,
                            height: expH,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _formatKey(key),
                        style: const TextStyle(
                          color: Color(0xFF8B949E),
                          fontSize: 9,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final Color color;
  final bool isUp;
  _SparklinePainter({required this.color, required this.isUp});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final path = Path();
    final points = isUp
        ? [0.6, 0.4, 0.5, 0.3, 0.4, 0.2]
        : [0.3, 0.4, 0.35, 0.5, 0.45, 0.6];
    for (int i = 0; i < points.length; i++) {
      final x = i * size.width / (points.length - 1);
      final y = points[i] * size.height;
      if (i == 0)
        path.moveTo(x, y);
      else
        path.lineTo(x, y);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
