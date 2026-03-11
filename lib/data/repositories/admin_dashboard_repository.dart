import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Dashboard statistics model with caching support
class DashboardStats {
  final int totalStaff;
  final int activeStaff;
  final int pendingLeaveRequests;
  final int pendingPermissionRequests;
  final int approvedLeavesToday;
  final int totalLeaveTypes;
  final int totalPermissionTypes;
  final Map<String, int> leavesByStatus;
  final Map<String, int> permissionsByStatus;
  final List<RecentActivity> recentActivities;
  final DateTime lastUpdated;
  final String? cacheKey;

  const DashboardStats({
    required this.totalStaff,
    required this.activeStaff,
    required this.pendingLeaveRequests,
    required this.pendingPermissionRequests,
    required this.approvedLeavesToday,
    required this.totalLeaveTypes,
    required this.totalPermissionTypes,
    required this.leavesByStatus,
    required this.permissionsByStatus,
    required this.recentActivities,
    required this.lastUpdated,
    this.cacheKey,
  });

  factory DashboardStats.empty() {
    return DashboardStats(
      totalStaff: 0,
      activeStaff: 0,
      pendingLeaveRequests: 0,
      pendingPermissionRequests: 0,
      approvedLeavesToday: 0,
      totalLeaveTypes: 0,
      totalPermissionTypes: 0,
      leavesByStatus: {},
      permissionsByStatus: {},
      recentActivities: [],
      lastUpdated: DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'totalStaff': totalStaff,
      'activeStaff': activeStaff,
      'pendingLeaveRequests': pendingLeaveRequests,
      'pendingPermissionRequests': pendingPermissionRequests,
      'approvedLeavesToday': approvedLeavesToday,
      'totalLeaveTypes': totalLeaveTypes,
      'totalPermissionTypes': totalPermissionTypes,
      'leavesByStatus': leavesByStatus,
      'permissionsByStatus': permissionsByStatus,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }
}

/// Recent activity model for dashboard feed
class RecentActivity {
  final String id;
  final String type; // 'leave_request', 'permission_request', 'staff_added', etc.
  final String title;
  final String description;
  final String? staffId;
  final String? staffName;
  final DateTime timestamp;
  final String status;
  final Map<String, dynamic>? metadata;

  const RecentActivity({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    this.staffId,
    this.staffName,
    required this.timestamp,
    required this.status,
    this.metadata,
  });

  factory RecentActivity.fromFirestore(DocumentSnapshot doc, String type) {
    final data = doc.data() as Map<String, dynamic>;
    return RecentActivity(
      id: doc.id,
      type: type,
      title: _getTitleForType(type, data),
      description: _getDescriptionForType(type, data),
      staffId: data['staffId'] as String? ?? data['applicantId'] as String?,
      staffName: data['staffName'] as String? ?? data['applicantName'] as String?,
      timestamp: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: data['status'] as String? ?? 'unknown',
      metadata: data,
    );
  }

  static String _getTitleForType(String type, Map<String, dynamic> data) {
    switch (type) {
      case 'leave_request':
        return 'Leave Request';
      case 'permission_request':
        return 'Permission Request';
      case 'staff_added':
        return 'New Staff Added';
      case 'leave_approved':
        return 'Leave Approved';
      case 'leave_rejected':
        return 'Leave Rejected';
      default:
        return 'Activity';
    }
  }

  static String _getDescriptionForType(String type, Map<String, dynamic> data) {
    final staffName = data['staffName'] ?? data['applicantName'] ?? 'Staff';
    switch (type) {
      case 'leave_request':
        return '$staffName requested leave';
      case 'permission_request':
        return '$staffName requested permission';
      case 'staff_added':
        return '$staffName was added to the school';
      case 'leave_approved':
        return 'Leave request approved for $staffName';
      case 'leave_rejected':
        return 'Leave request rejected for $staffName';
      default:
        return 'Activity by $staffName';
    }
  }
}

/// Monthly analytics for reporting
class MonthlyAnalytics {
  final String month;
  final String year;
  final int totalLeaveRequests;
  final int approvedLeaves;
  final int rejectedLeaves;
  final int cancelledLeaves;
  final int totalLeaveDays;
  final int totalPermissionRequests;
  final int approvedPermissions;
  final int totalPermissionMinutes;
  final Map<String, int> leavesByType;
  final Map<String, int> staffLeaveUsage;

  const MonthlyAnalytics({
    required this.month,
    required this.year,
    required this.totalLeaveRequests,
    required this.approvedLeaves,
    required this.rejectedLeaves,
    required this.cancelledLeaves,
    required this.totalLeaveDays,
    required this.totalPermissionRequests,
    required this.approvedPermissions,
    required this.totalPermissionMinutes,
    required this.leavesByType,
    required this.staffLeaveUsage,
  });

