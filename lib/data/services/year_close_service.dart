import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/student_fee_ledger.dart';

final yearCloseServiceProvider = Provider<YearCloseService>((ref) {
  return YearCloseService();
});

/// Per-student outcome of a year-close run.
class YearCloseOutcome {
  const YearCloseOutcome({
    required this.studentId,
    required this.studentName,
    required this.fromLedgerId,
    required this.carriedAmount,
    this.toLedgerId,
    this.error,
    this.skipped = false,
    this.skipReason,
  });

  final String studentId;
  final String studentName;
  final String fromLedgerId;
  final double carriedAmount;
  final String? toLedgerId;
  final String? error;
  final bool skipped;
  final String? skipReason;

  bool get isSuccess => error == null && !skipped;
}

/// Aggregated result for a year-close run.
class YearCloseReport {
  YearCloseReport({
    required this.fromAcademicYear,
    required this.toAcademicYear,
    required this.outcomes,
  });

  final String fromAcademicYear;
  final String toAcademicYear;
  final List<YearCloseOutcome> outcomes;

  int get successCount => outcomes.where((o) => o.isSuccess).length;
  int get skippedCount => outcomes.where((o) => o.skipped).length;
  int get errorCount => outcomes.where((o) => o.error != null).length;
  double get totalCarriedAmount =>
      outcomes.fold<double>(0, (s, o) => s + o.carriedAmount);
}

