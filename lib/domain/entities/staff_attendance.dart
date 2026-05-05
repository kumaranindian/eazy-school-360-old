import 'package:cloud_firestore/cloud_firestore.dart';

/// Staff attendance status enum
enum StaffAttendanceStatus {
  PRESENT,
  ABSENT,
  LEAVE,
  PERMISSION,
  LOP, // Loss of Pay
  HOLIDAY,
  PARTIAL, // Missing logout
}

/// Staff attendance entity
class StaffAttendance {
  final String id;
  final String schoolId;
  final String staffId;
  final String staffName;
  final DateTime date;
  final StaffAttendanceStatus status;
  
  // RFID swipe times
  final DateTime? loginTime;
  final DateTime? logoutTime;
  final bool isLate;
  final int? lateByMinutes;
  
  // Leave/Permission reference
  final String? leaveApplicationId;
  final String? permissionRequestId;
  final String? leaveType;
  
  // Working hours
  final int? workingMinutes;
  final int? permissionMinutes;
  
  // Metadata
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? createdBy;
  final Map<String, dynamic>? metadata;
  
  // RFID swipe records
  final List<RfidSwipe>? swipes;

  const StaffAttendance({
    required this.id,
    required this.schoolId,
    required this.staffId,
    required this.staffName,
    required this.date,
    required this.status,
    this.loginTime,
    this.logoutTime,
    this.isLate = false,
    this.lateByMinutes,
    this.leaveApplicationId,
    this.permissionRequestId,
    this.leaveType,
    this.workingMinutes,
    this.permissionMinutes,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy,
    this.metadata,
    this.swipes,
  });

