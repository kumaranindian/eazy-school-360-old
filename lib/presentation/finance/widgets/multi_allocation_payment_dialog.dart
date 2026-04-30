import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../data/repositories/term_fee_payment_repository.dart';
import '../../../domain/entities/student_fee_item.dart';
import '../../../domain/entities/student_fee_ledger.dart';
import '../../../domain/entities/term_fee_payment.dart';

const Color _bgDark = Color(0xFF0D1117);
const Color _cardDark = Color(0xFF161B22);
const Color _accentGreen = Color(0xFF4CAF50);
const Color _accentBlue = Color(0xFF3B82F6);
const Color _accentAmber = Color(0xFFF59E0B);
const Color _accentRed = Color(0xFFEF4444);
const Color _textPrimary = Color(0xFFE6EDF3);
const Color _textSecondary = Color(0xFF8B949E);
const Color _borderColor = Color(0xFF30363D);

/// Multi-row "Make Payment" dialog. Lets the cashier collect a single
/// payment that the system allocates across **multiple open ledger rows**
/// — across categories, terms, and prior-year arrears — atomically.
///
/// Behavior:
///   * Lists every ledger term entry with `balanceAmount > 0`.
///   * Arrears rows (carried from prior years) appear first by default
///     (FIFO), tagged with their source academic year.
///   * Also lists ad-hoc fee items with outstanding balances.
///   * The cashier can enter a total tendered amount and click
///     "Auto-allocate" to fill rows oldest-first; or fill row-by-row
///     manually.
///   * Submit records one [TermFeePayment] per allocated row, each as a
///     separate transaction (preserves the existing single-term contract
///     of [TermFeePaymentRepository.recordPayment] + receipt counter).
///   * For ad-hoc fees, records payments via StudentFeeItemRepository.
///   * On any per-row failure, the dialog reports which rows succeeded
///     and surfaces the failure for the rest, so the cashier can retry.
///
/// Returns `true` if at least one row was paid successfully so the
/// caller can refresh.
class MultiAllocationPaymentDialog extends ConsumerStatefulWidget {
  const MultiAllocationPaymentDialog({
    super.key,
    required this.schoolId,
    required this.ledger,
    this.adHocFeeItems = const [],
  });

  final String schoolId;
  final StudentFeeLedger ledger;
  final List<StudentFeeItem> adHocFeeItems;

  @override
  ConsumerState<MultiAllocationPaymentDialog> createState() =>
      _MultiAllocationPaymentDialogState();
}

