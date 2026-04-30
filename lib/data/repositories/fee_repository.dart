import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/fee_structure.dart';
import '../../domain/entities/fee_structure_v2.dart';
import '../../domain/entities/fee_term.dart';
import '../../domain/entities/student_fee_details.dart';
import '../../domain/entities/fee_payment.dart';

final feeRepositoryProvider = Provider<FeeRepository>((ref) {
  return FeeRepository();
});

// Fee Structure Providers
final feeStructuresProvider = StreamProvider.family<List<FeeStructure>, String>((ref, schoolId) {
  final repo = ref.watch(feeRepositoryProvider);
  return repo.getFeeStructuresStream(schoolId);
});

final feeStructureByClassProvider = FutureProvider.family<FeeStructure?, ({String schoolId, String className, String academicYear})>((ref, params) {
  final repo = ref.watch(feeRepositoryProvider);
  return repo.getFeeStructureByClass(params.schoolId, params.className, params.academicYear);
});

// FeeStructureV2 Providers
final feeStructuresV2Provider = StreamProvider.family<List<FeeStructureV2>, String>((ref, schoolId) {
  final repo = ref.watch(feeRepositoryProvider);
  return repo.getFeeStructuresV2Stream(schoolId);
});

final feeStructureV2ByClassProvider = FutureProvider.family<FeeStructureV2?, ({String schoolId, String className, String academicYear})>((ref, params) {
  final repo = ref.watch(feeRepositoryProvider);
  return repo.getFeeStructureV2ByClass(params.schoolId, params.className, params.academicYear);
});

// Student Fee Details Providers
final studentFeeDetailsProvider = StreamProvider.family<List<StudentFeeDetails>, String>((ref, schoolId) {
  final repo = ref.watch(feeRepositoryProvider);
  return repo.getAllStudentFeeDetailsStream(schoolId);
});

final studentFeeDetailsByIdProvider = FutureProvider.family<StudentFeeDetails?, ({String schoolId, String studentId})>((ref, params) {
  final repo = ref.watch(feeRepositoryProvider);
  return repo.getStudentFeeDetails(params.schoolId, params.studentId);
});

// Fee Payments Providers
final feePaymentsProvider = StreamProvider.family<List<FeePayment>, String>((ref, schoolId) {
  final repo = ref.watch(feeRepositoryProvider);
  return repo.getFeePaymentsStream(schoolId);
});

final feePaymentsByDateRangeProvider = FutureProvider.family<List<FeePayment>, ({String schoolId, DateTime startDate, DateTime endDate})>((ref, params) {
  final repo = ref.watch(feeRepositoryProvider);
  return repo.getFeePaymentsByDateRange(params.schoolId, params.startDate, params.endDate);
});

// Summary Providers
final feeSummaryProvider = FutureProvider.family<FeeSummary, String>((ref, schoolId) {
  final repo = ref.watch(feeRepositoryProvider);
  return repo.getFeeSummary(schoolId);
});

class FeeSummary {
  final double totalFees;
  final double collectedFees;
  final double outstandingFees;
  final int totalStudents;
  final int paidStudents;
  final int outstandingStudents;

  const FeeSummary({
    this.totalFees = 0.0,
    this.collectedFees = 0.0,
    this.outstandingFees = 0.0,
    this.totalStudents = 0,
    this.paidStudents = 0,
    this.outstandingStudents = 0,
  });
}

class FeeRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Collections
  CollectionReference<Map<String, dynamic>> _feeStructuresCollection(String schoolId) {
    return _firestore.collection('schools').doc(schoolId).collection('fee_structures');
  }

  CollectionReference<Map<String, dynamic>> _studentFeeDetailsCollection(String schoolId) {
    return _firestore.collection('schools').doc(schoolId).collection('student_fee_details');
  }

  CollectionReference<Map<String, dynamic>> _billsCollection(String schoolId) {
    return _firestore.collection('schools').doc(schoolId).collection('bills');
  }

  CollectionReference<Map<String, dynamic>> _feeStructuresV2Collection(String schoolId) {
    return _firestore.collection('schools').doc(schoolId).collection('feeStructuresV2');
  }

  CollectionReference<Map<String, dynamic>> _termFeePaymentsCollection(String schoolId) {
    return _firestore.collection('schools').doc(schoolId).collection('termFeePayments');
  }

  CollectionReference<Map<String, dynamic>> _studentFeeItemsCollection(String schoolId) {
    return _firestore.collection('schools').doc(schoolId).collection('studentFeeItems');
  }

  // ============ FEE STRUCTURES ============

  Stream<List<FeeStructure>> getFeeStructuresStream(String schoolId) {
    return _feeStructuresCollection(schoolId)
        .where('isActive', isEqualTo: true)
        .orderBy('className')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => FeeStructure.fromFirestore(doc)).toList());
  }

  Future<FeeStructure?> getFeeStructureByClass(String schoolId, String className, String academicYear) async {
    final snapshot = await _feeStructuresCollection(schoolId)
        .where('className', isEqualTo: className)
        .where('academicYear', isEqualTo: academicYear)
        .where('isActive', isEqualTo: true)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    return FeeStructure.fromFirestore(snapshot.docs.first);
  }

  Future<String> createFeeStructure(String schoolId, FeeStructure feeStructure) async {
    final docRef = await _feeStructuresCollection(schoolId).add(feeStructure.toFirestore());
    return docRef.id;
  }

  Future<void> updateFeeStructure(String schoolId, String id, FeeStructure feeStructure) async {
    await _feeStructuresCollection(schoolId).doc(id).update({
      ...feeStructure.toFirestore(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ============ STUDENT FEE DETAILS ============

  Stream<List<StudentFeeDetails>> getAllStudentFeeDetailsStream(String schoolId) {
    return _studentFeeDetailsCollection(schoolId)
        .orderBy('className')
        .orderBy('studentName')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => StudentFeeDetails.fromFirestore(doc)).toList());
  }

  Future<StudentFeeDetails?> getStudentFeeDetails(String schoolId, String studentId) async {
    final snapshot = await _studentFeeDetailsCollection(schoolId)
        .where('studentId', isEqualTo: studentId)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    return StudentFeeDetails.fromFirestore(snapshot.docs.first);
  }

  Future<List<StudentFeeDetails>> getStudentFeeDetailsByClass(String schoolId, String className) async {
    final snapshot = await _studentFeeDetailsCollection(schoolId)
        .where('className', isEqualTo: className)
        .orderBy('studentName')
        .get();
    return snapshot.docs.map((doc) => StudentFeeDetails.fromFirestore(doc)).toList();
  }

  Future<void> updateStudentFeeDetails(String schoolId, String id, StudentFeeDetails details) async {
    await _studentFeeDetailsCollection(schoolId).doc(id).update({
      ...details.toFirestore(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ============ FEE STRUCTURES V2 ============

  Stream<List<FeeStructureV2>> getFeeStructuresV2Stream(String schoolId) {
    return _feeStructuresV2Collection(schoolId)
        .orderBy('name')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => FeeStructureV2.fromFirestore(doc)).toList());
  }

  /// Finds the active FeeStructureV2 for a given class and academic year.
  /// If multiple are applicable to the class, the first is returned.
  Future<FeeStructureV2?> getFeeStructureV2ByClass(String schoolId, String className, String academicYear) async {
    final snapshot = await _feeStructuresV2Collection(schoolId)
        .where('academicYear', isEqualTo: academicYear)
        .where('applicableToClassIds', arrayContains: className)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    return FeeStructureV2.fromFirestore(snapshot.docs.first);
  }

  /// Lenient lookup: finds the most recent active FeeStructureV2 for the
  /// class **regardless of academic year**. Used as a soft fallback when
  /// importing a sheet whose target year has no structure yet — admins
  /// almost always want to reuse last/this year's structure rather than
  /// see "totals = 0". Returns the matching structure together with the
  /// academic year it was actually loaded from so callers can surface a
  /// notice to the user.
  Future<({FeeStructureV2 structure, String academicYear})?>
      getAnyActiveFeeStructureV2ByClass(
          String schoolId, String className) async {
    // Single-clause query keeps us off the composite-index code path.
    // We filter `isActive` client-side. Most schools have only a handful
    // of structures per class, so the extra docs read is negligible and
    // we avoid silent failures when the school admin hasn't deployed the
    // composite index.
    final snapshot = await _feeStructuresV2Collection(schoolId)
        .where('applicableToClassIds', arrayContains: className)
        .get();
    final activeDocs = snapshot.docs.where((d) {
      final v = d.data()['isActive'];
      // Treat missing field as active for backward compatibility with
      // older docs written before the flag was introduced.
      return v == null || v == true;
    }).toList();
    if (activeDocs.isEmpty) return null;
    // Prefer the structure with the lexicographically largest academic
    // year (e.g. "2026-27" > "2025-26"); good enough for school year
    // codes which are monotonic.
    activeDocs.sort((a, b) {
      final ay = (a.data()['academicYear'] ?? '').toString();
      final by = (b.data()['academicYear'] ?? '').toString();
      return by.compareTo(ay);
    });
    final picked = activeDocs.first;
    return (
      structure: FeeStructureV2.fromFirestore(picked),
      academicYear: (picked.data()['academicYear'] ?? '').toString(),
    );
  }

  /// Returns the next upcoming term (dueDate >= today) for a class/AY.
  /// If no upcoming term exists, returns null.
  Future<FeeTerm?> getNextDueTermForClass(String schoolId, String className, String academicYear) async {
    final structure = await getFeeStructureV2ByClass(schoolId, className, academicYear);
    if (structure == null) return null;

    final now = DateTime.now();
    final upcoming = structure.terms.where((t) => !t.dueDate.isBefore(now)).toList();
    if (upcoming.isEmpty) return null;

    // Return the soonest upcoming term
    upcoming.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return upcoming.first;
  }

  // ============ FEE PAYMENTS (BILLS - REVENUE) ============

  Stream<List<FeePayment>> getFeePaymentsStream(String schoolId) {
    return _billsCollection(schoolId)
        .where('billType', isEqualTo: 'Revenue')
        .where('isDeleted', isEqualTo: false)
        .orderBy('paymentDate', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => FeePayment.fromFirestore(doc)).toList());
  }

  Future<List<FeePayment>> getFeePaymentsByDateRange(String schoolId, DateTime startDate, DateTime endDate) async {
    final snapshot = await _billsCollection(schoolId)
        .where('billType', isEqualTo: 'Revenue')
        .where('isDeleted', isEqualTo: false)
        .where('billDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('billDate', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .orderBy('billDate', descending: true)
        .get();
    return snapshot.docs.map((doc) => FeePayment.fromFirestore(doc)).toList();
  }

  Future<List<FeePayment>> getFeePaymentsByStudent(String schoolId, String studentId) async {
    final snapshot = await _billsCollection(schoolId)
        .where('billType', isEqualTo: 'Revenue')
        .where('stuId', isEqualTo: studentId)
        .where('isDeleted', isEqualTo: false)
        .orderBy('billDate', descending: true)
        .get();
    return snapshot.docs.map((doc) => FeePayment.fromFirestore(doc)).toList();
  }

  Future<int> getNextBillId(String schoolId) async {
    final snapshot = await _billsCollection(schoolId)
        .orderBy('billId', descending: true)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return 1;
    final lastId = (snapshot.docs.first.data()['billId'] as num?)?.toInt() ?? 0;
    return lastId + 1;
  }

  Future<String> createFeePayment(String schoolId, FeePayment payment) async {
    final docRef = await _billsCollection(schoolId).add(payment.toFirestore());
    return docRef.id;
  }

  Future<void> deleteFeePayment(String schoolId, String paymentId, String reason) async {
    await _billsCollection(schoolId).doc(paymentId).update({
      'isDeleted': true,
      'isBillDeleted': true,
      'deletionReason': reason,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ============ SUMMARY & REPORTS ============

  Future<FeeSummary> getFeeSummary(String schoolId) async {
    final snapshot = await _studentFeeDetailsCollection(schoolId).get();
    
    double totalFees = 0.0;
    double collectedFees = 0.0;
    double outstandingFees = 0.0;
    int paidStudents = 0;
    int outstandingStudents = 0;
    int realStudents = 0;

    for (final doc in snapshot.docs) {
      final data = doc.data();
      // Skip legacy `_meta` placeholder seeds so freshly-provisioned
      // schools don't report phantom students.
      if (data['__system'] == true || data['isPlaceholder'] == true) continue;
      realStudents++;
      final total = (data['totalFees'] as num?)?.toDouble() ?? 0.0;
      final paid = (data['paidTotalFees'] as num?)?.toDouble() ?? 0.0;
      final balance = (data['balanceTotalFees'] as num?)?.toDouble() ?? 0.0;

      totalFees += total;
      collectedFees += paid;
      outstandingFees += balance;

      if (balance <= 0) {
        paidStudents++;
      } else {
        outstandingStudents++;
      }
    }

    return FeeSummary(
      totalFees: totalFees,
      collectedFees: collectedFees,
      outstandingFees: outstandingFees,
      totalStudents: realStudents,
      paidStudents: paidStudents,
      outstandingStudents: outstandingStudents,
    );
  }

  Future<Map<String, double>> getClassWiseCollection(String schoolId) async {
    final snapshot = await _studentFeeDetailsCollection(schoolId).get();
    final classWise = <String, double>{};

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final className = data['className'] as String? ?? 'Unknown';
      final paid = (data['paidTotalFees'] as num?)?.toDouble() ?? 0.0;
      classWise[className] = (classWise[className] ?? 0.0) + paid;
    }

    return classWise;
  }

  /// Get monthly revenue totals for a date range (aggregated by month)
  Future<Map<String, double>> getMonthlyRevenue(String schoolId, DateTime startDate, DateTime endDate) async {
    final monthly = <String, double>{};

    // Query term fee payments
    final termPaymentsSnap = await _termFeePaymentsCollection(schoolId)
        .where('paidAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('paidAt', isLessThan: Timestamp.fromDate(endDate))
        .get();

    for (final doc in termPaymentsSnap.docs) {
      final data = doc.data();
      final paidAt = (data['paidAt'] as Timestamp?)?.toDate();
      if (paidAt != null) {
        final key = '${paidAt.year}-${paidAt.month.toString().padLeft(2, '0')}';
        final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
        monthly[key] = (monthly[key] ?? 0.0) + amount;
      }
    }

    // Query student fee items (ad-hoc fees with payments)
    final feeItemsSnap = await _studentFeeItemsCollection(schoolId)
        .where('isActive', isEqualTo: true)
        .where('paidAmount', isGreaterThan: 0)
        .where('updatedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('updatedAt', isLessThan: Timestamp.fromDate(endDate))
        .get();

    for (final doc in feeItemsSnap.docs) {
      final data = doc.data();
      final updatedAt = (data['updatedAt'] as Timestamp?)?.toDate();
      if (updatedAt != null) {
        final key = '${updatedAt.year}-${updatedAt.month.toString().padLeft(2, '0')}';
        final amount = (data['paidAmount'] as num?)?.toDouble() ?? 0.0;
        monthly[key] = (monthly[key] ?? 0.0) + amount;
      }
    }

    return monthly;
  }

  Future<double> getTodayCollection(String schoolId) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    double total = 0.0;

    // Query term fee payments
    final termPaymentsSnap = await _termFeePaymentsCollection(schoolId)
        .where('paidAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('paidAt', isLessThan: Timestamp.fromDate(endOfDay))
        .get();

    for (final doc in termPaymentsSnap.docs) {
      total += (doc.data()['amount'] as num?)?.toDouble() ?? 0.0;
    }

    // Query student fee items (ad-hoc fees with payments today)
    final feeItemsSnap = await _studentFeeItemsCollection(schoolId)
        .where('isActive', isEqualTo: true)
        .where('paidAmount', isGreaterThan: 0)
        .where('updatedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('updatedAt', isLessThan: Timestamp.fromDate(endOfDay))
        .get();

    for (final doc in feeItemsSnap.docs) {
      total += (doc.data()['paidAmount'] as num?)?.toDouble() ?? 0.0;
    }

    return total;
  }
}
