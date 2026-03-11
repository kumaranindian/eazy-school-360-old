import 'package:cloud_firestore/cloud_firestore.dart';

enum SchoolStatus { ACTIVE, DISABLED }

class SchoolSettings {
  final String timezone;
  final String currency;
  final List<String> workingDays;
  final int maxLeaveCarryForward;

  const SchoolSettings({
    required this.timezone,
    required this.currency,
    required this.workingDays,
    required this.maxLeaveCarryForward,
  });

  factory SchoolSettings.fromMap(Map<String, dynamic> map) {
    return SchoolSettings(
      timezone: map['timezone'] as String? ?? 'Asia/Kolkata',
      currency: map['currency'] as String? ?? 'INR',
      workingDays: (map['workingDays'] as List<dynamic>?)?.cast<String>() ?? ['MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY'],
      maxLeaveCarryForward: map['maxLeaveCarryForward'] as int? ?? 5,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'timezone': timezone,
      'currency': currency,
      'workingDays': workingDays,
      'maxLeaveCarryForward': maxLeaveCarryForward,
    };
  }
}

class SchoolSubscription {
  final String plan;
  final int maxStaff;
  final DateTime expiresAt;
  final bool isActive;

  const SchoolSubscription({
    required this.plan,
    required this.maxStaff,
    required this.expiresAt,
    required this.isActive,
  });

  factory SchoolSubscription.fromMap(Map<String, dynamic> map) {
    return SchoolSubscription(
      plan: map['plan'] as String? ?? 'BASIC',
      maxStaff: map['maxStaff'] as int? ?? 50,
      expiresAt: (map['expiresAt'] as Timestamp?)?.toDate() ?? DateTime.now().add(const Duration(days: 365)),
      isActive: map['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'plan': plan,
      'maxStaff': maxStaff,
      'expiresAt': Timestamp.fromDate(expiresAt),
      'isActive': isActive,
    };
  }
}

class School {
  final String schoolId;
  final String schoolName;
  final String shortCode; // e.g., "ES360" - used for generating staff/leave IDs
  final DateTime academicYearStart;
  final SchoolStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;
  final String? adminUserId;
  final SchoolSettings settings;
  final SchoolSubscription subscription;
  final int staffCounter; // Auto-increment counter for staff IDs
  final int leaveCounter; // Auto-increment counter for leave IDs

  const School({
    required this.schoolId,
    required this.schoolName,
    required this.shortCode,
    required this.academicYearStart,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
    this.adminUserId,
    required this.settings,
    required this.subscription,
    this.staffCounter = 0,
    this.leaveCounter = 0,
  });

  factory School.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final schoolName = (data['schoolName'] as String?) ?? '';
    return School(
      schoolId: doc.id,
      schoolName: schoolName,
      shortCode: (data['shortCode'] as String?) ?? _generateShortCode(schoolName),
      academicYearStart: (data['academicYearStart'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: _parseStatus(data['status']),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: (data['createdBy'] as String?) ?? '',
      adminUserId: data['adminUserId'] as String?,
      settings: SchoolSettings.fromMap((data['settings'] as Map<String, dynamic>?) ?? {}),
      subscription: SchoolSubscription.fromMap((data['subscription'] as Map<String, dynamic>?) ?? {}),
      staffCounter: data['staffCounter'] as int? ?? 0,
      leaveCounter: data['leaveCounter'] as int? ?? 0,
    );
  }

  static String _generateShortCode(String schoolName) {
    if (schoolName.isEmpty) return 'SCH';
    final words = schoolName.toUpperCase().split(' ').where((w) => w.isNotEmpty).toList();
    if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}${words.length > 2 ? words[2][0] : ''}';
    }
    return schoolName.substring(0, schoolName.length >= 3 ? 3 : schoolName.length).toUpperCase();
  }

  static SchoolStatus _parseStatus(dynamic status) {
    if (status == null) return SchoolStatus.ACTIVE;
    switch (status.toString().toUpperCase()) {
      case 'ACTIVE':
        return SchoolStatus.ACTIVE;
      case 'DISABLED':
        return SchoolStatus.DISABLED;
      default:
        return SchoolStatus.ACTIVE;
    }
  }

  Map<String, dynamic> toFirestore() {
    return {
      'schoolId': schoolId,
      'schoolName': schoolName,
      'shortCode': shortCode,
      'academicYearStart': Timestamp.fromDate(academicYearStart),
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'createdBy': createdBy,
      'adminUserId': adminUserId,
      'settings': settings.toMap(),
      'subscription': subscription.toMap(),
      'staffCounter': staffCounter,
      'leaveCounter': leaveCounter,
    };
  }

  School copyWith({
    String? schoolId,
    String? schoolName,
    String? shortCode,
    DateTime? academicYearStart,
    SchoolStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    String? adminUserId,
    SchoolSettings? settings,
    SchoolSubscription? subscription,
    int? staffCounter,
    int? leaveCounter,
  }) {
    return School(
      schoolId: schoolId ?? this.schoolId,
      schoolName: schoolName ?? this.schoolName,
      shortCode: shortCode ?? this.shortCode,
      academicYearStart: academicYearStart ?? this.academicYearStart,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      adminUserId: adminUserId ?? this.adminUserId,
      settings: settings ?? this.settings,
      subscription: subscription ?? this.subscription,
      staffCounter: staffCounter ?? this.staffCounter,
      leaveCounter: leaveCounter ?? this.leaveCounter,
    );
  }
}
