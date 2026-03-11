import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:eazy_school_360/core/providers/auth_provider.dart';

class EnhancedAdminDashboard extends ConsumerWidget {
  const EnhancedAdminDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(currentSessionProvider);
    final colorScheme = Theme.of(context).colorScheme;

    if (session == null || !session.isAdmin || session.schoolId == null) {
      return const Center(child: Text('Access Denied'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome Header
          Text(
            'Admin Dashboard',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'School: ${session.schoolId}',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),

          // Statistics Cards Row
          Row(
            children: [
              Expanded(
                child: _PendingApprovalsCard(schoolId: session.schoolId!),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _StaffOnLeaveCard(schoolId: session.schoolId!),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Monthly Statistics
          _MonthlyStatsCard(schoolId: session.schoolId!),
          const SizedBox(height: 24),

          // Quick Actions
          Text(
            'Quick Actions',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _QuickActionsGrid(),
          const SizedBox(height: 24),

          // Recent Activity
          Text(
            'Recent Activity',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _RecentActivityList(schoolId: session.schoolId!),
        ],
      ),
    );
  }
}

class _PendingApprovalsCard extends ConsumerWidget {
  final String schoolId;

  const _PendingApprovalsCard({required this.schoolId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.pending_actions,
                  color: Colors.orange[600],
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Pending Approvals',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FutureBuilder<Map<String, int>>(
              future: _getPendingCounts(schoolId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final data = snapshot.data ?? {'leaves': 0, 'permissions': 0, 'cancellations': 0};
                final total = data.values.fold(0, (sum, count) => sum + count);

                return Column(
                  children: [
                    Text(
                      '$total',
                      style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Total Pending',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildBreakdown('Leaves', data['leaves'] ?? 0, Icons.event_note),
                    _buildBreakdown('Permissions', data['permissions'] ?? 0, Icons.access_time),
                    _buildBreakdown('Cancellations', data['cancellations'] ?? 0, Icons.cancel),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBreakdown(String label, int count, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          const Spacer(),
          Text(
            '$count',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Future<Map<String, int>> _getPendingCounts(String schoolId) async {
    final firestore = FirebaseFirestore.instance;
    
    try {
      // Get pending leaves count
      final leavesSnapshot = await firestore
          .collection('schools')
          .doc(schoolId)
          .collection('leaves')
          .where('status', isEqualTo: 'PENDING')
          .count()
          .get();

      // Get pending permissions count
      final permissionsSnapshot = await firestore
          .collection('schools')
          .doc(schoolId)
          .collection('permissions')
          .where('status', isEqualTo: 'PENDING')
          .count()
          .get();

      // Get pending cancellations count
      final cancellationsSnapshot = await firestore
          .collection('schools')
          .doc(schoolId)
          .collection('leaveCancellations')
          .where('status', isEqualTo: 'PENDING')
          .count()
          .get();

      return {
        'leaves': leavesSnapshot.count ?? 0,
        'permissions': permissionsSnapshot.count ?? 0,
        'cancellations': cancellationsSnapshot.count ?? 0,
      };
    } catch (e) {
      print('❌ Error getting pending counts: $e');
      return {'leaves': 0, 'permissions': 0, 'cancellations': 0};
    }
  }
}

class _StaffOnLeaveCard extends ConsumerWidget {
  final String schoolId;

  const _StaffOnLeaveCard({required this.schoolId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.people_outline,
                  color: Colors.blue[600],
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Staff on Leave',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FutureBuilder<Map<String, dynamic>>(
              future: _getStaffOnLeaveData(schoolId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final data = snapshot.data ?? {'today': 0, 'total': 0, 'percentage': 0.0};

                return Column(
                  children: [
                    Text(
                      '${data['today']}',
                      style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Staff on Leave Today',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: (data['percentage'] as double) / 100,
                      backgroundColor: Colors.grey[300],
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[600]!),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${data['percentage'].toStringAsFixed(1)}% of ${data['total']} total staff',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<Map<String, dynamic>> _getStaffOnLeaveData(String schoolId) async {
    final firestore = FirebaseFirestore.instance;
    
    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final todayEnd = todayStart.add(const Duration(days: 1));

      // Get total staff count
      final staffSnapshot = await firestore
          .collection('schools')
          .doc(schoolId)
          .collection('staff')
          .where('isActive', isEqualTo: true)
          .count()
          .get();
      final totalStaff = staffSnapshot.count ?? 0;

      // Get staff on leave today (approved leaves that cover today)
      final leavesSnapshot = await firestore
          .collection('schools')
          .doc(schoolId)
          .collection('leaves')
          .where('status', isEqualTo: 'APPROVED')
          .where('startDate', isLessThanOrEqualTo: Timestamp.fromDate(todayEnd))
          .get();

      int staffOnLeaveToday = 0;
      for (final doc in leavesSnapshot.docs) {
        final endDate = (doc.data()['endDate'] as Timestamp?)?.toDate();
        if (endDate != null && endDate.isAfter(todayStart)) {
          staffOnLeaveToday++;
        }
      }

      final percentage = totalStaff > 0 ? (staffOnLeaveToday / totalStaff) * 100 : 0.0;

      return {
        'today': staffOnLeaveToday,
        'total': totalStaff,
        'percentage': percentage,
      };
    } catch (e) {
      print('❌ Error getting staff on leave data: $e');
      return {'today': 0, 'total': 0, 'percentage': 0.0};
    }
  }
}

class _MonthlyStatsCard extends ConsumerWidget {
  final String schoolId;

  const _MonthlyStatsCard({required this.schoolId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Monthly Statistics',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            FutureBuilder<Map<String, dynamic>>(
              future: _getMonthlyStats(schoolId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final data = snapshot.data ?? {};
                
                return Row(
                  children: [
                    Expanded(
                      child: _buildStatColumn(
                        'Leave Requests',
                        (data['leaveRequests'] as num?)?.toInt() ?? 0,
                        Icons.event_note,
                        Colors.green,
                      ),
                    ),
                    Expanded(
                      child: _buildStatColumn(
                        'Permission Requests',
                        (data['permissionRequests'] as num?)?.toInt() ?? 0,
                        Icons.access_time,
                        Colors.orange,
                      ),
                    ),
                    Expanded(
                      child: _buildStatColumn(
                        'Approved',
                        (data['approved'] as num?)?.toInt() ?? 0,
                        Icons.check_circle,
                        Colors.blue,
                      ),
                    ),
                    Expanded(
                      child: _buildStatColumn(
                        'Rejected',
                        (data['rejected'] as num?)?.toInt() ?? 0,
                        Icons.cancel,
                        Colors.red,
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, int value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 8),
        Text(
          '$value',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Future<Map<String, dynamic>> _getMonthlyStats(String schoolId) async {
    final firestore = FirebaseFirestore.instance;
    
    try {
      final now = DateTime.now();
      final monthStart = DateTime(now.year, now.month, 1);
      final monthStartTimestamp = Timestamp.fromDate(monthStart);

      // Get leave requests this month
      final leavesSnapshot = await firestore
          .collection('schools')
          .doc(schoolId)
          .collection('leaves')
          .where('createdAt', isGreaterThanOrEqualTo: monthStartTimestamp)
          .get();

      // Get permission requests this month
      final permissionsSnapshot = await firestore
          .collection('schools')
          .doc(schoolId)
          .collection('permissions')
          .where('createdAt', isGreaterThanOrEqualTo: monthStartTimestamp)
          .get();

      int approved = 0;
      int rejected = 0;

      for (final doc in leavesSnapshot.docs) {
        final status = doc.data()['status'] as String?;
        if (status == 'APPROVED') approved++;
        if (status == 'REJECTED') rejected++;
      }

      for (final doc in permissionsSnapshot.docs) {
        final status = doc.data()['status'] as String?;
        if (status == 'APPROVED') approved++;
        if (status == 'REJECTED') rejected++;
      }

      return {
        'leaveRequests': leavesSnapshot.docs.length,
        'permissionRequests': permissionsSnapshot.docs.length,
        'approved': approved,
        'rejected': rejected,
      };
    } catch (e) {
      print('❌ Error getting monthly stats: $e');
      return {'leaveRequests': 0, 'permissionRequests': 0, 'approved': 0, 'rejected': 0};
    }
  }
}

class _QuickActionsGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 2.5,
      children: [
        _buildActionCard(
          'Pending Leaves',
          Icons.event_note,
          Colors.orange,
          () => _navigateToLeaveApprovals(context),
        ),
        _buildActionCard(
          'Pending Permissions',
          Icons.access_time,
          Colors.purple,
          () => _navigateToPermissionApprovals(context),
        ),
        _buildActionCard(
          'Staff Management',
          Icons.people,
          Colors.green,
          () => _navigateToStaffManagement(context),
        ),
        _buildActionCard(
          'Reports',
          Icons.analytics,
          Colors.blue,
          () => _navigateToReports(context),
        ),
      ],
    );
  }

  Widget _buildActionCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToLeaveApprovals(BuildContext context) {
    // Navigate to leave approvals screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Navigate to Leave Approvals')),
    );
  }

  void _navigateToPermissionApprovals(BuildContext context) {
    // Navigate to permission approvals screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Navigate to Permission Approvals')),
    );
  }

  void _navigateToStaffManagement(BuildContext context) {
    // Navigate to staff management screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Navigate to Staff Management')),
    );
  }

  void _navigateToReports(BuildContext context) {
    // Navigate to reports screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Navigate to Reports')),
    );
  }
}

class _RecentActivityList extends ConsumerWidget {
  final String schoolId;

  const _RecentActivityList({required this.schoolId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Activity',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextButton(
                  onPressed: () => _viewAllActivity(context),
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _getRecentActivity(schoolId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final activities = snapshot.data ?? [];
                
                if (activities.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text('No recent activity'),
                    ),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: activities.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final activity = activities[index];
                    return _buildActivityItem(activity);
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityItem(Map<String, dynamic> activity) {
    final actionType = activity['actionType'] as String;
    final timestamp = activity['timestamp'] as String;
    final description = activity['description'] as String;
    
    IconData icon;
    Color color;
    
    switch (actionType) {
      case 'LEAVE_APPROVED':
        icon = Icons.check_circle;
        color = Colors.green;
        break;
      case 'LEAVE_REJECTED':
        icon = Icons.cancel;
        color = Colors.red;
        break;
      case 'PERMISSION_APPROVED':
        icon = Icons.access_time;
        color = Colors.blue;
        break;
      default:
        icon = Icons.info;
        color = Colors.grey;
    }

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color, size: 20),
      title: Text(
        description,
        style: const TextStyle(fontSize: 14),
      ),
      subtitle: Text(
        timestamp,
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey[600],
        ),
      ),
      dense: true,
    );
  }

  Future<List<Map<String, dynamic>>> _getRecentActivity(String schoolId) async {
    final firestore = FirebaseFirestore.instance;
    
    try {
      // Get recent audit log entries
      final auditSnapshot = await firestore
          .collection('schools')
          .doc(schoolId)
          .collection('auditLog')
          .orderBy('timestamp', descending: true)
          .limit(10)
          .get();

      if (auditSnapshot.docs.isEmpty) {
        return [];
      }

      return auditSnapshot.docs.map((doc) {
        final data = doc.data();
        final timestamp = data['timestamp'] as Timestamp?;
        final timeAgo = timestamp != null ? _formatTimeAgo(timestamp.toDate()) : 'Unknown';
        
        return {
          'actionType': data['action'] ?? 'UNKNOWN',
          'description': _formatActivityDescription(data),
          'timestamp': timeAgo,
        };
      }).toList();
    } catch (e) {
      print('❌ Error getting recent activity: $e');
      return [];
    }
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  String _formatActivityDescription(Map<String, dynamic> data) {
    final action = data['action'] as String? ?? '';
    
    switch (action) {
      case 'LEAVE_APPROVED':
        return 'Approved leave request';
      case 'LEAVE_REJECTED':
        return 'Rejected leave request';
      case 'PERMISSION_APPROVED':
        return 'Approved permission request';
      case 'PERMISSION_REJECTED':
        return 'Rejected permission request';
      case 'LEAVE_CANCELLED':
        return 'Cancelled leave request';
      case 'PERMISSION_CANCELLED':
        return 'Cancelled permission request';
      default:
        return action.replaceAll('_', ' ').toLowerCase();
    }
  }

  void _viewAllActivity(BuildContext context) {
    // Navigate to full activity log
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Navigate to Activity Log')),
    );
  }
}
