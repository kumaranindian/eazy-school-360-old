import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eazy_school_360/domain/entities/leave_balance.dart';
import 'package:eazy_school_360/domain/entities/leave_type_config.dart';

/// Service to manage leave balance operations including auto-assignment
class LeaveBalanceService {
  final FirebaseFirestore _firestore;

  LeaveBalanceService(this._firestore);

  /// Initialize leave balances for a new staff member with all active leave types
  /// Called when a new staff member is added to the school
  Future<void> initializeLeaveBalancesForNewStaff({
    required String schoolId,
    required String staffId,
    required String userId,
    required String createdBy,
  }) async {
    try {
      print('🔄 [LEAVE_BALANCE_SERVICE] Initializing leave balances for new staff: $staffId');
      
      // Get all active leave types for the school
      final leaveTypesSnapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('leaveTypes')
          .where('isActive', isEqualTo: true)
          .get();

      if (leaveTypesSnapshot.docs.isEmpty) {
        print('⚠️ [LEAVE_BALANCE_SERVICE] No active leave types found for school: $schoolId');
        return;
      }

      final currentAcademicYear = AcademicYear.getCurrentAcademicYear();
      final batch = _firestore.batch();
      int balancesCreated = 0;

      for (final leaveTypeDoc in leaveTypesSnapshot.docs) {
        final leaveType = LeaveTypeConfig.fromFirestore(leaveTypeDoc);
        
        // Create balance document ID: staffId_leaveTypeId_academicYear
        final balanceId = '${staffId}_${leaveType.id}_$currentAcademicYear';
        final balanceRef = _firestore
            .collection('schools')
            .doc(schoolId)
            .collection('leaveBalances')
            .doc(balanceId);

        // Check if balance already exists
        final existingBalance = await balanceRef.get();
        if (existingBalance.exists) {
          print('⏭️ [LEAVE_BALANCE_SERVICE] Balance already exists: $balanceId');
          continue;
        }

        final balance = LeaveBalance(
          id: balanceId,
          schoolId: schoolId,
          staffId: staffId,
          userId: userId,
          leaveTypeId: leaveType.id,
          leaveTypeCode: leaveType.code,
          academicYear: currentAcademicYear,
          totalAllowed: leaveType.annualQuota,
          used: 0,
          pending: 0,
          carriedForward: 0,
          available: leaveType.annualQuota,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          createdBy: createdBy,
          metadata: {
            'autoCreated': true,
            'reason': 'New staff member initialization',
            'leaveTypeName': leaveType.name,
          },
        );

        batch.set(balanceRef, balance.toFirestore());
        balancesCreated++;
        print('✅ [LEAVE_BALANCE_SERVICE] Created balance for ${leaveType.name}: $balanceId');
      }

      if (balancesCreated > 0) {
        await batch.commit();
        print('✅ [LEAVE_BALANCE_SERVICE] Successfully created $balancesCreated leave balances for staff: $staffId');
      }
    } catch (e) {
      print('❌ [LEAVE_BALANCE_SERVICE] Error initializing leave balances: $e');
      throw Exception('Failed to initialize leave balances for new staff: $e');
    }
  }

  /// Apply a new leave type to all active staff members in a school
  /// Called when a new leave type is created
  Future<void> applyLeaveTypeToAllStaff({
    required String schoolId,
    required String leaveTypeId,
    required String createdBy,
  }) async {
    try {
      print('🔄 [LEAVE_BALANCE_SERVICE] Applying leave type $leaveTypeId to all staff in school: $schoolId');

      // Get the leave type configuration
      final leaveTypeDoc = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('leaveTypes')
          .doc(leaveTypeId)
          .get();

      if (!leaveTypeDoc.exists) {
        throw Exception('Leave type not found: $leaveTypeId');
      }

      final leaveType = LeaveTypeConfig.fromFirestore(leaveTypeDoc);
      if (!leaveType.isActive) {
        print('⚠️ [LEAVE_BALANCE_SERVICE] Leave type is not active, skipping: $leaveTypeId');
        return;
      }

      // Get all active staff members
      final staffSnapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('staff')
          .where('status', isEqualTo: 'ACTIVE')
          .get();

      if (staffSnapshot.docs.isEmpty) {
        print('⚠️ [LEAVE_BALANCE_SERVICE] No active staff found in school: $schoolId');
        return;
      }

      final currentAcademicYear = AcademicYear.getCurrentAcademicYear();
      int balancesCreated = 0;
      int balancesSkipped = 0;

      // Process in batches of 500 (Firestore batch limit)
      final batches = <WriteBatch>[];
      var currentBatch = _firestore.batch();
      int operationsInCurrentBatch = 0;

      for (final staffDoc in staffSnapshot.docs) {
        final staffData = staffDoc.data();
        final staffId = staffDoc.id;
        final userId = staffData['userId'] as String;

        // Create balance document ID
        final balanceId = '${staffId}_${leaveType.id}_$currentAcademicYear';
        final balanceRef = _firestore
            .collection('schools')
            .doc(schoolId)
            .collection('leaveBalances')
            .doc(balanceId);

        // Check if balance already exists
        final existingBalance = await balanceRef.get();
        if (existingBalance.exists) {
          balancesSkipped++;
          continue;
        }

        final balance = LeaveBalance(
          id: balanceId,
          schoolId: schoolId,
          staffId: staffId,
          userId: userId,
          leaveTypeId: leaveType.id,
          leaveTypeCode: leaveType.code,
          academicYear: currentAcademicYear,
          totalAllowed: leaveType.annualQuota,
          used: 0,
          pending: 0,
          carriedForward: 0,
          available: leaveType.annualQuota,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          createdBy: createdBy,
          metadata: {
            'autoCreated': true,
            'reason': 'New leave type applied to existing staff',
            'leaveTypeName': leaveType.name,
          },
        );

        currentBatch.set(balanceRef, balance.toFirestore());
        operationsInCurrentBatch++;
        balancesCreated++;

        // If batch is full, start a new one
        if (operationsInCurrentBatch >= 500) {
          batches.add(currentBatch);
          currentBatch = _firestore.batch();
          operationsInCurrentBatch = 0;
        }
      }

      // Add the last batch if it has operations
      if (operationsInCurrentBatch > 0) {
        batches.add(currentBatch);
      }

      // Commit all batches
      for (final batch in batches) {
        await batch.commit();
      }

      print('✅ [LEAVE_BALANCE_SERVICE] Applied leave type to staff - Created: $balancesCreated, Skipped: $balancesSkipped');
    } catch (e) {
      print('❌ [LEAVE_BALANCE_SERVICE] Error applying leave type to all staff: $e');
      throw Exception('Failed to apply leave type to all staff: $e');
    }
  }

