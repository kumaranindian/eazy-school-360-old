import 'dart:typed_data';
import 'dart:html' as html;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/providers/auth_provider.dart';
import '../../shared/widgets/searchable_dropdown.dart';
import '../../shared/pdf/pdf_branding.dart';

// Dark theme colors
const Color _bgDark = Color(0xFF0D1117);
const Color _cardDark = Color(0xFF161B22);
const Color _accentGreen = Color(0xFF4CAF50);
const Color _textPrimary = Color(0xFFE6EDF3);
const Color _textSecondary = Color(0xFF8B949E);
const Color _borderColor = Color(0xFF30363D);

class FinancialReportsScreen extends ConsumerStatefulWidget {
  const FinancialReportsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<FinancialReportsScreen> createState() =>
      _FinancialReportsScreenState();
}

class _FinancialReportsScreenState
    extends ConsumerState<FinancialReportsScreen> {
  bool _isGenerating = false;
  String _statusMessage = '';

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 1024;
    final isTablet = MediaQuery.of(context).size.width > 600;

    return _isGenerating
        ? _buildLoadingState()
        : SingleChildScrollView(
            padding: EdgeInsets.all(isDesktop ? 28 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(isDesktop),
                const SizedBox(height: 24),
                Text('Report Options',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _textPrimary)),
                const SizedBox(height: 16),
                _buildReportGrid(isDesktop, isTablet),
              ],
            ),
          );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(_accentGreen)),
          const SizedBox(height: 16),
          Text(_statusMessage.isEmpty ? 'Generating Report...' : _statusMessage,
              style: const TextStyle(
                  color: _textPrimary,
                  fontWeight: FontWeight.w500,
                  fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDesktop) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.insights_rounded,
                color: Colors.white, size: isDesktop ? 32 : 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Financial Reports',
                    style: TextStyle(
                        fontSize: isDesktop ? 24 : 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                const SizedBox(height: 4),
                Text('Generate and download detailed financial reports',
                    style: TextStyle(
                        fontSize: 14, color: Colors.white.withOpacity(0.9))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportGrid(bool isDesktop, bool isTablet) {
    final reports = [
      {
        'title': 'Class-wise Report',
        'subtitle': 'Fee summary grouped by class',
        'icon': Icons.assessment_rounded,
        'color': const Color(0xFF3B82F6),
        'action': _generateClassWiseReport
      },
      {
        'title': 'Student-wise Report',
        'subtitle': 'Individual student fee details',
        'icon': Icons.people_rounded,
        'color': const Color(0xFF10B981),
        'action': _generateStudentWiseReport
      },
      {
        'title': 'Monthly Report',
        'subtitle': 'Revenue & expense by month',
        'icon': Icons.calendar_month_rounded,
        'color': const Color(0xFFF59E0B),
        'action': _generateMonthlyReport
      },
      {
        'title': 'Expense Report (PDF)',
        'subtitle': 'Detailed expense PDF with filters',
        'icon': Icons.picture_as_pdf_rounded,
        'color': const Color(0xFFEF4444),
        'action': () => _showExpenseFilterDialog(isPdf: true)
      },
      {
        'title': 'Expense Report (Excel)',
        'subtitle': 'Export expenses to spreadsheet',
        'icon': Icons.table_chart_rounded,
        'color': const Color(0xFF8B5CF6),
        'action': () => _showExpenseFilterDialog(isPdf: false)
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isDesktop ? 3 : (isTablet ? 2 : 1),
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: isDesktop ? 2.0 : (isTablet ? 1.8 : 3.0),
      ),
      itemCount: reports.length,
      itemBuilder: (context, index) {
        final r = reports[index];
        return _buildReportCard(
          title: r['title'] as String,
          subtitle: r['subtitle'] as String,
          icon: r['icon'] as IconData,
          color: r['color'] as Color,
          onTap: r['action'] as VoidCallback,
        );
      },
    );
  }

  Widget _buildReportCard(
      {required String title,
      required String subtitle,
      required IconData icon,
      required Color color,
      required VoidCallback onTap}) {
    return Material(
      color: _cardDark,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _borderColor)),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            color: _textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 15)),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: const TextStyle(
                            color: _textSecondary, fontSize: 12)),
                  ],
                ),
              ),
              Icon(Icons.download_rounded, color: color, size: 22),
            ],
          ),
        ),
      ),
    );
  }

  String? get _schoolId => ref.read(currentSessionProvider)?.schoolId;

  // ============ CLASS-WISE REPORT (EXCEL) ============
  Future<void> _generateClassWiseReport() async {
    if (_schoolId == null) return;
    setState(() {
      _isGenerating = true;
      _statusMessage = 'Fetching student fee data...';
    });

    try {
      // Query student fee ledgers (new system)
      // Note: Using simple orderBy to avoid composite index requirement
      final ledgerSnap = await FirebaseFirestore.instance
          .collection('schools')
          .doc(_schoolId)
          .collection('studentFeeLedgers')
          .orderBy('className')
          .get();

      // Filter out archived ledgers client-side
      final activeLedgers = ledgerSnap.docs.where((doc) {
        final data = doc.data();
        return data['isArchived'] != true;
      }).toList();

      // Query fee structures V2 (new system)
      final feeStructSnap = await FirebaseFirestore.instance
          .collection('schools')
          .doc(_schoolId)
          .collection('feeStructuresV2')
          .where('isActive', isEqualTo: true)
          .get();

      final feeStructMap = <String, Map<String, dynamic>>{};
      for (final doc in feeStructSnap.docs) {
        final d = doc.data();
        // Map by class names in applicableToClassIds
        final classIds = (d['applicableToClassIds'] as List?) ?? [];
        for (final classId in classIds) {
          feeStructMap[classId.toString()] = d;
        }
      }

      final excel = Excel.createExcel();
      final sheet = excel['ClassWiseReport'];
      int row = 0;

      // Header
      final headers = [
        'Class',
        'Students',
        'Total Assigned',
        'Total Paid',
        'Total Pending',
        'Total Overdue',
        'Late Fees'
      ];
      for (int c = 0; c < headers.length; c++) {
        sheet
            .cell(CellIndex.indexByColumnRow(rowIndex: row, columnIndex: c))
            .value = TextCellValue(headers[c]);
      }
      row++;

      // Group by class
      final classGroups = <String, List<Map<String, dynamic>>>{};
      for (final doc in activeLedgers) {
        final d = doc.data();
        final String cn = (d['className'] ?? 'Unknown').toString();
        classGroups.putIfAbsent(cn, () => []).add(d);
      }

      for (final entry in classGroups.entries) {
        final className = entry.key;
        final students = entry.value;

        double totalAssigned = 0,
            totalPaid = 0,
            totalPending = 0,
            totalOverdue = 0,
            totalLateFee = 0;

        for (final s in students) {
          totalAssigned += (s['totalAssigned'] as num?)?.toDouble() ?? 0;
          totalPaid += (s['totalPaid'] as num?)?.toDouble() ?? 0;
          totalPending += (s['totalPending'] as num?)?.toDouble() ?? 0;
          totalOverdue += (s['totalOverdue'] as num?)?.toDouble() ?? 0;
          totalLateFee += (s['totalLateFee'] as num?)?.toDouble() ?? 0;
        }

        sheet
            .cell(CellIndex.indexByColumnRow(rowIndex: row, columnIndex: 0))
            .value = TextCellValue(className);
        sheet
            .cell(CellIndex.indexByColumnRow(rowIndex: row, columnIndex: 1))
            .value = IntCellValue(students.length);
        sheet
            .cell(CellIndex.indexByColumnRow(rowIndex: row, columnIndex: 2))
            .value = DoubleCellValue(totalAssigned);
        sheet
            .cell(CellIndex.indexByColumnRow(rowIndex: row, columnIndex: 3))
            .value = DoubleCellValue(totalPaid);
        sheet
            .cell(CellIndex.indexByColumnRow(rowIndex: row, columnIndex: 4))
            .value = DoubleCellValue(totalPending);
        sheet
            .cell(CellIndex.indexByColumnRow(rowIndex: row, columnIndex: 5))
            .value = DoubleCellValue(totalOverdue);
        sheet
            .cell(CellIndex.indexByColumnRow(rowIndex: row, columnIndex: 6))
            .value = DoubleCellValue(totalLateFee);
        row++;
      }

      final bytes = excel.save();
      if (bytes != null) {
        _downloadFile(
            Uint8List.fromList(bytes),
            'ClassWise_Report_${DateFormat('yyyyMMdd').format(DateTime.now())}.xlsx',
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      }
      _showSuccess('Class-wise report downloaded!');
    } catch (e) {
      _showError('Failed to generate report: $e');
    } finally {
      setState(() => _isGenerating = false);
    }
  }

  // ============ STUDENT-WISE REPORT (EXCEL) ============
  Future<void> _generateStudentWiseReport() async {
    if (_schoolId == null) return;
    setState(() {
      _isGenerating = true;
      _statusMessage = 'Fetching student data...';
    });

    try {
      // Query student fee ledgers (new system)
      // Note: Using simple orderBy to avoid composite index requirement
      final snap = await FirebaseFirestore.instance
          .collection('schools')
          .doc(_schoolId)
          .collection('studentFeeLedgers')
          .orderBy('className')
          .get();

      // Filter out archived ledgers and sort by studentName client-side
      final activeDocs = snap.docs.where((doc) {
        final data = doc.data();
        return data['isArchived'] != true;
      }).toList();
      activeDocs.sort((a, b) {
        final classA = (a.data()['className'] ?? '').toString();
        final classB = (b.data()['className'] ?? '').toString();
        final cmp = classA.compareTo(classB);
        if (cmp != 0) return cmp;
        final nameA = (a.data()['studentName'] ?? '').toString();
        final nameB = (b.data()['studentName'] ?? '').toString();
        return nameA.compareTo(nameB);
      });

      final excel = Excel.createExcel();
      final sheet = excel['StudentWiseReport'];
      int row = 0;

      final headers = [
        'ID',
        'Name',
        'Class',
        'Section',
        'Total Assigned',
        'Total Paid',
        'Total Pending',
        'Total Overdue',
        'Late Fees',
        'Fee Structure'
      ];
      for (int c = 0; c < headers.length; c++) {
        sheet
            .cell(CellIndex.indexByColumnRow(rowIndex: row, columnIndex: c))
            .value = TextCellValue(headers[c]);
      }
      row++;

      for (final doc in activeDocs) {
        final d = doc.data();
        sheet
            .cell(CellIndex.indexByColumnRow(rowIndex: row, columnIndex: 0))
            .value = TextCellValue(d['studentId']?.toString() ?? '');
        sheet
            .cell(CellIndex.indexByColumnRow(rowIndex: row, columnIndex: 1))
            .value = TextCellValue((d['studentName'] ?? '').toString());
        sheet
            .cell(CellIndex.indexByColumnRow(rowIndex: row, columnIndex: 2))
            .value = TextCellValue((d['className'] ?? '').toString());
        sheet
            .cell(CellIndex.indexByColumnRow(rowIndex: row, columnIndex: 3))
            .value = TextCellValue((d['section'] ?? '').toString());
        sheet
                .cell(CellIndex.indexByColumnRow(rowIndex: row, columnIndex: 4))
                .value =
            DoubleCellValue((d['totalAssigned'] as num?)?.toDouble() ?? 0.0);
        sheet
                .cell(CellIndex.indexByColumnRow(rowIndex: row, columnIndex: 5))
                .value =
            DoubleCellValue((d['totalPaid'] as num?)?.toDouble() ?? 0.0);
        sheet
                .cell(CellIndex.indexByColumnRow(rowIndex: row, columnIndex: 6))
                .value =
            DoubleCellValue((d['totalPending'] as num?)?.toDouble() ?? 0.0);
        sheet
                .cell(CellIndex.indexByColumnRow(rowIndex: row, columnIndex: 7))
                .value =
            DoubleCellValue((d['totalOverdue'] as num?)?.toDouble() ?? 0.0);
        sheet
                .cell(CellIndex.indexByColumnRow(rowIndex: row, columnIndex: 8))
                .value =
            DoubleCellValue((d['totalLateFee'] as num?)?.toDouble() ?? 0.0);
        sheet
            .cell(CellIndex.indexByColumnRow(rowIndex: row, columnIndex: 9))
            .value = TextCellValue((d['feeStructureName'] ?? '').toString());
        row++;
      }

      final bytes = excel.save();
      if (bytes != null) {
        _downloadFile(
            Uint8List.fromList(bytes),
            'StudentWise_Report_${DateFormat('yyyyMMdd').format(DateTime.now())}.xlsx',
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      }
      _showSuccess('Student-wise report downloaded!');
    } catch (e) {
      _showError('Failed to generate report: $e');
    } finally {
      setState(() => _isGenerating = false);
    }
  }

  // ============ MONTHLY REPORT (EXCEL) ============
  Future<void> _generateMonthlyReport() async {
    if (_schoolId == null) return;
    setState(() {
      _isGenerating = true;
      _statusMessage = 'Fetching monthly data...';
    });

    try {
      final now = DateTime.now();
      final startOfYear = DateTime(now.year, 1, 1);
      // Query bills ordered by billDate only to avoid composite index requirement
      final billsSnap = await FirebaseFirestore.instance
          .collection('schools')
          .doc(_schoolId)
          .collection('bills')
          .orderBy('billDate')
          .get();

      // Filter client-side for isDeleted and date range
      final filteredBills = billsSnap.docs.where((doc) {
        final d = doc.data();
        if (d['isDeleted'] == true) return false;
        final billDate = (d['billDate'] as Timestamp?)?.toDate();
        if (billDate == null) return false;
        return billDate.isAfter(startOfYear) ||
            billDate.isAtSameMomentAs(startOfYear);
      }).toList();

      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ];
      final monthlyRevenue = List.filled(12, 0.0);
      final monthlyExpense = List.filled(12, 0.0);

      for (final doc in filteredBills) {
        final d = doc.data();
        final date = (d['billDate'] as Timestamp?)?.toDate();
        if (date == null) continue;
        final monthIdx = date.month - 1;
        if (d['billType'] == 'Revenue') {
          monthlyRevenue[monthIdx] +=
              (d['revenueAmount'] as num?)?.toDouble() ?? 0;
        } else if (d['billType'] == 'Expense') {
          monthlyExpense[monthIdx] +=
              (d['expenseAmount'] as num?)?.toDouble() ?? 0;
        }
      }

      final excel = Excel.createExcel();
      final sheet = excel['MonthlyReport'];

      sheet
          .cell(CellIndex.indexByColumnRow(rowIndex: 0, columnIndex: 0))
          .value = TextCellValue('Month');
      sheet
          .cell(CellIndex.indexByColumnRow(rowIndex: 0, columnIndex: 1))
          .value = TextCellValue('Revenue');
      sheet
          .cell(CellIndex.indexByColumnRow(rowIndex: 0, columnIndex: 2))
          .value = TextCellValue('Expense');
      sheet
          .cell(CellIndex.indexByColumnRow(rowIndex: 0, columnIndex: 3))
          .value = TextCellValue('Net');

      for (int i = 0; i < 12; i++) {
        sheet
            .cell(CellIndex.indexByColumnRow(rowIndex: i + 1, columnIndex: 0))
            .value = TextCellValue('${months[i]} ${now.year}');
        sheet
            .cell(CellIndex.indexByColumnRow(rowIndex: i + 1, columnIndex: 1))
            .value = DoubleCellValue(monthlyRevenue[i]);
        sheet
            .cell(CellIndex.indexByColumnRow(rowIndex: i + 1, columnIndex: 2))
            .value = DoubleCellValue(monthlyExpense[i]);
        sheet
            .cell(CellIndex.indexByColumnRow(rowIndex: i + 1, columnIndex: 3))
            .value = DoubleCellValue(monthlyRevenue[i] - monthlyExpense[i]);
      }

      final bytes = excel.save();
      if (bytes != null) {
        _downloadFile(
            Uint8List.fromList(bytes),
            'Monthly_Report_${now.year}.xlsx',
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      }
      _showSuccess('Monthly report downloaded!');
    } catch (e) {
      _showError('Failed to generate report: $e');
    } finally {
      setState(() => _isGenerating = false);
    }
  }

  // ============ EXPENSE REPORT FILTER DIALOG ============
  void _showExpenseFilterDialog({required bool isPdf}) {
    final now = DateTime.now();
    DateTime startDate = DateTime(now.year, now.month, 1);
    DateTime endDate = now;
    bool includeMissed = false;
    String selectedRange = 'This Month';

    void updateRange(String range) {
      switch (range) {
        case 'This Week':
          startDate = now.subtract(Duration(days: now.weekday - 1));
          endDate = startDate.add(const Duration(days: 6));
          break;
        case 'This Month':
          startDate = DateTime(now.year, now.month, 1);
          endDate = DateTime(now.year, now.month + 1, 0);
          break;
        case 'This Quarter':
          final q = ((now.month - 1) ~/ 3);
          startDate = DateTime(now.year, q * 3 + 1, 1);
          endDate = DateTime(now.year, (q + 1) * 3 + 1, 0);
          break;
        case 'This Fiscal Year':
          startDate = DateTime(now.year, 4, 1);
          endDate = DateTime(now.year + 1, 3, 31);
          break;
      }
    }

    updateRange(selectedRange);

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: _cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 440),
          padding: const EdgeInsets.all(24),
          child: StatefulBuilder(
            builder: (ctx, setDlgState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                            color: _accentGreen.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.filter_alt_rounded,
                            color: _accentGreen, size: 20)),
                    const SizedBox(width: 12),
                    Text('Filter ${isPdf ? "PDF" : "Excel"} Report',
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _textPrimary)),
                  ]),
                  const SizedBox(height: 20),
                  const Text('Date Range',
                      style: TextStyle(
                          color: _textSecondary, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  SearchableDropdown<String>(
                    value: selectedRange,
                    items: const [
                      'This Week',
                      'This Month',
                      'This Quarter',
                      'This Fiscal Year',
                      'Custom'
                    ],
                    itemLabel: (v) => v,
                    hint: 'Select date range',
                    onChanged: (v) {
                      if (v == null) return;
                      setDlgState(() {
                        selectedRange = v;
                        if (v != 'Custom') updateRange(v);
                      });
                    },
                  ),
                  if (selectedRange == 'Custom') ...[
                    const SizedBox(height: 12),
                    _buildDateField('From', startDate,
                        (d) => setDlgState(() => startDate = d)),
                    const SizedBox(height: 8),
                    _buildDateField(
                        'To', endDate, (d) => setDlgState(() => endDate = d)),
                  ],
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                        color: _bgDark,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _borderColor)),
                    child: CheckboxListTile(
                      title: const Text('Include Missed Bills',
                          style: TextStyle(color: _textPrimary, fontSize: 14)),
                      value: includeMissed,
                      activeColor: _accentGreen,
                      onChanged: (v) =>
                          setDlgState(() => includeMissed = v ?? false),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel',
                              style: TextStyle(color: _textSecondary))),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: _accentGreen,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10))),
                        onPressed: () {
                          Navigator.pop(ctx);
                          if (isPdf) {
                            _generateExpensePdf(
                                startDate, endDate, includeMissed);
                          } else {
                            _generateExpenseExcel(
                                startDate, endDate, includeMissed);
                          }
                        },
                        child: const Text('Generate Report'),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildDateField(
      String label, DateTime date, Function(DateTime) onPicked) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
          builder: (ctx, child) => Theme(
              data: ThemeData.dark().copyWith(
                  colorScheme: const ColorScheme.dark(
                      primary: _accentGreen, surface: _cardDark)),
              child: child!),
        );
        if (picked != null) onPicked(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
            color: _bgDark,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _borderColor)),
        child: Row(children: [
          const Icon(Icons.calendar_today_rounded,
              size: 18, color: _accentGreen),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: const TextStyle(fontSize: 11, color: _textSecondary)),
            const SizedBox(height: 2),
            Text(DateFormat('dd MMM yyyy').format(date),
                style: const TextStyle(
                    color: _textPrimary, fontWeight: FontWeight.w500)),
          ]),
        ]),
      ),
    );
  }

  // ============ EXPENSE REPORT PDF ============
  Future<void> _generateExpensePdf(
      DateTime start, DateTime end, bool includeMissed) async {
    if (_schoolId == null) return;
    setState(() {
      _isGenerating = true;
      _statusMessage = 'Generating expense PDF...';
    });

    try {
      Query<Map<String, dynamic>> query = FirebaseFirestore.instance
          .collection('schools')
          .doc(_schoolId)
          .collection('bills')
          .where('billType', isEqualTo: 'Expense')
          .where('isDeleted', isEqualTo: false)
          .where('billDate', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('billDate',
              isLessThanOrEqualTo:
                  Timestamp.fromDate(end.add(const Duration(days: 1))))
          .orderBy('billDate', descending: true);

      final snap = await query.get();
      var expenses = snap.docs.map((d) => d.data()).toList();

      if (!includeMissed) {
        expenses = expenses
            .where((e) => (e['isMissedExpense'] ?? 'No') != 'Yes')
            .toList();
      }

      final branding = await PdfBranding.forSchool(_schoolId!);
      final pdf = pw.Document();
      final summaryMap = <String, double>{};
      double grandTotal = 0;

      for (final e in expenses) {
        final type = (e['expenseType'] ?? 'Other') as String;
        final amt = (e['expenseAmount'] as num?)?.toDouble() ?? 0;
        summaryMap[type] = (summaryMap[type] ?? 0) + amt;
        grandTotal += amt;
      }

      // Data page
      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        header: (ctx) => PdfBranding.buildHeader(
          branding,
          title: 'Expense Report',
          subtitle:
              '${DateFormat('dd MMM yyyy').format(start)} - ${DateFormat('dd MMM yyyy').format(end)}',
          showLogo: false,
        ),
        footer: (ctx) => PdfBranding.buildFooter(branding, ctx),
        build: (ctx) => [
          pw.TableHelper.fromTextArray(
            headerStyle:
                pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
            cellStyle: const pw.TextStyle(fontSize: 9),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            headers: [
              'Bill ID',
              'Date',
              'Type',
              'Amount',
              'POC',
              'Description'
            ],
            data: expenses
                .map((e) => [
                      (e['billId'] ?? '').toString(),
                      DateFormat('dd/MM/yyyy').format(
                          (e['billDate'] as Timestamp?)?.toDate() ??
                              DateTime.now()),
                      (e['expenseType'] ?? '').toString(),
                      'Rs${((e['expenseAmount'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)}',
                      (e['expensePOC'] ?? '').toString(),
                      (e['expenseDesc'] ?? '').toString(),
                    ])
                .toList(),
          ),
          pw.SizedBox(height: 16),
          pw.Container(
              alignment: pw.Alignment.centerRight,
              child: pw.Text('Grand Total: Rs${grandTotal.toStringAsFixed(2)}',
                  style: pw.TextStyle(
                      fontSize: 14, fontWeight: pw.FontWeight.bold))),
        ],
      ));

      // Summary page
      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        header: (ctx) => PdfBranding.buildHeader(
          branding,
          title: 'Expense Summary',
          subtitle:
              '${DateFormat('dd MMM yyyy').format(start)} - ${DateFormat('dd MMM yyyy').format(end)}',
          showLogo: false,
        ),
        footer: (ctx) => PdfBranding.buildFooter(branding, ctx),
        build: (ctx) => [
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            headers: ['Expense Type', 'Total Amount'],
            data: summaryMap.entries
                .map((e) => [e.key, 'Rs${e.value.toStringAsFixed(2)}'])
                .toList(),
          ),
          pw.SizedBox(height: 12),
          pw.Container(
              alignment: pw.Alignment.centerRight,
              child: pw.Text('Grand Total: Rs${grandTotal.toStringAsFixed(2)}',
                  style: pw.TextStyle(
                      fontSize: 16, fontWeight: pw.FontWeight.bold))),
        ],
      ));

      final pdfBytes = await pdf.save();
      _downloadFile(
          pdfBytes,
          'Expense_Report_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
          'application/pdf');
      _showSuccess('Expense PDF downloaded!');
    } catch (e) {
      _showError('Failed: $e');
    } finally {
      setState(() => _isGenerating = false);
    }
  }

  // ============ EXPENSE REPORT EXCEL ============
  Future<void> _generateExpenseExcel(
      DateTime start, DateTime end, bool includeMissed) async {
    if (_schoolId == null) return;
    setState(() {
      _isGenerating = true;
      _statusMessage = 'Generating expense Excel...';
    });

    try {
      final snap = await FirebaseFirestore.instance
          .collection('schools')
          .doc(_schoolId)
          .collection('bills')
          .where('billType', isEqualTo: 'Expense')
          .where('isDeleted', isEqualTo: false)
          .where('billDate', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('billDate',
              isLessThanOrEqualTo:
                  Timestamp.fromDate(end.add(const Duration(days: 1))))
          .orderBy('billDate', descending: true)
          .get();

      var expenses = snap.docs.map((d) => d.data()).toList();
      if (!includeMissed) {
        expenses = expenses
            .where((e) => (e['isMissedExpense'] ?? 'No') != 'Yes')
            .toList();
      }

      final excel = Excel.createExcel();
      final sheet = excel['Expenses'];
      int row = 0;

      final headers = [
        'Bill ID',
        'Date',
        'Type',
        'Amount',
        'POC',
        'Description',
        'Remarks',
        'Missed'
      ];
      for (int c = 0; c < headers.length; c++) {
        sheet
            .cell(CellIndex.indexByColumnRow(rowIndex: row, columnIndex: c))
            .value = TextCellValue(headers[c]);
      }
      row++;

      for (final e in expenses) {
        sheet
            .cell(CellIndex.indexByColumnRow(rowIndex: row, columnIndex: 0))
            .value = IntCellValue((e['billId'] as num?)?.toInt() ?? 0);
        sheet
                .cell(CellIndex.indexByColumnRow(rowIndex: row, columnIndex: 1))
                .value =
            TextCellValue(DateFormat('dd/MM/yyyy').format(
                (e['billDate'] as Timestamp?)?.toDate() ?? DateTime.now()));
        sheet
            .cell(CellIndex.indexByColumnRow(rowIndex: row, columnIndex: 2))
            .value = TextCellValue((e['expenseType'] ?? '').toString());
        sheet
                .cell(CellIndex.indexByColumnRow(rowIndex: row, columnIndex: 3))
                .value =
            DoubleCellValue((e['expenseAmount'] as num?)?.toDouble() ?? 0);
        sheet
            .cell(CellIndex.indexByColumnRow(rowIndex: row, columnIndex: 4))
            .value = TextCellValue((e['expensePOC'] ?? '').toString());
        sheet
            .cell(CellIndex.indexByColumnRow(rowIndex: row, columnIndex: 5))
            .value = TextCellValue((e['expenseDesc'] ?? '').toString());
        sheet
            .cell(CellIndex.indexByColumnRow(rowIndex: row, columnIndex: 6))
            .value = TextCellValue((e['remarks'] ?? '').toString());
        sheet
            .cell(CellIndex.indexByColumnRow(rowIndex: row, columnIndex: 7))
            .value = TextCellValue((e['isMissedExpense'] ?? 'No').toString());
        row++;
      }

      final bytes = excel.save();
      if (bytes != null) {
        _downloadFile(
            Uint8List.fromList(bytes),
            'Expense_Report_${DateFormat('yyyyMMdd').format(DateTime.now())}.xlsx',
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      }
      _showSuccess('Expense Excel downloaded!');
    } catch (e) {
      _showError('Failed: $e');
    } finally {
      setState(() => _isGenerating = false);
    }
  }

  // ============ HELPERS ============
  void _downloadFile(Uint8List bytes, String fileName, String mimeType) {
    final blob = html.Blob([bytes], mimeType);
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  void _showSuccess(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: _accentGreen,
        behavior: SnackBarBehavior.floating));
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating));
  }
}
