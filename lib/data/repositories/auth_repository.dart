import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/entities/school.dart';

/// Result class for login operation containing user details and status
class LoginResult {
  final UserCredential userCredential;
  final UserRole role;
  final bool isActive;
  final String? schoolId;
  final String displayName;
  final String message;

  LoginResult({
    required this.userCredential,
    required this.role,
    required this.isActive,
    this.schoolId,
    required this.displayName,
    required this.message,
  });
  
  /// Check if user can access the dashboard
  bool get canAccessDashboard => isActive;
  
  /// Check if user needs to wait for activation
  bool get needsActivation => !isActive;
}

class AuthRepository {
  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;

  AuthRepository({
    required FirebaseAuth firebaseAuth,
    required FirebaseFirestore firestore,
  })  : _firebaseAuth = firebaseAuth,
        _firestore = firestore;

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

  // Sign up with email and password (for tenant admin)
  Future<UserCredential> signUpWithEmailAndPassword({
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

      try {
        // Use simple timestamps instead of FieldValue.serverTimestamp() to avoid potential issues
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final Map<String, dynamic> schoolData = {
          'name': schoolName,
          'address': schoolAddress,
          'email': email,
          'phone': schoolPhone,
          'website': schoolWebsite ?? '',
          'logoUrl': '',
          'isActive': false, // Default to inactive until approved by super admin
          'createdAt': timestamp,
          'updatedAt': timestamp,
          'settings': {},
        };
        
        // 2. Create school document
        print('Creating school document for: $schoolName');
        final schoolDoc = await _firestore.collection(AppConstants.schoolsCollection).add(schoolData);
        print('School document created with ID: ${schoolDoc.id}');

        // Prepare admin user data
        final String displayName = adminName ?? email.split('@').first;
        final Map<String, dynamic> adminData = {
          'email': email,
          'displayName': displayName,
          'role': AppConstants.tenantAdminRole,
          'schoolId': schoolDoc.id,
          'isActive': false, // Default to inactive until approved by super admin
          'createdAt': timestamp,
          'updatedAt': timestamp,
        };
        
        // 3. Create admin user document
        print('Creating admin user document');
        await _firestore.collection(AppConstants.schoolsCollection)
            .doc(schoolDoc.id)
            .collection(AppConstants.adminUsersCollection)
            .doc(userCredential.user!.uid)
            .set(adminData);
        print('Admin user document created');

        // 4. Create user document
        print('Creating user document');
        final Map<String, dynamic> userData = {
          'email': email,
          'displayName': displayName,
          'role': AppConstants.tenantAdminRole,
          'schoolId': schoolDoc.id,
          'isActive': false, // Default to inactive until approved by super admin
          'createdAt': timestamp,
          'updatedAt': timestamp,
          'customClaims': {
            'role': AppConstants.tenantAdminRole,
            'schoolId': schoolDoc.id,
            'isActive': false,
          },
        };
        
        await _firestore.collection(AppConstants.usersCollection).doc(userCredential.user!.uid).set(userData);
        print('All documents created successfully');
      } catch (firestoreError) {
        // If Firestore operations fail, delete the created user to maintain consistency
        print('Error in Firestore operations: $firestoreError');
        if (userCredential.user != null) {
          print('Deleting user due to Firestore error');
          await userCredential.user!.delete();
        }
        throw Exception('Failed to create school records: ${firestoreError.toString()}');
      }

      return userCredential;
    } catch (e) {
      print('Error in signup process: $e');
      throw _handleAuthException(e);
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
