import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../data/repositories/student_fee_ledger_repository.dart';
import '../../../data/repositories/term_fee_payment_repository.dart';
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

class StudentFeeLedgerDetailScreen extends ConsumerStatefulWidget {
  const StudentFeeLedgerDetailScreen({
    super.key,
    required this.schoolId,
    required this.ledgerId,
  });

  final String schoolId;
  final String ledgerId;

  @override
  ConsumerState<StudentFeeLedgerDetailScreen> createState() =>
      _StudentFeeLedgerDetailScreenState();
}

class _StudentFeeLedgerDetailScreenState
    extends ConsumerState<StudentFeeLedgerDetailScreen> {
  StudentFeeLedger? _ledger;
  List<TermFeePayment> _payments = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ledgerRepo = ref.read(studentFeeLedgerRepositoryProvider);
      final paymentRepo = ref.read(termFeePaymentRepositoryProvider);
      final ledger = await ledgerRepo.getById(widget.schoolId, widget.ledgerId);
      final payments = await paymentRepo.listByLedger(
          widget.schoolId, widget.ledgerId);
      if (!mounted) return;
      setState(() {
        _ledger = ledger;
        _payments = payments;
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
    return Scaffold(
      backgroundColor: _bgDark,
      appBar: AppBar(
        backgroundColor: _bgDark,
        elevation: 0,
        title: const Text('Student Fee Ledger',
            style: TextStyle(color: _textPrimary, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: _textPrimary),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: _textSecondary),
            onPressed: _refresh,
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: _accentGreen))
          : _error != null
              ? Center(
                  child: Text('Error: $_error',
                      style: const TextStyle(color: _textSecondary)))
              : _ledger == null
                  ? const Center(
                      child: Text('Ledger not found.',
                          style: TextStyle(color: _textSecondary)))
                  : _body(_ledger!),
    );
  }

  Widget _body(StudentFeeLedger ledger) {
    final money =
        NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return RefreshIndicator(
      color: _accentGreen,
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _summaryCard(ledger, money),
          const SizedBox(height: 16),
          const Text('Terms',
              style: TextStyle(
                  color: _textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14)),
          const SizedBox(height: 8),
          ...ledger.termStatus.map((t) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _TermRow(
                  entry: t,
                  money: money,
                  onPay: () => _openPaymentSheet(ledger, t),
                ),
              )),
          const SizedBox(height: 16),
          const Text('Payment History',
              style: TextStyle(
                  color: _textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14)),
          const SizedBox(height: 8),
          if (_payments.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _cardDark,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _borderColor),
              ),
              child: const Text('No payments recorded yet.',
                  style: TextStyle(color: _textSecondary)),
            )
          else
            ..._payments.map((p) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _PaymentTile(payment: p, money: money),
                )),
        ],
      ),
    );
  }

  Widget _summaryCard(StudentFeeLedger l, NumberFormat money) {
    final pct = l.totalAssigned == 0
        ? 0.0
        : (l.totalPaid / l.totalAssigned).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: _accentBlue.withOpacity(0.2),
              child: Text(
                l.studentName.isNotEmpty
                    ? l.studentName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                    color: _accentBlue,
                    fontWeight: FontWeight.bold,
                    fontSize: 18),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.studentName,
                      style: const TextStyle(
                          color: _textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                  Text(
                    '${l.className} • ${l.section} • AY ${l.academicYear}',
                    style: const TextStyle(
                        color: _textSecondary, fontSize: 12),
                  ),
                  if (l.parentPhone != null && l.parentPhone!.isNotEmpty)
                    Text('Parent: ${l.parentName ?? ''} ${l.parentPhone}',
                        style: const TextStyle(
                            color: _textSecondary, fontSize: 11)),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: _stat('Assigned', money.format(l.totalAssigned),
                  _accentBlue),
            ),
            const SizedBox(width: 8),
            Expanded(
              child:
                  _stat('Paid', money.format(l.totalPaid), _accentGreen),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _stat(
                'Pending',
                money.format(l.totalPending),
                l.totalPending <= 0 ? _accentGreen : _accentAmber,
              ),
            ),
          ]),
          if (l.totalOverdue > 0) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _accentRed.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _accentRed.withOpacity(0.4)),
              ),
              child: Row(children: [
                const Icon(Icons.warning_amber,
                    color: _accentRed, size: 16),
                const SizedBox(width: 6),
                Text('Overdue: ${money.format(l.totalOverdue)}',
                    style: const TextStyle(
                        color: _accentRed, fontWeight: FontWeight.w600)),
              ]),
            ),
          ],
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 6,
              backgroundColor: _bgDark,
              valueColor: AlwaysStoppedAnimation(
                  l.totalPending <= 0 ? _accentGreen : _accentAmber),
            ),
          ),
          const SizedBox(height: 4),
          Text('${(pct * 100).toStringAsFixed(0)}% collected',
              style: const TextStyle(
                  color: _textSecondary, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(color: _textSecondary, fontSize: 10)),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 14)),
        ],
      ),
    );
  }

  void _openPaymentSheet(
      StudentFeeLedger ledger, TermLedgerEntry entry) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: _cardDark,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _RecordPaymentSheet(
        schoolId: widget.schoolId,
        ledger: ledger,
        entry: entry,
      ),
    );
    if (result == true) {
      _refresh();
    }
  }
}

