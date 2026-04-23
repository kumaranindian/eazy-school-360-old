import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/entities/membership.dart';
import '../../domain/entities/school.dart';
import '../services/membership_service.dart';

/// Result class for login operation containing user details and status
class LoginResult {
  final UserCredential userCredential;
  final UserRole role;
  final bool isActive;
  final String? schoolId;
  final String displayName;
  final String message;

  /// All active memberships for this user. Empty for legacy single-school
  /// users (back-compat: callers fall back to [schoolId]).
  final List<Membership> memberships;

  /// True when the user has more than one active membership and the caller
  /// should route to the School Chooser screen before showing a dashboard.
  bool get requiresSchoolSelection => memberships.length > 1;

  LoginResult({
    required this.userCredential,
    required this.role,
    required this.isActive,
    this.schoolId,
    required this.displayName,
    required this.message,
    this.memberships = const [],
  });
  
  /// Check if user can access the dashboard
  bool get canAccessDashboard => isActive;
  
  /// Check if user needs to wait for activation
  bool get needsActivation => !isActive;
}

/// Raised by [AuthRepository.signUpWithEmailAndPassword] when the email
/// is already registered. Callers should catch this and prompt the user
/// for their existing password so they can add the new school to their
/// existing Firebase Auth account via [signUpAdditionalSchool].
class EmailAlreadyRegisteredException implements Exception {
  final String email;
  EmailAlreadyRegisteredException(this.email);
  @override
  String toString() =>
      'Email "$email" is already registered. Sign in to add a new school.';
}

/// Raised by the signup flow when a school with the same name (case-insensitive,
/// trimmed) already exists. This is the very first check performed during
/// school creation so we never create duplicate tenants.
class SchoolNameAlreadyExistsException implements Exception {
  final String schoolName;
  SchoolNameAlreadyExistsException(this.schoolName);
  @override
  String toString() =>
      'A school named "$schoolName" is already registered. '
      'Please choose a different name.';
}

/// Result returned by the signup flows so the UI can kick off per-tenant
/// provisioning (seeding subcollections, verifying indexes, etc.) before
/// navigating away.
class SignupResult {
  final UserCredential credential;
  final String schoolId;
  final String uid;
  const SignupResult({
    required this.credential,
    required this.schoolId,
    required this.uid,
  });
}

class AuthRepository {
  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;
  final MembershipService _membershipService;

  AuthRepository({
    required FirebaseAuth firebaseAuth,
    required FirebaseFirestore firestore,
    MembershipService? membershipService,
  })  : _firebaseAuth = firebaseAuth,
        _firestore = firestore,
        _membershipService =
            membershipService ?? MembershipService(firestore: firestore);

  /// Public accessor so [AuthNotifier] / other callers can read memberships
  /// without re-instantiating the service.
  MembershipService get membershipService => _membershipService;

  // Get current user
  User? get currentUser => _firebaseAuth.currentUser;

  // Stream of auth state changes
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  // Sign in with email and password
  // Returns a LoginResult with user details and status
  Future<LoginResult> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      print('Attempting login for: $email');
      
      // 1. Authenticate with Firebase Auth
      final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      print('Firebase Auth successful for user: ${userCredential.user?.uid}');
      
      if (userCredential.user == null) {
        throw Exception('Login failed. Please try again.');
      }
      
