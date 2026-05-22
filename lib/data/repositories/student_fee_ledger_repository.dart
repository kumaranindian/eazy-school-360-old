import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/fee_structure_v2.dart';
import '../../domain/entities/student_fee_ledger.dart';
import 'fee_structure_v2_repository.dart';

final studentFeeLedgerRepositoryProvider =
    Provider<StudentFeeLedgerRepository>((ref) {
  return StudentFeeLedgerRepository(
    structureRepo: ref.watch(feeStructureV2RepositoryProvider),
  );
});

/// Stream all ledgers for a school (filtered by AY client-side as needed).
final studentFeeLedgersProvider =
    StreamProvider.family<List<StudentFeeLedger>, String>((ref, schoolId) {
  return ref.watch(studentFeeLedgerRepositoryProvider).watchAll(schoolId);
});

final studentFeeLedgerByStudentProvider = FutureProvider.family<
    StudentFeeLedger?,
    ({String schoolId, String studentId, String academicYear})>((ref, p) {
  return ref
      .watch(studentFeeLedgerRepositoryProvider)
      .getByStudent(p.schoolId, p.studentId, p.academicYear);
});

class StudentFeeLedgerRepository {
  StudentFeeLedgerRepository({required this.structureRepo});

  final FeeStructureV2Repository structureRepo;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String schoolId) => _firestore
      .collection('schools')
      .doc(schoolId)
      .collection('studentFeeLedgers');

  Stream<List<StudentFeeLedger>> watchAll(String schoolId) {
    return _col(schoolId)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((s) =>
            s.docs.map((d) => StudentFeeLedger.fromFirestore(d)).toList());
  }

  Future<List<StudentFeeLedger>> listByClass(
      String schoolId, String academicYear, String className) async {
    final snap = await _col(schoolId)
        .where('academicYear', isEqualTo: academicYear)
        .where('className', isEqualTo: className)
        .get();
    return snap.docs.map((d) => StudentFeeLedger.fromFirestore(d)).toList();
  }

  Future<StudentFeeLedger?> getByStudent(
      String schoolId, String studentId, String academicYear) async {
    print('[StudentFeeLedgerRepository] getByStudent: schoolId=$schoolId, studentId=$studentId (${studentId.runtimeType}), academicYear=$academicYear');
    final snap = await _col(schoolId)
        .where('studentId', isEqualTo: studentId)
        .where('academicYear', isEqualTo: academicYear)
        .limit(1)
        .get();
    print('[StudentFeeLedgerRepository] Query returned ${snap.docs.length} documents');
    if (snap.docs.isEmpty) {
      // Try querying with numeric studentId as well
      final numericId = int.tryParse(studentId);
      if (numericId != null) {
        print('[StudentFeeLedgerRepository] Trying numeric studentId: $numericId');
        final snap2 = await _col(schoolId)
            .where('studentId', isEqualTo: numericId)
            .where('academicYear', isEqualTo: academicYear)
            .limit(1)
            .get();
        print('[StudentFeeLedgerRepository] Numeric query returned ${snap2.docs.length} documents');
        if (snap2.docs.isNotEmpty) {
          return StudentFeeLedger.fromFirestore(snap2.docs.first);
        }
      }
      return null;
    }
    return StudentFeeLedger.fromFirestore(snap.docs.first);
  }

  Future<StudentFeeLedger?> getById(String schoolId, String ledgerId) async {
    final doc = await _col(schoolId).doc(ledgerId).get();
    if (!doc.exists) return null;
    return StudentFeeLedger.fromFirestore(doc);
  }

  /// Builds a fresh ledger from a structure for a single student.
  StudentFeeLedger buildLedger({
    required String schoolId,
    required String studentId,
    required String studentName,
    required String className,
    required String section,
    required FeeStructureV2 structure,
    String? parentName,
    String? parentPhone,
  }) {
    final now = DateTime.now();
    final terms = [...structure.terms]
      ..sort((a, b) => a.sequence.compareTo(b.sequence));
    final entries = terms
        .map((t) => TermLedgerEntry(
              termId: t.id,
              termName: t.termName,
              sequence: t.sequence,
              amount: t.amount,
              dueDate: t.dueDate,
              category: t.category,
            ))
        .toList();

    final total = entries.fold<double>(0, (s, e) => s + e.amount);
    return StudentFeeLedger(
      id: '',
      schoolId: schoolId,
      studentId: studentId,
      studentName: studentName,
      className: className,
      section: section,
      academicYear: structure.academicYear,
      feeStructureId: structure.id,
      feeStructureName: structure.name,
      totalAssigned: total,
      totalPending: total,
      termStatus: entries,
      parentName: parentName,
      parentPhone: parentPhone,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Pre-flight: returns the *active* ledger for this student in the given AY
  /// (each student has at most one active fee structure per AY in this app).
  /// Used to detect "would I be replacing another structure?" conflicts.
  Future<StudentFeeLedger?> findActiveLedger({
    required String schoolId,
    required String studentId,
    required String academicYear,
  }) =>
      getByStudent(schoolId, studentId, academicYear);

  /// Computes a non-mutating plan for what would happen if we assigned
  /// [structure] to [students]. Lets the UI show the summary up front and ask
  /// the admin to choose a [ConflictAction] before committing.
  Future<AssignmentPlan> planAssignment({
    required String schoolId,
    required FeeStructureV2 structure,
    required List<AssignTarget> students,
  }) async {
    final results = <AssignmentPreview>[];
    for (final s in students) {
      final existing = await findActiveLedger(
        schoolId: schoolId,
        studentId: s.studentId,
        academicYear: structure.academicYear,
      );
      AssignmentOutcome status;
      double paidOnExisting = 0;
      if (existing == null) {
        status = AssignmentOutcome.NEW;
      } else if (existing.feeStructureId == structure.id) {
        status = AssignmentOutcome.ALREADY_ASSIGNED;
        paidOnExisting = existing.totalPaid;
      } else if (existing.totalPaid > 0) {
        status = AssignmentOutcome.CONFLICT_WITH_PAID;
        paidOnExisting = existing.totalPaid;
      } else {
        status = AssignmentOutcome.CONFLICT_NO_PAID;
      }
      results.add(AssignmentPreview(
        target: s,
        existing: existing,
        status: status,
        paidOnExisting: paidOnExisting,
      ));
    }
    return AssignmentPlan(structure: structure, items: results);
  }

  /// Assign or update a structure on a single student, governed by a conflict
  /// policy. Returns a precise [AssignmentResult] so the caller can report
  /// outcomes (created / refreshed / skipped / replaced).
  ///
  /// Invariants:
  ///   * Each (studentId, academicYear) has at most ONE active ledger.
  ///   * Paid amounts are *always* preserved across same-structure refresh.
  ///   * On REPLACE with paid amounts, the prior ledger is **archived**
  ///     (`isArchived: true`) so audit history is never silently destroyed.
  Future<AssignmentResult> assignToStudent({
    required String schoolId,
    required String studentId,
    required String studentName,
    required String className,
    required String section,
    required String structureId,
    String? parentName,
    String? parentPhone,
    ConflictAction onConflict = ConflictAction.SKIP,
  }) async {
    final structure = await structureRepo.getWithTerms(schoolId, structureId);
    if (structure == null) {
      throw Exception('Fee structure not found');
    }

    final existing =
        await getByStudent(schoolId, studentId, structure.academicYear);

    var fresh = buildLedger(
      schoolId: schoolId,
      studentId: studentId,
      studentName: studentName,
      className: className,
      section: section,
      structure: structure,
      parentName: parentName,
      parentPhone: parentPhone,
    );

    // Load arrears from student_fee_details and add to ledger
    final arrearsEntries = await _loadArrearsEntries(
      schoolId: schoolId,
      studentId: studentId,
      academicYear: structure.academicYear,
    );
    if (arrearsEntries.isNotEmpty) {
      fresh = fresh.copyWith(
        termStatus: [...fresh.termStatus, ...arrearsEntries],
        totalAssigned: fresh.totalAssigned +
            arrearsEntries.fold<double>(0, (s, e) => s + e.amount),
        totalPending: fresh.totalPending +
            arrearsEntries.fold<double>(0, (s, e) => s + e.amount),
      );
    }

    // ── Case 1: brand new ────────────────────────────────────────────────
    if (existing == null) {
      print('[StudentFeeLedgerRepository] Creating new ledger for studentId=$studentId, academicYear=${structure.academicYear}');
      final ref = await _col(schoolId).add(fresh.toFirestore());
      print('[StudentFeeLedgerRepository] New ledger created with ID: ${ref.id}');
      return AssignmentResult(
        ledgerId: ref.id,
        outcome: AssignmentOutcome.NEW,
      );
    }

    // ── Case 2: same structure → idempotent refresh (always allowed) ─────
    if (existing.feeStructureId == structure.id) {
      final mergedEntries = _mergePaidAmounts(fresh, existing);
      await _writeMerged(
        schoolId: schoolId,
        existing: existing,
        fresh: fresh,
        mergedEntries: mergedEntries,
        parentName: parentName,
        parentPhone: parentPhone,
      );
      return AssignmentResult(
        ledgerId: existing.id,
        outcome: AssignmentOutcome.ALREADY_ASSIGNED,
      );
    }

    // ── Case 3: different structure → governed by [onConflict] ───────────
    switch (onConflict) {
      case ConflictAction.SKIP:
        return AssignmentResult(
          ledgerId: existing.id,
          outcome: existing.totalPaid > 0
              ? AssignmentOutcome.CONFLICT_WITH_PAID
              : AssignmentOutcome.CONFLICT_NO_PAID,
          skipped: true,
          previousStructureName: existing.feeStructureName,
        );

      case ConflictAction.REPLACE:
        // Archive the old ledger to keep audit trail.
        await _col(schoolId).doc(existing.id).update({
          'isArchived': true,
          'archivedAt': FieldValue.serverTimestamp(),
          'archivedReason':
              'Replaced by structure "${structure.name}" via bulk-assign',
          'updatedAt': FieldValue.serverTimestamp(),
        });
        final ref = await _col(schoolId).add(fresh.toFirestore());
        return AssignmentResult(
          ledgerId: ref.id,
          outcome: existing.totalPaid > 0
              ? AssignmentOutcome.REPLACED_WITH_PAID
              : AssignmentOutcome.REPLACED,
          previousLedgerId: existing.id,
          previousStructureName: existing.feeStructureName,
          paidAmountOnPrevious: existing.totalPaid,
        );
    }
  }

  List<TermLedgerEntry> _mergePaidAmounts(
      StudentFeeLedger fresh, StudentFeeLedger existing) {
    return fresh.termStatus.map((t) {
      final prior = existing.termStatus.firstWhere(
        (p) => p.termId == t.termId,
        orElse: () => t,
      );
      return t.copyWith(
        paidAmount: prior.paidAmount,
        lateFeeApplied: prior.lateFeeApplied,
        status: prior.status,
        paidAt: prior.paidAt,
        paymentIds: prior.paymentIds,
      );
    }).toList();
  }

  Future<void> _writeMerged({
    required String schoolId,
    required StudentFeeLedger existing,
    required StudentFeeLedger fresh,
    required List<TermLedgerEntry> mergedEntries,
    String? parentName,
    String? parentPhone,
  }) async {
    final paid = mergedEntries.fold<double>(0, (s, e) => s + e.paidAmount);
    final lateFees =
        mergedEntries.fold<double>(0, (s, e) => s + e.lateFeeApplied);
    final updated = existing.copyWith(
      feeStructureName: fresh.feeStructureName,
      totalAssigned: fresh.totalAssigned,
      totalPaid: paid,
      totalPending:
          (fresh.totalAssigned + lateFees - paid).clamp(0, double.infinity),
      totalLateFee: lateFees,
      termStatus: mergedEntries,
      parentName: parentName ?? existing.parentName,
      parentPhone: parentPhone ?? existing.parentPhone,
      updatedAt: DateTime.now(),
    );
    await _col(schoolId).doc(existing.id).set(updated.toFirestore());
  }

  /// Loads arrears from student_fee_details collection and converts to TermLedgerEntry objects
  Future<List<TermLedgerEntry>> _loadArrearsEntries({
    required String schoolId,
    required String studentId,
    required String academicYear,
  }) async {
    final entries = <TermLedgerEntry>[];
    try {
      final snap = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('student_fee_details')
          .where('stuId', isEqualTo: int.tryParse(studentId) ?? 0)
          .where('academicYear', isEqualTo: academicYear)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) return entries;

      final data = snap.docs.first.data();
      final balanceArrearTuition =
          (data['balanceArrearTuitionFees'] as num?)?.toDouble() ?? 0;
      final balanceArrearExam =
          (data['balanceArrearExamFees'] as num?)?.toDouble() ?? 0;
      final balanceArrearVan =
          (data['balanceArrearVanFees'] as num?)?.toDouble() ?? 0;
      final arrearsAy = (data['arrearsAcademicYear'] ?? '').toString();

      // Calculate previous AY if not stored
      final prevAy = arrearsAy.isNotEmpty
          ? arrearsAy
          : _getPreviousAcademicYear(academicYear);

      if (balanceArrearTuition > 0) {
        entries.add(TermLedgerEntry(
          termId: 'ARREARS_TUITION_$prevAy',
          termName: 'Tuition Arrears',
          sequence: 999,
          amount: balanceArrearTuition,
          dueDate: DateTime.now(),
          paidAmount: 0,
          category: 'TUITION',
          isArrear: true,
          sourceAcademicYear: prevAy,
        ));
      }
      if (balanceArrearExam > 0) {
        entries.add(TermLedgerEntry(
          termId: 'ARREARS_EXAM_$prevAy',
          termName: 'Exam Arrears',
          sequence: 999,
          amount: balanceArrearExam,
          dueDate: DateTime.now(),
          paidAmount: 0,
          category: 'EXAM',
          isArrear: true,
          sourceAcademicYear: prevAy,
        ));
      }
      if (balanceArrearVan > 0) {
        entries.add(TermLedgerEntry(
          termId: 'ARREARS_VAN_$prevAy',
          termName: 'Van Arrears',
          sequence: 999,
          amount: balanceArrearVan,
          dueDate: DateTime.now(),
          paidAmount: 0,
          category: 'VAN',
          isArrear: true,
          sourceAcademicYear: prevAy,
        ));
      }
    } catch (e) {
      // Log error but don't fail the assignment
      print('[StudentFeeLedgerRepository] Failed to load arrears: $e');
    }
    return entries;
  }

  /// Calculates previous academic year from current AY (e.g., 2026-2027 → 2025-2026)
  String _getPreviousAcademicYear(String currentAy) {
    final match = RegExp(r'^(\d{4})').firstMatch(currentAy);
    if (match == null) return currentAy;
    final startYear = int.tryParse(match.group(1)!) ?? DateTime.now().year;
    return '${startYear - 1}-${startYear - 1 + 1}';
  }

  /// Bulk-assign with conflict policy + per-student outcome tracking.
  Future<List<AssignmentResult>> assignToStudents({
    required String schoolId,
    required String structureId,
    required List<AssignTarget> students,
    ConflictAction onConflict = ConflictAction.SKIP,
  }) async {
    final out = <AssignmentResult>[];
    for (final s in students) {
      try {
        final r = await assignToStudent(
          schoolId: schoolId,
          studentId: s.studentId,
          studentName: s.studentName,
          className: s.className,
          section: s.section,
          structureId: structureId,
          parentName: s.parentName,
          parentPhone: s.parentPhone,
          onConflict: onConflict,
        );
        out.add(r);
      } catch (e) {
        out.add(AssignmentResult(
          ledgerId: '',
          outcome: AssignmentOutcome.ERROR,
          error: e.toString(),
        ));
      }
    }
    return out;
  }

  Future<void> setRemindersEnabled(
      String schoolId, String ledgerId, bool enabled) async {
    await _col(schoolId).doc(ledgerId).update({
      'remindersEnabled': enabled,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Update or add a VAN fee term in the student's ledger.
  /// This is called when van fee is updated via the student edit dialog.
  Future<void> updateVanFeeTerm({
    required String schoolId,
    required String studentId,
    required String academicYear,
    required double vanFee,
  }) async {
    final ledger = await getByStudent(schoolId, studentId, academicYear);
    if (ledger == null) {
      print('[StudentFeeLedgerRepository] No ledger found for student $studentId, cannot update van fee');
      return;
    }

    // Find existing VAN term or create new one
    final existingTerms = [...ledger.termStatus];
    final vanTermIndex = existingTerms.indexWhere(
      (t) => t.category.toUpperCase() == 'VAN' && !t.isArrear,
    );

    final now = DateTime.now();
    final newVanTerm = TermLedgerEntry(
      termId: 'VAN_FEE_${academicYear}_${now.millisecondsSinceEpoch}',
      termName: 'Van Fee',
      sequence: 100,
      amount: vanFee,
      dueDate: now,
      category: 'VAN',
      isArrear: false,
    );

    if (vanTermIndex >= 0) {
      // Preserve any paid amount from existing term
      final existing = existingTerms[vanTermIndex];
      existingTerms[vanTermIndex] = newVanTerm.copyWith(
        paidAmount: existing.paidAmount,
        status: existing.status,
        paidAt: existing.paidAt,
        paymentIds: existing.paymentIds,
      );
    } else {
      // Add new VAN term
      existingTerms.add(newVanTerm);
    }

    // Recalculate totals
    final totalAssigned = existingTerms.fold<double>(0, (s, e) => s + e.amount);
    final totalPaid = existingTerms.fold<double>(0, (s, e) => s + e.paidAmount);
    final totalLateFee = existingTerms.fold<double>(0, (s, e) => s + e.lateFeeApplied);
    final totalPending = (totalAssigned + totalLateFee - totalPaid).clamp(0, double.infinity);

    await _col(schoolId).doc(ledger.id).update({
      'termStatus': existingTerms.map((e) => e.toMap()).toList(),
      'totalAssigned': totalAssigned,
      'totalPaid': totalPaid,
      'totalPending': totalPending,
      'totalLateFee': totalLateFee,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    print('[StudentFeeLedgerRepository] Updated VAN fee to $vanFee for student $studentId');
  }

  /// Update concession amount in the student's ledger.
  /// This reduces the total pending amount by the concession value.
  /// Concession is stored as a separate field and applied to tuition first.
  Future<void> updateConcession({
    required String schoolId,
    required String studentId,
    required String academicYear,
    required double concessionAmount,
  }) async {
    final ledger = await getByStudent(schoolId, studentId, academicYear);
    if (ledger == null) {
      print('[StudentFeeLedgerRepository] No ledger found for student $studentId, cannot update concession');
      return;
    }

    // Store concession as a field on the ledger document
    // The totalPending will be calculated as: totalAssigned - totalPaid - concession
    final totalAssigned = ledger.totalAssigned;
    final totalPaid = ledger.totalPaid;
    final totalLateFee = ledger.totalLateFee;
    
    // Calculate new pending with concession applied
    // Concession reduces the pending amount (applied to tuition first conceptually)
    final totalPending = (totalAssigned + totalLateFee - totalPaid - concessionAmount).clamp(0, double.infinity);

    await _col(schoolId).doc(ledger.id).update({
      'totalConcession': concessionAmount,
      'totalPending': totalPending,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    print('[StudentFeeLedgerRepository] Updated concession to $concessionAmount for student $studentId, new pending: $totalPending');
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Value types for the conflict-aware assignment API.
// ─────────────────────────────────────────────────────────────────────────────

/// What to do when a student already has a *different* active fee structure
/// for the same academic year.
enum ConflictAction {
  /// Leave the existing ledger untouched. Default — safest.
  SKIP,

  /// Archive the existing ledger and create a new one for the new structure.
  /// The archived ledger keeps `isArchived=true` and its payment history is
  /// preserved for audit purposes.
  REPLACE,
}

/// Outcome of a single-student assignment attempt.
enum AssignmentOutcome {
  /// Brand-new ledger was created.
  NEW,

  /// Student already had this same structure assigned. Ledger refreshed
  /// in place; paid amounts preserved.
  ALREADY_ASSIGNED,

  /// Student had a *different* structure but **no payments** on it,
  /// and the caller chose [ConflictAction.SKIP].
  CONFLICT_NO_PAID,

  /// Student had a *different* structure with **payments** on it,
  /// and the caller chose [ConflictAction.SKIP].
  CONFLICT_WITH_PAID,

  /// Student had a different structure (no payments). The old ledger was
  /// archived and a new one was created.
  REPLACED,

  /// Student had a different structure **with payments**. Old ledger was
  /// archived (history preserved) and a new one created. Caller should be
  /// shown a clear warning.
  REPLACED_WITH_PAID,

  /// Per-row failure during bulk assign.
  ERROR,
}

/// Lightweight target specification for bulk-assign.
class AssignTarget {
  const AssignTarget({
    required this.studentId,
    required this.studentName,
    required this.className,
    required this.section,
    this.parentName,
    this.parentPhone,
  });

  final String studentId;
  final String studentName;
  final String className;
  final String section;
  final String? parentName;
  final String? parentPhone;
}

/// Pre-flight preview for one student in [planAssignment].
class AssignmentPreview {
  const AssignmentPreview({
    required this.target,
    required this.existing,
    required this.status,
    required this.paidOnExisting,
  });

  final AssignTarget target;
  final StudentFeeLedger? existing;
  final AssignmentOutcome status;
  final double paidOnExisting;

  bool get isConflict =>
      status == AssignmentOutcome.CONFLICT_NO_PAID ||
      status == AssignmentOutcome.CONFLICT_WITH_PAID;
}

/// Aggregated pre-flight result over a list of students.
class AssignmentPlan {
  const AssignmentPlan({required this.structure, required this.items});

  final FeeStructureV2 structure;
  final List<AssignmentPreview> items;

  int get newCount =>
      items.where((i) => i.status == AssignmentOutcome.NEW).length;
  int get alreadyAssignedCount =>
      items.where((i) => i.status == AssignmentOutcome.ALREADY_ASSIGNED).length;
  int get conflictNoPaidCount =>
      items.where((i) => i.status == AssignmentOutcome.CONFLICT_NO_PAID).length;
  int get conflictWithPaidCount => items
      .where((i) => i.status == AssignmentOutcome.CONFLICT_WITH_PAID)
      .length;

  bool get hasAnyConflict =>
      conflictNoPaidCount > 0 || conflictWithPaidCount > 0;
  bool get hasPaidConflict => conflictWithPaidCount > 0;
}

/// Result of a single-student assignment commit.
class AssignmentResult {
  const AssignmentResult({
    required this.ledgerId,
    required this.outcome,
    this.skipped = false,
    this.previousLedgerId,
    this.previousStructureName,
    this.paidAmountOnPrevious = 0,
    this.error,
  });

  final String ledgerId;
  final AssignmentOutcome outcome;
  final bool skipped;
  final String? previousLedgerId;
  final String? previousStructureName;
  final double paidAmountOnPrevious;
  final String? error;
}
