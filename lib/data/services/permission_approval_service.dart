import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Service to handle permission request approval workflows with atomic transactions
/// Replaces Cloud Functions - all logic runs client-side with Firestore rules for security
class PermissionApprovalService {
  final FirebaseFirestore _firestore;

  PermissionApprovalService(this._firestore);

  /// Approve a permission request with usage tracking
  Future<void> approvePermission({
    required String schoolId,
    required String permissionId,
    required String approvedBy,
    String? remarks,
  }) async {
    print('✅ [PERMISSION_APPROVAL] Approving permission: $permissionId');

    await _firestore.runTransaction((transaction) async {
      // 1. Get the permission document
      final permRef = _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('permissions')
          .doc(permissionId);

      final permDoc = await transaction.get(permRef);
      if (!permDoc.exists) {
        throw Exception('Permission request not found');
      }

      final permData = permDoc.data()!;
      final currentStatus = permData['status'] as String?;

      if (currentStatus != 'PENDING') {
        throw Exception('Cannot approve - permission is not in PENDING status (current: $currentStatus)');
      }

      final staffId = permData['staffId'] as String;
      final durationMinutes = permData['durationMinutes'] as int? ?? 0;
      final requestDate = (permData['requestDate'] as Timestamp?)?.toDate() ?? DateTime.now();

      // 2. Get/create monthly usage document
      final monthKey = '${requestDate.year}-${requestDate.month.toString().padLeft(2, '0')}';
      final usageId = '${staffId}_$monthKey';
      final usageRef = _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('monthlyPermissionUsage')
          .doc(usageId);

      final usageDoc = await transaction.get(usageRef);

      // 3. Update permission status
      transaction.update(permRef, {
        'status': 'APPROVED',
        'approvedBy': approvedBy,
        'approvedAt': FieldValue.serverTimestamp(),
        'remarks': remarks,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 4. Update monthly usage
      if (usageDoc.exists) {
        final usageData = usageDoc.data()!;
        transaction.update(usageRef, {
          'approvedRequests': (usageData['approvedRequests'] as int? ?? 0) + 1,
          'totalMinutesUsed': (usageData['totalMinutesUsed'] as int? ?? 0) + durationMinutes,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        transaction.set(usageRef, {
          'staffId': staffId,
          'month': monthKey,
          'totalRequests': 1,
          'approvedRequests': 1,
          'rejectedRequests': 0,
          'cancelledRequests': 0,
          'totalMinutesUsed': durationMinutes,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // 5. Audit log
      final auditRef = _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('auditLog')
          .doc();

      transaction.set(auditRef, {
        'action': 'PERMISSION_APPROVED',
        'performedBy': approvedBy,
        'timestamp': FieldValue.serverTimestamp(),
        'details': {
          'permissionId': permissionId,
          'staffId': staffId,
          'durationMinutes': durationMinutes,
          'remarks': remarks,
        },
      });
    });

    print('✅ [PERMISSION_APPROVAL] Permission approved: $permissionId');
  }

  /// Reject a permission request
  Future<void> rejectPermission({
    required String schoolId,
    required String permissionId,
    required String rejectedBy,
    required String reason,
  }) async {
    print('❌ [PERMISSION_APPROVAL] Rejecting permission: $permissionId');

    await _firestore.runTransaction((transaction) async {
      final permRef = _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('permissions')
          .doc(permissionId);

      final permDoc = await transaction.get(permRef);
      if (!permDoc.exists) {
        throw Exception('Permission request not found');
      }

      final permData = permDoc.data()!;
      final currentStatus = permData['status'] as String?;

      if (currentStatus != 'PENDING') {
        throw Exception('Cannot reject - permission is not in PENDING status');
      }

      final staffId = permData['staffId'] as String;
      final requestDate = (permData['requestDate'] as Timestamp?)?.toDate() ?? DateTime.now();

      // Get/create monthly usage
      final monthKey = '${requestDate.year}-${requestDate.month.toString().padLeft(2, '0')}';
      final usageId = '${staffId}_$monthKey';
      final usageRef = _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('monthlyPermissionUsage')
          .doc(usageId);

      final usageDoc = await transaction.get(usageRef);

      // Update permission status
      transaction.update(permRef, {
        'status': 'REJECTED',
        'rejectedBy': rejectedBy,
        'rejectedAt': FieldValue.serverTimestamp(),
        'rejectionReason': reason,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update monthly usage
      if (usageDoc.exists) {
        final usageData = usageDoc.data()!;
        transaction.update(usageRef, {
          'rejectedRequests': (usageData['rejectedRequests'] as int? ?? 0) + 1,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        transaction.set(usageRef, {
          'staffId': staffId,
          'month': monthKey,
          'totalRequests': 1,
          'approvedRequests': 0,
          'rejectedRequests': 1,
          'cancelledRequests': 0,
          'totalMinutesUsed': 0,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Audit log
      final auditRef = _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('auditLog')
          .doc();

      transaction.set(auditRef, {
        'action': 'PERMISSION_REJECTED',
        'performedBy': rejectedBy,
        'timestamp': FieldValue.serverTimestamp(),
        'details': {
          'permissionId': permissionId,
          'staffId': staffId,
          'reason': reason,
        },
      });
    });

    print('❌ [PERMISSION_APPROVAL] Permission rejected: $permissionId');
  }

  /// Cancel a permission request
  Future<void> cancelPermission({
    required String schoolId,
    required String permissionId,
    required String cancelledBy,
    String? reason,
  }) async {
    print('🚫 [PERMISSION_APPROVAL] Cancelling permission: $permissionId');

    await _firestore.runTransaction((transaction) async {
      final permRef = _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('permissions')
          .doc(permissionId);

      final permDoc = await transaction.get(permRef);
      if (!permDoc.exists) {
        throw Exception('Permission request not found');
      }

      final permData = permDoc.data()!;
      final currentStatus = permData['status'] as String?;

      if (currentStatus != 'PENDING' && currentStatus != 'APPROVED') {
        throw Exception('Cannot cancel - permission status is $currentStatus');
      }

      final staffId = permData['staffId'] as String;
      final durationMinutes = permData['durationMinutes'] as int? ?? 0;
      final requestDate = (permData['requestDate'] as Timestamp?)?.toDate() ?? DateTime.now();

      final monthKey = '${requestDate.year}-${requestDate.month.toString().padLeft(2, '0')}';
      final usageId = '${staffId}_$monthKey';
      final usageRef = _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('monthlyPermissionUsage')
          .doc(usageId);

      final usageDoc = await transaction.get(usageRef);

      // Update permission status
      transaction.update(permRef, {
        'status': 'CANCELLED',
        'cancelledBy': cancelledBy,
        'cancelledAt': FieldValue.serverTimestamp(),
        'cancellationReason': reason,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update monthly usage
      if (usageDoc.exists) {
        final usageData = usageDoc.data()!;
        final updates = <String, dynamic>{
          'cancelledRequests': (usageData['cancelledRequests'] as int? ?? 0) + 1,
          'updatedAt': FieldValue.serverTimestamp(),
        };

        // If was approved, reverse the usage
        if (currentStatus == 'APPROVED') {
          updates['approvedRequests'] = ((usageData['approvedRequests'] as int? ?? 0) - 1).clamp(0, double.infinity).toInt();
          updates['totalMinutesUsed'] = ((usageData['totalMinutesUsed'] as int? ?? 0) - durationMinutes).clamp(0, double.infinity).toInt();
        }

        transaction.update(usageRef, updates);
      }

      // Audit log
      final auditRef = _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('auditLog')
          .doc();

      transaction.set(auditRef, {
        'action': 'PERMISSION_CANCELLED',
        'performedBy': cancelledBy,
        'timestamp': FieldValue.serverTimestamp(),
        'details': {
          'permissionId': permissionId,
          'staffId': staffId,
          'previousStatus': currentStatus,
          'reason': reason,
        },
      });
    });

    print('🚫 [PERMISSION_APPROVAL] Permission cancelled: $permissionId');
  }

  /// Submit a new permission request
  Future<String> submitPermissionRequest({
    required String schoolId,
    required String staffId,
    required String applicantId,
    required String applicantName,
    required DateTime requestDate,
    required DateTime startTime,
    required DateTime endTime,
    required int durationMinutes,
    required String reason,
  }) async {
    print('📝 [PERMISSION_APPROVAL] Submitting permission request');

    // Check monthly limit before submitting
    final monthKey = '${requestDate.year}-${requestDate.month.toString().padLeft(2, '0')}';
    final usageId = '${staffId}_$monthKey';

    // Get permission config
    final configDoc = await _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('permissionConfig')
        .doc('default')
        .get();

    int monthlyLimit = 10; // Default
    if (configDoc.exists) {
      monthlyLimit = configDoc.data()?['monthlyLimit'] as int? ?? 10;
    }

    // Check current usage
    final usageDoc = await _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('monthlyPermissionUsage')
        .doc(usageId)
        .get();

    if (usageDoc.exists) {
      final currentRequests = usageDoc.data()?['totalRequests'] as int? ?? 0;
      if (currentRequests >= monthlyLimit) {
        throw Exception('Monthly permission limit reached ($monthlyLimit requests)');
      }
    }

    final permissionId = _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('permissions')
        .doc()
        .id;

    await _firestore.runTransaction((transaction) async {
      // Create permission request
      final permRef = _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('permissions')
          .doc(permissionId);

      transaction.set(permRef, {
        'id': permissionId,
        'schoolId': schoolId,
        'staffId': staffId,
        'applicantId': applicantId,
        'applicantName': applicantName,
        'requestDate': Timestamp.fromDate(requestDate),
        'startTime': Timestamp.fromDate(startTime),
        'endTime': Timestamp.fromDate(endTime),
        'durationMinutes': durationMinutes,
        'reason': reason,
        'status': 'PENDING',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update/create monthly usage tracking
      final usageRef = _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('monthlyPermissionUsage')
          .doc(usageId);

      final existingUsage = await transaction.get(usageRef);

      if (existingUsage.exists) {
        transaction.update(usageRef, {
          'totalRequests': FieldValue.increment(1),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        transaction.set(usageRef, {
          'staffId': staffId,
          'month': monthKey,
          'totalRequests': 1,
          'approvedRequests': 0,
          'rejectedRequests': 0,
          'cancelledRequests': 0,
          'totalMinutesUsed': 0,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });

    print('📝 [PERMISSION_APPROVAL] Permission submitted: $permissionId');
    return permissionId;
  }

  /// Batch approve multiple permissions
  Future<Map<String, dynamic>> batchApprovePermissions({
    required String schoolId,
    required List<String> permissionIds,
    required String approvedBy,
    String? remarks,
  }) async {
    print('📋 [PERMISSION_APPROVAL] Batch approving ${permissionIds.length} permissions');

    final results = <String, dynamic>{
      'success': <String>[],
      'failed': <Map<String, String>>[],
    };

    for (final permissionId in permissionIds) {
      try {
        await approvePermission(
          schoolId: schoolId,
          permissionId: permissionId,
          approvedBy: approvedBy,
          remarks: remarks,
        );
        (results['success'] as List).add(permissionId);
      } catch (e) {
        (results['failed'] as List).add({
          'permissionId': permissionId,
          'error': e.toString(),
        });
      }
    }

    return results;
  }

  /// Get permission analytics for a month
  Future<Map<String, dynamic>> getMonthlyAnalytics(String schoolId, String month) async {
    final snapshot = await _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('monthlyPermissionUsage')
        .where('month', isEqualTo: month)
        .get();

    int totalStaff = 0;
    int totalRequests = 0;
    int totalApproved = 0;
    int totalRejected = 0;
    int totalCancelled = 0;
    int totalMinutesUsed = 0;
    final staffUsage = <Map<String, dynamic>>[];

    for (final doc in snapshot.docs) {
      final data = doc.data();
      totalStaff++;
      totalRequests += data['totalRequests'] as int? ?? 0;
      totalApproved += data['approvedRequests'] as int? ?? 0;
      totalRejected += data['rejectedRequests'] as int? ?? 0;
      totalCancelled += data['cancelledRequests'] as int? ?? 0;
      totalMinutesUsed += data['totalMinutesUsed'] as int? ?? 0;

      staffUsage.add({
        'staffId': data['staffId'],
        'totalRequests': data['totalRequests'] ?? 0,
        'approvedRequests': data['approvedRequests'] ?? 0,
        'totalMinutesUsed': data['totalMinutesUsed'] ?? 0,
      });
    }

    staffUsage.sort((a, b) => 
        (b['totalMinutesUsed'] as int).compareTo(a['totalMinutesUsed'] as int));

    return {
      'totalStaff': totalStaff,
      'totalRequests': totalRequests,
      'totalApproved': totalApproved,
      'totalRejected': totalRejected,
      'totalCancelled': totalCancelled,
      'totalMinutesUsed': totalMinutesUsed,
      'averageMinutesPerStaff': totalStaff > 0 ? (totalMinutesUsed / totalStaff).round() : 0,
      'staffUsage': staffUsage,
    };
  }
}

/// Provider for PermissionApprovalService
final permissionApprovalServiceProvider = Provider<PermissionApprovalService>((ref) {
  return PermissionApprovalService(FirebaseFirestore.instance);
});
