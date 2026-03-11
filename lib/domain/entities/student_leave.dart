import 'package:cloud_firestore/cloud_firestore.dart';

enum StudentLeaveStatus { PENDING, APPROVED, REJECTED, CANCELLED }
enum StudentLeaveType { SICK_LEAVE, CASUAL_LEAVE, PERMISSION, FAMILY_EMERGENCY, OTHER }

class StudentLeaveRequest {
  final String id;
  final String schoolId;
  final String studentId;
  final String studentName;
  final int studentNumericId;
  final String className;
  final String section;
  final String? parentName;
  final String? parentPhone;
  final String? appliedByUserId;
  final StudentLeaveType leaveType;
  final DateTime startDate;
  final DateTime endDate;
  final int totalDays;
  final String reason;
  final StudentLeaveStatus status;
  final String? approvedBy;
  final DateTime? approvedAt;
  final String? rejectionReason;
  final DateTime createdAt;
  final DateTime updatedAt;

  const StudentLeaveRequest({
    required this.id,
    required this.schoolId,
    required this.studentId,
    required this.studentName,
    required this.studentNumericId,
    required this.className,
    required this.section,
    this.parentName,
    this.parentPhone,
    this.appliedByUserId,
    required this.leaveType,
    required this.startDate,
    required this.endDate,
    required this.totalDays,
    required this.reason,
    required this.status,
    this.approvedBy,
    this.approvedAt,
    this.rejectionReason,
    required this.createdAt,
    required this.updatedAt,
  });

  factory StudentLeaveRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return StudentLeaveRequest(
      id: doc.id,
      schoolId: data['schoolId'] as String? ?? '',
      studentId: data['studentId'] as String? ?? '',
      studentName: data['studentName'] as String? ?? '',
      studentNumericId: (data['studentNumericId'] as num?)?.toInt() ?? 0,
      className: data['className'] as String? ?? '',
      section: data['section'] as String? ?? '',
      parentName: data['parentName'] as String?,
      parentPhone: data['parentPhone'] as String?,
      appliedByUserId: data['appliedByUserId'] as String?,
      leaveType: _parseLeaveType(data['leaveType']),
      startDate: _parseDate(data['startDate']),
      endDate: _parseDate(data['endDate']),
      totalDays: (data['totalDays'] as num?)?.toInt() ?? 1,
      reason: data['reason'] as String? ?? '',
      status: _parseStatus(data['status']),
      approvedBy: data['approvedBy'] as String?,
      approvedAt: _parseDateTime(data['approvedAt']),
      rejectionReason: data['rejectionReason'] as String?,
      createdAt: _parseDate(data['createdAt']),
      updatedAt: _parseDate(data['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'schoolId': schoolId,
      'studentId': studentId,
      'studentName': studentName,
      'studentNumericId': studentNumericId,
      'className': className,
      'section': section,
      'parentName': parentName,
      'parentPhone': parentPhone,
      'appliedByUserId': appliedByUserId,
      'leaveType': leaveType.name,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'totalDays': totalDays,
      'reason': reason,
      'status': status.name,
      'approvedBy': approvedBy,
      'approvedAt': approvedAt != null ? Timestamp.fromDate(approvedAt!) : null,
      'rejectionReason': rejectionReason,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  static StudentLeaveType _parseLeaveType(dynamic value) {
    if (value == null) return StudentLeaveType.OTHER;
    switch (value.toString().toUpperCase()) {
      case 'SICK_LEAVE': return StudentLeaveType.SICK_LEAVE;
      case 'CASUAL_LEAVE': return StudentLeaveType.CASUAL_LEAVE;
      case 'PERMISSION': return StudentLeaveType.PERMISSION;
      case 'FAMILY_EMERGENCY': return StudentLeaveType.FAMILY_EMERGENCY;
      default: return StudentLeaveType.OTHER;
    }
  }

  static StudentLeaveStatus _parseStatus(dynamic value) {
    if (value == null) return StudentLeaveStatus.PENDING;
    switch (value.toString().toUpperCase()) {
      case 'APPROVED': return StudentLeaveStatus.APPROVED;
      case 'REJECTED': return StudentLeaveStatus.REJECTED;
      case 'CANCELLED': return StudentLeaveStatus.CANCELLED;
      default: return StudentLeaveStatus.PENDING;
    }
  }

  static DateTime _parseDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  String get leaveTypeLabel {
    switch (leaveType) {
      case StudentLeaveType.SICK_LEAVE: return 'Sick Leave';
      case StudentLeaveType.CASUAL_LEAVE: return 'Casual Leave';
      case StudentLeaveType.PERMISSION: return 'Permission';
      case StudentLeaveType.FAMILY_EMERGENCY: return 'Family Emergency';
      case StudentLeaveType.OTHER: return 'Other';
    }
  }

  String get statusLabel {
    switch (status) {
      case StudentLeaveStatus.PENDING: return 'Pending';
      case StudentLeaveStatus.APPROVED: return 'Approved';
      case StudentLeaveStatus.REJECTED: return 'Rejected';
      case StudentLeaveStatus.CANCELLED: return 'Cancelled';
    }
  }

  bool get isPending => status == StudentLeaveStatus.PENDING;
  bool get isApproved => status == StudentLeaveStatus.APPROVED;

  StudentLeaveRequest copyWith({
    String? id,
    String? schoolId,
    String? studentId,
    String? studentName,
    int? studentNumericId,
    String? className,
    String? section,
    String? parentName,
    String? parentPhone,
    String? appliedByUserId,
    StudentLeaveType? leaveType,
    DateTime? startDate,
    DateTime? endDate,
    int? totalDays,
    String? reason,
    StudentLeaveStatus? status,
    String? approvedBy,
    DateTime? approvedAt,
    String? rejectionReason,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return StudentLeaveRequest(
      id: id ?? this.id,
      schoolId: schoolId ?? this.schoolId,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      studentNumericId: studentNumericId ?? this.studentNumericId,
      className: className ?? this.className,
      section: section ?? this.section,
      parentName: parentName ?? this.parentName,
      parentPhone: parentPhone ?? this.parentPhone,
      appliedByUserId: appliedByUserId ?? this.appliedByUserId,
      leaveType: leaveType ?? this.leaveType,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      totalDays: totalDays ?? this.totalDays,
      reason: reason ?? this.reason,
      status: status ?? this.status,
      approvedBy: approvedBy ?? this.approvedBy,
      approvedAt: approvedAt ?? this.approvedAt,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
