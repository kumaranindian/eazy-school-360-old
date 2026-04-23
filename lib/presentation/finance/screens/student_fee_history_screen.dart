import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../data/services/student_yearly_history_service.dart';
import '../../../domain/entities/student_yearly_history.dart';

const Color _bgDark = Color(0xFF0D1117);
const Color _cardDark = Color(0xFF161B22);
const Color _accentGreen = Color(0xFF4CAF50);
const Color _accentBlue = Color(0xFF3B82F6);
const Color _accentAmber = Color(0xFFF59E0B);
const Color _accentRed = Color(0xFFEF4444);
const Color _textPrimary = Color(0xFFE6EDF3);
const Color _textSecondary = Color(0xFF8B949E);
const Color _borderColor = Color(0xFF30363D);

/// Per-academic-year fee history for a single student.
///
/// Shows the class the student was in for each AY plus aggregated fee
/// figures (fees expected, fees paid that year, arrears carried in/paid,
/// balance at end of year). Data is sourced from
/// `schools/{id}/students/{sid}/yearly_history` (written at creation,
/// every payment and at promotion time). Payments are layered on by
/// reading `bills` filtered by `stuId` so late arrears payments for older
/// years show up under the originating AY.
class StudentFeeHistoryScreen extends ConsumerStatefulWidget {
  final String studentDocId;
  final String studentName;
  final String studentNumericId;
  final String currentClassName;
  final String currentAcademicYear;

  const StudentFeeHistoryScreen({
    super.key,
    required this.studentDocId,
    required this.studentName,
    required this.studentNumericId,
    required this.currentClassName,
    required this.currentAcademicYear,
  });

  @override
  ConsumerState<StudentFeeHistoryScreen> createState() =>
      _StudentFeeHistoryScreenState();
}

