import 'package:cloud_firestore/cloud_firestore.dart';

/// Audit log action types
enum AuditActionType {
  LEAVE_APPROVED,
  LEAVE_REJECTED,
  LEAVE_CANCELLED,
  LEAVE_CANCELLATION_APPROVED,
  LEAVE_CANCELLATION_REJECTED,
  PERMISSION_APPROVED,
  PERMISSION_REJECTED,
  PERMISSION_CANCELLED,
  LEAVE_TYPE_CREATED,
  LEAVE_TYPE_UPDATED,
  LEAVE_TYPE_DEACTIVATED,
  PERMISSION_CONFIG_UPDATED,
  HOLIDAY_CREATED,
  HOLIDAY_UPDATED,
  HOLIDAY_DELETED,
  WEEKEND_CONFIG_UPDATED,
  STAFF_CREATED,
  STAFF_UPDATED,
  STAFF_DEACTIVATED,
  BALANCE_ADJUSTED,
  SYSTEM_CONFIG_UPDATED,
}

/// Immutable audit log entry (tenant-scoped)
class AuditLog {
  final String id;
  final String schoolId;
  final String actorUid;
  final String actorRole;
  final String? actorName;
  final AuditActionType actionType;
  final String targetId;
  final String? targetType;
  final String? targetName;
  final DateTime timestamp;
  final String? description;
  final Map<String, dynamic>? beforeData;
  final Map<String, dynamic>? afterData;
  final Map<String, dynamic>? metadata;
  final String? ipAddress;
  final String? userAgent;

  const AuditLog({
    required this.id,
    required this.schoolId,
    required this.actorUid,
    required this.actorRole,
    this.actorName,
    required this.actionType,
    required this.targetId,
    this.targetType,
    this.targetName,
    required this.timestamp,
    this.description,
    this.beforeData,
    this.afterData,
    this.metadata,
    this.ipAddress,
    this.userAgent,
  });

  factory AuditLog.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AuditLog(
      id: doc.id,
      schoolId: data['schoolId'] as String,
      actorUid: data['actorUid'] as String,
      actorRole: data['actorRole'] as String,
      actorName: data['actorName'] as String?,
      actionType: _parseActionType(data['actionType']),
      targetId: data['targetId'] as String,
      targetType: data['targetType'] as String?,
      targetName: data['targetName'] as String?,
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      description: data['description'] as String?,
      beforeData: data['beforeData'] as Map<String, dynamic>?,
      afterData: data['afterData'] as Map<String, dynamic>?,
      metadata: data['metadata'] as Map<String, dynamic>?,
      ipAddress: data['ipAddress'] as String?,
      userAgent: data['userAgent'] as String?,
    );
  }

  static AuditActionType _parseActionType(dynamic actionType) {
    if (actionType == null) return AuditActionType.SYSTEM_CONFIG_UPDATED;
    try {
      return AuditActionType.values.firstWhere(
        (type) => type.name == actionType.toString(),
        orElse: () => AuditActionType.SYSTEM_CONFIG_UPDATED,
      );
    } catch (e) {
      return AuditActionType.SYSTEM_CONFIG_UPDATED;
    }
  }

  Map<String, dynamic> toFirestore() {
    return {
      'schoolId': schoolId,
      'actorUid': actorUid,
      'actorRole': actorRole,
      'actorName': actorName,
      'actionType': actionType.name,
      'targetId': targetId,
      'targetType': targetType,
      'targetName': targetName,
      'timestamp': Timestamp.fromDate(timestamp),
      'description': description,
      'beforeData': beforeData,
      'afterData': afterData,
      'metadata': metadata,
      'ipAddress': ipAddress,
      'userAgent': userAgent,
    };
  }

  String get actionDisplayName {
    switch (actionType) {
      case AuditActionType.LEAVE_APPROVED:
        return 'Leave Approved';
      case AuditActionType.LEAVE_REJECTED:
        return 'Leave Rejected';
      case AuditActionType.LEAVE_CANCELLED:
        return 'Leave Cancelled';
      case AuditActionType.LEAVE_CANCELLATION_APPROVED:
        return 'Leave Cancellation Approved';
      case AuditActionType.LEAVE_CANCELLATION_REJECTED:
        return 'Leave Cancellation Rejected';
      case AuditActionType.PERMISSION_APPROVED:
        return 'Permission Approved';
      case AuditActionType.PERMISSION_REJECTED:
        return 'Permission Rejected';
      case AuditActionType.PERMISSION_CANCELLED:
        return 'Permission Cancelled';
      case AuditActionType.LEAVE_TYPE_CREATED:
        return 'Leave Type Created';
      case AuditActionType.LEAVE_TYPE_UPDATED:
        return 'Leave Type Updated';
      case AuditActionType.LEAVE_TYPE_DEACTIVATED:
        return 'Leave Type Deactivated';
      case AuditActionType.PERMISSION_CONFIG_UPDATED:
        return 'Permission Config Updated';
      case AuditActionType.HOLIDAY_CREATED:
        return 'Holiday Created';
      case AuditActionType.HOLIDAY_UPDATED:
        return 'Holiday Updated';
      case AuditActionType.HOLIDAY_DELETED:
        return 'Holiday Deleted';
      case AuditActionType.WEEKEND_CONFIG_UPDATED:
        return 'Weekend Config Updated';
      case AuditActionType.STAFF_CREATED:
        return 'Staff Created';
      case AuditActionType.STAFF_UPDATED:
        return 'Staff Updated';
      case AuditActionType.STAFF_DEACTIVATED:
        return 'Staff Deactivated';
      case AuditActionType.BALANCE_ADJUSTED:
        return 'Balance Adjusted';
      case AuditActionType.SYSTEM_CONFIG_UPDATED:
        return 'System Config Updated';
    }
  }

  String get timestampDisplayText {
    return '${timestamp.day}/${timestamp.month}/${timestamp.year} ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AuditLog && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'AuditLog(id: $id, actionType: ${actionType.name}, actorRole: $actorRole, timestamp: $timestampDisplayText)';
  }
}

