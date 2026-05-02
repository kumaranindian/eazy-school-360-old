import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/user_session.dart';

/// Audit log entry types
enum AuditAction {
  login,
  logout,
  schoolSwitch,
  dataAccess,
  dataModification,
  permissionCheck,
  failedAccess,
  sessionExpiry,
}

/// Audit log service for tracking security events
/// Logs school switching, access attempts, and other security-sensitive operations
class AuditLogService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const Uuid _uuid = Uuid();

  /// Log an audit event
  static Future<void> logEvent({
    required String schoolId,
    required String userId,
    required AuditAction action,
    String? targetSchoolId,
    String? resourceType,
    String? resourceId,
    String? details,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final logEntry = {
        'id': _uuid.v4(),
        'userId': userId,
        'schoolId': schoolId,
        'action': action.name,
        'targetSchoolId': targetSchoolId,
        'resourceType': resourceType,
        'resourceId': resourceId,
        'details': details,
        'metadata': metadata,
        'timestamp': FieldValue.serverTimestamp(),
        'userAgent': _getUserAgent(),
      };

      await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('audit_logs')
          .doc(logEntry['id'] as String)
          .set(logEntry);

      print('Audit log: ${action.name} by user $userId in school $schoolId');
    } catch (e) {
      print('Error logging audit event: $e');
      // Don't throw - audit logging failures shouldn't break the app
    }
  }

  /// Log school switching event
  static Future<void> logSchoolSwitch({
    required UserSession session,
    required String newSchoolId,
    required String previousSchoolId,
  }) async {
    await logEvent(
      schoolId: previousSchoolId,
      userId: session.uid,
      action: AuditAction.schoolSwitch,
      targetSchoolId: newSchoolId,
      details: 'User switched from school $previousSchoolId to $newSchoolId',
      metadata: {
        'userEmail': session.email,
        'userRole': session.role.name,
        'previousSchoolId': previousSchoolId,
        'newSchoolId': newSchoolId,
      },
    );

    // Also log to the new school
    await logEvent(
      schoolId: newSchoolId,
      userId: session.uid,
      action: AuditAction.schoolSwitch,
      targetSchoolId: previousSchoolId,
      details: 'User switched from school $previousSchoolId to $newSchoolId',
      metadata: {
        'userEmail': session.email,
        'userRole': session.role.name,
        'previousSchoolId': previousSchoolId,
        'newSchoolId': newSchoolId,
      },
    );
  }

  /// Login event
  static Future<void> logLogin({
    required UserSession session,
    String? method,
  }) async {
    if (session.schoolId == null) return;

    await logEvent(
      schoolId: session.schoolId!,
      userId: session.uid,
      action: AuditAction.login,
      details: 'User logged in',
      metadata: {
        'userEmail': session.email,
        'userRole': session.role.name,
        'loginMethod': method ?? 'unknown',
      },
    );
  }

  /// Logout event
  static Future<void> logLogout({
    required UserSession session,
  }) async {
    if (session.schoolId == null) return;

    await logEvent(
      schoolId: session.schoolId!,
      userId: session.uid,
      action: AuditAction.logout,
      details: 'User logged out',
      metadata: {
        'userEmail': session.email,
        'userRole': session.role.name,
      },
    );
  }

  /// Data access event
  static Future<void> logDataAccess({
    required UserSession session,
    required String resourceType,
    String? resourceId,
    String? details,
  }) async {
    if (session.schoolId == null) return;

    await logEvent(
      schoolId: session.schoolId!,
      userId: session.uid,
      action: AuditAction.dataAccess,
      resourceType: resourceType,
      resourceId: resourceId,
      details: details ?? 'Accessed $resourceType',
      metadata: {
        'userEmail': session.email,
        'userRole': session.role.name,
      },
    );
  }

  /// Data modification event
  static Future<void> logDataModification({
    required UserSession session,
    required String resourceType,
    String? resourceId,
    String? details,
  }) async {
    if (session.schoolId == null) return;

    await logEvent(
      schoolId: session.schoolId!,
      userId: session.uid,
      action: AuditAction.dataModification,
      resourceType: resourceType,
      resourceId: resourceId,
      details: details ?? 'Modified $resourceType',
      metadata: {
        'userEmail': session.email,
        'userRole': session.role.name,
      },
    );
  }

  /// Failed access attempt
  static Future<void> logFailedAccess({
    required String schoolId,
    required String userId,
    required String reason,
    String? resourceType,
    String? resourceId,
  }) async {
    await logEvent(
      schoolId: schoolId,
      userId: userId,
      action: AuditAction.failedAccess,
      resourceType: resourceType,
      resourceId: resourceId,
      details: reason,
      metadata: {
        'failureReason': reason,
      },
    );
  }

  /// Session expiry event
  static Future<void> logSessionExpiry({
    required UserSession session,
  }) async {
    if (session.schoolId == null) return;

    await logEvent(
      schoolId: session.schoolId!,
      userId: session.uid,
      action: AuditAction.sessionExpiry,
      details: 'Session expired',
      metadata: {
        'userEmail': session.email,
        'userRole': session.role.name,
        'lastLoginAt': session.lastLoginAt.toIso8601String(),
      },
    );
  }

  /// Get user agent string (simplified for web)
  static String _getUserAgent() {
    // In a real app, you'd get this from the platform
    // For web, this would be from window.navigator.userAgent
    return 'Flutter Web App';
  }

  /// Query audit logs for a school
  static Future<List<Map<String, dynamic>>> getAuditLogs({
    required String schoolId,
    String? userId,
    AuditAction? action,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 100,
  }) async {
    try {
      Query query = _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('audit_logs')
          .orderBy('timestamp', descending: true)
          .limit(limit);

      if (userId != null) {
        query = query.where('userId', isEqualTo: userId);
      }

      if (action != null) {
        query = query.where('action', isEqualTo: action.name);
      }

      if (startDate != null) {
        query = query.where('timestamp',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }

      if (endDate != null) {
        query = query.where('timestamp',
            isLessThanOrEqualTo: Timestamp.fromDate(endDate));
      }

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList();
    } catch (e) {
      print('Error fetching audit logs: $e');
      return [];
    }
  }

  /// Clean up old audit logs (older than specified days)
  static Future<void> cleanupOldLogs({
    required String schoolId,
    int daysToKeep = 90,
  }) async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: daysToKeep));

      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('audit_logs')
          .where('timestamp', isLessThan: Timestamp.fromDate(cutoffDate))
          .limit(500)
          .get();

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      print('Cleaned up ${snapshot.docs.length} old audit logs');
    } catch (e) {
      print('Error cleaning up audit logs: $e');
    }
  }
}
