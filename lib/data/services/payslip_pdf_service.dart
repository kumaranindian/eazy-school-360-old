import 'dart:typed_data';
import 'dart:html' as html;

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';

import '../../domain/entities/payroll.dart';

class PayslipPdfService {
  static final _fmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
  static final _dateFmt = DateFormat('dd MMM yyyy');

  // ══════════════════════════════════════════════════════════════════
  // SINGLE PAYSLIP PDF
  // ══════════════════════════════════════════════════════════════════

  static Future<Uint8List> generateSinglePayslip(PayrollRecord record, {String schoolName = 'Eazy School 360'}) async {
    final pdf = pw.Document();
    pdf.addPage(_buildPayslipPage(record, schoolName));
    return pdf.save();
  }

  // ══════════════════════════════════════════════════════════════════
  // BULK PAYSLIPS (all staff for a month)
  // ══════════════════════════════════════════════════════════════════

  static Future<Uint8List> generateBulkPayslips(List<PayrollRecord> records, {String schoolName = 'Eazy School 360'}) async {
    final pdf = pw.Document();
    for (final record in records) {
      pdf.addPage(_buildPayslipPage(record, schoolName));
    }
    return pdf.save();
  }

  // ══════════════════════════════════════════════════════════════════
  // PAGE BUILDER
  // ══════════════════════════════════════════════════════════════════