/// In-app notification entity (tenant-scoped)
class InAppNotification {
  final String id;
  final String schoolId;
  final String recipientUid;
  final String recipientRole;
  final String title;
  final String message;
  final String? actionType;
  final String? actionTargetId;
  final bool isRead;
  final DateTime createdAt;
  final DateTime? readAt;
  final Map<String, dynamic>? metadata;

  const InAppNotification({
    required this.id,
    required this.schoolId,
    required this.recipientUid,
    required this.recipientRole,
    required this.title,
    required this.message,
    this.actionType,
    this.actionTargetId,
    required this.isRead,
    required this.createdAt,
    this.readAt,
    this.metadata,
  });

  factory InAppNotification.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return InAppNotification(
      id: doc.id,
      schoolId: data['schoolId'] as String,
      recipientUid: data['recipientUid'] as String,
      recipientRole: data['recipientRole'] as String,
      title: data['title'] as String,
      message: data['message'] as String,
      actionType: data['actionType'] as String?,
      actionTargetId: data['actionTargetId'] as String?,
      isRead: data['isRead'] as bool? ?? false,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      readAt: data['readAt'] != null ? (data['readAt'] as Timestamp).toDate() : null,
      metadata: data['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'schoolId': schoolId,
      'recipientUid': recipientUid,
      'recipientRole': recipientRole,
      'title': title,
      'message': message,
      'actionType': actionType,
      'actionTargetId': actionTargetId,
      'isRead': isRead,
      'createdAt': Timestamp.fromDate(createdAt),
      'readAt': readAt != null ? Timestamp.fromDate(readAt!) : null,
      'metadata': metadata,
    };
  }

  InAppNotification copyWith({
    bool? isRead,
    DateTime? readAt,
  }) {
    return InAppNotification(
      id: id,
      schoolId: schoolId,
      recipientUid: recipientUid,
      recipientRole: recipientRole,
      title: title,
      message: message,
      actionType: actionType,
      actionTargetId: actionTargetId,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
      readAt: readAt ?? this.readAt,
      metadata: metadata,
    );
  }

