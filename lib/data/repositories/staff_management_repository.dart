import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eazy_school_360/domain/entities/staff_profile.dart';
import 'package:eazy_school_360/domain/entities/app_user.dart';
import 'package:eazy_school_360/config/environment_config.dart';
import 'package:eazy_school_360/data/services/leave_balance_service.dart';
import 'package:eazy_school_360/data/services/membership_service.dart';
import 'package:eazy_school_360/core/services/id_generator_service.dart';

class StaffManagementRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  // Secondary Auth instance used ONLY for creating new users,
  // so that the primary admin session (and its claims) stays active.
  FirebaseAuth? _secondaryAuth;

  StaffManagementRepository(this._firestore, this._auth);

  /// Get or initialize a secondary FirebaseAuth instance for user creation.
  /// This prevents the primary admin session from being replaced by the
  /// newly created teacher/admin user.
  Future<FirebaseAuth> _getSecondaryAuth() async {
    if (_secondaryAuth != null) return _secondaryAuth!;

    print('🔧 [STAFF_REPO] Initializing secondary auth with project: ${EnvironmentConfig.projectId}');
    
    // Try to reuse existing secondary app if it was initialized elsewhere
    FirebaseApp secondaryApp;
    try {
      secondaryApp = Firebase.app('admin-helper');
      print('✅ [STAFF_REPO] Reusing existing admin-helper app');
    } on FirebaseException {
      print('🔧 [STAFF_REPO] Creating new admin-helper app');
      secondaryApp = await Firebase.initializeApp(
        name: 'admin-helper',
        options: EnvironmentConfig.firebaseOptions,
      );
      print('✅ [STAFF_REPO] Secondary app created for project: ${EnvironmentConfig.projectId}');
    }

    _secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
    print('✅ [STAFF_REPO] Secondary auth instance ready');
    return _secondaryAuth!;
  }

  /// Get all staff for a specific school (Admin only)
  Stream<List<StaffProfile>> getSchoolStaff(String schoolId) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('staff')
        .orderBy('name')
        .limit(10000)
        .snapshots()
        .handleError((error) {
          print('❌ [STAFF_REPO] Error getting staff for school $schoolId: $error');
        })
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => StaffProfile.fromFirestore(doc))
              .toList();
        });
  }

  /// Get staff by user ID
  Future<StaffProfile?> getStaffByUserId(String schoolId, String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('staff')
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final staff = StaffProfile.fromFirestore(querySnapshot.docs.first);
        return staff;
      }
      
      return null;
    } catch (e) {
      print('❌ [STAFF_REPO] Error getting staff profile: $e');
      throw Exception('Failed to get staff profile: $e');
    }
  }

  /// Get staff by email
  Future<StaffProfile?> getStaffByEmail(String schoolId, String email) async {
    try {
      final querySnapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('staff')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final staff = StaffProfile.fromFirestore(querySnapshot.docs.first);
        return staff;
      }
      
      return null;
    } catch (e) {
      print('❌ [STAFF_REPO] Error getting staff by email: $e');
      throw Exception('Failed to get staff by email: $e');
    }
  }

  /// Check if employee ID is unique within school
  Future<bool> isEmployeeIdUnique(String schoolId, String employeeId, {String? excludeStaffId}) async {
    try {
      Query query = _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('staff')
          .where('employeeId', isEqualTo: employeeId);

      final querySnapshot = await query.get();
      
      if (excludeStaffId != null) {
        // When updating, exclude the current staff member
        return querySnapshot.docs.every((doc) => doc.id == excludeStaffId);
      }
      
      return querySnapshot.docs.isEmpty;
    } catch (e) {
      throw Exception('Failed to check employee ID uniqueness: $e');
    }
  }

  /// Create new staff member (Admin only)
  /// Returns a map with 'staffId' and 'employeeId'
  Future<Map<String, dynamic>> createStaff(
    String schoolId,
    String adminUserId,
    CreateStaffRequest request, {
    bool sendWelcomeEmail = true,
  }) async {
    print('🚀 [STAFF_REPO] createStaff called for email: ${request.email}');
    try {
      // Validate admin permissions
      await _validateAdminAccess(adminUserId, schoolId);
      print('✅ [STAFF_REPO] Admin validation done');

      print('📍 [STAFF_REPO] Step 2: Processing employee ID');
      // Auto-generate employee ID if not provided or empty
      String employeeId = request.employeeId;
      if (employeeId.isEmpty) {
        print('🔢 [STAFF_REPO] Auto-generating employee ID...');
        final idGenerator = IdGeneratorService(_firestore);
        employeeId = await idGenerator.generateStaffId(schoolId);
        print('✅ [STAFF_REPO] Auto-generated employee ID: $employeeId');
      } else {
        print('🔢 [STAFF_REPO] Checking employee ID uniqueness for: $employeeId');
        // Check employee ID uniqueness only if manually provided
        final isUnique = await isEmployeeIdUnique(schoolId, employeeId);
        if (!isUnique) {
          throw Exception('Employee ID $employeeId already exists in this school');
        }
        print('✅ [STAFF_REPO] Employee ID is unique');
      }

      print('📍 [STAFF_REPO] Step 3: Checking if email exists');
      // Check if email is already in use
      final existingUser = await _getUserByEmail(request.email);
      if (existingUser != null) {
        throw Exception('Email ${request.email} is already registered');
      }
      print('✅ [STAFF_REPO] Email is available');

      print('📍 [STAFF_REPO] Step 4: Creating Firebase Auth user');
      // Create Firebase Auth user using SECONDARY auth instance so we
      // don't sign out the current admin in the primary auth instance.
      // Use a random password that will be immediately reset
      final randomPassword = _generateRandomPassword();
      print('🔐 [STAFF_REPO] About to get secondary auth for ${request.email}');
      print('🔐 [STAFF_REPO] Current environment: ${EnvironmentConfig.environmentName}');
      print('🔐 [STAFF_REPO] Current project: ${EnvironmentConfig.projectId}');
      final secondaryAuth = await _getSecondaryAuth();
      print('✅ [STAFF_REPO] Got secondary auth instance');
      print('🔐 [STAFF_REPO] Creating auth user for ${request.email}');
      final userCredential = await secondaryAuth.createUserWithEmailAndPassword(
        email: request.email,
        password: randomPassword,
      );
      print('✅ [STAFF_REPO] Firebase Auth user created successfully for ${request.email}');
      print('✅ [STAFF_REPO] User ID: ${userCredential.user!.uid}');
      
      print('📍 [STAFF_REPO] Step 5: Signing out from secondary auth');
      // Sign out from secondary auth immediately
      await secondaryAuth.signOut();
      print('✅ [STAFF_REPO] Signed out from secondary auth');

      final userId = userCredential.user!.uid;
      print('📍 [STAFF_REPO] Step 6: Creating user document in Firestore');

      // Create user document in users collection
      final userData = AppUser(
        uid: userId,
        email: request.email,
        displayName: request.name,
        role: UserRole.STAFF,
        schoolId: schoolId,
        staffType: request.staffType,
        status: UserStatus.ACTIVE,
        onboardingStatus: OnboardingStatus.PENDING_ACTIVATION,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: adminUserId,
        profile: UserProfile(
          phoneNumber: request.phoneNumber,
          designation: request.designation,
          joiningDate: request.joiningDate,
          birthDate: request.birthDate,
          address: request.address != null ? {'street': request.address} : null,
          emergencyContact: request.emergencyContact != null
            ? {'name': request.emergencyContact} : null,
        ),
        permissions: UserPermissions.forRole(UserRole.STAFF),
      );

      final firestoreData = userData.toFirestore();
      print('🔍 [STAFF_REPO] User data to save: ${firestoreData.keys}');
      print('🔍 [STAFF_REPO] Role being saved: ${firestoreData['role']}');
      print('📝 [STAFF_REPO] Writing user document to Firestore...');
      await _firestore.collection('users').doc(userId).set(firestoreData);
      print('✅ [STAFF_REPO] User document created in Firestore for ${request.email}');

      print('📍 [STAFF_REPO] Step 7: Creating membership');
      // Get school name for membership
      try {
        print('🔍 [STAFF_REPO] Fetching school document...');
        final schoolDoc = await _firestore.collection('schools').doc(schoolId).get();
        final schoolName = schoolDoc.exists ? (schoolDoc.data()?['name'] as String? ?? 'Unknown School') : 'Unknown School';
        print('🔍 [STAFF_REPO] School name: $schoolName');

        // Create membership with STAFF role
        final membershipService = MembershipService(firestore: _firestore);
        print('🔍 [STAFF_REPO] Creating membership for userId: $userId, schoolId: $schoolId');
        await membershipService.upsertRoles(
          uid: userId,
          schoolId: schoolId,
          schoolName: schoolName,
          roles: const [UserRole.STAFF],
          ensureActive: true,
          createdBy: adminUserId,
        );
        print('✅ [STAFF_REPO] Membership created with UserRole.STAFF for ${request.email}');
      } catch (e) {
        print('❌ [STAFF_REPO] Failed to create membership: $e');
        throw Exception('Failed to create membership: $e');
      }

      print('📍 [STAFF_REPO] Step 8: Creating staff profile');
      // Create staff profile in school subcollection
      final staffProfile = StaffProfile(
        id: '', // Will be set by Firestore
        userId: userId,
        schoolId: schoolId,
        name: request.name,
        employeeId: employeeId, // Use auto-generated or provided employeeId
        email: request.email,
        staffType: request.staffType,
        status: UserStatus.ACTIVE,
        joiningDate: request.joiningDate,
        birthDate: request.birthDate,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: adminUserId,
        phoneNumber: request.phoneNumber,
        address: request.address,
        emergencyContact: request.emergencyContact,
        designation: request.designation,
      );

      print('📝 [STAFF_REPO] Writing staff profile to Firestore...');
      final docRef = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('staff')
          .add(staffProfile.toFirestore());
      print('✅ [STAFF_REPO] Staff profile created with ID: ${docRef.id}');

      print('📍 [STAFF_REPO] Step 9: Initializing leave balances');
      // Auto-assign leave balances for all active leave types
      try {
        final leaveBalanceService = LeaveBalanceService(_firestore);
        await leaveBalanceService.initializeLeaveBalancesForNewStaff(
          schoolId: schoolId,
          staffId: docRef.id,
          userId: userId,
          createdBy: adminUserId,
        );
        print('✅ [STAFF_REPO] Leave balances initialized for new staff: ${docRef.id}');
      } catch (e) {
        print('⚠️ [STAFF_REPO] Failed to initialize leave balances (non-blocking): $e');
        // Non-blocking - staff creation should still succeed even if leave balance init fails
      }

      print('📍 [STAFF_REPO] Step 10: Sending password reset email');
      // Send password reset email so user can set their own password
      if (sendWelcomeEmail) {
        await _sendPasswordResetEmail(request.email, request.name);
        print('✅ [STAFF_REPO] Password reset email sent');
      }

      print('🎉 [STAFF_REPO] Staff creation completed successfully!');

      return {
        'staffId': docRef.id,
        'employeeId': employeeId,
        'name': request.name,
        'email': request.email,
        'message': 'Password reset email sent to ${request.email}',
      };
    } catch (e, stackTrace) {
      print('❌ [STAFF_REPO] Error creating staff: $e');
      print('❌ [STAFF_REPO] Error type: ${e.runtimeType}');
      print('❌ [STAFF_REPO] Error toString: ${e.toString()}');
      
      // Try to extract more details from the error
      try {
        final errorObj = e as dynamic;
        print('❌ [STAFF_REPO] Error code: ${errorObj.code}');
        print('❌ [STAFF_REPO] Error message: ${errorObj.message}');
      } catch (_) {
        print('❌ [STAFF_REPO] Could not extract error details');
      }
      
      print('❌ [STAFF_REPO] Stack trace: $stackTrace');
      throw Exception('Failed to create staff member: $e');
    }
  }

  /// Update staff profile (Admin only)
  Future<void> updateStaff(String schoolId, String staffId, String adminUserId, UpdateStaffRequest request) async {
    try {
      // Validate admin permissions
      await _validateAdminAccess(adminUserId, schoolId);

      if (!request.hasChanges) {
        throw Exception('No changes to update');
      }

      final staffRef = _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('staff')
          .doc(staffId);

      final staffDoc = await staffRef.get();
      if (!staffDoc.exists) {
        throw Exception('Staff member not found');
      }

      final currentStaff = StaffProfile.fromFirestore(staffDoc);
      final updateData = request.toMap();

      // Update staff profile
      await staffRef.update(updateData);

      // If status changed, update user document as well
      if (request.status != null) {
        await _firestore.collection('users').doc(currentStaff.userId).update({
          'status': request.status!.name,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // If other profile fields changed, update user profile
      if (request.name != null || request.phoneNumber != null || request.birthDate != null) {
        final userUpdateData = <String, dynamic>{};
        if (request.name != null) {
          userUpdateData['displayName'] = request.name;
        }
        if (request.phoneNumber != null || request.birthDate != null) {
          final profileUpdates = <String, dynamic>{};
          if (request.phoneNumber != null) profileUpdates['phoneNumber'] = request.phoneNumber;
          if (request.birthDate != null) profileUpdates['birthDate'] = Timestamp.fromDate(request.birthDate!);
          userUpdateData['profile'] = profileUpdates;
        }
        userUpdateData['updatedAt'] = FieldValue.serverTimestamp();

        await _firestore.collection('users').doc(currentStaff.userId).update(userUpdateData);
      }
    } catch (e) {
      throw Exception('Failed to update staff member: $e');
    }
  }

  /// Enable/Disable staff member (Admin only)
  Future<void> toggleStaffStatus(String schoolId, String staffId, String adminUserId) async {
    try {
      // Validate admin permissions
      await _validateAdminAccess(adminUserId, schoolId);

      final staffRef = _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('staff')
          .doc(staffId);

      final staffDoc = await staffRef.get();
      if (!staffDoc.exists) {
        throw Exception('Staff member not found');
      }

      final currentStaff = StaffProfile.fromFirestore(staffDoc);
      final newStatus = currentStaff.status == UserStatus.ACTIVE 
          ? UserStatus.DISABLED 
          : UserStatus.ACTIVE;

      // Update staff profile
      await staffRef.update({
        'status': newStatus.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update user document
      await _firestore.collection('users').doc(currentStaff.userId).update({
        'status': newStatus.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to toggle staff status: $e');
    }
  }

  /// Delete staff member (Admin only) - Soft delete by disabling
  Future<void> deleteStaff(String schoolId, String staffId, String adminUserId) async {
    try {
      // Validate admin permissions
      await _validateAdminAccess(adminUserId, schoolId);

      final staffRef = _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('staff')
          .doc(staffId);

      final staffDoc = await staffRef.get();
      if (!staffDoc.exists) {
        throw Exception('Staff member not found');
      }

      final currentStaff = StaffProfile.fromFirestore(staffDoc);

      // Soft delete by disabling
      await staffRef.update({
        'status': UserStatus.DISABLED.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update user document
      await _firestore.collection('users').doc(currentStaff.userId).update({
        'status': UserStatus.DISABLED.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to delete staff member: $e');
    }
  }

  /// Create another admin (Admin only)
  /// Returns a map with 'staffId' and 'employeeId'
  Future<Map<String, String>> createAdmin(String schoolId, String adminUserId, CreateStaffRequest request) async {
    try {
      // Validate admin permissions
      await _validateAdminAccess(adminUserId, schoolId);

      // Auto-generate employee ID if not provided or empty
      String employeeId = request.employeeId;
      if (employeeId.isEmpty) {
        final idGenerator = IdGeneratorService(_firestore);
        employeeId = await idGenerator.generateStaffId(schoolId);
        print('✅ [STAFF_REPO] Auto-generated admin employee ID: $employeeId');
      }

      // Check if email is already in use
      final existingUser = await _getUserByEmail(request.email);
      if (existingUser != null) {
        throw Exception('Email ${request.email} is already registered');
      }

      // Create Firebase Auth user
      final tempPassword = _generateTemporaryPassword(
        email: request.email,
        phoneNumber: request.phoneNumber ?? '0000000000',
      );
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: request.email,
        password: tempPassword,
      );

      final userId = userCredential.user!.uid;

      // Create user document with ADMIN role
      final userData = AppUser(
        uid: userId,
        email: request.email,
        displayName: request.name,
        role: UserRole.ADMIN,
        schoolId: schoolId,
        staffType: request.staffType,
        status: UserStatus.ACTIVE,
        onboardingStatus: OnboardingStatus.PENDING_ACTIVATION,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: adminUserId,
        profile: UserProfile(
          phoneNumber: request.phoneNumber,
          designation: request.designation,
          joiningDate: request.joiningDate,
          birthDate: request.birthDate,
        ),
        permissions: UserPermissions.forRole(UserRole.ADMIN),
      );

      await _firestore.collection('users').doc(userId).set(userData.toFirestore());

      // Also create staff profile for consistency
      final staffProfile = StaffProfile(
        id: '',
        userId: userId,
        schoolId: schoolId,
        name: request.name,
        employeeId: employeeId,
        email: request.email,
        staffType: request.staffType,
        status: UserStatus.ACTIVE,
        joiningDate: request.joiningDate,
        birthDate: request.birthDate,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: adminUserId,
        phoneNumber: request.phoneNumber,
        address: request.address,
        emergencyContact: request.emergencyContact,
        designation: request.designation,
      );

      final docRef = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('staff')
          .add(staffProfile.toFirestore());

      // Send welcome email
      await _sendWelcomeEmail(request.email, request.name, tempPassword);

      return {
        'staffId': docRef.id,
        'employeeId': employeeId,
        'name': request.name,
        'email': request.email,
      };
    } catch (e) {
      throw Exception('Failed to create admin: $e');
    }
  }

  /// Create a Finance Admin user (Admin only).
  ///
  /// Multi-tenant behaviour:
  ///   * If the email is NEW → create a Firebase Auth user and write a
  ///     FINANCE membership at this school.
  ///   * If the email already belongs to ANY Firebase Auth user (in this
  ///     school or another) → DO NOT create a new Auth user. Reuse the
  ///     existing uid and simply attach a FINANCE membership. This covers:
  ///       - same user being granted FINANCE at a second school
  ///       - an existing STAFF member in this school being promoted to
  ///         STAFF+FINANCE (roles are merged, not replaced)
  Future<Map<String, String>> createFinanceUser(String schoolId, String adminUserId, CreateStaffRequest request) async {
    try {
      print('🔍 [STAFF_REPO] Creating finance user: ${request.email}');
      await _validateAdminAccess(adminUserId, schoolId);
      print('✅ [STAFF_REPO] Admin access validated');

      String employeeId = request.employeeId;
      if (employeeId.isEmpty) {
        final idGenerator = IdGeneratorService(_firestore);
        employeeId = await idGenerator.generateStaffId(schoolId);
      }

      // Fetch school name once — needed to populate the membership doc.
      String schoolName = '';
      try {
        final schoolDoc =
            await _firestore.collection('schools').doc(schoolId).get();
        final data = schoolDoc.data();
        if (data != null) {
          schoolName =
              (data['schoolName'] ?? data['name'] ?? '').toString();
        }
      } catch (_) {/* non-critical */}

      String userId;
      String? tempPassword;
      bool isNewAuthUser;
      print('🔍 [STAFF_REPO] Checking if user exists: ${request.email}');
      final existingUser = await _getUserByEmail(request.email);
      print('🔍 [STAFF_REPO] User exists: ${existingUser != null}');

      if (existingUser != null) {
        // Reuse the existing Firebase Auth account — no new credential is
        // created, no temp password is issued. The user keeps signing in
        // with their current email/password and gains FINANCE access.
        userId = existingUser.uid;
        isNewAuthUser = false;
        print('✅ [STAFF_REPO] Using existing user: ${existingUser.uid}');
      } else {
        tempPassword = _generateTemporaryPassword(
          email: request.email,
          phoneNumber: request.phoneNumber ?? '0000000000',
        );
        final secondaryAuth = await _getSecondaryAuth();
        final userCredential =
            await secondaryAuth.createUserWithEmailAndPassword(
          email: request.email,
          password: tempPassword,
        );
        userId = userCredential.user!.uid;
        isNewAuthUser = true;

        // Top-level user doc only for brand new users — we don't want to
        // overwrite an existing doc's role/schoolId here.
        final userData = AppUser(
          uid: userId,
          email: request.email,
          displayName: request.name,
          role: UserRole.FINANCE,
          schoolId: schoolId,
          staffType: request.staffType,
          status: UserStatus.ACTIVE,
          onboardingStatus: OnboardingStatus.PENDING_ACTIVATION,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          createdBy: adminUserId,
          profile: UserProfile(
            phoneNumber: request.phoneNumber,
            designation: request.designation,
            joiningDate: request.joiningDate,
            birthDate: request.birthDate,
          ),
          permissions: UserPermissions.forRole(UserRole.FINANCE),
        );
        await _firestore
            .collection('users')
            .doc(userId)
            .set(userData.toFirestore());
      }

      // Membership (authoritative per-school). upsertRoles merges the
      // FINANCE role into any existing memberships at this school so
      // STAFF + FINANCE etc. works cleanly.
      final membershipService = MembershipService(firestore: _firestore);
      await membershipService.upsertRoles(
        uid: userId,
        schoolId: schoolId,
        schoolName: schoolName,
        roles: const [UserRole.FINANCE],
        ensureActive: true,
        createdBy: adminUserId,
      );

      final staffProfile = StaffProfile(
        id: '',
        userId: userId,
        schoolId: schoolId,
        name: request.name,
        employeeId: employeeId,
        email: request.email,
        staffType: request.staffType,
        status: UserStatus.ACTIVE,
        joiningDate: request.joiningDate,
        birthDate: request.birthDate,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: adminUserId,
        phoneNumber: request.phoneNumber,
        address: request.address,
        emergencyContact: request.emergencyContact,
        designation: request.designation,
      );

      final docRef = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('staff')
          .add(staffProfile.toFirestore());

      if (isNewAuthUser && tempPassword != null) {
        await _sendWelcomeEmail(request.email, request.name, tempPassword);
      }

      return {
        'staffId': docRef.id,
        'employeeId': employeeId,
        'name': request.name,
        'email': request.email,
        'tempPassword': tempPassword ?? '',
        'reusedExistingAccount': existingUser != null ? 'true' : 'false',
      };
    } catch (e) {
      throw Exception('Failed to create finance user: $e');
    }
  }

  /// Validate admin access to school
  Future<void> _validateAdminAccess(String adminUserId, String schoolId) async {
    print('🔍 [STAFF_REPO] Validating admin access for user: $adminUserId, school: $schoolId');
    
    final adminDoc = await _firestore.collection('users').doc(adminUserId).get();
    print('🔍 [STAFF_REPO] Admin doc exists: ${adminDoc.exists}');
    
    if (!adminDoc.exists) {
      print('❌ [STAFF_REPO] Admin user document not found');
      throw Exception('Admin user not found');
    }

    final adminData = adminDoc.data()!;
    print('🔍 [STAFF_REPO] Admin doc data: $adminData');
    
    final userRole = adminData['role'];
    print('🔍 [STAFF_REPO] User role: $userRole');
    
    if (userRole != 'ADMIN' && userRole != 'tenant_admin') {
      print('❌ [STAFF_REPO] Insufficient permissions - role: $userRole');
      throw Exception('Insufficient permissions');
    }

    final userSchoolId = adminData['schoolId'];
    print('🔍 [STAFF_REPO] User school ID: $userSchoolId, Target school ID: $schoolId');
    
    if (userSchoolId != schoolId) {
      print('❌ [STAFF_REPO] School ID mismatch');
      throw Exception('Access denied to this school');
    }

    final userStatus = adminData['status'];
    final isActive = adminData['isActive'] == true;
    print('🔍 [STAFF_REPO] User status: $userStatus, isActive: $isActive');
    
    // Check both status (enum string) and isActive (boolean) for backward compatibility
    final isStatusActive = userStatus == 'ACTIVE' || userStatus == 'Active';
    if (!isStatusActive && !isActive) {
      print('❌ [STAFF_REPO] Admin account is not active (status: $userStatus, isActive: $isActive)');
      throw Exception('Admin account is not active');
    }
    
    print('✅ [STAFF_REPO] Admin access validation passed');
  }

  /// Get user by email - try multiple approaches
  Future<AppUser?> _getUserByEmail(String email) async {
    // Method 1: Try querying users collection first
    try {
      print('🔍 [STAFF_REPO] Querying users collection for email: $email');
      final querySnapshot = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      print('🔍 [STAFF_REPO] Query completed, found ${querySnapshot.docs.length} documents');
      if (querySnapshot.docs.isNotEmpty) {
        print('✅ [STAFF_REPO] User found: ${querySnapshot.docs.first.id}');
        return AppUser.fromFirestore(querySnapshot.docs.first);
      }
      print('ℹ️ [STAFF_REPO] No user found with email: $email');
      return null;
    } catch (e) {
      print('❌ [STAFF_REPO] Error querying user by email: $e');
      print('⚠️ [STAFF_REPO] Trying alternative method using Firebase Auth...');
      
      // Method 2: Try Firebase Auth to check if user exists
      try {
        // Since we can't easily check email existence, we'll proceed with creation
        // Firebase Auth will handle duplicate emails during createUserWithEmailAndPassword
        print('⚠️ [STAFF_REPO] Cannot query users collection due to permissions. Proceeding with creation.');
        print('ℹ️ [STAFF_REPO] Firebase Auth will handle duplicate email validation during user creation.');
        return null;
      } catch (authError) {
        print('❌ [STAFF_REPO] Alternative check failed: $authError');
        print('⚠️ [STAFF_REPO] Proceeding as if user does not exist. Firebase Auth will handle duplicates.');
        return null;
      }
    }
  }

  /// Generate random password for initial user creation (will be reset immediately)
  String _generateRandomPassword() {
    final random = Random.secure();
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$%^&*';
    return List.generate(16, (index) => chars[random.nextInt(chars.length)]).join();
  }

  /// Generate temporary password based on email and phone number
  String _generateTemporaryPassword({required String email, required String phoneNumber}) {
    // Extract email without domain (remove @ and everything after)
    final emailPart = email.split('@').first;
    // Extract last 5 digits of phone number (remove non-digits first)
    final phoneDigits = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    final last5Digits = phoneDigits.length >= 5 ? phoneDigits.substring(phoneDigits.length - 5) : phoneDigits.padLeft(5, '0');
    final password = '$emailPart$last5Digits';
    return password;
  }

  /// Send password reset email for new user activation
  Future<void> _sendPasswordResetEmail(String email, String name) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      print('✅ [STAFF_REPO] Password reset email sent to $email');
      print('📧 [STAFF_REPO] User $name can now set their password and activate their account');
    } catch (e) {
      print('❌ [STAFF_REPO] Failed to send password reset email to $email: $e');
      throw Exception('Failed to send password reset email: $e');
    }
  }

  /// Send welcome email using Firebase Auth password reset
  Future<void> _sendWelcomeEmail(String email, String name, String tempPassword) async {
    try {
      // Send password reset email so user can set their own password
      await _auth.sendPasswordResetEmail(email: email);
      print('✅ [STAFF_REPO] Password reset email sent to $email');
      print('📧 [STAFF_REPO] User can now set their own password via email link');
    } catch (e) {
      print('❌ [STAFF_REPO] Failed to send password reset email to $email: $e');
    }
  }
}

/// Providers
final staffManagementRepositoryProvider = Provider<StaffManagementRepository>((ref) {
  final firestore = FirebaseFirestore.instance;
  final auth = FirebaseAuth.instance;
  return StaffManagementRepository(firestore, auth);
});

/// Stream provider for school staff
final schoolStaffProvider = StreamProvider.family<List<StaffProfile>, String>((ref, schoolId) {
  final repository = ref.watch(staffManagementRepositoryProvider);
  return repository.getSchoolStaff(schoolId);
});

/// Provider for staff by user ID
final staffByUserIdProvider = FutureProvider.family.autoDispose<StaffProfile?, ({String schoolId, String userId})>((ref, params) {
  final repository = ref.watch(staffManagementRepositoryProvider);
  
  // Cache the result to prevent repeated calls
  ref.keepAlive();
  
  return repository.getStaffByUserId(params.schoolId, params.userId);
});
