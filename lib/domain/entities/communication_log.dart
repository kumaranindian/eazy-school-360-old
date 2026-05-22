import 'package:cloud_firestore/cloud_firestore.dart';

/// Communication channel used to send the message
enum CommChannel {
  whatsapp,
  sms,
  email,
  push,
  inApp;

  String get displayName {
    switch (this) {
      case CommChannel.whatsapp:
        return 'WhatsApp';
      case CommChannel.sms:
        return 'SMS';
      case CommChannel.email:
        return 'Email';
      case CommChannel.push:
        return 'Push';
      case CommChannel.inApp:
        return 'In-App';
    }
  }

  static CommChannel fromString(String? v) {
    switch ((v ?? '').toLowerCase()) {
      case 'sms':
        return CommChannel.sms;
      case 'email':
        return CommChannel.email;
      case 'push':
        return CommChannel.push;
      case 'inapp':
      case 'in_app':
        return CommChannel.inApp;
      case 'whatsapp':
      default:
        return CommChannel.whatsapp;
    }
  }
}

/// Delivery status of the communication
enum CommStatus {
  pending,
  sent,
  delivered,
  read,
  failed;

  String get displayName {
    switch (this) {
      case CommStatus.pending:
        return 'Pending';
      case CommStatus.sent:
        return 'Sent';
      case CommStatus.delivered:
        return 'Delivered';
      case CommStatus.read:
        return 'Read';
      case CommStatus.failed:
        return 'Failed';
    }
  }

  static CommStatus fromString(String? v) {
    switch ((v ?? '').toLowerCase()) {
      case 'sent':
        return CommStatus.sent;
      case 'delivered':
        return CommStatus.delivered;
      case 'read':
        return CommStatus.read;
      case 'failed':
        return CommStatus.failed;
      case 'pending':
      default:
        return CommStatus.pending;
    }
  }
}

/// Purpose/type of the communication
enum CommPurpose {
  paymentDue,
  feeReminder,
  paymentReceipt,
  attendance,
  leaveUpdate,
  announcement,
  welcome,
  custom;

  String get displayName {
    switch (this) {
      case CommPurpose.paymentDue:
        return 'Payment Due';
      case CommPurpose.feeReminder:
        return 'Fee Reminder';
      case CommPurpose.paymentReceipt:
        return 'Payment Receipt';
      case CommPurpose.attendance:
        return 'Attendance';
      case CommPurpose.leaveUpdate:
        return 'Leave Update';
      case CommPurpose.announcement:
        return 'Announcement';
      case CommPurpose.welcome:
        return 'Welcome';
      case CommPurpose.custom:
        return 'Custom';
    }
  }

  static CommPurpose fromString(String? v) {
    switch ((v ?? '').toLowerCase()) {
      case 'payment_due':
      case 'paymentdue':
        return CommPurpose.paymentDue;
      case 'fee_reminder':
      case 'feereminder':
        return CommPurpose.feeReminder;
      case 'payment_receipt':
      case 'paymentreceipt':
        return CommPurpose.paymentReceipt;
      case 'attendance':
        return CommPurpose.attendance;
      case 'leave_update':
      case 'leaveupdate':
        return CommPurpose.leaveUpdate;
      case 'announcement':
        return CommPurpose.announcement;
      case 'welcome':
        return CommPurpose.welcome;
      default:
        return CommPurpose.custom;
    }
  }
}

/// Type of recipient
enum RecipientType {
  parent,
  staff,
  student;

  String get displayName {
    switch (this) {
      case RecipientType.parent:
        return 'Parent';
      case RecipientType.staff:
        return 'Staff';
      case RecipientType.student:
        return 'Student';
    }
  }

  static RecipientType fromString(String? v) {
    switch ((v ?? '').toLowerCase()) {
      case 'staff':
        return RecipientType.staff;
      case 'student':
        return RecipientType.student;
      case 'parent':
      default:
        return RecipientType.parent;
    }
  }
}

