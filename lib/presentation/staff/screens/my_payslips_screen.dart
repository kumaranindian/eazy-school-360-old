import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../data/repositories/payroll_repository.dart';
import '../../../domain/entities/payroll.dart';
import '../../../data/services/payslip_pdf_service.dart';

class MyPayslipsScreen extends ConsumerWidget {
  const MyPayslipsScreen({super.key});

  static const Color _cardDark = Color(0xFF161B22);
  static const Color _accentBlue = Color(0xFF4CAF50);
  static const Color _textPrimary = Color(0xFFE6EDF3);
  static const Color _textSecondary = Color(0xFF8B949E);
  static const Color _borderColor = Color(0xFF30363D);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(currentSessionProvider);
    if (session == null || session.schoolId == null) {
      return const Center(child: Text('Access Denied', style: TextStyle(color: _textPrimary)));
    }

    final payrollAsync = ref.watch(staffPayrollRecordsProvider((
      schoolId: session.schoolId!,
      userId: session.uid,
    )));

    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 1024;

    return payrollAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: _accentBlue)),
      error: (e, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade300, size: 48),
            const SizedBox(height: 12),
            Text('Failed to load payslips: $e', style: const TextStyle(color: _textSecondary, fontSize: 13), textAlign: TextAlign.center),
          ],
        ),
      ),
      data: (records) {
        if (records.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.receipt_long_rounded, size: 56, color: _textSecondary.withOpacity(0.4)),
                const SizedBox(height: 16),
                const Text('No Payslips Yet', style: TextStyle(color: _textPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 6),
                const Text('Your approved payslips will appear here.', style: TextStyle(color: _textSecondary, fontSize: 13)),
              ],
            ),
          );
        }

        return Padding(
          padding: EdgeInsets.all(isDesktop ? 28 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary card
              _buildSummaryCard(records, currencyFormat),
              const SizedBox(height: 20),
              const Text('Payslip History', style: TextStyle(color: _textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  itemCount: records.length,
                  itemBuilder: (context, index) {
                    final record = records[index];
                    return _buildPayslipCard(context, record, currencyFormat, isDesktop);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryCard(List<PayrollRecord> records, NumberFormat fmt) {
    final latest = records.first;
    final ytdGross = records
        .where((r) => r.year == DateTime.now().year)
        .fold<double>(0, (s, r) => s + r.grossSalary);
    final ytdNet = records
        .where((r) => r.year == DateTime.now().year)
        .fold<double>(0, (s, r) => s + r.netSalary);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_accentBlue.withOpacity(0.15), const Color(0xFF161B22)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _accentBlue.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: _accentBlue.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.account_balance_wallet_rounded, color: _accentBlue, size: 24),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Latest Salary', style: TextStyle(color: _textSecondary, fontSize: 12)),
                  Text(fmt.format(latest.netSalary),
                      style: const TextStyle(color: _accentBlue, fontWeight: FontWeight.bold, fontSize: 24)),
                  Text(latest.periodLabel, style: const TextStyle(color: _textSecondary, fontSize: 12)),
                ],
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('YTD Gross', style: TextStyle(color: _textSecondary, fontSize: 11)),
                  Text(fmt.format(ytdGross),
                      style: const TextStyle(color: _textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 4),
                  const Text('YTD Net', style: TextStyle(color: _textSecondary, fontSize: 11)),
                  Text(fmt.format(ytdNet),
                      style: const TextStyle(color: _accentBlue, fontWeight: FontWeight.w600, fontSize: 14)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPayslipCard(BuildContext context, PayrollRecord record, NumberFormat fmt, bool isDesktop) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        iconColor: _textSecondary,
        collapsedIconColor: _textSecondary,
        shape: const RoundedRectangleBorder(side: BorderSide.none),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _accentBlue.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.receipt_long_rounded, color: _accentBlue, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(record.periodLabel,
                      style: const TextStyle(color: _textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 4),
                  Wrap(spacing: 6, runSpacing: 4, children: [
                    _tagChip('Present: ${record.presentDays}/${record.workingDays}', const Color(0xFF10B981)),
                    if (record.paidLeaveDays > 0)
                      _tagChip('PL: ${record.paidLeaveDays}d', const Color(0xFF3B82F6)),
                    if (record.unpaidLeaveDays > 0)
                      _tagChip('LOP: ${record.unpaidLeaveDays}d', const Color(0xFFF59E0B)),
                  ]),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(fmt.format(record.netSalary),
                    style: const TextStyle(color: _accentBlue, fontWeight: FontWeight.bold, fontSize: 16)),
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: record.status == PayrollStatus.PAID
                        ? const Color(0xFF3B82F6).withOpacity(0.15)
                        : const Color(0xFF10B981).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    record.status == PayrollStatus.PAID ? 'PAID' : 'APPROVED',
                    style: TextStyle(
                      color: record.status == PayrollStatus.PAID ? const Color(0xFF3B82F6) : const Color(0xFF10B981),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        children: [
          const Divider(color: _borderColor, height: 1),
          const SizedBox(height: 12),

          // ── Attendance Summary ──
          _sectionHeader('Attendance Summary', Icons.calendar_today_rounded, const Color(0xFF10B981)),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFF0D1117), borderRadius: BorderRadius.circular(8), border: Border.all(color: _borderColor)),
            child: Column(children: [
              _detailRow('Total Working Days', '${record.workingDays}'),
              _detailRow('Days Present', '${record.presentDays}', color: const Color(0xFF10B981)),
              _detailRow('Total Leave Days', '${record.leaveDaysTaken}'),
              _detailRow('Paid Leave', '${record.paidLeaveDays} days', color: const Color(0xFF3B82F6)),
              if (record.unpaidLeaveDays > 0)
                _detailRow('Unpaid Leave (LOP)', '${record.unpaidLeaveDays} days', color: const Color(0xFFF59E0B)),
            ]),
          ),
          const SizedBox(height: 12),

          // ── Leave Breakdown ──
          if (record.leaveBreakdown.isNotEmpty) ...[
            _sectionHeader('Leave Breakdown', Icons.event_note_rounded, const Color(0xFF8B5CF6)),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFF0D1117), borderRadius: BorderRadius.circular(8), border: Border.all(color: _borderColor)),
              child: Column(children: [
                // Header row
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(children: const [
                    Expanded(flex: 3, child: Text('Type', style: TextStyle(color: _textSecondary, fontSize: 10, fontWeight: FontWeight.w600))),
                    Expanded(child: Text('Quota', style: TextStyle(color: _textSecondary, fontSize: 10, fontWeight: FontWeight.w600), textAlign: TextAlign.center)),
                    Expanded(child: Text('Used', style: TextStyle(color: _textSecondary, fontSize: 10, fontWeight: FontWeight.w600), textAlign: TextAlign.center)),
                    Expanded(child: Text('This Mo', style: TextStyle(color: _textSecondary, fontSize: 10, fontWeight: FontWeight.w600), textAlign: TextAlign.center)),
                    Expanded(child: Text('Bal', style: TextStyle(color: _textSecondary, fontSize: 10, fontWeight: FontWeight.w600), textAlign: TextAlign.center)),
                  ]),
                ),
                ...record.leaveBreakdown.map((lb) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(children: [
                    Expanded(flex: 3, child: Row(children: [
                      Text(lb.leaveTypeName, style: const TextStyle(color: _textPrimary, fontSize: 11)),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                        decoration: BoxDecoration(
                          color: lb.isPaid ? const Color(0xFF10B981).withOpacity(0.12) : const Color(0xFFF59E0B).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: Text(lb.isPaid ? 'P' : 'U',
                            style: TextStyle(color: lb.isPaid ? const Color(0xFF10B981) : const Color(0xFFF59E0B), fontSize: 8, fontWeight: FontWeight.bold)),
                      ),
                    ])),
                    Expanded(child: Text('${lb.allowed}', style: const TextStyle(color: _textSecondary, fontSize: 11), textAlign: TextAlign.center)),
                    Expanded(child: Text('${lb.used}', style: const TextStyle(color: _textSecondary, fontSize: 11), textAlign: TextAlign.center)),
                    Expanded(child: Text('${lb.takenThisMonth}',
                        style: TextStyle(color: lb.takenThisMonth > 0 ? const Color(0xFFF59E0B) : _textSecondary, fontSize: 11, fontWeight: lb.takenThisMonth > 0 ? FontWeight.bold : FontWeight.normal),
                        textAlign: TextAlign.center)),
                    Expanded(child: Text('${lb.balance}',
                        style: TextStyle(color: lb.balance <= 0 ? Colors.redAccent : const Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center)),
                  ]),
                )),
              ]),
            ),
            const SizedBox(height: 12),
          ],

          // ── Earnings ──
          _sectionHeader('Earnings', Icons.trending_up_rounded, _accentBlue),
          _detailRow('Basic Pay', fmt.format(record.basicPay)),
          ...record.earnings.map((e) => _detailRow(e.name, fmt.format(e.amount))),
          _detailRow('Gross Salary', fmt.format(record.grossSalary), isBold: true),
          const SizedBox(height: 12),

          // ── Deductions ──
          _sectionHeader('Deductions', Icons.trending_down_rounded, Colors.redAccent),
          ...record.deductions.map((d) => _detailRow(d.name, '- ${fmt.format(d.amount)}', color: Colors.redAccent)),
          if (record.lopDeduction > 0)
            _detailRow(
              'LOP (${record.unpaidLeaveDays}d × ${fmt.format(record.perDaySalary)}/day)',
              '- ${fmt.format(record.lopDeduction)}',
              color: const Color(0xFFF59E0B),
            ),
          _detailRow('Total Deductions', '- ${fmt.format(record.totalDeductions)}', isBold: true, color: Colors.redAccent),
          const Divider(color: _borderColor, height: 24),

          // ── Net Pay ──
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [_accentBlue.withOpacity(0.1), _cardDark]),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _accentBlue.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('NET PAY', style: TextStyle(color: _textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
                Text(fmt.format(record.netSalary),
                    style: const TextStyle(color: _accentBlue, fontWeight: FontWeight.bold, fontSize: 20)),
              ],
            ),
          ),
          if (record.perDaySalary > 0) ...[
            const SizedBox(height: 6),
            Text('Per day salary: ${fmt.format(record.perDaySalary)}',
                style: const TextStyle(color: _textSecondary, fontSize: 10)),
          ],
          if (record.approvedAt != null) ...[
            const SizedBox(height: 4),
            Text('Approved on ${DateFormat('dd MMM yyyy, hh:mm a').format(record.approvedAt!)}',
                style: const TextStyle(color: _textSecondary, fontSize: 10)),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                try {
                  await PayslipPdfService.downloadSinglePayslip(record);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Payslip downloaded for ${record.periodLabel}'), backgroundColor: const Color(0xFF10B981)),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Download failed: $e'), backgroundColor: Colors.red),
                  );
                }
              },
              icon: const Icon(Icons.download_rounded, size: 16),
              label: const Text('Download Payslip PDF'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentBlue.withOpacity(0.15),
                foregroundColor: _accentBlue,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: _accentBlue.withOpacity(0.3))),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tagChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
      child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }

  Widget _sectionHeader(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(
            color: _textSecondary,
            fontSize: 13,
            fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
          )),
          Text(value, style: TextStyle(
            color: color ?? _textPrimary,
            fontSize: 13,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
          )),
        ],
      ),
    );
  }
}
