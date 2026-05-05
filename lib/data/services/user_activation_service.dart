import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

/// Service to handle user activation
/// 🔒 PRODUCTION-READY: Uses Cloud Functions for secure activation
/// 
/// Activation happens automatically via Cloud Function when:
/// 1. User completes password reset (first login)
/// 2. Admin manually activates user
/// 
/// This service is read-only - it checks activation status
class UserActivationService {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  UserActivationService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ?? FirebaseFunctions.instance;

  /// Check if user is activated
  /// This is a READ-ONLY check - activation happens via Cloud Function
  Future<ActivationResult> checkActivationStatus() async {
    final user = _auth.currentUser;
    if (user == null) {
      return ActivationResult(
        success: false,
        activated: false,
        message: 'No user logged in',
      );
    }

    try {
      // Check user document activation status
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      
      if (!userDoc.exists) {
        return ActivationResult(
          success: false,
          activated: false,
          message: 'User document not found',
        );
      }

      final userData = userDoc.data()!;
      final isActive = userData['isActive'] as bool? ?? false;
      final onboardingStatus = userData['onboardingStatus'] as String?;
      
      print('🔍 [ACTIVATION] Checking status for user: ${user.uid}');
      print('📊 [ACTIVATION] isActive: $isActive');
      print('📊 [ACTIVATION] onboardingStatus: $onboardingStatus');
      
      if (isActive && onboardingStatus == 'ACTIVE') {
        // Force token refresh to get latest claims
        await user.getIdToken(true);
        
        return ActivationResult(
          success: true,
          activated: true,
          message: 'User is active',
        );
      }
      
      // User not yet activated
      return ActivationResult(
        success: true,
        activated: false,
        message: 'User pending activation',
      );
    } catch (e) {
      print('❌ [ACTIVATION] Error checking activation status: $e');
      return ActivationResult(
        success: false,
        activated: false,
        message: 'Failed to check activation status: $e',
      );
    }
  }

  /// Manual activation by admin (calls Cloud Function)
  /// Only admins can call this
  Future<ActivationResult> activateUser(String userId) async {
    try {
      print('🔄 [ACTIVATION] Calling Cloud Function to activate user: $userId');
      
      final callable = _functions.httpsCallable('activateUser');
      final result = await callable.call({'userId': userId});
      
      print('✅ [ACTIVATION] Cloud Function response: ${result.data}');
      
      return ActivationResult(
        success: result.data['success'] as bool,
        activated: true,
        message: result.data['message'] as String,
      );
    } catch (e) {
      print('❌ [ACTIVATION] Error calling Cloud Function: $e');
      return ActivationResult(
        success: false,
        activated: false,
        message: 'Failed to activate user: $e',
      );
    }
  }

  /// Wait for activation (polling)
  /// Used on waiting activation screen
  Stream<bool> watchActivationStatus(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((doc) {
          if (!doc.exists) return false;
          final data = doc.data()!;
          final isActive = data['isActive'] as bool? ?? false;
          final status = data['onboardingStatus'] as String?;
          return isActive && status == 'ACTIVE';
        });
  }
}

/// Result of activation attempt
class ActivationResult {
  final bool success;
  final bool activated;
  final String message;

  ActivationResult({
    required this.success,
    required this.activated,
    required this.message,
  });

  @override
  String toString() {
    return 'ActivationResult(success: $success, activated: $activated, message: $message)';
  }
}
