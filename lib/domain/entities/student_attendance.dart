import 'package:cloud_firestore/cloud_firestore.dart';

enum AttendanceStatus { PRESENT, ABSENT, LATE, PERMISSION, HOLIDAY, NOT_MARKED }

class StudentAttendanceRecord {
  final String id;
  final String schoolId;
  final String studentId;
  final String studentName;
  final int studentNumericId;
  final String className;
  final String section;
  final DateTime date;
  final AttendanceStatus status;
  final String? remarks;
  final String? markedBy;
  final DateTime? markedAt;
  final String? parentPhone;

  const StudentAttendanceRecord({
    required this.id,
    required this.schoolId,
    required this.studentId,
    required this.studentName,
    required this.studentNumericId,
    required this.className,
    required this.section,
    required this.date,
    required this.status,
    this.remarks,
    this.markedBy,
    this.markedAt,
    this.parentPhone,
  });

  factory StudentAttendanceRecord.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return StudentAttendanceRecord(
      id: doc.id,
      schoolId: data['schoolId'] as String? ?? '',
      studentId: data['studentId'] as String? ?? '',
      studentName: data['studentName'] as String? ?? '',
      studentNumericId: (data['studentNumericId'] as num?)?.toInt() ?? 0,
      className: data['className'] as String? ?? '',
      section: data['section'] as String? ?? '',
      date: _parseDate(data['date']),
      status: _parseStatus(data['status']),
      remarks: data['remarks'] as String?,
      markedBy: data['markedBy'] as String?,
      markedAt: _parseDateTime(data['markedAt']),
      parentPhone: data['parentPhone'] as String?,
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
      'date': Timestamp.fromDate(DateTime(date.year, date.month, date.day)),
      'dateString': _dateToString(date),
      'status': status.name,
      'remarks': remarks,
      'markedBy': markedBy,
      'markedAt': markedAt != null ? Timestamp.fromDate(markedAt!) : FieldValue.serverTimestamp(),
      'parentPhone': parentPhone,
    };
  }

  static String _dateToString(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
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

  static AttendanceStatus _parseStatus(dynamic status) {
    if (status == null) return AttendanceStatus.NOT_MARKED;
    switch (status.toString().toUpperCase()) {
      case 'PRESENT': return AttendanceStatus.PRESENT;
      case 'ABSENT': return AttendanceStatus.ABSENT;
      case 'LATE': return AttendanceStatus.LATE;
      case 'PERMISSION': return AttendanceStatus.PERMISSION;
      case 'HOLIDAY': return AttendanceStatus.HOLIDAY;
      default: return AttendanceStatus.NOT_MARKED;
    }
  }

  StudentAttendanceRecord copyWith({
    String? id,
    String? schoolId,
    String? studentId,
    String? studentName,
    int? studentNumericId,
    String? className,
    String? section,
    DateTime? date,
    AttendanceStatus? status,
    String? remarks,
    String? markedBy,
    DateTime? markedAt,
    String? parentPhone,
  }) {
    return StudentAttendanceRecord(
      id: id ?? this.id,
      schoolId: schoolId ?? this.schoolId,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      studentNumericId: studentNumericId ?? this.studentNumericId,
      className: className ?? this.className,
      section: section ?? this.section,
      date: date ?? this.date,
      status: status ?? this.status,
      remarks: remarks ?? this.remarks,
      markedBy: markedBy ?? this.markedBy,
      markedAt: markedAt ?? this.markedAt,
      parentPhone: parentPhone ?? this.parentPhone,
    );
  }
}

/// Daily summary for a class/section
class DailyAttendanceSummary {
  final String className;
  final String section;
  final DateTime date;
  final int totalStudents;
  final int present;
  final int absent;
  final int late;
  final int permission;
  final bool isComplete;

  const DailyAttendanceSummary({
    required this.className,
    required this.section,
    required this.date,
    required this.totalStudents,
    required this.present,
    required this.absent,
    required this.late,
    required this.permission,
    required this.isComplete,
  });

  double get presentPercentage => totalStudents > 0 ? (present / totalStudents) * 100 : 0;
  double get absentPercentage => totalStudents > 0 ? (absent / totalStudents) * 100 : 0;
}

/// Monthly summary for a student
class MonthlyAttendanceSummary {
  final String studentId;
  final String studentName;
  final int month;
  final int year;
  final int totalWorkingDays;
  final int presentDays;
  final int absentDays;
  final int lateDays;
  final int permissionDays;
  final int holidayDays;

  const MonthlyAttendanceSummary({
    required this.studentId,
    required this.studentName,
    required this.month,
    required this.year,
    required this.totalWorkingDays,
    required this.presentDays,
    required this.absentDays,
    required this.lateDays,
    required this.permissionDays,
    required this.holidayDays,
  });

  double get attendancePercentage => totalWorkingDays > 0 ? (presentDays / totalWorkingDays) * 100 : 0;
}
