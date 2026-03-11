import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// BACKEND-ONLY PERMISSION SERVICE
/// Removes all client-side business logic and calculations
/// All operations now go through Cloud Functions or direct Firestore calls
class BackendPermissionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Create permission request with backend-only calculations
  /// Client only sends raw inputs, backend calculates duration and validates limits
  Future<Map<String, dynamic>> createPermissionRequest({
    required String schoolId,
    required String requestDate, // ISO string format
    required String startTime,   // HH:mm format
    required String endTime,     // HH:mm format
    required String reason,
  }) async {
    try {
      // Call backend function that handles all calculations and validations
      final result = await _callCloudFunction('createPermissionRequest', {
        'schoolId': schoolId,
        'requestDate': requestDate,
        'startTime': startTime,
        'endTime': endTime,
        'reason': reason,
      });
      
      return Map<String, dynamic>.from(result);
    } catch (e) {
      throw Exception('Failed to create permission request: ${e.toString()}');
    }
  }

  /// Cancel pending permission directly (no approval needed)
  /// Backend handles usage tracking atomically
  Future<Map<String, dynamic>> cancelPendingPermission({
    required String schoolId,
    required String permissionId,
  }) async {
    try {
      final result = await _callCloudFunction('cancelPendingPermission', {
        'schoolId': schoolId,
        'permissionId': permissionId,
      });
      
      return Map<String, dynamic>.from(result);
    } catch (e) {
      throw Exception('Failed to cancel pending permission: ${e.toString()}');
    }
  }

  /// Get permission configuration (read-only)
  Future<Map<String, dynamic>?> getPermissionConfig(String schoolId) async {
    try {
      final doc = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('permissionConfig')
          .doc('default')
          .get();
      
      return doc.exists ? doc.data() : null;
    } catch (e) {
      throw Exception('Failed to get permission config: ${e.toString()}');
    }
  }

  /// Get monthly permission usage (read-only)
  Future<Map<String, dynamic>?> getMonthlyUsage({
    required String schoolId,
    required String userId,
    required String month, // YYYY-MM format
  }) async {
    try {
      final usageId = '${userId}_$month';
      final doc = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('monthlyPermissionUsage')
          .doc(usageId)
          .get();
      
      return doc.exists ? doc.data() : null;
    } catch (e) {
      throw Exception('Failed to get monthly usage: ${e.toString()}');
    }
  }

  /// Validate permission request (backend-only)
  /// Checks overlaps, monthly limits, duration limits, etc.
  Future<Map<String, dynamic>> validatePermissionRequest({
    required String schoolId,
    required String requestDate,
    required String startTime,
    required String endTime,
  }) async {
    try {
      final result = await _callCloudFunction('validatePermissionRequest', {
        'schoolId': schoolId,
        'requestDate': requestDate,
        'startTime': startTime,
        'endTime': endTime,
      });
      
      return Map<String, dynamic>.from(result);
    } catch (e) {
      throw Exception('Failed to validate permission request: ${e.toString()}');
    }
  }

  /// Mock Cloud Function call (would use actual Firebase Functions in production)
  Future<Map<String, dynamic>> _callCloudFunction(String functionName, Map<String, dynamic> data) async {
    // In production, this would use FirebaseFunctions
    // For now, return mock success response
    await Future.delayed(const Duration(milliseconds: 500));
    
    switch (functionName) {
      case 'createPermissionRequest':
        return {
          'permissionId': 'perm_${DateTime.now().millisecondsSinceEpoch}',
          'durationMinutes': 60, // Mock calculated duration
          'status': 'PENDING',
        };
      case 'cancelPendingPermission':
        return {
          'success': true,
          'message': 'Permission cancelled successfully',
        };
      case 'validatePermissionRequest':
        return {
          'valid': true,
          'durationMinutes': 60,
          'remainingMonthlyLimit': 5,
        };
      default:
        throw Exception('Unknown function: $functionName');
    }
  }
}
