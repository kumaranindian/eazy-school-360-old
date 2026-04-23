import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../data/services/finance_dashboard_service.dart';

/// Finance Dashboard Home - shown as the landing page for finance users
class FinanceDashboardHome extends ConsumerWidget {
  final VoidCallback? onNavigateToFees;
  final VoidCallback? onNavigateToExpenses;
  final VoidCallback? onNavigateToBills;
  final VoidCallback? onNavigateToReports;
  final VoidCallback? onNavigateToStudents;

  const FinanceDashboardHome({
    super.key,
    this.onNavigateToFees,
    this.onNavigateToExpenses,
    this.onNavigateToBills,
    this.onNavigateToReports,
    this.onNavigateToStudents,
  });

  static const Color _bgDark = Color(0xFF0D1117);
  static const Color _cardDark = Color(0xFF161B22);
  static const Color _accentGreen = Color(0xFF4CAF50);
  static const Color _accentBlue = Color(0xFF3B82F6);
  static const Color _accentOrange = Color(0xFFF59E0B);
  static const Color _accentRed = Color(0xFFEF4444);
  static const Color _accentPurple = Color(0xFF8B5CF6);
  static const Color _textPrimary = Color(0xFFE6EDF3);
  static const Color _textSecondary = Color(0xFF8B949E);
  static const Color _borderColor = Color(0xFF30363D);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(currentSessionProvider);
    final schoolId = session?.schoolId;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 1024;
    final isTablet = screenWidth > 600 && screenWidth <= 1024;

    if (schoolId == null) {
      return const Center(
        child: Text('No school assigned', style: TextStyle(color: _textPrimary)),
      );
    }

    final statsAsync = ref.watch(financeDashboardStatsProvider(schoolId));
    final recentAsync = ref.watch(financeRecentActivityProvider(schoolId));

