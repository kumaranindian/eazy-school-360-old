import 'package:cloud_firestore/cloud_firestore.dart';

/// Permission request status enum
enum PermissionRequestStatus {
  PENDING,
  APPROVED,
  REJECTED,
  CANCELLED,
}

/// Permission request entity
class PermissionRequest {
  final String id;
  final String schoolId;
  final String applicantId; // User ID of the applicant
  final String staffId; // Staff profile ID
  final String permissionTypeId; // Selected permission type ID
  final DateTime requestDate;
  final DateTime startTime;
  final DateTime endTime;
  final int durationMinutes; // Duration in minutes
  final String reason;
  final PermissionRequestStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? approvedBy;
  final DateTime? approvedAt;
  final String? rejectionReason;
  final String? remarks;
  final Map<String, dynamic>? metadata;

  const PermissionRequest({
    required this.id,
    required this.schoolId,
    required this.applicantId,
    required this.staffId,
    required this.permissionTypeId,
    required this.requestDate,
    required this.startTime,
    required this.endTime,
    required this.durationMinutes,
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

  factory PermissionRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PermissionRequest(
      id: doc.id,
      schoolId: data['schoolId'] as String,
      applicantId: data['applicantId'] as String,
      staffId: data['staffId'] as String,
      permissionTypeId: data['permissionTypeId'] as String? ?? '',
      requestDate: (data['requestDate'] as Timestamp).toDate(),
      startTime: (data['startTime'] as Timestamp).toDate(),
      endTime: (data['endTime'] as Timestamp).toDate(),
      durationMinutes: (data['durationMinutes'] as num).toInt(),
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

  static PermissionRequestStatus _parseStatus(dynamic status) {
    if (status == null) return PermissionRequestStatus.PENDING;
    switch (status.toString().toUpperCase()) {
      case 'PENDING':
        return PermissionRequestStatus.PENDING;
      case 'APPROVED':
        return PermissionRequestStatus.APPROVED;
      case 'REJECTED':
        return PermissionRequestStatus.REJECTED;
      case 'CANCELLED':
        return PermissionRequestStatus.CANCELLED;
      default:
        return PermissionRequestStatus.PENDING;
    }
  }

  Map<String, dynamic> toFirestore() {
    return {
      'schoolId': schoolId,
      'applicantId': applicantId,
      'staffId': staffId,
      'permissionTypeId': permissionTypeId,
      'requestDate': Timestamp.fromDate(requestDate),
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'durationMinutes': durationMinutes,
      'reason': reason,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'approvedBy': approvedBy,
      'approvedAt': approvedAt != null ? Timestamp.fromDate(approvedAt!) : null,
      'rejectionReason': rejectionReason,
      'remarks': remarks,
      'metadata': metadata,
    };
  }

  bool get isPending => status == PermissionRequestStatus.PENDING;
  bool get isApproved => status == PermissionRequestStatus.APPROVED;
  bool get isRejected => status == PermissionRequestStatus.REJECTED;
  bool get isCancelled => status == PermissionRequestStatus.CANCELLED;
  bool get canBeCancelled => status == PermissionRequestStatus.PENDING;
  bool get canBeApproved => status == PermissionRequestStatus.PENDING;
  bool get isActive => status == PermissionRequestStatus.APPROVED;

  String get statusDisplayName {
    switch (status) {
      case PermissionRequestStatus.PENDING:
        return 'Pending';
      case PermissionRequestStatus.APPROVED:
        return 'Approved';
      case PermissionRequestStatus.REJECTED:
        return 'Rejected';
      case PermissionRequestStatus.CANCELLED:
        return 'Cancelled';
    }
  }

  String get durationDisplayText {
    final hours = durationMinutes ~/ 60;
    final minutes = durationMinutes % 60;
    
    if (hours > 0 && minutes > 0) {
      return '${hours}h ${minutes}m';
    } else if (hours > 0) {
      return '${hours}h';
    } else {
      return '${minutes}m';
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PermissionRequest && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'PermissionRequest(id: $id, applicantId: $applicantId, status: $status, duration: ${durationDisplayText})';
  }
}

/// Permission configuration for a school
class PermissionConfig {
  final String id;
  final String schoolId;
  final int monthlyLimit; // Maximum permissions per month
  final int maxDurationMinutes; // Maximum duration per permission in minutes
  final bool requiresApproval; // Whether permissions require admin approval
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;
  final Map<String, dynamic>? customRules;

  const PermissionConfig({
    required this.id,
    required this.schoolId,
    required this.monthlyLimit,
    required this.maxDurationMinutes,
    required this.requiresApproval,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
    this.customRules,
  });

  factory PermissionConfig.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PermissionConfig(
      id: doc.id,
      schoolId: data['schoolId'] as String,
      monthlyLimit: (data['monthlyLimit'] as num).toInt(),
      maxDurationMinutes: (data['maxDurationMinutes'] as num).toInt(),
      requiresApproval: data['requiresApproval'] as bool? ?? true,
      isActive: data['isActive'] as bool? ?? true,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      createdBy: data['createdBy'] as String,
      customRules: data['customRules'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'schoolId': schoolId,
      'monthlyLimit': monthlyLimit,
      'maxDurationMinutes': maxDurationMinutes,
      'requiresApproval': requiresApproval,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'createdBy': createdBy,
      'customRules': customRules,
    };
  }

  String get maxDurationDisplayText {
    final hours = maxDurationMinutes ~/ 60;
    final minutes = maxDurationMinutes % 60;
    
    if (hours > 0 && minutes > 0) {
      return '${hours}h ${minutes}m';
    } else if (hours > 0) {
      return '${hours}h';
    } else {
      return '${minutes}m';
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PermissionConfig && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Monthly permission usage tracking
class MonthlyPermissionUsage {
  final String id;
  final String schoolId;
  final String staffId;
  final String userId;
  final String month; // Format: "2024-12"
  final int totalRequests; // Total permission requests in the month
  final int approvedRequests; // Approved permission requests
  final int totalMinutesUsed; // Total minutes of approved permissions
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic>? metadata;

  const MonthlyPermissionUsage({
    required this.id,
    required this.schoolId,
    required this.staffId,
    required this.userId,
    required this.month,
    required this.totalRequests,
    required this.approvedRequests,
    required this.totalMinutesUsed,
    required this.createdAt,
    required this.updatedAt,
    this.metadata,
  });

  factory MonthlyPermissionUsage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MonthlyPermissionUsage(
      id: doc.id,
      schoolId: data['schoolId'] as String,
      staffId: data['staffId'] as String,
      userId: data['userId'] as String,
      month: data['month'] as String,
      totalRequests: (data['totalRequests'] as num).toInt(),
      approvedRequests: (data['approvedRequests'] as num).toInt(),
      totalMinutesUsed: (data['totalMinutesUsed'] as num).toInt(),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      metadata: data['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'schoolId': schoolId,
      'staffId': staffId,
      'userId': userId,
      'month': month,
      'totalRequests': totalRequests,
      'approvedRequests': approvedRequests,
      'totalMinutesUsed': totalMinutesUsed,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'metadata': metadata,
    };
  }

  String get totalTimeUsedDisplayText {
    final hours = totalMinutesUsed ~/ 60;
    final minutes = totalMinutesUsed % 60;
    
    if (hours > 0 && minutes > 0) {
      return '${hours}h ${minutes}m';
    } else if (hours > 0) {
      return '${hours}h';
    } else {
      return '${minutes}m';
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MonthlyPermissionUsage && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Request model for creating permission request
class CreatePermissionRequest {
  final DateTime requestDate;
  final DateTime startTime;
  final DateTime endTime;
  final String permissionTypeId;
  final String reason;
  final String? remarks;

  const CreatePermissionRequest({
    required this.requestDate,
    required this.startTime,
    required this.endTime,
    required this.permissionTypeId,
    required this.reason,
    this.remarks,
  });

  int get durationMinutes {
    return endTime.difference(startTime).inMinutes;
  }

  Map<String, dynamic> toMap() {
    return {
      'requestDate': requestDate.toIso8601String(),
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'reason': reason,
      'remarks': remarks,
    };
  }
}

/// Request model for approving/rejecting permission request
class PermissionApprovalRequest {
  final PermissionRequestStatus status;
  final String? rejectionReason;
  final String? remarks;

  const PermissionApprovalRequest({
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

/// Utility class for permission calculations
class PermissionCalculator {
  /// Get current month string in format "YYYY-MM"
  static String getCurrentMonth() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  /// Get month string for a specific date
  static String getMonthForDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}';
  }

  /// Calculate duration in minutes between two times
  static int calculateDurationMinutes(DateTime startTime, DateTime endTime) {
    return endTime.difference(startTime).inMinutes;
  }

  /// Validate permission request timing
  static String? validatePermissionTiming(
    DateTime requestDate,
    DateTime startTime,
    DateTime endTime,
    PermissionConfig config,
  ) {
    // Check if request date is not in the past
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final requestDateOnly = DateTime(requestDate.year, requestDate.month, requestDate.day);
    
    if (requestDateOnly.isBefore(todayDate)) {
      return 'Permission date cannot be in the past';
    }

    // Check if end time is after start time
    if (endTime.isBefore(startTime) || endTime.isAtSameMomentAs(startTime)) {
      return 'End time must be after start time';
    }

    // Check duration limits
    final durationMinutes = calculateDurationMinutes(startTime, endTime);
    if (durationMinutes > config.maxDurationMinutes) {
      final maxHours = config.maxDurationMinutes ~/ 60;
      final maxMins = config.maxDurationMinutes % 60;
      String maxDurationText;
      if (maxHours > 0 && maxMins > 0) {
        maxDurationText = '${maxHours}h ${maxMins}m';
      } else if (maxHours > 0) {
        maxDurationText = '${maxHours}h';
      } else {
        maxDurationText = '${maxMins}m';
      }
      return 'Permission duration exceeds maximum allowed ($maxDurationText)';
    }

    // Check if times are on the same date as request date
    final startDate = DateTime(startTime.year, startTime.month, startTime.day);
    final endDate = DateTime(endTime.year, endTime.month, endTime.day);
    
    if (!startDate.isAtSameMomentAs(requestDateOnly) || !endDate.isAtSameMomentAs(requestDateOnly)) {
      return 'Start and end times must be on the same date as the permission date';
    }

    return null; // No validation errors
  }

  /// Check if monthly limit is exceeded
  static bool isMonthlyLimitExceeded(
    int currentMonthRequests,
    PermissionConfig config,
  ) {
    return currentMonthRequests >= config.monthlyLimit;
  }
}
