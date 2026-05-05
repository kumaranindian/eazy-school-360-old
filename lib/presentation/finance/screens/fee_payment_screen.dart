// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/providers/auth_provider.dart';
import '../../../domain/entities/academic_year.dart';
import '../../../presentation/shared/widgets/searchable_dropdown.dart';
import '../../shared/pdf/pdf_branding.dart';

const Color _bgDark      = Color(0xFF0D1117);
const Color _cardDark    = Color(0xFF161B22);
const Color _accentGreen = Color(0xFF4CAF50);
const Color _accentBlue  = Color(0xFF3B82F6);
const Color _accentRed   = Color(0xFFEF4444);
const Color _accentAmber = Color(0xFFF59E0B);
const Color _textPrimary = Color(0xFFE6EDF3);
const Color _textSecondary = Color(0xFF8B949E);
const Color _borderColor = Color(0xFF30363D);

class FeePaymentScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> studentData;
  final String studentDocId;
  const FeePaymentScreen({Key? key, required this.studentData, required this.studentDocId}) : super(key: key);

  @override
  ConsumerState<FeePaymentScreen> createState() => _FeePaymentScreenState();
}

class _FeePaymentScreenState extends ConsumerState<FeePaymentScreen> {
  static const List<String> _feeTypes = [
    'Select Fees Type', 'Admission Fee', 'Exam Fee', 'Tution Fee', 'Van Fee',
    'Arrear Admission Fee', 'Arrear Exam Fee', 'Arrear Tution Fee', 'Arrear Van Fee',
  ];

  String _selectedFeeType = 'Select Fees Type';
  final _amountCtrl = TextEditingController(text: '0');
  final _dateCtrl   = TextEditingController();
  bool _isSaving = false;
  int _billNumber = 0;

  String? get _schoolId => ref.read(currentSessionProvider)?.schoolId;
  final _fmt = NumberFormat('#,##0.00', 'en_IN');

  @override
  void initState() {
    super.initState();
    _dateCtrl.text = DateFormat('dd/MM/yyyy').format(DateTime.now());
    _loadNextBillNumber();
  }

  @override
  void dispose() { _amountCtrl.dispose(); _dateCtrl.dispose(); super.dispose(); }