class _TermRow extends StatelessWidget {
  const _TermRow({
    required this.entry,
    required this.money,
    required this.onPay,
  });

  final TermLedgerEntry entry;
  final NumberFormat money;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(entry.status);
    final statusLabel = entry.status.name;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _cardDark,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _accentBlue.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text('#${entry.sequence}',
                  style: const TextStyle(
                      color: _accentBlue,
                      fontWeight: FontWeight.bold,
                      fontSize: 11)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(entry.termName,
                  style: const TextStyle(
                      color: _textPrimary,
                      fontWeight: FontWeight.bold)),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: color.withOpacity(0.4)),
              ),
              child: Text(statusLabel,
                  style: TextStyle(
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.bold)),
            ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Due ${DateFormat('dd MMM yyyy').format(entry.dueDate)}',
                      style: const TextStyle(
                          color: _textSecondary, fontSize: 11)),
                  const SizedBox(height: 2),
                  Text(
                    'Amount: ${money.format(entry.amount)}'
                    '${entry.lateFeeApplied > 0 ? ' + late ${money.format(entry.lateFeeApplied)}' : ''}',
                    style: const TextStyle(
                        color: _textPrimary, fontSize: 12),
                  ),
                  Text(
                      'Paid: ${money.format(entry.paidAmount)} • Balance: ${money.format(entry.balanceAmount)}',
                      style: TextStyle(
                          color: entry.balanceAmount > 0
                              ? _accentAmber
                              : _accentGreen,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            if (entry.balanceAmount > 0)
              ElevatedButton.icon(
                onPressed: onPay,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accentGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                ),
                icon: const Icon(Icons.payments_outlined, size: 16),
                label: const Text('Record Payment'),
              )
            else
              const Icon(Icons.check_circle, color: _accentGreen),
          ]),
        ],
      ),
    );
  }

  Color _statusColor(TermPaymentStatus s) {
    switch (s) {
      case TermPaymentStatus.PAID:
        return _accentGreen;
      case TermPaymentStatus.PARTIAL:
        return _accentAmber;
      case TermPaymentStatus.OVERDUE:
        return _accentRed;
      case TermPaymentStatus.UNPAID:
        return _textSecondary;
    }
  }
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({required this.payment, required this.money});

  final TermFeePayment payment;
  final NumberFormat money;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _cardDark,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _borderColor),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _accentGreen.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.receipt, color: _accentGreen, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${payment.termName} • ${payment.receiptNumber}',
                  style: const TextStyle(
                      color: _textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
              const SizedBox(height: 2),
              Text(
                  '${DateFormat('dd MMM yyyy').format(payment.paidAt)} • ${payment.paymentMode.name}'
                  '${payment.collectedByName != null ? ' • ${payment.collectedByName}' : ''}',
                  style: const TextStyle(
                      color: _textSecondary, fontSize: 11)),
            ],
          ),
        ),
        Text(money.format(payment.amount),
            style: const TextStyle(
                color: _accentGreen,
                fontWeight: FontWeight.bold,
                fontSize: 15)),
      ]),
    );
  }
}

// ───────────────────────────────────── Record Payment Bottom Sheet ─────────────────────────────────────

class _RecordPaymentSheet extends ConsumerStatefulWidget {
  const _RecordPaymentSheet({
    required this.schoolId,
    required this.ledger,
    required this.entry,
  });

  final String schoolId;
  final StudentFeeLedger ledger;
  final TermLedgerEntry entry;

  @override
  ConsumerState<_RecordPaymentSheet> createState() =>
      _RecordPaymentSheetState();
}

