import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

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
      final payments =
          await paymentRepo.listByLedger(widget.schoolId, widget.ledgerId);
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
          ? const Center(child: CircularProgressIndicator(color: _accentGreen))
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
                l.studentName.isNotEmpty ? l.studentName[0].toUpperCase() : '?',
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
                    style: const TextStyle(color: _textSecondary, fontSize: 12),
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
              child:
                  _stat('Assigned', money.format(l.totalAssigned), _accentBlue),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _stat('Paid', money.format(l.totalPaid), _accentGreen),
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
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _accentRed.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _accentRed.withOpacity(0.4)),
              ),
              child: Row(children: [
                const Icon(Icons.warning_amber, color: _accentRed, size: 16),
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
              style: const TextStyle(color: _textSecondary, fontSize: 11)),
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
                  color: color, fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }
}

class _TermRow extends StatelessWidget {
  const _TermRow({
    required this.entry,
    required this.money,
  });

  final TermLedgerEntry entry;
  final NumberFormat money;

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
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                      color: _textPrimary, fontWeight: FontWeight.bold)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: color.withOpacity(0.4)),
              ),
              child: Text(statusLabel,
                  style: TextStyle(
                      color: color, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Due ${DateFormat('dd MMM yyyy').format(entry.dueDate)}',
                      style:
                          const TextStyle(color: _textSecondary, fontSize: 11)),
                  const SizedBox(height: 2),
                  Text(
                    'Amount: ${money.format(entry.amount)}'
                    '${entry.lateFeeApplied > 0 ? ' + late ${money.format(entry.lateFeeApplied)}' : ''}',
                    style: const TextStyle(color: _textPrimary, fontSize: 12),
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
            if (entry.balanceAmount <= 0)
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
                  style: const TextStyle(color: _textSecondary, fontSize: 11)),
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
