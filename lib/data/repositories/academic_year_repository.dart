import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/academic_year.dart';

final academicYearRepositoryProvider = Provider<AcademicYearRepository>((ref) {
  return AcademicYearRepository();
});

/// Provider: all academic years for a school
final schoolAcademicYearsProvider = StreamProvider.family<List<AcademicYear>, String>((ref, schoolId) {
  final repo = ref.watch(academicYearRepositoryProvider);
  return repo.getAcademicYears(schoolId);
});

/// Provider: current academic year for a school
final currentAcademicYearProvider = StreamProvider.family<AcademicYear?, String>((ref, schoolId) {
  final repo = ref.watch(academicYearRepositoryProvider);
  return repo.getCurrentAcademicYear(schoolId);
});

/// Provider: all fiscal years for a school
final schoolFiscalYearsProvider = StreamProvider.family<List<FiscalYear>, String>((ref, schoolId) {
  final repo = ref.watch(academicYearRepositoryProvider);
  return repo.getFiscalYears(schoolId);
});

/// Provider: current fiscal year for a school
final currentFiscalYearProvider = StreamProvider.family<FiscalYear?, String>((ref, schoolId) {
  final repo = ref.watch(academicYearRepositoryProvider);
  return repo.getCurrentFiscalYear(schoolId);
});

class AcademicYearRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _academicYearsCollection(String schoolId) {
    return _firestore.collection('schools').doc(schoolId).collection('academicYears');
  }

  CollectionReference<Map<String, dynamic>> _fiscalYearsCollection(String schoolId) {
    return _firestore.collection('schools').doc(schoolId).collection('fiscalYears');
  }

  // ==================== ACADEMIC YEARS ====================

  /// Get all academic years for a school (ordered by start date descending)
  Stream<List<AcademicYear>> getAcademicYears(String schoolId) {
    return _academicYearsCollection(schoolId)
        .orderBy('startDate', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AcademicYear.fromFirestore(doc))
            .toList());
  }

  /// Get current academic year
  Stream<AcademicYear?> getCurrentAcademicYear(String schoolId) {
    return _academicYearsCollection(schoolId)
        .where('isCurrent', isEqualTo: true)
        .limit(1)
        .snapshots()
        .map((snapshot) => snapshot.docs.isNotEmpty
            ? AcademicYear.fromFirestore(snapshot.docs.first)
            : null);
  }

  /// Get academic year by year code
  Future<AcademicYear?> getAcademicYearByCode(String schoolId, String yearCode) async {
    final snapshot = await _academicYearsCollection(schoolId)
        .where('yearCode', isEqualTo: yearCode)
        .limit(1)
        .get();
    
    return snapshot.docs.isNotEmpty
        ? AcademicYear.fromFirestore(snapshot.docs.first)
        : null;
  }

  /// Create a new academic year
  Future<String> createAcademicYear(String schoolId, AcademicYear year) async {
    final docRef = await _academicYearsCollection(schoolId).add(year.toFirestore());
    return docRef.id;
  }

  /// Set current academic year (unsets all others)
  Future<void> setCurrentAcademicYear(String schoolId, String yearId) async {
    final batch = _firestore.batch();

    // Unset all current flags
    final allYears = await _academicYearsCollection(schoolId).get();
    for (final doc in allYears.docs) {
      batch.update(doc.reference, {
        'isCurrent': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    // Set the specified year as current
    batch.update(_academicYearsCollection(schoolId).doc(yearId), {
      'isCurrent': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  /// Initialize academic years for a school (creates last 2 years, current, and next 2 years)
  Future<void> initializeAcademicYears(String schoolId) async {
    final currentYearCode = AcademicYear.getCurrentYearCode();
    final currentYear = int.parse(currentYearCode.split('-')[0]);

    final batch = _firestore.batch();
    
    for (int i = -2; i <= 2; i++) {
      final year = AcademicYear.fromYear(
        schoolId,
        currentYear + i,
        isCurrent: i == 0,
      );
      
      final docRef = _academicYearsCollection(schoolId).doc();
      batch.set(docRef, year.toFirestore());
    }

    await batch.commit();
  }

  // ==================== FISCAL YEARS ====================

  /// Get all fiscal years for a school (ordered by start date descending)
  Stream<List<FiscalYear>> getFiscalYears(String schoolId) {
    return _fiscalYearsCollection(schoolId)
        .orderBy('startDate', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => FiscalYear.fromFirestore(doc))
            .toList());
  }

  /// Get current fiscal year
  Stream<FiscalYear?> getCurrentFiscalYear(String schoolId) {
    return _fiscalYearsCollection(schoolId)
        .where('isCurrent', isEqualTo: true)
        .limit(1)
        .snapshots()
        .map((snapshot) => snapshot.docs.isNotEmpty
            ? FiscalYear.fromFirestore(snapshot.docs.first)
            : null);
  }

  /// Get fiscal year by year code
  Future<FiscalYear?> getFiscalYearByCode(String schoolId, String yearCode) async {
    final snapshot = await _fiscalYearsCollection(schoolId)
        .where('yearCode', isEqualTo: yearCode)
        .limit(1)
        .get();
    
    return snapshot.docs.isNotEmpty
        ? FiscalYear.fromFirestore(snapshot.docs.first)
        : null;
  }

  /// Create a new fiscal year
  Future<String> createFiscalYear(String schoolId, FiscalYear year) async {
    final docRef = await _fiscalYearsCollection(schoolId).add(year.toFirestore());
    return docRef.id;
  }

  /// Set current fiscal year (unsets all others)
  Future<void> setCurrentFiscalYear(String schoolId, String yearId) async {
    final batch = _firestore.batch();

    // Unset all current flags
    final allYears = await _fiscalYearsCollection(schoolId).get();
    for (final doc in allYears.docs) {
      batch.update(doc.reference, {
        'isCurrent': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    // Set the specified year as current
    batch.update(_fiscalYearsCollection(schoolId).doc(yearId), {
      'isCurrent': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  /// Initialize fiscal years for a school (creates last 2 years, current, and next 2 years)
  Future<void> initializeFiscalYears(String schoolId) async {
    final currentYearCode = FiscalYear.getCurrentYearCode();
    final currentYear = int.parse(currentYearCode.split('-')[0]);

    final batch = _firestore.batch();
    
    for (int i = -2; i <= 2; i++) {
      final year = FiscalYear.fromYear(
        schoolId,
        currentYear + i,
        isCurrent: i == 0,
      );
      
      final docRef = _fiscalYearsCollection(schoolId).doc();
      batch.set(docRef, year.toFirestore());
    }

    await batch.commit();
  }

  /// Delete an academic year
  Future<void> deleteAcademicYear(String schoolId, String yearId) async {
    await _academicYearsCollection(schoolId).doc(yearId).delete();
  }

  /// Delete a fiscal year
  Future<void> deleteFiscalYear(String schoolId, String yearId) async {
    await _fiscalYearsCollection(schoolId).doc(yearId).delete();
  }
}
