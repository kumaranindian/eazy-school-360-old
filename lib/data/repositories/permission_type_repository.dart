import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:eazy_school_360/domain/entities/permission_type.dart';
import 'package:eazy_school_360/data/repositories/teacher_repository.dart';

class PermissionTypeRepository {
  final FirebaseFirestore _firestore;
  final TeacherRepository _teacherRepository;
  final Uuid _uuid = const Uuid();

  PermissionTypeRepository(this._firestore, this._teacherRepository);

  /// Get all active permission types for a school
  Stream<List<PermissionType>> getActivePermissionTypes(String schoolId) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('permissionTypes')
        .where('isActive', isEqualTo: true)
        .orderBy('name')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PermissionType.fromFirestore(doc))
            .toList());
  }

  /// Get all permission types (including inactive) for a school
  Stream<List<PermissionType>> getAllPermissionTypes(String schoolId) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('permissionTypes')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PermissionType.fromFirestore(doc))
            .toList());
  }

  /// Get permission type by ID
  Future<PermissionType?> getPermissionTypeById(String schoolId, String permissionTypeId) async {
    try {
      final doc = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('permissionTypes')
          .doc(permissionTypeId)
          .get();

      if (doc.exists) {
        return PermissionType.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get permission type: $e');
    }
  }

  /// Create new permission type and propagate to all teachers in school
  Future<PermissionType> createPermissionType(String schoolId, CreatePermissionTypeRequest request) async {
    try {
      // Check if name already exists in this school
      final existingPermissionType = await getPermissionTypeByName(schoolId, request.name);
      if (existingPermissionType != null) {
        throw Exception('Permission type with name "${request.name}" already exists');
      }

      final permissionTypeId = _uuid.v4();
      final now = DateTime.now();

      final permissionType = PermissionType(
        id: permissionTypeId,
        schoolId: schoolId,
        name: request.name,
        defaultLimit: request.defaultLimit,
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );

      // Create permission type document under school subcollection
      await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('permissionTypes')
          .doc(permissionTypeId)
          .set(permissionType.toFirestore());

      // Add this permission type to all existing active teachers
      await _teacherRepository.addPermissionLimitToAllTeachers(
        permissionTypeId,
        request.defaultLimit,
      );

      print('✅ [PERMISSION_TYPE_REPO] Created permission type: ${permissionType.name}');
      print('📊 [PERMISSION_TYPE_REPO] Propagated to all active teachers');

      return permissionType;
    } catch (e) {
      print('❌ [PERMISSION_TYPE_REPO] Error creating permission type: $e');
      throw Exception('Failed to create permission type: $e');
    }
  }

  /// Update permission type (master record only, does NOT affect existing teacher limits)
  Future<PermissionType> updatePermissionType(String schoolId, String permissionTypeId, UpdatePermissionTypeRequest request) async {
    try {
      final existingPermissionType = await getPermissionTypeById(schoolId, permissionTypeId);
      if (existingPermissionType == null) {
        throw Exception('Permission type not found');
      }

      // Check name uniqueness if name is being updated
      if (request.name != null && request.name != existingPermissionType.name) {
        final existingWithName = await getPermissionTypeByName(schoolId, request.name!);
        if (existingWithName != null) {
          throw Exception('Permission type with name "${request.name}" already exists');
        }
      }

      final updatedPermissionType = existingPermissionType.copyWith(
        name: request.name,
        defaultLimit: request.defaultLimit,
        isActive: request.isActive,
        updatedAt: DateTime.now(),
      );

      await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('permissionTypes')
          .doc(permissionTypeId)
          .update(updatedPermissionType.toFirestore());

      print('✅ [PERMISSION_TYPE_REPO] Updated permission type: ${updatedPermissionType.name}');
      print('ℹ️ [PERMISSION_TYPE_REPO] Note: Existing teacher limits were NOT modified');

      return updatedPermissionType;
    } catch (e) {
      print('❌ [PERMISSION_TYPE_REPO] Error updating permission type: $e');
      throw Exception('Failed to update permission type: $e');
    }
  }

  /// Soft delete permission type
  Future<void> deletePermissionType(String schoolId, String permissionTypeId) async {
    try {
      await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('permissionTypes')
          .doc(permissionTypeId)
          .update({
        'isActive': false,
        'updatedAt': Timestamp.now(),
      });

      print('✅ [PERMISSION_TYPE_REPO] Soft deleted permission type: $permissionTypeId');
      print('ℹ️ [PERMISSION_TYPE_REPO] Note: Teacher limits remain unchanged');
    } catch (e) {
      print('❌ [PERMISSION_TYPE_REPO] Error deleting permission type: $e');
      throw Exception('Failed to delete permission type: $e');
    }
  }

  /// Get permission type by name within a school
  Future<PermissionType?> getPermissionTypeByName(String schoolId, String name) async {
    try {
      final querySnapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('permissionTypes')
          .where('name', isEqualTo: name)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return PermissionType.fromFirestore(querySnapshot.docs.first);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get permission type by name: $e');
    }
  }

  /// Check if name is unique within a school
  Future<bool> isNameUnique(String schoolId, String name, {String? excludePermissionTypeId}) async {
    try {
      Query query = _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('permissionTypes')
          .where('name', isEqualTo: name);

      final querySnapshot = await query.get();

      if (excludePermissionTypeId != null) {
        return querySnapshot.docs
            .where((doc) => doc.id != excludePermissionTypeId)
            .isEmpty;
      }

      return querySnapshot.docs.isEmpty;
    } catch (e) {
      return false;
    }
  }
}

/// Providers
final permissionTypeRepositoryProvider = Provider<PermissionTypeRepository>((ref) {
  final firestore = FirebaseFirestore.instance;
  final teacherRepository = ref.watch(teacherRepositoryProvider);
  return PermissionTypeRepository(firestore, teacherRepository);
});

/// Stream provider for all permission types by school
final allPermissionTypesProvider = StreamProvider.family<List<PermissionType>, String>((ref, schoolId) {
  final repository = ref.watch(permissionTypeRepositoryProvider);
  return repository.getAllPermissionTypes(schoolId);
});

/// Stream provider for active permission types only by school
final activePermissionTypesProvider = StreamProvider.family<List<PermissionType>, String>((ref, schoolId) {
  final repository = ref.watch(permissionTypeRepositoryProvider);
  return repository.getActivePermissionTypes(schoolId);
});

/// Future provider for permission type by ID (requires schoolId and permissionTypeId)
final permissionTypeByIdProvider = FutureProvider.family<PermissionType?, Map<String, String>>((ref, params) {
  final repository = ref.watch(permissionTypeRepositoryProvider);
  return repository.getPermissionTypeById(params['schoolId']!, params['permissionTypeId']!);
});
