import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/student_attendance.dart';

final studentAttendanceRepositoryProvider = Provider<StudentAttendanceRepository>((ref) {
  return StudentAttendanceRepository();
});

/// Provider: attendance records for a class on a specific date
final classAttendanceProvider = StreamProvider.family<List<StudentAttendanceRecord>,
    ({String schoolId, String className, String section, String dateString})>((ref, params) {
  final repo = ref.watch(studentAttendanceRepositoryProvider);
  return repo.getClassAttendanceStream(params.schoolId, params.className, params.section, params.dateString);
});

/// Provider: attendance records for a single student in a month
final studentMonthlyAttendanceProvider = FutureProvider.family<List<StudentAttendanceRecord>,
    ({String schoolId, String studentId, int month, int year})>((ref, params) {
  final repo = ref.watch(studentAttendanceRepositoryProvider);
  return repo.getStudentMonthlyAttendance(params.schoolId, params.studentId, params.month, params.year);
});

/// Provider: attendance for a student by their Firestore doc ID (for parent view)
final studentAttendanceByDocIdProvider = FutureProvider.family<List<StudentAttendanceRecord>,
    ({String schoolId, String studentDocId, int month, int year})>((ref, params) {
  final repo = ref.watch(studentAttendanceRepositoryProvider);
  return repo.getStudentMonthlyAttendance(params.schoolId, params.studentDocId, params.month, params.year);
});

/// Provider: daily summary for all classes
final dailyAttendanceSummaryProvider = FutureProvider.family<List<DailyAttendanceSummary>,
    ({String schoolId, String dateString})>((ref, params) {
  final repo = ref.watch(studentAttendanceRepositoryProvider);
  return repo.getDailyAttendanceSummary(params.schoolId, params.dateString);
});

class StudentAttendanceRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _attendanceCollection(String schoolId) {
    return _firestore.collection('schools').doc(schoolId).collection('studentAttendance');
  }

  /// Get attendance for a class on a specific date (real-time)
  Stream<List<StudentAttendanceRecord>> getClassAttendanceStream(
      String schoolId, String className, String section, String dateString) {
    return _attendanceCollection(schoolId)
        .where('className', isEqualTo: className)
        .where('section', isEqualTo: section)
        .where('dateString', isEqualTo: dateString)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map((doc) => StudentAttendanceRecord.fromFirestore(doc)).toList();
      list.sort((a, b) => a.studentName.compareTo(b.studentName));
      return list;
    });
  }

  /// Get attendance for a single student for a month
  Future<List<StudentAttendanceRecord>> getStudentMonthlyAttendance(
      String schoolId, String studentId, int month, int year) async {
    final startDate = DateTime(year, month, 1);
    final endDate = DateTime(year, month + 1, 0, 23, 59, 59);

    final snapshot = await _attendanceCollection(schoolId)
        .where('studentId', isEqualTo: studentId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .orderBy('date')
        .get();

    return snapshot.docs.map((doc) => StudentAttendanceRecord.fromFirestore(doc)).toList();
  }

  /// Mark attendance for a single student
  Future<void> markAttendance(String schoolId, StudentAttendanceRecord record) async {
    final dateStr = _dateToString(record.date);
    // Use a composite key: studentId_dateString for idempotency
    final docId = '${record.studentId}_$dateStr';

    await _attendanceCollection(schoolId).doc(docId).set(
      record.toFirestore(),
      SetOptions(merge: true),
    );
  }

  /// Bulk mark attendance for an entire class
  Future<void> bulkMarkAttendance(String schoolId, List<StudentAttendanceRecord> records) async {
    final batch = _firestore.batch();
    for (final record in records) {
      final dateStr = _dateToString(record.date);
      final docId = '${record.studentId}_$dateStr';
      final docRef = _attendanceCollection(schoolId).doc(docId);
      batch.set(docRef, record.toFirestore(), SetOptions(merge: true));
    }
    await batch.commit();
  }

  /// Get daily summary across all classes
  Future<List<DailyAttendanceSummary>> getDailyAttendanceSummary(
      String schoolId, String dateString) async {
    final snapshot = await _attendanceCollection(schoolId)
        .where('dateString', isEqualTo: dateString)
        .get();

    final records = snapshot.docs.map((doc) => StudentAttendanceRecord.fromFirestore(doc)).toList();

    // Group by class+section
    final grouped = <String, List<StudentAttendanceRecord>>{};
    for (final r in records) {
      final key = '${r.className}|${r.section}';
      grouped.putIfAbsent(key, () => []).add(r);
    }

    // Get total student counts per class/section
    final studentsSnap = await _firestore
        .collection('schools').doc(schoolId).collection('students')
        .where('status', isEqualTo: 'ACTIVE')
        .get();

    final studentCountMap = <String, int>{};
    for (final doc in studentsSnap.docs) {
      final data = doc.data();
      final key = '${data['className']}|${data['section']}';
      studentCountMap[key] = (studentCountMap[key] ?? 0) + 1;
    }

    // Build all known class/section combos
    final allKeys = {...grouped.keys, ...studentCountMap.keys};

    return allKeys.map((key) {
      final parts = key.split('|');
      final className = parts[0];
      final section = parts.length > 1 ? parts[1] : '';
      final recs = grouped[key] ?? [];
      final total = studentCountMap[key] ?? recs.length;

      return DailyAttendanceSummary(
        className: className,
        section: section,
        date: recs.isNotEmpty ? recs.first.date : DateTime.now(),
        totalStudents: total,
        present: recs.where((r) => r.status == AttendanceStatus.PRESENT).length,
        absent: recs.where((r) => r.status == AttendanceStatus.ABSENT).length,
        late: recs.where((r) => r.status == AttendanceStatus.LATE).length,
        permission: recs.where((r) => r.status == AttendanceStatus.PERMISSION).length,
        isComplete: recs.length >= total,
      );
    }).toList()
      ..sort((a, b) {
        final c = a.className.compareTo(b.className);
        return c != 0 ? c : a.section.compareTo(b.section);
      });
  }

  /// Get monthly summary for a student
  Future<MonthlyAttendanceSummary> getMonthlyStudentSummary(
      String schoolId, String studentId, String studentName, int month, int year) async {
    final records = await getStudentMonthlyAttendance(schoolId, studentId, month, year);

    return MonthlyAttendanceSummary(
      studentId: studentId,
      studentName: studentName,
      month: month,
      year: year,
      totalWorkingDays: records.length,
      presentDays: records.where((r) => r.status == AttendanceStatus.PRESENT).length,
      absentDays: records.where((r) => r.status == AttendanceStatus.ABSENT).length,
      lateDays: records.where((r) => r.status == AttendanceStatus.LATE).length,
      permissionDays: records.where((r) => r.status == AttendanceStatus.PERMISSION).length,
      holidayDays: records.where((r) => r.status == AttendanceStatus.HOLIDAY).length,
    );
  }

  /// Get list of students with absent status for a date (for WhatsApp notification)
  Future<List<StudentAttendanceRecord>> getAbsenteesForDate(
      String schoolId, String dateString) async {
    final snapshot = await _attendanceCollection(schoolId)
        .where('dateString', isEqualTo: dateString)
        .where('status', isEqualTo: 'ABSENT')
        .get();

    return snapshot.docs.map((doc) => StudentAttendanceRecord.fromFirestore(doc)).toList();
  }

  static String _dateToString(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
