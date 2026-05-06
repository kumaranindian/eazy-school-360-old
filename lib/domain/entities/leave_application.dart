import 'package:cloud_firestore/cloud_firestore.dart';

/// Leave application status enum
enum LeaveApplicationStatus {
  PENDING,
  APPROVED,
  REJECTED,
  CANCELLED,
}

/// Leave application entity
class LeaveApplication {
  final String id;
  final String schoolId;
  final String applicantId; // User ID of the applicant
  final String staffId; // Staff profile ID
  final String? staffName; // Staff name for display
  final String leaveTypeId;
  final String leaveTypeCode;
  final String academicYear;
  final DateTime startDate;
  final DateTime endDate;
  final List<DateTime> leaveDates; // Actual leave dates (excluding weekends/holidays)
  final int totalDays; // Number of working days
  final String reason;
  final LeaveApplicationStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? approvedBy;
  final DateTime? approvedAt;
  final String? rejectionReason;
  final String? remarks;
  final Map<String, dynamic>? metadata;

  const LeaveApplication({
    required this.id,
    required this.schoolId,
    required this.applicantId,
    required this.staffId,
    this.staffName,
    required this.leaveTypeId,
    required this.leaveTypeCode,
    required this.academicYear,
    required this.startDate,
    required this.endDate,
    required this.leaveDates,
    required this.totalDays,
    required this.reason,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.approvedBy,
    this.approvedAt,
    this.rejectionReason,
    this.remarks,
    this.metadata,
  });

  factory LeaveApplication.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return LeaveApplication(
      id: doc.id,
      schoolId: data['schoolId'] as String,
      applicantId: data['applicantId'] as String,
      staffId: data['staffId'] as String,
      staffName: data['staffName'] as String?,
      leaveTypeId: data['leaveTypeId'] as String,
      leaveTypeCode: data['leaveTypeCode'] as String,
      academicYear: data['academicYear'] as String,
      startDate: (data['startDate'] as Timestamp).toDate(),
      endDate: (data['endDate'] as Timestamp).toDate(),
      leaveDates: (data['leaveDates'] as List<dynamic>)
          .map((timestamp) => (timestamp as Timestamp).toDate())
          .toList(),
      totalDays: (data['totalDays'] as num).toInt(),
      reason: data['reason'] as String,
      status: _parseStatus(data['status']),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      approvedBy: data['approvedBy'] as String?,
      approvedAt: data['approvedAt'] != null 
          ? (data['approvedAt'] as Timestamp).toDate() 
          : null,
      rejectionReason: data['rejectionReason'] as String?,
      remarks: data['remarks'] as String?,
      metadata: data['metadata'] as Map<String, dynamic>?,
    );
  }

  static LeaveApplicationStatus _parseStatus(dynamic status) {
    if (status == null) return LeaveApplicationStatus.PENDING;
    switch (status.toString().toUpperCase()) {
      case 'PENDING':
        return LeaveApplicationStatus.PENDING;
      case 'APPROVED':
        return LeaveApplicationStatus.APPROVED;
      case 'REJECTED':
        return LeaveApplicationStatus.REJECTED;
      case 'CANCELLED':
        return LeaveApplicationStatus.CANCELLED;
      default:
        return LeaveApplicationStatus.PENDING;
    }
  }

  Map<String, dynamic> toFirestore() {
    return {
      'schoolId': schoolId,
      'applicantId': applicantId,
      'staffId': staffId,
      'leaveTypeId': leaveTypeId,
      'leaveTypeCode': leaveTypeCode,
      'academicYear': academicYear,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'leaveDates': leaveDates.map((date) => Timestamp.fromDate(date)).toList(),
      'totalDays': totalDays,
      'reason': reason,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'approvedBy': approvedBy,
      'approvedAt': approvedAt != null ? Timestamp.fromDate(approvedAt!) : null,
      'rejectionReason': rejectionReason,
      'remarks': remarks,
      'metadata': metadata,
      'staffName': staffName,
    };
  }

  LeaveApplication copyWith({
    String? id,
    String? schoolId,
    String? applicantId,
    String? staffId,
    String? staffName,
    String? leaveTypeId,
    String? leaveTypeCode,
    String? academicYear,
    DateTime? startDate,
    DateTime? endDate,
    List<DateTime>? leaveDates,
    int? totalDays,
    String? reason,
    LeaveApplicationStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? approvedBy,
    DateTime? approvedAt,
    String? rejectionReason,
    String? remarks,
    Map<String, dynamic>? metadata,
  }) {
    return LeaveApplication(
      id: id ?? this.id,
      schoolId: schoolId ?? this.schoolId,
      applicantId: applicantId ?? this.applicantId,
      staffId: staffId ?? this.staffId,
      staffName: staffName ?? this.staffName,
      leaveTypeId: leaveTypeId ?? this.leaveTypeId,
      leaveTypeCode: leaveTypeCode ?? this.leaveTypeCode,
      academicYear: academicYear ?? this.academicYear,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      leaveDates: leaveDates ?? this.leaveDates,
      totalDays: totalDays ?? this.totalDays,
      reason: reason ?? this.reason,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      approvedBy: approvedBy ?? this.approvedBy,
      approvedAt: approvedAt ?? this.approvedAt,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      remarks: remarks ?? this.remarks,
      metadata: metadata ?? this.metadata,
    );
  }

  bool get isPending => status == LeaveApplicationStatus.PENDING;
  bool get isApproved => status == LeaveApplicationStatus.APPROVED;
  bool get isRejected => status == LeaveApplicationStatus.REJECTED;
  bool get isCancelled => status == LeaveApplicationStatus.CANCELLED;
  bool get canBeCancelled => status == LeaveApplicationStatus.PENDING;
  bool get canBeApproved => status == LeaveApplicationStatus.PENDING;
  bool get isActive => status == LeaveApplicationStatus.APPROVED;

  String get statusDisplayName {
    switch (status) {
      case LeaveApplicationStatus.PENDING:
        return 'Pending';
      case LeaveApplicationStatus.APPROVED:
        return 'Approved';
      case LeaveApplicationStatus.REJECTED:
        return 'Rejected';
      case LeaveApplicationStatus.CANCELLED:
        return 'Cancelled';
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LeaveApplication && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'LeaveApplication(id: $id, applicantId: $applicantId, status: $status, totalDays: $totalDays)';
  }
}

