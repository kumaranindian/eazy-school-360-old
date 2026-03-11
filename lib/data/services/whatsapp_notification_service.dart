import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/student_attendance.dart';

/// Service to send WhatsApp notifications via Meta WhatsApp Business API.
/// 
/// Configuration is stored in Firestore at: schools/{schoolId}/settings/whatsapp
/// Fields: phoneNumberId, accessToken, templateName, enabled
class WhatsAppNotificationService {
  WhatsAppNotificationService._();

  /// Send attendance notification to a parent via WhatsApp
  static Future<bool> sendAttendanceNotification({
    required String parentPhone,
    required String studentName,
    required String className,
    required DateTime date,
    required AttendanceStatus status,
    required String schoolId,
  }) async {
    try {
      // Fetch WhatsApp config from Firestore
      final config = await _getWhatsAppConfig(schoolId);
      if (config == null || config['enabled'] != true) {
        debugPrint('WhatsApp notifications not configured or disabled for school: $schoolId');
        return false;
      }

      final phoneNumberId = config['phoneNumberId'] as String?;
      final accessToken = config['accessToken'] as String?;

      if (phoneNumberId == null || accessToken == null) {
        debugPrint('WhatsApp config missing phoneNumberId or accessToken');
        return false;
      }

      // Format phone number (ensure it starts with country code)
      final formattedPhone = _formatPhoneNumber(parentPhone);
      if (formattedPhone == null) {
        debugPrint('Invalid phone number: $parentPhone');
        return false;
      }

      final dateStr = DateFormat('dd MMMM yyyy').format(date);
      final statusStr = _statusToString(status);

      // Log the notification attempt (we store in Firestore for audit)
      await _logNotification(
        schoolId: schoolId,
        parentPhone: formattedPhone,
        studentName: studentName,
        className: className,
        date: date,
        status: status,
        success: true,
      );

      // For now, we queue the message in Firestore for the Cloud Function to process
      // This avoids exposing the access token in the client app
      await FirebaseFirestore.instance
          .collection('schools')
          .doc(schoolId)
          .collection('whatsappQueue')
          .add({
        'to': formattedPhone,
        'studentName': studentName,
        'className': className,
        'date': dateStr,
        'status': statusStr,
        'message': 'Dear Parent, your ward $studentName (Class $className) was marked $statusStr on $dateStr. - Eazy School 360',
        'createdAt': FieldValue.serverTimestamp(),
        'processed': false,
        'type': 'attendance',
      });

      return true;
    } catch (e) {
      debugPrint('WhatsApp notification error: $e');
      return false;
    }
  }

  /// Send bulk attendance notifications for all absent students
  static Future<Map<String, int>> sendBulkAbsentNotifications({
    required String schoolId,
    required List<StudentAttendanceRecord> absentRecords,
  }) async {
    int sent = 0;
    int failed = 0;

    for (final record in absentRecords) {
      if (record.parentPhone != null && record.parentPhone!.isNotEmpty) {
        final success = await sendAttendanceNotification(
          parentPhone: record.parentPhone!,
          studentName: record.studentName,
          className: record.className,
          date: record.date,
          status: record.status,
          schoolId: schoolId,
        );
        if (success) {
          sent++;
        } else {
          failed++;
        }
      } else {
        failed++;
      }
    }

    return {'sent': sent, 'failed': failed};
  }

  /// Get WhatsApp configuration for a school
  static Future<Map<String, dynamic>?> _getWhatsAppConfig(String schoolId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('schools')
          .doc(schoolId)
          .collection('settings')
          .doc('whatsapp')
          .get();

      if (!doc.exists) return null;
      return doc.data();
    } catch (e) {
      debugPrint('Error fetching WhatsApp config: $e');
      return null;
    }
  }

  /// Save WhatsApp configuration for a school
  static Future<void> saveWhatsAppConfig({
    required String schoolId,
    required String phoneNumberId,
    required String accessToken,
    String templateName = 'attendance_notification',
    bool enabled = true,
  }) async {
    await FirebaseFirestore.instance
        .collection('schools')
        .doc(schoolId)
        .collection('settings')
        .doc('whatsapp')
        .set({
      'phoneNumberId': phoneNumberId,
      'accessToken': accessToken,
      'templateName': templateName,
      'enabled': enabled,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Format phone number to international format
  static String? _formatPhoneNumber(String phone) {
    // Remove spaces, dashes, etc.
    String cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');

    // If starts with +, strip it for the API
    if (cleaned.startsWith('+')) {
      cleaned = cleaned.substring(1);
    }

    // If it's a 10-digit Indian number, prepend 91
    if (cleaned.length == 10 && !cleaned.startsWith('0')) {
      cleaned = '91$cleaned';
    }

    // If starts with 0, remove it and prepend 91
    if (cleaned.startsWith('0')) {
      cleaned = '91${cleaned.substring(1)}';
    }

    // Validate minimum length
    if (cleaned.length < 10) return null;

    return cleaned;
  }

  /// Convert attendance status to readable string
  static String _statusToString(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.PRESENT: return 'Present';
      case AttendanceStatus.ABSENT: return 'Absent';
      case AttendanceStatus.LATE: return 'Late';
      case AttendanceStatus.PERMISSION: return 'On Permission';
      case AttendanceStatus.HOLIDAY: return 'Holiday';
      case AttendanceStatus.NOT_MARKED: return 'Not Marked';
    }
  }

  /// Log notification for audit
  static Future<void> _logNotification({
    required String schoolId,
    required String parentPhone,
    required String studentName,
    required String className,
    required DateTime date,
    required AttendanceStatus status,
    required bool success,
  }) async {
    try {
      await FirebaseFirestore.instance
          .collection('schools')
          .doc(schoolId)
          .collection('notificationLogs')
          .add({
        'type': 'whatsapp_attendance',
        'parentPhone': parentPhone,
        'studentName': studentName,
        'className': className,
        'date': Timestamp.fromDate(date),
        'status': status.name,
        'success': success,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error logging notification: $e');
    }
  }
}