  double get approvalRate => 
      totalLeaveRequests > 0 ? (approvedLeaves / totalLeaveRequests) * 100 : 0;

  double get averageLeaveDaysPerRequest =>
      approvedLeaves > 0 ? totalLeaveDays / approvedLeaves : 0;
}

/// Admin Dashboard Repository with performance optimizations
class AdminDashboardRepository {
  final FirebaseFirestore _firestore;
  
  // In-memory cache for dashboard stats
  final Map<String, DashboardStats> _statsCache = {};
  final Duration _cacheDuration = const Duration(minutes: 5);

  AdminDashboardRepository(this._firestore);

  /// Get dashboard statistics with caching
  Future<DashboardStats> getDashboardStats(String schoolId, {bool forceRefresh = false}) async {
    final cacheKey = 'dashboard_$schoolId';
    
    // Check cache validity
    if (!forceRefresh && _statsCache.containsKey(cacheKey)) {
      final cached = _statsCache[cacheKey]!;
      if (DateTime.now().difference(cached.lastUpdated) < _cacheDuration) {
        print('📊 [DASHBOARD_REPO] Returning cached stats for school: $schoolId');
        return cached;
      }
    }

    print('📊 [DASHBOARD_REPO] Fetching fresh stats for school: $schoolId');

    try {
      // Execute parallel queries for performance
      final results = await Future.wait([
        _getStaffCounts(schoolId),
        _getPendingLeaveCount(schoolId),
        _getPendingPermissionCount(schoolId),
        _getApprovedLeavesToday(schoolId),
        _getLeaveTypeCount(schoolId),
        _getPermissionTypeCount(schoolId),
        _getLeavesByStatus(schoolId),
        _getPermissionsByStatus(schoolId),
        _getRecentActivities(schoolId, limit: 10),
      ]);

      final staffCounts = results[0] as Map<String, int>;
      final pendingLeaves = results[1] as int;
      final pendingPermissions = results[2] as int;
      final approvedToday = results[3] as int;
      final leaveTypeCount = results[4] as int;
      final permissionTypeCount = results[5] as int;
      final leavesByStatus = results[6] as Map<String, int>;
      final permissionsByStatus = results[7] as Map<String, int>;
      final recentActivities = results[8] as List<RecentActivity>;

      final stats = DashboardStats(
        totalStaff: staffCounts['total'] ?? 0,
        activeStaff: staffCounts['active'] ?? 0,
        pendingLeaveRequests: pendingLeaves,
        pendingPermissionRequests: pendingPermissions,
        approvedLeavesToday: approvedToday,
        totalLeaveTypes: leaveTypeCount,
        totalPermissionTypes: permissionTypeCount,
        leavesByStatus: leavesByStatus,
        permissionsByStatus: permissionsByStatus,
        recentActivities: recentActivities,
        lastUpdated: DateTime.now(),
        cacheKey: cacheKey,
      );

      // Update cache
      _statsCache[cacheKey] = stats;
      
      print('✅ [DASHBOARD_REPO] Stats fetched successfully');
      return stats;
    } catch (e) {
      print('❌ [DASHBOARD_REPO] Error fetching dashboard stats: $e');
      // Return cached data if available, otherwise empty stats
      return _statsCache[cacheKey] ?? DashboardStats.empty();
    }
  }

  /// Get staff counts (total and active)
  Future<Map<String, int>> _getStaffCounts(String schoolId) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('staff')
          .get();

      int total = snapshot.docs.length;
      int active = snapshot.docs.where((doc) {
        final data = doc.data();
        return data['status'] == 'ACTIVE';
      }).length;

