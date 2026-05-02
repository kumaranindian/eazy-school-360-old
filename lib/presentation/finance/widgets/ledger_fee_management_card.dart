import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../data/repositories/fee_structure_v2_repository.dart';
import '../../../data/repositories/student_fee_item_repository.dart';
import '../../../data/repositories/student_fee_ledger_repository.dart';
import '../../../domain/entities/fee_category.dart';
import '../../../domain/entities/fee_structure_v2.dart';
import '../../../domain/entities/student_fee_item.dart';
import '../../../domain/entities/student_fee_ledger.dart';
import 'multi_allocation_payment_dialog.dart';

const Color _bgDark = Color(0xFF0D1117);
const Color _cardDark = Color(0xFF161B22);
const Color _accentGreen = Color(0xFF10B981);
const Color _accentBlue = Color(0xFF3B82F6);
const Color _accentAmber = Color(0xFFF59E0B);
const Color _accentRed = Color(0xFFEF4444);
const Color _textPrimary = Color(0xFFE6EDF3);
const Color _textSecondary = Color(0xFF8B949E);
const Color _borderColor = Color(0xFF30363D);

/// Production-ready Fee Management card driven entirely by the
/// [StudentFeeLedger]. Renders the same TOTAL / PAID / BALANCE layout
/// as the legacy screen but with **dynamic per-category rows** plus a
/// **separate per-prior-academic-year arrears section** for any
/// carried-forward balances.
///
/// Layout (top-to-bottom):
///   1. Current-AY group: 3 cards (Total / Paid / Balance), each with
///      one row per FeeCategory found in `ledger.termStatus` where
///      `isArrear == false`.
///   2. For each unique `sourceAcademicYear` found in arrears entries,
///      an "Arrears <AY>" group with the same 3-card layout.
///   3. Action row: Make Payment, Bill History, Refresh.
///
/// All numbers are computed from the ledger — there is no parallel
/// denormalised store. The "Make Payment" dialog allocates across rows
/// transactionally via [TermFeePaymentRepository.recordPayment].
class LedgerFeeManagementCard extends ConsumerStatefulWidget {
  const LedgerFeeManagementCard({
    super.key,
    required this.schoolId,
    required this.studentId,
    required this.academicYear,
    required this.studentName,
    required this.className,
    required this.section,
    this.parentName,
    this.parentPhone,
    this.onBillHistory,
  });

  final String schoolId;
  final String studentId;
  final String academicYear;
  final String studentName;
  final String className;
  final String section;
  final String? parentName;
  final String? parentPhone;
  final VoidCallback? onBillHistory;

  @override
  ConsumerState<LedgerFeeManagementCard> createState() =>
      _LedgerFeeManagementCardState();
}