/// Closes an academic year by carrying every student's outstanding balance
/// from `fromAcademicYear` into the corresponding ledger for
/// `toAcademicYear` as **arrears** entries — one entry per (term + category)
/// that still has positive balance.
///
/// **Invariants:**
///   * The source ledger is **never deleted**. We mark it `closed: true`
///     so further edits are blocked at the UI layer; payment history is
///     preserved for audit.
///   * Idempotent: running close twice for the same (from, to) AY pair on
///     the same student is a no-op (we tag carried entries with
///     `carriedFromLedgerId` and skip if already present).
///   * The student must already have a ledger for `toAcademicYear`
///     (created via assign-fee-structure or sheet upload). If they don't,
///     the outcome is `skipped` with reason — the admin must assign the
///     new-year structure first.
class YearCloseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _ledgers(String schoolId) =>
      _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('studentFeeLedgers');

  CollectionReference<Map<String, dynamic>> _audit(String schoolId) =>
      _firestore.collection('schools').doc(schoolId).collection('yearCloseAudits');

  /// Pre-flight: count how many ledgers will be touched and the total
  /// outstanding amount. Lets the admin confirm before committing.
  Future<({int ledgerCount, double totalOutstanding, int missingTargetCount})>
      previewClose({
    required String schoolId,
    required String fromAcademicYear,
    required String toAcademicYear,
  }) async {
    final fromSnap = await _ledgers(schoolId)
        .where('academicYear', isEqualTo: fromAcademicYear)
        .get();
    final fromLedgers = fromSnap.docs
        .where((d) => (d.data()['isArchived'] as bool? ?? false) == false)
        .where((d) => (d.data()['closed'] as bool? ?? false) == false)
        .map(StudentFeeLedger.fromFirestore)
        .where((l) => l.totalPending > 0.001)
        .toList();

    int missing = 0;
    double totalOut = 0;
    for (final l in fromLedgers) {
      totalOut += l.totalPending;
      final target = await _ledgers(schoolId)
          .where('studentId', isEqualTo: l.studentId)
          .where('academicYear', isEqualTo: toAcademicYear)
          .limit(1)
          .get();
      if (target.docs.isEmpty) missing++;
    }
    return (
      ledgerCount: fromLedgers.length,
      totalOutstanding: totalOut,
      missingTargetCount: missing,
    );
  }

  /// Run the close. Returns a per-student report.
  Future<YearCloseReport> closeYear({
    required String schoolId,
    required String fromAcademicYear,
    required String toAcademicYear,
    String? actorUid,
    String? actorName,
  }) async {
    if (fromAcademicYear.isEmpty || toAcademicYear.isEmpty) {
      throw ArgumentError('Both academic years are required');
    }
    if (fromAcademicYear == toAcademicYear) {
      throw ArgumentError('From and To academic year must differ');
    }

    final fromSnap = await _ledgers(schoolId)
        .where('academicYear', isEqualTo: fromAcademicYear)
        .get();
    final fromLedgers = fromSnap.docs
        .where((d) => (d.data()['isArchived'] as bool? ?? false) == false)
        .map(StudentFeeLedger.fromFirestore)
        .toList();

    final outcomes = <YearCloseOutcome>[];
    for (final source in fromLedgers) {
      try {
        final outcome = await _closeOne(
          schoolId: schoolId,
          source: source,
          toAcademicYear: toAcademicYear,
        );
        outcomes.add(outcome);
      } catch (e) {
        outcomes.add(YearCloseOutcome(
          studentId: source.studentId,
          studentName: source.studentName,
          fromLedgerId: source.id,
          carriedAmount: 0,
          error: e.toString(),
        ));
      }
    }

    // Audit doc.
    await _audit(schoolId).add({
      'fromAcademicYear': fromAcademicYear,
      'toAcademicYear': toAcademicYear,
      'ranAt': FieldValue.serverTimestamp(),
      'actorUid': actorUid,
      'actorName': actorName,
      'totalLedgers': outcomes.length,
      'successCount': outcomes.where((o) => o.isSuccess).length,
      'skippedCount': outcomes.where((o) => o.skipped).length,
      'errorCount': outcomes.where((o) => o.error != null).length,
      'totalCarriedAmount':
          outcomes.fold<double>(0, (s, o) => s + o.carriedAmount),
    });

    return YearCloseReport(
      fromAcademicYear: fromAcademicYear,
      toAcademicYear: toAcademicYear,
      outcomes: outcomes,
    );
  }

  Future<YearCloseOutcome> _closeOne({
    required String schoolId,
    required StudentFeeLedger source,
    required String toAcademicYear,
  }) async {
    // Find the student's target-AY ledger.
    final targetSnap = await _ledgers(schoolId)
        .where('studentId', isEqualTo: source.studentId)
        .where('academicYear', isEqualTo: toAcademicYear)
        .limit(1)
        .get();

    if (targetSnap.docs.isEmpty) {
      // Mark source closed even if no carry-forward target — there's nothing
      // to do but the admin still wants the AY locked. Skip the carry.
      return YearCloseOutcome(
        studentId: source.studentId,
        studentName: source.studentName,
        fromLedgerId: source.id,
        carriedAmount: 0,
        skipped: true,
        skipReason:
            'No ledger for $toAcademicYear — assign the new-year fee structure first.',
      );
    }

    final targetRef = targetSnap.docs.first.reference;
    final sourceRef = _ledgers(schoolId).doc(source.id);

    return _firestore.runTransaction<YearCloseOutcome>((txn) async {
      final targetDoc = await txn.get(targetRef);
      final sourceDoc = await txn.get(sourceRef);
      if (!targetDoc.exists || !sourceDoc.exists) {
        throw Exception('Ledger disappeared mid-transaction');
      }
      final source2 = StudentFeeLedger.fromFirestore(sourceDoc);
      final target = StudentFeeLedger.fromFirestore(targetDoc);

      // Idempotency: if target already has any entry tagged with this
      // source ledger id, we've already carried — bail out cleanly.
      final alreadyCarried = target.termStatus.any((e) =>
          e.isArrear && e.sourceAcademicYear == source2.academicYear);
      if (alreadyCarried) {
        // Still ensure source is closed.
        if (!(sourceDoc.data()?['closed'] as bool? ?? false)) {
          txn.update(sourceRef, {
            'closed': true,
            'closedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
        return YearCloseOutcome(
          studentId: source2.studentId,
          studentName: source2.studentName,
          fromLedgerId: source2.id,
          toLedgerId: target.id,
          carriedAmount: 0,
          skipped: true,
          skipReason: 'Already carried in a previous run.',
        );
      }

      // Build arrears entries — one per source term that still has balance.
      // We preserve the term's category so the new-AY UI groups it correctly.
      final carried = <TermLedgerEntry>[];
      double carriedTotal = 0;
      for (final t in source2.termStatus) {
        final bal = t.balanceAmount;
        if (bal <= 0.001) continue;
        carried.add(TermLedgerEntry(
          termId: 'arrear_${source2.id}_${t.termId}',
          termName: '${t.termName} (Arrears ${source2.academicYear})',
          // Use a high sequence so arrears render after current-year terms.
          sequence: 10000 + t.sequence,
          amount: bal,
          dueDate: t.dueDate,
          category: t.category,
          isArrear: true,
          sourceAcademicYear: source2.academicYear,
          sourceClass: source2.className,
        ));
        carriedTotal += bal;
      }

      if (carried.isEmpty) {
        // Nothing to carry — still close source.
        txn.update(sourceRef, {
          'closed': true,
          'closedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return YearCloseOutcome(
          studentId: source2.studentId,
          studentName: source2.studentName,
          fromLedgerId: source2.id,
          toLedgerId: target.id,
          carriedAmount: 0,
          skipped: true,
          skipReason: 'No outstanding balance to carry.',
        );
      }

      final newEntries = [...target.termStatus, ...carried];
      final newAssigned = target.totalAssigned + carriedTotal;
      final newPending = (newAssigned + target.totalLateFee - target.totalPaid)
          .clamp(0, double.infinity)
          .toDouble();

      txn.update(targetRef, {
        'termStatus': newEntries.map((e) => e.toMap()).toList(),
        'totalAssigned': newAssigned,
        'totalPending': newPending,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      txn.update(sourceRef, {
        'closed': true,
        'closedAt': FieldValue.serverTimestamp(),
        'carriedToLedgerId': target.id,
        'carriedAmount': carriedTotal,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return YearCloseOutcome(
        studentId: source2.studentId,
        studentName: source2.studentName,
        fromLedgerId: source2.id,
        toLedgerId: target.id,
        carriedAmount: carriedTotal,
      );
    });
  }
}
