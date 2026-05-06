import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eazy_school_360/domain/entities/leave_type_config.dart';
import 'package:eazy_school_360/data/services/leave_balance_service.dart';

class LeaveConfigurationRepository {
  final FirebaseFirestore _firestore;

  LeaveConfigurationRepository(this._firestore);

  /// Get all leave type configurations for a school
  Stream<List<LeaveTypeConfig>> getSchoolLeaveTypes(String schoolId) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('leaveTypes')
        .orderBy('code')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => LeaveTypeConfig.fromFirestore(doc))
            .toList());
  }

  /// Get active leave type configurations for a school
  Stream<List<LeaveTypeConfig>> getActiveSchoolLeaveTypes(String schoolId) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('leaveTypes')
        .where('isActive', isEqualTo: true)
        // TODO: Re-enable orderBy('code') once Firestore index is built
        // .orderBy('code')
        .snapshots()
        .map((snapshot) {
          final leaveTypes = snapshot.docs
              .map((doc) => LeaveTypeConfig.fromFirestore(doc))
              .toList();

          // Deduplicate by code — keep the first occurrence (oldest doc) per code
          final seen = <String>{};
          final deduplicated = leaveTypes.where((lt) => seen.add(lt.code.toUpperCase())).toList();

          // Sort in memory until index is ready
          deduplicated.sort((a, b) => a.code.compareTo(b.code));
          return deduplicated;
        });
  }

  /// Get a specific leave type configuration
  Future<LeaveTypeConfig?> getLeaveTypeConfig(String schoolId, String leaveTypeId) async {
    try {
      final doc = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('leaveTypes')
          .doc(leaveTypeId)
          .get();

      if (doc.exists) {
        return LeaveTypeConfig.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get leave type configuration: $e');
    }
  }

  /// Check if leave type code is unique within school
  Future<bool> isLeaveTypeCodeUnique(String schoolId, String code, {String? excludeLeaveTypeId}) async {
    try {
      Query query = _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('leaveTypes')
          .where('code', isEqualTo: code);

      final querySnapshot = await query.get();
      
      if (excludeLeaveTypeId != null) {
        // When updating, exclude the current leave type
        return querySnapshot.docs.every((doc) => doc.id == excludeLeaveTypeId);
      }
      
      return querySnapshot.docs.isEmpty;
    } catch (e) {
      throw Exception('Failed to check leave type code uniqueness: $e');
    }
  }

  /// Create new leave type configuration (Admin only)
  Future<String> createLeaveTypeConfig(String schoolId, String adminUserId, CreateLeaveTypeConfigRequest request) async {
    try {
      // Validate admin permissions
      await _validateAdminAccess(adminUserId, schoolId);

      // Check code uniqueness
      final isUnique = await isLeaveTypeCodeUnique(schoolId, request.code);
      if (!isUnique) {
        throw Exception('Leave type code ${request.code} already exists in this school');
      }

      // Validate configuration
      _validateLeaveTypeConfig(request);

      final leaveTypeConfig = LeaveTypeConfig(
        id: '', // Will be set by Firestore
        schoolId: schoolId,
        name: request.name,
        code: request.code.toUpperCase(),
        description: request.description,
        annualQuota: request.annualQuota,
        carryForwardAllowed: request.carryForwardAllowed,
        maxCarryForwardDays: request.maxCarryForwardDays,
        maxDaysPerRequest: request.maxDaysPerRequest,
        isPaid: request.isPaid,
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: adminUserId,
        customRules: request.customRules,
      );

      final docRef = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('leaveTypes')
          .add(leaveTypeConfig.toFirestore());

      // Auto-apply new leave type to all existing active staff members
      try {
        final leaveBalanceService = LeaveBalanceService(_firestore);
        await leaveBalanceService.applyLeaveTypeToAllStaff(
          schoolId: schoolId,
          leaveTypeId: docRef.id,
          createdBy: adminUserId,
        );
        print('✅ [LEAVE_CONFIG_REPO] Leave type applied to all staff: ${docRef.id}');
      } catch (e) {
        print('⚠️ [LEAVE_CONFIG_REPO] Failed to apply leave type to staff (non-blocking): $e');
        // Non-blocking - leave type creation should still succeed
      }

      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create leave type configuration: $e');
    }
  }

  /// Update leave type configuration (Admin only)
  Future<void> updateLeaveTypeConfig(String schoolId, String leaveTypeId, String adminUserId, UpdateLeaveTypeConfigRequest request) async {
    try {
      // Validate admin permissions
      await _validateAdminAccess(adminUserId, schoolId);

      if (!request.hasChanges) {
        throw Exception('No changes to update');
      }

      final leaveTypeRef = _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('leaveTypes')
          .doc(leaveTypeId);

      final leaveTypeDoc = await leaveTypeRef.get();
      if (!leaveTypeDoc.exists) {
        throw Exception('Leave type configuration not found');
      }

      final updateData = request.toMap();

      // Validate updated configuration
      if (request.annualQuota != null || request.maxCarryForwardDays != null || request.carryForwardAllowed != null) {
        final currentConfig = LeaveTypeConfig.fromFirestore(leaveTypeDoc);
        final updatedConfig = currentConfig.copyWith(
          annualQuota: request.annualQuota,
          maxCarryForwardDays: request.maxCarryForwardDays,
          carryForwardAllowed: request.carryForwardAllowed,
        );
        _validateLeaveTypeConfigUpdate(updatedConfig);
      }

      await leaveTypeRef.update(updateData);

      // If quota changed, trigger balance updates for all staff
      if (request.annualQuota != null) {
        await _triggerBalanceQuotaUpdate(schoolId, leaveTypeId, request.annualQuota!, adminUserId);
      }
    } catch (e) {
      throw Exception('Failed to update leave type configuration: $e');
    }
  }

  /// Delete leave type configuration (Admin only)
  Future<void> deleteLeaveTypeConfig(String schoolId, String leaveTypeId, String adminUserId) async {
    try {
      // Validate admin permissions
      await _validateAdminAccess(adminUserId, schoolId);

      final leaveTypeRef = _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('leaveTypes')
          .doc(leaveTypeId);

      final leaveTypeDoc = await leaveTypeRef.get();
      if (!leaveTypeDoc.exists) {
        throw Exception('Leave type configuration not found');
      }

      // Check if there are any leave requests for this type
      final leaveRequestsQuery = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('leaves')
          .where('leaveTypeId', isEqualTo: leaveTypeId)
          .limit(1)
          .get();

      if (leaveRequestsQuery.docs.isNotEmpty) {
        throw Exception('Cannot delete leave type that has been used in leave requests');
      }

      // Actually delete the document
      await leaveTypeRef.delete();
    } catch (e) {
      throw Exception('Failed to delete leave type configuration: $e');
    }
  }

  /// Deactivate leave type configuration (Admin only) - soft delete
  Future<void> deactivateLeaveTypeConfig(String schoolId, String leaveTypeId, String adminUserId) async {
    try {
      // Validate admin permissions
      await _validateAdminAccess(adminUserId, schoolId);

      final leaveTypeRef = _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('leaveTypes')
          .doc(leaveTypeId);

      final leaveTypeDoc = await leaveTypeRef.get();
      if (!leaveTypeDoc.exists) {
        throw Exception('Leave type configuration not found');
      }

      // Check if there are active leave requests for this type
      final activeRequestsQuery = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('leaves')
          .where('leaveTypeId', isEqualTo: leaveTypeId)
          .where('status', whereIn: ['PENDING', 'APPROVED'])
          .limit(1)
          .get();

      if (activeRequestsQuery.docs.isNotEmpty) {
        throw Exception('Cannot deactivate leave type with active leave requests');
      }

      // Soft delete by deactivating
      await leaveTypeRef.update({
        'isActive': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to deactivate leave type configuration: $e');
    }
  }

  /// Initialize default leave types for a new school (skips codes that already exist)
  Future<void> initializeDefaultLeaveTypes(String schoolId, String adminUserId) async {
    try {
      await _validateAdminAccess(adminUserId, schoolId);

      // Fetch all existing leave type codes for this school to avoid duplicates
      final existingSnapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('leaveTypes')
          .get();
      final existingCodes = existingSnapshot.docs
          .map((doc) => ((doc.data()['code'] as String?) ?? '').toUpperCase())
          .toSet();

      final defaultConfigs = _getDefaultLeaveTypeConfigs();
      final batch = _firestore.batch();
      int added = 0;

      for (final config in defaultConfigs) {
        final code = (config['code'] as String).toUpperCase();
        if (existingCodes.contains(code)) {
          print('⏭️ [LEAVE_CONFIG_REPO] Skipping existing leave type code: $code');
          continue;
        }

        final leaveTypeConfig = LeaveTypeConfig(
          id: '',
          schoolId: schoolId,
          name: config['name'] as String,
          code: code,
          description: config['description'] as String,
          annualQuota: config['annualQuota'] as int,
          carryForwardAllowed: config['carryForwardAllowed'] as bool,
          maxCarryForwardDays: config['maxCarryForwardDays'] as int,
          maxDaysPerRequest: config['maxDaysPerRequest'] as int,
          isPaid: config['isPaid'] as bool,
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          createdBy: adminUserId,
        );

        final docRef = _firestore
            .collection('schools')
            .doc(schoolId)
            .collection('leaveTypes')
            .doc();

        batch.set(docRef, leaveTypeConfig.toFirestore());
        added++;
      }

      if (added > 0) {
        await batch.commit();
        print('✅ [LEAVE_CONFIG_REPO] Initialized $added default leave types for school: $schoolId');
      } else {
        print('ℹ️ [LEAVE_CONFIG_REPO] All default leave types already exist for school: $schoolId');
      }
    } catch (e) {
      throw Exception('Failed to initialize default leave types: $e');
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

  /// Validate leave type configuration
  void _validateLeaveTypeConfig(CreateLeaveTypeConfigRequest config) {
    if (config.annualQuota <= 0 || config.annualQuota > 365) {
      throw Exception('Annual quota must be between 1 and 365 days');
    }

    if (config.maxDaysPerRequest <= 0 || config.maxDaysPerRequest > config.annualQuota) {
      throw Exception('Max days per request must be between 1 and annual quota');
    }

    if (config.maxCarryForwardDays < 0 || config.maxCarryForwardDays > config.annualQuota) {
      throw Exception('Max carry forward days must be between 0 and annual quota');
    }

    if (!config.carryForwardAllowed && config.maxCarryForwardDays > 0) {
      throw Exception('Max carry forward days must be 0 when carry forward is not allowed');
    }

    if (config.code.trim().isEmpty || config.code.length > 20) {
      throw Exception('Leave type code must be between 1 and 20 characters');
    }

    if (config.name.trim().isEmpty || config.name.length > 100) {
      throw Exception('Leave type name must be between 1 and 100 characters');
    }
  }

  /// Validate leave type configuration update
  void _validateLeaveTypeConfigUpdate(LeaveTypeConfig config) {
    if (config.annualQuota <= 0 || config.annualQuota > 365) {
      throw Exception('Annual quota must be between 1 and 365 days');
    }

    if (config.maxDaysPerRequest <= 0 || config.maxDaysPerRequest > config.annualQuota) {
      throw Exception('Max days per request must be between 1 and annual quota');
    }

    if (config.maxCarryForwardDays < 0 || config.maxCarryForwardDays > config.annualQuota) {
      throw Exception('Max carry forward days must be between 0 and annual quota');
    }

    if (!config.carryForwardAllowed && config.maxCarryForwardDays > 0) {
      throw Exception('Max carry forward days must be 0 when carry forward is not allowed');
    }
  }

  /// Trigger balance quota update for all staff
  Future<void> _triggerBalanceQuotaUpdate(String schoolId, String leaveTypeId, int newQuota, String updatedBy) async {
    try {
      final leaveBalanceService = LeaveBalanceService(_firestore);
      await leaveBalanceService.updateLeaveTypeQuotaForAllStaff(
        schoolId: schoolId,
        leaveTypeId: leaveTypeId,
        newQuota: newQuota,
        updatedBy: updatedBy,
      );
      print('✅ [LEAVE_CONFIG_REPO] Quota updated for all staff balances');
    } catch (e) {
      print('⚠️ [LEAVE_CONFIG_REPO] Failed to update quota for staff balances: $e');
      // Non-blocking - quota update in config should still succeed
    }
  }

  /// Get default leave type configurations
  List<Map<String, dynamic>> _getDefaultLeaveTypeConfigs() {
    return [
      {
        'name': 'Casual Leave',
        'code': LeaveTypeCodes.casual,
        'description': 'General purpose casual leave for personal work',
        'annualQuota': 12,
        'carryForwardAllowed': true,
        'maxCarryForwardDays': 5,
        'maxDaysPerRequest': 3,
        'isPaid': true,
      },
      {
        'name': 'Sick Leave',
        'code': LeaveTypeCodes.sick,
        'description': 'Medical leave for illness or health issues',
        'annualQuota': 10,
        'carryForwardAllowed': false,
        'maxCarryForwardDays': 0,
        'maxDaysPerRequest': 7,
        'isPaid': true,
      },
      {
        'name': 'Earned Leave',
        'code': LeaveTypeCodes.earned,
        'description': 'Vacation leave earned through service',
        'annualQuota': 21,
        'carryForwardAllowed': true,
        'maxCarryForwardDays': 15,
        'maxDaysPerRequest': 15,
        'isPaid': true,
      },
      {
        'name': 'Emergency Leave',
        'code': LeaveTypeCodes.emergency,
        'description': 'Emergency leave for urgent personal matters',
        'annualQuota': 5,
        'carryForwardAllowed': false,
        'maxCarryForwardDays': 0,
        'maxDaysPerRequest': 2,
        'isPaid': false,
      },
    ];
  }
}

/// Providers
final leaveConfigurationRepositoryProvider = Provider<LeaveConfigurationRepository>((ref) {
  final firestore = FirebaseFirestore.instance;
  return LeaveConfigurationRepository(firestore);
});

/// Stream provider for school leave types
final schoolLeaveTypesProvider = StreamProvider.family<List<LeaveTypeConfig>, String>((ref, schoolId) {
  final repository = ref.watch(leaveConfigurationRepositoryProvider);
  return repository.getSchoolLeaveTypes(schoolId);
});

/// Stream provider for active school leave types
final activeSchoolLeaveTypesProvider = StreamProvider.family<List<LeaveTypeConfig>, String>((ref, schoolId) {
  final repository = ref.watch(leaveConfigurationRepositoryProvider);
  return repository.getActiveSchoolLeaveTypes(schoolId);
});

/// Provider for specific leave type configuration
final leaveTypeConfigProvider = FutureProvider.family<LeaveTypeConfig?, Map<String, String>>((ref, params) {
  final repository = ref.watch(leaveConfigurationRepositoryProvider);
  return repository.getLeaveTypeConfig(params['schoolId']!, params['leaveTypeId']!);
});
