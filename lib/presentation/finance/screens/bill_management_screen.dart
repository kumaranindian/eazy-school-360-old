import 'dart:typed_data';
import 'dart:html' as html;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/providers/auth_provider.dart';
import '../../shared/widgets/searchable_dropdown.dart';
import '../../shared/pdf/pdf_branding.dart';

const Color _bgDark = Color(0xFF0D1117);
const Color _cardDark = Color(0xFF161B22);
const Color _accentGreen = Color(0xFF4CAF50);
const Color _textPrimary = Color(0xFFE6EDF3);
const Color _textSecondary = Color(0xFF8B949E);
const Color _borderColor = Color(0xFF30363D);

class BillManagementScreen extends ConsumerStatefulWidget {
  const BillManagementScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<BillManagementScreen> createState() => _BillManagementScreenState();
}

class _BillManagementScreenState extends ConsumerState<BillManagementScreen> {
  // Default to the current week (Monday → Sunday) so the view is focused
  // on recent activity instead of the entire year.
  DateTime _startDate = _startOfCurrentWeek();
  DateTime _endDate = _endOfCurrentWeek();
  String _filterType = 'Both';
  String _quickRange = 'week'; // 'today' | 'week' | 'month' | 'year' | 'custom'
  List<Map<String, dynamic>> _bills = [];
  bool _isLoading = false;
  String? _schoolId;

