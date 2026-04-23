import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../domain/entities/arrears.dart';
import '../../domain/entities/student.dart';

/// Service for managing student fee arrears and carry-forward logic
class ArrearsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Calculate arrears for a student at the end of an academic year
  /// Returns the balance total fees from student_fee_details
  Future<double> calculateArrearsForStudent({
    required String schoolId,
    required String studentId,
    required String academicYearCode,
  }) async {
    try {
      // Get the student doc to find the numeric studentId
      final studentDoc = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('students')
          .doc(studentId)
          .get();

      if (!studentDoc.exists) return 0.0;
      final stuNumericId = studentDoc.data()!['studentId'];

      // Get balance from student_fee_details (the actual fee tracker)
      final feeSnap = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('student_fee_details')
          .where('stuId', isEqualTo: stuNumericId)
          .limit(1)
          .get();

      if (feeSnap.docs.isEmpty) return 0.0;

      final fd = feeSnap.docs.first.data();
      final balTotal = (fd['stuBalTotalFees'] as num?)?.toDouble() ?? 0.0;
      return balTotal > 0 ? balTotal : 0.0;
    } catch (e) {
      debugPrint('[ArrearsService] Error calculating arrears: $e');
      return 0.0;
    }
  }

  /// Create arrears record for a student when transitioning to new academic year.
  /// Uses student_fee_details to get the actual balance (total - paid).
  Future<String?> createArrearsRecord({
    required String schoolId,
    required String studentId,
    required String fromAcademicYear,
    required String toAcademicYear,
    required String createdBy,
  }) async {
    try {
      // Get student details
      final studentDoc = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('students')
          .doc(studentId)
          .get();

      if (!studentDoc.exists) return null;

      final student = Student.fromFirestore(studentDoc);

      // Get totals and paid from student_fee_details (the real tracker)
      final feeSnap = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('student_fee_details')
          .where('stuId', isEqualTo: student.studentId)
          .limit(1)
          .get();

      double totalFees = 0.0;
      double totalPaid = 0.0;
      double arrearsAmount = 0.0;
      String? feeDocId;

      if (feeSnap.docs.isNotEmpty) {
        final fd = feeSnap.docs.first.data();
        feeDocId = feeSnap.docs.first.id;
        totalFees = (fd['stuTotalFees'] as num?)?.toDouble() ?? 0.0;
        totalPaid = (fd['stuPaidTotalFees'] as num?)?.toDouble() ?? 0.0;
        arrearsAmount = (fd['stuBalTotalFees'] as num?)?.toDouble() ?? 0.0;
      }

      // Only create arrears record if there's pending amount
      if (arrearsAmount <= 0) return null;

      final now = DateTime.now();
      final arrears = Arrears(
        id: '',
        schoolId: schoolId,
        studentId: studentId,
        studentName: student.name,
        studentNumericId: student.studentId,
        className: student.className,
        section: student.section,
        fromAcademicYear: fromAcademicYear,
        toAcademicYear: toAcademicYear,
        totalFeesForYear: totalFees,
        totalPaidForYear: totalPaid,
        arrearsAmount: arrearsAmount,
        paidAmount: 0.0,
        remainingAmount: arrearsAmount,
        status: ArrearsStatus.PENDING,
        description: 'Pending fees from $fromAcademicYear carried forward to $toAcademicYear',
        createdAt: now,
        updatedAt: now,
        createdBy: createdBy,
      );

      final docRef = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('arrears')
          .add(arrears.toFirestore());

      // Also update student_fee_details to carry forward arrears into the new year fields
      if (feeDocId != null) {
        final fd = feeSnap.docs.first.data();
        double n(String k) => (fd[k] as num?)?.toDouble() ?? 0;

        // Move current balances to arrear fields
        await _firestore
            .collection('schools')
            .doc(schoolId)
            .collection('student_fee_details')
            .doc(feeDocId)
            .update({
          'arrearTuitionFees': n('stuBalTutionFees'),
          'arrearExamFees': n('stuBalExamFees'),
          'arrearAdmissionFees': n('stuBalAdmissionFees'),
          'arrearVanFees': n('stuBalVanFees'),
          'balanceArrearTuitionFees': n('stuBalTutionFees'),
          'balanceArrearExamFees': n('stuBalExamFees'),
          'balanceArrearAdmissionFees': n('stuBalAdmissionFees'),
          'balanceArrearVanFees': n('stuBalVanFees'),
          'stuPaidArrearTutionFees': 0.0,
          'stuPaidArrearExamFees': 0.0,
          'stuPaidArrearAdmissionFees': 0.0,
          'stuPaidArrearVanFees': 0.0,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      return docRef.id;
    } catch (e) {
      debugPrint('[ArrearsService] Error creating arrears record: $e');
      return null;
    }
  }

  /// Record payment towards arrears
  Future<void> recordArrearsPayment({
    required String schoolId,
    required String arrearsId,
    required double paymentAmount,
  }) async {
    try {
      final arrearsDoc = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('arrears')
          .doc(arrearsId)
          .get();

      if (!arrearsDoc.exists) return;

      final arrears = Arrears.fromFirestore(arrearsDoc);
      final newPaidAmount = arrears.paidAmount + paymentAmount;
      final newRemainingAmount = arrears.arrearsAmount - newPaidAmount;

      ArrearsStatus newStatus;
      if (newRemainingAmount <= 0) {
        newStatus = ArrearsStatus.PAID;
      } else if (newPaidAmount > 0) {
        newStatus = ArrearsStatus.PARTIALLY_PAID;
      } else {
        newStatus = ArrearsStatus.PENDING;
      }

      await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('arrears')
          .doc(arrearsId)
          .update({
        'paidAmount': newPaidAmount,
        'remainingAmount': newRemainingAmount > 0 ? newRemainingAmount : 0.0,
        'status': newStatus.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('[ArrearsService] Error recording arrears payment: $e');
      rethrow;
    }
  }

  /// Waive arrears for a student
  Future<void> waiveArrears({
    required String schoolId,
    required String arrearsId,
    required String reason,
  }) async {
    try {
      await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('arrears')
          .doc(arrearsId)
          .update({
        'status': ArrearsStatus.WAIVED.name,
        'description': reason,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('[ArrearsService] Error waiving arrears: $e');
      rethrow;
    }
  }

  /// Get all arrears for a student
  Stream<List<Arrears>> getStudentArrears({
    required String schoolId,
    required String studentId,
  }) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('arrears')
        .where('studentId', isEqualTo: studentId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Arrears.fromFirestore(doc))
            .toList());
  }

  /// Get pending arrears for a student in current academic year
  Future<double> getPendingArrearsAmount({
    required String schoolId,
    required String studentId,
    required String academicYearCode,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('arrears')
          .where('studentId', isEqualTo: studentId)
          .where('toAcademicYear', isEqualTo: academicYearCode)
          .where('status', whereIn: ['PENDING', 'PARTIALLY_PAID'])
          .get();

      double totalPending = 0.0;
      for (final doc in snapshot.docs) {
        final arrears = Arrears.fromFirestore(doc);
        totalPending += arrears.remainingAmount;
      }

      return totalPending;
    } catch (e) {
      debugPrint('[ArrearsService] Error getting pending arrears: $e');
      return 0.0;
    }
  }

  /// Bulk create arrears for all students at year end
  Future<Map<String, dynamic>> bulkCreateArrears({
    required String schoolId,
    required String fromAcademicYear,
    required String toAcademicYear,
    required String createdBy,
    String? className,
    String? section,
  }) async {
    int successCount = 0;
    int skipCount = 0;
    int errorCount = 0;
    final List<String> errors = [];

    try {
      // Get all students (optionally filtered by class/section)
      Query<Map<String, dynamic>> query = _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('students')
          .where('academicYearCode', isEqualTo: fromAcademicYear)
          .where('status', isEqualTo: 'ACTIVE');

      if (className != null) {
        query = query.where('className', isEqualTo: className);
      }
      if (section != null) {
        query = query.where('section', isEqualTo: section);
      }

      final studentsSnapshot = await query.get();

      for (final studentDoc in studentsSnapshot.docs) {
        try {
          final arrearsId = await createArrearsRecord(
            schoolId: schoolId,
            studentId: studentDoc.id,
            fromAcademicYear: fromAcademicYear,
            toAcademicYear: toAcademicYear,
            createdBy: createdBy,
          );

          if (arrearsId != null) {
            successCount++;
          } else {
            skipCount++; // No arrears (fully paid)
          }
        } catch (e) {
          errorCount++;
          errors.add('${studentDoc.id}: $e');
        }
      }

      return {
        'success': true,
        'successCount': successCount,
        'skipCount': skipCount,
        'errorCount': errorCount,
        'errors': errors,
        'message': 'Processed ${studentsSnapshot.docs.length} students. '
            'Created: $successCount, Skipped: $skipCount, Errors: $errorCount',
      };
    } catch (e) {
      debugPrint('[ArrearsService] Error in bulk arrears creation: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
}
