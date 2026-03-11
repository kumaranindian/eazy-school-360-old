import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eazy_school_360/core/models/user_session.dart';
import 'package:eazy_school_360/domain/entities/app_user.dart';

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
  UserSession? _currentSession;

  AuthNotifier(this._firebaseAuth, this._firestore) : super(AuthState.initial) {
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

  /// Sign in with email and password
  Future<AuthResult> signIn(String email, String password) async {
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
      final authResult = await _fetchUserProfile(credential.user!.uid);
      if (!authResult.success) {
        await _firebaseAuth.signOut();
        state = AuthState.unauthenticated;
        return authResult;
      }

      // Validate user status and permissions
      final session = authResult.session!;
      if (!session.isActive) {
        await _firebaseAuth.signOut();
        state = AuthState.unauthenticated;
        return AuthResult.failure('Account is disabled. Please contact your administrator.');
      }

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

  /// Fetch user profile from Firestore with security validation
  Future<AuthResult> _fetchUserProfile(String uid) async {
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
      final session = UserSession.fromAppUser(appUser);

      // Additional security checks
      if (!session.isValid()) {
        return AuthResult.failure('Invalid user session. Please contact support.');
      }

      return AuthResult.success(session);
    } catch (e) {
      debugPrint('Error fetching user profile: $e');
      return AuthResult.failure('Failed to load user profile. Please try again.');
    }
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