class _MultiAllocationPaymentDialogState
    extends ConsumerState<MultiAllocationPaymentDialog> {
  late List<TermLedgerEntry> _openEntries;
  late List<StudentFeeItem> _openAdHocItems;
  late Map<String, TextEditingController> _amountCtrls;
  late Map<String, TextEditingController> _adhocAmountCtrls;
  final TextEditingController _totalTenderedCtrl = TextEditingController();
  final TextEditingController _refCtrl = TextEditingController();
  final TextEditingController _notesCtrl = TextEditingController();
  TermPaymentMode _mode = TermPaymentMode.CASH;
  DateTime _paidAt = DateTime.now();
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Arrears first (FIFO by sourceAcademicYear), then regular by sequence.
    final entries = widget.ledger.termStatus
        .where((e) => e.balanceAmount > 0.001)
        .toList()
      ..sort((a, b) {
        if (a.isArrear != b.isArrear) return a.isArrear ? -1 : 1;
        if (a.isArrear) {
          // Older source AY first.
          final c = a.sourceAcademicYear.compareTo(b.sourceAcademicYear);
          if (c != 0) return c;
        }
        return a.sequence.compareTo(b.sequence);
      });
    _openEntries = entries;
    _amountCtrls = {
      for (final e in entries) e.termId: TextEditingController(text: '0'),
    };
    
    // Ad-hoc fee items with outstanding balance
    final adhocItems = widget.adHocFeeItems
        .where((e) => e.balanceAmount > 0.001)
        .toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    _openAdHocItems = adhocItems;
    _adhocAmountCtrls = {
      for (final e in adhocItems) e.id: TextEditingController(text: '0'),
    };
  }

  @override
  void dispose() {
    for (final c in _amountCtrls.values) {
      c.dispose();
    }
    for (final c in _adhocAmountCtrls.values) {
      c.dispose();
    }
    _totalTenderedCtrl.dispose();
    _refCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  double _allocatedTotal() {
    double t = 0;
    for (final c in _amountCtrls.values) {
      t += double.tryParse(c.text.trim()) ?? 0;
    }
    for (final c in _adhocAmountCtrls.values) {
      t += double.tryParse(c.text.trim()) ?? 0;
    }
    return t;
  }

  void _autoAllocate() {
    final tendered = double.tryParse(_totalTenderedCtrl.text.trim()) ?? 0;
    if (tendered <= 0) {
      setState(() => _error = 'Enter a tendered amount first');
      return;
    }
    double remaining = tendered;
    
    // Allocate to ledger entries first (arrears first, then regular)
    for (final e in _openEntries) {
      if (remaining <= 0) {
        _amountCtrls[e.termId]!.text = '0';
        continue;
      }
      final take = remaining < e.balanceAmount ? remaining : e.balanceAmount;
      _amountCtrls[e.termId]!.text = take.toStringAsFixed(0);
      remaining -= take;
    }
    
    // Then allocate to ad-hoc fee items
    for (final e in _openAdHocItems) {
      if (remaining <= 0) {
        _adhocAmountCtrls[e.id]!.text = '0';
        continue;
      }
      final take = remaining < e.balanceAmount ? remaining : e.balanceAmount;
      _adhocAmountCtrls[e.id]!.text = take.toStringAsFixed(0);
      remaining -= take;
    }
    
    setState(() {
      _error = remaining > 0.01
          ? 'Tendered amount exceeds total outstanding by ₹${remaining.toStringAsFixed(0)}'
          : null;
    });
  }

  Future<void> _submit() async {
    final allocations = <(TermLedgerEntry entry, double amount)>[];
    for (final e in _openEntries) {
      final amt = double.tryParse(_amountCtrls[e.termId]!.text.trim()) ?? 0;
      if (amt <= 0) continue;
      if (amt > e.balanceAmount + 0.01) {
        setState(() =>
            _error = 'Row "${e.termName}": ₹$amt exceeds balance ₹${e.balanceAmount.toStringAsFixed(0)}');
        return;
      }
      allocations.add((e, amt));
    }
    
    final adhocAllocations = <(StudentFeeItem item, double amount)>[];
    for (final e in _openAdHocItems) {
      final amt = double.tryParse(_adhocAmountCtrls[e.id]!.text.trim()) ?? 0;
      if (amt <= 0) continue;
      if (amt > e.balanceAmount + 0.01) {
        setState(() =>
            _error = 'Ad-hoc fee "${e.itemName}": ₹$amt exceeds balance ₹${e.balanceAmount.toStringAsFixed(0)}');
        return;
      }
      adhocAllocations.add((e, amt));
    }
    
    if (allocations.isEmpty && adhocAllocations.isEmpty) {
      setState(() => _error = 'Enter an amount on at least one row');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final repo = ref.read(termFeePaymentRepositoryProvider);
    final session = ref.read(currentSessionProvider);

    try {
      // Prepare term allocations
      final termAllocations = allocations.map((a) => TermAllocation(
        termId: a.$1.termId,
        termName: a.$1.termName,
        amount: a.$2,
      )).toList();

      // Prepare ad-hoc allocations
      final adHocAllocations = adhocAllocations.map((a) => AdHocAllocation(
        feeItemId: a.$1.id,
        itemName: a.$1.itemName,
        categoryCode: a.$1.categoryCode,
        amount: a.$2,
      )).toList();

      // Record single payment with both term and adhoc allocations
      await repo.recordMultiTermPayment(RecordMultiTermPaymentRequest(
        schoolId: widget.schoolId,
        ledgerId: widget.ledger.id,
        termAllocations: termAllocations,
        adHocAllocations: adHocAllocations,
        paymentMode: _mode,
        transactionRef:
            _refCtrl.text.trim().isEmpty ? null : _refCtrl.text.trim(),
        paidAt: _paidAt,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        collectedBy: session?.uid,
        collectedByName: session?.displayName,
      ));

      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: _accentGreen,
        content: Text(
            'Payment saved successfully with single bill ID'),
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final money =
        NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final allocated = _allocatedTotal();
    final outstanding = _openEntries.fold<double>(
        0, (s, e) => s + e.balanceAmount) +
        _openAdHocItems.fold<double>(0, (s, e) => s + e.balanceAmount);

    return Dialog(
      backgroundColor: _cardDark,
      surfaceTintColor: _cardDark,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Theme(
        // Force a dark InputDecoration theme so every TextField /
        // DropdownButtonFormField / InputDecorator below inherits the
        // correct dark surface instead of the app-wide light fill.
        data: Theme.of(context).copyWith(
          canvasColor: _cardDark,
          dialogBackgroundColor: _cardDark,
          textTheme: Theme.of(context).textTheme.apply(
                bodyColor: _textPrimary,
                displayColor: _textPrimary,
              ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: _bgDark,
            isDense: true,
            labelStyle: const TextStyle(color: _textSecondary),
            hintStyle: const TextStyle(color: _textSecondary),
            prefixStyle: const TextStyle(color: _textSecondary),
            suffixStyle: const TextStyle(color: _textSecondary),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _accentGreen),
            ),
          ),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720, maxHeight: 720),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(children: [
                const Icon(Icons.payments_rounded, color: _accentGreen),
                const SizedBox(width: 8),
                const Text('Make Payment',
                    style: TextStyle(
                        color: _textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 18)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: _textSecondary),
                  onPressed: _saving ? null : () => Navigator.pop(context),
                ),
              ]),
              const SizedBox(height: 4),
              Text(
                  '${widget.ledger.studentName} • ${widget.ledger.className} • AY ${widget.ledger.academicYear}',
                  style: const TextStyle(
                      color: _textSecondary, fontSize: 12)),
              const SizedBox(height: 12),

              // Tendered amount + auto-allocate
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _bgDark,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _borderColor),
                ),
                child: Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _totalTenderedCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d+\.?\d{0,2}'))
                      ],
                      style: const TextStyle(
                          color: _textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 16),
                      decoration: const InputDecoration(
                        labelText: 'Total Tendered',
                        labelStyle: TextStyle(color: _textSecondary),
                        prefixText: '₹ ',
                        prefixStyle: TextStyle(color: _textSecondary),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _saving ? null : _autoAllocate,
                    icon: const Icon(Icons.auto_awesome, size: 16),
                    label: const Text('Auto-allocate'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accentBlue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 12),

              // Open ledger rows
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      ..._openEntries
                          .map((e) => _allocationRow(e, money))
                          .toList(),
                      if (_openAdHocItems.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _accentAmber.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.event_note_rounded,
                                  color: _accentAmber, size: 14),
                              const SizedBox(width: 4),
                              Text('Ad-Hoc Fees',
                                  style: TextStyle(
                                      color: _accentAmber,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        ..._openAdHocItems
                            .map((e) => _adhocAllocationRow(e, money))
                            .toList(),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // Allocation summary
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: _bgDark,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _borderColor),
                ),
                child: Row(children: [
                  Text('Outstanding: ${money.format(outstanding)}',
                      style: const TextStyle(
                          color: _textSecondary, fontSize: 12)),
                  const Spacer(),
                  Text('Allocated: ${money.format(allocated)}',
                      style: TextStyle(
                          color: allocated > 0
                              ? _accentGreen
                              : _textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.bold)),
                ]),
              ),

              const SizedBox(height: 12),

              // Mode + date + ref + notes
              Row(children: [
                Expanded(
                  child: DropdownButtonFormField<TermPaymentMode>(
                    value: _mode,
                    dropdownColor: _cardDark,
                    style: const TextStyle(color: _textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Mode',
                      labelStyle: TextStyle(color: _textSecondary),
                      isDense: true,
                    ),
                    items: TermPaymentMode.values
                        .map((m) => DropdownMenuItem(
                            value: m, child: Text(m.name)))
                        .toList(),
                    onChanged: _saving
                        ? null
                        : (v) => setState(
                            () => _mode = v ?? TermPaymentMode.CASH),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: _saving
                        ? null
                        : () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _paidAt,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now()
                                  .add(const Duration(days: 1)),
                            );
                            if (picked != null) {
                              setState(() => _paidAt = picked);
                            }
                          },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Date',
                        labelStyle: TextStyle(color: _textSecondary),
                        isDense: true,
                      ),
                      child: Text(
                          DateFormat('dd MMM yyyy').format(_paidAt),
                          style: const TextStyle(color: _textPrimary)),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              TextField(
                controller: _refCtrl,
                style: const TextStyle(color: _textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Transaction Reference',
                  labelStyle: TextStyle(color: _textSecondary),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _notesCtrl,
                style: const TextStyle(color: _textPrimary),
                maxLines: 1,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  labelStyle: TextStyle(color: _textSecondary),
                  isDense: true,
                ),
              ),

              if (_error != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _accentRed.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                    border:
                        Border.all(color: _accentRed.withOpacity(0.4)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.warning_amber,
                        color: _accentRed, size: 14),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(_error!,
                          style: const TextStyle(
                              color: _accentRed, fontSize: 12)),
                    ),
                  ]),
                ),
              ],

              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _saving || allocated <= 0 ? null : _submit,
                  icon: _saving
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.save_rounded),
                  label: Text(_saving
                      ? 'Saving…'
                      : 'Save Payment (${money.format(allocated)})'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accentGreen,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: _borderColor,
                    disabledForegroundColor: _textSecondary,
                    padding:
                        const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
          ),
        ),
      ),
    );
  }

  Widget _allocationRow(TermLedgerEntry e, NumberFormat money) {
    final isArrear = e.isArrear;
    final tagColor = isArrear ? _accentRed : _accentBlue;
    final tagLabel = isArrear ? 'ARREARS ${e.sourceAcademicYear}' : e.category;

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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: tagColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: tagColor.withOpacity(0.4)),
            ),
            child: Text(tagLabel,
                style: TextStyle(
                    color: tagColor,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3)),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.termName,
                    style: const TextStyle(
                        color: _textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
                Text(
                    'Due ${DateFormat('dd MMM yyyy').format(e.dueDate)} • Bal ${money.format(e.balanceAmount)}',
                    style: const TextStyle(
                        color: _textSecondary, fontSize: 10)),
              ],
            ),
          ),
          SizedBox(
            width: 110,
            child: TextField(
              controller: _amountCtrls[e.termId],
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))
              ],
              style: const TextStyle(color: _textPrimary, fontSize: 13),
              textAlign: TextAlign.right,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                prefixText: '₹ ',
                prefixStyle: const TextStyle(color: _textSecondary),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 8),
                hintText: '0',
                hintStyle: const TextStyle(color: _textSecondary),
                filled: true,
                fillColor: _cardDark,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: _borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: _borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: _accentGreen),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _adhocAllocationRow(StudentFeeItem item, NumberFormat money) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _bgDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _accentAmber.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _accentAmber.withOpacity(0.15),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: _accentAmber.withOpacity(0.4)),
            ),
            child: Text(item.categoryCode,
                style: TextStyle(
                    color: _accentAmber,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3)),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.itemName,
                    style: const TextStyle(
                        color: _textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
                Text(
                    'Due ${DateFormat('dd MMM yyyy').format(item.dueDate)} • Bal ${money.format(item.balanceAmount)}',
                    style: const TextStyle(
                        color: _textSecondary, fontSize: 10)),
              ],
            ),
          ),
          SizedBox(
            width: 110,
            child: TextField(
              controller: _adhocAmountCtrls[item.id],
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))
              ],
              style: const TextStyle(color: _textPrimary, fontSize: 13),
              textAlign: TextAlign.right,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                prefixText: '₹ ',
                prefixStyle: const TextStyle(color: _textSecondary),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 8),
                hintText: '0',
                hintStyle: const TextStyle(color: _textSecondary),
                filled: true,
                fillColor: _cardDark,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: _borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: _borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: _accentAmber),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Suppress unused-warning for _accentAmber if neighbors trim it.
// ignore: unused_element
const Color _kKeepAmber = _accentAmber;
