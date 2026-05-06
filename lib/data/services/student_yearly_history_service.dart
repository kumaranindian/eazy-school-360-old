import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../domain/entities/student.dart';
import '../../domain/entities/student_yearly_history.dart';

/// Service to manage per-academic-year snapshots of a student's class and fees.
///
/// Data lives at:
///   schools/{schoolId}/students/{studentDocId}/yearly_history/{academicYear}
///
/// This is the authoritative historical record used when the user asks
/// "In 2025-26, which class was this student in and what fees did they pay?".
class StudentYearlyHistoryService {
  final FirebaseFirestore _firestore;
  StudentYearlyHistoryService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _historyCol(
      String schoolId, String studentDocId) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('students')
        .doc(studentDocId)
        .collection('yearly_history');
  }

  /// Upsert the current-year snapshot for a student (called at creation and
  /// at every payment) so history is always up-to-date without waiting for
  /// promotion.
  Future<void> upsertCurrentYearSnapshot({
    required String schoolId,
    required String studentDocId,
    required Student student,
    required String academicYear,
    double totalFees = 0,
    double totalAdmissionFees = 0,
    double totalTuitionFees = 0,
    double totalExamFees = 0,
    double totalVanFees = 0,
    double paidAdmissionFees = 0,
    double paidTuitionFees = 0,
    double paidExamFees = 0,
    double paidVanFees = 0,
    double paidTotalFees = 0,
    double arrearsCarriedIn = 0,
    double arrearsPaid = 0,
  }) async {
    try {
      final docRef = _historyCol(schoolId, studentDocId).doc(academicYear);
      final now = DateTime.now();
      final snap = StudentYearlyHistory(
        id: academicYear,
        schoolId: schoolId,
        studentId: studentDocId,
        studentDocId: studentDocId,
        studentNumericId: student.studentId.toString(),
        studentName: student.name,
        academicYear: academicYear,
        className: student.className,
        section: student.section,
        totalFees: totalFees,
        totalAdmissionFees: totalAdmissionFees,
        totalTuitionFees: totalTuitionFees,
        totalExamFees: totalExamFees,
        totalVanFees: totalVanFees,
        paidAdmissionFees: paidAdmissionFees,
        paidTuitionFees: paidTuitionFees,
        paidExamFees: paidExamFees,
        paidVanFees: paidVanFees,
        paidTotalFees: paidTotalFees,
        arrearsCarriedIn: arrearsCarriedIn,
        arrearsPaid: arrearsPaid,
        balanceAtEndOfYear:
            (totalFees + arrearsCarriedIn) - (paidTotalFees + arrearsPaid),
        isCurrent: true,
        createdAt: now,
        updatedAt: now,
      );
      await docRef.set(snap.toFirestore(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('[YearlyHistory] upsert error: $e');
    }
  }

  /// Finalise the current-year snapshot when the student is promoted.
  /// Stamps `promotedOn`, flips `isCurrent` off, and records end-of-year
  /// balance so next year's arrears carry-over is visible.
  Future<void> finaliseSnapshotOnPromotion({
    required String schoolId,
    required String studentDocId,
    required String academicYear,
    double balanceAtEndOfYear = 0,
  }) async {
    try {
      final docRef = _historyCol(schoolId, studentDocId).doc(academicYear);
      await docRef.set({
        'isCurrent': false,
        'balanceAtEndOfYear': balanceAtEndOfYear,
        'promotedOn': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[YearlyHistory] finalise error: $e');
    }
  }

  /// Create a fresh snapshot row for the new academic year after promotion.
  Future<void> createSnapshotForNewYear({
    required String schoolId,
    required String studentDocId,
    required Student studentAfterPromotion,
    required String newAcademicYear,
    double arrearsCarriedIn = 0,
  }) async {
    await upsertCurrentYearSnapshot(
      schoolId: schoolId,
      studentDocId: studentDocId,
      student: studentAfterPromotion,
      academicYear: newAcademicYear,
      arrearsCarriedIn: arrearsCarriedIn,
    );
  }

  /// List all yearly snapshots for a student, newest year first.
  Stream<List<StudentYearlyHistory>> watchHistory({
    required String schoolId,
    required String studentDocId,
  }) {
    return _historyCol(schoolId, studentDocId)
        .orderBy('academicYear', descending: true)
        .snapshots()
        .map((s) => s.docs.map(StudentYearlyHistory.fromFirestore).toList());
  }

  Future<List<StudentYearlyHistory>> getHistory({
    required String schoolId,
    required String studentDocId,
  }) async {
    final snap = await _historyCol(schoolId, studentDocId)
        .orderBy('academicYear', descending: true)
        .get();
    return snap.docs.map(StudentYearlyHistory.fromFirestore).toList();
  }
}
