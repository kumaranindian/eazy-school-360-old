import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:eazy_school_360/domain/entities/leave_type.dart';
import 'package:eazy_school_360/data/repositories/teacher_repository.dart';

class LeaveTypeRepository {
  final FirebaseFirestore _firestore;
  final TeacherRepository _teacherRepository;
  final Uuid _uuid = const Uuid();

  LeaveTypeRepository(this._firestore, this._teacherRepository);

  /// Get all active leave types for a school
  Stream<List<LeaveType>> getActiveLeaveTypes(String schoolId) {
    return _firestore
        .collection('leave_types')
        .where('schoolId', isEqualTo: schoolId)
        .where('isActive', isEqualTo: true)
        .orderBy('name')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => LeaveType.fromFirestore(doc))
            .toList());
  }

  /// Get all leave types (including inactive) for a school
  Stream<List<LeaveType>> getAllLeaveTypes(String schoolId) {
    return _firestore
        .collection('leave_types')
        .where('schoolId', isEqualTo: schoolId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => LeaveType.fromFirestore(doc))
            .toList());
  }

  /// Get leave type by ID
  Future<LeaveType?> getLeaveTypeById(String leaveTypeId) async {
    try {
      final doc = await _firestore
          .collection('leave_types')
          .doc(leaveTypeId)
          .get();

      if (doc.exists) {
        return LeaveType.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get leave type: $e');
    }
  }

  /// Create new leave type and propagate to all teachers in school
  Future<LeaveType> createLeaveType(String schoolId, CreateLeaveTypeRequest request) async {
    try {
      // Check if name already exists in this school
      final existingLeaveType = await getLeaveTypeByName(schoolId, request.name);
      if (existingLeaveType != null) {
        throw Exception('Leave type with name "${request.name}" already exists');
      }

      final leaveTypeId = _uuid.v4();
      final now = DateTime.now();

      final leaveType = LeaveType(
        id: leaveTypeId,
        schoolId: schoolId,
        name: request.name,
        defaultBalance: request.defaultBalance,
        isPaid: request.isPaid,
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );

      // Create leave type document
      await _firestore
          .collection('leave_types')
          .doc(leaveTypeId)
          .set(leaveType.toFirestore());

      // Add this leave type to all existing active teachers in this school
      await _teacherRepository.addLeaveBalanceToAllTeachers(schoolId, leaveTypeId, request.defaultBalance);

      print('✅ [LEAVE_TYPE_REPO] Created leave type: ${leaveType.name}');
      print('📊 [LEAVE_TYPE_REPO] Propagated to all active teachers');

      return leaveType;
    } catch (e) {
      print('❌ [LEAVE_TYPE_REPO] Error creating leave type: $e');
      throw Exception('Failed to create leave type: $e');
    }
  }

  /// Update leave type (master record only)
  Future<LeaveType> updateLeaveType(String schoolId, String leaveTypeId, UpdateLeaveTypeRequest request) async {
    try {
      final existingLeaveType = await getLeaveTypeById(leaveTypeId);
      if (existingLeaveType == null) {
        throw Exception('Leave type not found');
      }

      // Check name uniqueness if name is being updated
      if (request.name != null && request.name != existingLeaveType.name) {
        final existingWithName = await getLeaveTypeByName(schoolId, request.name!);
        if (existingWithName != null) {
          throw Exception('Leave type with name "${request.name}" already exists');
        }
      }

      final updatedLeaveType = existingLeaveType.copyWith(
        name: request.name,
        defaultBalance: request.defaultBalance,
        isPaid: request.isPaid,
        isActive: request.isActive,
        updatedAt: DateTime.now(),
      );

      await _firestore
          .collection('leave_types')
          .doc(leaveTypeId)
          .update(updatedLeaveType.toFirestore());

      print('✅ [LEAVE_TYPE_REPO] Updated leave type: ${updatedLeaveType.name}');
      print('ℹ️ [LEAVE_TYPE_REPO] Note: Existing teacher balances were NOT modified');

      return updatedLeaveType;
    } catch (e) {
      print('❌ [LEAVE_TYPE_REPO] Error updating leave type: $e');
      throw Exception('Failed to update leave type: $e');
    }
  }

  /// Soft delete leave type
  Future<void> deleteLeaveType(String leaveTypeId) async {
    try {
      await _firestore
          .collection('leave_types')
          .doc(leaveTypeId)
          .update({
        'isActive': false,
        'updatedAt': Timestamp.now(),
      });

      print('✅ [LEAVE_TYPE_REPO] Soft deleted leave type: $leaveTypeId');
      print('ℹ️ [LEAVE_TYPE_REPO] Note: Teacher balances remain unchanged');
    } catch (e) {
      print('❌ [LEAVE_TYPE_REPO] Error deleting leave type: $e');
      throw Exception('Failed to delete leave type: $e');
    }
  }

  /// Get leave type by name within a school
  Future<LeaveType?> getLeaveTypeByName(String schoolId, String name) async {
    try {
      final querySnapshot = await _firestore
          .collection('leave_types')
          .where('schoolId', isEqualTo: schoolId)
          .where('name', isEqualTo: name)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return LeaveType.fromFirestore(querySnapshot.docs.first);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get leave type by name: $e');
    }
  }

  /// Check if name is unique
  Future<bool> isNameUnique(String name, {String? excludeLeaveTypeId}) async {
    try {
      Query query = _firestore
          .collection('leave_types')
          .where('name', isEqualTo: name);

      final querySnapshot = await query.get();

      if (excludeLeaveTypeId != null) {
        return querySnapshot.docs
            .where((doc) => doc.id != excludeLeaveTypeId)
            .isEmpty;
      }

      return querySnapshot.docs.isEmpty;
    } catch (e) {
      return false;
    }
  }
}

/// Providers
final leaveTypeRepositoryProvider = Provider<LeaveTypeRepository>((ref) {
  final firestore = FirebaseFirestore.instance;
  final teacherRepository = ref.watch(teacherRepositoryProvider);
  return LeaveTypeRepository(firestore, teacherRepository);
});

/// Stream provider for all leave types by school
final allLeaveTypesProvider = StreamProvider.family<List<LeaveType>, String>((ref, schoolId) {
  final repository = ref.watch(leaveTypeRepositoryProvider);
  return repository.getAllLeaveTypes(schoolId);
});

/// Stream provider for active leave types only by school
final activeLeaveTypesProvider = StreamProvider.family<List<LeaveType>, String>((ref, schoolId) {
  final repository = ref.watch(leaveTypeRepositoryProvider);
  return repository.getActiveLeaveTypes(schoolId);
});

/// Future provider for leave type by ID
final leaveTypeByIdProvider = FutureProvider.family<LeaveType?, String>((ref, leaveTypeId) {
  final repository = ref.watch(leaveTypeRepositoryProvider);
  return repository.getLeaveTypeById(leaveTypeId);
});
