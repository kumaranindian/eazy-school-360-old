import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eazy_school_360/domain/entities/permission_request.dart';

class PermissionRequestRepository {
  final FirebaseFirestore _firestore;

  PermissionRequestRepository(this._firestore);

  String? _extractPermissionTypeId(Map<String, dynamic> data) {
    final direct = data['permissionTypeId'] as String?;
    if (direct != null && direct.isNotEmpty) return direct;

    final metadata = data['metadata'];
    if (metadata is Map<String, dynamic>) {
      final permissionType = metadata['permissionType'];
      if (permissionType is Map<String, dynamic>) {
        final nestedId = permissionType['id'] as String?;
        if (nestedId != null && nestedId.isNotEmpty) return nestedId;
      }
    }
    return null;
  }

  /// Get all permission requests for a school (Admin view)
  Stream<List<PermissionRequest>> getSchoolPermissionRequests(String schoolId) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('permissions')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PermissionRequest.fromFirestore(doc))
            .toList());
  }

  Future<Map<String, int>> getMonthlyPermissionUsageByType(
    String schoolId,
    String staffId,
    String month,
  ) async {
    final parts = month.split('-');
    final year = int.parse(parts[0]);
    final m = int.parse(parts[1]);
    final start = DateTime(year, m, 1);
    final end = DateTime(year, m + 1, 1);

    final snapshot = await _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('permissions')
        .where('staffId', isEqualTo: staffId)
        .where('requestDate', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('requestDate', isLessThan: Timestamp.fromDate(end))
        .get();

    final counts = <String, int>{};
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final status = (data['status'] as String?)?.toUpperCase();
      if (status != 'PENDING' && status != 'APPROVED') continue;

      final permissionTypeId = _extractPermissionTypeId(data);
      if (permissionTypeId == null) continue;
      counts[permissionTypeId] = (counts[permissionTypeId] ?? 0) + 1;
    }
    return counts;
  }

  Future<int> getMonthlyPermissionTypeUsageCount(
    String schoolId,
    String staffId,
    String permissionTypeId,
    String month,
  ) async {
    final parts = month.split('-');
    final year = int.parse(parts[0]);
    final m = int.parse(parts[1]);
    final start = DateTime(year, m, 1);
    final end = DateTime(year, m + 1, 1);

    final snapshot = await _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('permissions')
        .where('staffId', isEqualTo: staffId)
        .where('requestDate', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('requestDate', isLessThan: Timestamp.fromDate(end))
        .get();

    // Count only active requests (pending/approved). Avoid counting cancelled/rejected.
    var count = 0;
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final status = (data['status'] as String?)?.toUpperCase();
      if (status != 'PENDING' && status != 'APPROVED') continue;

      final extractedTypeId = _extractPermissionTypeId(data);
      if (extractedTypeId == permissionTypeId) {
        count++;
      }
    }
    return count;
  }

  Future<int> getMonthlyPermissionTypeUsageCountFlexible(
    String schoolId, {
    required String staffId,
    required String applicantId,
    required String permissionTypeId,
    required String month,
  }) async {
    final countByStaffId = await getMonthlyPermissionTypeUsageCount(
      schoolId,
      staffId,
      permissionTypeId,
      month,
    );
    if (countByStaffId > 0) return countByStaffId;

    final parts = month.split('-');
    final year = int.parse(parts[0]);
    final m = int.parse(parts[1]);
    final start = DateTime(year, m, 1);
    final end = DateTime(year, m + 1, 1);

    final snapshot = await _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('permissions')
        .where('applicantId', isEqualTo: applicantId)
        .where('requestDate', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('requestDate', isLessThan: Timestamp.fromDate(end))
        .get();

    var count = 0;
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final status = (data['status'] as String?)?.toUpperCase();
      if (status != 'PENDING' && status != 'APPROVED') continue;

      final extractedTypeId = _extractPermissionTypeId(data);
      if (extractedTypeId == permissionTypeId) {
        count++;
      }
    }
    return count;
  }

  /// Get pending permission requests for a school (Admin approval queue)
  Stream<List<PermissionRequest>> getPendingPermissionRequests(String schoolId) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('permissions')
        .where('status', isEqualTo: 'PENDING')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PermissionRequest.fromFirestore(doc))
            .toList());
  }

  /// Get permission requests for a specific staff member
  Stream<List<PermissionRequest>> getStaffPermissionRequests(String schoolId, String applicantId) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('permissions')
        .where('applicantId', isEqualTo: applicantId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PermissionRequest.fromFirestore(doc))
            .toList());
  }

  /// Get permission configuration for a school (read-only, safe for staff)
  Future<PermissionConfig?> getPermissionConfig(String schoolId) async {
    try {
      final doc = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('permissionConfig')
          .doc('default')
          .get();

      if (doc.exists) {
        return PermissionConfig.fromFirestore(doc);
      }

      return null;
    } catch (e) {
      throw Exception('Failed to get permission configuration: $e');
    }
  }

  /// Create or reset default permission config for a school (Admin only)
  Future<PermissionConfig> createDefaultPermissionConfig(String schoolId, String adminUserId) async {
    final now = DateTime.now();
    final defaultConfig = {
      'schoolId': schoolId,
      'monthlyLimit': 4,
      'maxDurationMinutes': 120,
      'requiresApproval': true,
      'isActive': true,
      'createdAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
      'createdBy': adminUserId,
    };

    await _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('permissionConfig')
        .doc('default')
        .set(defaultConfig);

    final newDoc = await _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('permissionConfig')
        .doc('default')
        .get();

    return PermissionConfig.fromFirestore(newDoc);
  }

  /// Get monthly permission usage for a staff member
  Future<MonthlyPermissionUsage?> getMonthlyPermissionUsage(
    String schoolId,
    String staffId,
    String month,
  ) async {
    try {
      final usageId = '${staffId}_$month';
      final doc = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('monthlyPermissionUsage')
          .doc(usageId)
          .get();

      if (doc.exists) {
        return MonthlyPermissionUsage.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get monthly permission usage: $e');
    }
  }

  /// Create permission request (Staff)
  Future<String> createPermissionRequest(
    String schoolId,
    String applicantId,
    String staffId,
    CreatePermissionRequest request,
  ) async {
    try {
      // Validate user permissions
      await _validateStaffAccess(applicantId, schoolId);

      // Get permission configuration
      final config = await getPermissionConfig(schoolId);
      if (config == null) {
        throw Exception('Permission configuration not found for this school');
      }

      if (!config.isActive) {
        throw Exception('Permission requests are currently disabled for this school');
      }

      // Validate permission timing
      final validationError = PermissionCalculator.validatePermissionTiming(
        request.requestDate,
        request.startTime,
        request.endTime,
        config,
      );

      if (validationError != null) {
        throw Exception(validationError);
      }

      // Determine monthly limit for selected permission type
      final permissionTypeDoc = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('permissionTypes')
          .doc(request.permissionTypeId)
          .get();

      if (!permissionTypeDoc.exists) {
        throw Exception('Selected permission type not found');
      }
      final permissionTypeData = permissionTypeDoc.data() as Map<String, dynamic>;
      final typeMonthlyLimit = (permissionTypeData['defaultLimit'] as num?)?.toInt() ?? 0;
      if (typeMonthlyLimit <= 0) {
        throw Exception('Invalid monthly limit for selected permission type');
      }

      // Check monthly limits (per selected type)
      final currentMonth = PermissionCalculator.getMonthForDate(request.requestDate);
      final currentMonthRequests = await getMonthlyPermissionTypeUsageCount(
        schoolId,
        staffId,
        request.permissionTypeId,
        currentMonth,
      );

      if (currentMonthRequests >= typeMonthlyLimit) {
        throw Exception(
          'Monthly permission limit exceeded for this permission type. You have used $currentMonthRequests out of $typeMonthlyLimit this month.',
        );
      }

      // Create permission request
      final permissionRequest = PermissionRequest(
        id: '',
        schoolId: schoolId,
        applicantId: applicantId,
        staffId: staffId,
        permissionTypeId: request.permissionTypeId,
        requestDate: request.requestDate,
        startTime: request.startTime,
        endTime: request.endTime,
        durationMinutes: request.durationMinutes,
        reason: request.reason,
        status: PermissionRequestStatus.PENDING,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        remarks: request.remarks,
        metadata: {
          'permissionConfig': {
            'monthlyLimit': config.monthlyLimit,
            'maxDurationMinutes': config.maxDurationMinutes,
            'requiresApproval': config.requiresApproval,
          },
          'permissionType': {
            'id': request.permissionTypeId,
            'monthlyLimit': typeMonthlyLimit,
          },
          'currentMonthUsage': currentMonthRequests,
          'calculatedDuration': request.durationMinutes,
        },
      );

      final docRef = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('permissions')
          .add(permissionRequest.toFirestore());

      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create permission request: $e');
    }
  }

  /// Approve/Reject permission request (Admin only)
  Future<void> processPermissionRequest(
    String schoolId,
    String permissionId,
    String adminUserId,
    PermissionApprovalRequest request,
  ) async {
    try {
      // Validate admin permissions
      await _validateAdminAccess(adminUserId, schoolId);

      final permissionRef = _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('permissions')
          .doc(permissionId);

      final permissionDoc = await permissionRef.get();
      if (!permissionDoc.exists) {
        throw Exception('Permission request not found');
      }

      final currentRequest = PermissionRequest.fromFirestore(permissionDoc);
      if (!currentRequest.canBeApproved) {
        throw Exception('Permission request cannot be processed in current status');
      }

      // Validate status transition
      if (request.status != PermissionRequestStatus.APPROVED && 
          request.status != PermissionRequestStatus.REJECTED) {
        throw Exception('Invalid status for permission approval action');
      }

      if (request.status == PermissionRequestStatus.REJECTED && 
          (request.rejectionReason == null || request.rejectionReason!.trim().isEmpty)) {
        throw Exception('Rejection reason is required when rejecting permission request');
      }

      // Update permission request
      final updateData = <String, dynamic>{
        'status': request.status.name,
        'updatedAt': FieldValue.serverTimestamp(),
        'approvedBy': adminUserId,
        'approvedAt': FieldValue.serverTimestamp(),
      };

      if (request.rejectionReason != null) {
        updateData['rejectionReason'] = request.rejectionReason;
      }

      if (request.remarks != null) {
        updateData['remarks'] = request.remarks;
      }

      await permissionRef.update(updateData);

      // Monthly usage update will be handled by Cloud Function trigger
    } catch (e) {
      throw Exception('Failed to process permission request: $e');
    }
  }

  /// Cancel permission request (Staff only - own requests)
  Future<void> cancelPermissionRequest(String schoolId, String permissionId, String applicantId) async {
    try {
      // Validate user permissions
      await _validateStaffAccess(applicantId, schoolId);

      final permissionRef = _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('permissions')
          .doc(permissionId);

      final permissionDoc = await permissionRef.get();
      if (!permissionDoc.exists) {
        throw Exception('Permission request not found');
      }

      final currentRequest = PermissionRequest.fromFirestore(permissionDoc);
      
      // Check ownership
      if (currentRequest.applicantId != applicantId) {
        throw Exception('You can only cancel your own permission requests');
      }

      if (!currentRequest.canBeCancelled) {
        throw Exception('Permission request cannot be cancelled in current status');
      }

      // Update permission request
      await permissionRef.update({
        'status': PermissionRequestStatus.CANCELLED.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Monthly usage update will be handled by Cloud Function trigger
    } catch (e) {
      throw Exception('Failed to cancel permission request: $e');
    }
  }

  /// Create or update permission configuration (Admin only)
  Future<void> updatePermissionConfig(
    String schoolId,
    String adminUserId,
    PermissionConfig config,
  ) async {
    try {
      // Validate admin permissions
      await _validateAdminAccess(adminUserId, schoolId);

      // Validate configuration
      if (config.monthlyLimit <= 0 || config.monthlyLimit > 100) {
        throw Exception('Monthly limit must be between 1 and 100');
      }

      if (config.maxDurationMinutes <= 0 || config.maxDurationMinutes > 480) { // Max 8 hours
        throw Exception('Maximum duration must be between 1 minute and 8 hours');
      }

      final configData = config.toFirestore();
      configData['updatedAt'] = FieldValue.serverTimestamp();

      await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('permissionConfig')
          .doc('default')
          .set(configData, SetOptions(merge: true));
    } catch (e) {
      throw Exception('Failed to update permission configuration: $e');
    }
  }

  /// Initialize default permission configuration for a school
  Future<void> initializeDefaultPermissionConfig(String schoolId, String adminUserId) async {
    try {
      await _validateAdminAccess(adminUserId, schoolId);

      final defaultConfig = PermissionConfig(
        id: 'default',
        schoolId: schoolId,
        monthlyLimit: 10, // 10 permissions per month
        maxDurationMinutes: 120, // 2 hours maximum
        requiresApproval: true,
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: adminUserId,
        customRules: {
          'allowWeekends': false,
          'allowHolidays': false,
          'minAdvanceNoticeHours': 2,
        },
      );

      await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('permissionConfig')
          .doc('default')
          .set(defaultConfig.toFirestore());
    } catch (e) {
      throw Exception('Failed to initialize permission configuration: $e');
    }
  }

  /// Get permission usage analytics for admin dashboard
  Future<Map<String, dynamic>> getPermissionUsageAnalytics(String schoolId, String month) async {
    try {
      final usageQuery = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('monthlyPermissionUsage')
          .where('month', isEqualTo: month)
          .get();

      int totalStaff = 0;
      int totalRequests = 0;
      int totalApproved = 0;
      int totalMinutesUsed = 0;
      
      final staffUsage = <Map<String, dynamic>>[];

      for (final doc in usageQuery.docs) {
        final usage = MonthlyPermissionUsage.fromFirestore(doc);
        totalStaff++;
        totalRequests += usage.totalRequests;
        totalApproved += usage.approvedRequests;
        totalMinutesUsed += usage.totalMinutesUsed;

        staffUsage.add({
          'staffId': usage.staffId,
          'totalRequests': usage.totalRequests,
          'approvedRequests': usage.approvedRequests,
          'totalMinutesUsed': usage.totalMinutesUsed,
          'totalTimeUsed': usage.totalTimeUsedDisplayText,
        });
      }

      return {
        'month': month,
        'totalStaff': totalStaff,
        'totalRequests': totalRequests,
        'totalApproved': totalApproved,
        'totalRejected': totalRequests - totalApproved,
        'approvalRate': totalRequests > 0 ? (totalApproved / totalRequests * 100).round() : 0,
        'totalMinutesUsed': totalMinutesUsed,
        'totalHoursUsed': (totalMinutesUsed / 60).toStringAsFixed(1),
        'averageRequestsPerStaff': totalStaff > 0 ? (totalRequests / totalStaff).toStringAsFixed(1) : '0',
        'staffUsage': staffUsage,
      };
    } catch (e) {
      throw Exception('Failed to get permission usage analytics: $e');
    }
  }

  /// Validate staff access to school
  Future<void> _validateStaffAccess(String userId, String schoolId) async {
    final userDoc = await _firestore.collection('users').doc(userId).get();
    if (!userDoc.exists) {
      throw Exception('User not found');
    }

    final userData = userDoc.data()!;
    final role = (userData['role'] as String? ?? '').toUpperCase();
    // Accept all staff/teacher/admin role variants
    const validRoles = {'STAFF', 'TEACHER', 'ADMIN', 'TENANT_ADMIN', 'FINANCE'};
    if (!validRoles.contains(role)) {
      throw Exception('Insufficient permissions');
    }

    if (userData['schoolId'] != schoolId) {
      throw Exception('Access denied to this school');
    }

    final status = (userData['status'] as String? ?? 'ACTIVE').toUpperCase();
    if (status != 'ACTIVE') {
      throw Exception('User account is not active');
    }
  }

  /// Validate admin access to school
  Future<void> _validateAdminAccess(String adminUserId, String schoolId) async {
    final adminDoc = await _firestore.collection('users').doc(adminUserId).get();
    if (!adminDoc.exists) {
      throw Exception('Admin user not found');
    }

    final adminData = adminDoc.data()!;
    final role = adminData['role'] as String?;
    
    // Accept multiple admin role formats
    final isAdminRole = role == 'ADMIN' || role == 'SUPER_ADMIN' || role == 'tenant_admin' || role == 'admin';
    if (!isAdminRole) {
      throw Exception('Insufficient permissions');
    }

    // For non-super admins, verify school access
    final isSuperAdmin = role == 'SUPER_ADMIN';
    if (!isSuperAdmin && adminData['schoolId'] != schoolId) {
      throw Exception('Access denied to this school');
    }

    // Check both status (enum string) and isActive (boolean) for backward compatibility
    final userStatus = adminData['status'];
    final isActive = adminData['isActive'] == true;
    final isStatusActive = userStatus == 'ACTIVE' || userStatus == 'Active';
    if (!isStatusActive && !isActive) {
      throw Exception('Admin account is not active');
    }
  }
}

/// Providers
final permissionRequestRepositoryProvider = Provider<PermissionRequestRepository>((ref) {
  final firestore = FirebaseFirestore.instance;
  return PermissionRequestRepository(firestore);
});

/// Stream provider for school permission requests (Admin view)
final schoolPermissionRequestsProvider = StreamProvider.family<List<PermissionRequest>, String>((ref, schoolId) {
  final repository = ref.watch(permissionRequestRepositoryProvider);
  return repository.getSchoolPermissionRequests(schoolId);
});

/// Stream provider for pending permission requests (Admin approval queue)
final pendingPermissionRequestsProvider = StreamProvider.family<List<PermissionRequest>, String>((ref, schoolId) {
  final repository = ref.watch(permissionRequestRepositoryProvider);
  return repository.getPendingPermissionRequests(schoolId);
});
final monthlyPermissionUsageByTypeProvider = FutureProvider.family<Map<String, int>, ({String schoolId, String staffId, String month})>((ref, params) {
  final repository = ref.watch(permissionRequestRepositoryProvider);
  return repository.getMonthlyPermissionUsageByType(params.schoolId, params.staffId, params.month);
});


/// Stream provider for staff permission requests
final staffPermissionRequestsProvider = StreamProvider.family<List<PermissionRequest>, ({String schoolId, String applicantId})>((ref, params) {
  final repository = ref.watch(permissionRequestRepositoryProvider);
  return repository.getStaffPermissionRequests(params.schoolId, params.applicantId);
});

/// Provider for permission configuration
final permissionConfigProvider = FutureProvider.family<PermissionConfig?, String>((ref, schoolId) {
  final repository = ref.watch(permissionRequestRepositoryProvider);
  return repository.getPermissionConfig(schoolId);
});

/// Provider for monthly permission usage count with fallback to applicantId for legacy documents
final monthlyPermissionTypeUsageCountFlexibleProvider = FutureProvider.family<int, ({
  String schoolId,
  String staffId,
  String applicantId,
  String permissionTypeId,
  String month,
})>((ref, params) {
  final repository = ref.watch(permissionRequestRepositoryProvider);
  return repository.getMonthlyPermissionTypeUsageCountFlexible(
    params.schoolId,
    staffId: params.staffId,
    applicantId: params.applicantId,
    permissionTypeId: params.permissionTypeId,
    month: params.month,
  );
});

/// Provider for monthly permission usage
final monthlyPermissionUsageProvider = FutureProvider.family<MonthlyPermissionUsage?, ({String schoolId, String staffId, String month})>((ref, params) {
  final repository = ref.watch(permissionRequestRepositoryProvider);
  return repository.getMonthlyPermissionUsage(
    params.schoolId,
    params.staffId,
    params.month,
  );
});

final monthlyPermissionTypeUsageCountProvider = FutureProvider.family<int, ({String schoolId, String staffId, String permissionTypeId, String month})>((ref, params) {
  final repository = ref.watch(permissionRequestRepositoryProvider);
  return repository.getMonthlyPermissionTypeUsageCount(
    params.schoolId,
    params.staffId,
    params.permissionTypeId,
    params.month,
  );
});

/// Provider for permission usage analytics
final permissionUsageAnalyticsProvider = FutureProvider.family<Map<String, dynamic>, ({String schoolId, String month})>((ref, params) {
  final repository = ref.watch(permissionRequestRepositoryProvider);
  return repository.getPermissionUsageAnalytics(params.schoolId, params.month);
});
