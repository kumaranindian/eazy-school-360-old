import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../domain/entities/academic_year.dart';

/// Service for migrating existing data to support academic year system
class AcademicYearMigrationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Initialize academic and fiscal years for a school
  Future<Map<String, dynamic>> initializeYearsForSchool(String schoolId) async {
    try {
      // Check if years already exist
      final academicYearsSnapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('academicYears')
          .limit(1)
          .get();

      if (academicYearsSnapshot.docs.isNotEmpty) {
        return {
          'success': false,
          'message': 'Academic years already initialized for this school',
        };
      }

      final currentAcademicYearCode = AcademicYear.getCurrentYearCode();
      final currentFiscalYearCode = FiscalYear.getCurrentYearCode();
      final currentAcademicYear = int.parse(currentAcademicYearCode.split('-')[0]);
      final currentFiscalYear = int.parse(currentFiscalYearCode.split('-')[0]);
      final batch = _firestore.batch();

      // Create academic years (-2 to +2 years) based on current academic year
      for (int i = -2; i <= 2; i++) {
        final year = AcademicYear.fromYear(
          schoolId,
          currentAcademicYear + i,
          isCurrent: i == 0,
        );
        final docRef = _firestore
            .collection('schools')
            .doc(schoolId)
            .collection('academicYears')
            .doc();
        batch.set(docRef, year.toFirestore());
      }

      // Create fiscal years (-2 to +2 years) based on current fiscal year
      for (int i = -2; i <= 2; i++) {
        final year = FiscalYear.fromYear(
          schoolId,
          currentFiscalYear + i,
          isCurrent: i == 0,
        );
        final docRef = _firestore
            .collection('schools')
            .doc(schoolId)
            .collection('fiscalYears')
            .doc();
        batch.set(docRef, year.toFirestore());
      }

      await batch.commit();

      return {
        'success': true,
        'message': 'Successfully initialized 5 academic years and 5 fiscal years',
        'currentAcademicYear': currentAcademicYearCode,
      };
    } catch (e) {
      debugPrint('[Migration] Error initializing years: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Assign current academic year to all existing students
  Future<Map<String, dynamic>> assignAcademicYearToStudents(String schoolId) async {
    int successCount = 0;
    int errorCount = 0;

    try {
      final currentYearCode = AcademicYear.getCurrentYearCode();

      // Get all students without academicYearCode
      final studentsSnapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('students')
          .get();

      final batch = _firestore.batch();
      int batchCount = 0;

      for (final doc in studentsSnapshot.docs) {
        final data = doc.data();
        final existingYear = data['academicYearCode'] as String?;

        // Only update if academicYearCode is missing or empty
        if (existingYear == null || existingYear.isEmpty) {
          batch.update(doc.reference, {
            'academicYearCode': currentYearCode,
            'arrears': 0.0,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          batchCount++;
          successCount++;

          // Firestore batch limit is 500
          if (batchCount >= 500) {
            await batch.commit();
            batchCount = 0;
          }
        }
      }

      if (batchCount > 0) {
        await batch.commit();
      }

      return {
        'success': true,
        'updatedCount': successCount,
        'totalStudents': studentsSnapshot.docs.length,
        'assignedYear': currentYearCode,
        'message': 'Assigned academic year $currentYearCode to $successCount students',
      };
    } catch (e) {
      debugPrint('[Migration] Error assigning academic year to students: $e');
      return {
        'success': false,
        'error': e.toString(),
        'successCount': successCount,
        'errorCount': errorCount,
      };
    }
  }

  /// Assign current academic year to all fee structures
  Future<Map<String, dynamic>> assignAcademicYearToFeeStructures(String schoolId) async {
    int successCount = 0;

    try {
      final currentYearCode = AcademicYear.getCurrentYearCode();

      final feeStructuresSnapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('feeStructures')
          .get();

      final batch = _firestore.batch();
      int batchCount = 0;

      for (final doc in feeStructuresSnapshot.docs) {
        final data = doc.data();
        final existingYear = data['academicYearCode'] as String?;

        if (existingYear == null || existingYear.isEmpty) {
          batch.update(doc.reference, {
            'academicYearCode': currentYearCode,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          batchCount++;
          successCount++;

          if (batchCount >= 500) {
            await batch.commit();
            batchCount = 0;
          }
        }
      }

      if (batchCount > 0) {
        await batch.commit();
      }

      return {
        'success': true,
        'updatedCount': successCount,
        'assignedYear': currentYearCode,
        'message': 'Assigned academic year $currentYearCode to $successCount fee structures',
      };
    } catch (e) {
      debugPrint('[Migration] Error assigning academic year to fee structures: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Assign fiscal year to all bills
  Future<Map<String, dynamic>> assignFiscalYearToBills(String schoolId) async {
    int successCount = 0;

    try {
      final currentYearCode = FiscalYear.getCurrentYearCode();

      final billsSnapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('bills')
          .get();

      final batch = _firestore.batch();
      int batchCount = 0;

      for (final doc in billsSnapshot.docs) {
        final data = doc.data();
        final existingYear = data['fiscalYearCode'] as String?;

        if (existingYear == null || existingYear.isEmpty) {
          batch.update(doc.reference, {
            'fiscalYearCode': currentYearCode,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          batchCount++;
          successCount++;

          if (batchCount >= 500) {
            await batch.commit();
            batchCount = 0;
          }
        }
      }

      if (batchCount > 0) {
        await batch.commit();
      }

      return {
        'success': true,
        'updatedCount': successCount,
        'assignedYear': currentYearCode,
        'message': 'Assigned fiscal year $currentYearCode to $successCount bills',
      };
    } catch (e) {
      debugPrint('[Migration] Error assigning fiscal year to bills: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Run complete migration for a school
  Future<Map<String, dynamic>> runCompleteMigration(String schoolId) async {
    final results = <String, dynamic>{};

    try {
      // Step 1: Initialize years
      debugPrint('[Migration] Step 1: Initializing years...');
      results['initializeYears'] = await initializeYearsForSchool(schoolId);

      // Step 2: Assign year to students
      debugPrint('[Migration] Step 2: Assigning academic year to students...');
      results['assignStudentYears'] = await assignAcademicYearToStudents(schoolId);

      // Step 3: Assign year to fee structures
      debugPrint('[Migration] Step 3: Assigning academic year to fee structures...');
      results['assignFeeStructureYears'] = await assignAcademicYearToFeeStructures(schoolId);

      // Step 4: Assign fiscal year to bills
      debugPrint('[Migration] Step 4: Assigning fiscal year to bills...');
      results['assignBillYears'] = await assignFiscalYearToBills(schoolId);

      final allSuccessful = results.values.every((r) => r['success'] == true);

      return {
        'success': allSuccessful,
        'results': results,
        'message': allSuccessful
            ? 'Migration completed successfully for all components'
            : 'Migration completed with some errors. Check results for details.',
      };
    } catch (e) {
      debugPrint('[Migration] Error in complete migration: $e');
      return {
        'success': false,
        'error': e.toString(),
        'results': results,
      };
    }
  }

  /// Verify migration status for a school
  Future<Map<String, dynamic>> verifyMigration(String schoolId) async {
    try {
      // Check academic years
      final academicYearsSnapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('academicYears')
          .get();

      // Check students with year
      final studentsSnapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('students')
          .get();

      int studentsWithYear = 0;
      int studentsWithoutYear = 0;

      for (final doc in studentsSnapshot.docs) {
        final data = doc.data();
        final year = data['academicYearCode'] as String?;
        if (year != null && year.isNotEmpty) {
          studentsWithYear++;
        } else {
          studentsWithoutYear++;
        }
      }

      return {
        'success': true,
        'academicYearsCount': academicYearsSnapshot.docs.length,
        'totalStudents': studentsSnapshot.docs.length,
        'studentsWithYear': studentsWithYear,
        'studentsWithoutYear': studentsWithoutYear,
        'migrationComplete': studentsWithoutYear == 0 && academicYearsSnapshot.docs.isNotEmpty,
      };
    } catch (e) {
      debugPrint('[Migration] Error verifying migration: $e');
      return {'success': false, 'error': e.toString()};
    }
  }
}
