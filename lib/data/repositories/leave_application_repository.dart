import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eazy_school_360/domain/entities/leave_application.dart';
import 'package:eazy_school_360/domain/entities/leave_type_config.dart';
import 'package:eazy_school_360/domain/entities/leave_balance.dart';
import 'package:eazy_school_360/core/services/id_generator_service.dart';

class LeaveApplicationRepository {
  final FirebaseFirestore _firestore;

  LeaveApplicationRepository(this._firestore);

  /// Get all leave applications for a school (Admin view)
  Stream<List<LeaveApplication>> getSchoolLeaveApplications(String schoolId) {
    print('🔍 [LEAVE_REPO] Getting leave applications for schoolId: $schoolId');
    print('🔍 [LEAVE_REPO] Query path: schools/$schoolId/leaves');
    
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('leaves')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .handleError((error) {
          print('❌ [LEAVE_REPO] Error getting leave applications: $error');
          print('❌ [LEAVE_REPO] Error type: ${error.runtimeType}');
          if (error is FirebaseException) {
            print('❌ [LEAVE_REPO] Error code: ${error.code}');
            print('❌ [LEAVE_REPO] Error message: ${error.message}');
          }
          print('❌ [LEAVE_REPO] School ID: $schoolId');
          print('❌ [LEAVE_REPO] Full error: $error');
        })
        .map((snapshot) {
          print('✅ [LEAVE_REPO] Successfully got ${snapshot.docs.length} leave applications');
          for (var doc in snapshot.docs) {
            print('📄 [LEAVE_REPO] Leave doc: ${doc.id}');
          }
          return snapshot.docs
              .map((doc) => LeaveApplication.fromFirestore(doc))
              .toList();
        });
  }

  /// Get pending leave applications for a school (Admin approval queue)
  Stream<List<LeaveApplication>> getPendingLeaveApplications(String schoolId) {
    print('🔍 [LEAVE_REPO] Getting pending leave applications for schoolId: $schoolId');
    
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('leaves')
        .where('status', isEqualTo: 'PENDING')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .handleError((error) {
          print('❌ [LEAVE_REPO] Error getting pending leaves: $error');
          print('❌ [LEAVE_REPO] Error type: ${error.runtimeType}');
          if (error is FirebaseException) {
            print('❌ [LEAVE_REPO] Error code: ${error.code}');
            print('❌ [LEAVE_REPO] Error message: ${error.message}');
          }
          print('❌ [LEAVE_REPO] School ID: $schoolId');
        })
        .map((snapshot) {
          print('✅ [LEAVE_REPO] Successfully got ${snapshot.docs.length} pending leave applications');
          return snapshot.docs
              .map((doc) => LeaveApplication.fromFirestore(doc))
              .toList();
        });
  }