      // 2. Get user details from Firestore
      print('Fetching user details from Firestore...');
      final userDoc = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userCredential.user!.uid)
          .get();
      
      if (!userDoc.exists) {
        print('User document not found in Firestore');
        // Sign out the user since they don't have a proper account setup
        await _firebaseAuth.signOut();
        throw Exception('Account not found. Please contact support or register again.');
      }
      
      final userData = userDoc.data()!;
      print('User data retrieved: role=${userData['role']}, isActive=${userData['isActive']}');
      
      // 3. Parse user role
      final String roleString = (userData['role'] as String?) ?? '';
      final UserRole role = _parseRole(roleString);
      final bool isActive = (userData['isActive'] as bool?) ?? false;
      final String? schoolId = userData['schoolId'] as String?;
      final String displayName = (userData['displayName'] as String?) ?? email.split('@').first;

      print('Parsed role: $role, isActive: $isActive, schoolId: $schoolId');

      // 3b. Load all memberships for this uid.
      //
      // Multi-tenant model: one Firebase Auth account → many schools, each
      // with >=1 roles. If the user has no membership docs yet (legacy)
      // we synthesise one from `users/{uid}.schoolId/role` so existing
      // accounts keep working while the migration runs.
      final memberships = await _loadMembershipsWithLegacyFallback(
        uid: userCredential.user!.uid,
        legacySchoolId: schoolId,
        legacyRole: role,
        isActive: isActive,
      );
      print('Loaded ${memberships.length} membership(s) for user');

      // 4. Check activation status based on role
      if (role == UserRole.SUPER_ADMIN) {
        // Super admin is always active
        return LoginResult(
          userCredential: userCredential,
          role: role,
          isActive: true,
          schoolId: null,
          displayName: displayName,
          message: 'Welcome back, Super Admin!',
          memberships: memberships,
        );
      }
      
      // For tenant admin and teacher, check if account is active
      if (!isActive) {
        print('Account is not active');
        return LoginResult(
          userCredential: userCredential,
          role: role,
          isActive: false,
          schoolId: schoolId,
          displayName: displayName,
          message: 'Your account is pending activation. Please contact the administrator.',
          memberships: memberships,
        );
      }
      
      // 5. For tenant admin, also check if school is active
      if (role == UserRole.ADMIN && schoolId != null) {
        print('Checking school activation status...');
        final schoolDoc = await _firestore
            .collection(AppConstants.schoolsCollection)
            .doc(schoolId)
            .get();
        
        if (!schoolDoc.exists) {
          await _firebaseAuth.signOut();
          throw Exception('School not found. Please contact support.');
        }
        
        final schoolData = schoolDoc.data()!;
        final bool schoolIsActive = (schoolData['isActive'] as bool?) ?? false;
        
        if (!schoolIsActive) {
          print('School is not active');
          return LoginResult(
            userCredential: userCredential,
            role: role,
            isActive: false,
            schoolId: schoolId,
            displayName: displayName,
            message: 'Your school account is pending activation. Please contact the administrator.',
          );
        }
      }
      
      // 6. For teacher, check school activation as well
      if (role == UserRole.STAFF && schoolId != null) {
        print('Checking school activation status for teacher...');
        final schoolDoc = await _firestore
            .collection(AppConstants.schoolsCollection)
            .doc(schoolId)
            .get();
        
        if (!schoolDoc.exists) {
          await _firebaseAuth.signOut();
          throw Exception('School not found. Please contact your administrator.');
        }
        
        final schoolData = schoolDoc.data()!;
        final bool schoolIsActive = (schoolData['isActive'] as bool?) ?? false;
        
        if (!schoolIsActive) {
          print('School is not active for teacher');
          return LoginResult(
            userCredential: userCredential,
            role: role,
            isActive: false,
            schoolId: schoolId,
            displayName: displayName,
            message: 'Your school is currently inactive. Please contact your administrator.',
          );
        }
      }
      
      // 7. All checks passed - return success
      String welcomeMessage;
      switch (role) {
        case UserRole.ADMIN:
          welcomeMessage = 'Welcome back, $displayName!';
          break;
        case UserRole.STAFF:
          welcomeMessage = 'Welcome back, $displayName!';
          break;
        default:
          welcomeMessage = 'Login successful!';
      }
      
      print('Login successful: $welcomeMessage');
      return LoginResult(
        userCredential: userCredential,
        role: role,
        isActive: true,
        schoolId: schoolId,
        displayName: displayName,
        message: welcomeMessage,
        memberships: memberships,
      );
      
    } on FirebaseAuthException catch (e) {
      print('FirebaseAuthException: ${e.code} - ${e.message}');
      throw _handleAuthException(e);
    } catch (e) {
      print('Login error: $e');
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Login failed: ${e.toString()}');
    }
  }
  
  // Helper method to parse role string to UserRole enum
  UserRole _parseRole(String roleString) {
    switch (roleString.toLowerCase()) {
      case 'super_admin':
      case 'superadmin':
        return UserRole.SUPER_ADMIN;
      case 'admin':
      case 'tenant_admin':
      case 'tenantadmin':
        return UserRole.ADMIN;
      case 'finance':
      case 'user':
      case 'accounts':
        return UserRole.FINANCE;
      case 'staff':
      case 'teacher':
        return UserRole.STAFF;
      default:
        return UserRole.STAFF;
    }
  }

  // Sign up with email and password (for tenant admin).
  //
  // Multi-tenant behaviour:
  //   * If the email is NEW to Firebase Auth, a brand-new Auth account is
  //     created + a school + an ADMIN membership are written.
  //   * If the email ALREADY belongs to a Firebase Auth account we throw
  //     [EmailAlreadyRegisteredException] so the UI can prompt the user for
  //     their existing password and call [signUpAdditionalSchool] to attach
  //     the new school to their existing uid (one email → many schools).
  /// Ensures no existing school doc matches [schoolName] (case-insensitive,
  /// trimmed). Throws [SchoolNameAlreadyExistsException] if a match is found.
  /// This is intentionally the very first check in the school creation flow
  /// so we never create duplicate tenants (or orphaned auth users because of
  /// downstream failures).
  Future<void> _assertSchoolNameAvailable(String schoolName) async {
    final trimmed = schoolName.trim();
    if (trimmed.isEmpty) return;
    final lower = trimmed.toLowerCase();

    // Query each field independently so a single read failure (missing
    // index, permission denied, empty collection) only disables THAT lookup
    // instead of the whole check. We only throw when we actually find a
    // duplicate. If the collection doesn't exist yet, all queries return
    // empty and we allow the signup to proceed.
    Future<bool> _hasMatch(String field, String value) async {
      try {
        final snap = await _firestore
            .collection(AppConstants.schoolsCollection)
            .where(field, isEqualTo: value)
            .limit(1)
            .get();
        return snap.docs.isNotEmpty;
      } catch (e) {
        // Missing collection / index / rule denial -> treat as "no match".
        // Duplicate detection is best-effort; unique-constraint enforcement
        // should happen server-side (security rules / cloud function) for
        // guaranteed safety.
        print('School-name lookup on "$field" skipped: $e');
        return false;
      }
    }

    if (await _hasMatch('schoolNameLower', lower) ||
        await _hasMatch('schoolName', trimmed) ||
        await _hasMatch('name', trimmed)) {
      throw SchoolNameAlreadyExistsException(trimmed);
    }
  }

  Future<SignupResult> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String schoolName,
    required String schoolAddress,
    required String schoolPhone,
    String? schoolWebsite,
    String? adminName,
  }) async {
    UserCredential? userCredential;
    try {
      // 1. Create user in Firebase Auth
      print('Attempting to create user with email: $email');
      userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      print('User created successfully: ${userCredential.user?.uid}');

      // 2. FIRST check of the school-creation flow: ensure no school with
      //    the same name already exists. If there is one, roll back the
      //    auth user we just created so nothing is left orphaned.
      try {
        await _assertSchoolNameAvailable(schoolName);
      } catch (e) {
        try {
          await userCredential.user?.delete();
        } catch (_) {/* best-effort rollback */}
        rethrow;
      }

      String schoolId;
      try {
        schoolId = await _createSchoolAndAdminDocs(
          uid: userCredential.user!.uid,
          email: email,
          displayName: adminName ?? email.split('@').first,
          schoolName: schoolName,
          schoolAddress: schoolAddress,
          schoolPhone: schoolPhone,
          schoolWebsite: schoolWebsite,
          isFirstAccount: true,
        );
      } catch (firestoreError) {
        // If Firestore operations fail, delete the created user to maintain consistency
        print('Error in Firestore operations: $firestoreError');
        if (userCredential.user != null) {
          print('Deleting user due to Firestore error');
          await userCredential.user!.delete();
        }
        throw Exception('Failed to create school records: ${firestoreError.toString()}');
      }

      return SignupResult(
        credential: userCredential,
        schoolId: schoolId,
        uid: userCredential.user!.uid,
      );
    } on FirebaseAuthException catch (e) {
      // The common "email-already-in-use" case needs special handling so
      // the UI can pivot into the "add new school to my existing account"
      // flow. Everything else goes through the shared error translator.
      if (e.code == 'email-already-in-use') {
        throw EmailAlreadyRegisteredException(email);
      }
      print('FirebaseAuthException in signup: ${e.code} - ${e.message}');
      throw _handleAuthException(e);
    } catch (e) {
      print('Error in signup process: $e');
      throw _handleAuthException(e);
    }
  }

  /// Adds a NEW school to an EXISTING Firebase Auth account.
  ///
  /// Flow on the UI side:
  ///   1. User enters email + password on the signup form.
  ///   2. [signUpWithEmailAndPassword] throws [EmailAlreadyRegisteredException].
  ///   3. UI re-prompts (or reuses the password) and calls this method.
  ///
  /// This is what enables "one email → multiple schools". The user stays on
  /// the same uid, we just add another school + membership.
  Future<SignupResult> signUpAdditionalSchool({
    required String email,
    required String password,
    required String schoolName,
    required String schoolAddress,
    required String schoolPhone,
    String? schoolWebsite,
    String? adminName,
  }) async {
    try {
      // 1. Authenticate with the existing credentials so we operate as the
      //    correct uid and prove ownership of the email.
      final cred = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (cred.user == null) {
        throw Exception('Failed to verify existing account.');
      }

      // 2. FIRST check of the school-creation flow: ensure no school with
      //    the same name already exists anywhere in the system.
      await _assertSchoolNameAvailable(schoolName);

      // 3. Reuse the existing display name when the caller didn't supply one.
      String displayName = adminName ?? '';
      if (displayName.isEmpty) {
        try {
          final existingUser = await _firestore
              .collection(AppConstants.usersCollection)
              .doc(cred.user!.uid)
              .get();
          displayName =
              (existingUser.data()?['displayName'] as String?) ?? email.split('@').first;
        } catch (_) {
          displayName = email.split('@').first;
        }
      }

      final schoolId = await _createSchoolAndAdminDocs(
        uid: cred.user!.uid,
        email: email,
        displayName: displayName,
        schoolName: schoolName,
        schoolAddress: schoolAddress,
        schoolPhone: schoolPhone,
        schoolWebsite: schoolWebsite,
        // Existing user: don't clobber their users/{uid}.role — an ADMIN at
        // one school can still be STAFF at another. Membership docs carry the
        // authoritative per-school role.
        isFirstAccount: false,
      );
      return SignupResult(
        credential: cred,
        schoolId: schoolId,
        uid: cred.user!.uid,
      );
    } on FirebaseAuthException catch (e) {
      print('FirebaseAuthException in signUpAdditionalSchool: ${e.code}');
      throw _handleAuthException(e);
    } catch (e) {
      print('Error adding additional school: $e');
      rethrow;
    }
  }

  /// Shared writer used by both the new-account and the additional-school
  /// signup paths. Creates the school doc, admin profile subdoc, users/{uid}
  /// stub (when absent) and the ADMIN membership doc.
  Future<String> _createSchoolAndAdminDocs({
    required String uid,
    required String email,
    required String displayName,
    required String schoolName,
    required String schoolAddress,
    required String schoolPhone,
    String? schoolWebsite,
    required bool isFirstAccount,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final Map<String, dynamic> schoolData = {
      'name': schoolName,
      'schoolName': schoolName,
      'schoolNameLower': schoolName.trim().toLowerCase(),
      'address': schoolAddress,
      'email': email,
      'phone': schoolPhone,
      'website': schoolWebsite ?? '',
      'logoUrl': '',
      'isActive': false, // Default inactive until approved by super admin
      'createdAt': timestamp,
      'updatedAt': timestamp,
      'createdBy': uid,
      'settings': {},
    };

    print('Creating school document for: $schoolName');
    final schoolDoc =
        await _firestore.collection(AppConstants.schoolsCollection).add(schoolData);
    final schoolId = schoolDoc.id;
    print('School document created with ID: $schoolId');

    // Admin profile subdoc (per-school).
    final Map<String, dynamic> adminData = {
      'email': email,
      'displayName': displayName,
      'role': AppConstants.tenantAdminRole,
      'schoolId': schoolId,
      'isActive': false,
      'createdAt': timestamp,
      'updatedAt': timestamp,
    };
    await _firestore
        .collection(AppConstants.schoolsCollection)
        .doc(schoolId)
        .collection(AppConstants.adminUsersCollection)
        .doc(uid)
        .set(adminData);

    // users/{uid} — top-level profile.
    //
    // * First-time accounts get a fresh doc that mirrors legacy shape
    //   (role/schoolId) so existing single-school code keeps working until
    //   the whole stack is migrated to membership-based checks.
    // * Additional schools DO NOT overwrite the existing users/{uid} doc —
    //   that would forcibly switch the user's default school. We only set
    //   missing fields (MERGE) so the record stays intact.
    if (isFirstAccount) {
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(uid)
          .set({
        'email': email,
        'displayName': displayName,
        'role': AppConstants.tenantAdminRole,
        'schoolId': schoolId,
        'defaultSchoolId': schoolId,
        'isActive': false,
        'createdAt': timestamp,
        'updatedAt': timestamp,
        'customClaims': {
          'role': AppConstants.tenantAdminRole,
          'schoolId': schoolId,
          'isActive': false,
        },
      });
    } else {
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(uid)
          .set({
        'email': email,
        if (displayName.isNotEmpty) 'displayName': displayName,
        'updatedAt': timestamp,
      }, SetOptions(merge: true));
    }

    // Membership doc — the authoritative per-school record.
    await _membershipService.upsertRoles(
      uid: uid,
      schoolId: schoolId,
      schoolName: schoolName,
      roles: const [UserRole.ADMIN],
      isOwner: true,
      ensureActive: false, // membership is inactive until school is approved
      schoolIsActive: false, // school itself is pending super-admin approval
      createdBy: uid,
    );

    print('All signup documents (incl. membership) created successfully');
    return schoolId;
  }

  /// Loads memberships for [uid] and, when none exist yet (legacy users),
  /// synthesises ONE in-memory membership from the top-level users/{uid}
  /// doc so downstream code uniformly sees a List<Membership>.
  ///
  /// Also opportunistically persists the synthesised membership so the
  /// next login has real data. Safe to call on every login — idempotent.
  Future<List<Membership>> _loadMembershipsWithLegacyFallback({
    required String uid,
    required String? legacySchoolId,
    required UserRole legacyRole,
    required bool isActive,
  }) async {
    final memberships = await _membershipService.listForUser(uid);
    if (memberships.isNotEmpty) return memberships;

    if (legacySchoolId == null || legacySchoolId.isEmpty) {
      return const [];
    }

    // Legacy single-school user: backfill a membership so the rest of the
    // app gets the richer shape. We keep the fields conservative — real
    // data (schoolName etc.) is filled in when the user visits the school.
    String schoolName = '';
    bool schoolIsActive = true;
    try {
      final schoolDoc = await _firestore
          .collection(AppConstants.schoolsCollection)
          .doc(legacySchoolId)
          .get();
      final data = schoolDoc.data();
      if (data != null) {
        schoolName =
            (data['schoolName'] ?? data['name'] ?? '').toString();
        schoolIsActive = data['isActive'] as bool? ?? true;
      }
    } catch (_) {/* non-critical */}

    final membership = await _membershipService.upsertRoles(
      uid: uid,
      schoolId: legacySchoolId,
      schoolName: schoolName,
      roles: [legacyRole == UserRole.NONE ? UserRole.STAFF : legacyRole],
      isOwner: legacyRole == UserRole.ADMIN,
      ensureActive: isActive,
      schoolIsActive: schoolIsActive,
    );
    return [membership];
  }

  /// Admin operation: grant an additional role to an EXISTING user at a
  /// specific school. Used when an admin adds e.g. FINANCE role to someone
  /// who is already STAFF at the same school (or to a user whose email is
  /// already registered at another school — no new Auth user is created).
  ///
  /// [targetUid] is the uid to grant the role to; if the email belongs to
  /// an existing user, callers should resolve it via [findUidByEmail] first.
  Future<void> addRoleToUser({
    required String targetUid,
    required String schoolId,
    required String schoolName,
    required UserRole role,
    String? addedByUid,
  }) async {
    await _membershipService.upsertRoles(
      uid: targetUid,
      schoolId: schoolId,
      schoolName: schoolName,
      roles: [role],
      ensureActive: true,
      createdBy: addedByUid,
    );
  }

  /// Returns the uid of an existing user with [email], or null if none.
  /// Callers use this when adding roles/memberships by email.
  Future<String?> findUidByEmail(String email) async {
    try {
      final snap = await _firestore
          .collection(AppConstants.usersCollection)
          .where('email', isEqualTo: email.trim())
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return null;
      return snap.docs.first.id;
    } catch (e) {
      print('findUidByEmail error: $e');
      return null;
    }
  }

  // Create teacher account (by tenant admin)
  Future<void> createTeacherAccount({
    required String email,
    required String password,
    required String schoolId,
    required String firstName,
    required String lastName,
    required String phone,
  }) async {
    try {
      // 1. Create user in Firebase Auth
      final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // 2. Create teacher document
      await _firestore.collection(AppConstants.schoolsCollection)
          .doc(schoolId)
          .collection(AppConstants.teachersCollection)
          .doc(userCredential.user!.uid)
          .set({
        'userId': userCredential.user!.uid,
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'phone': phone,
        'schoolId': schoolId,
        'isActive': true,
        'employmentType': AppConstants.fullTimeEmployment,
        'joiningDate': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 3. Create user document
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'email': email,
        'displayName': '$firstName $lastName',
        'role': AppConstants.teacherRole,
        'schoolId': schoolId,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'customClaims': {
          'role': AppConstants.teacherRole,
          'schoolId': schoolId,
          'isActive': true,
        },
      });

      // Note: Custom claims would typically be set by a Cloud Function
    } catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email);
    } catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Get user details from Firestore
  Future<AppUser?> getUserDetails(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return AppUser.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get user details: ${e.toString()}');
    }
  }

  // Get school details
  Future<School?> getSchoolDetails(String schoolId) async {
    try {
      final doc = await _firestore
          .collection(AppConstants.schoolsCollection)
          .doc(schoolId)
          .get();
      if (doc.exists) {
        return School.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get school details: ${e.toString()}');
    }
  }

  // Activate school and admin (by super admin)
  Future<void> activateSchool(String schoolId, String adminId) async {
    try {
      // Update school document
      await _firestore
          .collection(AppConstants.schoolsCollection)
          .doc(schoolId)
          .update({
        'isActive': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update admin user document
      await _firestore
          .collection(AppConstants.schoolsCollection)
          .doc(schoolId)
          .collection(AppConstants.adminUsersCollection)
          .doc(adminId)
          .update({
        'isActive': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update user document
      await _firestore.collection('users').doc(adminId).update({
        'isActive': true,
        'updatedAt': FieldValue.serverTimestamp(),
        'customClaims.isActive': true,
      });

      // Update membership to activate it when school is approved
      await _membershipService.upsertRoles(
        uid: adminId,
        schoolId: schoolId,
        schoolName: '', // Will be preserved from existing membership
        roles: const [UserRole.ADMIN], // Will be preserved from existing membership
        ensureActive: true, // Activate the membership
        schoolIsActive: true, // School is now active
      );

      // Note: Custom claims would typically be updated by a Cloud Function
    } catch (e) {
      throw Exception('Failed to activate school: ${e.toString()}');
    }
  }

  // Handle Firebase Auth exceptions
  Exception _handleAuthException(dynamic e) {
    print('Handling auth exception: $e');
    if (e is FirebaseAuthException) {
      print('Firebase Auth Exception code: ${e.code}');
      switch (e.code) {
        case 'user-not-found':
          return Exception('No user found with this email.');
        case 'wrong-password':
          return Exception('Wrong password provided.');
        case 'email-already-in-use':
          return Exception('The email address is already in use.');
        case 'weak-password':
          return Exception('The password is too weak. Please use at least 6 characters.');
        case 'invalid-email':
          return Exception('The email address is invalid.');
        case 'user-disabled':
          return Exception('This user account has been disabled.');
        case 'too-many-requests':
          return Exception('Too many requests. Try again later.');
        case 'operation-not-allowed':
          return Exception('Email/password accounts are not enabled. Please contact support.');
        case 'network-request-failed':
          return Exception('Network error. Please check your internet connection.');
        case 'invalid-credential':
          return Exception('The credential is malformed or has expired.');
        case 'account-exists-with-different-credential':
          return Exception('An account already exists with the same email address but different sign-in credentials.');
        default:
          return Exception('Authentication error: ${e.message ?? e.toString()}');
      }
    } else if (e is FirebaseException) {
      print('Firebase Exception code: ${e.code}');
      return Exception('Firebase error: ${e.message ?? e.toString()}');
    }
    return Exception('Authentication error: ${e.toString()}');
  }

  /// Create a staff user with temporary password
  /// Used for bulk upload of staff from CSV
  Future<void> createStaffUser({
    required String schoolId,
    required String name,
    required String email,
    required String phone,
    String role = 'Teacher',
    String department = '',
    String employeeId = '',
  }) async {
    try {
      // Generate temporary password
      final tempPassword = _generateTempPassword();

      // Create Firebase Auth user
      final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: tempPassword,
      );

      if (userCredential.user == null) {
        throw Exception('Failed to create user account');
      }

      final userId = userCredential.user!.uid;

      // Update display name
      await userCredential.user?.updateDisplayName(name);

      // Create user document in Firestore
      await _firestore.collection(AppConstants.usersCollection).doc(userId).set({
        'email': email,
        'displayName': name,
        'phone': phone,
        'role': 'teacher',
        'schoolId': schoolId,
        'isActive': false, // Needs admin activation
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'customClaims': {
          'department': department,
          'employeeId': employeeId,
          'designation': role,
        },
      });

      // Send password reset email so user can set their own password
      await _firebaseAuth.sendPasswordResetEmail(email: email);

    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        throw Exception('Email $email is already registered');
      }
      throw Exception('Failed to create user: ${e.message}');
    } catch (e) {
      throw Exception('Failed to create staff user: $e');
    }
  }

  String _generateTempPassword() {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$%^&*';
    final random = DateTime.now().millisecondsSinceEpoch;
    final buffer = StringBuffer();
    for (var i = 0; i < 16; i++) {
      buffer.write(chars[(random + i * 7) % chars.length]);
    }
    return buffer.toString();
  }
}

// Provider for AuthRepository
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    firebaseAuth: FirebaseAuth.instance,
    firestore: FirebaseFirestore.instance,
  );
});

// Provider for current user
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

// Provider for current app user
final currentAppUserProvider = FutureProvider<AppUser?>((ref) async {
  final user = ref.watch(authRepositoryProvider).currentUser;
  if (user != null) {
    return ref.watch(authRepositoryProvider).getUserDetails(user.uid);
  }
  return null;
});

// Provider for current school
final currentSchoolProvider = FutureProvider<School?>((ref) async {
  final appUser = await ref.watch(currentAppUserProvider.future);
  if (appUser != null && appUser.schoolId != null) {
    return ref.watch(authRepositoryProvider).getSchoolDetails(appUser.schoolId!);
  }
  return null;
});