  String get timeAgoText {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is InAppNotification && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Dashboard statistics entity
class DashboardStats {
  final String schoolId;
  final int pendingLeaveApprovals;
  final int pendingPermissionApprovals;
  final int staffOnLeaveToday;
  final int totalStaff;
  final Map<String, int> monthlyLeaveStats;
  final Map<String, int> monthlyPermissionStats;
  final DateTime lastUpdated;

  const DashboardStats({
    required this.schoolId,
    required this.pendingLeaveApprovals,
    required this.pendingPermissionApprovals,
    required this.staffOnLeaveToday,
    required this.totalStaff,
    required this.monthlyLeaveStats,
    required this.monthlyPermissionStats,
    required this.lastUpdated,
  });

  factory DashboardStats.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DashboardStats(
      schoolId: data['schoolId'] as String,
      pendingLeaveApprovals: (data['pendingLeaveApprovals'] as num?)?.toInt() ?? 0,
      pendingPermissionApprovals: (data['pendingPermissionApprovals'] as num?)?.toInt() ?? 0,
      staffOnLeaveToday: (data['staffOnLeaveToday'] as num?)?.toInt() ?? 0,
      totalStaff: (data['totalStaff'] as num?)?.toInt() ?? 0,
      monthlyLeaveStats: Map<String, int>.from(data['monthlyLeaveStats'] as Map? ?? {}),
      monthlyPermissionStats: Map<String, int>.from(data['monthlyPermissionStats'] as Map? ?? {}),
      lastUpdated: (data['lastUpdated'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'schoolId': schoolId,
      'pendingLeaveApprovals': pendingLeaveApprovals,
      'pendingPermissionApprovals': pendingPermissionApprovals,
      'staffOnLeaveToday': staffOnLeaveToday,
      'totalStaff': totalStaff,
      'monthlyLeaveStats': monthlyLeaveStats,
      'monthlyPermissionStats': monthlyPermissionStats,
      'lastUpdated': Timestamp.fromDate(lastUpdated),
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DashboardStats && other.schoolId == schoolId;
  }

  @override
  int get hashCode => schoolId.hashCode;
}

/// Staff dashboard data entity
class StaffDashboardData {
  final String staffId;
  final String schoolId;
  final Map<String, dynamic> leaveBalances; // leaveTypeId -> balance data
  final int currentMonthPermissions;
  final int permissionLimit;
  final List<Map<String, dynamic>> recentRequests;
  final List<Map<String, dynamic>> upcomingHolidays;
  final DateTime lastUpdated;

  const StaffDashboardData({
    required this.staffId,
    required this.schoolId,
    required this.leaveBalances,
    required this.currentMonthPermissions,
    required this.permissionLimit,
    required this.recentRequests,
    required this.upcomingHolidays,
    required this.lastUpdated,
  });

  factory StaffDashboardData.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return StaffDashboardData(
      staffId: data['staffId'] as String,
      schoolId: data['schoolId'] as String,
      leaveBalances: Map<String, dynamic>.from(data['leaveBalances'] as Map? ?? {}),
      currentMonthPermissions: (data['currentMonthPermissions'] as num?)?.toInt() ?? 0,
      permissionLimit: (data['permissionLimit'] as num?)?.toInt() ?? 0,
      recentRequests: List<Map<String, dynamic>>.from(data['recentRequests'] as List? ?? []),
      upcomingHolidays: List<Map<String, dynamic>>.from(data['upcomingHolidays'] as List? ?? []),
      lastUpdated: (data['lastUpdated'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'staffId': staffId,
      'schoolId': schoolId,
      'leaveBalances': leaveBalances,
      'currentMonthPermissions': currentMonthPermissions,
      'permissionLimit': permissionLimit,
      'recentRequests': recentRequests,
      'upcomingHolidays': upcomingHolidays,
      'lastUpdated': Timestamp.fromDate(lastUpdated),
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is StaffDashboardData && other.staffId == staffId;
  }

  @override
  int get hashCode => staffId.hashCode;
}