/// Request model for creating leave application
class CreateLeaveApplicationRequest {
  final String leaveTypeId;
  final DateTime startDate;
  final DateTime endDate;
  final String reason;
  final String? remarks;

  const CreateLeaveApplicationRequest({
    required this.leaveTypeId,
    required this.startDate,
    required this.endDate,
    required this.reason,
    this.remarks,
  });

  Map<String, dynamic> toMap() {
    return {
      'leaveTypeId': leaveTypeId,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'reason': reason,
      'remarks': remarks,
    };
  }
}

/// Request model for approving/rejecting leave application
class LeaveApprovalRequest {
  final LeaveApplicationStatus status;
  final String? rejectionReason;
  final String? remarks;

  const LeaveApprovalRequest({
    required this.status,
    this.rejectionReason,
    this.remarks,
  });

  Map<String, dynamic> toMap() {
    return {
      'status': status.name,
      'rejectionReason': rejectionReason,
      'remarks': remarks,
    };
  }
}

/// Holiday configuration for leave calculation
class Holiday {
  final String id;
  final String schoolId;
  final DateTime date;
  final String name;
  final String description;
  final bool isRecurring;
  final String? recurringType; // YEARLY, MONTHLY
  final bool isActive;

  const Holiday({
    required this.id,
    required this.schoolId,
    required this.date,
    required this.name,
    required this.description,
    required this.isRecurring,
    this.recurringType,
    required this.isActive,
  });

