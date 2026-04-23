import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../domain/entities/student.dart';
import 'arrears_service.dart';
import 'student_yearly_history_service.dart';

/// Service for promoting students to next class/academic year
class StudentPromotionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ArrearsService _arrearsService = ArrearsService();
  final StudentYearlyHistoryService _historyService =
      StudentYearlyHistoryService();

  /// Class progression mapping
  static const Map<String, String> _classProgression = {
    'Pre-KG': 'LKG',
    'LKG': 'UKG',
    'UKG': 'I',
    'I': 'II',
    'II': 'III',
    'III': 'IV',
    'IV': 'V',
    'V': 'VI',
    'VI': 'VII',
    'VII': 'VIII',
    'VIII': 'IX',
    'IX': 'X',
    'X': 'XI',
    'XI': 'XII',
    'XII': 'GRADUATED',
  };

  /// Get next class for a given class
  String? getNextClass(String currentClass) {
    return _classProgression[currentClass];
  }

  /// Promote a single student to next class and academic year
  Future<Map<String, dynamic>> promoteStudent({
    required String schoolId,
    required String studentId,
    required String toAcademicYear,
    required String promotedBy,
    String? toClass,
    String? toSection,
  }) async {
    try {
      final studentDoc = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('students')
          .doc(studentId)
          .get();

      if (!studentDoc.exists) {
        return {'success': false, 'error': 'Student not found'};
      }

      final student = Student.fromFirestore(studentDoc);
      final fromAcademicYear = student.academicYearCode;

      // Determine next class if not provided
      final nextClass = toClass ?? getNextClass(student.className);
      if (nextClass == null) {
        return {'success': false, 'error': 'Cannot determine next class'};
      }

      if (nextClass == 'GRADUATED') {
        // Mark student as graduated
        await _firestore
            .collection('schools')
            .doc(schoolId)
            .collection('students')
            .doc(studentId)
            .update({
          'status': StudentStatus.GRADUATED.name,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        return {
          'success': true,
          'message': '${student.name} marked as GRADUATED',
          'graduated': true,
        };
      }

      // Create arrears record for pending fees from previous year
      final arrearsId = await _arrearsService.createArrearsRecord(
        schoolId: schoolId,
        studentId: studentId,
        fromAcademicYear: fromAcademicYear,
        toAcademicYear: toAcademicYear,
        createdBy: promotedBy,
      );

      // Get pending arrears amount
      final pendingArrears = await _arrearsService.getPendingArrearsAmount(
        schoolId: schoolId,
        studentId: studentId,
        academicYearCode: toAcademicYear,
      );

      // Finalise last year's history snapshot before we rewrite student.
      await _historyService.finaliseSnapshotOnPromotion(
        schoolId: schoolId,
        studentDocId: studentId,
        academicYear: fromAcademicYear,
        balanceAtEndOfYear: pendingArrears,
      );

      // Update student record.
      //
      // We also persist `previousAcademicYear` and `previousClass` so the
      // fee-payment screen can tag arrears bills with the correct origin
      // (e.g. student is now in Class IV (2026-27) but paying arrears for
      //  Class III (2025-26) — the bill keeps that attribution).
      final targetSection = toSection ?? student.section;
      await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('students')
          .doc(studentId)
          .update({
        'className': nextClass,
        'section': targetSection,
        'academicYearCode': toAcademicYear,
        'arrears': pendingArrears,
        'previousAcademicYear': fromAcademicYear,
        'previousClass': student.className,
        'previousSection': student.section,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // ── Update student_fee_details for the new academic year ──
      // Reset current-year paid/balance and load new class fee structure.
      final feeSnap = await _firestore
          .collection('schools').doc(schoolId).collection('student_fee_details')
          .where('stuId', isEqualTo: student.studentId)
          .limit(1)
          .get();

      if (feeSnap.docs.isNotEmpty) {
        final feeDocRef = feeSnap.docs.first.reference;

        // Lookup new class fee structure
        double newTuition = 0, newExam = 0;
        final feeStrSnap = await _firestore
            .collection('schools').doc(schoolId).collection('fee_structures')
            .where('className', isEqualTo: nextClass)
            .where('isActive', isEqualTo: true)
            .limit(1)
            .get();
        if (feeStrSnap.docs.isNotEmpty) {
          final fs = feeStrSnap.docs.first.data();
          newTuition = (fs['tuitionFee'] as num?)?.toDouble() ?? 0;
          newExam = (fs['examFee'] as num?)?.toDouble() ?? 0;
        }

        final fd = feeSnap.docs.first.data();
        final vanFees = (fd['stuTotalVanFees'] as num?)?.toDouble() ?? 0;
        final newTotalFees = newTuition + newExam + vanFees;

        await feeDocRef.update({
          'stuClass': nextClass,
          'className': nextClass,
          'stuSection': targetSection,
          'section': targetSection,
          'academicYear': toAcademicYear,
          'stuTotalTutionFees': newTuition,
          'stuTotalExamFees': newExam,
          'stuTotalFees': newTotalFees,
          'stuPaidTutionFees': 0.0,
          'stuPaidExamFees': 0.0,
          'studPaidVanFees': 0.0,
          'stuPaidAdmissionFees': 0.0,
          'stuPaidTotalFees': 0.0,
          'stuBalTutionFees': newTuition,
          'stuBalExamFees': newExam,
          'stuBalVanFees': vanFees,
          'stuBalAdmissionFees': 0.0,
          'stuBalTotalFees': newTotalFees,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Create the new year's snapshot, carrying over the arrears amount.
      final promotedStudent = student.copyWith(
        className: nextClass,
        section: targetSection,
        academicYearCode: toAcademicYear,
        arrears: pendingArrears,
      );
      await _historyService.createSnapshotForNewYear(
        schoolId: schoolId,
        studentDocId: studentId,
        studentAfterPromotion: promotedStudent,
        newAcademicYear: toAcademicYear,
        arrearsCarriedIn: pendingArrears,
      );

      return {
        'success': true,
        'message': '${student.name} promoted from ${student.className} to $nextClass',
        'fromClass': student.className,
        'toClass': nextClass,
        'arrearsCreated': arrearsId != null,
        'arrearsAmount': pendingArrears,
      };
    } catch (e) {
      debugPrint('[PromotionService] Error promoting student: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Bulk promote all students of a class to next class
  Future<Map<String, dynamic>> bulkPromoteClass({
    required String schoolId,
    required String fromClass,
    required String fromSection,
    required String fromAcademicYear,
    required String toAcademicYear,
    required String promotedBy,
    String? toClass,
    String? toSection,
  }) async {
    int successCount = 0;
    int graduatedCount = 0;
    int errorCount = 0;
    final List<String> errors = [];
    double totalArrearsCreated = 0.0;

    try {
      // Get all active students in the class
      final studentsSnapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('students')
          .where('className', isEqualTo: fromClass)
          .where('section', isEqualTo: fromSection)
          .where('academicYearCode', isEqualTo: fromAcademicYear)
          .where('status', isEqualTo: StudentStatus.ACTIVE.name)
          .get();

      if (studentsSnapshot.docs.isEmpty) {
        return {
          'success': false,
          'error': 'No active students found in $fromClass-$fromSection',
        };
      }

      // Determine target class
      final targetClass = toClass ?? getNextClass(fromClass);
      if (targetClass == null) {
        return {
          'success': false,
          'error': 'Cannot determine next class for $fromClass',
        };
      }

      for (final studentDoc in studentsSnapshot.docs) {
        try {
          final result = await promoteStudent(
            schoolId: schoolId,
            studentId: studentDoc.id,
            toAcademicYear: toAcademicYear,
            promotedBy: promotedBy,
            toClass: targetClass,
            toSection: toSection ?? fromSection,
          );

          if (result['success'] == true) {
            if (result['graduated'] == true) {
              graduatedCount++;
            } else {
              successCount++;
              if (result['arrearsAmount'] != null) {
                totalArrearsCreated += result['arrearsAmount'] as double;
              }
            }
          } else {
            errorCount++;
            errors.add('${studentDoc.id}: ${result['error']}');
          }
        } catch (e) {
          errorCount++;
          errors.add('${studentDoc.id}: $e');
        }
      }

      return {
        'success': true,
        'totalStudents': studentsSnapshot.docs.length,
        'successCount': successCount,
        'graduatedCount': graduatedCount,
        'errorCount': errorCount,
        'errors': errors,
        'fromClass': fromClass,
        'toClass': targetClass,
        'totalArrearsCreated': totalArrearsCreated,
        'message': 'Promoted $successCount students from $fromClass to $targetClass. '
            'Graduated: $graduatedCount. Errors: $errorCount. '
            'Total arrears: ₹${totalArrearsCreated.toStringAsFixed(2)}',
      };
    } catch (e) {
      debugPrint('[PromotionService] Error in bulk promotion: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Promote all students in a school to next academic year
  Future<Map<String, dynamic>> promoteEntireSchool({
    required String schoolId,
    required String fromAcademicYear,
    required String toAcademicYear,
    required String promotedBy,
  }) async {
    int totalProcessed = 0;
    int successCount = 0;
    int graduatedCount = 0;
    int errorCount = 0;
    final List<String> errors = [];
    final Map<String, int> classWiseCount = {};

    try {
      // Get all unique class-section combinations
      final studentsSnapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('students')
          .where('academicYearCode', isEqualTo: fromAcademicYear)
          .where('status', isEqualTo: StudentStatus.ACTIVE.name)
          .get();

      // Group by class-section
      final Map<String, List<String>> classSectionMap = {};
      for (final doc in studentsSnapshot.docs) {
        final data = doc.data();
        final className = data['className'] as String?;
        final section = data['section'] as String?;
        if (className != null && section != null) {
          final key = '$className-$section';
          classSectionMap.putIfAbsent(key, () => []).add(doc.id);
        }
      }

      // Promote each class-section
      for (final entry in classSectionMap.entries) {
        final parts = entry.key.split('-');
        final className = parts[0];
        final section = parts[1];

        final result = await bulkPromoteClass(
          schoolId: schoolId,
          fromClass: className,
          fromSection: section,
          fromAcademicYear: fromAcademicYear,
          toAcademicYear: toAcademicYear,
          promotedBy: promotedBy,
        );

        if (result['success'] == true) {
          totalProcessed += result['totalStudents'] as int;
          successCount += result['successCount'] as int;
          graduatedCount += result['graduatedCount'] as int;
          errorCount += result['errorCount'] as int;
          classWiseCount[className] = result['successCount'] as int;
        }
      }

      return {
        'success': true,
        'totalProcessed': totalProcessed,
        'successCount': successCount,
        'graduatedCount': graduatedCount,
        'errorCount': errorCount,
        'classWiseCount': classWiseCount,
        'message': 'School-wide promotion completed. '
            'Promoted: $successCount, Graduated: $graduatedCount, Errors: $errorCount',
      };
    } catch (e) {
      debugPrint('[PromotionService] Error in school-wide promotion: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Rollback promotion for a student (emergency use only)
  Future<Map<String, dynamic>> rollbackPromotion({
    required String schoolId,
    required String studentId,
    required String toPreviousClass,
    required String toPreviousSection,
    required String toPreviousAcademicYear,
  }) async {
    try {
      await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('students')
          .doc(studentId)
          .update({
        'className': toPreviousClass,
        'section': toPreviousSection,
        'academicYearCode': toPreviousAcademicYear,
        'status': StudentStatus.ACTIVE.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return {
        'success': true,
        'message': 'Student rolled back to $toPreviousClass-$toPreviousSection',
      };
    } catch (e) {
      debugPrint('[PromotionService] Error rolling back promotion: $e');
      return {'success': false, 'error': e.toString()};
    }
  }
}
