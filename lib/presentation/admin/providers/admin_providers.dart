import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Provider to get current user's school ID from Firebase Auth token
final currentSchoolIdProvider = FutureProvider<String?>((ref) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return null;
  
  try {
    final idTokenResult = await user.getIdTokenResult();
    final schoolId = idTokenResult.claims?['schoolId'] as String?;
    return schoolId;
  } catch (e) {
    print('❌ [ADMIN_PROVIDERS] Error getting schoolId from token: $e');
    return null;
  }
});

/// Provider to get current user info
final currentUserProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});