class _StudentFeeHistoryScreenState
    extends ConsumerState<StudentFeeHistoryScreen> {
  final _historyService = StudentYearlyHistoryService();
  bool _loading = true;
  String? _error;
  List<StudentYearlyHistory> _history = [];
  // Per-AY list of payments (from bills.originatingAcademicYear)
  final Map<String, List<_PaymentEntry>> _paymentsByAY = {};

  String? get _schoolId => ref.read(currentSessionProvider)?.schoolId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final schoolId = _schoolId;
    if (schoolId == null) {
      setState(() {
        _loading = false;
        _error = 'No active school session';
      });
      return;
    }
    try {
      final history = await _historyService.getHistory(
        schoolId: schoolId,
        studentDocId: widget.studentDocId,
      );

      // If the student has no history docs yet (pre-migration), synthesise a
      // single row for the current year so the UI still shows something.
      final rows = history.isEmpty
          ? [
              StudentYearlyHistory(
                id: widget.currentAcademicYear,
                schoolId: schoolId,
                studentDocId: widget.studentDocId,
                studentNumericId: widget.studentNumericId,
                studentName: widget.studentName,
                academicYear: widget.currentAcademicYear,
                className: widget.currentClassName,
                section: '',
                isCurrent: true,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              )
            ]
          : history;

      // Pull payments grouped by originatingAcademicYear so arrears paid in
      // later years roll up under the year they belong to.
      final billsSnap = await FirebaseFirestore.instance
          .collection('schools')
          .doc(schoolId)
          .collection('bills')
          .where('billType', isEqualTo: 'Revenue')
          .where('stuId', isEqualTo: widget.studentNumericId)
          .where('isDeleted', isEqualTo: false)
          .get();

      final payments = <String, List<_PaymentEntry>>{};
      for (final d in billsSnap.docs) {
        final data = d.data();
        final ay = ((data['originatingAcademicYear'] ?? data['academicYear']) ??
                '')
            .toString();
        if (ay.isEmpty) continue;
        payments.putIfAbsent(ay, () => []).add(_PaymentEntry.fromMap(data));
      }
      for (final list in payments.values) {
        list.sort((a, b) => b.date.compareTo(a.date));
      }

      if (!mounted) return;
      setState(() {
        _history = rows;
        _paymentsByAY
          ..clear()
          ..addAll(payments);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgDark,
      appBar: AppBar(
        backgroundColor: _cardDark,
        foregroundColor: _textPrimary,
        elevation: 0,
        title: Text('${widget.studentName} — Fee History',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(32),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                _pill('ID ${widget.studentNumericId}', _accentBlue),
                const SizedBox(width: 8),
                _pill('Class ${widget.currentClassName}', _accentGreen),
                const SizedBox(width: 8),
                _pill('AY ${widget.currentAcademicYear}', _accentAmber),
              ],
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _accentGreen))
          : _error != null
              ? _errorCard(_error!)
              : _history.isEmpty
                  ? const Center(
                      child: Text('No academic-year records yet',
                          style: TextStyle(color: _textSecondary)))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _history.length,
                      itemBuilder: (_, i) => _buildYearCard(_history[i]),
                    ),
    );
  }

  Widget _buildYearCard(StudentYearlyHistory h) {
    final payments = _paymentsByAY[h.academicYear] ?? const <_PaymentEntry>[];
    final paidFromBills = payments.fold<double>(0, (s, p) => s + p.amount);
    // Prefer the snapshot's paidTotalFees if available; else fall back to
    // the sum of bills we just fetched.
    final paid = h.paidTotalFees > 0 ? h.paidTotalFees : paidFromBills;
    final expected = h.totalFees + h.arrearsCarriedIn;
    final balance = h.balanceAtEndOfYear > 0
        ? h.balanceAtEndOfYear
        : (expected - paid).clamp(0, double.infinity).toDouble();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: _cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: h.isCurrent
                ? _accentGreen.withOpacity(0.5)
                : _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _bgDark.withOpacity(0.6),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (h.isCurrent ? _accentGreen : _accentBlue)
                        .withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('AY ${h.academicYear}',
                      style: TextStyle(
                          color: h.isCurrent ? _accentGreen : _accentBlue,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 8),
                Text('Class ${h.className.isEmpty ? '—' : h.className}',
                    style: const TextStyle(
                        color: _textPrimary, fontWeight: FontWeight.w600)),
                if (h.section.isNotEmpty)
                  Text('  •  Sec ${h.section}',
                      style: const TextStyle(color: _textSecondary)),
                const Spacer(),
                if (h.isCurrent)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _accentGreen.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('CURRENT',
                        style: TextStyle(
                            color: _accentGreen,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5)),
                  )
                else if (h.promotedOn != null)
                  Text(
                      'Promoted ${DateFormat('dd MMM yyyy').format(h.promotedOn!)}',
                      style: const TextStyle(
                          color: _textSecondary, fontSize: 11)),
              ],
            ),
          ),

          // Metrics
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
            child: Row(
              children: [
                _metric('Expected', expected, _accentBlue),
                _metric('Paid', paid, _accentGreen),
                _metric('Balance', balance.toDouble(),
                    balance > 0 ? _accentRed : _textSecondary),
              ],
            ),
          ),
          if (h.arrearsCarriedIn > 0 || h.arrearsPaid > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
              child: Row(
                children: [
                  _miniStat(
                      'Arrears in', h.arrearsCarriedIn, _accentAmber),
                  const SizedBox(width: 16),
                  _miniStat(
                      'Arrears paid', h.arrearsPaid, _accentGreen),
                ],
              ),
            ),

          // Payment list
          if (payments.isNotEmpty) ...[
            const Divider(height: 1, color: _borderColor),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
              child: Text('Payments (${payments.length})',
                  style: const TextStyle(
                      color: _textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5)),
            ),
            ...payments.take(6).map((p) => Padding(
                  padding: const EdgeInsets.fromLTRB(14, 2, 14, 2),
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: _accentGreen,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${p.revenueType.isEmpty ? 'Payment' : p.revenueType}'
                          '${p.paidInAY != h.academicYear ? '  (paid in ${p.paidInAY})' : ''}',
                          style: const TextStyle(
                              color: _textPrimary, fontSize: 12),
                        ),
                      ),
                      Text(DateFormat('dd MMM').format(p.date),
                          style: const TextStyle(
                              color: _textSecondary, fontSize: 11)),
                      const SizedBox(width: 10),
                      Text('₹${p.amount.toStringAsFixed(0)}',
                          style: const TextStyle(
                              color: _accentGreen,
                              fontWeight: FontWeight.w600,
                              fontSize: 12)),
                    ],
                  ),
                )),
            if (payments.length > 6)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
                child: Text('+ ${payments.length - 6} more',
                    style: const TextStyle(
                        color: _textSecondary, fontSize: 11)),
              )
            else
              const SizedBox(height: 10),
          ] else
            const Padding(
              padding: EdgeInsets.fromLTRB(14, 4, 14, 12),
              child: Text('No payments recorded for this year',
                  style: TextStyle(color: _textSecondary, fontSize: 11)),
            ),
        ],
      ),
    );
  }

  Widget _metric(String label, double value, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(color: _textSecondary, fontSize: 10)),
          const SizedBox(height: 2),
          Text('₹${value.toStringAsFixed(0)}',
              style: TextStyle(
                  color: color,
                  fontSize: 15,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _miniStat(String label, double value, Color color) {
    return Text('$label: ',
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500));
  }

  Widget _pill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  Widget _errorCard(String err) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _accentRed.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _accentRed.withOpacity(0.4)),
        ),
        child: Row(children: [
          const Icon(Icons.error_outline, color: _accentRed),
          const SizedBox(width: 10),
          Expanded(
            child: Text('Failed to load history: $err',
                style: const TextStyle(color: _textPrimary, fontSize: 13)),
          ),
        ]),
      ),
    );
  }
}

class _PaymentEntry {
  final double amount;
  final String revenueType;
  final DateTime date;
  final String paidInAY; // the AY the payment was recorded in (current AY)

  _PaymentEntry({
    required this.amount,
    required this.revenueType,
    required this.date,
    required this.paidInAY,
  });

  factory _PaymentEntry.fromMap(Map<String, dynamic> data) {
    final amt = (data['revenueAmount'] as num?)?.toDouble() ??
        (data['totalAmount'] as num?)?.toDouble() ??
        0.0;
    final ts = data['billDate'] as Timestamp? ?? data['createdAt'] as Timestamp?;
    return _PaymentEntry(
      amount: amt,
      revenueType: (data['revenueType'] ?? '').toString(),
      date: ts?.toDate() ?? DateTime.now(),
      paidInAY: (data['academicYear'] ?? '').toString(),
    );
  }
}
