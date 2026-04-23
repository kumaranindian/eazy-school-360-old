import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eazy_school_360/domain/entities/staff_profile.dart';
import 'package:eazy_school_360/domain/entities/app_user.dart';
import 'package:eazy_school_360/firebase_options.dart';
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

    // Try to reuse existing secondary app if it was initialized elsewhere
    FirebaseApp secondaryApp;
    try {
      secondaryApp = Firebase.app('admin-helper');
    } on FirebaseException {
      secondaryApp = await Firebase.initializeApp(
        name: 'admin-helper',
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }

    _secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
    return _secondaryAuth!;
  }

  /// Get all staff for a specific school (Admin only)
  Stream<List<StaffProfile>> getSchoolStaff(String schoolId) {
    print('🔍 [STAFF_REPO] Getting staff for schoolId: $schoolId');
    print('🔍 [STAFF_REPO] Current user: ${_auth.currentUser?.uid}');
    print('🔍 [STAFF_REPO] User authenticated: ${_auth.currentUser != null}');
    print('🔍 [STAFF_REPO] Query path: schools/$schoolId/staff');
    print('🔍 [STAFF_REPO] Attempting to query staff collection...');
    
    // First, let's check if the school document exists and log its data
    _firestore.collection('schools').doc(schoolId).get().then((schoolDoc) {
      print('🔍 [STAFF_REPO] School doc exists: ${schoolDoc.exists}');
      if (schoolDoc.exists) {
        print('🔍 [STAFF_REPO] School doc data: ${schoolDoc.data()}');
      }
    }).catchError((error) {
      print('❌ [STAFF_REPO] Error checking school doc: $error');
    });
    
    // Let's also check if we can access the users collection for the current user
    if (_auth.currentUser != null) {
      _firestore.collection('users').doc(_auth.currentUser!.uid).get().then((userDoc) {
        print('🔍 [STAFF_REPO] Current user doc exists: ${userDoc.exists}');
        if (userDoc.exists) {
          final userData = userDoc.data()!;
          print('🔍 [STAFF_REPO] Current user doc data: $userData');
          print('🔍 [STAFF_REPO] User role: ${userData['role']}');
          print('🔍 [STAFF_REPO] User schoolId: ${userData['schoolId']}');
          print('🔍 [STAFF_REPO] User status: ${userData['status']}');
          print('🔍 [STAFF_REPO] User isActive: ${userData['isActive']}');
          
          // Check if this user should have admin access
          final role = userData['role'];
          final userSchoolId = userData['schoolId'];
          final isActive = userData['isActive'];
          final status = userData['status'];
          
          print('🔍 [STAFF_REPO] Role check - is admin: ${role == 'ADMIN' || role == 'tenant_admin'}');
          print('🔍 [STAFF_REPO] School match: ${userSchoolId == schoolId}');
          print('🔍 [STAFF_REPO] Active status: $isActive');
          print('🔍 [STAFF_REPO] User status: $status');
          
          // Fix the bug: if status is null but isActive is true, update the status field
          if (status == null && isActive == true) {
            print('🔧 [STAFF_REPO] FIXING BUG: User status is null but isActive is true. Updating status to ACTIVE...');
            _firestore.collection('users').doc(_auth.currentUser!.uid).update({
              'status': 'ACTIVE',
              'updatedAt': FieldValue.serverTimestamp(),
            }).then((_) {
              print('✅ [STAFF_REPO] User status updated to ACTIVE successfully');
              
              // Force refresh the Firebase Auth token to pick up the updated user document
              print('🔄 [STAFF_REPO] Refreshing Firebase Auth token...');
              return _auth.currentUser!.getIdToken(true);
            }).then((newToken) {
              print('✅ [STAFF_REPO] Firebase Auth token refreshed successfully');
              
              // Wait a moment for the token to propagate, then retry the test document
              Future.delayed(const Duration(seconds: 2), () {
                print('🔄 [STAFF_REPO] Retrying test document creation after token refresh...');
                _firestore.collection('schools').doc(schoolId).collection('staff').doc('test-doc-retry').set({
                  'test': true,
                  'retryAfterFix': true,
                  'timestamp': FieldValue.serverTimestamp(),
                }).then((_) {
                  print('✅ [STAFF_REPO] RETRY SUCCESS: Test document created after fixing status!');
                  // Clean up
                  _firestore.collection('schools').doc(schoolId).collection('staff').doc('test-doc-retry').delete();
                }).catchError((retryError) {
                  print('❌ [STAFF_REPO] RETRY FAILED: Still getting permission error after fix: $retryError');
                });
              });
            }).catchError((updateError) {
              print('❌ [STAFF_REPO] Error updating user status or refreshing token: $updateError');
            });
          }
        }
      }).catchError((error) {
        print('❌ [STAFF_REPO] Error checking current user doc: $error');
      });
    }
    
    // Try to create a test document to see if we have write permissions
    _firestore.collection('schools').doc(schoolId).collection('staff').doc('test-doc').set({
      'test': true,
      'timestamp': FieldValue.serverTimestamp(),
    }).then((_) {
      print('✅ [STAFF_REPO] Test document created successfully');
      // Clean up the test document
      _firestore.collection('schools').doc(schoolId).collection('staff').doc('test-doc').delete();
    }).catchError((error) {
      print('❌ [STAFF_REPO] Error with test document: $error');
      
      // Let's also check what the Firebase rules are actually seeing
      if (_auth.currentUser != null) {
        print('🔍 [STAFF_REPO] Checking Firebase Auth token claims...');
        _auth.currentUser!.getIdTokenResult().then((tokenResult) {
          print('🔍 [STAFF_REPO] Token claims: ${tokenResult.claims}');
          print('🔍 [STAFF_REPO] Token auth time: ${tokenResult.authTime}');
          print('🔍 [STAFF_REPO] Token issued at: ${tokenResult.issuedAtTime}');
        }).catchError((tokenError) {
          print('❌ [STAFF_REPO] Error getting token: $tokenError');
        });
      }
    });
    
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('staff')
        .orderBy('name')
        .snapshots()
        .handleError((error) {
          print('❌ [STAFF_REPO] Error getting staff: $error');
          print('❌ [STAFF_REPO] Error type: ${error.runtimeType}');
          if (error is FirebaseException) {
            print('❌ [STAFF_REPO] Error code: ${error.code}');
            print('❌ [STAFF_REPO] Error message: ${error.message}');
          }
          print('❌ [STAFF_REPO] User ID: ${_auth.currentUser?.uid}');
          print('❌ [STAFF_REPO] User email: ${_auth.currentUser?.email}');
          print('❌ [STAFF_REPO] School ID: $schoolId');
          print('❌ [STAFF_REPO] Full error: $error');
        })
        .map((snapshot) {
          print('✅ [STAFF_REPO] Successfully got ${snapshot.docs.length} staff members');
          for (var doc in snapshot.docs) {
            print('📄 [STAFF_REPO] Staff doc: ${doc.id}');
          }
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
  Future<Map<String, String>> createStaff(String schoolId, String adminUserId, CreateStaffRequest request) async {
    try {
      // Validate admin permissions
      await _validateAdminAccess(adminUserId, schoolId);

      // Auto-generate employee ID if not provided or empty
      String employeeId = request.employeeId;
      if (employeeId.isEmpty) {
        final idGenerator = IdGeneratorService(_firestore);
        employeeId = await idGenerator.generateStaffId(schoolId);
        print('✅ [STAFF_REPO] Auto-generated employee ID: $employeeId');
      } else {
        // Check employee ID uniqueness only if manually provided
        final isUnique = await isEmployeeIdUnique(schoolId, employeeId);
        if (!isUnique) {
          throw Exception('Employee ID $employeeId already exists in this school');
        }
      }

      // Check if email is already in use
      final existingUser = await _getUserByEmail(request.email);
      if (existingUser != null) {
        throw Exception('Email ${request.email} is already registered');
      }

      // Create Firebase Auth user using SECONDARY auth instance so we
      // don't sign out the current admin in the primary auth instance.
      final tempPassword = _generateTemporaryPassword();
      final secondaryAuth = await _getSecondaryAuth();
      final userCredential = await secondaryAuth.createUserWithEmailAndPassword(
        email: request.email,
        password: tempPassword,
      );

      final userId = userCredential.user!.uid;

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
          department: request.department,
          designation: request.designation,
          joiningDate: request.joiningDate,
          address: request.address != null ? {'street': request.address} : null,
          emergencyContact: request.emergencyContact != null 
            ? {'name': request.emergencyContact} : null,
        ),
        permissions: UserPermissions.forRole(UserRole.STAFF),
      );

      await _firestore.collection('users').doc(userId).set(userData.toFirestore());

      // Create staff profile in school subcollection
      final staffProfile = StaffProfile(
        id: '', // Will be set by Firestore
        userId: userId,
        schoolId: schoolId,
        name: request.name,
        employeeId: employeeId, // Use auto-generated or provided employeeId
        email: request.email,
        department: request.department,
        staffType: request.staffType,
        status: UserStatus.ACTIVE,
        joiningDate: request.joiningDate,
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

      // Send welcome email (implement separately)
      await _sendWelcomeEmail(request.email, request.name, tempPassword);

      return {
        'staffId': docRef.id,
        'employeeId': employeeId,
        'name': request.name,
        'email': request.email,
      };
    } catch (e) {
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
      if (request.name != null || request.department != null || request.phoneNumber != null) {
        final userUpdateData = <String, dynamic>{};
        if (request.name != null) {
          userUpdateData['displayName'] = request.name;
        }
        if (request.department != null || request.phoneNumber != null) {
          final profileUpdates = <String, dynamic>{};
          if (request.department != null) profileUpdates['department'] = request.department;
          if (request.phoneNumber != null) profileUpdates['phoneNumber'] = request.phoneNumber;
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
      final tempPassword = _generateTemporaryPassword();
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
          department: request.department,
          designation: request.designation,
          joiningDate: request.joiningDate,
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
        department: request.department,
        staffType: request.staffType,
        status: UserStatus.ACTIVE,
        joiningDate: request.joiningDate,
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
        tempPassword = _generateTemporaryPassword();
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
            department: request.department,
            designation: request.designation,
            joiningDate: request.joiningDate,
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
        department: request.department,
        staffType: request.staffType,
        status: UserStatus.ACTIVE,
        joiningDate: request.joiningDate,
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
    print('🔍 [STAFF_REPO] User status: $userStatus');
    
    // UserStatus is stored as enum string, check against ACTIVE
    if (userStatus != 'ACTIVE' && userStatus != 'Active') {
      print('❌ [STAFF_REPO] Admin account is not active');
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

  /// Generate temporary password
  String _generateTemporaryPassword() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final random = DateTime.now().millisecondsSinceEpoch;
    return 'Temp${random.toString().substring(8)}!';
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
      // Fallback: just log the temp password
      print('🔑 [STAFF_REPO] Temporary password for $email: $tempPassword');
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
