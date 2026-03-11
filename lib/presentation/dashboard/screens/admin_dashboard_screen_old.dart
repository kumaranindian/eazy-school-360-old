import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/security/route_guard.dart';
import '../../../core/security/role_policy.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../admin/screens/staff_management_screen.dart';
import '../../admin/screens/leave_policy_config_screen.dart';
import '../../admin/screens/permission_policy_config_screen.dart';
import '../../admin/screens/leave_approval_screen.dart';
import '../../admin/screens/permission_approval_screen.dart';
import '../../admin/screens/holiday_management_screen.dart';
import '../../auth/screens/enhanced_login_screen.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  int _selectedIndex = 0;

  // Dark theme colors matching the design
  static const Color _bgDark = Color(0xFF0D1117);
  static const Color _cardDark = Color(0xFF161B22);
  static const Color _sidebarDark = Color(0xFF0D1117);
  static const Color _accentBlue = Color(0xFF4CAF50);
  static const Color _textPrimary = Color(0xFFE6EDF3);
  static const Color _textSecondary = Color(0xFF8B949E);
  static const Color _borderColor = Color(0xFF30363D);

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
      backgroundColor: _sidebarDark,
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
                        Text('360 Admin Portal', style: TextStyle(fontSize: 11, color: _textSecondary)),
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
                  _buildDrawerNavItem(context, Icons.people_alt_rounded, 'Staff Management', 1),
                  _buildDrawerNavItem(context, Icons.event_note_rounded, 'Leave Requests', 2),
                  _buildDrawerNavItem(context, Icons.policy_rounded, 'Leave Policy', 3),
                  _buildDrawerNavItem(context, Icons.access_time_rounded, 'Permission Requests', 4),
                  _buildDrawerNavItem(context, Icons.tune_rounded, 'Permission Policy', 5),
                  _buildDrawerNavItem(context, Icons.calendar_month_rounded, 'Holiday Management', 6),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Divider(color: Color(0xFF30363D)),
                  ),
                  _buildDrawerNavItemBeta(context, Icons.school_rounded, 'Student Management'),
                  _buildDrawerNavItemBeta(context, Icons.account_balance_wallet_rounded, 'Finance Management'),
                  _buildDrawerNavItemBeta(context, Icons.bar_chart_rounded, 'Reports'),
                  _buildDrawerNavItemBeta(context, Icons.settings_rounded, 'Settings'),
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
                    child: Text((session.displayName as String? ?? 'A')[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(session.displayName as String? ?? 'Admin', style: const TextStyle(color: _textPrimary, fontWeight: FontWeight.w600, fontSize: 13), overflow: TextOverflow.ellipsis),
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

  Widget _buildDrawerNavItemBeta(BuildContext context, IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () {
            Navigator.pop(context);
            _showComingSoonDialog(label);
          },
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(icon, color: _textSecondary.withOpacity(0.6), size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text(label, style: TextStyle(color: _textSecondary.withOpacity(0.6), fontWeight: FontWeight.w500, fontSize: 13))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: _accentBlue.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                  child: const Text('Beta', style: TextStyle(color: _accentBlue, fontSize: 9, fontWeight: FontWeight.bold)),
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
      width: 260,
      color: _sidebarDark,
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
                      Text('360 Admin Portal', style: TextStyle(fontSize: 11, color: _textSecondary)),
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
                _buildNavItem(Icons.people_alt_rounded, 'Staff Management', 1),
                _buildNavItem(Icons.event_note_rounded, 'Leave Requests', 2),
                _buildNavItem(Icons.policy_rounded, 'Leave Policy', 3),
                _buildNavItem(Icons.access_time_rounded, 'Permission Requests', 4),
                _buildNavItem(Icons.tune_rounded, 'Permission Policy', 5),
                _buildNavItem(Icons.calendar_month_rounded, 'Holiday Management', 6),
                const SizedBox(height: 8),
                _buildNavItemBeta(Icons.school_rounded, 'Student Management', 7),
                _buildNavItemBeta(Icons.account_balance_wallet_rounded, 'Finance Management', 8),
                const SizedBox(height: 8),
                _buildNavItemBeta(Icons.bar_chart_rounded, 'Reports', 9),
                _buildNavItemBeta(Icons.settings_rounded, 'Settings', 10),
              ],
            ),
          ),
          
          // User Info
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _cardDark,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _borderColor),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: _accentBlue,
                  radius: 18,
                  child: Text(
                    (session.displayName as String? ?? 'A')[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(session.displayName as String? ?? 'Admin', style: const TextStyle(color: _textPrimary, fontWeight: FontWeight.w600, fontSize: 13), overflow: TextOverflow.ellipsis),
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

  Widget _buildNavItemBeta(IconData icon, String label, int index) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () => _showComingSoonDialog(label),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              children: [
                Icon(icon, color: _textSecondary.withOpacity(0.6), size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text(label, style: TextStyle(color: _textSecondary.withOpacity(0.6), fontWeight: FontWeight.w500, fontSize: 13))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: _accentBlue.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                  child: const Text('Beta', style: TextStyle(color: _accentBlue, fontSize: 9, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItemComingSoon(IconData icon, String label, int index) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () => _showComingSoonDialog(label),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              children: [
                Icon(icon, color: _textSecondary.withOpacity(0.5), size: 20),
                const SizedBox(width: 12),
                Text(label, style: TextStyle(color: _textSecondary.withOpacity(0.5), fontWeight: FontWeight.w500, fontSize: 13)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showComingSoonDialog(String featureName) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: _cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(28),
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: _accentBlue.withOpacity(0.15), shape: BoxShape.circle),
                child: const Icon(Icons.rocket_launch_rounded, size: 40, color: _accentBlue),
              ),
              const SizedBox(height: 20),
              Text(featureName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _textPrimary)),
              const SizedBox(height: 10),
              const Text('This feature is coming soon! We\'re working hard to bring you an amazing experience.', style: TextStyle(fontSize: 13, color: _textSecondary, height: 1.5), textAlign: TextAlign.center),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(backgroundColor: _accentBlue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  child: const Text('Got it!', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getAdminPageTitle() {
    switch (_selectedIndex) {
      case 0: return 'Dashboard';
      case 1: return 'Staff Management';
      case 2: return 'Leave Requests';
      case 3: return 'Leave Policy';
      case 4: return 'Permission Requests';
      case 5: return 'Permission Policy';
      case 6: return 'Holiday Management';
      default: return 'Dashboard';
    }
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
            const SizedBox(width: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset('assets/images/eazyschool.png', width: 36, height: 36, fit: BoxFit.contain),
            ),
            const SizedBox(width: 12),
            Text(_getAdminPageTitle(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _textPrimary)),
          ],
          if (isDesktop)
            Text(_getAdminPageTitle(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _textPrimary)),
          
          const Spacer(),
          
          // Notifications
          Stack(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: _cardDark, borderRadius: BorderRadius.circular(8), border: Border.all(color: _borderColor)),
                child: const Icon(Icons.notifications_outlined, color: _textSecondary, size: 20),
              ),
              Positioned(
                right: 4, top: 4,
                child: Container(
                  width: 8, height: 8,
                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                ),
              ),
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
                    child: Text((session.displayName as String? ?? 'A')[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                  if (isDesktop) ...[
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(session.displayName as String? ?? 'Admin', style: const TextStyle(color: _textPrimary, fontWeight: FontWeight.w600, fontSize: 12)),
                        const Text('Administrator', style: TextStyle(color: _textSecondary, fontSize: 10)),
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

  Widget _buildContent(BuildContext context, dynamic session, bool isDesktop, bool isTablet) {
    switch (_selectedIndex) {
      case 0: return _buildDashboardHome(context, session, isDesktop, isTablet);
      case 1: return const StaffManagementScreen();
      case 2: return const LeaveApprovalScreen();
      case 3: return const LeavePolicyConfigScreen();
      case 4: return const PermissionApprovalScreen();
      case 5: return const PermissionPolicyConfigScreen();
      case 6: return const HolidayManagementScreen();
      default: return _buildComingSoon();
    }
  }

  Widget _buildDashboardHome(BuildContext context, dynamic session, bool isDesktop, bool isTablet) {
    final padding = isDesktop ? 28.0 : 16.0;
    
    return SingleChildScrollView(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Page Header
          Text('Dashboard', style: TextStyle(fontSize: isDesktop ? 26 : 22, fontWeight: FontWeight.bold, color: _textPrimary)),
          const SizedBox(height: 4),
          const Text('Welcome back! Here\'s what\'s happening at Eazy School 360.', style: TextStyle(color: _textSecondary, fontSize: 14)),
          
          const SizedBox(height: 24),
          
          // Stats Cards Row
          _buildStatsRow(isDesktop, isTablet),
          
          const SizedBox(height: 24),
          
          // Quick Actions and Recent Activity
          isDesktop
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 1, child: _buildQuickActions()),
                    const SizedBox(width: 24),
                    Expanded(flex: 2, child: _buildRecentActivity()),
                  ],
                )
              : Column(
                  children: [
                    _buildQuickActions(),
                    const SizedBox(height: 20),
                    _buildRecentActivity(),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(bool isDesktop, bool isTablet) {
    final session = ref.watch(currentSessionProvider);
    final schoolId = session?.schoolId;

    if (schoolId == null) {
      return const Center(child: Text('No school selected', style: TextStyle(color: _textSecondary)));
    }

    return FutureBuilder<Map<String, int>>(
      future: _fetchDashboardStats(schoolId),
      builder: (context, snapshot) {
        final data = snapshot.data ?? {'staff': 0, 'pendingLeaves': 0, 'pendingPermissions': 0, 'onLeave': 0};
        
        final stats = [
          {'title': 'Total Staff', 'value': '${data['staff'] ?? 0}', 'icon': Icons.people_alt_rounded, 'color': const Color(0xFF3B82F6)},
          {'title': 'Pending Leaves', 'value': '${data['pendingLeaves'] ?? 0}', 'icon': Icons.event_note_rounded, 'color': const Color(0xFFF59E0B)},
          {'title': 'Pending Permissions', 'value': '${data['pendingPermissions'] ?? 0}', 'icon': Icons.access_time_rounded, 'color': const Color(0xFF10B981)},
          {'title': 'On Leave Today', 'value': '${data['onLeave'] ?? 0}', 'icon': Icons.pending_actions_rounded, 'color': const Color(0xFFEF4444)},
        ];

        if (isDesktop) {
          return Row(
            children: stats.map((stat) => Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: stat == stats.last ? 0 : 16),
                child: _buildStatCard(stat['title'] as String, stat['value'] as String, stat['icon'] as IconData, stat['color'] as Color),
              ),
            )).toList(),
          );
        }

        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: isTablet ? 4 : 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: isTablet ? 1.8 : 1.6,
          children: stats.map((stat) => _buildStatCard(stat['title'] as String, stat['value'] as String, stat['icon'] as IconData, stat['color'] as Color)).toList(),
        );
      },
    );
  }

  Future<Map<String, int>> _fetchDashboardStats(String schoolId) async {
    final firestore = FirebaseFirestore.instance;
    
    try {
      // Get total staff count (status field stores 'ACTIVE' string)
      final staffSnapshot = await firestore
          .collection('schools')
          .doc(schoolId)
          .collection('staff')
          .where('status', isEqualTo: 'ACTIVE')
          .count()
          .get();

      // Get pending leaves count
      final pendingLeavesSnapshot = await firestore
          .collection('schools')
          .doc(schoolId)
          .collection('leaves')
          .where('status', isEqualTo: 'PENDING')
          .count()
          .get();

      // Get pending permissions count
      final pendingPermissionsSnapshot = await firestore
          .collection('schools')
          .doc(schoolId)
          .collection('permissions')
          .where('status', isEqualTo: 'PENDING')
          .count()
          .get();

      // Get staff on leave today
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

      // Filter for leaves that include today
      int onLeaveCount = 0;
      for (final doc in onLeaveSnapshot.docs) {
        final endDate = (doc.data()['endDate'] as Timestamp?)?.toDate();
        if (endDate != null && endDate.isAfter(todayStart)) {
          onLeaveCount++;
        }
      }

      return {
        'staff': staffSnapshot.count ?? 0,
        'pendingLeaves': pendingLeavesSnapshot.count ?? 0,
        'pendingPermissions': pendingPermissionsSnapshot.count ?? 0,
        'onLeave': onLeaveCount,
      };
    } catch (e) {
      debugPrint('Error fetching dashboard stats: $e');
      return {'staff': 0, 'pendingLeaves': 0, 'pendingPermissions': 0, 'onLeave': 0};
    }
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title, style: const TextStyle(color: _textSecondary, fontSize: 12)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(color: _textPrimary, fontSize: 22, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    final actions = [
      {'title': 'Add New Staff', 'icon': Icons.person_add_rounded, 'index': 1},
      {'title': 'Add New Student', 'icon': Icons.school_rounded, 'index': 5},
      {'title': 'View Reports', 'icon': Icons.bar_chart_rounded, 'index': 7},
      {'title': 'Review Leave Requests', 'icon': Icons.event_note_rounded, 'index': 2},
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: _cardDark, borderRadius: BorderRadius.circular(12), border: Border.all(color: _borderColor)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Quick Actions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _textPrimary)),
          const SizedBox(height: 16),
          ...actions.map((action) => _buildQuickActionItem(action['title'] as String, action['icon'] as IconData, action['index'] as int)),
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
          onTap: () {
            if (index == 5 || index == 7) {
              _showComingSoonDialog(title);
            } else {
              setState(() => _selectedIndex = index);
            }
          },
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

  Widget _buildRecentActivity() {
    final session = ref.watch(currentSessionProvider);
    final schoolId = session?.schoolId;

    if (schoolId == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: _cardDark, borderRadius: BorderRadius.circular(12), border: Border.all(color: _borderColor)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Recent Activity', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _textPrimary)),
              TextButton(onPressed: () {}, child: const Text('View All', style: TextStyle(color: _accentBlue, fontSize: 12))),
            ],
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _fetchRecentActivity(schoolId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(color: _accentBlue),
                ));
              }
              
              final activities = snapshot.data ?? [];
              
              if (activities.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: Text('No recent activity', style: TextStyle(color: _textSecondary))),
                );
              }
              
              return Column(
                children: activities.map((activity) => _buildActivityItem(
                  activity['title'] as String,
                  activity['subtitle'] as String,
                  activity['time'] as String,
                  activity['icon'] as IconData,
                  activity['color'] as Color,
                )).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _fetchRecentActivity(String schoolId) async {
    final firestore = FirebaseFirestore.instance;
    final List<Map<String, dynamic>> activities = [];
    
    try {
      // Get recent leaves
      final leavesSnapshot = await firestore
          .collection('schools')
          .doc(schoolId)
          .collection('leaves')
          .orderBy('createdAt', descending: true)
          .limit(5)
          .get();

      for (final doc in leavesSnapshot.docs) {
        final data = doc.data();
        final status = data['status'] as String? ?? 'PENDING';
        final staffName = data['staffName'] as String? ?? 'Staff';
        final createdAt = data['createdAt'] as Timestamp?;
        final timeAgo = createdAt != null ? _formatTimeAgo(createdAt.toDate()) : 'Unknown';
        
        activities.add({
          'title': status == 'PENDING' ? 'Leave Request' : 'Leave $status',
          'subtitle': '$staffName requested leave',
          'time': timeAgo,
          'icon': status == 'APPROVED' ? Icons.check_circle_rounded : Icons.event_note_rounded,
          'color': status == 'APPROVED' ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
        });
      }

      return activities;
    } catch (e) {
      debugPrint('Error fetching recent activity: $e');
      return [];
    }
  }

  Map<String, dynamic> _mapActionToActivity(String action, Map<String, dynamic> data, String timeAgo) {
    switch (action) {
      case 'LEAVE_APPROVED':
        return {
          'title': 'Leave Approved',
          'subtitle': 'Leave request approved',
          'time': timeAgo,
          'icon': Icons.check_circle_rounded,
          'color': const Color(0xFF10B981),
        };
      case 'LEAVE_REJECTED':
        return {
          'title': 'Leave Rejected',
          'subtitle': 'Leave request rejected',
          'time': timeAgo,
          'icon': Icons.cancel_rounded,
          'color': const Color(0xFFEF4444),
        };
      case 'PERMISSION_APPROVED':
        return {
          'title': 'Permission Approved',
          'subtitle': 'Permission request approved',
          'time': timeAgo,
          'icon': Icons.check_circle_rounded,
          'color': const Color(0xFF10B981),
        };
      case 'PERMISSION_REJECTED':
        return {
          'title': 'Permission Rejected',
          'subtitle': 'Permission request rejected',
          'time': timeAgo,
          'icon': Icons.cancel_rounded,
          'color': const Color(0xFFEF4444),
        };
      case 'STAFF_CREATED':
        return {
          'title': 'New Staff Added',
          'subtitle': 'New staff member joined',
          'time': timeAgo,
          'icon': Icons.person_add_rounded,
          'color': const Color(0xFF3B82F6),
        };
      default:
        return {
          'title': action.replaceAll('_', ' '),
          'subtitle': 'Activity recorded',
          'time': timeAgo,
          'icon': Icons.info_rounded,
          'color': const Color(0xFF8B5CF6),
        };
    }
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  Widget _buildActivityItem(String title, String subtitle, String time, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: _textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(color: _textSecondary, fontSize: 12)),
              ],
            ),
          ),
          Text(time, style: const TextStyle(color: _textSecondary, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildComingSoon() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: _cardDark, shape: BoxShape.circle),
            child: const Icon(Icons.construction_rounded, size: 56, color: _textSecondary),
          ),
          const SizedBox(height: 20),
          const Text('Coming Soon', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _textPrimary)),
          const SizedBox(height: 8),
          const Text('This feature is under development', style: TextStyle(color: _textSecondary)),
        ],
      ),
    );
  }

}
