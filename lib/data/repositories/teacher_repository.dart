import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:eazy_school_360/domain/entities/teacher.dart';

class TeacherRepository {
  final FirebaseFirestore _firestore;
  final Uuid _uuid = const Uuid();

  TeacherRepository(this._firestore);

  /// Get all active teachers for a school
  Stream<List<Teacher>> getActiveTeachers(String schoolId) {
    return _firestore
        .collection('teachers')
        .where('schoolId', isEqualTo: schoolId)
        .where('isActive', isEqualTo: true)
        .orderBy('name')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Teacher.fromFirestore(doc))
            .toList());
  }

  /// Get all teachers (including inactive) for a school
  Stream<List<Teacher>> getAllTeachers(String schoolId) {
    return _firestore
        .collection('teachers')
        .where('schoolId', isEqualTo: schoolId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Teacher.fromFirestore(doc))
            .toList());
  }

  /// Get teacher by ID
  Future<Teacher?> getTeacherById(String teacherId) async {
    try {
      final doc = await _firestore
          .collection('teachers')
          .doc(teacherId)
          .get();

      if (doc.exists) {
        return Teacher.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get teacher: $e');
    }
  }

  /// Get teacher by email within a school
  Future<Teacher?> getTeacherByEmail(String schoolId, String email) async {
    try {
      final querySnapshot = await _firestore
          .collection('teachers')
          .where('schoolId', isEqualTo: schoolId)
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return Teacher.fromFirestore(querySnapshot.docs.first);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get teacher by email: $e');
    }
  }

  /// Create new teacher with automatic balance initialization
  Future<Teacher> createTeacher(String schoolId, CreateTeacherRequest request) async {
    try {
      // Check if email already exists in this school
      final existingTeacher = await getTeacherByEmail(schoolId, request.email);
      if (existingTeacher != null) {
        throw Exception('Teacher with email ${request.email} already exists');
      }

      final teacherId = _uuid.v4();
      final now = DateTime.now();

      // Fetch all active leave types and permission types for this school
      final leaveTypesSnapshot = await _firestore
          .collection('leave_types')
          .where('schoolId', isEqualTo: schoolId)
          .where('isActive', isEqualTo: true)
          .get();

      final permissionTypesSnapshot = await _firestore
          .collection('permission_types')
          .where('schoolId', isEqualTo: schoolId)
          .where('isActive', isEqualTo: true)
          .get();

      // Initialize leave balances from leave types
      final Map<String, int> leaveBalances = {};
      for (final doc in leaveTypesSnapshot.docs) {
        final data = doc.data();
        final defaultBalance = (data['defaultBalance'] ?? 0) as int;
        leaveBalances[doc.id] = defaultBalance;
      }

      // Initialize permission limits from permission types
      final Map<String, int> permissionLimits = {};
      for (final doc in permissionTypesSnapshot.docs) {
        final data = doc.data();
        final defaultLimit = (data['defaultLimit'] ?? 0) as int;
        permissionLimits[doc.id] = defaultLimit;
      }

      final teacher = Teacher(
        teacherId: teacherId,
        schoolId: schoolId,
        name: request.name,
        email: request.email,
        phone: request.phone,
        role: request.role,
        isActive: true,
        createdAt: now,
        updatedAt: now,
        leaveBalances: leaveBalances,
        permissionLimits: permissionLimits,
      );

      await _firestore
          .collection('teachers')
          .doc(teacherId)
          .set(teacher.toFirestore());

      print('✅ [TEACHER_REPO] Created teacher: ${teacher.name} (${teacher.email})');
      print('📊 [TEACHER_REPO] Initialized ${leaveBalances.length} leave types and ${permissionLimits.length} permission types');

      return teacher;
    } catch (e) {
      print('❌ [TEACHER_REPO] Error creating teacher: $e');
      throw Exception('Failed to create teacher: $e');
    }
  }

  /// Update teacher
  Future<Teacher> updateTeacher(String teacherId, UpdateTeacherRequest request) async {
    try {
      final existingTeacher = await getTeacherById(teacherId);
      if (existingTeacher == null) {
        throw Exception('Teacher not found');
      }

      // Check email uniqueness if email is being updated
      if (request.email != null && request.email != existingTeacher.email) {
        final existingWithEmail = await getTeacherByEmail(existingTeacher.schoolId, request.email!);
        if (existingWithEmail != null) {
          throw Exception('Teacher with email ${request.email} already exists');
        }
      }

      final updatedTeacher = existingTeacher.copyWith(
        name: request.name,
        email: request.email,
        phone: request.phone,
        role: request.role,
        isActive: request.isActive,
        updatedAt: DateTime.now(),
      );

      await _firestore
          .collection('teachers')
          .doc(teacherId)
          .update(updatedTeacher.toFirestore());

      print('✅ [TEACHER_REPO] Updated teacher: ${updatedTeacher.name}');

      return updatedTeacher;
    } catch (e) {
      print('❌ [TEACHER_REPO] Error updating teacher: $e');
      throw Exception('Failed to update teacher: $e');
    }
  }

  /// Soft delete teacher
  Future<void> deleteTeacher(String teacherId) async {
    try {
      await _firestore
          .collection('teachers')
          .doc(teacherId)
          .update({
        'isActive': false,
        'updatedAt': Timestamp.now(),
      });

      print('✅ [TEACHER_REPO] Soft deleted teacher: $teacherId');
    } catch (e) {
      print('❌ [TEACHER_REPO] Error deleting teacher: $e');
      throw Exception('Failed to delete teacher: $e');
    }
  }

  /// Add leave balance to all active teachers in school (called when new leave type is created)
  Future<void> addLeaveBalanceToAllTeachers(String schoolId, String leaveTypeId, int defaultBalance) async {
    try {
      final teachersSnapshot = await _firestore
          .collection('teachers')
          .where('schoolId', isEqualTo: schoolId)
          .where('isActive', isEqualTo: true)
          .get();

      final batch = _firestore.batch();
      int batchCount = 0;

      for (final doc in teachersSnapshot.docs) {
        final teacherRef = _firestore.collection('teachers').doc(doc.id);
        
        batch.update(teacherRef, {
          'leaveBalances.$leaveTypeId': defaultBalance,
          'updatedAt': Timestamp.now(),
        });

        batchCount++;
        
        // Execute batch if we reach 500 operations (Firestore limit)
        if (batchCount >= 500) {
          await batch.commit();
          batchCount = 0;
        }
      }

      // Execute remaining operations
      if (batchCount > 0) {
        await batch.commit();
      }

      print('✅ [TEACHER_REPO] Added leave type $leaveTypeId to ${teachersSnapshot.docs.length} teachers');
    } catch (e) {
      print('❌ [TEACHER_REPO] Error adding leave balance to teachers: $e');
      throw Exception('Failed to add leave balance to teachers: $e');
    }
  }

  /// Add permission limit to all active teachers (called when new permission type is created)
  Future<void> addPermissionLimitToAllTeachers(String permissionTypeId, int defaultLimit) async {
    try {
      final teachersSnapshot = await _firestore
          .collection('teachers')
          .where('isActive', isEqualTo: true)
          .get();

      final batch = _firestore.batch();
      int batchCount = 0;

      for (final doc in teachersSnapshot.docs) {
        final teacherRef = _firestore.collection('teachers').doc(doc.id);
        
        batch.update(teacherRef, {
          'permissionLimits.$permissionTypeId': defaultLimit,
          'updatedAt': Timestamp.now(),
        });

        batchCount++;
        
        // Execute batch if we reach 500 operations (Firestore limit)
        if (batchCount >= 500) {
          await batch.commit();
          batchCount = 0;
        }
      }

      // Execute remaining operations
      if (batchCount > 0) {
        await batch.commit();
      }

      print('✅ [TEACHER_REPO] Added permission type $permissionTypeId to ${teachersSnapshot.docs.length} teachers');
    } catch (e) {
      print('❌ [TEACHER_REPO] Error adding permission limit to teachers: $e');
      throw Exception('Failed to add permission limit to teachers: $e');
    }
  }

  /// Check if email is unique
  Future<bool> isEmailUnique(String email, {String? excludeTeacherId}) async {
    try {
      Query query = _firestore
          .collection('teachers')
          .where('email', isEqualTo: email);

      final querySnapshot = await query.get();

      if (excludeTeacherId != null) {
        return querySnapshot.docs
            .where((doc) => doc.id != excludeTeacherId)
            .isEmpty;
      }

      return querySnapshot.docs.isEmpty;
    } catch (e) {
      return false;
    }
  }
}

/// Providers
final teacherRepositoryProvider = Provider<TeacherRepository>((ref) {
  final firestore = FirebaseFirestore.instance;
  return TeacherRepository(firestore);
});

/// Stream provider for all teachers by school
final allTeachersProvider = StreamProvider.family<List<Teacher>, String>((ref, schoolId) {
  final repository = ref.watch(teacherRepositoryProvider);
  return repository.getAllTeachers(schoolId);
});

/// Stream provider for active teachers only by school
final activeTeachersProvider = StreamProvider.family<List<Teacher>, String>((ref, schoolId) {
  final repository = ref.watch(teacherRepositoryProvider);
  return repository.getActiveTeachers(schoolId);
});

/// Future provider for teacher by ID
final teacherByIdProvider = FutureProvider.family<Teacher?, String>((ref, teacherId) {
  final repository = ref.watch(teacherRepositoryProvider);
  return repository.getTeacherById(teacherId);
});
