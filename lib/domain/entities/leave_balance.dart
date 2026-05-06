import 'package:cloud_firestore/cloud_firestore.dart';

/// Leave balance for a staff member for a specific leave type and academic year
class LeaveBalance {
  final String id;
  final String schoolId;
  final String staffId;
  final String userId;
  final String leaveTypeId;
  final String leaveTypeCode;
  final String academicYear; // Format: "2024-2025"
  final int totalAllowed; // Total quota for the year
  final int used; // Days used in current year
  final int pending; // Days in pending requests
  final int carriedForward; // Days carried from previous year
  final int available; // Calculated: totalAllowed + carriedForward - used - pending
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;
  final Map<String, dynamic>? metadata; // Additional tracking data

  const LeaveBalance({
    required this.id,
    required this.schoolId,
    required this.staffId,
    required this.userId,
    required this.leaveTypeId,
    required this.leaveTypeCode,
    required this.academicYear,
    required this.totalAllowed,
    required this.used,
    required this.pending,
    required this.carriedForward,
    required this.available,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
    this.metadata,
  });

  factory LeaveBalance.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return LeaveBalance(
      id: doc.id,
      schoolId: data['schoolId'] as String,
      staffId: data['staffId'] as String,
      userId: data['userId'] as String,
      leaveTypeId: data['leaveTypeId'] as String,
      leaveTypeCode: data['leaveTypeCode'] as String,
      academicYear: data['academicYear'] as String,
      totalAllowed: (data['totalAllowed'] as num).toInt(),
      used: (data['used'] as num).toInt(),
      pending: (data['pending'] as num).toInt(),
      carriedForward: (data['carriedForward'] as num).toInt(),
      available: (data['available'] as num).toInt(),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      createdBy: data['createdBy'] as String,
      metadata: data['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'schoolId': schoolId,
      'staffId': staffId,
      'userId': userId,
      'leaveTypeId': leaveTypeId,
      'leaveTypeCode': leaveTypeCode,
      'academicYear': academicYear,
      'totalAllowed': totalAllowed,
      'used': used,
      'pending': pending,
      'carriedForward': carriedForward,
      'available': available,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'createdBy': createdBy,
      'metadata': metadata,
    };
  }

  /// Calculate available balance
  static int calculateAvailable(int totalAllowed, int carriedForward, int used, int pending) {
    return totalAllowed + carriedForward - used - pending;
  }

  /// Create a new balance with recalculated available days
  LeaveBalance recalculate() {
    return copyWith(
      available: calculateAvailable(totalAllowed, carriedForward, used, pending),
      updatedAt: DateTime.now(),
    );
  }

  LeaveBalance copyWith({
    String? id,
    String? schoolId,
    String? staffId,
    String? userId,
    String? leaveTypeId,
    String? leaveTypeCode,
    String? academicYear,
    int? totalAllowed,
    int? used,
    int? pending,
    int? carriedForward,
    int? available,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    Map<String, dynamic>? metadata,
  }) {
    return LeaveBalance(
      id: id ?? this.id,
      schoolId: schoolId ?? this.schoolId,
      staffId: staffId ?? this.staffId,
      userId: userId ?? this.userId,
      leaveTypeId: leaveTypeId ?? this.leaveTypeId,
      leaveTypeCode: leaveTypeCode ?? this.leaveTypeCode,
      academicYear: academicYear ?? this.academicYear,
      totalAllowed: totalAllowed ?? this.totalAllowed,
      used: used ?? this.used,
      pending: pending ?? this.pending,
      carriedForward: carriedForward ?? this.carriedForward,
      available: available ?? this.available,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      metadata: metadata ?? this.metadata,
    );
  }

  bool get hasAvailableDays => available > 0;
  bool get isOverdrawn => available < 0;
  double get utilizationPercentage => totalAllowed > 0 ? (used / totalAllowed) * 100 : 0;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LeaveBalance && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'LeaveBalance(id: $id, staffId: $staffId, leaveTypeCode: $leaveTypeCode, available: $available)';
  }
}

