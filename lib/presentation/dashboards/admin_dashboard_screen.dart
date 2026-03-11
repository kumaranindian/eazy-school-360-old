import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eazy_school_360/core/providers/auth_provider.dart';
import 'package:eazy_school_360/core/routing/app_router.dart';
import 'package:eazy_school_360/presentation/admin/screens/staff_management_screen.dart';
import 'package:eazy_school_360/presentation/admin/screens/leave_approval_screen.dart';
import 'package:eazy_school_360/presentation/admin/screens/leave_type_management_screen.dart';
import 'package:eazy_school_360/presentation/admin/screens/permission_type_management_screen.dart';
import 'package:eazy_school_360/presentation/admin/screens/student_attendance_screen.dart';
import 'package:eazy_school_360/presentation/admin/screens/student_leave_approval_screen.dart';
import 'package:eazy_school_360/presentation/admin/screens/student_directory_screen.dart';
import 'package:eazy_school_360/presentation/admin/screens/permission_approval_screen.dart';
import 'package:eazy_school_360/presentation/admin/screens/holiday_management_screen.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  int _selectedNavIndex = 0;

  // Dark theme colors
  static const Color _bgDark = Color(0xFF0D1117);
  static const Color _cardDark = Color(0xFF161B22);
  static const Color _accentBlue = Color(0xFF4CAF50);
  static const Color _textPrimary = Color(0xFFE6EDF3);
  static const Color _textSecondary = Color(0xFF8B949E);
  static const Color _borderColor = Color(0xFF30363D);

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(currentSessionProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final isWideScreen = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: _bgDark,
      body: Row(
        children: [
          // Side Navigation for wide screens
          if (isWideScreen)
            _buildSideNavigation(context, colorScheme),
          
          // Main Content
          Expanded(
            child: Column(
              children: [
                // Top App Bar
                _buildTopBar(context, session, colorScheme),
                
                // Dashboard Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Welcome Header
                        _buildWelcomeHeader(session, colorScheme),
                        const SizedBox(height: 24),
                        
                        // Stats Cards
                        _buildStatsRow(colorScheme),
                        const SizedBox(height: 24),
                        
                        // Quick Actions Grid
                        Text(
                          'Quick Actions',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildQuickActionsGrid(context, colorScheme),
                        const SizedBox(height: 24),
                        
                        // Recent Activity Section
                        _buildRecentActivitySection(context, colorScheme),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      // Bottom Navigation for mobile
      bottomNavigationBar: isWideScreen ? null : _buildBottomNavigation(colorScheme),
    );
  }

  Widget _buildSideNavigation(BuildContext context, ColorScheme colorScheme) {
    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: _cardDark,
        border: Border(right: BorderSide(color: _borderColor)),
      ),
      child: Column(
        children: [
          // Logo Section
          Container(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_accentBlue, _accentBlue.withOpacity(0.8)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.school, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Eazy School',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: _borderColor),
          
          // Navigation Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _buildNavItem(Icons.dashboard_rounded, 'Dashboard', 0, colorScheme),
                _buildNavItem(Icons.people_rounded, 'Staff Management', 1, colorScheme),
                _buildNavItem(Icons.event_note_rounded, 'Leave Requests', 2, colorScheme),
                _buildNavItem(Icons.access_time_rounded, 'Permissions', 3, colorScheme),
                _buildNavItem(Icons.category_rounded, 'Leave Types', 4, colorScheme),
                _buildNavItem(Icons.rule_rounded, 'Permission Types', 5, colorScheme),
                _buildNavItem(Icons.calendar_month_rounded, 'Holiday Calendar', 6, colorScheme),
                const Divider(height: 32),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Text('STUDENT MANAGEMENT', style: TextStyle(color: _textSecondary.withOpacity(0.6), fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1)),
                ),
                _buildNavItem(Icons.school_rounded, 'Student Directory', 10, colorScheme),
                _buildNavItem(Icons.fact_check_rounded, 'Student Attendance', 8, colorScheme),
                _buildNavItem(Icons.pending_actions_rounded, 'Student Leaves', 9, colorScheme),
                const Divider(height: 32),
                _buildNavItem(Icons.developer_mode, 'Developer Tools', 7, colorScheme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index, ColorScheme colorScheme) {
    final isSelected = _selectedNavIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: isSelected ? _accentBlue.withOpacity(0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: () => _handleNavigation(index),
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isSelected ? _accentBlue : _textSecondary,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? _accentBlue : _textPrimary,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, dynamic session, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: _cardDark,
        border: Border(bottom: BorderSide(color: _borderColor)),
      ),
      child: Row(
        children: [
          // Search Bar - BLACK BACKGROUND
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              child: TextField(
                style: const TextStyle(color: _textPrimary),
                decoration: InputDecoration(
                  hintText: 'Search...',
                  hintStyle: const TextStyle(color: _textSecondary),
                  prefixIcon: const Icon(Icons.search, color: _textSecondary),
                  filled: true,
                  fillColor: _bgDark,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _accentBlue),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          
          // Notifications
          IconButton(
            icon: Badge(
              label: const Text('3'),
              child: const Icon(Icons.notifications_outlined, color: _textSecondary),
            ),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
          
          // User Menu
          PopupMenuButton<String>(
            offset: const Offset(0, 50),
            color: _cardDark,
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: _accentBlue,
                  radius: 18,
                  child: Text(
                    ((session?.displayName as String?) ?? 'A')[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      (session?.displayName as String?) ?? 'Admin',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: _textPrimary),
                    ),
                    const Text(
                      'School Admin',
                      style: TextStyle(color: _textSecondary, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(width: 4),
                const Icon(Icons.keyboard_arrow_down, color: _textSecondary),
              ],
            ),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'profile', child: Text('Profile', style: TextStyle(color: _textPrimary))),
              const PopupMenuItem(value: 'settings', child: Text('Settings', style: TextStyle(color: _textPrimary))),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'logout', child: Text('Logout', style: TextStyle(color: _textPrimary))),
            ],
            onSelected: (value) async {
              if (value == 'logout') {
                await ref.read(authProvider.notifier).signOut();
                if (context.mounted) {
                  context.goToLogin();
                }
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeHeader(dynamic session, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colorScheme.primary, colorScheme.primary.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back, ${session?.displayName ?? 'Admin'}!',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Here\'s what\'s happening with your school today.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.school, color: Colors.white, size: 48),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(ColorScheme colorScheme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 600;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _buildStatCard('Total Staff', '35', Icons.people, Colors.blue, isNarrow),
            _buildStatCard('Pending Leaves', '5', Icons.event_note, Colors.orange, isNarrow),
            _buildStatCard('Active Today', '28', Icons.check_circle, Colors.green, isNarrow),
            _buildStatCard('On Leave', '7', Icons.event_busy, Colors.red, isNarrow),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, bool isNarrow) {
    return Container(
      width: isNarrow ? double.infinity : 200,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                title,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsGrid(BuildContext context, ColorScheme colorScheme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 800 ? 4 : (constraints.maxWidth > 500 ? 3 : 2);
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.2,
          children: [
            _buildActionCard('Manage Staff', Icons.people_rounded, Colors.blue, () => _handleNavigation(1)),
            _buildActionCard('Leave Requests', Icons.event_note_rounded, Colors.orange, () => _handleNavigation(2)),
            _buildActionCard('Permissions', Icons.access_time_rounded, Colors.purple, () => _handleNavigation(3)),
            _buildActionCard('Leave Types', Icons.category_rounded, Colors.teal, () => _handleNavigation(4)),
            _buildActionCard('Permission Types', Icons.rule_rounded, Colors.indigo, () => _handleNavigation(5)),
            _buildActionCard('Student Directory', Icons.school_rounded, Colors.cyan, () => _handleNavigation(10)),
            _buildActionCard('Student Attendance', Icons.fact_check_rounded, Colors.deepOrange, () => _handleNavigation(8)),
            _buildActionCard('Reports', Icons.analytics_rounded, Colors.pink, () => _showComingSoon(context)),
            _buildActionCard('Settings', Icons.settings_rounded, Colors.grey, () => _showComingSoon(context)),
          ],
        );
      },
    );
  }

  Widget _buildActionCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentActivitySection(BuildContext context, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Activity',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () {},
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildActivityItem(
            'John Smith',
            'Applied for Casual Leave',
            '2 hours ago',
            Icons.event_note,
            Colors.orange,
          ),
          _buildActivityItem(
            'Emily Davis',
            'Leave request approved',
            '5 hours ago',
            Icons.check_circle,
            Colors.green,
          ),
          _buildActivityItem(
            'Michael Brown',
            'Requested early departure',
            'Yesterday',
            Icons.access_time,
            Colors.purple,
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(String name, String action, String time, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  action,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
              ],
            ),
          ),
          Text(
            time,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigation(ColorScheme colorScheme) {
    return NavigationBar(
      selectedIndex: _selectedNavIndex > 3 ? 0 : _selectedNavIndex,
      onDestinationSelected: _handleNavigation,
      destinations: const [
        NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Dashboard'),
        NavigationDestination(icon: Icon(Icons.people_outlined), selectedIcon: Icon(Icons.people), label: 'Staff'),
        NavigationDestination(icon: Icon(Icons.event_note_outlined), selectedIcon: Icon(Icons.event_note), label: 'Leaves'),
        NavigationDestination(icon: Icon(Icons.more_horiz), label: 'More'),
      ],
    );
  }

  void _handleNavigation(int index) {
    setState(() => _selectedNavIndex = index);
    
    switch (index) {
      case 1:
        Navigator.push(context, MaterialPageRoute(builder: (_) => const StaffManagementScreen()));
        break;
      case 2:
        Navigator.push(context, MaterialPageRoute(builder: (_) => const LeaveApprovalScreen()));
        break;
      case 3:
        Navigator.push(context, MaterialPageRoute(builder: (_) => const PermissionApprovalScreen()));
        break;
      case 4:
        Navigator.push(context, MaterialPageRoute(builder: (_) => const LeaveTypeManagementScreen()));
        break;
      case 5:
        Navigator.push(context, MaterialPageRoute(builder: (_) => const PermissionTypeManagementScreen()));
        break;
      case 6:
        Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(
          backgroundColor: const Color(0xFF0D1117),
          appBar: AppBar(
            title: const Text('Holiday Calendar', style: TextStyle(color: Color(0xFFE6EDF3), fontWeight: FontWeight.bold, fontSize: 18)),
            backgroundColor: const Color(0xFF161B22),
            foregroundColor: const Color(0xFFE6EDF3),
            elevation: 0,
          ),
          body: const HolidayManagementScreen(),
        )));
        break;
      case 7:
        _showComingSoon(context);
        break;
      case 8:
        Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(
          backgroundColor: const Color(0xFF0D1117),
          appBar: AppBar(
            title: const Text('Student Attendance', style: TextStyle(color: Color(0xFFE6EDF3), fontWeight: FontWeight.bold, fontSize: 18)),
            backgroundColor: const Color(0xFF161B22),
            foregroundColor: const Color(0xFFE6EDF3),
            elevation: 0,
          ),
          body: const StudentAttendanceScreen(),
        )));
        break;
      case 9:
        Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(
          backgroundColor: const Color(0xFF0D1117),
          appBar: AppBar(
            title: const Text('Student Leave Requests', style: TextStyle(color: Color(0xFFE6EDF3), fontWeight: FontWeight.bold, fontSize: 18)),
            backgroundColor: const Color(0xFF161B22),
            foregroundColor: const Color(0xFFE6EDF3),
            elevation: 0,
          ),
          body: const StudentLeaveApprovalScreen(),
        )));
        break;
      case 10:
        Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(
          backgroundColor: const Color(0xFF0D1117),
          appBar: AppBar(
            title: const Text('Student Directory', style: TextStyle(color: Color(0xFFE6EDF3), fontWeight: FontWeight.bold, fontSize: 18)),
            backgroundColor: const Color(0xFF161B22),
            foregroundColor: const Color(0xFFE6EDF3),
            elevation: 0,
          ),
          body: const StudentDirectoryScreen(),
        )));
        break;
    }
  }

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.white),
            SizedBox(width: 12),
            Text('Feature coming soon!'),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}
