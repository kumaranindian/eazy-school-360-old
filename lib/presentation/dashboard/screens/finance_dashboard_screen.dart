import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/auth_provider.dart';
import '../../auth/screens/enhanced_login_screen.dart';
import '../../finance/screens/student_management_screen.dart';
import '../../finance/screens/expense_entry_screen.dart';
import '../../finance/screens/financial_reports_screen.dart';
import '../../finance/screens/bill_management_screen.dart';
import '../../finance/screens/student_fee_management_screen.dart';
import '../../finance/screens/fee_structure_list_screen.dart';
import '../../finance/screens/student_fee_ledger_list_screen.dart';
import 'finance_dashboard_home.dart';
import '../../widgets/theme_toggle_button.dart';

class FinanceDashboardScreen extends ConsumerStatefulWidget {
  const FinanceDashboardScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<FinanceDashboardScreen> createState() =>
      _FinanceDashboardScreenState();
}

// Menu index mapping:
// 0 = Dashboard Home
// 1 = Student Directory
// 2 = Fee Management (legacy)
// 3 = Expense Entry
// 4 = Bill Management
// 5 = Financial Reports
// 6 = Fee Structures (term-wise)

class _FinanceDashboardScreenState
    extends ConsumerState<FinanceDashboardScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return _buildDashboard(context);
  }

  Widget _buildDashboard(BuildContext context) {
    final session = ref.watch(currentSessionProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 1024;
    final isTablet = screenWidth > 600 && screenWidth <= 1024;

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
                        Text('Finance Portal',
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
                  _buildDrawerSectionHeader('Home'),
                  _buildDrawerNavItem(
                      context, Icons.dashboard_rounded, 'Dashboard', 0),
                  _buildDrawerSectionHeader('Students'),
                  _buildDrawerNavItem(
                      context, Icons.people_rounded, 'Student Directory', 1),
                  _buildDrawerSectionHeader('Finance'),
                  _buildDrawerNavItem(
                      context,
                      Icons.account_balance_wallet_rounded,
                      'Fee Management',
                      2),
                  _buildDrawerNavItem(
                      context, Icons.money_off_rounded, 'Expense Entry', 3),
                  _buildDrawerNavItem(context, Icons.receipt_long_rounded,
                      'Bill Management', 4),
                  _buildDrawerSectionHeader('Term-wise Fees'),
                  _buildDrawerNavItem(context, Icons.receipt_long_outlined,
                      'Fee Structures', 6),
                  _buildDrawerNavItem(context, Icons.assignment_ind_outlined,
                      'Student Ledgers', 7),
                  _buildDrawerSectionHeader('Reports'),
                  _buildDrawerNavItem(
                      context, Icons.insights_rounded, 'Financial Reports', 5),
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
                        (session.displayName as String? ?? 'F')[0]
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
                        Text(session.displayName as String? ?? 'Finance User',
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
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset('assets/images/eazyschool.png',
                      width: 40, height: 40, fit: BoxFit.contain),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Eazy School',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface)),
                      Text('Finance Portal',
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

          // Navigation Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _buildSideNavSectionHeader('Home'),
                _buildSideNavItem(Icons.dashboard_rounded, 'Dashboard', 0),
                _buildSideNavSectionHeader('Students'),
                _buildSideNavItem(Icons.people_rounded, 'Student Directory', 1),
                _buildSideNavSectionHeader('Finance'),
                _buildSideNavItem(
                    Icons.account_balance_wallet_rounded, 'Fee Management', 2),
                _buildSideNavItem(Icons.money_off_rounded, 'Expense Entry', 3),
                _buildSideNavItem(
                    Icons.receipt_long_rounded, 'Bill Management', 4),
                _buildSideNavSectionHeader('Term-wise Fees'),
                _buildSideNavItem(
                    Icons.receipt_long_outlined, 'Fee Structures', 6),
                _buildSideNavItem(
                    Icons.assignment_ind_outlined, 'Student Ledgers', 7),
                _buildSideNavSectionHeader('Reports'),
                _buildSideNavItem(
                    Icons.insights_rounded, 'Financial Reports', 5),
              ],
            ),
          ),

          // User Info Footer
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
                      (session.displayName as String? ?? 'F')[0].toUpperCase(),
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
                      Text(session.displayName as String? ?? 'Finance User',
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
    );
  }

  Widget _buildDrawerSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(title.toUpperCase(),
          style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2)),
    );
  }

  Widget _buildSideNavSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(title.toUpperCase(),
          style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2)),
    );
  }

  Widget _buildSideNavItem(IconData icon, String label, int index) {
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

  String _getPageTitle() {
    switch (_selectedIndex) {
      case 0:
        return 'Dashboard';
      case 1:
        return 'Student Directory';
      case 2:
        return 'Fee Management';
      case 3:
        return 'Expense Entry';
      case 4:
        return 'Bill Management';
      case 5:
        return 'Financial Reports';
      case 6:
        return 'Fee Structures';
      case 7:
        return 'Student Ledgers';
      default:
        return 'Dashboard';
    }
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
            const SizedBox(width: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset('assets/images/eazyschool.png',
                  width: 36, height: 36, fit: BoxFit.contain),
            ),
            const SizedBox(width: 12),
          ],
          Text(_getPageTitle(),
              style: TextStyle(
                  fontSize: 18,
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

          if (isDesktop) ...[
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                        (session.displayName as String? ?? 'F')[0]
                            .toUpperCase(),
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
                  ),
                  const SizedBox(width: 8),
                  Text(session.displayName as String? ?? 'Finance',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w500,
                          fontSize: 13)),
                  const SizedBox(width: 4),
                  Icon(Icons.keyboard_arrow_down,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      size: 18),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildContent(
      BuildContext context, dynamic session, bool isDesktop, bool isTablet) {
    switch (_selectedIndex) {
      case 0:
        return FinanceDashboardHome(
          onNavigateToStudents: () => setState(() => _selectedIndex = 1),
          onNavigateToFees: () => setState(() => _selectedIndex = 2),
          onNavigateToExpenses: () => setState(() => _selectedIndex = 3),
          onNavigateToBills: () => setState(() => _selectedIndex = 4),
          onNavigateToReports: () => setState(() => _selectedIndex = 5),
        );
      case 1:
        return const StudentManagementScreen();
      case 2:
        return const StudentFeeManagementScreen();
      case 3:
        return const ExpenseEntryScreen();
      case 4:
        return const BillManagementScreen();
      case 5:
        return const FinancialReportsScreen();
      case 6:
        return const FeeStructureListScreen();
      case 7:
        return const StudentFeeLedgerListScreen();
      default:
        return FinanceDashboardHome(
          onNavigateToStudents: () => setState(() => _selectedIndex = 1),
          onNavigateToFees: () => setState(() => _selectedIndex = 2),
          onNavigateToExpenses: () => setState(() => _selectedIndex = 3),
          onNavigateToBills: () => setState(() => _selectedIndex = 4),
          onNavigateToReports: () => setState(() => _selectedIndex = 5),
        );
    }
  }

  // ignore: unused_element
  Widget _buildUnusedDashboardContent(
      BuildContext context, dynamic session, bool isDesktop, bool isTablet) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isDesktop ? 24 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF4CAF50).withOpacity(0.15),
                  const Color(0xFF4CAF50).withOpacity(0.05)
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: const Color(0xFF4CAF50).withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          'Welcome back, ${session.displayName ?? "Finance User"}!',
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface)),
                      const SizedBox(height: 4),
                      Text('Manage fees, expenses, and financial reports',
                          style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50).withOpacity(0.2),
                      shape: BoxShape.circle),
                  child: const Icon(Icons.account_balance_wallet_rounded,
                      color: Color(0xFF4CAF50), size: 28),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Quick Stats
          Text('Overview',
              style: TextStyle(
                  fontSize: isDesktop ? 18 : 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface)),
          const SizedBox(height: 12),

          GridView.count(
            crossAxisCount: isDesktop ? 4 : (isTablet ? 2 : 2),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: isDesktop ? 1.8 : 1.5,
            children: [
              _buildStatCard('Total Students', '0', Icons.people_rounded,
                  const Color(0xFF3B82F6)),
              _buildStatCard(
                  'Fees Collected',
                  '₹0',
                  Icons.account_balance_wallet_rounded,
                  const Color(0xFF10B981)),
              _buildStatCard('Outstanding Fees', '₹0',
                  Icons.account_balance_rounded, const Color(0xFFF59E0B)),
              _buildStatCard('Total Expenses', '₹0', Icons.money_off_rounded,
                  const Color(0xFFEF4444)),
            ],
          ),

          const SizedBox(height: 24),

          // Quick Actions
          Text('Quick Actions',
              style: TextStyle(
                  fontSize: isDesktop ? 18 : 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface)),
          const SizedBox(height: 12),

          GridView.count(
            crossAxisCount: isDesktop ? 4 : (isTablet ? 2 : 2),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: isDesktop ? 2.5 : 2.0,
            children: [
              _buildQuickActionCard('Add Student', Icons.person_add_rounded,
                  () => setState(() => _selectedIndex = 1)),
              _buildQuickActionCard(
                  'Fee Management',
                  Icons.account_balance_wallet_rounded,
                  () => setState(() => _selectedIndex = 2)),
              _buildQuickActionCard('Collect Fee', Icons.payment_rounded,
                  () => setState(() => _selectedIndex = 3)),
              _buildQuickActionCard('Add Expense', Icons.add_card_rounded,
                  () => setState(() => _selectedIndex = 4)),
              _buildQuickActionCard(
                  'Bill Management',
                  Icons.receipt_long_rounded,
                  () => setState(() => _selectedIndex = 5)),
              _buildQuickActionCard('Financial Reports', Icons.insights_rounded,
                  () => setState(() => _selectedIndex = 6)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: color, size: 20),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface)),
              Text(title,
                  style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard(
      String title, IconData icon, VoidCallback onTap) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).colorScheme.outline),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: const Color(0xFF4CAF50), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(title,
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 13)),
              ),
              Icon(Icons.arrow_forward_ios,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  size: 14),
            ],
          ),
        ),
      ),
    );
  }
}
