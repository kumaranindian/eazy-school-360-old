import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eazy_school_360/domain/entities/leave_cancellation.dart';
import 'package:eazy_school_360/domain/entities/leave_application.dart';

class LeaveCancellationRepository {
  final FirebaseFirestore _firestore;

  LeaveCancellationRepository(this._firestore);

  /// Get all leave cancellation requests for a school (Admin view)
  Stream<List<LeaveCancellationRequest>> getSchoolLeaveCancellations(String schoolId) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('leaveCancellations')
        .orderBy('requestedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => LeaveCancellationRequest.fromFirestore(doc))
            .toList());
  }

  /// Get pending leave cancellation requests for a school (Admin approval queue)
  Stream<List<LeaveCancellationRequest>> getPendingLeaveCancellations(String schoolId) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('leaveCancellations')
        .where('status', isEqualTo: 'PENDING')
        .orderBy('requestedAt', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => LeaveCancellationRequest.fromFirestore(doc))
            .toList());
  }

  /// Get leave cancellation requests for a specific staff member
  Stream<List<LeaveCancellationRequest>> getStaffLeaveCancellations(String schoolId, String applicantId) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('leaveCancellations')
        .where('applicantId', isEqualTo: applicantId)
        .orderBy('requestedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => LeaveCancellationRequest.fromFirestore(doc))
            .toList());
  }

  /// Get a specific leave cancellation request
  Future<LeaveCancellationRequest?> getLeaveCancellationRequest(String schoolId, String cancellationId) async {
    try {
      final doc = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('leaveCancellations')
          .doc(cancellationId)
          .get();

      if (doc.exists) {
        return LeaveCancellationRequest.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get leave cancellation request: $e');
    }
  }

  /// Create leave cancellation request (Staff)
  Future<String> createLeaveCancellationRequest(
    String schoolId,
    String applicantId,
    String staffId,
    CreateLeaveCancellationRequest request,
  ) async {
    try {
      // Validate user permissions
      await _validateStaffAccess(applicantId, schoolId);

      // Get the leave application to validate and extract details
      final leaveDoc = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('leaves')
          .doc(request.leaveApplicationId)
          .get();

      if (!leaveDoc.exists) {
        throw Exception('Leave application not found');
      }

      final leaveApplication = LeaveApplication.fromFirestore(leaveDoc);

      // Validate that the leave belongs to the requesting user
      if (leaveApplication.applicantId != applicantId) {
        throw Exception('You can only request cancellation for your own leave applications');
      }

      // Validate that the leave is in an approved state
      if (!leaveApplication.isApproved) {
        throw Exception('Only approved leave applications can be cancelled through this process');
      }

      // Check if leave is in the future
      final today = DateTime.now();
      final todayDate = DateTime(today.year, today.month, today.day);
      final leaveStartDate = DateTime(
        leaveApplication.startDate.year,
        leaveApplication.startDate.month,
        leaveApplication.startDate.day,
      );

      if (leaveStartDate.isBefore(todayDate)) {
        throw Exception('Cannot cancel leave that has already started or passed');
      }

      // Check if there's already a pending cancellation request
      final existingCancellationQuery = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('leaveCancellations')
          .where('leaveApplicationId', isEqualTo: request.leaveApplicationId)
          .where('status', isEqualTo: 'PENDING')
          .get();

      if (existingCancellationQuery.docs.isNotEmpty) {
        throw Exception('A cancellation request is already pending for this leave application');
      }

      // Create leave cancellation request
      final cancellationRequest = LeaveCancellationRequest(
        id: '',
        schoolId: schoolId,
        leaveApplicationId: request.leaveApplicationId,
        applicantId: applicantId,
        staffId: staffId,
        leaveTypeId: leaveApplication.leaveTypeId,
        leaveTypeCode: leaveApplication.leaveTypeCode,
        academicYear: leaveApplication.academicYear,
        totalDaysToRestore: leaveApplication.totalDays,
        cancellationReason: request.cancellationReason,
        status: LeaveCancellationStatus.PENDING,
        requestedAt: DateTime.now(),
        updatedAt: DateTime.now(),
        metadata: {
          'originalLeaveStartDate': leaveApplication.startDate.toIso8601String(),
          'originalLeaveEndDate': leaveApplication.endDate.toIso8601String(),
          'originalLeaveDates': leaveApplication.leaveDates.map((d) => d.toIso8601String()).toList(),
          'leaveApplicationCreatedAt': leaveApplication.createdAt.toIso8601String(),
        },
      );

      final docRef = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('leaveCancellations')
          .add(cancellationRequest.toFirestore());

      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create leave cancellation request: $e');
    }
  }

  /// Approve/Reject leave cancellation request (Admin only)
  Future<void> processLeaveCancellationRequest(
    String schoolId,
    String cancellationId,
    String adminUserId,
    LeaveCancellationApprovalRequest request,
  ) async {
    try {
      // Validate admin permissions
      await _validateAdminAccess(adminUserId, schoolId);

      final cancellationRef = _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('leaveCancellations')
          .doc(cancellationId);

      final cancellationDoc = await cancellationRef.get();
      if (!cancellationDoc.exists) {
        throw Exception('Leave cancellation request not found');
      }

      final currentRequest = LeaveCancellationRequest.fromFirestore(cancellationDoc);
      if (!currentRequest.canBeApproved) {
        throw Exception('Leave cancellation request cannot be processed in current status');
      }

      // Validate status transition
      if (request.status != LeaveCancellationStatus.APPROVED && 
          request.status != LeaveCancellationStatus.REJECTED) {
        throw Exception('Invalid status for cancellation approval action');
      }

      if (request.status == LeaveCancellationStatus.REJECTED && 
          (request.rejectionReason == null || request.rejectionReason!.trim().isEmpty)) {
        throw Exception('Rejection reason is required when rejecting cancellation request');
      }

      // Update cancellation request
      final updateData = <String, dynamic>{
        'status': request.status.name,
        'updatedAt': FieldValue.serverTimestamp(),
        'approvedBy': adminUserId,
        'approvedAt': FieldValue.serverTimestamp(),
      };

      if (request.rejectionReason != null) {
        updateData['rejectionReason'] = request.rejectionReason;
      }

      if (request.adminRemarks != null) {
        updateData['adminRemarks'] = request.adminRemarks;
      }

      await cancellationRef.update(updateData);

      // Balance restoration and leave status update will be handled by Cloud Function trigger
    } catch (e) {
      throw Exception('Failed to process leave cancellation request: $e');
    }
  }

  /// Check if a leave application can be cancelled directly (pending leaves)
  Future<bool> canCancelLeaveDirectly(String schoolId, String leaveId, String applicantId) async {
    try {
      final leaveDoc = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('leaves')
          .doc(leaveId)
          .get();

      if (!leaveDoc.exists) {
        return false;
      }

      final leaveApplication = LeaveApplication.fromFirestore(leaveDoc);
      
      // Can cancel directly if:
      // 1. Leave is pending
      // 2. User is the applicant
      return leaveApplication.isPending && leaveApplication.applicantId == applicantId;
    } catch (e) {
      return false;
    }
  }

  /// Cancel pending leave directly (no admin approval needed)
  Future<void> cancelPendingLeave(String schoolId, String leaveId, String applicantId) async {
    try {
      // Validate user permissions
      await _validateStaffAccess(applicantId, schoolId);

      final leaveRef = _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('leaves')
          .doc(leaveId);

      final leaveDoc = await leaveRef.get();
      if (!leaveDoc.exists) {
        throw Exception('Leave application not found');
      }

      final leaveApplication = LeaveApplication.fromFirestore(leaveDoc);
      
      // Validate ownership and status
      if (leaveApplication.applicantId != applicantId) {
        throw Exception('You can only cancel your own leave applications');
      }

      if (!leaveApplication.isPending) {
        throw Exception('Only pending leave applications can be cancelled directly');
      }

      // Update leave status to cancelled
      await leaveRef.update({
        'status': LeaveApplicationStatus.CANCELLED.name,
        'updatedAt': FieldValue.serverTimestamp(),
        'cancelledAt': FieldValue.serverTimestamp(),
        'cancellationReason': 'Cancelled by applicant',
      });

      // Balance update will be handled by existing Cloud Function trigger
    } catch (e) {
      throw Exception('Failed to cancel pending leave: $e');
    }
  }

  /// Get cancellable leaves for a staff member
  Future<List<LeaveApplication>> getCancellableLeaves(String schoolId, String applicantId) async {
    try {
      // Get approved leaves that are in the future
      final today = DateTime.now();
      final todayTimestamp = Timestamp.fromDate(DateTime(today.year, today.month, today.day));

      final approvedLeavesQuery = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('leaves')
          .where('applicantId', isEqualTo: applicantId)
          .where('status', isEqualTo: 'APPROVED')
          .where('startDate', isGreaterThan: todayTimestamp)
          .get();

      final pendingLeavesQuery = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('leaves')
          .where('applicantId', isEqualTo: applicantId)
          .where('status', isEqualTo: 'PENDING')
          .get();

      final allLeaves = <LeaveApplication>[];
      
      // Add approved future leaves
      for (final doc in approvedLeavesQuery.docs) {
        allLeaves.add(LeaveApplication.fromFirestore(doc));
      }

      // Add pending leaves
      for (final doc in pendingLeavesQuery.docs) {
        allLeaves.add(LeaveApplication.fromFirestore(doc));
      }

      // Sort by start date
      allLeaves.sort((a, b) => a.startDate.compareTo(b.startDate));

      return allLeaves;
    } catch (e) {
      throw Exception('Failed to get cancellable leaves: $e');
    }
  }

  /// Validate staff access to school
  Future<void> _validateStaffAccess(String userId, String schoolId) async {
    final userDoc = await _firestore.collection('users').doc(userId).get();
    if (!userDoc.exists) {
      throw Exception('User not found');
    }

    final userData = userDoc.data()!;
    if (userData['role'] != 'STAFF' && userData['role'] != 'ADMIN') {
      throw Exception('Insufficient permissions');
    }

    if (userData['schoolId'] != schoolId) {
      throw Exception('Access denied to this school');
    }

    if (userData['status'] != 'ACTIVE') {
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

    // UserStatus is stored as enum string, check against ACTIVE
    if (adminData['status'] != 'ACTIVE' && adminData['status'] != 'Active') {
      throw Exception('Admin account is not active');
    }
  }
}

/// Providers
final leaveCancellationRepositoryProvider = Provider<LeaveCancellationRepository>((ref) {
  final firestore = FirebaseFirestore.instance;
  return LeaveCancellationRepository(firestore);
});

/// Stream provider for school leave cancellation requests (Admin view)
final schoolLeaveCancellationsProvider = StreamProvider.family<List<LeaveCancellationRequest>, String>((ref, schoolId) {
  final repository = ref.watch(leaveCancellationRepositoryProvider);
  return repository.getSchoolLeaveCancellations(schoolId);
});

/// Stream provider for pending leave cancellation requests (Admin approval queue)
final pendingLeaveCancellationsProvider = StreamProvider.family<List<LeaveCancellationRequest>, String>((ref, schoolId) {
  final repository = ref.watch(leaveCancellationRepositoryProvider);
  return repository.getPendingLeaveCancellations(schoolId);
});

/// Stream provider for staff leave cancellation requests
final staffLeaveCancellationsProvider = StreamProvider.family<List<LeaveCancellationRequest>, Map<String, String>>((ref, params) {
  final repository = ref.watch(leaveCancellationRepositoryProvider);
  return repository.getStaffLeaveCancellations(params['schoolId']!, params['applicantId']!);
});

/// Provider for specific leave cancellation request
final leaveCancellationRequestProvider = FutureProvider.family<LeaveCancellationRequest?, Map<String, String>>((ref, params) {
  final repository = ref.watch(leaveCancellationRepositoryProvider);
  return repository.getLeaveCancellationRequest(params['schoolId']!, params['cancellationId']!);
});

/// Provider for cancellable leaves
final cancellableLeavesProvider = FutureProvider.family<List<LeaveApplication>, Map<String, String>>((ref, params) {
  final repository = ref.watch(leaveCancellationRepositoryProvider);
  return repository.getCancellableLeaves(params['schoolId']!, params['applicantId']!);
});
