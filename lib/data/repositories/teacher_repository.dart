import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:eazy_school_360/domain/entities/teacher.dart';
import 'package:eazy_school_360/config/environment_config.dart';

class TeacherRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final Uuid _uuid = const Uuid();

  // Secondary Auth instance used ONLY for creating new users
  FirebaseAuth? _secondaryAuth;

  TeacherRepository(this._firestore, this._auth);

  /// Get or initialize a secondary FirebaseAuth instance for user creation
  Future<FirebaseAuth> _getSecondaryAuth() async {
    if (_secondaryAuth != null) return _secondaryAuth!;

    FirebaseApp secondaryApp;
    try {
      secondaryApp = Firebase.app('teacher-helper');
    } on FirebaseException {
      secondaryApp = await Firebase.initializeApp(
        name: 'teacher-helper',
        options: EnvironmentConfig.firebaseOptions,
      );
    }

    _secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
    return _secondaryAuth!;
  }

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

  /// Create new teacher with automatic balance initialization and Firebase Auth user creation
  Future<Map<String, dynamic>> createTeacher(String schoolId, CreateTeacherRequest request) async {
    try {
      // Check if email already exists in this school
      final existingTeacher = await getTeacherByEmail(schoolId, request.email);
      if (existingTeacher != null) {
        throw Exception('Teacher with email ${request.email} already exists');
      }

      final teacherId = _uuid.v4();
      final now = DateTime.now();
      String? tempPassword;
      bool isNewAuthUser = false;

      // Check if Firebase Auth user exists
      try {
        final userRecord = await _auth.createUserWithEmailAndPassword(
          email: request.email + '_check', // Temporary check
          password: 'temp123',
        );
        await userRecord.user?.delete(); // Clean up
      } catch (e) {
        // User already exists, which is what we want to check
      }
      
      // Try to create new Firebase Auth user
      tempPassword = _generateTemporaryPassword();
      final secondaryAuth = await _getSecondaryAuth();
      try {
        await secondaryAuth.createUserWithEmailAndPassword(
          email: request.email,
          password: tempPassword,
        );
        isNewAuthUser = true;
        print('✅ [TEACHER_REPO] Created Firebase Auth user: ${request.email}');
      } catch (e) {
        print('ℹ️ [TEACHER_REPO] Firebase Auth user already exists: ${request.email}');
        tempPassword = null;
      }

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

      // Send welcome email for new users
      if (isNewAuthUser && tempPassword != null) {
        await _sendWelcomeEmail(request.email, request.name, tempPassword);
      }

      return {
        'teacher': teacher,
        'tempPassword': tempPassword ?? '',
        'isNewAuthUser': isNewAuthUser,
      };
    } catch (e) {
      print('❌ [TEACHER_REPO] Error creating teacher: $e');
      throw Exception('Failed to create teacher: $e');
    }
  }

  /// Generate temporary password for new users
  String _generateTemporaryPassword() {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#';
    final random = DateTime.now().millisecondsSinceEpoch;
    return '${random.toString().substring(5)}@Teach';
  }

  /// Send welcome email with temporary password
  Future<void> _sendWelcomeEmail(String email, String name, String tempPassword) async {
    try {
      // Note: Implement email sending logic here
      // This would typically use Firebase Functions, SendGrid, or another email service
      print('📧 [TEACHER_REPO] Welcome email sent to: $email');

      // For now, just log the email details
      // In production, integrate with your email service
    } catch (e) {
      print('❌ [TEACHER_REPO] Error sending welcome email: $e');
      // Don't throw error - teacher creation should succeed even if email fails
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
          .collection('schools')
          .doc(schoolId)
          .collection('teachers')
          .where('isActive', isEqualTo: true)
          .get();

      final batch = _firestore.batch();
      int batchCount = 0;

      for (final doc in teachersSnapshot.docs) {
        final teacherRef = _firestore
            .collection('schools')
            .doc(schoolId)
            .collection('teachers')
            .doc(doc.id);
        
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
  Future<void> addPermissionLimitToAllTeachers(String schoolId, String permissionTypeId, int defaultLimit) async {
    try {
      final teachersSnapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('teachers')
          .where('isActive', isEqualTo: true)
          .get();

      final batch = _firestore.batch();
      int batchCount = 0;

      for (final doc in teachersSnapshot.docs) {
        final teacherRef = _firestore
            .collection('schools')
            .doc(schoolId)
            .collection('teachers')
            .doc(doc.id);
        
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
  final auth = FirebaseAuth.instance;
  return TeacherRepository(firestore, auth);
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
