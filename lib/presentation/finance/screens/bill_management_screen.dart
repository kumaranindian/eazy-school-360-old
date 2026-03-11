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
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 365));
  DateTime _endDate = DateTime.now();
  String _filterType = 'Both';
  List<Map<String, dynamic>> _bills = [];
  bool _isLoading = false;
  String? _schoolId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _schoolId = ref.read(currentSessionProvider)?.schoolId;
      if (_schoolId != null) _fetchBills();
    });
  }

  Future<void> _fetchBills() async {
    if (_schoolId == null) return;
    setState(() => _isLoading = true);

    try {
      Query<Map<String, dynamic>> query = FirebaseFirestore.instance
          .collection('schools').doc(_schoolId).collection('bills')
          .where('isDeleted', isEqualTo: false)
          .orderBy('billDate', descending: true);

      if (_filterType == 'Revenue') {
        query = FirebaseFirestore.instance
            .collection('schools').doc(_schoolId).collection('bills')
            .where('billType', isEqualTo: 'Revenue')
            .where('isDeleted', isEqualTo: false)
            .orderBy('billDate', descending: true);
      } else if (_filterType == 'Expense') {
        query = FirebaseFirestore.instance
            .collection('schools').doc(_schoolId).collection('bills')
            .where('billType', isEqualTo: 'Expense')
            .where('isDeleted', isEqualTo: false)
            .orderBy('billDate', descending: true);
      }

      final snap = await query.get();
      final bills = <Map<String, dynamic>>[];
      for (final doc in snap.docs) {
        final d = doc.data();
        d['docId'] = doc.id;
        final billDate = (d['billDate'] as Timestamp?)?.toDate();
        if (billDate != null) {
          if (billDate.isAfter(_startDate.subtract(const Duration(days: 1))) &&
              billDate.isBefore(_endDate.add(const Duration(days: 1)))) {
            bills.add(d);
          }
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
          _buildDateButton('From', _startDate, (d) => setState(() => _startDate = d)),
          _buildDateButton('To', _endDate, (d) => setState(() => _endDate = d)),
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

  Widget _buildDateButton(String label, DateTime date, Function(DateTime) onPicked) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(2020), lastDate: DateTime(2030),
          builder: (ctx, child) => Theme(data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: _accentGreen, surface: _cardDark)), child: child!));
        if (picked != null) { onPicked(picked); }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: _bgDark, borderRadius: BorderRadius.circular(8), border: Border.all(color: _borderColor)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.calendar_today_rounded, size: 14, color: _accentGreen),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(label, style: const TextStyle(fontSize: 10, color: _textSecondary)),
            Text(DateFormat('yyyy-MM-dd').format(date), style: const TextStyle(color: _textPrimary, fontSize: 13)),
          ]),
        ]),
      ),
    );
  }

  Widget _buildTypeDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: _bgDark, borderRadius: BorderRadius.circular(8), border: Border.all(color: _borderColor)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _filterType,
          dropdownColor: _cardDark,
          style: const TextStyle(color: _textPrimary, fontSize: 13),
          items: ['Both', 'Revenue', 'Expense'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
          onChanged: (v) { if (v != null) setState(() => _filterType = v); },
        ),
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
            final amount = isRevenue
                ? (b['revenueAmount'] as num?)?.toDouble() ?? 0
                : (b['expenseAmount'] as num?)?.toDouble() ?? 0;
            final subType = isRevenue
                ? (b['revenueType'] ?? '').toString()
                : (b['expenseType'] ?? '').toString();
            final date = (b['billDate'] as Timestamp?)?.toDate();

            return DataRow(cells: [
              DataCell(Text('${b['billId'] ?? ''}', style: const TextStyle(color: _textPrimary, fontSize: 12))),
              DataCell(Text(date != null ? DateFormat('dd/MM/yyyy').format(date) : '', style: const TextStyle(color: _textPrimary, fontSize: 12))),
              DataCell(Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: isRevenue ? const Color(0xFF10B981).withOpacity(0.15) : const Color(0xFFEF4444).withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                child: Text(billType, style: TextStyle(color: isRevenue ? const Color(0xFF10B981) : const Color(0xFFEF4444), fontSize: 11, fontWeight: FontWeight.bold)),
              )),
              DataCell(Text(subType, style: const TextStyle(color: _textSecondary, fontSize: 12))),
              DataCell(Text((b['stuId'] ?? 'NA').toString(), style: const TextStyle(color: _textPrimary, fontSize: 12))),
              DataCell(Text((b['stuName'] ?? (b['expensePOC'] ?? '')).toString(), style: const TextStyle(color: _textPrimary, fontSize: 12))),
              DataCell(Text('₹${amount.toStringAsFixed(2)}', style: TextStyle(color: isRevenue ? const Color(0xFF10B981) : const Color(0xFFEF4444), fontWeight: FontWeight.bold, fontSize: 12))),
              DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(icon: const Icon(Icons.print_rounded, color: Color(0xFF3B82F6), size: 18), tooltip: 'Print', onPressed: () => _printSingleBill(b)),
                IconButton(icon: const Icon(Icons.delete_rounded, color: Color(0xFFEF4444), size: 18), tooltip: 'Delete', onPressed: () => _confirmDeleteBill(b)),
              ])),
            ]);
          }).toList(),
        ),
      ),
    );
  }

  // ============ PRINT SINGLE BILL ============
  Future<void> _printSingleBill(Map<String, dynamic> bill) async {
    final pdf = pw.Document();
    final isRevenue = (bill['billType'] ?? '') == 'Revenue';
    final amount = isRevenue ? (bill['revenueAmount'] as num?)?.toDouble() ?? 0 : (bill['expenseAmount'] as num?)?.toDouble() ?? 0;
    final date = (bill['billDate'] as Timestamp?)?.toDate() ?? DateTime.now();

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a5,
      margin: const pw.EdgeInsets.all(24),
      build: (ctx) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Center(child: pw.Text('Fee Receipt', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold))),
        pw.SizedBox(height: 8),
        pw.Divider(),
        pw.SizedBox(height: 12),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text('Bill No: ${bill['billId'] ?? ''}'),
          pw.Text('Date: ${DateFormat('dd/MM/yyyy').format(date)}'),
        ]),
        pw.SizedBox(height: 8),
        pw.Text('Type: ${bill['billType'] ?? ''}'),
        pw.Text('Sub Type: ${isRevenue ? (bill['revenueType'] ?? '') : (bill['expenseType'] ?? '')}'),
        if (isRevenue) ...[
          pw.Text('Student ID: ${bill['stuId'] ?? 'N/A'}'),
          pw.Text('Student Name: ${bill['stuName'] ?? 'N/A'}'),
        ],
        if (!isRevenue) pw.Text('POC: ${bill['expensePOC'] ?? ''}'),
        pw.SizedBox(height: 16),
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(border: pw.Border.all(), borderRadius: pw.BorderRadius.circular(8)),
          child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text('Amount:', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.Text('Rs. ${amount.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          ]),
        ),
        if ((bill['remarks'] ?? '').toString().isNotEmpty) ...[
          pw.SizedBox(height: 8),
          pw.Text('Remarks: ${bill['remarks']}'),
        ],
        pw.SizedBox(height: 24),
        pw.Divider(),
        pw.Text('Cashier: ${bill['billCashierName'] ?? ''}', style: const pw.TextStyle(fontSize: 10)),
      ]),
    ));

    final pdfBytes = await pdf.save();
    _downloadFile(pdfBytes, 'Bill_${bill['billId']}_Receipt.pdf', 'application/pdf');
  }

  // ============ PRINT ALL BILLS ============
  Future<void> _printAllBills() async {
    final pdf = pw.Document();

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(20),
      header: (ctx) => pw.Column(children: [
        pw.Center(child: pw.Text('Bills Report', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold))),
        pw.SizedBox(height: 4),
        pw.Center(child: pw.Text('${DateFormat('dd MMM yyyy').format(_startDate)} - ${DateFormat('dd MMM yyyy').format(_endDate)}')),
        pw.SizedBox(height: 12),
      ]),
      build: (ctx) => [
        pw.TableHelper.fromTextArray(
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
          cellStyle: const pw.TextStyle(fontSize: 8),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          headers: ['Bill ID', 'Date', 'Type', 'Sub Type', 'Student ID', 'Name', 'Amount'],
          data: _bills.map((b) {
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
      await FirebaseFirestore.instance.collection('schools').doc(_schoolId).collection('bills').doc(bill['docId'].toString()).update({
        'isDeleted': true,
        'isBillDeleted': true,
        'deletionReason': reason,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _fetchBills();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bill deleted'), backgroundColor: _accentGreen));
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