/// Communication log entry - represents a single outbound message
class CommunicationLog {
  final String id;
  final String schoolId;

  // Recipient info
  final String? recipientId;
  final String recipientName;
  final String recipientPhone;
  final String? recipientEmail;
  final RecipientType recipientType;

  // Message content/metadata
  final CommPurpose? purpose;
  final CommChannel channel;
  final CommStatus status;
  final String subject;
  final String message;

  // Related entity (e.g., which student ledger / fee item / etc.)
  final String? relatedEntityId;
  final String? relatedEntityType;

  // Sender info
  final String? sentByUserId;
  final String? sentByName;

  // Timestamps
  final DateTime sentAt;
  final DateTime? deliveredAt;
  final DateTime? readAt;
  final DateTime? failedAt;
  final String? errorMessage;

  final Map<String, dynamic>? metadata;

  const CommunicationLog({
    required this.id,
    required this.schoolId,
    this.recipientId,
    required this.recipientName,
    required this.recipientPhone,
    this.recipientEmail,
    required this.recipientType,
    this.purpose,
    required this.channel,
    required this.status,
    required this.subject,
    required this.message,
    this.relatedEntityId,
    this.relatedEntityType,
    this.sentByUserId,
    this.sentByName,
    required this.sentAt,
    this.deliveredAt,
    this.readAt,
    this.failedAt,
    this.errorMessage,
    this.metadata,
  });

  factory CommunicationLog.fromFirestore(
      Map<String, dynamic> data, String id) {
    return CommunicationLog(
      id: id,
      schoolId: data['schoolId']?.toString() ?? '',
      recipientId: data['recipientId']?.toString(),
      recipientName: data['recipientName']?.toString() ?? '',
      recipientPhone: data['recipientPhone']?.toString() ?? '',
      recipientEmail: data['recipientEmail']?.toString(),
      recipientType: RecipientType.fromString(data['recipientType'] as String?),
      purpose: data['purpose'] != null ? CommPurpose.fromString(data['purpose'] as String?) : null,
      channel: CommChannel.fromString(data['channel'] as String?),
      status: CommStatus.fromString(data['status'] as String?),
      subject: data['subject']?.toString() ?? '',
      message: data['message']?.toString() ?? '',
      relatedEntityId: data['relatedEntityId']?.toString(),
      relatedEntityType: data['relatedEntityType']?.toString(),
      sentByUserId: data['sentByUserId']?.toString(),
      sentByName: data['sentByName']?.toString(),
      sentAt: _toDate(data['sentAt']) ?? DateTime.now(),
      deliveredAt: _toDate(data['deliveredAt']),
      readAt: _toDate(data['readAt']),
      failedAt: _toDate(data['failedAt']),
      errorMessage: data['errorMessage']?.toString(),
      metadata: data['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'schoolId': schoolId,
      'recipientId': recipientId,
      'recipientName': recipientName,
      'recipientPhone': recipientPhone,
      'recipientEmail': recipientEmail,
      'recipientType': recipientType.name,
      if (purpose != null) 'purpose': purpose!.name,
      'channel': channel.name,
      'status': status.name,
      'subject': subject,
      'message': message,
      'relatedEntityId': relatedEntityId,
      'relatedEntityType': relatedEntityType,
      'sentByUserId': sentByUserId,
      'sentByName': sentByName,
      'sentAt': Timestamp.fromDate(sentAt),
      'deliveredAt':
          deliveredAt != null ? Timestamp.fromDate(deliveredAt!) : null,
      'readAt': readAt != null ? Timestamp.fromDate(readAt!) : null,
      'failedAt': failedAt != null ? Timestamp.fromDate(failedAt!) : null,
      'errorMessage': errorMessage,
      'metadata': metadata,
    };
  }

  static DateTime? _toDate(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    if (v is String) return DateTime.tryParse(v);
    return null;
  }
}