  /// Get leave applications for a specific staff member
  Stream<List<LeaveApplication>> getStaffLeaveApplications(String schoolId, String applicantId) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('leaves')
        .where('applicantId', isEqualTo: applicantId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => LeaveApplication.fromFirestore(doc))
            .toList());
  }

  /// Get availed (approved + pending) leave days for a staff member by leave type in current academic year
  Future<int> getAvailedLeaveDays(
    String schoolId,
    String applicantId,
    String leaveTypeId,
    String academicYear,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('leaves')
          .where('applicantId', isEqualTo: applicantId)
          .where('leaveTypeId', isEqualTo: leaveTypeId)
          .where('academicYear', isEqualTo: academicYear)
          .get();

      int totalDays = 0;
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final status = (data['status'] as String?)?.toUpperCase();
        // Count approved and pending leaves
        if (status == 'APPROVED' || status == 'PENDING') {
          totalDays += (data['totalDays'] as num?)?.toInt() ?? 0;
        }
      }
      return totalDays;
    } catch (e) {
      print('Error getting availed leave days: $e');
      return 0;
    }
  }

  /// Get a specific leave application
  Future<LeaveApplication?> getLeaveApplication(String schoolId, String leaveId) async {
    try {
      final doc = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('leaves')
          .doc(leaveId)
          .get();

      if (doc.exists) {
        return LeaveApplication.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get leave application: $e');
    }
  }

  /// Get holidays for a school
  Future<List<Holiday>> getSchoolHolidays(String schoolId, {DateTime? startDate, DateTime? endDate}) async {
    try {
      Query query = _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('holidays')
          .where('isActive', isEqualTo: true);

      if (startDate != null) {
        query = query.where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }

      if (endDate != null) {
        query = query.where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
      }

      final snapshot = await query.get();
      return snapshot.docs.map((doc) => Holiday.fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('Failed to get school holidays: $e');
    }
  }

  /// Create leave application (Staff)
  Future<String> createLeaveApplication(
    String schoolId,
    String applicantId,
    String staffId,
    CreateLeaveApplicationRequest request,
  ) async {
    try {
      // Validate user permissions
      await _validateStaffAccess(applicantId, schoolId);

      // Get leave type configuration
      final leaveTypeDoc = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('leaveTypes')
          .doc(request.leaveTypeId)
          .get();

      if (!leaveTypeDoc.exists) {
        throw Exception('Leave type not found');
      }

      final leaveTypeConfig = LeaveTypeConfig.fromFirestore(leaveTypeDoc);
      if (!leaveTypeConfig.isActive) {
        throw Exception('Leave type is not active');
      }

      // Get holidays for date calculation
      final holidays = await getSchoolHolidays(
        schoolId,
        startDate: request.startDate,
        endDate: request.endDate,
      );

      // Get existing leave applications for overlap check
      final existingApplications = await _getStaffLeaveApplicationsForDateRange(
        schoolId,
        applicantId,
        request.startDate,
        request.endDate,
      );

      // Calculate leave dates and validate
      final validationError = LeaveDateCalculator.validateLeaveDates(
        request.startDate,
        request.endDate,
        holidays,
        existingApplications,
      );

      if (validationError != null) {
        throw Exception(validationError);
      }

      final leaveDates = LeaveDateCalculator.calculateLeaveDates(
        request.startDate,
        request.endDate,
        holidays,
      );

      // Validate against leave type constraints
      if (leaveDates.length > leaveTypeConfig.maxDaysPerRequest) {
        throw Exception(
          'Leave request exceeds maximum ${leaveTypeConfig.maxDaysPerRequest} days per request',
        );
      }

      // Check leave balance
      final currentAcademicYear = AcademicYear.getCurrentAcademicYear();
      final balanceId = '${staffId}_${request.leaveTypeId}_$currentAcademicYear';
      final balanceDoc = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('leaveBalances')
          .doc(balanceId)
          .get();

      if (!balanceDoc.exists) {
        throw Exception('Leave balance not found for this leave type');
      }

      final balance = LeaveBalance.fromFirestore(balanceDoc);
      if (balance.available < leaveDates.length) {
        throw Exception(
          'Insufficient leave balance. Available: ${balance.available}, Requested: ${leaveDates.length}',
        );
      }

      // Auto-generate leave application code
      final idGenerator = IdGeneratorService(_firestore);
      final leaveCode = await idGenerator.generateLeaveId(schoolId);
      print('✅ [LEAVE_REPO] Auto-generated leave code: $leaveCode');

      // Fetch staff name for display
      String? staffName;
      try {
        final staffDoc = await _firestore
            .collection('schools')
            .doc(schoolId)
            .collection('staff')
            .doc(staffId)
            .get();
        if (staffDoc.exists) {
          staffName = staffDoc.data()?['firstName'] as String?;
          final lastName = staffDoc.data()?['lastName'] as String?;
          if (staffName != null && lastName != null) {
            staffName = '$staffName $lastName';
          }
        }
      } catch (e) {
        print('⚠️ [LEAVE_REPO] Could not fetch staff name: $e');
      }

      // Create leave application
      final leaveApplication = LeaveApplication(
        id: '',
        schoolId: schoolId,
        applicantId: applicantId,
        staffId: staffId,
        staffName: staffName,
        leaveTypeId: request.leaveTypeId,
        leaveTypeCode: leaveTypeConfig.code,
        academicYear: currentAcademicYear,
        startDate: request.startDate,
        endDate: request.endDate,
        leaveDates: leaveDates,
        totalDays: leaveDates.length,
        reason: request.reason,
        status: LeaveApplicationStatus.PENDING,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        remarks: request.remarks,
        metadata: {
          'leaveCode': leaveCode,
          'holidaysExcluded': holidays.length,
          'weekendsExcluded': _countWeekends(request.startDate, request.endDate),
          'leaveTypeConfig': {
            'name': leaveTypeConfig.name,
            'maxDaysPerRequest': leaveTypeConfig.maxDaysPerRequest,
            'isPaid': leaveTypeConfig.isPaid,
          },
        },
      );

      final docRef = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('leaves')
          .add(leaveApplication.toFirestore());

      // ✅ Balance reservation is handled by Cloud Function (handleLeaveApplicationCreate)
      // No client-side balance updates - prevents tampering
      print('✅ [LEAVE_REPO] Leave application created: ${docRef.id}');
      print('⏳ [LEAVE_REPO] Cloud Function will reserve balance automatically');

      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create leave application: $e');
    }
  }

  /// Approve leave application (Admin only)
  Future<void> approveLeaveApplication(
    String schoolId,
    String leaveId,
    String adminUserId,
    LeaveApprovalRequest request,
  ) async {
    try {
      // Validate admin permissions
      await _validateAdminAccess(adminUserId, schoolId);

      final leaveRef = _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('leaves')
          .doc(leaveId);

      final leaveDoc = await leaveRef.get();
      if (!leaveDoc.exists) {
        throw Exception('Leave application not found');
      }

      final currentApplication = LeaveApplication.fromFirestore(leaveDoc);
      if (!currentApplication.canBeApproved) {
        throw Exception('Leave application cannot be approved in current status');
      }

      // Validate status transition
      if (request.status != LeaveApplicationStatus.APPROVED && 
          request.status != LeaveApplicationStatus.REJECTED) {
        throw Exception('Invalid status for approval action');
      }

      if (request.status == LeaveApplicationStatus.REJECTED && 
          (request.rejectionReason == null || request.rejectionReason!.trim().isEmpty)) {
        throw Exception('Rejection reason is required when rejecting leave');
      }

      // Update leave application
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

      await leaveRef.update(updateData);

      // Balance update will be handled by Cloud Function trigger
    } catch (e) {
      throw Exception('Failed to approve leave application: $e');
    }
  }

  /// Cancel leave application (Staff only - own applications)
  Future<void> cancelLeaveApplication(String schoolId, String leaveId, String applicantId) async {
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

      final currentApplication = LeaveApplication.fromFirestore(leaveDoc);
      
      // Check ownership
      if (currentApplication.applicantId != applicantId) {
        throw Exception('You can only cancel your own leave applications');
      }

      if (!currentApplication.canBeCancelled) {
        throw Exception('Leave application cannot be cancelled in current status');
      }

      // Update leave application
      await leaveRef.update({
        'status': LeaveApplicationStatus.CANCELLED.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Balance update will be handled by Cloud Function trigger
    } catch (e) {
      throw Exception('Failed to cancel leave application: $e');
    }
  }

  /// Get staff leave applications for date range (for overlap checking)
  Future<List<LeaveApplication>> _getStaffLeaveApplicationsForDateRange(
    String schoolId,
    String applicantId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('leaves')
          .where('applicantId', isEqualTo: applicantId)
          .where('status', whereIn: ['PENDING', 'APPROVED'])
          .get();

      final applications = snapshot.docs
          .map((doc) => LeaveApplication.fromFirestore(doc))
          .where((app) => 
            // Check if there's any overlap with the requested date range
            app.startDate.isBefore(endDate.add(const Duration(days: 1))) &&
            app.endDate.isAfter(startDate.subtract(const Duration(days: 1)))
          )
          .toList();

      return applications;
    } catch (e) {
      throw Exception('Failed to get staff leave applications: $e');
    }
  }

  // ❌ REMOVED: _reserveLeaveBalance method
  // Balance reservation is now handled by Cloud Function (handleLeaveApplicationCreate)
  // This ensures:
  // - No client-side tampering
  // - Atomic server-side transactions
  // - Complete audit trail
  // - Better security and reliability

  /// Count weekends in date range
  int _countWeekends(DateTime startDate, DateTime endDate) {
    int weekendCount = 0;
    DateTime currentDate = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);

    while (currentDate.isBefore(end) || currentDate.isAtSameMomentAs(end)) {
      if (currentDate.weekday == DateTime.saturday || 
          currentDate.weekday == DateTime.sunday) {
        weekendCount++;
      }
      currentDate = currentDate.add(const Duration(days: 1));
    }

    return weekendCount;
  }

  /// Validate staff access to school
  Future<void> _validateStaffAccess(String userId, String schoolId) async {
    // Check if user exists in the staff collection for this school
    final staffQuery = await _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('staff')
        .where('userId', isEqualTo: userId)
        .limit(1)
        .get();

    if (staffQuery.docs.isNotEmpty) {
      final staffData = staffQuery.docs.first.data();
      // Check status field (ACTIVE/DISABLED) or legacy isActive field
      final status = staffData['status'] as String?;
      final isActive = staffData['isActive'];
      
      // Staff is valid if status is ACTIVE or if using legacy isActive=true
      if (status?.toUpperCase() == 'ACTIVE' || (status == null && isActive == true) || (status == null && isActive == null)) {
        return; // Staff is valid and active
      }
      throw Exception('Staff account is not active');
    }

    // Fallback: check users collection with flexible role matching
    final userDoc = await _firestore.collection('users').doc(userId).get();
    if (!userDoc.exists) {
      throw Exception('User not found');
    }

    final userData = userDoc.data()!;
    final role = userData['role'] as String?;
    
    // Accept multiple role formats
    final validRoles = ['STAFF', 'staff', 'ADMIN', 'admin', 'tenant_admin', 'teacher', 'TEACHER'];
    if (role == null || !validRoles.contains(role)) {
      throw Exception('Insufficient permissions');
    }

    // For non-super admin users, verify school access
    if (role != 'SUPER_ADMIN' && role != 'super_admin') {
      if (userData['schoolId'] != schoolId) {
        throw Exception('Access denied to this school');
      }
    }

    final status = userData['status'] as String?;
    if (status != null && status != 'ACTIVE' && status != 'active') {
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
final leaveApplicationRepositoryProvider = Provider<LeaveApplicationRepository>((ref) {
  final firestore = FirebaseFirestore.instance;
  return LeaveApplicationRepository(firestore);
});

/// Stream provider for school leave applications (Admin view)
final schoolLeaveApplicationsProvider = StreamProvider.family<List<LeaveApplication>, String>((ref, schoolId) {
  final repository = ref.watch(leaveApplicationRepositoryProvider);
  return repository.getSchoolLeaveApplications(schoolId);
});

/// Stream provider for pending leave applications (Admin approval queue)
final pendingLeaveApplicationsProvider = StreamProvider.family<List<LeaveApplication>, String>((ref, schoolId) {
  final repository = ref.watch(leaveApplicationRepositoryProvider);
  return repository.getPendingLeaveApplications(schoolId);
});

/// Stream provider for staff leave applications
final staffLeaveApplicationsProvider = StreamProvider.family<List<LeaveApplication>, ({String schoolId, String applicantId})>((ref, params) {
  final repository = ref.watch(leaveApplicationRepositoryProvider);
  return repository.getStaffLeaveApplications(params.schoolId, params.applicantId);
});

/// Provider for specific leave application
final leaveApplicationProvider = FutureProvider.family<LeaveApplication?, Map<String, String>>((ref, params) {
  final repository = ref.watch(leaveApplicationRepositoryProvider);
  return repository.getLeaveApplication(params['schoolId']!, params['leaveId']!);
});

/// Provider for school holidays
final schoolHolidaysProvider = FutureProvider.family<List<Holiday>, Map<String, dynamic>>((ref, params) {
  final repository = ref.watch(leaveApplicationRepositoryProvider);
  return repository.getSchoolHolidays(
    params['schoolId'] as String,
    startDate: params['startDate'] as DateTime?,
    endDate: params['endDate'] as DateTime?,
  );
});

/// Provider for availed leave days (approved + pending) by leave type
final availedLeaveDaysProvider = FutureProvider.family<int, ({
  String schoolId,
  String applicantId,
  String leaveTypeId,
  String academicYear,
})>((ref, params) {
  final repository = ref.watch(leaveApplicationRepositoryProvider);
  return repository.getAvailedLeaveDays(
    params.schoolId,
    params.applicantId,
    params.leaveTypeId,
    params.academicYear,
  );
});