  static pw.Page _buildPayslipPage(PayrollRecord record, String schoolName) {
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // ── Header ──
            _buildHeader(record, schoolName),
            pw.SizedBox(height: 16),
            _divider(),
            pw.SizedBox(height: 12),

            // ── Employee Details ──
            _sectionTitle('EMPLOYEE DETAILS'),
            pw.SizedBox(height: 6),
            _buildEmployeeDetails(record),
            pw.SizedBox(height: 14),

            // ── Attendance Summary ──
            _sectionTitle('ATTENDANCE SUMMARY'),
            pw.SizedBox(height: 6),
            _buildAttendanceSummary(record),
            pw.SizedBox(height: 14),

            // ── Leave Breakdown ──
            if (record.leaveBreakdown.isNotEmpty) ...[
              _sectionTitle('LEAVE BREAKDOWN'),
              pw.SizedBox(height: 6),
              _buildLeaveBreakdownTable(record),
              pw.SizedBox(height: 14),
            ],

            // ── Earnings & Deductions ──
            _buildEarningsDeductionsTable(record),
            pw.SizedBox(height: 14),

            // ── Net Pay ──
            _buildNetPayBox(record),
            pw.SizedBox(height: 14),

            // ── Footer ──
            _buildFooter(record),
          ],
        );
      },
    );
  }

  // ── HEADER ──
  static pw.Widget _buildHeader(PayrollRecord record, String schoolName) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(schoolName,
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800)),
            pw.SizedBox(height: 2),
            pw.Text('PAYSLIP', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.green800)),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(record.periodLabel, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 2),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: pw.BoxDecoration(
                color: record.status == PayrollStatus.APPROVED || record.status == PayrollStatus.PAID
                    ? PdfColors.green100
                    : PdfColors.amber100,
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Text(record.status.name,
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: record.status == PayrollStatus.APPROVED || record.status == PayrollStatus.PAID
                        ? PdfColors.green800
                        : PdfColors.amber800,
                  )),
            ),
          ],
        ),
      ],
    );
  }

  // ── EMPLOYEE DETAILS ──
  static pw.Widget _buildEmployeeDetails(PayrollRecord record) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _keyValue('Name', record.staffName),
              pw.SizedBox(height: 4),
              _keyValue('Employee ID', record.employeeId),
            ],
          )),
          pw.Expanded(child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _keyValue('Department', record.department.isNotEmpty ? record.department : '-'),
              pw.SizedBox(height: 4),
              _keyValue('Designation', record.designation.isNotEmpty ? record.designation : '-'),
            ],
          )),
          pw.Expanded(child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _keyValue('Pay Period', record.periodLabel),
              pw.SizedBox(height: 4),
              _keyValue('Per Day Salary', _fmt.format(record.perDaySalary)),
            ],
          )),
        ],
      ),
    );
  }

  // ── ATTENDANCE SUMMARY ──
  static pw.Widget _buildAttendanceSummary(PayrollRecord record) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(4),
        color: PdfColors.grey50,
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          _attendanceBox('Working Days', '${record.workingDays}', PdfColors.blueGrey700),
          _attendanceBox('Present', '${record.presentDays}', PdfColors.green700),
          _attendanceBox('Total Leave', '${record.leaveDaysTaken}', PdfColors.orange700),
          _attendanceBox('Paid Leave', '${record.paidLeaveDays}', PdfColors.blue700),
          _attendanceBox('Unpaid (LOP)', '${record.unpaidLeaveDays}', PdfColors.red700),
        ],
      ),
    );
  }

  static pw.Widget _attendanceBox(String label, String value, PdfColor color) {
    return pw.Column(children: [
      pw.Text(value, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: color)),
      pw.SizedBox(height: 2),
      pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
    ]);
  }

  // ── LEAVE BREAKDOWN TABLE ──
  static pw.Widget _buildLeaveBreakdownTable(PayrollRecord record) {
    final headers = ['Leave Type', 'Paid/Unpaid', 'Annual Quota', 'Used (YTD)', 'This Month', 'Balance'];
    final data = record.leaveBreakdown.map((lb) => [
      lb.leaveTypeName,
      lb.isPaid ? 'Paid' : 'Unpaid',
      '${lb.allowed}',
      '${lb.used}',
      '${lb.takenThisMonth}',
      '${lb.balance}',
    ]).toList();

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: data,
      headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey700),
      cellStyle: const pw.TextStyle(fontSize: 9),
      cellAlignment: pw.Alignment.center,
      headerAlignment: pw.Alignment.center,
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
    );
  }

  // ── EARNINGS & DEDUCTIONS TABLE ──
  static pw.Widget _buildEarningsDeductionsTable(PayrollRecord record) {
    // Build earnings rows
    final earningsRows = <List<String>>[
      ['Basic Pay', _fmt.format(record.basicPay), '', ''],
      ...record.earnings.map((e) => [e.name, _fmt.format(e.amount), '', '']),
    ];

    // Build deductions rows
    final deductionsRows = <List<String>>[
      ...record.deductions.map((d) => ['', '', d.name, _fmt.format(d.amount)]),
    ];
    if (record.lopDeduction > 0) {
      deductionsRows.add(['', '', 'LOP (${record.unpaidLeaveDays}d × ${_fmt.format(record.perDaySalary)}/day)', _fmt.format(record.lopDeduction)]);
    }

    // Combine
    final maxRows = earningsRows.length > deductionsRows.length ? earningsRows.length : deductionsRows.length;
    final tableData = <List<String>>[];
    for (int i = 0; i < maxRows; i++) {
      final earning = i < earningsRows.length ? earningsRows[i] : ['', '', '', ''];
      final deduction = i < deductionsRows.length ? deductionsRows[i] : ['', '', '', ''];
      tableData.add([earning[0], earning[1], deduction[2], deduction[3]]);
    }

    // Totals row
    tableData.add(['Gross Salary', _fmt.format(record.grossSalary), 'Total Deductions', _fmt.format(record.totalDeductions)]);

    return pw.Column(children: [
      pw.Row(children: [
        pw.Expanded(child: _sectionTitle('EARNINGS')),
        pw.Expanded(child: _sectionTitle('DEDUCTIONS')),
      ]),
      pw.SizedBox(height: 6),
      pw.TableHelper.fromTextArray(
        headers: ['Earning Component', 'Amount', 'Deduction Component', 'Amount'],
        data: tableData,
        headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey700),
        cellStyle: const pw.TextStyle(fontSize: 9),
        cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
        oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey50),
      ),
    ]);
  }

  // ── NET PAY BOX ──
  static pw.Widget _buildNetPayBox(PayrollRecord record) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: PdfColors.green50,
        border: pw.Border.all(color: PdfColors.green700, width: 1.5),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('NET PAY', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.green900)),
          pw.Text(_fmt.format(record.netSalary),
              style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.green800)),
        ],
      ),
    );
  }

  // ── FOOTER ──
  static pw.Widget _buildFooter(PayrollRecord record) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _divider(),
        pw.SizedBox(height: 6),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            if (record.processedAt != null)
              pw.Text('Processed: ${_dateFmt.format(record.processedAt!)}',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
            if (record.approvedAt != null)
              pw.Text('Approved: ${_dateFmt.format(record.approvedAt!)}',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
            pw.Text('Generated: ${_dateFmt.format(DateTime.now())}',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
          ],
        ),
        pw.SizedBox(height: 16),
        pw.Text('This is a computer-generated payslip and does not require a signature.',
            style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey400)),
      ],
    );
  }

  // ── HELPERS ──

  static pw.Widget _sectionTitle(String title) {
    return pw.Text(title, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800));
  }

  static pw.Widget _keyValue(String key, String value) {
    return pw.RichText(text: pw.TextSpan(children: [
      pw.TextSpan(text: '$key: ', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
      pw.TextSpan(text: value, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
    ]));
  }

  static pw.Widget _divider() {
    return pw.Container(height: 1, color: PdfColors.grey300);
  }

  // ══════════════════════════════════════════════════════════════════
  // DOWNLOAD HELPER (Web)
  // ══════════════════════════════════════════════════════════════════

  static void downloadPdf(Uint8List bytes, String fileName) {
    final blob = html.Blob([bytes], 'application/pdf');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  /// Download single payslip
  static Future<void> downloadSinglePayslip(PayrollRecord record, {String schoolName = 'Eazy School 360'}) async {
    final bytes = await generateSinglePayslip(record, schoolName: schoolName);
    final fileName = 'Payslip_${record.staffName.replaceAll(' ', '_')}_${record.periodLabel.replaceAll(' ', '_')}.pdf';
    downloadPdf(bytes, fileName);
  }

  /// Download all payslips for a month as combined PDF
  static Future<void> downloadBulkPayslips(List<PayrollRecord> records, {String schoolName = 'Eazy School 360'}) async {
    if (records.isEmpty) return;
    final bytes = await generateBulkPayslips(records, schoolName: schoolName);
    final period = records.first.periodLabel.replaceAll(' ', '_');
    final fileName = 'All_Payslips_$period.pdf';
    downloadPdf(bytes, fileName);
  }
}