class _LedgerFeeManagementCardState
    extends ConsumerState<LedgerFeeManagementCard> {
  StudentFeeLedger? _ledger;
  Map<String, FeeCategory> _categoriesByCode = const {};
  bool _loading = true;
  String? _error;

  // Empty-state diagnostics: structures the admin could assign to this
  // student so they don't have to navigate away to fix the data.
  List<FeeStructureV2> _matchingStructures = const [];
  List<FeeStructureV2> _allStructuresForAy = const [];
  bool _assignBusy = false;
  String? _assignError;

  // Ad-hoc fee items (event-based fees not in the ledger)
  List<StudentFeeItem> _adhocFeeItems = const [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void didUpdateWidget(covariant LedgerFeeManagementCard old) {
    super.didUpdateWidget(old);
    if (old.studentId != widget.studentId ||
        old.academicYear != widget.academicYear ||
        old.schoolId != widget.schoolId) {
      _refresh();
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(studentFeeLedgerRepositoryProvider);
      final ledger = await repo.getByStudent(
          widget.schoolId, widget.studentId, widget.academicYear);

      // Load arrears from student_fee_details collection
      List<TermLedgerEntry> arrearsEntries = [];
      try {
        final arrearsSnap = await FirebaseFirestore.instance
            .collection('schools')
            .doc(widget.schoolId)
            .collection('student_fee_details')
            .where('stuId', isEqualTo: int.tryParse(widget.studentId) ?? 0)
            .where('isArrearsRecord', isEqualTo: true)
            .get();

        for (final doc in arrearsSnap.docs) {
          final data = doc.data();
          final arrearsAy = (data['academicYear'] ?? '').toString();
          final balanceArrearTuition =
              (data['balanceArrearTuitionFees'] as num?)?.toDouble() ?? 0;
          final balanceArrearExam =
              (data['balanceArrearExamFees'] as num?)?.toDouble() ?? 0;
          final balanceArrearVan =
              (data['balanceArrearVanFees'] as num?)?.toDouble() ?? 0;

          if (balanceArrearTuition > 0) {
            arrearsEntries.add(TermLedgerEntry(
              termId: 'ARREARS_TUITION_$arrearsAy',
              termName: 'Tuition Arrears',
              sequence: 999,
              amount: balanceArrearTuition,
              dueDate: DateTime.now(),
              paidAmount: 0,
              category: 'TUITION',
              isArrear: true,
              sourceAcademicYear: arrearsAy,
            ));
          }
          if (balanceArrearExam > 0) {
            arrearsEntries.add(TermLedgerEntry(
              termId: 'ARREARS_EXAM_$arrearsAy',
              termName: 'Exam Arrears',
              sequence: 999,
              amount: balanceArrearExam,
              dueDate: DateTime.now(),
              paidAmount: 0,
              category: 'EXAM',
              isArrear: true,
              sourceAcademicYear: arrearsAy,
            ));
          }
          if (balanceArrearVan > 0) {
            arrearsEntries.add(TermLedgerEntry(
              termId: 'ARREARS_VAN_$arrearsAy',
              termName: 'Van Arrears',
              sequence: 999,
              amount: balanceArrearVan,
              dueDate: DateTime.now(),
              paidAmount: 0,
              category: 'VAN',
              isArrear: true,
              sourceAcademicYear: arrearsAy,
            ));
          }
        }
        print(
            '[LedgerFeeManagementCard] Loaded ${arrearsEntries.length} arrears entries for student ${widget.studentId}');
      } catch (e) {
        print('[LedgerFeeManagementCard] Failed to load arrears: $e');
      }

      // Best-effort load of category catalog so we can render friendly
      // names rather than UPPER_SNAKE codes. Failure is non-fatal — we
      // fall back to the code itself.
      Map<String, FeeCategory> cats = {};
      try {
        final snap = await FirebaseFirestore.instance
            .collection('schools')
            .doc(widget.schoolId)
            .collection('feeCategories')
            .get();
        cats = {
          for (final d in snap.docs)
            (d.data()['code']?.toString().toUpperCase() ?? d.id):
                FeeCategory.fromFirestore(d),
        };
      } catch (_) {}

      // Load ad-hoc fee items for the student
      List<StudentFeeItem> adhocItems = const [];
      try {
        final feeItemRepo = ref.read(studentFeeItemRepositoryProvider);
        adhocItems = await feeItemRepo.getByStudent(
          widget.schoolId,
          widget.studentId,
          widget.academicYear,
        );
        print(
            '[LedgerFeeManagementCard] Loaded ${adhocItems.length} ad-hoc fee items for student ${widget.studentId}');
        for (final item in adhocItems) {
          print(
              '  - ${item.itemName}: amount=${item.amount}, paid=${item.paidAmount}, balance=${item.balanceAmount}');
        }
      } catch (e) {
        print('[LedgerFeeManagementCard] Failed to load ad-hoc fee items: $e');
      }

      // When the ledger is absent, eagerly look up active FeeStructureV2s
      // so the empty state can offer one-click assign instead of bouncing
      // the admin to another screen.
      List<FeeStructureV2> matching = const [];
      List<FeeStructureV2> allInAy = const [];
      if (ledger == null) {
        try {
          final structRepo = ref.read(feeStructureV2RepositoryProvider);
          final all = await structRepo.listAll(widget.schoolId);
          allInAy = all
              .where((s) => s.isActive && s.academicYear == widget.academicYear)
              .toList();
          final classKey = widget.className.trim();
          matching = allInAy.where((s) {
            if (s.applicableToClassIds.isEmpty) return s.isDefault;
            return s.applicableToClassIds
                .any((c) => c.trim().toLowerCase() == classKey.toLowerCase());
          }).toList();
          // Default structures are valid fallbacks if no class-specific
          // match exists.
          if (matching.isEmpty) {
            matching = allInAy.where((s) => s.isDefault).toList();
          }
        } catch (_) {
          // Diagnostics-only; non-fatal.
        }
      }

      if (!mounted) return;
      setState(() {
        // Merge arrears entries with ledger termStatus
        if (ledger != null && arrearsEntries.isNotEmpty) {
          final mergedTermStatus = [...ledger.termStatus, ...arrearsEntries];
          _ledger = ledger.copyWith(termStatus: mergedTermStatus);
        } else {
          _ledger = ledger;
        }
        _categoriesByCode = cats;
        _matchingStructures = matching;
        _allStructuresForAy = allInAy;
        _adhocFeeItems = adhocItems;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return _shell(
          child: const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator(color: _accentGreen)),
      ));
    }
    if (_error != null) {
      return _shell(
          child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text('Failed to load fees: $_error',
              style: const TextStyle(color: _accentRed)),
        ),
      ));
    }
    if (_ledger == null) {
      return _shell(child: _emptyState());
    }

    final width = MediaQuery.of(context).size.width;
    final isDesktop = width > 1024;
    final isMobile = width <= 600;

    final ledger = _ledger!;
    final regular = ledger.termStatus.where((e) => !e.isArrear).toList();
    final arrears = ledger.termStatus.where((e) => e.isArrear).toList();

    // Group arrears by source AY so we can render one card-group per AY.
    final arrearsByAy = <String, List<TermLedgerEntry>>{};
    for (final e in arrears) {
      final k = e.sourceAcademicYear.isEmpty ? '—' : e.sourceAcademicYear;
      arrearsByAy.putIfAbsent(k, () => []).add(e);
    }
    final arrearsAys = arrearsByAy.keys.toList()..sort();

    return _shell(
        child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Icon(Icons.account_balance_wallet_rounded, color: _accentGreen),
          const SizedBox(width: 8),
          Text('Fee Management • AY ${ledger.academicYear}',
              style: TextStyle(
                  color: _textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: isMobile ? 14 : 16)),
          const Spacer(),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded,
                color: _textSecondary, size: 18),
            onPressed: _refresh,
          ),
        ]),
        const SizedBox(height: 12),
        _yearGroup('Current Year', regular, isDesktop, isMobile,
            highlight: false, padWithCatalog: true, adHocItems: _adhocFeeItems),
        for (final ay in arrearsAys) ...[
          const SizedBox(height: 16),
          _yearGroup('Arrears • $ay', arrearsByAy[ay]!, isDesktop, isMobile,
              highlight: true, padWithCatalog: false),
        ],
        const SizedBox(height: 16),
        _actionRow(ledger),
      ],
    ));
  }

  Widget _emptyState() {
    final money =
        NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final hasMatching = _matchingStructures.isNotEmpty;
    final hasAnyForAy = _allStructuresForAy.isNotEmpty;
    final showFallback = !hasMatching && hasAnyForAy;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.info_outline_rounded,
                color: _accentAmber, size: 22),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('No fee ledger for this student yet',
                  style: TextStyle(
                      color: _textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
            ),
          ]),
          const SizedBox(height: 6),
          Text(
              'Lookup: studentId="${widget.studentId}" • class="${widget.className}" • AY="${widget.academicYear}"',
              style: const TextStyle(color: _textSecondary, fontSize: 11)),
          const SizedBox(height: 12),
          if (hasMatching) ...[
            const Text('Matching fee structure(s) for this class:',
                style: TextStyle(color: _textSecondary, fontSize: 12)),
            const SizedBox(height: 8),
            for (final s in _matchingStructures)
              _structureRow(s, money, isFallback: false),
          ] else if (showFallback) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _accentAmber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _accentAmber.withOpacity(0.3)),
              ),
              child: Text(
                  'No structure is tagged for class "${widget.className}" in AY ${widget.academicYear}. Pick one below or fix the structure\'s applicable classes.',
                  style: const TextStyle(color: _accentAmber, fontSize: 12)),
            ),
            const SizedBox(height: 10),
            const Text('Other structures active in this AY (assign manually):',
                style: TextStyle(color: _textSecondary, fontSize: 12)),
            const SizedBox(height: 8),
            for (final s in _allStructuresForAy)
              _structureRow(s, money, isFallback: true),
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: _accentRed.withOpacity(0.08),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _accentRed.withOpacity(0.3)),
              ),
              child: Text(
                  'No active fee structure exists for AY ${widget.academicYear}. Create one via Finance → Fee Structures → New Structure, then return here.',
                  style: const TextStyle(color: _accentRed, fontSize: 12)),
            ),
          ],
          if (_assignError != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _accentRed.withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _accentRed.withOpacity(0.4)),
              ),
              child: Text(_assignError!,
                  style: const TextStyle(color: _accentRed, fontSize: 12)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _structureRow(FeeStructureV2 s, NumberFormat money,
      {required bool isFallback}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _bgDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _borderColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(s.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: _textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13)),
                  ),
                  if (s.isDefault)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: _accentBlue.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: const Text('DEFAULT',
                          style: TextStyle(
                              color: _accentBlue,
                              fontSize: 9,
                              fontWeight: FontWeight.bold)),
                    ),
                ]),
                const SizedBox(height: 2),
                Text(
                    '${s.type.name} • ${s.termCount} term(s) • Total ${money.format(s.totalAmount)} • Classes: ${s.applicableToClassIds.isEmpty ? "—" : s.applicableToClassIds.join(", ")}',
                    style:
                        const TextStyle(color: _textSecondary, fontSize: 10)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton.icon(
            onPressed: _assignBusy ? null : () => _assign(s),
            icon: _assignBusy
                ? const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : Icon(
                    isFallback
                        ? Icons.warning_amber_rounded
                        : Icons.check_circle_outline_rounded,
                    size: 14),
            label: Text(isFallback ? 'Assign anyway' : 'Assign & Load'),
            style: ElevatedButton.styleFrom(
              backgroundColor: isFallback ? _accentAmber : _accentGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              textStyle: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _assign(FeeStructureV2 s) async {
    if (widget.studentId.isEmpty) {
      setState(
          () => _assignError = 'Student id is empty — cannot create a ledger.');
      return;
    }
    setState(() {
      _assignBusy = true;
      _assignError = null;
    });
    try {
      final repo = ref.read(studentFeeLedgerRepositoryProvider);
      await repo.assignToStudent(
        schoolId: widget.schoolId,
        studentId: widget.studentId,
        studentName: widget.studentName,
        className: widget.className,
        section: widget.section,
        structureId: s.id,
        parentName:
            (widget.parentName ?? '').isEmpty ? null : widget.parentName,
        parentPhone:
            (widget.parentPhone ?? '').isEmpty ? null : widget.parentPhone,
        onConflict: ConflictAction.SKIP,
      );
      if (!mounted) return;
      setState(() => _assignBusy = false);
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _assignBusy = false;
        _assignError = 'Assign failed: $e';
      });
    }
  }

  Widget _shell({required Widget child}) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _cardDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _borderColor),
        ),
        child: child,
      );

  Widget _yearGroup(String title, List<TermLedgerEntry> entries, bool isDesktop,
      bool isMobile,
      {required bool highlight,
      required bool padWithCatalog,
      List<StudentFeeItem> adHocItems = const []}) {
    if (entries.isEmpty && !padWithCatalog) return const SizedBox.shrink();

    // Group entries by category and sum totals/paid/balance.
    final byCategory = <String, _CategoryAggregate>{};
    for (final e in entries) {
      final agg = byCategory.putIfAbsent(
          e.category, () => _CategoryAggregate(category: e.category));
      agg.total += e.amount + e.lateFeeApplied;
      agg.paid += e.paidAmount;
      agg.balance += e.balanceAmount;
    }

    // Add ad-hoc fees to the category aggregation
    // Use uppercase category code to match the catalog keys
    for (final item in adHocItems) {
      final categoryKey = item.categoryCode.toUpperCase();
      final agg = byCategory.putIfAbsent(
          categoryKey, () => _CategoryAggregate(category: categoryKey));
      agg.total += item.amount;
      agg.paid += item.paidAmount;
      agg.balance += item.balanceAmount;
      agg.hasAdHoc = true;
      print(
          '[_yearGroup] Added ad-hoc item: ${item.itemName}, category=$categoryKey, amount=${item.amount}');
    }

    // When rendering the current-year group, pad with every category
    // configured in the school's catalog so the admin sees the full fee
    // matrix (e.g. EXAM / VAN / ADMISSION rows showing ₹0 when the
    // assigned structure doesn't yet include terms for them). Arrears
    // groups skip this — they must stay faithful to what was carried.
    if (padWithCatalog) {
      for (final code in _categoriesByCode.keys) {
        byCategory.putIfAbsent(code, () => _CategoryAggregate(category: code));
      }
    }

    final cats = byCategory.values.toList()
      ..sort((a, b) =>
          _categoryRank(a.category).compareTo(_categoryRank(b.category)));

    const totalColor = _accentAmber;
    const paidColor = _accentGreen;
    const balanceColor = _accentRed;

    final cards = [
      _breakdownCard(
          'TOTAL FEES', totalColor, cats, _BreakdownKind.total, isMobile),
      _breakdownCard(
          'PAID FEES', paidColor, cats, _BreakdownKind.paid, isMobile),
      _breakdownCard(
          'BALANCE FEES', balanceColor, cats, _BreakdownKind.balance, isMobile),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: highlight
                  ? _accentRed.withOpacity(0.15)
                  : _accentBlue.withOpacity(0.12),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: highlight
                    ? _accentRed.withOpacity(0.4)
                    : _accentBlue.withOpacity(0.3),
              ),
            ),
            child: Text(title.toUpperCase(),
                style: TextStyle(
                    color: highlight ? _accentRed : _accentBlue,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    letterSpacing: 0.5)),
          ),
        ]),
        const SizedBox(height: 8),
        if (isDesktop)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (int i = 0; i < cards.length; i++) ...[
                  if (i > 0) const SizedBox(width: 12),
                  Expanded(child: cards[i]),
                ],
              ],
            ),
          )
        else
          Column(
            children: [
              for (int i = 0; i < cards.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                cards[i],
              ],
            ],
          ),
      ],
    );
  }

  Widget _breakdownCard(String title, Color accent,
      List<_CategoryAggregate> cats, _BreakdownKind kind, bool isMobile) {
    final money =
        NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    // Calculate total outside of Builder to ensure proper accumulation
    double sum = 0;
    for (final c in cats) {
      final v = switch (kind) {
        _BreakdownKind.total => c.total,
        _BreakdownKind.paid => c.paid,
        _BreakdownKind.balance => c.balance,
      };
      sum += v;
    }

    return Container(
      padding: EdgeInsets.all(isMobile ? 10 : 12),
      decoration: BoxDecoration(
        color: _bgDark,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: isMobile ? 6 : 8),
            decoration: BoxDecoration(
                color: accent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(6)),
            child: Center(
                child: Text(title,
                    style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.bold,
                        fontSize: isMobile ? 12 : 13,
                        letterSpacing: 0.5))),
          ),
          SizedBox(height: isMobile ? 6 : 6),
          if (cats.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Text('No fees',
                  style: TextStyle(color: _textSecondary, fontSize: 12)),
            )
          else
            for (final c in cats)
              Padding(
                padding: EdgeInsets.symmetric(vertical: isMobile ? 2 : 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(_categoryLabel(c.category),
                        style: TextStyle(
                            color: _textPrimary, fontSize: isMobile ? 11 : 12)),
                    if (c.hasAdHoc) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: _accentAmber.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(3),
                          border:
                              Border.all(color: _accentAmber.withOpacity(0.4)),
                        ),
                        child: Text('AD-HOC',
                            style: TextStyle(
                                color: _accentAmber,
                                fontSize: isMobile ? 8 : 9,
                                fontWeight: FontWeight.bold,
                                height: 1)),
                      ),
                    ],
                    const Spacer(),
                    Text(
                        money.format(switch (kind) {
                          _BreakdownKind.total => c.total,
                          _BreakdownKind.paid => c.paid,
                          _BreakdownKind.balance => c.balance,
                        }),
                        style: TextStyle(
                            color: _textPrimary,
                            fontSize: isMobile ? 11 : 12,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
          Divider(color: _borderColor, height: isMobile ? 8 : 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('TOTAL',
                  style: TextStyle(
                      color: _textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: isMobile ? 11 : 12)),
              Text(money.format(sum),
                  style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.bold,
                      fontSize: isMobile ? 13 : 14)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionRow(StudentFeeLedger ledger) {
    // Calculate actual outstanding balance from ledger entries instead of relying on totalPending field
    // which may not be updated correctly
    double actualOutstanding = 0;
    for (final entry in ledger.termStatus) {
      actualOutstanding += entry.balanceAmount;
    }
    // Also include ad-hoc fee items
    for (final item in _adhocFeeItems) {
      actualOutstanding += item.balanceAmount;
    }

    final outstanding =
        actualOutstanding > 0 ? actualOutstanding : ledger.totalPending;
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      children: [
        ElevatedButton.icon(
          onPressed: outstanding > 0 ? () => _openPaymentDialog(ledger) : null,
          icon: const Icon(Icons.payments_rounded, size: 16),
          label: const Text('Make Payment'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _accentGreen,
            foregroundColor: Colors.white,
            disabledBackgroundColor: _borderColor,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        if (widget.onBillHistory != null)
          OutlinedButton.icon(
            onPressed: widget.onBillHistory,
            icon: const Icon(Icons.receipt_long_rounded, size: 16),
            label: const Text('Bill History'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _textPrimary,
              side: const BorderSide(color: _borderColor),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
      ],
    );
  }

  Future<void> _openPaymentDialog(StudentFeeLedger ledger) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => MultiAllocationPaymentDialog(
        schoolId: widget.schoolId,
        ledger: ledger,
        adHocFeeItems: _adhocFeeItems,
      ),
    );
    if (result == true) await _refresh();
  }

  /// Stable rank so the screenshot's order (Tuition, Exam, Van, Admission,
  /// then everything else alphabetically) is preserved when those
  /// categories are present.
  int _categoryRank(String code) {
    switch (code.toUpperCase()) {
      case 'TUITION':
        return 0;
      case 'EXAM':
        return 1;
      case 'VAN':
        return 2;
      case 'ADMISSION':
        return 3;
      default:
        return 100;
    }
  }

  String _categoryLabel(String code) {
    final cat = _categoriesByCode[code.toUpperCase()];
    if (cat != null && cat.name.trim().isNotEmpty) return cat.name;
    // Pretty-print SNAKE_CASE / UPPER codes.
    final pretty = code
        .replaceAll('_', ' ')
        .toLowerCase()
        .split(' ')
        .where((s) => s.isNotEmpty)
        .map((s) => s[0].toUpperCase() + s.substring(1))
        .join(' ');
    if (pretty.isEmpty) return code;
    if (!pretty.toLowerCase().endsWith('fee') &&
        !pretty.toLowerCase().endsWith('fees')) {
      return '$pretty Fees';
    }
    return pretty;
  }
}

class _CategoryAggregate {
  _CategoryAggregate({required this.category});
  final String category;
  double total = 0;
  double paid = 0;
  double balance = 0;
  bool hasAdHoc = false;
}

enum _BreakdownKind { total, paid, balance }