  factory Holiday.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    // Support both legacy (name) and new (title) fields
    final resolvedName = (data['name'] as String?) ?? (data['title'] as String?) ?? '';
    // Derive schoolId from path if missing in document
    final resolvedSchoolId = (data['schoolId'] as String?) ?? doc.reference.parent.parent?.id ?? '';
    return Holiday(
      id: doc.id,
      schoolId: resolvedSchoolId,
      date: (data['date'] as Timestamp).toDate(),
      name: resolvedName,
      description: data['description'] as String? ?? '',
      isRecurring: data['isRecurring'] as bool? ?? false,
      recurringType: data['recurringType'] as String?,
      isActive: data['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'schoolId': schoolId,
      'date': Timestamp.fromDate(date),
      'name': name,
      'description': description,
      'isRecurring': isRecurring,
      'recurringType': recurringType,
      'isActive': isActive,
    };
  }
}

/// Utility class for leave date calculations
class LeaveDateCalculator {
  /// Calculate working days between start and end date, excluding weekends and holidays
  static List<DateTime> calculateLeaveDates(
    DateTime startDate,
    DateTime endDate,
    List<Holiday> holidays,
  ) {
    final leaveDates = <DateTime>[];
    final holidayDates = holidays
        .where((h) => h.isActive)
        .map((h) => DateTime(h.date.year, h.date.month, h.date.day))
        .toSet();

    DateTime currentDate = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);

    while (currentDate.isBefore(end) || currentDate.isAtSameMomentAs(end)) {
      // Skip weekends (Saturday = 6, Sunday = 7)
      if (currentDate.weekday != DateTime.saturday && 
          currentDate.weekday != DateTime.sunday) {
        // Skip holidays
        if (!holidayDates.contains(currentDate)) {
          leaveDates.add(currentDate);
        }
      }
      currentDate = currentDate.add(const Duration(days: 1));
    }

    return leaveDates;
  }

  /// Check if there are overlapping leave dates with existing applications
  static bool hasOverlappingLeaves(
    List<DateTime> newLeaveDates,
    List<LeaveApplication> existingApplications,
  ) {
    final existingDates = <DateTime>{};
    
    for (final application in existingApplications) {
      if (application.isApproved || application.isPending) {
        existingDates.addAll(application.leaveDates.map(
          (date) => DateTime(date.year, date.month, date.day),
        ));
      }
    }

    for (final date in newLeaveDates) {
      final normalizedDate = DateTime(date.year, date.month, date.day);
      if (existingDates.contains(normalizedDate)) {
        return true;
      }
    }

    return false;
  }

  /// Get overlapping dates between new leave and existing applications
  static List<DateTime> getOverlappingDates(
    List<DateTime> newLeaveDates,
    List<LeaveApplication> existingApplications,
  ) {
    final existingDates = <DateTime>{};
    final overlappingDates = <DateTime>[];
    
    for (final application in existingApplications) {
      if (application.isApproved || application.isPending) {
        existingDates.addAll(application.leaveDates.map(
          (date) => DateTime(date.year, date.month, date.day),
        ));
      }
    }

    for (final date in newLeaveDates) {
      final normalizedDate = DateTime(date.year, date.month, date.day);
      if (existingDates.contains(normalizedDate)) {
        overlappingDates.add(normalizedDate);
      }
    }

    return overlappingDates;
  }

  /// Validate leave application dates
  static String? validateLeaveDates(
    DateTime startDate,
    DateTime endDate,
    List<Holiday> holidays,
    List<LeaveApplication> existingApplications,
  ) {
    // Check if start date is not in the past (allow same day)
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final startDateOnly = DateTime(startDate.year, startDate.month, startDate.day);
    
    if (startDateOnly.isBefore(todayDate)) {
      return 'Start date cannot be in the past';
    }

    // Check if end date is after start date
    if (endDate.isBefore(startDate)) {
      return 'End date must be after start date';
    }

    // Calculate leave dates
    final leaveDates = calculateLeaveDates(startDate, endDate, holidays);
    
    if (leaveDates.isEmpty) {
      return 'No working days found in the selected date range';
    }

    // Check for overlapping leaves
    if (hasOverlappingLeaves(leaveDates, existingApplications)) {
      final overlappingDates = getOverlappingDates(leaveDates, existingApplications);
      final dateStrings = overlappingDates.map((d) => '${d.day}/${d.month}/${d.year}').join(', ');
      return 'Leave request overlaps with existing applications on: $dateStrings';
    }

    return null; // No validation errors
  }
}