  factory StaffAttendance.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return StaffAttendance(
      id: doc.id,
      schoolId: data['schoolId'] as String,
      staffId: data['staffId'] as String,
      staffName: data['staffName'] as String? ?? '',
      date: (data['date'] as Timestamp).toDate(),
      status: _parseStatus(data['status']),
      loginTime: data['loginTime'] != null 
          ? (data['loginTime'] as Timestamp).toDate() 
          : null,
      logoutTime: data['logoutTime'] != null 
          ? (data['logoutTime'] as Timestamp).toDate() 
          : null,
      isLate: data['isLate'] as bool? ?? false,
      lateByMinutes: data['lateByMinutes'] as int?,
      leaveApplicationId: data['leaveApplicationId'] as String?,
      permissionRequestId: data['permissionRequestId'] as String?,
      leaveType: data['leaveType'] as String?,
      workingMinutes: data['workingMinutes'] as int?,
      permissionMinutes: data['permissionMinutes'] as int?,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      createdBy: data['createdBy'] as String?,
      metadata: data['metadata'] as Map<String, dynamic>?,
      swipes: data['swipes'] != null
          ? (data['swipes'] as List<dynamic>)
              .map((s) => RfidSwipe.fromMap(s as Map<String, dynamic>))
              .toList()
          : null,
    );
  }

  static StaffAttendanceStatus _parseStatus(dynamic status) {
    if (status == null) return StaffAttendanceStatus.ABSENT;
    switch (status.toString().toUpperCase()) {
      case 'PRESENT':
        return StaffAttendanceStatus.PRESENT;
      case 'ABSENT':
        return StaffAttendanceStatus.ABSENT;
      case 'LEAVE':
        return StaffAttendanceStatus.LEAVE;
      case 'PERMISSION':
        return StaffAttendanceStatus.PERMISSION;
      case 'LOP':
        return StaffAttendanceStatus.LOP;
      case 'HOLIDAY':
        return StaffAttendanceStatus.HOLIDAY;
      case 'PARTIAL':
        return StaffAttendanceStatus.PARTIAL;
      default:
        return StaffAttendanceStatus.ABSENT;
    }
  }

  Map<String, dynamic> toFirestore() {
    return {
      'schoolId': schoolId,
      'staffId': staffId,
      'staffName': staffName,
      'date': Timestamp.fromDate(date),
      'status': status.name,
      if (loginTime != null) 'loginTime': Timestamp.fromDate(loginTime!),
      if (logoutTime != null) 'logoutTime': Timestamp.fromDate(logoutTime!),
      'isLate': isLate,
      if (lateByMinutes != null) 'lateByMinutes': lateByMinutes,
      if (leaveApplicationId != null) 'leaveApplicationId': leaveApplicationId,
      if (permissionRequestId != null) 'permissionRequestId': permissionRequestId,
      if (leaveType != null) 'leaveType': leaveType,
      if (workingMinutes != null) 'workingMinutes': workingMinutes,
      if (permissionMinutes != null) 'permissionMinutes': permissionMinutes,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      if (createdBy != null) 'createdBy': createdBy,
      if (metadata != null) 'metadata': metadata,
      if (swipes != null) 'swipes': swipes!.map((s) => s.toMap()).toList(),
    };
  }

  StaffAttendance copyWith({
    String? id,
    String? schoolId,
    String? staffId,
    String? staffName,
    DateTime? date,
    StaffAttendanceStatus? status,
    DateTime? loginTime,
    DateTime? logoutTime,
    bool? isLate,
    int? lateByMinutes,
    String? leaveApplicationId,
    String? permissionRequestId,
    String? leaveType,
    int? workingMinutes,
    int? permissionMinutes,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    Map<String, dynamic>? metadata,
    List<RfidSwipe>? swipes,
  }) {
    return StaffAttendance(
      id: id ?? this.id,
      schoolId: schoolId ?? this.schoolId,
      staffId: staffId ?? this.staffId,
      staffName: staffName ?? this.staffName,
      date: date ?? this.date,
      status: status ?? this.status,
      loginTime: loginTime ?? this.loginTime,
      logoutTime: logoutTime ?? this.logoutTime,
      isLate: isLate ?? this.isLate,
      lateByMinutes: lateByMinutes ?? this.lateByMinutes,
      leaveApplicationId: leaveApplicationId ?? this.leaveApplicationId,
      permissionRequestId: permissionRequestId ?? this.permissionRequestId,
      leaveType: leaveType ?? this.leaveType,
      workingMinutes: workingMinutes ?? this.workingMinutes,
      permissionMinutes: permissionMinutes ?? this.permissionMinutes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      metadata: metadata ?? this.metadata,
      swipes: swipes ?? this.swipes,
    );
  }

  bool get isPresent => status == StaffAttendanceStatus.PRESENT;
  bool get isAbsent => status == StaffAttendanceStatus.ABSENT;
  bool get isOnLeave => status == StaffAttendanceStatus.LEAVE;
  bool get hasPermission => status == StaffAttendanceStatus.PERMISSION;
  bool get isLOP => status == StaffAttendanceStatus.LOP;
  bool get isHoliday => status == StaffAttendanceStatus.HOLIDAY;
  bool get isPartial => status == StaffAttendanceStatus.PARTIAL;

  String get statusDisplayName {
    switch (status) {
      case StaffAttendanceStatus.PRESENT:
        return 'Present';
      case StaffAttendanceStatus.ABSENT:
        return 'Absent';
      case StaffAttendanceStatus.LEAVE:
        return 'Leave';
      case StaffAttendanceStatus.PERMISSION:
        return 'Permission';
      case StaffAttendanceStatus.LOP:
        return 'LOP';
      case StaffAttendanceStatus.HOLIDAY:
        return 'Holiday';
      case StaffAttendanceStatus.PARTIAL:
        return 'Partial';
    }
  }

  String? get workingHoursDisplay {
    if (workingMinutes == null) return null;
    final hours = workingMinutes! ~/ 60;
    final minutes = workingMinutes! % 60;
    return '${hours}h ${minutes}m';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is StaffAttendance && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// RFID swipe record
class RfidSwipe {
  final String cardUuid;
  final DateTime timestamp;
  final String? deviceId;
  final Map<String, dynamic>? metadata;

  const RfidSwipe({
    required this.cardUuid,
    required this.timestamp,
    this.deviceId,
    this.metadata,
  });

  factory RfidSwipe.fromMap(Map<String, dynamic> data) {
    return RfidSwipe(
      cardUuid: data['cardUuid'] as String,
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      deviceId: data['deviceId'] as String?,
      metadata: data['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'cardUuid': cardUuid,
      'timestamp': Timestamp.fromDate(timestamp),
      if (deviceId != null) 'deviceId': deviceId,
      if (metadata != null) 'metadata': metadata,
    };
  }
}

/// Raw RFID swipe data from ESP32
class RfidSwipeData {
  final String schoolId;
  final String cardUuid;
  final DateTime timestamp;
  final String? deviceId;
  final Map<String, dynamic>? metadata;

  const RfidSwipeData({
    required this.schoolId,
    required this.cardUuid,
    required this.timestamp,
    this.deviceId,
    this.metadata,
  });

  factory RfidSwipeData.fromMap(Map<String, dynamic> data) {
    return RfidSwipeData(
      schoolId: data['schoolId'] as String,
      cardUuid: data['cardUuid'] as String? ?? data['uuid'] as String,
      timestamp: data['timestamp'] is Timestamp
          ? (data['timestamp'] as Timestamp).toDate()
          : DateTime.parse(data['timestamp'] as String),
      deviceId: data['deviceId'] as String?,
      metadata: data['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'schoolId': schoolId,
      'cardUuid': cardUuid,
      'timestamp': Timestamp.fromDate(timestamp),
      if (deviceId != null) 'deviceId': deviceId,
      if (metadata != null) 'metadata': metadata,
    };
  }
}

/// Attendance configuration for a school
class AttendanceConfig {
  final String id;
  final String schoolId;
  final String lateThresholdTime; // e.g., "09:30"
  final int lateGraceMinutes; // Grace period before marking late
  final List<String> workingDays; // ["MONDAY", "TUESDAY", ...]
  final bool autoMarkAbsent; // Auto-mark absent if no swipe
  final bool requireBothSwipes; // Require both login and logout
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;

  const AttendanceConfig({
    required this.id,
    required this.schoolId,
    required this.lateThresholdTime,
    required this.lateGraceMinutes,
    required this.workingDays,
    required this.autoMarkAbsent,
    required this.requireBothSwipes,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
  });

  factory AttendanceConfig.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AttendanceConfig(
      id: doc.id,
      schoolId: data['schoolId'] as String,
      lateThresholdTime: data['lateThresholdTime'] as String? ?? "09:30",
      lateGraceMinutes: (data['lateGraceMinutes'] as num?)?.toInt() ?? 5,
      workingDays: (data['workingDays'] as List<dynamic>?)?.cast<String>() ??
          ['MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY'],
      autoMarkAbsent: data['autoMarkAbsent'] as bool? ?? true,
      requireBothSwipes: data['requireBothSwipes'] as bool? ?? true,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      createdBy: data['createdBy'] as String,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'schoolId': schoolId,
      'lateThresholdTime': lateThresholdTime,
      'lateGraceMinutes': lateGraceMinutes,
      'workingDays': workingDays,
      'autoMarkAbsent': autoMarkAbsent,
      'requireBothSwipes': requireBothSwipes,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'createdBy': createdBy,
    };
  }

  /// Parse late threshold time to DateTime for today
  DateTime getLateThresholdForDate(DateTime date) {
    final parts = lateThresholdTime.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  /// Check if a day is a working day
  bool isWorkingDay(DateTime date) {
    final dayName = _getDayName(date.weekday);
    return workingDays.contains(dayName);
  }

  String _getDayName(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'MONDAY';
      case DateTime.tuesday:
        return 'TUESDAY';
      case DateTime.wednesday:
        return 'WEDNESDAY';
      case DateTime.thursday:
        return 'THURSDAY';
      case DateTime.friday:
        return 'FRIDAY';
      case DateTime.saturday:
        return 'SATURDAY';
      case DateTime.sunday:
        return 'SUNDAY';
      default:
        return '';
    }
  }
}
