import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';

/// Production-ready WhatsApp Business API service using Meta's Cloud API
/// Handles fee reminders, payment confirmations, and admin notifications
class WhatsAppService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Meta WhatsApp Business API endpoints
  static const String _baseUrl = 'https://graph.facebook.com/v18.0';

  /// Send fee due reminder to parent
  ///
  /// [schoolId] - School identifier
  /// [phoneNumber] - Parent's phone number in E.164 format (e.g., +919876543210)
  /// [studentName] - Name of the student
  /// [dueAmount] - Amount due
  /// [dueDate] - Fee due date
  /// [termName] - Term/installment name
  Future<bool> sendFeeDueReminder({
    required String schoolId,
    required String phoneNumber,
    required String studentName,
    required double dueAmount,
    required DateTime dueDate,
    required String termName,
  }) async {
    try {
      final config = await _getWhatsAppConfig(schoolId);
      if (config == null || config['enabled'] != true) {
        print('[WhatsApp] Service not enabled for school: $schoolId');
        return false;
      }

      final accessToken = config['accessToken'] as String;
      final phoneNumberId = config['phoneNumberId'] as String;
      final templateName =
          config['feeDueTemplate'] as String? ?? 'fee_due_reminder';

      // Format phone number to E.164 if needed
      final formattedPhone = _formatPhoneNumber(phoneNumber);

      // Format due date
      final dueDateStr = '${dueDate.day}/${dueDate.month}/${dueDate.year}';

      final response = await http.post(
        Uri.parse('$_baseUrl/$phoneNumberId/messages'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'messaging_product': 'whatsapp',
          'to': formattedPhone,
          'type': 'template',
          'template': {
            'name': templateName,
            'language': {'code': 'en'},
            'components': [
              {
                'type': 'body',
                'parameters': [
                  {'type': 'text', 'text': studentName},
                  {'type': 'text', 'text': termName},
                  {'type': 'text', 'text': '₹${dueAmount.toStringAsFixed(2)}'},
                  {'type': 'text', 'text': dueDateStr},
                ]
              }
            ]
          }
        }),
      );

      if (response.statusCode == 200) {
        await _logNotification(
          schoolId: schoolId,
          type: 'fee_due_reminder',
          recipient: formattedPhone,
          studentName: studentName,
          metadata: {
            'termName': termName,
            'dueAmount': dueAmount,
            'dueDate': dueDateStr,
          },
          status: 'sent',
        );
        return true;
      } else {
        print(
            '[WhatsApp] Failed to send reminder: ${response.statusCode} - ${response.body}');
        await _logNotification(
          schoolId: schoolId,
          type: 'fee_due_reminder',
          recipient: formattedPhone,
          studentName: studentName,
          metadata: {'error': response.body},
          status: 'failed',
        );
        return false;
      }
    } catch (e) {
      print('[WhatsApp] Error sending fee due reminder: $e');
      return false;
    }
  }

  /// Send payment confirmation to parent
  ///
  /// [schoolId] - School identifier
  /// [phoneNumber] - Parent's phone number
  /// [studentName] - Name of the student
  /// [paidAmount] - Amount paid
  /// [receiptNumber] - Receipt/bill number
  /// [paymentDate] - Date of payment
  /// [balanceAmount] - Remaining balance
  Future<bool> sendPaymentConfirmation({
    required String schoolId,
    required String phoneNumber,
    required String studentName,
    required double paidAmount,
    required String receiptNumber,
    required DateTime paymentDate,
    required double balanceAmount,
  }) async {
    try {
      final config = await _getWhatsAppConfig(schoolId);
      if (config == null || config['enabled'] != true) {
        return false;
      }

      final accessToken = config['accessToken'] as String;
      final phoneNumberId = config['phoneNumberId'] as String;
      final templateName = config['paymentConfirmationTemplate'] as String? ??
          'payment_confirmation';

      final formattedPhone = _formatPhoneNumber(phoneNumber);
      final paymentDateStr =
          '${paymentDate.day}/${paymentDate.month}/${paymentDate.year}';

      final response = await http.post(
        Uri.parse('$_baseUrl/$phoneNumberId/messages'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'messaging_product': 'whatsapp',
          'to': formattedPhone,
          'type': 'template',
          'template': {
            'name': templateName,
            'language': {'code': 'en'},
            'components': [
              {
                'type': 'body',
                'parameters': [
                  {'type': 'text', 'text': studentName},
                  {'type': 'text', 'text': '₹${paidAmount.toStringAsFixed(2)}'},
                  {'type': 'text', 'text': receiptNumber},
                  {'type': 'text', 'text': paymentDateStr},
                  {
                    'type': 'text',
                    'text': '₹${balanceAmount.toStringAsFixed(2)}'
                  },
                ]
              }
            ]
          }
        }),
      );

      if (response.statusCode == 200) {
        await _logNotification(
          schoolId: schoolId,
          type: 'payment_confirmation',
          recipient: formattedPhone,
          studentName: studentName,
          metadata: {
            'paidAmount': paidAmount,
            'receiptNumber': receiptNumber,
            'balanceAmount': balanceAmount,
          },
          status: 'sent',
        );
        return true;
      } else {
        print(
            '[WhatsApp] Failed to send payment confirmation: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('[WhatsApp] Error sending payment confirmation: $e');
      return false;
    }
  }

  /// Send admin notification for daily fee collection summary
  ///
  /// [schoolId] - School identifier
  /// [totalCollected] - Total amount collected today
  /// [transactionCount] - Number of transactions
  /// [date] - Collection date
  Future<bool> sendAdminDailySummary({
    required String schoolId,
    required double totalCollected,
    required int transactionCount,
    required DateTime date,
  }) async {
    try {
      final config = await _getWhatsAppConfig(schoolId);
      if (config == null || config['enabled'] != true) {
        return false;
      }

      final adminNumbers =
          (config['adminPhoneNumbers'] as List?)?.cast<String>() ?? [];
      if (adminNumbers.isEmpty) {
        print('[WhatsApp] No admin numbers configured');
        return false;
      }

      final accessToken = config['accessToken'] as String;
      final phoneNumberId = config['phoneNumberId'] as String;
      final templateName =
          config['adminSummaryTemplate'] as String? ?? 'admin_daily_summary';

      final dateStr = '${date.day}/${date.month}/${date.year}';
      bool allSent = true;

      for (final adminPhone in adminNumbers) {
        final formattedPhone = _formatPhoneNumber(adminPhone);

        final response = await http.post(
          Uri.parse('$_baseUrl/$phoneNumberId/messages'),
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'messaging_product': 'whatsapp',
            'to': formattedPhone,
            'type': 'template',
            'template': {
              'name': templateName,
              'language': {'code': 'en'},
              'components': [
                {
                  'type': 'body',
                  'parameters': [
                    {'type': 'text', 'text': dateStr},
                    {
                      'type': 'text',
                      'text': '₹${totalCollected.toStringAsFixed(2)}'
                    },
                    {'type': 'text', 'text': transactionCount.toString()},
                  ]
                }
              ]
            }
          }),
        );

        if (response.statusCode != 200) {
          allSent = false;
          print('[WhatsApp] Failed to send admin summary to $adminPhone');
        }
      }

      return allSent;
    } catch (e) {
      print('[WhatsApp] Error sending admin summary: $e');
      return false;
    }
  }

  /// Get WhatsApp configuration for a school
  Future<Map<String, dynamic>?> _getWhatsAppConfig(String schoolId) async {
    try {
      final doc = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('settings')
          .doc('whatsapp')
          .get();

      if (!doc.exists) return null;
      return doc.data();
    } catch (e) {
      print('[WhatsApp] Error fetching config: $e');
      return null;
    }
  }

  /// Format phone number to E.164 format
  /// Assumes Indian numbers if no country code
  String _formatPhoneNumber(String phone) {
    // Remove all non-digit characters
    String cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');

    // If already has +, return as is
    if (cleaned.startsWith('+')) {
      return cleaned;
    }

    // If starts with country code without +, add it
    if (cleaned.startsWith('91') && cleaned.length == 12) {
      return '+$cleaned';
    }

    // Assume Indian number, add +91
    if (cleaned.length == 10) {
      return '+91$cleaned';
    }

    return cleaned;
  }

  /// Log notification for audit trail
  Future<void> _logNotification({
    required String schoolId,
    required String type,
    required String recipient,
    required String studentName,
    required Map<String, dynamic> metadata,
    required String status,
  }) async {
    try {
      await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('whatsappNotifications')
          .add({
        'type': type,
        'recipient': recipient,
        'studentName': studentName,
        'metadata': metadata,
        'status': status,
        'sentAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('[WhatsApp] Error logging notification: $e');
    }
  }

  /// Test WhatsApp configuration by sending a test message
  Future<bool> testConfiguration({
    required String schoolId,
    required String testPhoneNumber,
  }) async {
    try {
      final config = await _getWhatsAppConfig(schoolId);
      if (config == null) {
        print('[WhatsApp] No configuration found for school: $schoolId');
        return false;
      }

      final accessToken = config['accessToken'] as String?;
      final phoneNumberId = config['phoneNumberId'] as String?;

      if (accessToken == null || accessToken.isEmpty) {
        print('[WhatsApp] Access token is missing or empty');
        return false;
      }

      if (phoneNumberId == null || phoneNumberId.isEmpty) {
        print('[WhatsApp] Phone number ID is missing or empty');
        return false;
      }

      final formattedPhone = _formatPhoneNumber(testPhoneNumber);
      if (formattedPhone == null) {
        print('[WhatsApp] Invalid phone number: $testPhoneNumber');
        return false;
      }

      print('[WhatsApp] Testing configuration...');
      print('[WhatsApp] Phone Number ID: $phoneNumberId');
      print('[WhatsApp] Test Phone: $formattedPhone');

      final url = Uri.parse('$_baseUrl/$phoneNumberId/messages');
      print('[WhatsApp] Request URL: $url');

      final response = await http
          .post(
        url,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'messaging_product': 'whatsapp',
          'to': formattedPhone,
          'type': 'template',
          'template': {
            'name': 'hello_world', // Meta's default test template
            'language': {'code': 'en_US'},
          }
        }),
      )
          .timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          print('[WhatsApp] Request timed out after 30 seconds');
          throw Exception('Request timeout');
        },
      );

      return response.statusCode == 200;
    } catch (e) {
      print('[WhatsApp] Test failed: $e');
      return false;
    }
  }
}