  /// Update leave balances when leave type quota is changed
  /// Only updates the totalAllowed and recalculates available
  Future<void> updateLeaveTypeQuotaForAllStaff({
    required String schoolId,
    required String leaveTypeId,
    required int newQuota,
    required String updatedBy,
  }) async {
    try {
      print('🔄 [LEAVE_BALANCE_SERVICE] Updating quota for leave type $leaveTypeId to $newQuota');

      final currentAcademicYear = AcademicYear.getCurrentAcademicYear();

      // Get all balances for this leave type in current academic year
      final balancesSnapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('leaveBalances')
          .where('leaveTypeId', isEqualTo: leaveTypeId)
          .where('academicYear', isEqualTo: currentAcademicYear)
          .get();

      if (balancesSnapshot.docs.isEmpty) {
        print('⚠️ [LEAVE_BALANCE_SERVICE] No balances found for leave type: $leaveTypeId');
        return;
      }

      final batches = <WriteBatch>[];
      var currentBatch = _firestore.batch();
      int operationsInCurrentBatch = 0;
      int balancesUpdated = 0;

      for (final balanceDoc in balancesSnapshot.docs) {
        final balance = LeaveBalance.fromFirestore(balanceDoc);
        
        // Calculate new available balance
        final newAvailable = LeaveBalance.calculateAvailable(
          newQuota,
          balance.carriedForward,
          balance.used,
          balance.pending,
        );

        currentBatch.update(balanceDoc.reference, {
          'totalAllowed': newQuota,
          'available': newAvailable,
          'updatedAt': FieldValue.serverTimestamp(),
          'metadata': {
            ...?balance.metadata,
            'lastQuotaUpdate': DateTime.now().toIso8601String(),
            'previousQuota': balance.totalAllowed,
            'updatedBy': updatedBy,
          },
        });

        operationsInCurrentBatch++;
        balancesUpdated++;

        if (operationsInCurrentBatch >= 500) {
          batches.add(currentBatch);
          currentBatch = _firestore.batch();
          operationsInCurrentBatch = 0;
        }
      }

      if (operationsInCurrentBatch > 0) {
        batches.add(currentBatch);
      }

      for (final batch in batches) {
        await batch.commit();
      }

      print('✅ [LEAVE_BALANCE_SERVICE] Updated $balancesUpdated balances with new quota: $newQuota');
    } catch (e) {
      print('❌ [LEAVE_BALANCE_SERVICE] Error updating leave type quota: $e');
      throw Exception('Failed to update leave type quota for all staff: $e');
    }
  }

  /// Get all leave balances for a staff member
  Stream<List<LeaveBalance>> getStaffLeaveBalances(String schoolId, String staffId) {
    final currentAcademicYear = AcademicYear.getCurrentAcademicYear();
    
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('leaveBalances')
        .where('staffId', isEqualTo: staffId)
        .where('academicYear', isEqualTo: currentAcademicYear)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => LeaveBalance.fromFirestore(doc))
            .toList());
  }

  /// Get a specific leave balance
  Future<LeaveBalance?> getLeaveBalance(String schoolId, String balanceId) async {
    try {
      final doc = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('leaveBalances')
          .doc(balanceId)
          .get();

      if (doc.exists) {
        return LeaveBalance.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get leave balance: $e');
    }
  }
}

/// Provider for LeaveBalanceService
final leaveBalanceServiceProvider = Provider<LeaveBalanceService>((ref) {
  return LeaveBalanceService(FirebaseFirestore.instance);
});

/// Stream provider for staff leave balances
final staffLeaveBalancesProvider = StreamProvider.family<List<LeaveBalance>, ({String schoolId, String staffId})>((ref, params) {
  final service = ref.watch(leaveBalanceServiceProvider);
  return service.getStaffLeaveBalances(params.schoolId, params.staffId);
});