class _RecordPaymentSheetState extends ConsumerState<_RecordPaymentSheet> {
  late final TextEditingController _amountCtrl;
  final _refCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  TermPaymentMode _mode = TermPaymentMode.CASH;
  DateTime _paidAt = DateTime.now();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController(
        text: widget.entry.balanceAmount.toStringAsFixed(0));
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _refCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final money =
        NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final balance = widget.entry.balanceAmount;
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(
          left: 16, right: 16, top: 16, bottom: 16 + viewInsets),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 48,
              height: 4,
              decoration: BoxDecoration(
                  color: _borderColor,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 12),
          Text('Record Payment',
              style: const TextStyle(
                  color: _textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 18)),
          const SizedBox(height: 4),
          Text(
              '${widget.ledger.studentName}  •  ${widget.entry.termName}  •  Balance ${money.format(balance)}',
              style:
                  const TextStyle(color: _textSecondary, fontSize: 12)),
          const SizedBox(height: 16),
          _label('Amount *'),
          const SizedBox(height: 4),
          TextField(
            controller: _amountCtrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))
            ],
            style: const TextStyle(
                color: _textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold),
            decoration: _input('0',
                prefix: '₹ ',
                suffix: 'Max ${money.format(balance)}'),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('Mode'),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: _bgDark,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _borderColor),
                    ),
                    child: DropdownButton<TermPaymentMode>(
                      value: _mode,
                      isExpanded: true,
                      underline: const SizedBox(),
                      dropdownColor: _cardDark,
                      iconEnabledColor: _textSecondary,
                      style: const TextStyle(color: _textPrimary),
                      items: TermPaymentMode.values
                          .map((m) => DropdownMenuItem(
                              value: m, child: Text(m.name)))
                          .toList(),
                      onChanged: (v) => setState(
                          () => _mode = v ?? TermPaymentMode.CASH),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('Date'),
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _paidAt,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now()
                            .add(const Duration(days: 1)),
                        builder: (c, child) => Theme(
                          data: Theme.of(c).copyWith(
                            colorScheme: const ColorScheme.dark(
                              primary: _accentGreen,
                              onPrimary: Colors.white,
                              surface: _cardDark,
                              onSurface: _textPrimary,
                            ),
                          ),
                          child: child!,
                        ),
                      );
                      if (picked != null) {
                        setState(() => _paidAt = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 12),
                      decoration: BoxDecoration(
                        color: _bgDark,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _borderColor),
                      ),
                      child: Row(children: [
                        const Icon(Icons.event,
                            size: 14, color: _textSecondary),
                        const SizedBox(width: 6),
                        Text(
                            DateFormat('dd MMM yyyy').format(_paidAt),
                            style: const TextStyle(
                                color: _textPrimary, fontSize: 13)),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 12),
          _label('Transaction Reference'),
          const SizedBox(height: 4),
          TextField(
            controller: _refCtrl,
            style: const TextStyle(color: _textPrimary),
            decoration: _input('UPI ID, Cheque#, etc. (optional)'),
          ),
          const SizedBox(height: 12),
          _label('Notes'),
          const SizedBox(height: 4),
          TextField(
            controller: _notesCtrl,
            style: const TextStyle(color: _textPrimary),
            maxLines: 2,
            decoration: _input('Optional remarks'),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentGreen,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.save),
              label: Text(_saving ? 'Saving…' : 'Save Payment'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    if (amount <= 0) {
      _toast('Enter a valid amount', error: true);
      return;
    }
    if (amount > widget.entry.balanceAmount + 0.01) {
      _toast('Amount exceeds balance', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final repo = ref.read(termFeePaymentRepositoryProvider);
      final session = ref.read(currentSessionProvider);
      await repo.recordPayment(RecordTermPaymentRequest(
        schoolId: widget.schoolId,
        ledgerId: widget.ledger.id,
        termId: widget.entry.termId,
        amount: amount,
        paymentMode: _mode,
        transactionRef:
            _refCtrl.text.trim().isEmpty ? null : _refCtrl.text.trim(),
        paidAt: _paidAt,
        notes:
            _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        collectedBy: session?.uid,
        collectedByName: session?.displayName,
      ));
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      _toast('Failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _label(String t) => Text(t,
      style: const TextStyle(color: _textSecondary, fontSize: 12));

  InputDecoration _input(String hint, {String? prefix, String? suffix}) =>
      InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: _textSecondary),
        prefixText: prefix,
        prefixStyle: const TextStyle(color: _textSecondary),
        suffixText: suffix,
        suffixStyle: const TextStyle(color: _textSecondary, fontSize: 11),
        filled: true,
        fillColor: _bgDark,
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
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      );

  void _toast(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? _accentRed : _accentGreen,
      ),
    );
  }
}
