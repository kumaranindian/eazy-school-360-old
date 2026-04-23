import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eazy_school_360/core/models/user_session.dart';
import 'package:eazy_school_360/data/services/membership_service.dart';
import 'package:eazy_school_360/domain/entities/app_user.dart';
import 'package:eazy_school_360/domain/entities/membership.dart';

/// Authentication state enum
enum AuthState {
  initial,
  loading,
  authenticated,
  unauthenticated,
  error,
}

/// Authentication result with error handling
class AuthResult {
  final bool success;
  final String? error;
  final UserSession? session;

  const AuthResult({
    required this.success,
    this.error,
    this.session,
  });

  factory AuthResult.success(UserSession session) {
    return AuthResult(success: true, session: session);
  }

  factory AuthResult.failure(String error) {
    return AuthResult(success: false, error: error);
  }
}

/// Authentication provider managing user session and Firebase Auth
class AuthNotifier extends StateNotifier<AuthState> {
  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;
  final MembershipService _membershipService;
  UserSession? _currentSession;

  AuthNotifier(
    this._firebaseAuth,
    this._firestore, {
    MembershipService? membershipService,
  })  : _membershipService =
            membershipService ?? MembershipService(firestore: _firestore),
        super(AuthState.initial) {
    _initializeAuth();
  }

  UserSession? get currentSession => _currentSession;
  bool get isAuthenticated => _currentSession != null && _currentSession!.isValid();
  bool get isSuperAdmin => _currentSession?.isSuperAdmin ?? false;
  bool get isAdmin => _currentSession?.isAdmin ?? false;
  bool get isStaff => _currentSession?.isStaff ?? false;

  /// Initialize authentication state on app start
  Future<void> _initializeAuth() async {
    try {
      state = AuthState.loading;
      
      // Check for persisted session
      final persistedSession = await _loadPersistedSession();
      if (persistedSession != null && persistedSession.isValid()) {
        _currentSession = persistedSession;
        state = AuthState.authenticated;
        return;
      }

      // Check Firebase Auth state
      final firebaseUser = _firebaseAuth.currentUser;
      if (firebaseUser != null) {
        // Fetch fresh user data from Firestore
        final authResult = await _fetchUserProfile(firebaseUser.uid);
        if (authResult.success && authResult.session != null) {
          _currentSession = authResult.session;
          await _persistSession(_currentSession!);
          state = AuthState.authenticated;
        } else {
          await _signOut();
        }
      } else {
        state = AuthState.unauthenticated;
      }
    } catch (e) {
      debugPrint('Auth initialization error: $e');
      state = AuthState.unauthenticated;
    }
  }

