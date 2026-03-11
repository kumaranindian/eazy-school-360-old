import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/auth_provider.dart';
import '../../auth/screens/enhanced_login_screen.dart';
import '../../finance/screens/student_management_screen.dart';
import '../../finance/screens/expense_entry_screen.dart';
import '../../finance/screens/financial_reports_screen.dart';
import '../../finance/screens/bill_management_screen.dart';
import '../../finance/screens/student_fee_management_screen.dart';

class FinanceDashboardScreen extends ConsumerStatefulWidget {
  const FinanceDashboardScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<FinanceDashboardScreen> createState() => _FinanceDashboardScreenState();
}

// Menu index mapping:
// 0 = Student Directory
// 1 = Fee Management
// 2 = Expense Entry
// 3 = Bill Management
// 4 = Financial Reports

class _FinanceDashboardScreenState extends ConsumerState<FinanceDashboardScreen> {
  int _selectedIndex = 0;

  // Dark theme colors (match other dashboards)
  static const Color _bgDark = Color(0xFF0D1117);
  static const Color _cardDark = Color(0xFF161B22);
  static const Color _accentBlue = Color(0xFF4CAF50);
  static const Color _textPrimary = Color(0xFFE6EDF3);
  static const Color _textSecondary = Color(0xFF8B949E);
  static const Color _borderColor = Color(0xFF30363D);

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
                        Text('Finance Portal', style: TextStyle(fontSize: 11, color: _textSecondary)),
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
                  _buildDrawerSectionHeader('Students'),
                  _buildDrawerNavItem(context, Icons.people_rounded, 'Student Directory', 0),
                  _buildDrawerSectionHeader('Finance'),
                  _buildDrawerNavItem(context, Icons.account_balance_wallet_rounded, 'Fee Management', 1),
                  _buildDrawerNavItem(context, Icons.money_off_rounded, 'Expense Entry', 2),
                  _buildDrawerNavItem(context, Icons.receipt_long_rounded, 'Bill Management', 3),
                  _buildDrawerSectionHeader('Reports'),
                  _buildDrawerNavItem(context, Icons.insights_rounded, 'Financial Reports', 4),
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
                    child: Text((session.displayName as String? ?? 'F')[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(session.displayName as String? ?? 'Finance User', style: const TextStyle(color: _textPrimary, fontWeight: FontWeight.w600, fontSize: 13), overflow: TextOverflow.ellipsis),
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
                      Text('Finance Portal', style: TextStyle(fontSize: 11, color: _textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(height: 1, color: _borderColor),
          
          // Navigation Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _buildSideNavSectionHeader('Students'),
                _buildSideNavItem(Icons.people_rounded, 'Student Directory', 0),
                _buildSideNavSectionHeader('Finance'),
                _buildSideNavItem(Icons.account_balance_wallet_rounded, 'Fee Management', 1),
                _buildSideNavItem(Icons.money_off_rounded, 'Expense Entry', 2),
                _buildSideNavItem(Icons.receipt_long_rounded, 'Bill Management', 3),
                _buildSideNavSectionHeader('Reports'),
                _buildSideNavItem(Icons.insights_rounded, 'Financial Reports', 4),
              ],
            ),
          ),
          
          // User Info Footer
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
                  child: Text((session.displayName as String? ?? 'F')[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(session.displayName as String? ?? 'Finance User', style: const TextStyle(color: _textPrimary, fontWeight: FontWeight.w600, fontSize: 13), overflow: TextOverflow.ellipsis),
                      Text(session.email as String? ?? '', style: const TextStyle(color: _textSecondary, fontSize: 10), overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.logout_rounded, color: _textSecondary, size: 18),
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
      child: Text(title.toUpperCase(), style: const TextStyle(color: _textSecondary, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1.2)),
    );
  }

  Widget _buildSideNavSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(title.toUpperCase(), style: const TextStyle(color: _textSecondary, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1.2)),
    );
  }

  Widget _buildSideNavItem(IconData icon, String label, int index) {
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

  String _getPageTitle() {
    switch (_selectedIndex) {
      case 0: return 'Student Directory';
      case 1: return 'Fee Management';
      case 2: return 'Expense Entry';
      case 3: return 'Bill Management';
      case 4: return 'Financial Reports';
      default: return 'Student Directory';
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
          ],
          Text(_getPageTitle(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _textPrimary)),
          
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
          
          if (isDesktop) ...[
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: _cardDark, borderRadius: BorderRadius.circular(8), border: Border.all(color: _borderColor)),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: _accentBlue,
                    radius: 14,
                    child: Text((session.displayName as String? ?? 'F')[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                  const SizedBox(width: 8),
                  Text(session.displayName as String? ?? 'Finance', style: const TextStyle(color: _textPrimary, fontWeight: FontWeight.w500, fontSize: 13)),
                  const SizedBox(width: 4),
                  const Icon(Icons.keyboard_arrow_down, color: _textSecondary, size: 18),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, dynamic session, bool isDesktop, bool isTablet) {
    switch (_selectedIndex) {
      case 0: return const StudentManagementScreen();
      case 1: return const StudentFeeManagementScreen();
      case 2: return const ExpenseEntryScreen();
      case 3: return const BillManagementScreen();
      case 4: return const FinancialReportsScreen();
      default: return const StudentManagementScreen();
    }
  }

  Widget _buildUnusedDashboardContent(BuildContext context, dynamic session, bool isDesktop, bool isTablet) {
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
                colors: [_accentBlue.withOpacity(0.15), _accentBlue.withOpacity(0.05)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _accentBlue.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Welcome back, ${session.displayName ?? "Finance User"}!', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _textPrimary)),
                      const SizedBox(height: 4),
                      const Text('Manage fees, expenses, and financial reports', style: TextStyle(color: _textSecondary)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: _accentBlue.withOpacity(0.2), shape: BoxShape.circle),
                  child: const Icon(Icons.account_balance_wallet_rounded, color: _accentBlue, size: 28),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Quick Stats
          Text('Overview', style: TextStyle(fontSize: isDesktop ? 18 : 16, fontWeight: FontWeight.bold, color: _textPrimary)),
          const SizedBox(height: 12),
          
          GridView.count(
            crossAxisCount: isDesktop ? 4 : (isTablet ? 2 : 2),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: isDesktop ? 1.8 : 1.5,
            children: [
              _buildStatCard('Total Students', '0', Icons.people_rounded, const Color(0xFF3B82F6)),
              _buildStatCard('Fees Collected', '₹0', Icons.account_balance_wallet_rounded, const Color(0xFF10B981)),
              _buildStatCard('Pending Fees', '₹0', Icons.pending_rounded, const Color(0xFFF59E0B)),
              _buildStatCard('Total Expenses', '₹0', Icons.money_off_rounded, const Color(0xFFEF4444)),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Quick Actions
          Text('Quick Actions', style: TextStyle(fontSize: isDesktop ? 18 : 16, fontWeight: FontWeight.bold, color: _textPrimary)),
          const SizedBox(height: 12),
          
          GridView.count(
            crossAxisCount: isDesktop ? 4 : (isTablet ? 2 : 2),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: isDesktop ? 2.5 : 2.0,
            children: [
              _buildQuickActionCard('Add Student', Icons.person_add_rounded, () => setState(() => _selectedIndex = 1)),
              _buildQuickActionCard('Fee Management', Icons.account_balance_wallet_rounded, () => setState(() => _selectedIndex = 2)),
              _buildQuickActionCard('Collect Fee', Icons.payment_rounded, () => setState(() => _selectedIndex = 3)),
              _buildQuickActionCard('Add Expense', Icons.add_card_rounded, () => setState(() => _selectedIndex = 4)),
              _buildQuickActionCard('Bill Management', Icons.receipt_long_rounded, () => setState(() => _selectedIndex = 5)),
              _buildQuickActionCard('Financial Reports', Icons.insights_rounded, () => setState(() => _selectedIndex = 6)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor),
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
                decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: color, size: 20),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _textPrimary)),
              Text(title, style: const TextStyle(fontSize: 12, color: _textSecondary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard(String title, IconData icon, VoidCallback onTap) {
    return Material(
      color: _cardDark,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _borderColor),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: _accentBlue.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: _accentBlue, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, color: _textPrimary, fontSize: 13)),
              ),
              const Icon(Icons.arrow_forward_ios, color: _textSecondary, size: 14),
            ],
          ),
        ),
      ),
    );
  }

}
