import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Service to handle leave approval workflows with atomic transactions
/// Replaces Cloud Functions - all logic runs client-side with Firestore rules for security
///
/// NOT CURRENTLY WIRED TO ANY SCREEN — the live admin approval flow
/// (leave_approval_screen.dart -> LeaveApplicationRepository.approveLeaveApplication)
/// only updates the leave document's status and relies on the
/// onLeaveStatusChange Cloud Function trigger to move the balance, matching
/// firebase/firestore.rules ("leaveBalances: allow write: if false"). This
/// class's direct client write to leaveBalances would be rejected by that
/// rule today — but if the rule is ever loosened and this class is wired up,
/// its balance mutation would double up with the same mutation the
/// onLeaveStatusChange trigger performs on the same status change. Don't use
/// this class unless you also remove/guard against that trigger.
class LeaveApprovalService {
  final FirebaseFirestore _firestore;

  LeaveApprovalService(this._firestore);

  /// Approve a leave application with atomic balance update
  /// Uses Firestore transaction to ensure consistency
  Future<void> approveLeave({
    required String schoolId,
    required String leaveId,
    required String approvedBy,
    String? remarks,
  }) async {
    print('✅ [LEAVE_APPROVAL] Approving leave: $leaveId');

    await _firestore.runTransaction((transaction) async {
      // 1. Get the leave document
      final leaveRef = _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('leaves')
          .doc(leaveId);

      final leaveDoc = await transaction.get(leaveRef);
      if (!leaveDoc.exists) {
        throw Exception('Leave application not found');
      }

      final leaveData = leaveDoc.data()!;
      final currentStatus = leaveData['status'] as String?;

      // Validate current status
      if (currentStatus != 'PENDING') {
        throw Exception('Cannot approve - leave is not in PENDING status (current: $currentStatus)');
      }

      final staffId = leaveData['staffId'] as String;
      final leaveTypeId = leaveData['leaveTypeId'] as String;
      final totalDays = leaveData['totalDays'] as int? ?? 0;
      final academicYear = leaveData['academicYear'] as String;

      // 2. Get the balance document
      final balanceId = '${staffId}_${leaveTypeId}_$academicYear';
      final balanceRef = _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('leaveBalances')
          .doc(balanceId);

      final balanceDoc = await transaction.get(balanceRef);
      if (!balanceDoc.exists) {
        throw Exception('Leave balance not found for staff');
      }

      final balanceData = balanceDoc.data()!;
      final currentPending = balanceData['pending'] as int? ?? 0;
      final currentUsed = balanceData['used'] as int? ?? 0;

      // 3. Update leave status
      transaction.update(leaveRef, {
        'status': 'APPROVED',
        'approvedBy': approvedBy,
        'approvedAt': FieldValue.serverTimestamp(),
        'remarks': remarks,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 4. Update balance: move from pending to used
      transaction.update(balanceRef, {
        'pending': (currentPending - totalDays).clamp(0, double.infinity).toInt(),
        'used': currentUsed + totalDays,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 5. Create audit log entry
      final auditRef = _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('auditLog')
          .doc();

      transaction.set(auditRef, {
        'action': 'LEAVE_APPROVED',
        'performedBy': approvedBy,
        'timestamp': FieldValue.serverTimestamp(),
        'details': {
          'leaveId': leaveId,
          'staffId': staffId,
          'totalDays': totalDays,
          'leaveTypeId': leaveTypeId,
          'remarks': remarks,
        },
      });
    });

    print('✅ [LEAVE_APPROVAL] Leave approved successfully: $leaveId');
  }

  /// Reject a leave application with atomic balance update
  Future<void> rejectLeave({
    required String schoolId,
    required String leaveId,
    required String rejectedBy,
    required String reason,
  }) async {
    print('❌ [LEAVE_APPROVAL] Rejecting leave: $leaveId');

    await _firestore.runTransaction((transaction) async {
      // 1. Get the leave document
      final leaveRef = _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('leaves')
          .doc(leaveId);

      final leaveDoc = await transaction.get(leaveRef);
      if (!leaveDoc.exists) {
        throw Exception('Leave application not found');
      }

      final leaveData = leaveDoc.data()!;
      final currentStatus = leaveData['status'] as String?;

      if (currentStatus != 'PENDING') {
        throw Exception('Cannot reject - leave is not in PENDING status');
      }

      final staffId = leaveData['staffId'] as String;
      final leaveTypeId = leaveData['leaveTypeId'] as String;
      final totalDays = leaveData['totalDays'] as int? ?? 0;
      final academicYear = leaveData['academicYear'] as String;

      // 2. Get the balance document
      final balanceId = '${staffId}_${leaveTypeId}_$academicYear';
      final balanceRef = _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('leaveBalances')
          .doc(balanceId);

      final balanceDoc = await transaction.get(balanceRef);
      if (!balanceDoc.exists) {
        throw Exception('Leave balance not found');
      }

      final balanceData = balanceDoc.data()!;
      final currentPending = balanceData['pending'] as int? ?? 0;
      final currentAvailable = balanceData['available'] as int? ?? 0;

      // 3. Update leave status
      transaction.update(leaveRef, {
        'status': 'REJECTED',
        'rejectedBy': rejectedBy,
        'rejectedAt': FieldValue.serverTimestamp(),
        'rejectionReason': reason,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 4. Update balance: release pending back to available
      transaction.update(balanceRef, {
        'pending': (currentPending - totalDays).clamp(0, double.infinity).toInt(),
        'available': currentAvailable + totalDays,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 5. Audit log
      final auditRef = _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('auditLog')
          .doc();

      transaction.set(auditRef, {
        'action': 'LEAVE_REJECTED',
        'performedBy': rejectedBy,
        'timestamp': FieldValue.serverTimestamp(),
        'details': {
          'leaveId': leaveId,
          'staffId': staffId,
          'totalDays': totalDays,
          'reason': reason,
        },
      });
    });

    print('❌ [LEAVE_APPROVAL] Leave rejected: $leaveId');
  }

  /// Cancel a leave application (by staff or admin)
  Future<void> cancelLeave({
    required String schoolId,
    required String leaveId,
    required String cancelledBy,
    String? reason,
  }) async {
    print('🚫 [LEAVE_APPROVAL] Cancelling leave: $leaveId');

    await _firestore.runTransaction((transaction) async {
      final leaveRef = _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('leaves')
          .doc(leaveId);

      final leaveDoc = await transaction.get(leaveRef);
      if (!leaveDoc.exists) {
        throw Exception('Leave application not found');
      }

      final leaveData = leaveDoc.data()!;
      final currentStatus = leaveData['status'] as String?;

      if (currentStatus != 'PENDING' && currentStatus != 'APPROVED') {
        throw Exception('Cannot cancel - leave status is $currentStatus');
      }

      final staffId = leaveData['staffId'] as String;
      final leaveTypeId = leaveData['leaveTypeId'] as String;
      final totalDays = leaveData['totalDays'] as int? ?? 0;
      final academicYear = leaveData['academicYear'] as String;

      final balanceId = '${staffId}_${leaveTypeId}_$academicYear';
      final balanceRef = _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('leaveBalances')
          .doc(balanceId);

      final balanceDoc = await transaction.get(balanceRef);
      if (!balanceDoc.exists) {
        throw Exception('Leave balance not found');
      }

      final balanceData = balanceDoc.data()!;

      // Update leave status
      transaction.update(leaveRef, {
        'status': 'CANCELLED',
        'cancelledBy': cancelledBy,
        'cancelledAt': FieldValue.serverTimestamp(),
        'cancellationReason': reason,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update balance based on previous status
      if (currentStatus == 'PENDING') {
        // Release pending back to available
        final currentPending = balanceData['pending'] as int? ?? 0;
        final currentAvailable = balanceData['available'] as int? ?? 0;
        transaction.update(balanceRef, {
          'pending': (currentPending - totalDays).clamp(0, double.infinity).toInt(),
          'available': currentAvailable + totalDays,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else if (currentStatus == 'APPROVED') {
        // Release used back to available
        final currentUsed = balanceData['used'] as int? ?? 0;
        final currentAvailable = balanceData['available'] as int? ?? 0;
        transaction.update(balanceRef, {
          'used': (currentUsed - totalDays).clamp(0, double.infinity).toInt(),
          'available': currentAvailable + totalDays,
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
        'action': 'LEAVE_CANCELLED',
        'performedBy': cancelledBy,
        'timestamp': FieldValue.serverTimestamp(),
        'details': {
          'leaveId': leaveId,
          'staffId': staffId,
          'totalDays': totalDays,
          'previousStatus': currentStatus,
          'reason': reason,
        },
      });
    });

    print('🚫 [LEAVE_APPROVAL] Leave cancelled: $leaveId');
  }

  /// Submit a new leave application with balance reservation
  Future<String> submitLeaveApplication({
    required String schoolId,
    required String staffId,
    required String applicantId,
    required String applicantName,
    required String leaveTypeId,
    required String leaveTypeCode,
    required String leaveTypeName,
    required DateTime startDate,
    required DateTime endDate,
    required int totalDays,
    required String academicYear,
    String? reason,
  }) async {
    print('📝 [LEAVE_APPROVAL] Submitting leave application');

    final leaveId = _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('leaves')
        .doc()
        .id;

    await _firestore.runTransaction((transaction) async {
      // 1. Check balance availability
      final balanceId = '${staffId}_${leaveTypeId}_$academicYear';
      final balanceRef = _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('leaveBalances')
          .doc(balanceId);

      final balanceDoc = await transaction.get(balanceRef);
      
      int currentAvailable = 0;
      bool balanceExists = balanceDoc.exists;

      if (balanceExists) {
        final balanceData = balanceDoc.data()!;
        currentAvailable = balanceData['available'] as int? ?? 0;

        if (currentAvailable < totalDays) {
          throw Exception('Insufficient leave balance. Available: $currentAvailable, Requested: $totalDays');
        }
      }

      // 2. Create leave application
      final leaveRef = _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('leaves')
          .doc(leaveId);

      transaction.set(leaveRef, {
        'id': leaveId,
        'schoolId': schoolId,
        'staffId': staffId,
        'applicantId': applicantId,
        'applicantName': applicantName,
        'leaveTypeId': leaveTypeId,
        'leaveTypeCode': leaveTypeCode,
        'leaveTypeName': leaveTypeName,
        'startDate': Timestamp.fromDate(startDate),
        'endDate': Timestamp.fromDate(endDate),
        'totalDays': totalDays,
        'academicYear': academicYear,
        'reason': reason,
        'status': 'PENDING',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 3. Reserve balance (move from available to pending)
      if (balanceExists) {
        final balanceData = balanceDoc.data()!;
        final currentPending = balanceData['pending'] as int? ?? 0;

        transaction.update(balanceRef, {
          'pending': currentPending + totalDays,
          'available': currentAvailable - totalDays,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });

    print('📝 [LEAVE_APPROVAL] Leave submitted: $leaveId');
    return leaveId;
  }

  /// Batch approve multiple leaves (admin operation)
  Future<Map<String, dynamic>> batchApproveLeaves({
    required String schoolId,
    required List<String> leaveIds,
    required String approvedBy,
    String? remarks,
  }) async {
    print('📋 [LEAVE_APPROVAL] Batch approving ${leaveIds.length} leaves');

    final results = <String, dynamic>{
      'success': <String>[],
      'failed': <Map<String, String>>[],
    };

    for (final leaveId in leaveIds) {
      try {
        await approveLeave(
          schoolId: schoolId,
          leaveId: leaveId,
          approvedBy: approvedBy,
          remarks: remarks,
        );
        (results['success'] as List).add(leaveId);
      } catch (e) {
        (results['failed'] as List).add({
          'leaveId': leaveId,
          'error': e.toString(),
        });
      }
    }

    print('📋 [LEAVE_APPROVAL] Batch complete: ${(results['success'] as List).length} approved, ${(results['failed'] as List).length} failed');
    return results;
  }

  /// Batch reject multiple leaves
  Future<Map<String, dynamic>> batchRejectLeaves({
    required String schoolId,
    required List<String> leaveIds,
    required String rejectedBy,
    required String reason,
  }) async {
    final results = <String, dynamic>{
      'success': <String>[],
      'failed': <Map<String, String>>[],
    };

    for (final leaveId in leaveIds) {
      try {
        await rejectLeave(
          schoolId: schoolId,
          leaveId: leaveId,
          rejectedBy: rejectedBy,
          reason: reason,
        );
        (results['success'] as List).add(leaveId);
      } catch (e) {
        (results['failed'] as List).add({
          'leaveId': leaveId,
          'error': e.toString(),
        });
      }
    }

    return results;
  }
}

/// Provider for LeaveApprovalService
final leaveApprovalServiceProvider = Provider<LeaveApprovalService>((ref) {
  return LeaveApprovalService(FirebaseFirestore.instance);
});
