import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/student_fee_ledger.dart';
import '../../domain/entities/term_fee_payment.dart';

final termFeePaymentRepositoryProvider =
    Provider<TermFeePaymentRepository>((ref) {
  return TermFeePaymentRepository();
});

final termPaymentsByLedgerProvider = FutureProvider.family<List<TermFeePayment>,
    ({String schoolId, String ledgerId})>((ref, p) {
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

class TermAllocation {
  final String termId;
  final String termName;
  final double amount;

  const TermAllocation({
    required this.termId,
    required this.termName,
    required this.amount,
  });

  Map<String, dynamic> toMap() {
    return {
      'termId': termId,
      'termName': termName,
      'amount': amount,
    };
  }
}

class AdHocAllocation {
  final String feeItemId;
  final String itemName;
  final String categoryCode;
  final double amount;

  const AdHocAllocation({
    required this.feeItemId,
    required this.itemName,
    required this.categoryCode,
    required this.amount,
  });

  Map<String, dynamic> toMap() {
    return {
      'feeItemId': feeItemId,
      'itemName': itemName,
      'categoryCode': categoryCode,
      'amount': amount,
    };
  }
}

class RecordMultiTermPaymentRequest {
  final String schoolId;
  final String ledgerId;
  final List<TermAllocation> termAllocations;
  final List<AdHocAllocation> adHocAllocations;
  final TermPaymentMode paymentMode;
  final String? transactionRef;
  final DateTime paidAt;
  final String? notes;
  final String? collectedBy;
  final String? collectedByName;

  const RecordMultiTermPaymentRequest({
    required this.schoolId,
    required this.ledgerId,
    this.termAllocations = const [],
    this.adHocAllocations = const [],
    this.paymentMode = TermPaymentMode.CASH,
    this.transactionRef,
    required this.paidAt,
    this.notes,
    this.collectedBy,
    this.collectedByName,
  });

  double get totalAmount =>
      termAllocations.fold(0.0, (sum, a) => sum + a.amount) +
      adHocAllocations.fold(0.0, (sum, a) => sum + a.amount);
}

class TermFeePaymentRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _paymentsCol(String schoolId) =>
      _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('termFeePayments');

  CollectionReference<Map<String, dynamic>> _ledgersCol(String schoolId) =>
      _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('studentFeeLedgers');

  CollectionReference<Map<String, dynamic>> _settingsCol(String schoolId) =>
      _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('financeSettings');

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

      // Fetch school document to get school name for code generation
      final schoolRef = _firestore.collection('schools').doc(req.schoolId);
      final schoolSnap = await txn.get(schoolRef);
      final schoolName = (schoolSnap.data()?['schoolName'] as String?) ?? '';
      // Use first 4 characters of school name (uppercase), fallback to schoolCode field, then schoolId
      final schoolCode = schoolName.length >= 4
          ? schoolName.substring(0, 4).toUpperCase()
          : ((schoolSnap.data()?['schoolCode'] as String?) ??
              req.schoolId.substring(0, 4).toUpperCase());

      // Format receipt number as [SCHOOLCODE]-RCPT-[ACYEAR]-[RUNNING NUMBER]
      final acYear = ledger.academicYear.replaceAll('-', '');
      final receiptNumber =
          '${schoolCode}-RCPT-${acYear}-${next.toString().padLeft(6, '0')}';

      // Keep prefix for receipt counter (legacy compatibility)
      final prefix = '${schoolCode}-RCPT-${acYear}-';

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

  /// Atomically record a multi-term payment with a single bill ID.
  /// Returns the saved [TermFeePayment] with all term allocations.
  Future<TermFeePayment> recordMultiTermPayment(
      RecordMultiTermPaymentRequest req) async {
    if (req.termAllocations.isEmpty && req.adHocAllocations.isEmpty) {
      throw Exception('At least one allocation is required');
    }
    if (req.totalAmount <= 0) {
      throw Exception('Total amount must be greater than zero');
    }

    final ledgerRef = _ledgersCol(req.schoolId).doc(req.ledgerId);
    final paymentRef = _paymentsCol(req.schoolId).doc();
    final receiptCounterRef = _settingsCol(req.schoolId).doc('receiptCounter');

    final result = await _firestore.runTransaction<TermFeePayment>((txn) async {
      // === PHASE 1: ALL READS ===
      final ledgerSnap = await txn.get(ledgerRef);
      if (!ledgerSnap.exists) {
        throw Exception('Student ledger not found');
      }
      final ledger = StudentFeeLedger.fromFirestore(ledgerSnap);

      print(
          '[Payment Repo] Ledger loaded. termStatus count: ${ledger.termStatus.length}');
      for (final term in ledger.termStatus) {
        print(
            '[Payment Repo] Ledger term: ${term.termId}, isArrear: ${term.isArrear}');
      }

      // Receipt counter (per-school).
      final counterSnap = await txn.get(receiptCounterRef);
      final next = ((counterSnap.data()?['value'] as num?)?.toInt() ?? 0) + 1;

      // Fetch school document to get school name for code generation
      final schoolRef = _firestore.collection('schools').doc(req.schoolId);
      final schoolSnap = await txn.get(schoolRef);
      final schoolName = (schoolSnap.data()?['schoolName'] as String?) ?? '';
      // Use first 4 characters of school name (uppercase), fallback to schoolCode field, then schoolId
      final schoolCode = schoolName.length >= 4
          ? schoolName.substring(0, 4).toUpperCase()
          : ((schoolSnap.data()?['schoolCode'] as String?) ??
              req.schoolId.substring(0, 4).toUpperCase());

      // Read all fee items for ad-hoc allocations
      final feeItemRefs = <DocumentReference>[];
      final feeItemSnaps = <DocumentSnapshot>[];
      for (final alloc in req.adHocAllocations) {
        final feeItemRef = _firestore
            .collection('schools')
            .doc(req.schoolId)
            .collection('studentFeeItems')
            .doc(alloc.feeItemId);
        feeItemRefs.add(feeItemRef);
        final feeItemSnap = await txn.get(feeItemRef);
        feeItemSnaps.add(feeItemSnap);
      }

      // Read arrears documents for any arrears term allocations
      // We need to identify which AYs have arrears and fetch those documents
      final arrearsDocRefs = <DocumentReference>[];
      final arrearsDocSnaps = <DocumentSnapshot>[];
      final arrearsAyMap = <String, String>{}; // termId -> academicYear

      // First, collect all unique AYs from both ledger termStatus and termAllocations
      final uniqueAySet = <String>{};

      // Check ledger termStatus for arrears
      for (final term in ledger.termStatus) {
        if (term.isArrear && term.balanceAmount > 0.001) {
          arrearsAyMap[term.termId] = term.sourceAcademicYear;
          uniqueAySet.add(term.sourceAcademicYear);
        }
      }

      // Also check termAllocations for standalone arrears (not in ledger)
      for (final alloc in req.termAllocations) {
        if (alloc.termId.startsWith('ARREARS_')) {
          final parts = alloc.termId.split('_');
          if (parts.length >= 3) {
            final ay = parts.sublist(2).join('_');
            uniqueAySet.add(ay);
          }
        }
      }

      print('[Payment Repo] Unique AYs with arrears: ${uniqueAySet.toList()}');

      // Since arrears are now stored in the current year's student_fee_details record,
      // we only need to fetch the current year record
      final currentAy = ledger.academicYear;
      final currentYearQuery = _firestore
          .collection('schools')
          .doc(req.schoolId)
          .collection('student_fee_details')
          .where('stuId', isEqualTo: int.tryParse(ledger.studentId) ?? 0)
          .where('academicYear', isEqualTo: currentAy)
          .limit(1);
      final currentYearSnap = await currentYearQuery.get();
      if (currentYearSnap.docs.isNotEmpty) {
        arrearsDocRefs.add(currentYearSnap.docs.first.reference);
        arrearsDocSnaps.add(currentYearSnap.docs.first);
        print(
            '[Payment Repo] Loaded current year student_fee_details for AY: $currentAy');
      } else {
        print(
            '[Payment Repo] No student_fee_details found for current AY: $currentAy');
      }

      // === PHASE 2: PROCESS DATA ===
      // Local map to store fee item updates
      final feeItemUpdates = <String, Map<String, dynamic>>{};
      // Format receipt number as [SCHOOLCODE]-RCPT-[ACYEAR]-[RUNNING NUMBER]
      final acYear = ledger.academicYear.replaceAll('-', '');
      final receiptNumber =
          '${schoolCode}-RCPT-${acYear}-${next.toString().padLeft(6, '0')}';

      // Keep prefix for receipt counter (legacy compatibility)
      final prefix = '${schoolCode}-RCPT-${acYear}-';

      // Bill ID (sequential int) — kept for legacy receipt parity.
      final billId = next;

      // Update all affected terms in the ledger
      double totalPaidIncrease = 0;
      final termAllocationMaps = <Map<String, dynamic>>[];
      final adHocAllocationMaps = <Map<String, dynamic>>[];

      // Track arrears updates for student_fee_details collection
      final arrearsUpdates = <String, Map<String, dynamic>>{};

      for (final alloc in req.termAllocations) {
        final idx =
            ledger.termStatus.indexWhere((t) => t.termId == alloc.termId);
        if (idx >= 0) {
          final term = ledger.termStatus[idx];
          print(
              '[Payment Repo] Processing term: ${term.termId}, isArrear: ${term.isArrear}, amount: ${alloc.amount}');
          final updatedTerm = term.copyWith(
            paidAmount: term.paidAmount + alloc.amount,
            paymentIds: [...term.paymentIds, paymentRef.id],
            paidAt: req.paidAt,
            status: _resolveStatus(term.amount, term.paidAmount + alloc.amount,
                term.lateFeeApplied, term.dueDate),
          );
          ledger.termStatus[idx] = updatedTerm;
          totalPaidIncrease += alloc.amount;

          termAllocationMaps.add(alloc.toMap());

          // If this is an arrears entry, add metadata to the allocation map for bill generation
          if (term.isArrear) {
            termAllocationMaps.last['isArrear'] = true;
            termAllocationMaps.last['sourceAcademicYear'] =
                term.sourceAcademicYear;
            termAllocationMaps.last['arrearsCategory'] = term.category;
          }

          // If this is an arrears entry, track the update for student_fee_details
          if (term.isArrear) {
            print(
                '[Payment Repo] Detected arrears payment for term: ${term.termId}, AY: ${term.sourceAcademicYear}, category: ${term.category}');
            final arrearsAy = term.sourceAcademicYear;
            final category = term.category.toUpperCase();

            // Map category to the appropriate balance field
            String balanceField;
            String paidField;
            switch (category) {
              case 'TUITION':
                balanceField = 'balanceArrearTuitionFees';
                paidField = 'stuPaidArrearTutionFees';
                break;
              case 'EXAM':
                balanceField = 'balanceArrearExamFees';
                paidField = 'stuPaidArrearExamFees';
                break;
              case 'VAN':
                balanceField = 'balanceArrearVanFees';
                paidField = 'stuPaidArrearVanFees';
                break;
              default:
                // Skip unknown categories
                print('[Payment Repo] Unknown category: $category, skipping');
                continue;
            }

            // Use the source academic year as the key for grouping updates
            final key = '${ledger.studentId}_$arrearsAy';
            if (!arrearsUpdates.containsKey(key)) {
              arrearsUpdates[key] = {
                'schoolId': req.schoolId,
                'studentId': ledger.studentId,
                'academicYear': arrearsAy,
                balanceField: 0.0,
                paidField: 0.0,
              };
              print(
                  '[Payment Repo] Created new arrears update entry for key: $key');
            }

            // Subtract payment from balance, add to paid
            arrearsUpdates[key]![balanceField] =
                (arrearsUpdates[key]![balanceField] as num? ?? 0.0) -
                    alloc.amount;
            arrearsUpdates[key]![paidField] =
                (arrearsUpdates[key]![paidField] as num? ?? 0.0) + alloc.amount;
            print(
                '[Payment Repo] Updated arrears for key $key: $balanceField -= ${alloc.amount}, $paidField += ${alloc.amount}');
          }
        } else {
          print('[Payment Repo] Term not found in ledger: ${alloc.termId}');
          // If termId starts with ARREARS_, it's an arrears entry that's not in the ledger
          // We need to handle it differently
          if (alloc.termId.startsWith('ARREARS_')) {
            print(
                '[Payment Repo] Arrears term not in ledger, will handle separately');
            // Extract AY and category from termId
            // Format: ARREARS_CATEGORY_AY
            final parts = alloc.termId.split('_');
            if (parts.length >= 3) {
              final category = parts[1];
              final ay = parts
                  .sublist(2)
                  .join('_'); // Rejoin in case AY has underscores
              print(
                  '[Payment Repo] Extracted arrears info - Category: $category, AY: $ay');

              String balanceField;
              String paidField;
              switch (category.toUpperCase()) {
                case 'TUITION':
                  balanceField = 'balanceArrearTuitionFees';
                  paidField = 'stuPaidArrearTutionFees';
                  break;
                case 'EXAM':
                  balanceField = 'balanceArrearExamFees';
                  paidField = 'stuPaidArrearExamFees';
                  break;
                case 'VAN':
                  balanceField = 'balanceArrearVanFees';
                  paidField = 'stuPaidArrearVanFees';
                  break;
                default:
                  print('[Payment Repo] Unknown arrears category: $category');
                  continue;
              }

              final key = '${ledger.studentId}_$ay';
              if (!arrearsUpdates.containsKey(key)) {
                arrearsUpdates[key] = {
                  'schoolId': req.schoolId,
                  'studentId': ledger.studentId,
                  'academicYear': ay,
                  balanceField: 0.0,
                  paidField: 0.0,
                };
              }

              arrearsUpdates[key]![balanceField] =
                  (arrearsUpdates[key]![balanceField] as num? ?? 0.0) -
                      alloc.amount;
              arrearsUpdates[key]![paidField] =
                  (arrearsUpdates[key]![paidField] as num? ?? 0.0) +
                      alloc.amount;
              print(
                  '[Payment Repo] Tracked arrears update for standalone term: $key');

              // Add this allocation to termAllocationMaps with metadata for bill
              final allocationMap = alloc.toMap();
              allocationMap['isArrear'] = true;
              allocationMap['sourceAcademicYear'] = ay;
              allocationMap['arrearsCategory'] = category;
              termAllocationMaps.add(allocationMap);
              print(
                  '[Payment Repo] Added standalone arrears allocation to termAllocationMaps');
            }
          }
        }
      }

      print(
          '[Payment Repo] Total arrears updates tracked: ${arrearsUpdates.length}');

      // Process ad-hoc allocations with their snapshots
      for (int i = 0; i < req.adHocAllocations.length; i++) {
        final alloc = req.adHocAllocations[i];
        final feeItemSnap = feeItemSnaps[i];
        print(
            '[Payment Repo] Processing ad-hoc allocation: ${alloc.itemName}, feeItemId: ${alloc.feeItemId}');
        adHocAllocationMaps.add(alloc.toMap());

        if (feeItemSnap.exists) {
          final feeItemData = feeItemSnap.data() as Map<String, dynamic>?;
          print(
              '[Payment Repo] Fee item data keys: ${feeItemData?.keys.toList()}');
          final currentPaid =
              (feeItemData?['paidAmount'] as num?)?.toDouble() ?? 0.0;
          final currentAmount =
              (feeItemData?['amount'] as num?)?.toDouble() ?? 0.0;
          print(
              '[Payment Repo] Current paid: $currentPaid, amount: $currentAmount');
          final newPaid = currentPaid + alloc.amount;
          final newBalance =
              (currentAmount - newPaid).clamp(0, double.infinity).toDouble();
          print('[Payment Repo] New paid: $newPaid, new balance: $newBalance');

          // Store the update data to apply in write phase
          final feeItemUpdateData = {
            'paidAmount': newPaid,
            'balanceAmount': newBalance,
            'updatedAt': FieldValue.serverTimestamp(),
          };
          feeItemUpdates[feeItemRefs[i].id] = feeItemUpdateData;
          print('[Payment Repo] Fee item update prepared');
        }
      }

      final newPaid = ledger.totalPaid + totalPaidIncrease;
      final newPending = (ledger.totalAssigned + ledger.totalLateFee - newPaid)
          .clamp(0, double.infinity)
          .toDouble();
      final overdueSum = ledger.termStatus
          .where((t) => t.status == TermPaymentStatus.OVERDUE)
          .fold<double>(0, (s, t) => s + t.balanceAmount);

      // === PHASE 3: ALL WRITES ===
      // 1) write single payment doc with all allocations
      final now = DateTime.now();
      final allComponents = [...termAllocationMaps, ...adHocAllocationMaps];
      final payment = TermFeePayment(
        id: paymentRef.id,
        schoolId: req.schoolId,
        studentId: ledger.studentId,
        studentName: ledger.studentName,
        className: ledger.className,
        section: ledger.section,
        ledgerId: ledger.id,
        feeStructureId: ledger.feeStructureId,
        termId: 'MULTI', // Special marker for multi-term payments
        termName: 'Multi-Term Payment',
        academicYear: ledger.academicYear,
        amount: req.totalAmount,
        lateFeeAmount: 0,
        paymentMode: req.paymentMode,
        transactionRef: req.transactionRef,
        receiptNumber: receiptNumber,
        billId: billId,
        components: allComponents, // Store all term and adhoc allocations here
        collectedBy: req.collectedBy,
        collectedByName: req.collectedByName,
        paidAt: req.paidAt,
        notes: req.notes,
        createdAt: now,
        updatedAt: now,
      );
      txn.set(paymentRef, payment.toFirestore());

      // 2) update ledger with all term updates
      txn.update(ledgerRef, {
        'termStatus': ledger.termStatus.map((e) => e.toMap()).toList(),
        'totalPaid': newPaid,
        'totalPending': newPending,
        'totalOverdue': overdueSum,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 3) update all fee items
      for (int i = 0; i < feeItemRefs.length; i++) {
        final updateData = feeItemUpdates[feeItemRefs[i].id];
        if (updateData != null) {
          txn.update(feeItemRefs[i], updateData);
          print('[Payment Repo] Fee item ${feeItemRefs[i].id} updated');
        }
      }

      // 4) update student_fee_details for arrears payments
      print(
          '[Payment Repo] Starting arrears updates. Docs to update: ${arrearsDocRefs.length}');
      if (arrearsDocRefs.isNotEmpty) {
        final docRef = arrearsDocRefs[0];
        final currentData = arrearsDocSnaps[0].data() as Map<String, dynamic>;

        print('[Payment Repo] Processing current year student_fee_details');

        // Build the update map from tracked arrears updates
        final updateMap = <String, dynamic>{};

        // Apply all tracked arrears updates (they all go to the current year record)
        for (final update in arrearsUpdates.values) {
          for (final key in update.keys) {
            if (key == 'schoolId' ||
                key == 'studentId' ||
                key == 'academicYear') {
              continue; // Skip metadata fields
            }
            final currentVal = currentData[key] as num? ?? 0.0;
            final newVal = update[key] as num? ?? 0.0;
            if (newVal != 0) {
              updateMap[key] = currentVal + newVal;
              print(
                  '[Payment Repo] Field update: $key, current: $currentVal, delta: $newVal, new: ${currentVal + newVal}');
            }
          }
        }

        if (updateMap.isNotEmpty) {
          // Recalculate total arrears
          final tuitionBalance =
              (currentData['balanceArrearTuitionFees'] as num? ?? 0.0) +
                  (updateMap['balanceArrearTuitionFees'] as num? ?? 0.0);
          final examBalance =
              (currentData['balanceArrearExamFees'] as num? ?? 0.0) +
                  (updateMap['balanceArrearExamFees'] as num? ?? 0.0);
          final vanBalance =
              (currentData['balanceArrearVanFees'] as num? ?? 0.0) +
                  (updateMap['balanceArrearVanFees'] as num? ?? 0.0);

          updateMap['totalArrears'] =
              (tuitionBalance + examBalance + vanBalance)
                  .clamp(0, double.infinity);
          updateMap['updatedAt'] = FieldValue.serverTimestamp();

          print(
              '[Payment Repo] Applying update to student_fee_details: $updateMap');
          txn.update(docRef, updateMap);
          print('[Payment Repo] student_fee_details updated');
        } else {
          print('[Payment Repo] No arrears updates to apply');
        }
      } else {
        if (arrearsUpdates.isNotEmpty) {
          print(
              '[Payment Repo] WARNING: Arrears updates tracked but no student_fee_details document found');
          print(
              '[Payment Repo] Tracked updates: ${arrearsUpdates.keys.toList()}');
        }
      }

      // 5) bump receipt counter
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
        final newPaid = (t.paidAmount - payment.amount)
            .clamp(0, double.infinity)
            .toDouble();
        entries[idx] = t.copyWith(
          paidAmount: newPaid,
          paymentIds: t.paymentIds.where((id) => id != payment.id).toList(),
          status:
              _resolveStatus(t.amount, newPaid, t.lateFeeApplied, t.dueDate),
        );
      }

      final newPaidTotal = (ledger.totalPaid - payment.amount)
          .clamp(0, double.infinity)
          .toDouble();
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