/// Academic year utilities
class AcademicYear {
  /// Get current academic year (June 1 to May 31)
  static String getCurrentAcademicYear() {
    final now = DateTime.now();
    final currentYear = now.year;
    
    // If current date is before June 1, we're still in previous academic year
    if (now.month < 6) {
      return '${currentYear - 1}-$currentYear';
    } else {
      return '$currentYear-${currentYear + 1}';
    }
  }

  /// Get academic year for a specific date
  static String getAcademicYearForDate(DateTime date) {
    final year = date.year;
    
    if (date.month < 6) {
      return '${year - 1}-$year';
    } else {
      return '$year-${year + 1}';
    }
  }

  /// Get start date of academic year
  static DateTime getAcademicYearStart(String academicYear) {
    final startYear = int.parse(academicYear.split('-')[0]);
    return DateTime(startYear, 6, 1); // June 1
  }

  /// Get end date of academic year
  static DateTime getAcademicYearEnd(String academicYear) {
    final startYear = int.parse(academicYear.split('-')[0]);
    return DateTime(startYear + 1, 5, 31); // May 31 of next year
  }

  /// Get next academic year
  static String getNextAcademicYear(String currentYear) {
    final startYear = int.parse(currentYear.split('-')[0]);
    final nextStartYear = startYear + 1;
    return '$nextStartYear-${nextStartYear + 1}';
  }

  /// Get previous academic year
  static String getPreviousAcademicYear(String currentYear) {
    final startYear = int.parse(currentYear.split('-')[0]);
    final prevStartYear = startYear - 1;
    return '$prevStartYear-${prevStartYear + 1}';
  }

  /// Check if date falls within academic year
  static bool isDateInAcademicYear(DateTime date, String academicYear) {
    final start = getAcademicYearStart(academicYear);
    final end = getAcademicYearEnd(academicYear);
    return date.isAfter(start.subtract(const Duration(days: 1))) && 
           date.isBefore(end.add(const Duration(days: 1)));
  }
}

/// Balance mutation record for audit trail
class BalanceMutation {
  final String id;
  final String schoolId;
  final String staffId;
  final String userId;
  final String leaveTypeId;
  final String academicYear;
  final String mutationType; // CREATED, USED, PENDING_ADDED, PENDING_REMOVED, CARRY_FORWARD, RESET
  final int previousValue;
  final int newValue;
  final int delta;
  final String? referenceId; // Leave request ID or other reference
  final String reason;
  final DateTime createdAt;
  final String createdBy;
  final Map<String, dynamic>? metadata;

  const BalanceMutation({
    required this.id,
    required this.schoolId,
    required this.staffId,
    required this.userId,
    required this.leaveTypeId,
    required this.academicYear,
    required this.mutationType,
    required this.previousValue,
    required this.newValue,
    required this.delta,
    this.referenceId,
    required this.reason,
    required this.createdAt,
    required this.createdBy,
    this.metadata,
  });

  factory BalanceMutation.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BalanceMutation(
      id: doc.id,
      schoolId: data['schoolId'] as String,
      staffId: data['staffId'] as String,
      userId: data['userId'] as String,
      leaveTypeId: data['leaveTypeId'] as String,
      academicYear: data['academicYear'] as String,
      mutationType: data['mutationType'] as String,
      previousValue: (data['previousValue'] as num).toInt(),
      newValue: (data['newValue'] as num).toInt(),
      delta: (data['delta'] as num).toInt(),
      referenceId: data['referenceId'] as String?,
      reason: data['reason'] as String,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      createdBy: data['createdBy'] as String,
      metadata: data['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'schoolId': schoolId,
      'staffId': staffId,
      'userId': userId,
      'leaveTypeId': leaveTypeId,
      'academicYear': academicYear,
      'mutationType': mutationType,
      'previousValue': previousValue,
      'newValue': newValue,
      'delta': delta,
      'referenceId': referenceId,
      'reason': reason,
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy,
      'metadata': metadata,
    };
  }
}

/// Mutation types for balance changes
class MutationTypes {
  static const String created = 'CREATED';
  static const String used = 'USED';
  static const String pendingAdded = 'PENDING_ADDED';
  static const String pendingRemoved = 'PENDING_REMOVED';
  static const String carryForward = 'CARRY_FORWARD';
  static const String reset = 'RESET';
  static const String adjustment = 'ADJUSTMENT';
}