      return {'total': total, 'active': active};
    } catch (e) {
      print('❌ [DASHBOARD_REPO] Error getting staff counts: $e');
      return {'total': 0, 'active': 0};
    }
  }

  /// Get pending leave request count
  Future<int> _getPendingLeaveCount(String schoolId) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('leaves')
          .where('status', isEqualTo: 'PENDING')
          .count()
          .get();

      return snapshot.count ?? 0;
    } catch (e) {
      print('❌ [DASHBOARD_REPO] Error getting pending leave count: $e');
      return 0;
    }
  }

  /// Get pending permission request count
  Future<int> _getPendingPermissionCount(String schoolId) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('permissions')
          .where('status', isEqualTo: 'PENDING')
          .count()
          .get();

      return snapshot.count ?? 0;
    } catch (e) {
      print('❌ [DASHBOARD_REPO] Error getting pending permission count: $e');
      return 0;
    }
  }

  /// Get approved leaves today
  Future<int> _getApprovedLeavesToday(String schoolId) async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('leaves')
          .where('status', isEqualTo: 'APPROVED')
          .where('approvedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('approvedAt', isLessThan: Timestamp.fromDate(endOfDay))
          .count()
          .get();

      return snapshot.count ?? 0;
    } catch (e) {
      print('❌ [DASHBOARD_REPO] Error getting approved leaves today: $e');
      return 0;
    }
  }

  /// Get leave type count
  Future<int> _getLeaveTypeCount(String schoolId) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('leaveTypes')
          .where('isActive', isEqualTo: true)
          .count()
          .get();

      return snapshot.count ?? 0;
    } catch (e) {
      print('❌ [DASHBOARD_REPO] Error getting leave type count: $e');
      return 0;
    }
  }

  /// Get permission type count
  Future<int> _getPermissionTypeCount(String schoolId) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('permissionTypes')
          .where('isActive', isEqualTo: true)
          .count()
          .get();

      return snapshot.count ?? 0;
    } catch (e) {
      print('❌ [DASHBOARD_REPO] Error getting permission type count: $e');
      return 0;
    }
  }

  /// Get leaves grouped by status
  Future<Map<String, int>> _getLeavesByStatus(String schoolId) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('leaves')
          .get();

      final statusCounts = <String, int>{};
      for (final doc in snapshot.docs) {
        final status = doc.data()['status'] as String? ?? 'UNKNOWN';
        statusCounts[status] = (statusCounts[status] ?? 0) + 1;
      }

      return statusCounts;
    } catch (e) {
      print('❌ [DASHBOARD_REPO] Error getting leaves by status: $e');
      return {};
    }
  }

  /// Get permissions grouped by status
  Future<Map<String, int>> _getPermissionsByStatus(String schoolId) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('permissions')
          .get();

      final statusCounts = <String, int>{};
      for (final doc in snapshot.docs) {
        final status = doc.data()['status'] as String? ?? 'UNKNOWN';
        statusCounts[status] = (statusCounts[status] ?? 0) + 1;
      }

      return statusCounts;
    } catch (e) {
      print('❌ [DASHBOARD_REPO] Error getting permissions by status: $e');
      return {};
    }
  }

  /// Get recent activities for dashboard feed
  Future<List<RecentActivity>> _getRecentActivities(String schoolId, {int limit = 10}) async {
    try {
      final activities = <RecentActivity>[];

      // Get recent leave requests
      final leavesSnapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('leaves')
          .orderBy('createdAt', descending: true)
          .limit(limit ~/ 2)
          .get();

      for (final doc in leavesSnapshot.docs) {
        activities.add(RecentActivity.fromFirestore(doc, 'leave_request'));
      }

      // Get recent permission requests
      final permissionsSnapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('permissions')
          .orderBy('createdAt', descending: true)
          .limit(limit ~/ 2)
          .get();

      for (final doc in permissionsSnapshot.docs) {
        activities.add(RecentActivity.fromFirestore(doc, 'permission_request'));
      }

      // Sort by timestamp and limit
      activities.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return activities.take(limit).toList();
    } catch (e) {
      print('❌ [DASHBOARD_REPO] Error getting recent activities: $e');
      return [];
    }
  }

  /// Get monthly analytics for reporting
  Future<MonthlyAnalytics> getMonthlyAnalytics(String schoolId, int month, int year) async {
    try {
      final startDate = DateTime(year, month, 1);
      final endDate = DateTime(year, month + 1, 1);

      // Get leave requests for the month
      final leavesSnapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('leaves')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('createdAt', isLessThan: Timestamp.fromDate(endDate))
          .get();

      int totalLeaveRequests = leavesSnapshot.docs.length;
      int approvedLeaves = 0;
      int rejectedLeaves = 0;
      int cancelledLeaves = 0;
      int totalLeaveDays = 0;
      final leavesByType = <String, int>{};
      final staffLeaveUsage = <String, int>{};

      for (final doc in leavesSnapshot.docs) {
        final data = doc.data();
        final status = data['status'] as String? ?? '';
        final days = data['totalDays'] as int? ?? 0;
        final leaveTypeId = data['leaveTypeId'] as String? ?? 'unknown';
        final staffId = data['staffId'] as String? ?? 'unknown';

        switch (status) {
          case 'APPROVED':
            approvedLeaves++;
            totalLeaveDays += days;
            break;
          case 'REJECTED':
            rejectedLeaves++;
            break;
          case 'CANCELLED':
            cancelledLeaves++;
            break;
        }

        leavesByType[leaveTypeId] = (leavesByType[leaveTypeId] ?? 0) + 1;
        if (status == 'APPROVED') {
          staffLeaveUsage[staffId] = (staffLeaveUsage[staffId] ?? 0) + days;
        }
      }

      // Get permission requests for the month
      final permissionsSnapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('permissions')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('createdAt', isLessThan: Timestamp.fromDate(endDate))
          .get();

      int totalPermissionRequests = permissionsSnapshot.docs.length;
      int approvedPermissions = 0;
      int totalPermissionMinutes = 0;

      for (final doc in permissionsSnapshot.docs) {
        final data = doc.data();
        final status = data['status'] as String? ?? '';
        final minutes = data['durationMinutes'] as int? ?? 0;

        if (status == 'APPROVED') {
          approvedPermissions++;
          totalPermissionMinutes += minutes;
        }
      }

      return MonthlyAnalytics(
        month: month.toString().padLeft(2, '0'),
        year: year.toString(),
        totalLeaveRequests: totalLeaveRequests,
        approvedLeaves: approvedLeaves,
        rejectedLeaves: rejectedLeaves,
        cancelledLeaves: cancelledLeaves,
        totalLeaveDays: totalLeaveDays,
        totalPermissionRequests: totalPermissionRequests,
        approvedPermissions: approvedPermissions,
        totalPermissionMinutes: totalPermissionMinutes,
        leavesByType: leavesByType,
        staffLeaveUsage: staffLeaveUsage,
      );
    } catch (e) {
      print('❌ [DASHBOARD_REPO] Error getting monthly analytics: $e');
      rethrow;
    }
  }

  /// Get staff leave summary for admin view
  Future<List<Map<String, dynamic>>> getStaffLeaveSummary(String schoolId) async {
    try {
      final staffSnapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('staff')
          .where('status', isEqualTo: 'ACTIVE')
          .get();

      final summaries = <Map<String, dynamic>>[];

      for (final staffDoc in staffSnapshot.docs) {
        final staffData = staffDoc.data();
        final staffId = staffDoc.id;

        // Get leave balances for this staff
        final balancesSnapshot = await _firestore
            .collection('schools')
            .doc(schoolId)
            .collection('leaveBalances')
            .where('staffId', isEqualTo: staffId)
            .get();

        int totalAllowed = 0;
        int totalUsed = 0;
        int totalPending = 0;
        int totalAvailable = 0;

        for (final balanceDoc in balancesSnapshot.docs) {
          final balanceData = balanceDoc.data();
          totalAllowed += (balanceData['totalAllowed'] as int?) ?? 0;
          totalUsed += (balanceData['used'] as int?) ?? 0;
          totalPending += (balanceData['pending'] as int?) ?? 0;
          totalAvailable += (balanceData['available'] as int?) ?? 0;
        }

        summaries.add({
          'staffId': staffId,
          'staffName': staffData['name'] ?? 'Unknown',
          'email': staffData['email'] ?? '',
          'department': staffData['department'] ?? '',
          'totalAllowed': totalAllowed,
          'totalUsed': totalUsed,
          'totalPending': totalPending,
          'totalAvailable': totalAvailable,
          'utilizationRate': totalAllowed > 0 
              ? ((totalUsed / totalAllowed) * 100).round() 
              : 0,
        });
      }

      // Sort by utilization rate descending
      summaries.sort((a, b) => 
          (b['utilizationRate'] as int).compareTo(a['utilizationRate'] as int));

      return summaries;
    } catch (e) {
      print('❌ [DASHBOARD_REPO] Error getting staff leave summary: $e');
      return [];
    }
  }

  /// Clear cache for a specific school
  void clearCache(String schoolId) {
    _statsCache.remove('dashboard_$schoolId');
    print('🗑️ [DASHBOARD_REPO] Cache cleared for school: $schoolId');
  }

  /// Clear all cached data
  void clearAllCache() {
    _statsCache.clear();
    print('🗑️ [DASHBOARD_REPO] All cache cleared');
  }
}

/// Providers
final adminDashboardRepositoryProvider = Provider<AdminDashboardRepository>((ref) {
  return AdminDashboardRepository(FirebaseFirestore.instance);
});

/// Dashboard stats provider with auto-refresh
final dashboardStatsProvider = FutureProvider.family<DashboardStats, String>((ref, schoolId) async {
  final repository = ref.watch(adminDashboardRepositoryProvider);
  return repository.getDashboardStats(schoolId);
});

/// Monthly analytics provider
final monthlyAnalyticsProvider = FutureProvider.family<MonthlyAnalytics, Map<String, dynamic>>((ref, params) async {
  final repository = ref.watch(adminDashboardRepositoryProvider);
  return repository.getMonthlyAnalytics(
    params['schoolId'] as String,
    params['month'] as int,
    params['year'] as int,
  );
});

/// Staff leave summary provider
final staffLeaveSummaryProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, schoolId) async {
  final repository = ref.watch(adminDashboardRepositoryProvider);
  return repository.getStaffLeaveSummary(schoolId);
});
