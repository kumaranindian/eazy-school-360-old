import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../data/repositories/payroll_repository.dart';
import '../../../data/repositories/staff_management_repository.dart';
import '../../../domain/entities/payroll.dart';
import '../../../domain/entities/staff_profile.dart';
import '../../../data/services/payslip_pdf_service.dart';

class PayrollManagementScreen extends ConsumerStatefulWidget {
  const PayrollManagementScreen({super.key});

  @override
  ConsumerState<PayrollManagementScreen> createState() => _PayrollManagementScreenState();
}

class _PayrollManagementScreenState extends ConsumerState<PayrollManagementScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  bool _isProcessing = false;

  static const Color _bgDark = Color(0xFF0D1117);
  static const Color _cardDark = Color(0xFF161B22);
  static const Color _accentBlue = Color(0xFF4CAF50);
  static const Color _textPrimary = Color(0xFFE6EDF3);
  static const Color _textSecondary = Color(0xFF8B949E);
  static const Color _borderColor = Color(0xFF30363D);

  final _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(currentSessionProvider);
    if (session == null || session.schoolId == null) {
      return const Center(child: Text('Access Denied', style: TextStyle(color: _textPrimary)));
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 1024;

    return Scaffold(
      backgroundColor: _bgDark,
      body: Column(
        children: [
          _buildMonthSelector(isDesktop),
          TabBar(
            controller: _tabController,
            indicatorColor: _accentBlue,
            labelColor: _accentBlue,
            unselectedLabelColor: _textSecondary,
            tabs: const [
              Tab(text: 'Salary Config'),
              Tab(text: 'Monthly Payroll'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSalaryConfigTab(session),
                _buildMonthlyPayrollTab(session, isDesktop),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthSelector(bool isDesktop) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 28 : 16, vertical: 12),
      decoration: const BoxDecoration(
        color: _bgDark,
        border: Border(bottom: BorderSide(color: _borderColor)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: _textPrimary),
            onPressed: () {
              setState(() {
                _selectedMonth--;
                if (_selectedMonth < 1) {
                  _selectedMonth = 12;
                  _selectedYear--;
                }
              });
            },
          ),
          GestureDetector(
            onTap: () => _showMonthPicker(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _cardDark,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _borderColor),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.calendar_month, color: _accentBlue, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    DateFormat('MMMM yyyy').format(DateTime(_selectedYear, _selectedMonth)),
                    style: const TextStyle(color: _textPrimary, fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_drop_down, color: _textSecondary, size: 20),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: _textPrimary),
            onPressed: () {
              setState(() {
                _selectedMonth++;
                if (_selectedMonth > 12) {
                  _selectedMonth = 1;
                  _selectedYear++;
                }
              });
            },
          ),
          const Spacer(),
          if (!_isProcessing)
            ElevatedButton.icon(
              onPressed: () => _processAllPayroll(),
              icon: const Icon(Icons.play_arrow_rounded, size: 18),
              label: const Text('Process All'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            )
          else
            const SizedBox(
              width: 24, height: 24,
              child: CircularProgressIndicator(strokeWidth: 2, color: _accentBlue),
            ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () => _approveAllPayroll(),
            icon: const Icon(Icons.check_circle_rounded, size: 18),
            label: const Text('Approve All'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // TAB 1: SALARY CONFIG
  // ══════════════════════════════════════════════════════════════════

  Widget _buildSalaryConfigTab(dynamic session) {
    final configsAsync = ref.watch(allPayrollConfigsProvider(session.schoolId as String));
    final staffAsync = ref.watch(schoolStaffProvider(session.schoolId as String));

    return staffAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: _accentBlue)),
      error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.red))),
      data: (staffList) {
        return configsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: _accentBlue)),
          error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.red))),
          data: (configs) {
            final configMap = {for (var c in configs) c.staffId: c};
            final activeStaff = staffList.where((s) => s.isActive).toList();

            if (activeStaff.isEmpty) {
              return const Center(child: Text('No active staff found', style: TextStyle(color: _textSecondary)));
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: activeStaff.length,
              itemBuilder: (context, index) {
                final staff = activeStaff[index];
                final config = configMap[staff.id];
                return _buildStaffConfigCard(staff, config, session);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildStaffConfigCard(StaffProfile staff, PayrollConfig? config, dynamic session) {
    final hasConfig = config != null && config.netSalary > 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: hasConfig ? _accentBlue.withOpacity(0.3) : _borderColor),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showPayrollConfigDialog(staff, config, session),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: hasConfig ? _accentBlue.withOpacity(0.2) : _borderColor,
                  radius: 22,
                  child: Text(staff.name[0].toUpperCase(),
                      style: TextStyle(color: hasConfig ? _accentBlue : _textSecondary, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(staff.name, style: const TextStyle(color: _textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
                      const SizedBox(height: 2),
                      Text('${staff.employeeId} • ${staff.department}',
                          style: const TextStyle(color: _textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
                if (hasConfig) ...[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(_currencyFormat.format(config.netSalary),
                          style: const TextStyle(color: _accentBlue, fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('Net/month', style: const TextStyle(color: _textSecondary, fontSize: 11)),
                    ],
                  ),
                  const SizedBox(width: 12),
                ],
                Icon(hasConfig ? Icons.edit_rounded : Icons.add_circle_outline_rounded,
                    color: hasConfig ? _textSecondary : _accentBlue, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // TAB 2: MONTHLY PAYROLL
  // ══════════════════════════════════════════════════════════════════

  Widget _buildMonthlyPayrollTab(dynamic session, bool isDesktop) {
    final payrollAsync = ref.watch(monthlyPayrollProvider((
      schoolId: session.schoolId as String,
      month: _selectedMonth,
      year: _selectedYear,
    )));

    return payrollAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: _accentBlue)),
      error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.red))),
      data: (records) {
        if (records.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.receipt_long_rounded, size: 48, color: _textSecondary.withOpacity(0.5)),
                const SizedBox(height: 16),
                Text('No payroll records for ${DateFormat('MMMM yyyy').format(DateTime(_selectedYear, _selectedMonth))}',
                    style: const TextStyle(color: _textSecondary, fontSize: 14)),
                const SizedBox(height: 8),
                const Text('Click "Process All" to generate payroll', style: TextStyle(color: _textSecondary, fontSize: 12)),
              ],
            ),
          );
        }

        // Summary stats
        final totalGross = records.fold<double>(0, (s, r) => s + r.grossSalary);
        final totalNet = records.fold<double>(0, (s, r) => s + r.netSalary);
        final approvedCount = records.where((r) => r.isApproved).length;
        final processedCount = records.where((r) => r.isProcessed).length;

        return Column(
          children: [
            // Summary bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(color: _cardDark, border: Border(bottom: BorderSide(color: _borderColor))),
              child: Row(
                children: [
                  _summaryChip('Total Staff', '${records.length}', Icons.people_alt_rounded, const Color(0xFF3B82F6)),
                  const SizedBox(width: 16),
                  _summaryChip('Gross', _currencyFormat.format(totalGross), Icons.account_balance_wallet_rounded, const Color(0xFF8B5CF6)),
                  const SizedBox(width: 16),
                  _summaryChip('Net Payable', _currencyFormat.format(totalNet), Icons.payments_rounded, _accentBlue),
                  const SizedBox(width: 16),
                  _summaryChip('Approved', '$approvedCount / ${records.length}', Icons.check_circle_rounded, const Color(0xFF10B981)),
                  if (processedCount > 0) ...[
                    const SizedBox(width: 16),
                    _summaryChip('Pending Approval', '$processedCount', Icons.pending_rounded, const Color(0xFFF59E0B)),
                  ],
                  const Spacer(),
                  Tooltip(
                    message: 'Download all payslips as PDF',
                    child: ElevatedButton.icon(
                      onPressed: records.isEmpty ? null : () async {
                        try {
                          await PayslipPdfService.downloadBulkPayslips(records);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('All payslips downloaded!'), backgroundColor: Color(0xFF10B981)),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Download failed: $e'), backgroundColor: Colors.red),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.download_rounded, size: 16),
                      label: const Text('Download All', style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B82F6),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Records list
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: records.length,
                itemBuilder: (context, index) => _buildPayrollRecordCard(records[index], session),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _summaryChip(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
                  Text(label, style: const TextStyle(color: _textSecondary, fontSize: 10)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPayrollRecordCard(PayrollRecord record, dynamic session) {
    final statusColor = _getStatusColor(record.status);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showPayslipDetailDialog(record),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: statusColor.withOpacity(0.2),
                  radius: 22,
                  child: Text(record.staffName.isNotEmpty ? record.staffName[0].toUpperCase() : '?',
                      style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(record.staffName, style: const TextStyle(color: _textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
                      const SizedBox(height: 2),
                      Text('${record.employeeId} • ${record.department}',
                          style: const TextStyle(color: _textSecondary, fontSize: 12)),
                      const SizedBox(height: 4),
                      Row(children: [
                        _miniChip('Present: ${record.presentDays}/${record.workingDays}', const Color(0xFF10B981)),
                        const SizedBox(width: 6),
                        if (record.paidLeaveDays > 0)
                          _miniChip('Paid Leave: ${record.paidLeaveDays}d', const Color(0xFF3B82F6)),
                        if (record.paidLeaveDays > 0) const SizedBox(width: 6),
                        if (record.unpaidLeaveDays > 0)
                          _miniChip('LOP: ${record.unpaidLeaveDays}d', const Color(0xFFF59E0B)),
                      ]),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(_currencyFormat.format(record.netSalary),
                        style: const TextStyle(color: _textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
                    if (record.lopDeduction > 0)
                      Text('-${_currencyFormat.format(record.lopDeduction)}',
                          style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 11)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(record.status.name,
                          style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                if (record.isProcessed)
                  PopupMenuButton<String>(
                    color: _cardDark,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    onSelected: (value) {
                      if (value == 'approve') _approveSingle(record, session);
                      if (value == 'reject') _rejectSingle(record, session);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'approve', child: Text('Approve', style: TextStyle(color: _textPrimary))),
                      PopupMenuItem(value: 'reject', child: Text('Reject', style: TextStyle(color: Colors.red))),
                    ],
                    child: const Icon(Icons.more_vert, color: _textSecondary, size: 20),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _miniChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
      child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // DETAILED PAYSLIP DIALOG (Admin view)
  // ══════════════════════════════════════════════════════════════════

  void _showPayslipDetailDialog(PayrollRecord record) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: _cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 600,
          constraints: const BoxConstraints(maxHeight: 750),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _borderColor))),
                child: Row(
                  children: [
                    const Icon(Icons.receipt_long_rounded, color: _accentBlue, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Payslip', style: TextStyle(color: _textPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
                        Text(record.periodLabel, style: const TextStyle(color: _textSecondary, fontSize: 13)),
                      ]),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getStatusColor(record.status).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(record.status.name,
                          style: TextStyle(color: _getStatusColor(record.status), fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.download_rounded, color: _accentBlue),
                      tooltip: 'Download Payslip PDF',
                      onPressed: () async {
                        try {
                          await PayslipPdfService.downloadSinglePayslip(record);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Payslip downloaded for ${record.staffName}'), backgroundColor: const Color(0xFF10B981)),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Download failed: $e'), backgroundColor: Colors.red),
                            );
                          }
                        }
                      },
                    ),
                    IconButton(icon: const Icon(Icons.close, color: _textSecondary), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
              ),
              // Body
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    // Employee Info
                    _payslipSection('Employee Details', Icons.person_rounded, const Color(0xFF3B82F6), [
                      _payslipRow('Name', record.staffName),
                      _payslipRow('Employee ID', record.employeeId),
                      _payslipRow('Department', record.department.isNotEmpty ? record.department : '-'),
                      _payslipRow('Designation', record.designation.isNotEmpty ? record.designation : '-'),
                      _payslipRow('Pay Period', record.periodLabel),
                    ]),
                    const SizedBox(height: 16),

                    // Attendance Summary
                    _payslipSection('Attendance Summary', Icons.calendar_today_rounded, const Color(0xFF10B981), [
                      _payslipRow('Total Working Days', '${record.workingDays}'),
                      _payslipRow('Days Present', '${record.presentDays}'),
                      _payslipRow('Total Leave Days', '${record.leaveDaysTaken}'),
                      _payslipRow('Paid Leave Days', '${record.paidLeaveDays}', valueColor: const Color(0xFF10B981)),
                      _payslipRow('Unpaid Leave (LOP)', '${record.unpaidLeaveDays}',
                          valueColor: record.unpaidLeaveDays > 0 ? const Color(0xFFF59E0B) : null),
                    ]),
                    const SizedBox(height: 16),

                    // Leave Breakdown
                    if (record.leaveBreakdown.isNotEmpty) ...[
                      _payslipSection('Leave Breakdown', Icons.event_note_rounded, const Color(0xFF8B5CF6), [
                        // Table header
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(children: const [
                            Expanded(flex: 3, child: Text('Leave Type', style: TextStyle(color: _textSecondary, fontSize: 11, fontWeight: FontWeight.w600))),
                            Expanded(child: Text('Allowed', style: TextStyle(color: _textSecondary, fontSize: 11, fontWeight: FontWeight.w600), textAlign: TextAlign.center)),
                            Expanded(child: Text('Used', style: TextStyle(color: _textSecondary, fontSize: 11, fontWeight: FontWeight.w600), textAlign: TextAlign.center)),
                            Expanded(child: Text('This Mo.', style: TextStyle(color: _textSecondary, fontSize: 11, fontWeight: FontWeight.w600), textAlign: TextAlign.center)),
                            Expanded(child: Text('Balance', style: TextStyle(color: _textSecondary, fontSize: 11, fontWeight: FontWeight.w600), textAlign: TextAlign.center)),
                            SizedBox(width: 50, child: Text('Type', style: TextStyle(color: _textSecondary, fontSize: 11, fontWeight: FontWeight.w600), textAlign: TextAlign.center)),
                          ]),
                        ),
                        ...record.leaveBreakdown.map((lb) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(children: [
                            Expanded(flex: 3, child: Text(lb.leaveTypeName, style: const TextStyle(color: _textPrimary, fontSize: 12))),
                            Expanded(child: Text('${lb.allowed}', style: const TextStyle(color: _textSecondary, fontSize: 12), textAlign: TextAlign.center)),
                            Expanded(child: Text('${lb.used}', style: const TextStyle(color: _textSecondary, fontSize: 12), textAlign: TextAlign.center)),
                            Expanded(child: Text('${lb.takenThisMonth}',
                                style: TextStyle(color: lb.takenThisMonth > 0 ? const Color(0xFFF59E0B) : _textSecondary, fontSize: 12, fontWeight: lb.takenThisMonth > 0 ? FontWeight.bold : FontWeight.normal),
                                textAlign: TextAlign.center)),
                            Expanded(child: Text('${lb.balance}',
                                style: TextStyle(color: lb.balance <= 0 ? Colors.redAccent : const Color(0xFF10B981), fontSize: 12), textAlign: TextAlign.center)),
                            SizedBox(width: 50, child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: lb.isPaid ? const Color(0xFF10B981).withOpacity(0.12) : const Color(0xFFF59E0B).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(lb.isPaid ? 'Paid' : 'Unpaid',
                                  style: TextStyle(color: lb.isPaid ? const Color(0xFF10B981) : const Color(0xFFF59E0B), fontSize: 9, fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.center),
                            )),
                          ]),
                        )),
                      ]),
                      const SizedBox(height: 16),
                    ],

                    // Earnings
                    _payslipSection('Earnings', Icons.trending_up_rounded, _accentBlue, [
                      _payslipRow('Basic Pay', _currencyFormat.format(record.basicPay)),
                      ...record.earnings.map((e) => _payslipRow(e.name, _currencyFormat.format(e.amount))),
                      const Divider(color: _borderColor, height: 12),
                      _payslipRow('Gross Salary', _currencyFormat.format(record.grossSalary), isBold: true),
                    ]),
                    const SizedBox(height: 16),

                    // Deductions
                    _payslipSection('Deductions', Icons.trending_down_rounded, Colors.redAccent, [
                      ...record.deductions.map((d) => _payslipRow(d.name, '- ${_currencyFormat.format(d.amount)}', valueColor: Colors.redAccent)),
                      if (record.lopDeduction > 0)
                        _payslipRow('LOP Deduction (${record.unpaidLeaveDays} days × ${_currencyFormat.format(record.perDaySalary)}/day)',
                            '- ${_currencyFormat.format(record.lopDeduction)}', valueColor: const Color(0xFFF59E0B)),
                      const Divider(color: _borderColor, height: 12),
                      _payslipRow('Total Deductions', '- ${_currencyFormat.format(record.totalDeductions)}', isBold: true, valueColor: Colors.redAccent),
                    ]),
                    const SizedBox(height: 16),

                    // Net Pay
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [_accentBlue.withOpacity(0.15), _cardDark]),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _accentBlue.withOpacity(0.3)),
                      ),
                      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        const Text('NET PAY', style: TextStyle(color: _textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
                        Text(_currencyFormat.format(record.netSalary),
                            style: const TextStyle(color: _accentBlue, fontWeight: FontWeight.bold, fontSize: 22)),
                      ]),
                    ),

                    if (record.perDaySalary > 0) ...[
                      const SizedBox(height: 8),
                      Text('Per day salary: ${_currencyFormat.format(record.perDaySalary)}',
                          style: const TextStyle(color: _textSecondary, fontSize: 11)),
                    ],
                    if (record.approvedAt != null) ...[
                      const SizedBox(height: 4),
                      Text('Approved on: ${DateFormat('dd MMM yyyy, hh:mm a').format(record.approvedAt!)}',
                          style: const TextStyle(color: _textSecondary, fontSize: 11)),
                    ],
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _payslipSection(String title, IconData icon, Color color, List<Widget> children) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
      ]),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF0D1117),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _borderColor),
        ),
        child: Column(children: children),
      ),
    ]);
  }

  Widget _payslipRow(String label, String value, {bool isBold = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Flexible(child: Text(label, style: TextStyle(color: _textSecondary, fontSize: 12, fontWeight: isBold ? FontWeight.w600 : FontWeight.normal))),
        Text(value, style: TextStyle(color: valueColor ?? _textPrimary, fontSize: 12, fontWeight: isBold ? FontWeight.bold : FontWeight.w500)),
      ]),
    );
  }

  Color _getStatusColor(PayrollStatus status) {
    switch (status) {
      case PayrollStatus.DRAFT: return _textSecondary;
      case PayrollStatus.PROCESSED: return const Color(0xFFF59E0B);
      case PayrollStatus.APPROVED: return const Color(0xFF10B981);
      case PayrollStatus.PAID: return const Color(0xFF3B82F6);
      case PayrollStatus.REJECTED: return Colors.red;
    }
  }

  // ══════════════════════════════════════════════════════════════════
  // ACTIONS
  // ══════════════════════════════════════════════════════════════════

  Future<void> _processAllPayroll() async {
    final session = ref.read(currentSessionProvider);
    if (session?.schoolId == null) return;

    final staffList = await ref.read(schoolStaffProvider(session!.schoolId!).future);
    if (staffList.isEmpty) {
      _showSnack('No staff found', Colors.orange);
      return;
    }

    setState(() => _isProcessing = true);
    try {
      final repo = ref.read(payrollRepositoryProvider);
      final count = await repo.processPayrollForAll(
        schoolId: session.schoolId!,
        adminUserId: session.uid,
        month: _selectedMonth,
        year: _selectedYear,
        staffList: staffList,
      );
      _showSnack('Payroll processed for $count staff members', _accentBlue);
      _tabController.animateTo(1); // Switch to Monthly Payroll tab
    } catch (e) {
      _showSnack('Error: $e', Colors.red);
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _approveAllPayroll() async {
    final session = ref.read(currentSessionProvider);
    if (session?.schoolId == null) return;

    try {
      final repo = ref.read(payrollRepositoryProvider);
      final count = await repo.approveAllPayroll(
        session!.schoolId!, _selectedMonth, _selectedYear, session.uid,
      );
      _showSnack('$count payroll records approved! Teachers can now view their payslips.', _accentBlue);
    } catch (e) {
      _showSnack('Error: $e', Colors.red);
    }
  }

  Future<void> _approveSingle(PayrollRecord record, dynamic session) async {
    try {
      final repo = ref.read(payrollRepositoryProvider);
      await repo.approvePayroll(session.schoolId as String, record.id, session.uid as String);
      _showSnack('Payroll approved for ${record.staffName}', _accentBlue);
    } catch (e) {
      _showSnack('Error: $e', Colors.red);
    }
  }

  Future<void> _rejectSingle(PayrollRecord record, dynamic session) async {
    final reasonController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardDark,
        title: const Text('Reject Payroll', style: TextStyle(color: _textPrimary)),
        content: TextField(
          controller: reasonController,
          style: const TextStyle(color: _textPrimary),
          decoration: InputDecoration(
            hintText: 'Reason for rejection',
            hintStyle: const TextStyle(color: _textSecondary),
            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: _borderColor)),
            focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: _accentBlue)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, reasonController.text),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      try {
        final repo = ref.read(payrollRepositoryProvider);
        await repo.rejectPayroll(session.schoolId as String, record.id, session.uid as String, result);
        _showSnack('Payroll rejected for ${record.staffName}', Colors.orange);
      } catch (e) {
        _showSnack('Error: $e', Colors.red);
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════
  // PAYROLL CONFIG DIALOG
  // ══════════════════════════════════════════════════════════════════

  void _showPayrollConfigDialog(StaffProfile staff, PayrollConfig? existing, dynamic session) {
    showDialog(
      context: context,
      builder: (ctx) => _PayrollConfigDialog(
        staff: staff,
        existing: existing,
        schoolId: session.schoolId as String,
        adminUserId: session.uid as String,
      ),
    );
  }

  void _showMonthPicker() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardDark,
        title: const Text('Select Month', style: TextStyle(color: _textPrimary)),
        content: SizedBox(
          width: 300,
          height: 300,
          child: GridView.count(
            crossAxisCount: 3,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: List.generate(12, (i) {
              final month = i + 1;
              final isSelected = month == _selectedMonth;
              return InkWell(
                onTap: () {
                  setState(() => _selectedMonth = month);
                  Navigator.pop(ctx);
                },
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected ? _accentBlue.withOpacity(0.2) : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isSelected ? _accentBlue : _borderColor),
                  ),
                  child: Text(
                    DateFormat('MMM').format(DateTime(_selectedYear, month)),
                    style: TextStyle(color: isSelected ? _accentBlue : _textPrimary, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }
}

// ══════════════════════════════════════════════════════════════════
// PAYROLL CONFIG DIALOG (set salary for a staff member)
// ══════════════════════════════════════════════════════════════════

class _PayrollConfigDialog extends ConsumerStatefulWidget {
  final StaffProfile staff;
  final PayrollConfig? existing;
  final String schoolId;
  final String adminUserId;

  const _PayrollConfigDialog({
    required this.staff,
    this.existing,
    required this.schoolId,
    required this.adminUserId,
  });

  @override
  ConsumerState<_PayrollConfigDialog> createState() => _PayrollConfigDialogState();
}

class _PayrollConfigDialogState extends ConsumerState<_PayrollConfigDialog> {
  final _basicPayController = TextEditingController();
  final List<_ComponentEntry> _earnings = [];
  final List<_ComponentEntry> _deductions = [];
  bool _isSaving = false;

  static const Color _cardDark = Color(0xFF161B22);
  static const Color _accentBlue = Color(0xFF4CAF50);
  static const Color _textPrimary = Color(0xFFE6EDF3);
  static const Color _textSecondary = Color(0xFF8B949E);
  static const Color _borderColor = Color(0xFF30363D);

  final _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      _basicPayController.text = widget.existing!.basicPay.toStringAsFixed(0);
      for (final e in widget.existing!.earnings) {
        _earnings.add(_ComponentEntry(
          nameController: TextEditingController(text: e.name),
          amountController: TextEditingController(text: e.amount.toStringAsFixed(0)),
        ));
      }
      for (final d in widget.existing!.deductions) {
        _deductions.add(_ComponentEntry(
          nameController: TextEditingController(text: d.name),
          amountController: TextEditingController(text: d.amount.toStringAsFixed(0)),
        ));
      }
    }
    // Add default earnings if empty
    if (_earnings.isEmpty) {
      _earnings.add(_ComponentEntry(
        nameController: TextEditingController(text: 'HRA'),
        amountController: TextEditingController(),
      ));
      _earnings.add(_ComponentEntry(
        nameController: TextEditingController(text: 'DA'),
        amountController: TextEditingController(),
      ));
    }
    // Add default deductions if empty
    if (_deductions.isEmpty) {
      _deductions.add(_ComponentEntry(
        nameController: TextEditingController(text: 'PF'),
        amountController: TextEditingController(),
      ));
      _deductions.add(_ComponentEntry(
        nameController: TextEditingController(text: 'Professional Tax'),
        amountController: TextEditingController(),
      ));
    }
  }

  @override
  void dispose() {
    _basicPayController.dispose();
    for (final e in _earnings) { e.dispose(); }
    for (final d in _deductions) { d.dispose(); }
    super.dispose();
  }

  double get _basicPay => double.tryParse(_basicPayController.text) ?? 0;
  double get _totalEarnings => _earnings.fold<double>(0, (s, e) => s + (double.tryParse(e.amountController.text) ?? 0));
  double get _totalDeductions => _deductions.fold<double>(0, (s, d) => s + (double.tryParse(d.amountController.text) ?? 0));
  double get _grossSalary => _basicPay + _totalEarnings;
  double get _netSalary => _grossSalary - _totalDeductions;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _cardDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 520,
        constraints: const BoxConstraints(maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: _borderColor)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: _accentBlue.withOpacity(0.2),
                    child: Text(widget.staff.name[0], style: const TextStyle(color: _accentBlue, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Salary Structure', style: const TextStyle(color: _textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
                        Text(widget.staff.name, style: const TextStyle(color: _textSecondary, fontSize: 13)),
                      ],
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.close, color: _textSecondary), onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),

            // Scrollable body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Basic Pay
                    const Text('Basic Pay', style: TextStyle(color: _textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 8),
                    _buildAmountField(_basicPayController, 'Enter basic pay amount'),
                    const SizedBox(height: 20),

                    // Earnings
                    Row(
                      children: [
                        const Text('Earnings (Allowances)', style: TextStyle(color: _textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () => setState(() => _earnings.add(_ComponentEntry(
                            nameController: TextEditingController(),
                            amountController: TextEditingController(),
                          ))),
                          icon: const Icon(Icons.add, size: 16, color: _accentBlue),
                          label: const Text('Add', style: TextStyle(color: _accentBlue, fontSize: 12)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ..._earnings.asMap().entries.map((e) => _buildComponentRow(e.value, e.key, true)),

                    const SizedBox(height: 20),

                    // Deductions
                    Row(
                      children: [
                        const Text('Deductions', style: TextStyle(color: _textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () => setState(() => _deductions.add(_ComponentEntry(
                            nameController: TextEditingController(),
                            amountController: TextEditingController(),
                          ))),
                          icon: const Icon(Icons.add, size: 16, color: Colors.redAccent),
                          label: const Text('Add', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ..._deductions.asMap().entries.map((e) => _buildComponentRow(e.value, e.key, false)),

                    const SizedBox(height: 20),

                    // Summary
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _accentBlue.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _accentBlue.withOpacity(0.2)),
                      ),
                      child: Column(
                        children: [
                          _summaryRow('Basic Pay', _basicPay),
                          _summaryRow('Total Earnings', _totalEarnings),
                          _summaryRow('Gross Salary', _grossSalary, isBold: true),
                          const Divider(color: _borderColor, height: 20),
                          _summaryRow('Total Deductions', _totalDeductions, color: Colors.redAccent),
                          const Divider(color: _borderColor, height: 20),
                          _summaryRow('Net Salary', _netSalary, isBold: true, color: _accentBlue, fontSize: 18),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: _borderColor))),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel', style: TextStyle(color: _textSecondary)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accentBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: _isSaving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Save Salary Structure'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountField(TextEditingController controller, String hint) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      style: const TextStyle(color: _textPrimary, fontSize: 16),
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: _textSecondary),
        prefixText: '₹ ',
        prefixStyle: const TextStyle(color: _accentBlue, fontWeight: FontWeight.bold),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _borderColor)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _accentBlue)),
        filled: true,
        fillColor: const Color(0xFF0D1117),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }

  Widget _buildComponentRow(_ComponentEntry entry, int index, bool isEarning) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: TextField(
              controller: entry.nameController,
              style: const TextStyle(color: _textPrimary, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Component name',
                hintStyle: const TextStyle(color: _textSecondary, fontSize: 12),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _borderColor)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: isEarning ? _accentBlue : Colors.redAccent)),
                filled: true,
                fillColor: const Color(0xFF0D1117),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextField(
              controller: entry.amountController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: _textPrimary, fontSize: 13),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: '₹ 0',
                hintStyle: const TextStyle(color: _textSecondary, fontSize: 12),
                prefixText: '₹ ',
                prefixStyle: TextStyle(color: isEarning ? _accentBlue : Colors.redAccent, fontSize: 12),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _borderColor)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: isEarning ? _accentBlue : Colors.redAccent)),
                filled: true,
                fillColor: const Color(0xFF0D1117),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 20),
            onPressed: () {
              setState(() {
                if (isEarning) {
                  _earnings.removeAt(index);
                } else {
                  _deductions.removeAt(index);
                }
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, double amount, {bool isBold = false, Color? color, double fontSize = 14}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: _textSecondary, fontSize: fontSize - 1, fontWeight: isBold ? FontWeight.w600 : FontWeight.normal)),
          Text(
            _currencyFormat.format(amount),
            style: TextStyle(color: color ?? _textPrimary, fontSize: fontSize, fontWeight: isBold ? FontWeight.bold : FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (_basicPay <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter basic pay'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final earningComponents = _earnings
          .where((e) => e.nameController.text.isNotEmpty && (double.tryParse(e.amountController.text) ?? 0) > 0)
          .map((e) => SalaryComponent(
                name: e.nameController.text.trim(),
                amount: double.tryParse(e.amountController.text) ?? 0,
                type: SalaryComponentType.EARNING,
              ))
          .toList();

      final deductionComponents = _deductions
          .where((d) => d.nameController.text.isNotEmpty && (double.tryParse(d.amountController.text) ?? 0) > 0)
          .map((d) => SalaryComponent(
                name: d.nameController.text.trim(),
                amount: double.tryParse(d.amountController.text) ?? 0,
                type: SalaryComponentType.DEDUCTION,
              ))
          .toList();

      final now = DateTime.now();
      final config = PayrollConfig(
        id: widget.staff.id,
        staffId: widget.staff.id,
        staffName: widget.staff.name,
        employeeId: widget.staff.employeeId,
        basicPay: _basicPay,
        earnings: earningComponents,
        deductions: deductionComponents,
        grossSalary: 0, // Will be recalculated
        totalDeductions: 0,
        netSalary: 0,
        createdAt: widget.existing?.createdAt ?? now,
        updatedAt: now,
        updatedBy: widget.adminUserId,
      );

      final repo = ref.read(payrollRepositoryProvider);
      await repo.savePayrollConfig(widget.schoolId, config);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Salary structure saved for ${widget.staff.name}'), backgroundColor: const Color(0xFF4CAF50)),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

class _ComponentEntry {
  final TextEditingController nameController;
  final TextEditingController amountController;

  _ComponentEntry({required this.nameController, required this.amountController});

  void dispose() {
    nameController.dispose();
    amountController.dispose();
  }
}