  @override
  void initState() {
    super.initState();
    loadPdfUnicodeFont(); // Load global Unicode font
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _schoolId = ref.read(currentSessionProvider)?.schoolId;
      if (_schoolId != null) _fetchBills();
    });
  }

  static DateTime _startOfCurrentWeek() {
    final now = DateTime.now();
    // DateTime.weekday: Monday = 1 ... Sunday = 7
    final monday = now.subtract(Duration(days: now.weekday - 1));
    return DateTime(monday.year, monday.month, monday.day);
  }

  static DateTime _endOfCurrentWeek() {
    final monday = _startOfCurrentWeek();
    final sunday = monday.add(const Duration(days: 6));
    return DateTime(sunday.year, sunday.month, sunday.day, 23, 59, 59);
  }

  Future<void> _fetchBills() async {
    if (_schoolId == null) return;
    setState(() => _isLoading = true);

    try {
      // Fetch ALL bills (including deleted) so we can show them with a highlight
      Query<Map<String, dynamic>> query = FirebaseFirestore.instance
          .collection('schools').doc(_schoolId).collection('bills')
          .orderBy('billDate', descending: true);

      if (_filterType == 'Revenue') {
        query = FirebaseFirestore.instance
            .collection('schools').doc(_schoolId).collection('bills')
            .where('billType', isEqualTo: 'Revenue')
            .orderBy('billDate', descending: true);
      } else if (_filterType == 'Expense') {
        query = FirebaseFirestore.instance
            .collection('schools').doc(_schoolId).collection('bills')
            .where('billType', isEqualTo: 'Expense')
            .orderBy('billDate', descending: true);
      }

      final snap = await query.get();
      final bills = <Map<String, dynamic>>[];
      // Normalize the filter window so the whole first day and the whole
      // last day are always included, regardless of the time component on the
      // stored billDate timestamps.
      final rangeStart = DateTime(_startDate.year, _startDate.month, _startDate.day);
      final rangeEnd = DateTime(_endDate.year, _endDate.month, _endDate.day, 23, 59, 59, 999);
      for (final doc in snap.docs) {
        final d = doc.data();
        d['docId'] = doc.id;
        final billDate = (d['billDate'] as Timestamp?)?.toDate() ??
            (d['paymentDate'] as Timestamp?)?.toDate() ??
            (d['createdAt'] as Timestamp?)?.toDate();
        if (billDate == null) continue;
        if (!billDate.isBefore(rangeStart) && !billDate.isAfter(rangeEnd)) {
          bills.add(d);
        }
      }
      setState(() { _bills = bills; _isLoading = false; });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 1024;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isDesktop ? 28 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 20),
          _buildFilterBar(isDesktop),
          const SizedBox(height: 16),
          _buildActionBar(),
          const SizedBox(height: 16),
          _isLoading ? const Center(child: CircularProgressIndicator(color: _accentGreen)) : _buildBillsTable(isDesktop),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 28)),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Bill Management', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
          Text('View and manage bills', style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.9))),
        ])),
        Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
          child: Text('${_bills.length} records', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
        ),
      ]),
    );
  }

  void _applyQuickRange(String key) {
    final now = DateTime.now();
    DateTime start = _startDate;
    DateTime end = _endDate;
    switch (key) {
      case 'today':
        start = DateTime(now.year, now.month, now.day);
        end = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      case 'week':
        start = _startOfCurrentWeek();
        end = _endOfCurrentWeek();
        break;
      case 'month':
        start = DateTime(now.year, now.month, 1);
        final lastDay = DateTime(now.year, now.month + 1, 0);
        end = DateTime(lastDay.year, lastDay.month, lastDay.day, 23, 59, 59);
        break;
      case 'year':
        start = DateTime(now.year, 1, 1);
        end = DateTime(now.year, 12, 31, 23, 59, 59);
        break;
      case 'custom':
        // Keep current dates; just enable the pickers
        setState(() => _quickRange = 'custom');
        return;
    }
    setState(() {
      _quickRange = key;
      _startDate = start;
      _endDate = end;
    });
    _fetchBills();
  }

  Widget _buildFilterBar(bool isDesktop) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _cardDark, borderRadius: BorderRadius.circular(12), border: Border.all(color: _borderColor)),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Icon(Icons.filter_list_rounded, color: _accentGreen, size: 20),
          const Text('Filter', style: TextStyle(color: _textPrimary, fontWeight: FontWeight.bold)),
          _buildQuickChip('Today', 'today'),
          _buildQuickChip('This Week', 'week'),
          _buildQuickChip('This Month', 'month'),
          _buildQuickChip('This Year', 'year'),
          _buildQuickChip('Custom', 'custom'),
          _buildDateButton('From', _startDate, (d) => setState(() => _startDate = d),
              enabled: _quickRange == 'custom'),
          _buildDateButton('To', _endDate, (d) => setState(() => _endDate = d),
              enabled: _quickRange == 'custom'),
          _buildTypeDropdown(),
          ElevatedButton.icon(
            icon: const Icon(Icons.search_rounded, size: 18),
            label: const Text('Apply Filter'),
            style: ElevatedButton.styleFrom(backgroundColor: _accentGreen, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: _fetchBills,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickChip(String label, String key) {
    final selected = _quickRange == key;
    return InkWell(
      onTap: () => _applyQuickRange(key),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? _accentGreen.withValues(alpha: 0.15) : _bgDark,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? _accentGreen : _borderColor),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? _accentGreen : _textSecondary,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildDateButton(String label, DateTime date, Function(DateTime) onPicked,
      {bool enabled = true}) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: InkWell(
        onTap: enabled
            ? () async {
                final picked = await showDatePicker(
                    context: context,
                    initialDate: date,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                    builder: (ctx, child) => Theme(
                        data: ThemeData.dark().copyWith(
                            colorScheme: const ColorScheme.dark(
                                primary: _accentGreen, surface: _cardDark)),
                        child: child!));
                if (picked != null) {
                  onPicked(picked);
                }
              }
            : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
              color: _bgDark,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _borderColor)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(
                enabled ? Icons.calendar_today_rounded : Icons.lock_outline_rounded,
                size: 14,
                color: enabled ? _accentGreen : _textSecondary),
            const SizedBox(width: 8),
            Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label,
                      style: const TextStyle(fontSize: 10, color: _textSecondary)),
                  Text(DateFormat('yyyy-MM-dd').format(date),
                      style: const TextStyle(color: _textPrimary, fontSize: 13)),
                ]),
          ]),
        ),
      ),
    );
  }

  Widget _buildTypeDropdown() {
    return SizedBox(
      width: 140,
      child: SearchableDropdown<String>(
        value: _filterType,
        items: const ['Both', 'Revenue', 'Expense'],
        itemLabel: (v) => v,
        hint: 'Type',
        onChanged: (v) { if (v != null) setState(() => _filterType = v); },
      ),
    );
  }

  Widget _buildActionBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        ElevatedButton.icon(
          icon: const Icon(Icons.print_rounded, size: 16),
          label: const Text('Print All'),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B82F6), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
          onPressed: _bills.isEmpty ? null : _printAllBills,
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          icon: const Icon(Icons.download_rounded, size: 16),
          label: const Text('Export CSV'),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
          onPressed: _bills.isEmpty ? null : _exportCsv,
        ),
      ],
    );
  }

  Widget _buildBillsTable(bool isDesktop) {
    if (_bills.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(color: _cardDark, borderRadius: BorderRadius.circular(12), border: Border.all(color: _borderColor)),
        child: const Center(child: Text('No bills found for the selected filters.', style: TextStyle(color: _textSecondary, fontSize: 15))),
      );
    }

    return Container(
      decoration: BoxDecoration(color: _cardDark, borderRadius: BorderRadius.circular(12), border: Border.all(color: _borderColor)),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(_bgDark),
          dataRowColor: WidgetStateProperty.all(_cardDark),
          dividerThickness: 0.5,
          columns: const [
            DataColumn(label: Text('Bill ID', style: TextStyle(color: _accentGreen, fontWeight: FontWeight.bold, fontSize: 12))),
            DataColumn(label: Text('Date', style: TextStyle(color: _accentGreen, fontWeight: FontWeight.bold, fontSize: 12))),
            DataColumn(label: Text('Type', style: TextStyle(color: _accentGreen, fontWeight: FontWeight.bold, fontSize: 12))),
            DataColumn(label: Text('Sub Type', style: TextStyle(color: _accentGreen, fontWeight: FontWeight.bold, fontSize: 12))),
            DataColumn(label: Text('Student ID', style: TextStyle(color: _accentGreen, fontWeight: FontWeight.bold, fontSize: 12))),
            DataColumn(label: Text('Name', style: TextStyle(color: _accentGreen, fontWeight: FontWeight.bold, fontSize: 12))),
            DataColumn(label: Text('Amount', style: TextStyle(color: _accentGreen, fontWeight: FontWeight.bold, fontSize: 12))),
            DataColumn(label: Text('Actions', style: TextStyle(color: _accentGreen, fontWeight: FontWeight.bold, fontSize: 12))),
          ],
          rows: _bills.map((b) {
            final billType = (b['billType'] ?? '').toString();
            final isRevenue = billType == 'Revenue';
            final isDeleted = b['isDeleted'] == true;
            final amount = isRevenue
                ? (b['revenueAmount'] as num?)?.toDouble() ?? 0
                : (b['expenseAmount'] as num?)?.toDouble() ?? 0;
            final subType = isRevenue
                ? (b['revenueType'] ?? '').toString()
                : (b['expenseType'] ?? '').toString();
            final date = (b['billDate'] as Timestamp?)?.toDate();
            final deletionReason = (b['deletionReason'] ?? '').toString();

            final rowTextStyle = TextStyle(
              color: isDeleted ? _textSecondary.withOpacity(0.5) : _textPrimary,
              fontSize: 12,
              decoration: isDeleted ? TextDecoration.lineThrough : null,
            );

            return DataRow(
              color: isDeleted ? WidgetStateProperty.all(const Color(0xFFEF4444).withOpacity(0.06)) : null,
              cells: [
                DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('${b['billId'] ?? ''}', style: rowTextStyle),
                  if (isDeleted) ...[
                    const SizedBox(width: 6),
                    Tooltip(
                      message: deletionReason.isNotEmpty ? 'Deleted: $deletionReason' : 'Deleted',
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(color: const Color(0xFFEF4444).withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                        child: const Text('DELETED', style: TextStyle(color: Color(0xFFEF4444), fontSize: 8, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ])),
                DataCell(Text(date != null ? DateFormat('dd/MM/yyyy').format(date) : '', style: rowTextStyle)),
                DataCell(Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isDeleted
                        ? Colors.grey.withOpacity(0.1)
                        : isRevenue ? const Color(0xFF10B981).withOpacity(0.15) : const Color(0xFFEF4444).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(billType, style: TextStyle(
                    color: isDeleted ? _textSecondary.withOpacity(0.5) : isRevenue ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                    fontSize: 11, fontWeight: FontWeight.bold,
                    decoration: isDeleted ? TextDecoration.lineThrough : null,
                  )),
                )),
                DataCell(Text(subType, style: TextStyle(color: isDeleted ? _textSecondary.withOpacity(0.4) : _textSecondary, fontSize: 12, decoration: isDeleted ? TextDecoration.lineThrough : null))),
                DataCell(Text((b['stuId'] ?? 'NA').toString(), style: rowTextStyle)),
                DataCell(Text((b['stuName'] ?? (b['expensePOC'] ?? '')).toString(), style: rowTextStyle)),
                DataCell(Text('₹${amount.toStringAsFixed(2)}', style: TextStyle(
                  color: isDeleted ? _textSecondary.withOpacity(0.5) : isRevenue ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                  fontWeight: FontWeight.bold, fontSize: 12,
                  decoration: isDeleted ? TextDecoration.lineThrough : null,
                ))),
                DataCell(isDeleted
                    ? Tooltip(message: deletionReason.isNotEmpty ? deletionReason : 'Deleted', child: const Icon(Icons.info_outline, color: _textSecondary, size: 16))
                    : Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(icon: const Icon(Icons.print_rounded, color: Color(0xFF3B82F6), size: 18), tooltip: 'Print', onPressed: () => _printSingleBill(b)),
                        IconButton(icon: const Icon(Icons.delete_rounded, color: Color(0xFFEF4444), size: 18), tooltip: 'Delete', onPressed: () => _confirmDeleteBill(b)),
                      ])),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  // ============ PRINT SINGLE BILL ============
  Future<void> _printSingleBill(Map<String, dynamic> bill) async {
    if (_schoolId == null) return;
    final branding = await PdfBranding.forSchool(_schoolId!);
    final pdf = pw.Document();
    final isRevenue = (bill['billType'] ?? '') == 'Revenue';
    final amount = isRevenue ? (bill['revenueAmount'] as num?)?.toDouble() ?? 0 : (bill['expenseAmount'] as num?)?.toDouble() ?? 0;
    final date = (bill['billDate'] as Timestamp?)?.toDate() ?? DateTime.now();
    final ay = (bill['academicYear'] ?? '').toString();
    final origAy = (bill['originatingAcademicYear'] ?? '').toString();
    final origClass = (bill['originatingClass'] ?? '').toString();
    final schoolName = branding.schoolName.isNotEmpty ? branding.schoolName : 'School';
    final schoolAddr = branding.schoolAddress;
    final schoolPhone = branding.schoolPhone;

    // Build one receipt copy as a list of widgets
    pw.Widget buildReceiptCopy(String copyLabel) {
      final bold = pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10);
      const normal = pw.TextStyle(fontSize: 9);
      const small = pw.TextStyle(fontSize: 8);
      return pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // School name + copy label
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text(schoolName, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                if (schoolAddr.isNotEmpty) pw.Text(schoolAddr, style: small),
                if (schoolPhone.isNotEmpty) pw.Text('Ph: $schoolPhone', style: small),
              ])),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
                child: pw.Text(copyLabel, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
              ),
            ]),
            pw.Divider(thickness: 0.5, height: 8),
            // Title
            pw.Center(child: pw.Text(
              isRevenue ? 'FEE RECEIPT' : 'EXPENSE VOUCHER',
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
            )),
            pw.SizedBox(height: 4),
            // Bill info row
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text('Bill No: ${bill['billId'] ?? ''}', style: bold),
              pw.Text('Date: ${DateFormat('dd/MM/yyyy').format(date)}', style: bold),
            ]),
            pw.SizedBox(height: 4),
            if (isRevenue) ...[
              pw.Row(children: [
                pw.Text('Student: ', style: bold),
                pw.Text('${bill['stuName'] ?? 'N/A'} (ID: ${bill['stuId'] ?? 'N/A'})', style: normal),
              ]),
              pw.Row(children: [
                pw.Text('Class: ', style: bold),
                pw.Text('${bill['stuClass'] ?? ''} - ${bill['stuSection'] ?? ''}', style: normal),
                pw.SizedBox(width: 20),
                pw.Text('AY: ', style: bold),
                pw.Text(ay, style: normal),
              ]),
              if (origAy.isNotEmpty && origAy != ay)
                pw.Text('Arrears from: Class $origClass ($origAy)', style: small),
            ],
            if (!isRevenue) ...[
              pw.Row(children: [
                pw.Text('POC: ', style: bold),
                pw.Text('${bill['expensePOC'] ?? ''}', style: normal),
              ]),
            ],
            pw.Row(children: [
              pw.Text('Fee Type: ', style: bold),
              pw.Text(isRevenue ? (bill['revenueType'] ?? '').toString() : (bill['expenseType'] ?? '').toString(), style: normal),
            ]),
            pw.SizedBox(height: 6),
            // Amount box
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
              child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text('AMOUNT:', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                pw.Text('Rs. ${amount.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
              ]),
            ),
            if ((bill['remarks'] ?? '').toString().isNotEmpty) ...[
              pw.SizedBox(height: 3),
              pw.Text('Remarks: ${bill['remarks']}', style: small),
            ],
            pw.SizedBox(height: 6),
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text('Cashier: ${bill['billCashierName'] ?? ''}', style: small),
              pw.Text('Signature: _______________', style: small),
            ]),
          ],
        ),
      );
    }

    // Two copies on one A4 page
    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(24),
      build: (ctx) => pw.Column(
        children: [
          buildReceiptCopy('SCHOOL COPY'),
          pw.SizedBox(height: 6),
          pw.Center(child: pw.Text(
            '- - - - - - - - - - - - - - - - - -  Cut Here  - - - - - - - - - - - - - - - - - -',
            style: const pw.TextStyle(fontSize: 7),
          )),
          pw.SizedBox(height: 6),
          buildReceiptCopy('PARENT COPY'),
        ],
      ),
    ));

    final pdfBytes = await pdf.save();
    _downloadFile(pdfBytes, 'Bill_${bill['billId']}_Receipt.pdf', 'application/pdf');
  }

  // ============ PRINT ALL BILLS ============
  Future<void> _printAllBills() async {
    if (_schoolId == null) return;
    final branding = await PdfBranding.forSchool(_schoolId!);
    final schoolName = branding.schoolName.isNotEmpty ? branding.schoolName : 'School';
    final pdf = pw.Document();

    // Filter out deleted bills for the print report
    final activeBills = _bills.where((b) => b['isDeleted'] != true).toList();

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(20),
      header: (ctx) => pw.Container(
        padding: const pw.EdgeInsets.only(bottom: 8),
        margin: const pw.EdgeInsets.only(bottom: 8),
        decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 0.5))),
        child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text(schoolName, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.Text('Bills Report: ${DateFormat('dd/MM/yyyy').format(_startDate)} - ${DateFormat('dd/MM/yyyy').format(_endDate)}',
              style: const pw.TextStyle(fontSize: 9)),
        ]),
      ),
      footer: (ctx) => pw.Container(
        alignment: pw.Alignment.centerRight,
        child: pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}', style: const pw.TextStyle(fontSize: 8)),
      ),
      build: (ctx) => [
        pw.TableHelper.fromTextArray(
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
          cellStyle: const pw.TextStyle(fontSize: 8),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          headers: ['Bill ID', 'Date', 'Type', 'Sub Type', 'Student ID', 'Name', 'Amount'],
          data: activeBills.map((b) {
            final isRev = (b['billType'] ?? '') == 'Revenue';
            final amt = isRev ? (b['revenueAmount'] as num?)?.toDouble() ?? 0 : (b['expenseAmount'] as num?)?.toDouble() ?? 0;
            final date = (b['billDate'] as Timestamp?)?.toDate();
            return [
              (b['billId'] ?? '').toString(),
              date != null ? DateFormat('dd/MM/yyyy').format(date) : '',
              (b['billType'] ?? '').toString(),
              isRev ? (b['revenueType'] ?? '').toString() : (b['expenseType'] ?? '').toString(),
              (b['stuId'] ?? 'NA').toString(),
              (b['stuName'] ?? (b['expensePOC'] ?? '')).toString(),
              'Rs.${amt.toStringAsFixed(2)}',
            ];
          }).toList(),
        ),
      ],
    ));

    final pdfBytes = await pdf.save();
    _downloadFile(pdfBytes, 'All_Bills_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf', 'application/pdf');
  }

  // ============ EXPORT CSV ============
  void _exportCsv() {
    final rows = <List<String>>[
      ['Bill ID', 'Date', 'Type', 'Sub Type', 'Student ID', 'Name', 'Amount', 'Remarks'],
    ];

    for (final b in _bills) {
      final isRev = (b['billType'] ?? '') == 'Revenue';
      final amt = isRev ? (b['revenueAmount'] as num?)?.toDouble() ?? 0 : (b['expenseAmount'] as num?)?.toDouble() ?? 0;
      final date = (b['billDate'] as Timestamp?)?.toDate();
      rows.add([
        (b['billId'] ?? '').toString(),
        date != null ? DateFormat('dd/MM/yyyy').format(date) : '',
        (b['billType'] ?? '').toString(),
        isRev ? (b['revenueType'] ?? '').toString() : (b['expenseType'] ?? '').toString(),
        (b['stuId'] ?? 'NA').toString(),
        (b['stuName'] ?? (b['expensePOC'] ?? '')).toString(),
        amt.toStringAsFixed(2),
        (b['remarks'] ?? '').toString(),
      ]);
    }

    final csvData = const ListToCsvConverter().convert(rows);
    final bytes = Uint8List.fromList(csvData.codeUnits);
    _downloadFile(bytes, 'Bills_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv', 'text/csv');
  }

  // ============ DELETE BILL ============
  void _confirmDeleteBill(Map<String, dynamic> bill) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Bill', style: TextStyle(color: _textPrimary)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Are you sure you want to delete Bill #${bill['billId']}?', style: const TextStyle(color: _textSecondary)),
          const SizedBox(height: 16),
          TextField(
            controller: reasonController,
            style: const TextStyle(color: _textPrimary),
            decoration: InputDecoration(
              hintText: 'Reason for deletion',
              hintStyle: const TextStyle(color: _textSecondary),
              filled: true,
              fillColor: _bgDark,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _borderColor)),
            ),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: _textSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              await _deleteBill(bill, reasonController.text);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteBill(Map<String, dynamic> bill, String reason) async {
    if (_schoolId == null) return;
    try {
      final billType = (bill['billType'] ?? '').toString();
      final isRevenue = billType == 'Revenue';

      // Soft-delete the bill
      await FirebaseFirestore.instance.collection('schools').doc(_schoolId).collection('bills').doc(bill['docId'].toString()).update({
        'isDeleted': true,
        'isBillDeleted': true,
        'deletionReason': reason,
        'deletedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Revert fee amount against the student's record if this is a Revenue bill
      if (isRevenue) {
        final stuId = (bill['stuId'] ?? '').toString();
        final revenueType = (bill['revenueType'] ?? '').toString();
        final amount = (bill['revenueAmount'] as num?)?.toDouble() ?? 0.0;

        if (stuId.isNotEmpty && amount > 0) {
          // Find the student_fee_details doc for this student
          final feeSnap = await FirebaseFirestore.instance
              .collection('schools').doc(_schoolId).collection('student_fee_details')
              .where('stuId', isEqualTo: int.tryParse(stuId) ?? stuId)
              .limit(1)
              .get();

          if (feeSnap.docs.isNotEmpty) {
            final feeDoc = feeSnap.docs.first;
            final fd = feeDoc.data();
            double n(String k) => (fd[k] as num?)?.toDouble() ?? 0;

            final Map<String, dynamic> revert = {'updatedAt': FieldValue.serverTimestamp()};

            // Reverse the exact fields that fee_payment_screen increments
            switch (revenueType) {
              case 'Admission Fee':
                revert['stuPaidAdmissionFees'] = n('stuPaidAdmissionFees') - amount;
                revert['stuBalAdmissionFees']  = n('stuBalAdmissionFees')  + amount;
                break;
              case 'Exam Fee':
                revert['stuPaidExamFees'] = n('stuPaidExamFees') - amount;
                revert['stuBalExamFees']  = n('stuBalExamFees')  + amount;
                break;
              case 'Tution Fee':
                revert['stuPaidTutionFees'] = n('stuPaidTutionFees') - amount;
                revert['stuBalTutionFees']  = n('stuBalTutionFees')  + amount;
                break;
              case 'Van Fee':
                revert['studPaidVanFees'] = n('studPaidVanFees') - amount;
                revert['stuBalVanFees']   = n('stuBalVanFees')   + amount;
                break;
              case 'Arrear Admission Fee':
                revert['stuPaidArrearAdmissionFees'] = n('stuPaidArrearAdmissionFees') - amount;
                revert['balanceArrearAdmissionFees'] = n('balanceArrearAdmissionFees') + amount;
                break;
              case 'Arrear Exam Fee':
                revert['stuPaidArrearExamFees'] = n('stuPaidArrearExamFees') - amount;
                revert['balanceArrearExamFees'] = n('balanceArrearExamFees') + amount;
                break;
              case 'Arrear Tution Fee':
                revert['stuPaidArrearTutionFees']  = n('stuPaidArrearTutionFees') - amount;
                revert['balanceArrearTuitionFees'] = n('balanceArrearTuitionFees') + amount;
                break;
              case 'Arrear Van Fee':
                revert['stuPaidArrearVanFees'] = n('stuPaidArrearVanFees') - amount;
                revert['balanceArrearVanFees'] = n('balanceArrearVanFees') + amount;
                break;
            }
            revert['stuPaidTotalFees'] = n('stuPaidTotalFees') - amount;
            revert['stuBalTotalFees']  = n('stuBalTotalFees')  + amount;

            await feeDoc.reference.update(revert);
          }
        }
      }

      _fetchBills();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isRevenue
              ? 'Bill deleted & ₹${((bill['revenueAmount'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)} reverted to student balance'
              : 'Bill deleted'),
          backgroundColor: _accentGreen,
        ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  void _downloadFile(Uint8List bytes, String fileName, String mimeType) {
    final blob = html.Blob([bytes], mimeType);
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)..setAttribute('download', fileName)..click();
    html.Url.revokeObjectUrl(url);
  }
}