  Future<void> _loadNextBillNumber() async {
    if (_schoolId == null) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('schools').doc(_schoolId).collection('bills')
          .orderBy('billId', descending: true).limit(1).get();
      setState(() => _billNumber = snap.docs.isEmpty
          ? 1 : ((snap.docs.first.data()['billId'] as num?)?.toInt() ?? 0) + 1);
    } catch (_) { setState(() => _billNumber = 1); }
  }

  double get _balance {
    final d = widget.studentData;
    double n(String k) => (d[k] as num?)?.toDouble() ?? 0;
    switch (_selectedFeeType) {
      case 'Admission Fee':        return n('stuBalAdmissionFees');
      case 'Exam Fee':             return n('stuBalExamFees');
      case 'Tution Fee':           return n('stuBalTutionFees');
      case 'Van Fee':              return n('stuBalVanFees');
      case 'Arrear Admission Fee': return n('balanceArrearAdmissionFees');
      case 'Arrear Exam Fee':      return n('balanceArrearExamFees');
      case 'Arrear Tution Fee':    return n('balanceArrearTuitionFees');
      case 'Arrear Van Fee':       return n('balanceArrearVanFees');
      default: return 0;
    }
  }

  bool get _isArrear => _selectedFeeType.startsWith('Arrear');

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg), backgroundColor: isError ? _accentRed : _accentGreen));
  }

  Future<void> _savePayment() async {
    if (_schoolId == null) return;
    if (_selectedFeeType == 'Select Fees Type') { _snack('Select a fee type', isError: true); return; }
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    if (amount <= 0) { _snack('Enter a valid amount', isError: true); return; }
    if (amount > _balance) { _snack('Amount exceeds balance ₹${_fmt.format(_balance)}', isError: true); return; }

    setState(() => _isSaving = true);
    try {
      final d = widget.studentData;
      double n(String k) => (d[k] as num?)?.toDouble() ?? 0;
      final stuId      = d['stuId']?.toString() ?? '';
      final stuName    = (d['stuName'] ?? d['studentName'] ?? '').toString();
      final stuClass   = (d['stuClass'] ?? d['className'] ?? '').toString();
      final stuSection = (d['stuSection'] ?? d['section'] ?? '').toString();

      final Map<String, dynamic> upd = {'updatedAt': FieldValue.serverTimestamp()};
      switch (_selectedFeeType) {
        case 'Admission Fee':
          upd['stuPaidAdmissionFees'] = n('stuPaidAdmissionFees') + amount;
          upd['stuBalAdmissionFees']  = n('stuBalAdmissionFees')  - amount; break;
        case 'Exam Fee':
          upd['stuPaidExamFees'] = n('stuPaidExamFees') + amount;
          upd['stuBalExamFees']  = n('stuBalExamFees')  - amount; break;
        case 'Tution Fee':
          upd['stuPaidTutionFees'] = n('stuPaidTutionFees') + amount;
          upd['stuBalTutionFees']  = n('stuBalTutionFees')  - amount; break;
        case 'Van Fee':
          upd['studPaidVanFees'] = n('studPaidVanFees') + amount;
          upd['stuBalVanFees']   = n('stuBalVanFees')   - amount; break;
        case 'Arrear Admission Fee':
          upd['stuPaidArrearAdmissionFees'] = n('stuPaidArrearAdmissionFees') + amount;
          upd['balanceArrearAdmissionFees'] = n('balanceArrearAdmissionFees') - amount; break;
        case 'Arrear Exam Fee':
          upd['stuPaidArrearExamFees'] = n('stuPaidArrearExamFees') + amount;
          upd['balanceArrearExamFees'] = n('balanceArrearExamFees') - amount; break;
        case 'Arrear Tution Fee':
          upd['stuPaidArrearTutionFees']  = n('stuPaidArrearTutionFees') + amount;
          upd['balanceArrearTuitionFees'] = n('balanceArrearTuitionFees') - amount; break;
        case 'Arrear Van Fee':
          upd['stuPaidArrearVanFees'] = n('stuPaidArrearVanFees') + amount;
          upd['balanceArrearVanFees'] = n('balanceArrearVanFees') - amount; break;
      }
      upd['stuPaidTotalFees'] = n('stuPaidTotalFees') + amount;
      upd['stuBalTotalFees']  = n('stuBalTotalFees')  - amount;

      await FirebaseFirestore.instance
          .collection('schools').doc(_schoolId)
          .collection('student_fee_details').doc(widget.studentDocId)
          .update(upd);

      // For arrears, attribute payment to the originating academic year/class
      // when available on the student record (populated during promotion).
      // Falls back to current AY/class so regular payments keep working.
      final currentAY = AcademicYear.getCurrentYearCode();
      final currentFY = FiscalYear.getCurrentYearCode();
      final prevAY = (d['previousAcademicYear'] ?? '').toString();
      final prevClass = (d['previousClass'] ?? '').toString();
      final originatingAY = _isArrear && prevAY.isNotEmpty ? prevAY : currentAY;
      final originatingClass = _isArrear && prevClass.isNotEmpty ? prevClass : stuClass;

      await FirebaseFirestore.instance
          .collection('schools').doc(_schoolId).collection('bills').add({
        'billId': _billNumber, 'billType': 'Revenue',
        'revenueType': _selectedFeeType, 'revenueAmount': amount,
        'stuId': stuId, 'stuName': stuName, 'stuClass': stuClass, 'stuSection': stuSection,
        'billDate': Timestamp.fromDate(DateTime.now()),
        'createdAt': FieldValue.serverTimestamp(),
        'isDeleted': false, 'isBillDeleted': false, 'remarks': '',
        // Payment is recorded in the CURRENT AY/FY (money flow).
        'academicYear': currentAY,
        'fiscalYear': currentFY,
        // But we keep track of where the unpaid fees originally came from,
        // so historical reports can show "X paid in 2026-27 for Class III of 2025-26".
        'originatingAcademicYear': originatingAY,
        'originatingClass': originatingClass,
        'isArrear': _isArrear,
      });

      setState(() => _isSaving = false);
      _snack('Payment saved! Bill #$_billNumber generated.');
      _loadNextBillNumber();
      _amountCtrl.text = '0';
      setState(() => _selectedFeeType = 'Select Fees Type');
    } catch (e) {
      setState(() => _isSaving = false);
      _snack('Error: $e', isError: true);
    }
  }

  Future<void> _printReceipt() async {
    if (_selectedFeeType == 'Select Fees Type') { _snack('Select fee type first', isError: true); return; }
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    if (amount <= 0) { _snack('Enter amount first', isError: true); return; }
    try {
      final d = widget.studentData;
      final stuName    = (d['stuName'] ?? d['studentName'] ?? '').toString();
      final stuClass   = (d['stuClass'] ?? d['className'] ?? '').toString();
      final stuSection = (d['stuSection'] ?? d['section'] ?? '').toString();
      final stuId      = d['stuId']?.toString() ?? '';

      final branding = _schoolId == null
          ? const PdfBrandingContext(
              schoolName: '',
              schoolAddress: '',
              schoolPhone: '',
              schoolEmail: '',
              schoolWebsite: '',
              logoImage: null,
            )
          : await PdfBranding.forSchool(_schoolId!);

      final pdf = pw.Document();
      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a5,
        margin: const pw.EdgeInsets.all(20),
        header: (ctx) => PdfBranding.buildHeader(
          branding,
          title: 'FEE RECEIPT',
          subtitle: 'Bill #$_billNumber • ${_dateCtrl.text}',
        ),
        footer: (ctx) => PdfBranding.buildFooter(branding, ctx),
        build: (ctx) => [
          pw.SizedBox(height: 4),
          _pr('Student Name', stuName), _pr('Student ID', stuId),
          _pr('Class & Section', '$stuClass - $stuSection'),
          _pr('Academic Year', AcademicYear.getCurrentYearCode()),
          pw.SizedBox(height: 8), pw.Divider(), pw.SizedBox(height: 8),
          _pr('Fee Type', _selectedFeeType),
          _pr('Amount Paid', 'Rs. ${_fmt.format(amount)}'),
          _pr('Balance Due', 'Rs. ${_fmt.format(_balance - amount)}'),
          pw.SizedBox(height: 20),
          pw.Center(child: pw.Text('Thank you!', style: const pw.TextStyle(fontSize: 12))),
        ],
      ));
      final bytes = await pdf.save();
      _dl(bytes, 'receipt_$_billNumber.pdf', 'application/pdf');
      _snack('Receipt downloaded');
    } catch (e) { _snack('Print failed: $e', isError: true); }
  }

  pw.Widget _pr(String l, String v) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 3),
    child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
      pw.Text(l, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
      pw.Text(v, style: const pw.TextStyle(fontSize: 11)),
    ]),
  );

  Future<void> _exportCsv() async {
    try {
      final d = widget.studentData;
      final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
      final csv = 'Bill No,Date,Student Name,Class,Section,Fee Type,Amount,Balance\n'
          '$_billNumber,${_dateCtrl.text},"${d['stuName'] ?? ''}",${d['stuClass'] ?? ''},${d['stuSection'] ?? ''},'
          '"$_selectedFeeType",${amount.toStringAsFixed(2)},${_balance.toStringAsFixed(2)}\n';
      _dl(Uint8List.fromList(csv.codeUnits), 'payment_$_billNumber.csv', 'text/csv');
      _snack('CSV exported');
    } catch (e) { _snack('Export failed: $e', isError: true); }
  }

  void _dl(List<int> bytes, String name, String mime) {
    final blob = html.Blob([Uint8List.fromList(bytes)], mime);
    final url  = html.Url.createObjectUrlFromBlob(blob);
    (html.AnchorElement(href: url)..setAttribute('download', name)..click());
    html.Url.revokeObjectUrl(url);
  }

  void _clearForm() => setState(() {
    _selectedFeeType = 'Select Fees Type';
    _amountCtrl.text = '0';
    _dateCtrl.text = DateFormat('dd/MM/yyyy').format(DateTime.now());
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 1024;
    final dialogWidth = isDesktop ? 900.0 : (screenWidth > 600 ? screenWidth * 0.92 : screenWidth - 32);
    final d = widget.studentData;
    final stuName    = (d['stuName'] ?? d['studentName'] ?? 'Unknown').toString();
    final stuClass   = (d['stuClass'] ?? d['className'] ?? '').toString();
    final stuSection = (d['stuSection'] ?? d['section'] ?? '').toString();

    return Dialog(
      backgroundColor: _bgDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: SizedBox(
        width: dialogWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Dialog header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                color: _cardDark,
                borderRadius: BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
                border: Border(bottom: BorderSide(color: _borderColor)),
              ),
              child: Row(children: [
                const Icon(Icons.payment_rounded, color: _accentGreen, size: 20),
                const SizedBox(width: 10),
                const Expanded(child: Text('Fee Payment', style: TextStyle(color: _textPrimary, fontWeight: FontWeight.bold, fontSize: 16))),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: _textSecondary, size: 20),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ]),
            ),
            // Dialog body
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(isDesktop ? 24 : 16),
                child: isDesktop
                    ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Expanded(flex: 3, child: _buildLeftCard(stuName, stuClass, stuSection)),
                        const SizedBox(width: 20),
                        Expanded(flex: 2, child: _buildRightCard()),
                      ])
                    : Column(children: [
                        _buildLeftCard(stuName, stuClass, stuSection),
                        const SizedBox(height: 16),
                        _buildRightCard(),
                      ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeftCard(String stuName, String stuClass, String stuSection) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: _cardDark, borderRadius: BorderRadius.circular(12), border: Border.all(color: _borderColor)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _hdr(Icons.assignment_outlined, 'Payment Information', _accentBlue),
      const SizedBox(height: 20),
      _lbl('Fee Type'), const SizedBox(height: 8),
      _buildFeeTypeDropdown(),
      const SizedBox(height: 20),
      _lbl('Bill Information'), const SizedBox(height: 8),
      Row(children: [
        Expanded(child: _roField('Bill Number', '#$_billNumber', Icons.tag_outlined)),
        const SizedBox(width: 12),
        Expanded(child: _dateField()),
      ]),
      const SizedBox(height: 20),
      _lbl('Student Information'), const SizedBox(height: 8),
      Row(children: [
        Expanded(child: _roField('Student Name & ID', '$stuName – ${widget.studentData['stuId'] ?? ''}', Icons.person_outline)),
        const SizedBox(width: 12),
        Expanded(child: _roField('Class & Section', '$stuClass – $stuSection', Icons.school_outlined)),
      ]),
    ]),
  );

  Widget _buildRightCard() {
    final bal = _balance;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: _cardDark, borderRadius: BorderRadius.circular(12), border: Border.all(color: _borderColor)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _hdr(Icons.account_balance_wallet_outlined, 'Payment Details', _accentGreen),
        const SizedBox(height: 20),
        if (_selectedFeeType != 'Select Fees Type') ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: (_isArrear ? _accentRed : _accentBlue).withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: (_isArrear ? _accentRed : _accentBlue).withOpacity(0.3)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_isArrear ? 'Arrear Balance Due' : 'Balance Due',
                  style: TextStyle(color: _isArrear ? _accentRed : _accentBlue, fontSize: 13)),
              const SizedBox(height: 4),
              Text('₹${_fmt.format(bal)}',
                  style: TextStyle(color: _isArrear ? _accentRed : _accentBlue, fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: (_isArrear ? _accentRed : _accentGreen).withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                child: Text(_selectedFeeType, style: TextStyle(color: _isArrear ? _accentRed : _accentGreen, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ]),
          ),
          const SizedBox(height: 16),
        ],
        _lbl('Payment Amount'), const SizedBox(height: 4),
        const Text('Amount to Pay', style: TextStyle(color: _textSecondary, fontSize: 12)),
        const SizedBox(height: 6),
        TextField(
          controller: _amountCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
          style: const TextStyle(color: _textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            prefixText: '₹ ', prefixStyle: const TextStyle(color: _textSecondary, fontSize: 16),
            suffixText: _selectedFeeType != 'Select Fees Type' ? 'Max ₹${_fmt.format(bal)}' : '',
            suffixStyle: const TextStyle(color: _textSecondary, fontSize: 11),
            filled: true, fillColor: _bgDark,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _borderColor)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _borderColor)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _accentGreen, width: 2)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: _isSaving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save_rounded, size: 18),
            label: Text(_isSaving ? 'Saving...' : 'Save Payment'),
            style: ElevatedButton.styleFrom(backgroundColor: _accentGreen, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            onPressed: _isSaving ? null : _savePayment,
          ),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _actBtn('Print', Icons.print_rounded, _accentBlue, _printReceipt)),
          const SizedBox(width: 8),
          Expanded(child: _actBtn('Export', Icons.download_rounded, _accentAmber, _exportCsv)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _actBtn('Clear', Icons.clear_rounded, _accentRed, _clearForm)),
          const SizedBox(width: 8),
          Expanded(child: _actBtn('Home', Icons.home_rounded, _textSecondary, () => Navigator.pop(context))),
        ]),
      ]),
    );
  }

  Widget _buildFeeTypeDropdown() => SearchableDropdown<String>(
    value: _selectedFeeType == 'Select Fees Type' ? null : _selectedFeeType,
    items: _feeTypes.where((t) => t != 'Select Fees Type').toList(),
    itemLabel: (t) => t,
    hint: 'Select fees type',
    onChanged: (v) => setState(() {
      _selectedFeeType = v ?? 'Select Fees Type';
      _amountCtrl.text = '0';
    }),
  );

  Widget _roField(String label, String value, IconData icon) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(color: _textSecondary, fontSize: 11)),
      const SizedBox(height: 4),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(color: _bgDark.withOpacity(0.5), borderRadius: BorderRadius.circular(10), border: Border.all(color: _borderColor)),
        child: Row(children: [
          Icon(icon, color: _textSecondary, size: 16), const SizedBox(width: 8),
          Expanded(child: Text(value, style: const TextStyle(color: _textPrimary, fontSize: 13), overflow: TextOverflow.ellipsis)),
        ]),
      ),
    ],
  );

  Widget _dateField() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('Bill Date', style: TextStyle(color: _textSecondary, fontSize: 11)),
      const SizedBox(height: 4),
      TextField(
        controller: _dateCtrl,
        style: const TextStyle(color: _textPrimary, fontSize: 13),
        readOnly: true,
        decoration: InputDecoration(
          suffixIcon: const Icon(Icons.calendar_today_outlined, color: _textSecondary, size: 16),
          filled: true, fillColor: _bgDark,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _borderColor)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _borderColor)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _accentBlue, width: 2)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
        onTap: () async {
          final picked = await showDatePicker(
            context: context, initialDate: DateTime.now(),
            firstDate: DateTime(2020), lastDate: DateTime(2030),
            builder: (ctx, child) => Theme(data: ThemeData.dark(), child: child!),
          );
          if (picked != null) setState(() => _dateCtrl.text = DateFormat('dd/MM/yyyy').format(picked));
        },
      ),
    ],
  );

  Widget _hdr(IconData icon, String title, Color color) => Row(children: [
    Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: color, size: 18)),
    const SizedBox(width: 10),
    Text(title, style: const TextStyle(color: _textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
  ]);

  Widget _lbl(String t) => Text(t, style: const TextStyle(color: _textSecondary, fontSize: 12, fontWeight: FontWeight.w500));

  Widget _actBtn(String label, IconData icon, Color color, VoidCallback onTap) => OutlinedButton.icon(
    icon: Icon(icon, size: 14, color: color),
    label: Text(label, style: TextStyle(color: color, fontSize: 12)),
    style: OutlinedButton.styleFrom(side: BorderSide(color: color.withOpacity(0.4)), padding: const EdgeInsets.symmetric(vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
    onPressed: onTap,
  );
}