    return RefreshIndicator(
      color: _accentGreen,
      backgroundColor: _cardDark,
      onRefresh: () async {
        ref.invalidate(financeDashboardStatsProvider(schoolId));
        ref.invalidate(financeRecentActivityProvider(schoolId));
        await Future.delayed(const Duration(milliseconds: 400));
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(isDesktop ? 24 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWelcomeHeader(session, isDesktop),
            const SizedBox(height: 24),
            statsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator(color: _accentGreen)),
              ),
              error: (e, _) => _buildErrorCard(e.toString()),
              data: (stats) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatsGrid(stats, isDesktop, isTablet),
                  const SizedBox(height: 24),
                  _buildTodayMonthRow(stats, isDesktop),
                  const SizedBox(height: 24),
                  _buildCollectionProgress(stats, isDesktop),
                  const SizedBox(height: 24),
                  _buildQuickActions(isDesktop, isTablet),
                  const SizedBox(height: 24),
                  _buildTwoColumnSection(
                    stats: stats,
                    recentAsync: recentAsync,
                    isDesktop: isDesktop,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeHeader(dynamic session, bool isDesktop) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Good morning' : hour < 17 ? 'Good afternoon' : 'Good evening';
    final name = (session?.displayName as String?) ?? 'Finance User';
    final dateStr = DateFormat('EEEE, d MMMM yyyy').format(DateTime.now());

    return Container(
      padding: EdgeInsets.all(isDesktop ? 24 : 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_accentGreen.withValues(alpha: 0.18), _accentGreen.withValues(alpha: 0.04)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _accentGreen.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$greeting, $name!',
                  style: TextStyle(
                    fontSize: isDesktop ? 22 : 18,
                    fontWeight: FontWeight.bold,
                    color: _textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  dateStr,
                  style: const TextStyle(color: _textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Here is a snapshot of your school finances today.',
                  style: TextStyle(color: _textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
          if (isDesktop)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _accentGreen.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.account_balance_wallet_rounded, color: _accentGreen, size: 32),
            ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(FinanceDashboardStats stats, bool isDesktop, bool isTablet) {
    final crossAxisCount = isDesktop ? 4 : (isTablet ? 2 : 2);
    final aspectRatio = isDesktop ? 1.6 : 1.25;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Overview',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _textPrimary)),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: aspectRatio,
          children: [
            _StatCard(
              title: 'Total Students',
              value: stats.totalStudents.toString(),
              subtitle: '${stats.fullyPaidStudents} paid · ${stats.studentsWithOutstandingFees} outstanding',
              icon: Icons.people_rounded,
              color: _accentBlue,
            ),
            _StatCard(
              title: 'Fees Collected',
              value: _formatCurrency(stats.totalFeesCollected),
              subtitle: 'of ${_formatCurrency(stats.totalFeesExpected)} expected',
              icon: Icons.account_balance_wallet_rounded,
              color: _accentGreen,
            ),
            _StatCard(
              title: 'Outstanding Fees',
              value: _formatCurrency(stats.totalOutstandingFees),
              subtitle: '${stats.studentsWithOutstandingFees} students',
              icon: Icons.account_balance_rounded,
              color: _accentOrange,
            ),
            _StatCard(
              title: 'Total Expenses',
              value: _formatCurrency(stats.totalExpenses),
              subtitle: 'Net: ${_formatCurrency(stats.netIncome)}',
              icon: Icons.money_off_rounded,
              color: _accentRed,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTodayMonthRow(FinanceDashboardStats stats, bool isDesktop) {
    final items = [
      _MiniStat(
        label: "Today's Collection",
        value: _formatCurrency(stats.todayCollection),
        icon: Icons.today_rounded,
        color: _accentGreen,
      ),
      _MiniStat(
        label: "Today's Expenses",
        value: _formatCurrency(stats.todayExpenses),
        icon: Icons.receipt_rounded,
        color: _accentRed,
      ),
      _MiniStat(
        label: 'This Month Collection',
        value: _formatCurrency(stats.monthCollection),
        icon: Icons.calendar_month_rounded,
        color: _accentBlue,
      ),
      _MiniStat(
        label: 'Pending Arrears',
        value: _formatCurrency(stats.totalArrears),
        icon: Icons.warning_amber_rounded,
        color: _accentPurple,
      ),
    ];

    if (isDesktop) {
      return Row(
        children: items
            .map((item) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: item,
                  ),
                ))
            .toList(),
      );
    }

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 2.2,
      children: items,
    );
  }

  Widget _buildCollectionProgress(FinanceDashboardStats stats, bool isDesktop) {
    final rate = stats.collectionRate;
    final pct = (rate / 100).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Fee Collection Progress',
                  style: TextStyle(color: _textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
              Text('${rate.toStringAsFixed(1)}%',
                  style: const TextStyle(color: _accentGreen, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 10,
              backgroundColor: _bgDark,
              valueColor: const AlwaysStoppedAnimation<Color>(_accentGreen),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Collected: ${_formatCurrency(stats.totalFeesCollected)}',
                style: const TextStyle(color: _textSecondary, fontSize: 12),
              ),
              Text(
                'Expected: ${_formatCurrency(stats.totalFeesExpected)}',
                style: const TextStyle(color: _textSecondary, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(bool isDesktop, bool isTablet) {
    final crossAxisCount = isDesktop ? 5 : (isTablet ? 3 : 2);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Quick Actions',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _textPrimary)),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: isDesktop ? 1.6 : 1.8,
          children: [
            _QuickAction(
              label: 'Fee Management',
              icon: Icons.account_balance_wallet_rounded,
              color: _accentGreen,
              onTap: onNavigateToFees,
            ),
            _QuickAction(
              label: 'Collect Payment',
              icon: Icons.payment_rounded,
              color: _accentBlue,
              onTap: onNavigateToBills,
            ),
            _QuickAction(
              label: 'Record Expense',
              icon: Icons.money_off_rounded,
              color: _accentRed,
              onTap: onNavigateToExpenses,
            ),
            _QuickAction(
              label: 'Reports',
              icon: Icons.insights_rounded,
              color: _accentPurple,
              onTap: onNavigateToReports,
            ),
            _QuickAction(
              label: 'Students',
              icon: Icons.people_rounded,
              color: _accentOrange,
              onTap: onNavigateToStudents,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTwoColumnSection({
    required FinanceDashboardStats stats,
    required AsyncValue<List<RecentActivity>> recentAsync,
    required bool isDesktop,
  }) {
    final recent = _buildRecentActivity(recentAsync);
    final classWise = _buildClassWiseCollection(stats);

    if (isDesktop) {
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: 3, child: recent),
            const SizedBox(width: 16),
            Expanded(flex: 2, child: classWise),
          ],
        ),
      );
    }

    return Column(
      children: [
        recent,
        const SizedBox(height: 16),
        classWise,
      ],
    );
  }

  Widget _buildRecentActivity(AsyncValue<List<RecentActivity>> recentAsync) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Recent Activity',
              style: TextStyle(color: _textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 12),
          recentAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator(color: _accentGreen)),
            ),
            error: (e, _) => Text('Failed to load activity: $e',
                style: const TextStyle(color: _textSecondary, fontSize: 12)),
            data: (list) {
              if (list.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text('No recent activity',
                        style: TextStyle(color: _textSecondary, fontSize: 13)),
                  ),
                );
              }
              return Column(
                children: list.map((a) => _buildActivityRow(a)).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActivityRow(RecentActivity a) {
    final isPayment = a.type == 'payment';
    final color = isPayment ? _accentGreen : _accentRed;
    final icon = isPayment ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded;
    final sign = isPayment ? '+' : '-';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.title,
                    style: const TextStyle(
                        color: _textPrimary, fontWeight: FontWeight.w600, fontSize: 13),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(a.subtitle,
                    style: const TextStyle(color: _textSecondary, fontSize: 11),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$sign${_formatCurrency(a.amount)}',
                  style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13)),
              Text(DateFormat('dd MMM').format(a.date),
                  style: const TextStyle(color: _textSecondary, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildClassWiseCollection(FinanceDashboardStats stats) {
    // Union of class names across collected + expected so classes with only
    // one of the two still render.
    final allClasses = <String>{
      ...stats.classWiseCollection.keys,
      ...stats.classWiseExpected.keys,
    }.toList()
      ..sort((a, b) {
        final expA = stats.classWiseExpected[a] ?? 0;
        final expB = stats.classWiseExpected[b] ?? 0;
        if (expA != expB) return expB.compareTo(expA);
        final colA = stats.classWiseCollection[a] ?? 0;
        final colB = stats.classWiseCollection[b] ?? 0;
        return colB.compareTo(colA);
      });
    final top = allClasses.take(8).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Class-wise Collection',
              style: TextStyle(
                  color: _textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 4),
          const Text('Collected vs Expected per class',
              style: TextStyle(color: _textSecondary, fontSize: 11)),
          const SizedBox(height: 12),
          if (top.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text('No data available',
                    style: TextStyle(color: _textSecondary, fontSize: 13)),
              ),
            )
          else
            ...top.map((className) {
              final collected = stats.classWiseCollection[className] ?? 0.0;
              final expected = stats.classWiseExpected[className] ?? 0.0;
              final ratio = expected > 0
                  ? (collected / expected).clamp(0.0, 1.0)
                  : (collected > 0 ? 1.0 : 0.0);
              final pctText = expected > 0
                  ? '${(collected / expected * 100).clamp(0, 999).toStringAsFixed(0)}%'
                  : '—';
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Class $className',
                            style: const TextStyle(
                                color: _textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w500)),
                        Text(pctText,
                            style: const TextStyle(
                                color: _accentBlue,
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 6,
                        backgroundColor: _bgDark,
                        valueColor:
                            const AlwaysStoppedAnimation<Color>(_accentGreen),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Collected: ${_formatCurrency(collected)}',
                            style: const TextStyle(
                                color: _textSecondary, fontSize: 10)),
                        Text('Expected: ${_formatCurrency(expected)}',
                            style: const TextStyle(
                                color: _textSecondary, fontSize: 10)),
                      ],
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildErrorCard(String error) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _accentRed.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _accentRed.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: _accentRed),
          const SizedBox(width: 12),
          Expanded(
            child: Text('Failed to load stats: $error',
                style: const TextStyle(color: _textPrimary, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  String _formatCurrency(double value) {
    if (value >= 10000000) {
      return '₹${(value / 10000000).toStringAsFixed(2)}Cr';
    } else if (value >= 100000) {
      return '₹${(value / 100000).toStringAsFixed(2)}L';
    } else if (value >= 1000) {
      return '₹${(value / 1000).toStringAsFixed(1)}K';
    }
    return '₹${value.toStringAsFixed(0)}';
  }
}

// ───────────────────────── Helper widgets ─────────────────────────

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FinanceDashboardHome._cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FinanceDashboardHome._borderColor),
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
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold, color: FinanceDashboardHome._textPrimary),
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(title,
                  style: const TextStyle(fontSize: 12, color: FinanceDashboardHome._textSecondary),
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text(subtitle,
                  style: const TextStyle(fontSize: 10, color: FinanceDashboardHome._textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MiniStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FinanceDashboardHome._cardDark,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: FinanceDashboardHome._borderColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(color: FinanceDashboardHome._textSecondary, fontSize: 11),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(
                        color: FinanceDashboardHome._textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 15),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _QuickAction({
    required this.label,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: FinanceDashboardHome._cardDark,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: FinanceDashboardHome._borderColor),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 10),
              Text(label,
                  style: const TextStyle(
                      color: FinanceDashboardHome._textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}
