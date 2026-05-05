import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/staff_attendance.dart';

class StaffAttendanceRepository {
  final FirebaseFirestore _firestore;

  StaffAttendanceRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Get attendance for a specific staff member and date range
  Stream<List<StaffAttendance>> getStaffAttendance({
    required String schoolId,
    required String staffId,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    final startDateOnly = DateTime(startDate.year, startDate.month, startDate.day);
    final endDateOnly = DateTime(endDate.year, endDate.month, endDate.day);

    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('staffAttendance')
        .where('staffId', isEqualTo: staffId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDateOnly))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDateOnly))
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => StaffAttendance.fromFirestore(doc))
            .toList());
  }

  /// Get attendance for all staff on a specific date
  Stream<List<StaffAttendance>> getAllStaffAttendanceForDate({
    required String schoolId,
    required DateTime date,
  }) {
    final dateOnly = DateTime(date.year, date.month, date.day);

    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('staffAttendance')
        .where('date', isEqualTo: Timestamp.fromDate(dateOnly))
        .orderBy('staffName')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => StaffAttendance.fromFirestore(doc))
            .toList());
  }

  /// Get attendance for a specific staff member and month
  Stream<List<StaffAttendance>> getMonthlyAttendance({
    required String schoolId,
    required String staffId,
    required int year,
    required int month,
  }) {
    final startDate = DateTime(year, month, 1);
    final endDate = DateTime(year, month + 1, 0);

    return getStaffAttendance(
      schoolId: schoolId,
      staffId: staffId,
      startDate: startDate,
      endDate: endDate,
    );
  }

  /// Get single attendance record
  Future<StaffAttendance?> getAttendanceForDate({
    required String schoolId,
    required String staffId,
    required DateTime date,
  }) async {
    final dateStr = date.toIso8601String().split('T')[0];
    final attendanceId = '${staffId}_$dateStr';

    final doc = await _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('staffAttendance')
        .doc(attendanceId)
        .get();

    if (!doc.exists) return null;
    return StaffAttendance.fromFirestore(doc);
  }

  /// Get attendance statistics for a staff member
  Future<AttendanceStatistics> getAttendanceStatistics({
    required String schoolId,
    required String staffId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final startDateOnly = DateTime(startDate.year, startDate.month, startDate.day);
    final endDateOnly = DateTime(endDate.year, endDate.month, endDate.day);

    final snapshot = await _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('staffAttendance')
        .where('staffId', isEqualTo: staffId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDateOnly))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDateOnly))
        .get();

    int presentCount = 0;
    int absentCount = 0;
    int leaveCount = 0;
    int permissionCount = 0;
    int lopCount = 0;
    int holidayCount = 0;
    int partialCount = 0;
    int lateCount = 0;
    int totalLateMinutes = 0;

    for (final doc in snapshot.docs) {
      final attendance = StaffAttendance.fromFirestore(doc);
      
      switch (attendance.status) {
        case StaffAttendanceStatus.PRESENT:
          presentCount++;
          break;
        case StaffAttendanceStatus.ABSENT:
          absentCount++;
          break;
        case StaffAttendanceStatus.LEAVE:
          leaveCount++;
          break;
        case StaffAttendanceStatus.PERMISSION:
          permissionCount++;
          break;
        case StaffAttendanceStatus.LOP:
          lopCount++;
          break;
        case StaffAttendanceStatus.HOLIDAY:
          holidayCount++;
          break;
        case StaffAttendanceStatus.PARTIAL:
          partialCount++;
          break;
      }

      if (attendance.isLate) {
        lateCount++;
        totalLateMinutes += attendance.lateByMinutes ?? 0;
      }
    }

    return AttendanceStatistics(
      totalDays: snapshot.docs.length,
      presentCount: presentCount,
      absentCount: absentCount,
      leaveCount: leaveCount,
      permissionCount: permissionCount,
      lopCount: lopCount,
      holidayCount: holidayCount,
      partialCount: partialCount,
      lateCount: lateCount,
      averageLateMinutes: lateCount > 0 ? totalLateMinutes / lateCount : 0,
    );
  }

  /// Get attendance config for a school
  Future<AttendanceConfig?> getAttendanceConfig(String schoolId) async {
    final doc = await _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('attendanceConfig')
        .doc('default')
        .get();

    if (!doc.exists) return null;
    return AttendanceConfig.fromFirestore(doc);
  }

  /// Update attendance config
  Future<void> updateAttendanceConfig({
    required String schoolId,
    required AttendanceConfig config,
  }) async {
    await _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('attendanceConfig')
        .doc('default')
        .set(config.toFirestore(), SetOptions(merge: true));
  }

  /// Create or update attendance config
  Future<void> createAttendanceConfig({
    required String schoolId,
    required String lateThresholdTime,
    required int lateGraceMinutes,
    required List<String> workingDays,
    required bool autoMarkAbsent,
    required bool requireBothSwipes,
    required String createdBy,
  }) async {
    final config = AttendanceConfig(
      id: 'default',
      schoolId: schoolId,
      lateThresholdTime: lateThresholdTime,
      lateGraceMinutes: lateGraceMinutes,
      workingDays: workingDays,
      autoMarkAbsent: autoMarkAbsent,
      requireBothSwipes: requireBothSwipes,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      createdBy: createdBy,
    );

    await _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('attendanceConfig')
        .doc('default')
        .set(config.toFirestore());
  }

  /// Manual attendance marking (for corrections)
  Future<void> markManualAttendance({
    required String schoolId,
    required String staffId,
    required String staffName,
    required DateTime date,
    required StaffAttendanceStatus status,
    DateTime? loginTime,
    DateTime? logoutTime,
    String? remarks,
    required String markedBy,
  }) async {
    final dateStr = date.toIso8601String().split('T')[0];
    final attendanceId = '${staffId}_$dateStr';

    final attendance = StaffAttendance(
      id: attendanceId,
      schoolId: schoolId,
      staffId: staffId,
      staffName: staffName,
      date: date,
      status: status,
      loginTime: loginTime,
      logoutTime: logoutTime,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      createdBy: markedBy,
      metadata: {
        'manualEntry': true,
        if (remarks != null) 'remarks': remarks,
      },
    );

    await _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('staffAttendance')
        .doc(attendanceId)
        .set(attendance.toFirestore(), SetOptions(merge: true));
  }

  /// Get attendance summary for admin dashboard
  Future<Map<String, dynamic>> getAttendanceSummary({
    required String schoolId,
    required DateTime date,
  }) async {
    final dateOnly = DateTime(date.year, date.month, date.day);

    final snapshot = await _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('staffAttendance')
        .where('date', isEqualTo: Timestamp.fromDate(dateOnly))
        .get();

    int present = 0;
    int absent = 0;
    int leave = 0;
    int permission = 0;
    int lop = 0;
    int holiday = 0;
    int partial = 0;
    int late = 0;

    for (final doc in snapshot.docs) {
      final attendance = StaffAttendance.fromFirestore(doc);
      
      switch (attendance.status) {
        case StaffAttendanceStatus.PRESENT:
          present++;
          break;
        case StaffAttendanceStatus.ABSENT:
          absent++;
          break;
        case StaffAttendanceStatus.LEAVE:
          leave++;
          break;
        case StaffAttendanceStatus.PERMISSION:
          permission++;
          break;
        case StaffAttendanceStatus.LOP:
          lop++;
          break;
        case StaffAttendanceStatus.HOLIDAY:
          holiday++;
          break;
        case StaffAttendanceStatus.PARTIAL:
          partial++;
          break;
      }

      if (attendance.isLate) {
        late++;
      }
    }

    return {
      'total': snapshot.docs.length,
      'present': present,
      'absent': absent,
      'leave': leave,
      'permission': permission,
      'lop': lop,
      'holiday': holiday,
      'partial': partial,
      'late': late,
    };
  }
}

/// Attendance statistics model
class AttendanceStatistics {
  final int totalDays;
  final int presentCount;
  final int absentCount;
  final int leaveCount;
  final int permissionCount;
  final int lopCount;
  final int holidayCount;
  final int partialCount;
  final int lateCount;
  final double averageLateMinutes;

  AttendanceStatistics({
    required this.totalDays,
    required this.presentCount,
    required this.absentCount,
    required this.leaveCount,
    required this.permissionCount,
    required this.lopCount,
    required this.holidayCount,
    required this.partialCount,
    required this.lateCount,
    required this.averageLateMinutes,
  });

  double get attendancePercentage {
    if (totalDays == 0) return 0;
    final workingDays = totalDays - holidayCount;
    if (workingDays == 0) return 0;
    return (presentCount / workingDays) * 100;
  }

  int get workingDays => totalDays - holidayCount;
}
