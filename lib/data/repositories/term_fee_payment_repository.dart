import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/student_fee_ledger.dart';
import '../../domain/entities/term_fee_payment.dart';

final termFeePaymentRepositoryProvider =
    Provider<TermFeePaymentRepository>((ref) {
  return TermFeePaymentRepository();
});

final termPaymentsByLedgerProvider =
    FutureProvider.family<List<TermFeePayment>, ({String schoolId, String ledgerId})>((ref, p) {
  return ref
      .watch(termFeePaymentRepositoryProvider)
      .listByLedger(p.schoolId, p.ledgerId);
});

class RecordTermPaymentRequest {
  final String schoolId;
  final String ledgerId;
  final String termId;
  final double amount;
  final TermPaymentMode paymentMode;
  final String? transactionRef;
  final DateTime paidAt;
  final String? notes;
  final String? collectedBy;
  final String? collectedByName;
  final List<Map<String, dynamic>> components;

  const RecordTermPaymentRequest({
    required this.schoolId,
    required this.ledgerId,
    required this.termId,
    required this.amount,
    this.paymentMode = TermPaymentMode.CASH,
    this.transactionRef,
    required this.paidAt,
    this.notes,
    this.collectedBy,
    this.collectedByName,
    this.components = const [],
  });
}

class TermFeePaymentRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _paymentsCol(String schoolId) =>
      _firestore.collection('schools').doc(schoolId).collection('termFeePayments');

  CollectionReference<Map<String, dynamic>> _ledgersCol(String schoolId) =>
      _firestore.collection('schools').doc(schoolId).collection('studentFeeLedgers');

  CollectionReference<Map<String, dynamic>> _settingsCol(String schoolId) =>
      _firestore.collection('schools').doc(schoolId).collection('financeSettings');

  Future<List<TermFeePayment>> listByLedger(
      String schoolId, String ledgerId) async {
    final snap = await _paymentsCol(schoolId)
        .where('ledgerId', isEqualTo: ledgerId)
        .where('isDeleted', isEqualTo: false)
        .orderBy('paidAt', descending: true)
        .get();
    return snap.docs.map((d) => TermFeePayment.fromFirestore(d)).toList();
  }

  Future<List<TermFeePayment>> listByStudent(
      String schoolId, String studentId) async {
    final snap = await _paymentsCol(schoolId)
        .where('studentId', isEqualTo: studentId)
        .where('isDeleted', isEqualTo: false)
        .orderBy('paidAt', descending: true)
        .get();
    return snap.docs.map((d) => TermFeePayment.fromFirestore(d)).toList();
  }

  /// Atomically record a term payment + update the student ledger.
  /// Returns the saved [TermFeePayment].
  Future<TermFeePayment> recordPayment(RecordTermPaymentRequest req) async {
    if (req.amount <= 0) {
      throw Exception('Amount must be greater than zero');
    }

    final ledgerRef = _ledgersCol(req.schoolId).doc(req.ledgerId);
    final paymentRef = _paymentsCol(req.schoolId).doc();
    final receiptCounterRef = _settingsCol(req.schoolId).doc('receiptCounter');

    final result = await _firestore.runTransaction<TermFeePayment>((txn) async {
      final ledgerSnap = await txn.get(ledgerRef);
      if (!ledgerSnap.exists) {
        throw Exception('Student ledger not found');
      }
      final ledger = StudentFeeLedger.fromFirestore(ledgerSnap);

      // Locate the term inside termStatus.
      final entries = [...ledger.termStatus];
      final idx = entries.indexWhere((t) => t.termId == req.termId);
      if (idx < 0) {
        throw Exception('Term ${req.termId} not on ledger');
      }
      final term = entries[idx];
      final balance = term.balanceAmount;
      if (req.amount > balance + 0.01) {
        throw Exception(
            'Amount ₹${req.amount.toStringAsFixed(2)} exceeds balance ₹${balance.toStringAsFixed(2)}');
      }

      // Receipt counter (per-school).
      final counterSnap = await txn.get(receiptCounterRef);
      final next = ((counterSnap.data()?['value'] as num?)?.toInt() ?? 0) + 1;
      final prefix =
          (counterSnap.data()?['prefix'] as String?) ?? 'RCPT-';
      final receiptNumber =
          '$prefix${next.toString().padLeft(6, '0')}';

      // Bill ID (sequential int) — kept for legacy receipt parity.
      final billId = next;

      final updatedTerm = term.copyWith(
        paidAmount: term.paidAmount + req.amount,
        paymentIds: [...term.paymentIds, paymentRef.id],
        paidAt: req.paidAt,
        status: _resolveStatus(term.amount, term.paidAmount + req.amount,
            term.lateFeeApplied, term.dueDate),
      );
      entries[idx] = updatedTerm;

      final newPaid = ledger.totalPaid + req.amount;
      final newPending = (ledger.totalAssigned + ledger.totalLateFee - newPaid)
          .clamp(0, double.infinity)
          .toDouble();
      final overdueSum = entries
          .where((t) => t.status == TermPaymentStatus.OVERDUE)
          .fold<double>(0, (s, t) => s + t.balanceAmount);

      // 1) write payment doc
      final now = DateTime.now();
      final payment = TermFeePayment(
        id: paymentRef.id,
        schoolId: req.schoolId,
        studentId: ledger.studentId,
        studentName: ledger.studentName,
        className: ledger.className,
        section: ledger.section,
        ledgerId: ledger.id,
        feeStructureId: ledger.feeStructureId,
        termId: term.termId,
        termName: term.termName,
        academicYear: ledger.academicYear,
        amount: req.amount,
        lateFeeAmount: 0,
        paymentMode: req.paymentMode,
        transactionRef: req.transactionRef,
        receiptNumber: receiptNumber,
        billId: billId,
        components: req.components,
        collectedBy: req.collectedBy,
        collectedByName: req.collectedByName,
        paidAt: req.paidAt,
        notes: req.notes,
        createdAt: now,
        updatedAt: now,
      );
      txn.set(paymentRef, payment.toFirestore());

      // 2) update ledger
      txn.update(ledgerRef, {
        'termStatus': entries.map((e) => e.toMap()).toList(),
        'totalPaid': newPaid,
        'totalPending': newPending,
        'totalOverdue': overdueSum,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 3) bump receipt counter
      txn.set(
        receiptCounterRef,
        {
          'value': next,
          'prefix': prefix,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      return payment;
    });

    return result;
  }

  /// Soft-delete a payment and reverse its impact on the ledger.
  Future<void> deletePayment({
    required String schoolId,
    required String paymentId,
    required String reason,
  }) async {
    final paymentRef = _paymentsCol(schoolId).doc(paymentId);

    await _firestore.runTransaction((txn) async {
      final paySnap = await txn.get(paymentRef);
      if (!paySnap.exists) throw Exception('Payment not found');
      final payment = TermFeePayment.fromFirestore(paySnap);
      if (payment.isDeleted) return;

      final ledgerRef = _ledgersCol(schoolId).doc(payment.ledgerId);
      final ledgerSnap = await txn.get(ledgerRef);
      if (!ledgerSnap.exists) throw Exception('Ledger missing for payment');
      final ledger = StudentFeeLedger.fromFirestore(ledgerSnap);

      final entries = [...ledger.termStatus];
      final idx = entries.indexWhere((t) => t.termId == payment.termId);
      if (idx >= 0) {
        final t = entries[idx];
        final newPaid = (t.paidAmount - payment.amount).clamp(0, double.infinity).toDouble();
        entries[idx] = t.copyWith(
          paidAmount: newPaid,
          paymentIds: t.paymentIds.where((id) => id != payment.id).toList(),
          status: _resolveStatus(t.amount, newPaid, t.lateFeeApplied, t.dueDate),
        );
      }

      final newPaidTotal =
          (ledger.totalPaid - payment.amount).clamp(0, double.infinity).toDouble();
      final newPending =
          (ledger.totalAssigned + ledger.totalLateFee - newPaidTotal)
              .clamp(0, double.infinity)
              .toDouble();
      final overdueSum = entries
          .where((t) => t.status == TermPaymentStatus.OVERDUE)
          .fold<double>(0, (s, t) => s + t.balanceAmount);

      txn.update(paymentRef, {
        'isDeleted': true,
        'deletionReason': reason,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      txn.update(ledgerRef, {
        'termStatus': entries.map((e) => e.toMap()).toList(),
        'totalPaid': newPaidTotal,
        'totalPending': newPending,
        'totalOverdue': overdueSum,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  static TermPaymentStatus _resolveStatus(
      double amount, double paid, double lateFee, DateTime dueDate) {
    final total = amount + lateFee;
    if (paid >= total - 0.001) return TermPaymentStatus.PAID;
    if (paid > 0) {
      // partial — still mark overdue if past due
      if (DateTime.now().isAfter(dueDate)) return TermPaymentStatus.OVERDUE;
      return TermPaymentStatus.PARTIAL;
    }
    if (DateTime.now().isAfter(dueDate)) return TermPaymentStatus.OVERDUE;
    return TermPaymentStatus.UNPAID;
  }
}