  /// Sign in with email and password.
  ///
  /// [preferredSchoolId] is optional — pass it when resuming a session that
  /// already knew which school it wanted (e.g. after the user picks one
  /// on the School Chooser screen).
  Future<AuthResult> signIn(
    String email,
    String password, {
    String? preferredSchoolId,
  }) async {
    try {
      state = AuthState.loading;

      // Firebase Authentication
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user == null) {
        state = AuthState.unauthenticated;
        return AuthResult.failure('Authentication failed');
      }

      // Fetch user profile from Firestore
      final authResult = await _fetchUserProfile(
        credential.user!.uid,
        preferredSchoolId: preferredSchoolId,
      );
      if (!authResult.success) {
        await _firebaseAuth.signOut();
        state = AuthState.unauthenticated;
        return authResult;
      }

      // Validate user status and permissions
      final session = authResult.session!;
      
      // Allow inactive users to proceed to login screen - the UI will route them to waiting activation
      // Don't sign them out here, let the login screen handle routing based on session.isActive

      // Update last login time
      await _updateLastLogin(session.uid);

      // Store session
      _currentSession = session;
      await _persistSession(session);
      state = AuthState.authenticated;

      return AuthResult.success(session);
    } on FirebaseAuthException catch (e) {
      state = AuthState.unauthenticated;
      return AuthResult.failure(_getFirebaseAuthErrorMessage(e));
    } catch (e) {
      state = AuthState.unauthenticated;
      return AuthResult.failure('An unexpected error occurred: ${e.toString()}');
    }
  }

  /// Switch the active school for the currently-signed-in user.
  ///
  /// Rebuilds the session around [schoolId], updates
  /// `users/{uid}.defaultSchoolId` so next login lands in the same place,
  /// and returns an [AuthResult]. Fails if the user has no active
  /// membership at [schoolId].
  Future<AuthResult> switchSchool(String schoolId) async {
    final user = _firebaseAuth.currentUser;
    if (user == null || _currentSession == null) {
      return AuthResult.failure('Not signed in.');
    }

    // Guard: user must have an active membership at the target school.
    final target = _currentSession!.memberships.firstWhere(
      (m) => m.schoolId == schoolId,
      orElse: () => Membership(
        schoolId: '',
        schoolName: '',
        roles: const [],
        joinedAt: DateTime.now(),
      ),
    );
    if (target.schoolId.isEmpty || !target.isActive || !target.schoolIsActive) {
      return AuthResult.failure(
          'You do not have access to that school anymore.');
    }

    final result = await _fetchUserProfile(
      user.uid,
      preferredSchoolId: schoolId,
    );
    if (!result.success || result.session == null) return result;

    _currentSession = result.session;
    await _persistSession(_currentSession!);
    // Persist the preference so the next cold start opens this school.
    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .set({'defaultSchoolId': schoolId}, SetOptions(merge: true));
    } catch (_) {/* non-critical */}
    // Keep the state the same (still authenticated) but notify listeners.
    state = AuthState.authenticated;
    // ignore: invalid_use_of_protected_member
    super.state = AuthState.authenticated; // force notify
    return result;
  }

  /// Sign out user
  Future<void> signOut() async {
    await _signOut();
  }

  Future<void> _signOut() async {
    try {
      await _firebaseAuth.signOut();
      await _clearPersistedSession();
      _currentSession = null;
      state = AuthState.unauthenticated;
    } catch (e) {
      debugPrint('Sign out error: $e');
    }
  }

  /// Fetch user profile from Firestore with security validation.
  ///
  /// [preferredSchoolId] picks which membership becomes active in the
  /// session. If null we fall back to the user's `defaultSchoolId`, then to
  /// the legacy `users/{uid}.schoolId`, then to the single membership (when
  /// there's only one).
  Future<AuthResult> _fetchUserProfile(
    String uid, {
    String? preferredSchoolId,
  }) async {
    try {
      final userDoc = await _firestore.collection('users').doc(uid).get();
      
      if (!userDoc.exists) {
        return AuthResult.failure('User profile not found. Please contact support.');
      }

      // Security validation: Ensure data integrity
      // The uid is stored as the document ID, not as a field in the document
      if (userDoc.id != uid) {
        return AuthResult.failure('Profile data integrity error. Please contact support.');
      }

      final appUser = AppUser.fromFirestore(userDoc);

      // Load all memberships up-front so the session knows every school
      // this user can act in. Legacy single-school users without a
      // membership doc still work — UserSession falls back to appUser.
      final memberships = await _membershipService.listForUser(uid);
      final activeMemberships =
          memberships.where((m) => m.isActive && m.schoolIsActive).toList();

      // Choose which school this session is scoped to.
      final resolvedSchoolId = _resolveActiveSchoolId(
        preferredSchoolId: preferredSchoolId,
        userDocData: userDoc.data() ?? const <String, dynamic>{},
        appUser: appUser,
        activeMemberships: activeMemberships,
      );

      final session = UserSession.fromAppUser(
        appUser,
        memberships: memberships,
        activeSchoolId: resolvedSchoolId,
      );

      // Only fail on hard integrity issues (missing uid/email). Activation
      // status is intentionally allowed through here so the UI can route the
      // user to the WaitingActivationScreen instead of showing a confusing
      // "invalid session" error right after signup.
      if (session.uid.isEmpty || session.email.isEmpty) {
        return AuthResult.failure(
            'Your user profile is incomplete. Please contact support.');
      }

      // Best-effort: mark the chosen school's membership as most-recently used.
      if (resolvedSchoolId != null) {
        unawaited(_membershipService.touchLastAccessed(
          uid: uid,
          schoolId: resolvedSchoolId,
        ));
      }

      return AuthResult.success(session);
    } catch (e) {
      debugPrint('Error fetching user profile: $e');
      return AuthResult.failure('Failed to load user profile. Please try again.');
    }
  }

  String? _resolveActiveSchoolId({
    required String? preferredSchoolId,
    required Map<String, dynamic> userDocData,
    required AppUser appUser,
    required List<Membership> activeMemberships,
  }) {
    if (activeMemberships.isEmpty) return appUser.schoolId;
    bool has(String sid) => activeMemberships.any((m) => m.schoolId == sid);

    if (preferredSchoolId != null && has(preferredSchoolId)) {
      return preferredSchoolId;
    }
    final def = userDocData['defaultSchoolId'] as String?;
    if (def != null && def.isNotEmpty && has(def)) return def;

    if (appUser.schoolId != null && has(appUser.schoolId!)) {
      return appUser.schoolId;
    }
    if (activeMemberships.length == 1) {
      return activeMemberships.first.schoolId;
    }
    // >1 memberships and nothing preferred — leave unresolved so the UI
    // can route to the School Chooser screen.
    return null;
  }

  /// Update last login timestamp
  Future<void> _updateLastLogin(String uid) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'lastLoginAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error updating last login: $e');
      // Non-critical error, don't fail authentication
    }
  }

  /// Persist session to local storage
  Future<void> _persistSession(UserSession session) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionJson = jsonEncode(session.toJson());
      await prefs.setString('user_session', sessionJson);
    } catch (e) {
      debugPrint('Error persisting session: $e');
    }
  }

  /// Load persisted session from local storage
  Future<UserSession?> _loadPersistedSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionJson = prefs.getString('user_session');
      if (sessionJson != null) {
        final sessionData = jsonDecode(sessionJson) as Map<String, dynamic>;
        return UserSession.fromJson(sessionData);
      }
    } catch (e) {
      debugPrint('Error loading persisted session: $e');
    }
    return null;
  }

  /// Clear persisted session
  Future<void> _clearPersistedSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_session');
    } catch (e) {
      debugPrint('Error clearing persisted session: $e');
    }
  }

  /// Get user-friendly Firebase Auth error messages
  String _getFirebaseAuthErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found with this email address.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-email':
        return 'Invalid email address format.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact support.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Please check your connection and try again.';
      default:
        return 'Authentication failed: ${e.message}';
    }
  }

  /// Refresh user session from Firestore
  Future<bool> refreshSession() async {
    if (_currentSession == null) return false;

    try {
      final authResult = await _fetchUserProfile(_currentSession!.uid);
      if (authResult.success && authResult.session != null) {
        _currentSession = authResult.session;
        await _persistSession(_currentSession!);
        return true;
      }
    } catch (e) {
      debugPrint('Error refreshing session: $e');
    }
    return false;
  }

  /// Check if user has specific permission
  bool hasPermission(String permission) {
    return _currentSession?.hasPermission(permission) ?? false;
  }

  /// Validate school access for current user
  bool canAccessSchool(String schoolId) {
    if (_currentSession == null) return false;
    
    // SUPER_ADMIN can access any school
    if (_currentSession!.isSuperAdmin) return true;
    
    // ADMIN and STAFF can only access their own school
    return _currentSession!.schoolId == schoolId;
  }
}

/// Providers
final firebaseAuthProvider = Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);
final firestoreProvider = Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final firebaseAuth = ref.watch(firebaseAuthProvider);
  final firestore = ref.watch(firestoreProvider);
  return AuthNotifier(firebaseAuth, firestore);
});

/// Current session provider
final currentSessionProvider = Provider<UserSession?>((ref) {
  ref.watch(authProvider); // Watch state changes
  final authNotifier = ref.watch(authProvider.notifier);
  return authNotifier.currentSession;
});

/// Authentication state helpers
final isAuthenticatedProvider = Provider<bool>((ref) {
  final authNotifier = ref.watch(authProvider.notifier);
  return authNotifier.isAuthenticated;
});

final userRoleProvider = Provider<UserRole?>((ref) {
  final session = ref.watch(currentSessionProvider);
  return session?.role;
});

final userSchoolIdProvider = Provider<String?>((ref) {
  final session = ref.watch(currentSessionProvider);
  return session?.schoolId;
});
