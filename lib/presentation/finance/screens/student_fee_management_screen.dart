import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/auth_provider.dart';
import 'fee_payment_screen.dart';
import '../../shared/widgets/searchable_dropdown.dart';

const Color _bgDark = Color(0xFF0D1117);
const Color _cardDark = Color(0xFF161B22);
const Color _accentGreen = Color(0xFF4CAF50);
const Color _textPrimary = Color(0xFFE6EDF3);
const Color _textSecondary = Color(0xFF8B949E);
const Color _borderColor = Color(0xFF30363D);

class StudentFeeManagementScreen extends ConsumerStatefulWidget {
  const StudentFeeManagementScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<StudentFeeManagementScreen> createState() => _StudentFeeManagementScreenState();
}

class _StudentFeeManagementScreenState extends ConsumerState<StudentFeeManagementScreen> {
  String? _selectedClass;
  String? _selectedSection;
  String? _selectedStudentDocId;
  Map<String, dynamic>? _studentData;
  List<String> _classes = [];
  List<String> _sections = [];
  List<Map<String, dynamic>> _students = [];
  String? get _schoolId => ref.read(currentSessionProvider)?.schoolId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadClasses());
  }

  Future<void> _loadClasses() async {
    if (_schoolId == null) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('schools').doc(_schoolId).collection('student_fee_details').get();
      final classSet = <String>{};
      for (final doc in snap.docs) {
        final c = (doc.data()['stuClass'] ?? doc.data()['className'] ?? '').toString();
        if (c.isNotEmpty) classSet.add(c);
      }
      if (mounted) setState(() => _classes = classSet.toList()..sort());
    } catch (_) {}
  }

  Future<void> _loadSections() async {
    if (_schoolId == null || _selectedClass == null) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('schools').doc(_schoolId).collection('student_fee_details')
          .where('stuClass', isEqualTo: _selectedClass).get();
      final sectionSet = <String>{};
      for (final doc in snap.docs) {
        final s = (doc.data()['stuSection'] ?? '').toString();
        if (s.isNotEmpty) sectionSet.add(s);
      }
      if (mounted) {
        setState(() {
          _sections = sectionSet.toList()..sort();
          _selectedSection = null;
          _selectedStudentDocId = null;
          _studentData = null;
          _students = [];
        });
      }
    } catch (_) {}
  }

  Future<void> _loadStudents() async {
    if (_schoolId == null || _selectedClass == null || _selectedSection == null) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('schools').doc(_schoolId).collection('student_fee_details')
          .where('stuClass', isEqualTo: _selectedClass)
          .where('stuSection', isEqualTo: _selectedSection)
          .orderBy('stuName').get();
      if (mounted) {
        setState(() {
          _students = snap.docs.map((d) {
            final data = d.data();
            data['docId'] = d.id;
            return data;
          }).toList();
          _selectedStudentDocId = null;
          _studentData = null;
        });
      }
    } catch (_) {}
  }

  void _onStudentSelected(String? docId) {
    if (docId == null || docId.isEmpty) return;
    final student = _students.firstWhere((s) => s['docId'].toString() == docId, orElse: () => {});
    if (student.isEmpty) return;
    setState(() {
      _selectedStudentDocId = docId;
      _studentData = student;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 1024;
    final isMobile = screenWidth <= 600;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 12 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(isMobile),
          SizedBox(height: isMobile ? 16 : 20),
          // Top 3 cards row
          isDesktop
              ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: _buildFilterCard(isMobile)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildStudentDetailsCard(isMobile)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildFeesSummaryCard(isMobile)),
                ])
              : Column(children: [
                  _buildFilterCard(isMobile),
                  const SizedBox(height: 12),
                  _buildStudentDetailsCard(isMobile),
                  const SizedBox(height: 12),
                  _buildFeesSummaryCard(isMobile),
                ]),
          if (_studentData != null) ...[
            SizedBox(height: isMobile ? 16 : 20),
            _buildFeeManagementSection(isDesktop, isMobile),
            SizedBox(height: isMobile ? 12 : 16),
            _buildActionButtons(isMobile),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 14 : 18),
      decoration: BoxDecoration(
        color: _cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor),
      ),
      child: Row(children: [
        Container(
          padding: EdgeInsets.all(isMobile ? 8 : 10),
          decoration: BoxDecoration(
            color: _accentGreen.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.account_balance_wallet_rounded, color: _accentGreen, size: isMobile ? 22 : 26),
        ),
        SizedBox(width: isMobile ? 12 : 16),
        Text('Student Fee Management', style: TextStyle(fontSize: isMobile ? 16 : 20, fontWeight: FontWeight.bold, color: _textPrimary)),
      ]),
    );
  }

  Widget _buildFilterCard(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 14 : 18),
      decoration: BoxDecoration(
        color: _cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.filter_alt_rounded, color: _accentGreen, size: isMobile ? 18 : 20),
          SizedBox(width: isMobile ? 6 : 8),
          Text('Filter Student', style: TextStyle(color: _textPrimary, fontWeight: FontWeight.bold, fontSize: isMobile ? 14 : 16)),
        ]),
        SizedBox(height: isMobile ? 12 : 16),
        _buildLabel('Select Class'),
        const SizedBox(height: 6),
        _buildDropdown(
          hint: 'Select Class',
          value: _selectedClass,
          items: _classes,
          onChanged: (v) {
            setState(() => _selectedClass = v);
            _loadSections();
          },
          isMobile: isMobile,
        ),
        SizedBox(height: isMobile ? 10 : 12),
        _buildLabel('Select Section'),
        const SizedBox(height: 6),
        _buildDropdown(
          hint: 'Select Section',
          value: _selectedSection,
          items: _sections,
          onChanged: (v) {
            setState(() => _selectedSection = v);
            _loadStudents();
          },
          isMobile: isMobile,
        ),
        SizedBox(height: isMobile ? 10 : 12),
        _buildLabel('Select Student Name'),
        const SizedBox(height: 6),
        _buildDropdown(
          hint: 'Select Student Name',
          value: _selectedStudentDocId,
          items: _students.map((s) => s['docId'].toString()).toList(),
          onChanged: _onStudentSelected,
          displayMapper: (docId) {
            final s = _students.firstWhere((s) => s['docId'].toString() == docId, orElse: () => {});
            return '${s['stuName'] ?? ''} - ${s['stuId'] ?? ''}';
          },
          isMobile: isMobile,
        ),
      ]),
    );
  }

  Widget _buildStudentDetailsCard(bool isMobile) {
    final s = _studentData;
    return Container(
      padding: EdgeInsets.all(isMobile ? 14 : 18),
      decoration: BoxDecoration(
        color: _cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.person_rounded, color: const Color(0xFF3B82F6), size: isMobile ? 18 : 20),
          SizedBox(width: isMobile ? 6 : 8),
          Text('Student Details', style: TextStyle(color: _textPrimary, fontWeight: FontWeight.bold, fontSize: isMobile ? 14 : 16)),
        ]),
        SizedBox(height: isMobile ? 12 : 16),
        _detailRow('Student Name', s != null ? (s['stuName'] ?? 'Select Student Name').toString() : 'Select Student Name', isMobile),
        _detailRow('Student ID', s != null ? (s['stuId'] ?? 'N/A').toString() : 'N/A', isMobile),
        _detailRow('Class', s != null ? (s['stuClass'] ?? 'Select Class').toString() : 'Select Class', isMobile),
        _detailRow('Section', s != null ? (s['stuSection'] ?? 'Select Section').toString() : 'Select Section', isMobile),
        _detailRow('Phone', s != null ? (s['phoneNumber'] ?? 'N/A').toString() : 'N/A', isMobile),
      ]),
    );
  }

  Widget _buildFeesSummaryCard(bool isMobile) {
    final s = _studentData;
    final arrearTuition = (s?['arrearTuitionFees'] as num?)?.toDouble() ?? 0;
    final arrearExam = (s?['arrearExamFees'] as num?)?.toDouble() ?? 0;
    final arrearVan = (s?['arrearVanFees'] as num?)?.toDouble() ?? 0;
    final totalArrears = arrearTuition + arrearExam + arrearVan;
    final concession = (s?['stuConcessionFees'] as num?)?.toDouble() ?? 0;

    return Container(
      padding: EdgeInsets.all(isMobile ? 14 : 18),
      decoration: BoxDecoration(
        color: _cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.receipt_long_rounded, color: _accentGreen, size: isMobile ? 18 : 20),
          SizedBox(width: isMobile ? 6 : 8),
          Text('Fees Summary', style: TextStyle(color: _textPrimary, fontWeight: FontWeight.bold, fontSize: isMobile ? 14 : 16)),
        ]),
        SizedBox(height: isMobile ? 12 : 16),
        _summaryRow('Arrear Fees', '₹${totalArrears.toStringAsFixed(0)}', totalArrears > 0 ? const Color(0xFFEF4444) : _accentGreen, isMobile),
        SizedBox(height: isMobile ? 8 : 10),
        _summaryRow('Concession Fees', '₹${concession.toStringAsFixed(0)}', const Color(0xFF3B82F6), isMobile),
      ]),
    );
  }

  Widget _buildFeeManagementSection(bool isDesktop, bool isMobile) {
    final s = _studentData;
    if (s == null) return const SizedBox.shrink();

    const totalColor = Color(0xFFF59E0B);
    const paidColor = Color(0xFF10B981);
    const balanceColor = Color(0xFFEF4444);

    return Container(
      padding: EdgeInsets.all(isMobile ? 14 : 18),
      decoration: BoxDecoration(
        color: _cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.account_balance_wallet_rounded, color: _accentGreen, size: isMobile ? 18 : 20),
          SizedBox(width: isMobile ? 6 : 8),
          Text('Fee Management', style: TextStyle(color: _textPrimary, fontWeight: FontWeight.bold, fontSize: isMobile ? 14 : 16)),
        ]),
        SizedBox(height: isMobile ? 12 : 16),
        isDesktop
            ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: _buildFeeBreakdownCard('TOTAL FEES', totalColor, s, 'Total', isMobile)),
                const SizedBox(width: 12),
                Expanded(child: _buildFeeBreakdownCard('PAID FEES', paidColor, s, 'Paid', isMobile)),
                const SizedBox(width: 12),
                Expanded(child: _buildFeeBreakdownCard('BALANCE FEES', balanceColor, s, 'Balance', isMobile)),
              ])
            : Column(children: [
                _buildFeeBreakdownCard('TOTAL FEES', totalColor, s, 'Total', isMobile),
                const SizedBox(height: 12),
                _buildFeeBreakdownCard('PAID FEES', paidColor, s, 'Paid', isMobile),
                const SizedBox(height: 12),
                _buildFeeBreakdownCard('BALANCE FEES', balanceColor, s, 'Balance', isMobile),
              ]),
      ]),
    );
  }

  Widget _buildFeeBreakdownCard(String title, Color accent, Map<String, dynamic> s, String type, bool isMobile) {
    double tuition = 0, exam = 0, van = 0, admission = 0, total = 0;
    double tuitionArr = 0, examArr = 0, vanArr = 0, admissionArr = 0;

    switch (type) {
      case 'Total':
        tuition = (s['stuTotalTutionFees'] as num?)?.toDouble() ?? 0;
        exam = (s['stuTotalExamFees'] as num?)?.toDouble() ?? 0;
        van = (s['stuTotalVanFees'] as num?)?.toDouble() ?? 0;
        admission = (s['stuTotalAdmissionFees'] as num?)?.toDouble() ?? 0;
        tuitionArr = (s['arrearTuitionFees'] as num?)?.toDouble() ?? 0;
        examArr = (s['arrearExamFees'] as num?)?.toDouble() ?? 0;
        vanArr = (s['arrearVanFees'] as num?)?.toDouble() ?? 0;
        admissionArr = (s['arrearAdmissionFees'] as num?)?.toDouble() ?? 0;
        break;
      case 'Paid':
        tuition = (s['stuPaidTutionFees'] as num?)?.toDouble() ?? 0;
        exam = (s['stuPaidExamFees'] as num?)?.toDouble() ?? 0;
        van = (s['studPaidVanFees'] as num?)?.toDouble() ?? 0;
        admission = (s['stuPaidAdmissionFees'] as num?)?.toDouble() ?? 0;
        tuitionArr = (s['stuPaidArrearTutionFees'] as num?)?.toDouble() ?? 0;
        examArr = (s['stuPaidArrearExamFees'] as num?)?.toDouble() ?? 0;
        vanArr = (s['stuPaidArrearVanFees'] as num?)?.toDouble() ?? 0;
        admissionArr = (s['stuPaidArrearAdmissionFees'] as num?)?.toDouble() ?? 0;
        break;
      case 'Balance':
        tuition = (s['stuBalTutionFees'] as num?)?.toDouble() ?? 0;
        exam = (s['stuBalExamFees'] as num?)?.toDouble() ?? 0;
        van = (s['stuBalVanFees'] as num?)?.toDouble() ?? 0;
        admission = (s['stuBalAdmissionFees'] as num?)?.toDouble() ?? 0;
        tuitionArr = (s['balanceArrearTuitionFees'] as num?)?.toDouble() ?? 0;
        examArr = (s['balanceArrearExamFees'] as num?)?.toDouble() ?? 0;
        vanArr = (s['balanceArrearVanFees'] as num?)?.toDouble() ?? 0;
        admissionArr = (s['balanceArrearAdmissionFees'] as num?)?.toDouble() ?? 0;
        break;
    }
    total = tuition + exam + van + admission;

    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 14),
      decoration: BoxDecoration(
        color: _bgDark,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withOpacity(0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: isMobile ? 6 : 8),
          decoration: BoxDecoration(color: accent.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
          child: Center(child: Text(title, style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: isMobile ? 12 : 13))),
        ),
        SizedBox(height: isMobile ? 8 : 10),
        _feeRow('', 'Regular', 'Arrears', accent, isHeader: true, isMobile: isMobile),
        _feeRow('Tuition Fees', '₹${tuition.toStringAsFixed(0)}', '₹${tuitionArr.toStringAsFixed(0)}', accent, isMobile: isMobile),
        _feeRow('Exam Fees', '₹${exam.toStringAsFixed(0)}', '₹${examArr.toStringAsFixed(0)}', accent, isMobile: isMobile),
        _feeRow('Van Fees', '₹${van.toStringAsFixed(0)}', '₹${vanArr.toStringAsFixed(0)}', accent, isMobile: isMobile),
        _feeRow('Admission Fees', '₹${admission.toStringAsFixed(0)}', '₹${admissionArr.toStringAsFixed(0)}', accent, isMobile: isMobile),
        Divider(color: _borderColor, height: isMobile ? 12 : 14),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('TOTAL', style: TextStyle(color: _textPrimary, fontWeight: FontWeight.bold, fontSize: isMobile ? 11 : 12)),
          Text('₹${total.toStringAsFixed(0)}', style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: isMobile ? 13 : 14)),
        ]),
      ]),
    );
  }

  Widget _feeRow(String label, String regular, String arrears, Color accent, {bool isHeader = false, bool isMobile = false}) {
    final style = isHeader
        ? TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: isMobile ? 10 : 11)
        : TextStyle(color: _textPrimary, fontSize: isMobile ? 11 : 12);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: EdgeInsets.symmetric(vertical: isMobile ? 5 : 6, horizontal: isMobile ? 6 : 8),
      decoration: isHeader
          ? null
          : BoxDecoration(
              color: accent.withOpacity(0.08),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: accent.withOpacity(0.15)),
            ),
      child: Row(children: [
        if (!isHeader) Icon(Icons.circle, size: 5, color: accent),
        if (!isHeader) const SizedBox(width: 6),
        Expanded(
            flex: 3,
            child: Text(label,
                style: TextStyle(
                    color: isHeader ? _textSecondary : _textPrimary,
                    fontSize: isMobile ? 11 : 12,
                    fontWeight: isHeader ? FontWeight.normal : FontWeight.w500))),
        Expanded(flex: 2, child: Text(regular, style: style, textAlign: TextAlign.right)),
        const SizedBox(width: 8),
        Expanded(flex: 2, child: Text(arrears, style: style, textAlign: TextAlign.right)),
      ]),
    );
  }

  Widget _buildActionButtons(bool isMobile) {
    return Wrap(
      spacing: isMobile ? 8 : 12,
      runSpacing: isMobile ? 8 : 12,
      children: [
        _actionBtn(Icons.payment_rounded, 'Make Payment', _accentGreen, _navigateToPayment, isMobile),
        _actionBtn(Icons.clear_rounded, 'Clear', _textSecondary, _clearSelection, isMobile),
        _actionBtn(Icons.history_rounded, 'Bill History', const Color(0xFF3B82F6), _showBillHistory, isMobile),
      ],
    );
  }

  Widget _actionBtn(IconData icon, String label, Color color, VoidCallback onTap, bool isMobile) {
    return ElevatedButton.icon(
      icon: Icon(icon, size: isMobile ? 16 : 18),
      label: Text(label, style: TextStyle(fontSize: isMobile ? 11 : 13)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.15),
        foregroundColor: color,
        side: BorderSide(color: color.withOpacity(0.3)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isMobile ? 8 : 10)),
        padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20, vertical: isMobile ? 10 : 14),
      ),
      onPressed: onTap,
    );
  }

  void _navigateToPayment() {
    if (_studentData == null || _selectedStudentDocId == null) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => FeePaymentScreen(
        studentData: _studentData!,
        studentDocId: _selectedStudentDocId!,
      ),
    ).then((_) {
      if (_selectedStudentDocId != null && _schoolId != null) {
        FirebaseFirestore.instance
            .collection('schools')
            .doc(_schoolId)
            .collection('student_fee_details')
            .doc(_selectedStudentDocId)
            .get()
            .then((doc) {
          if (doc.exists && mounted) {
            final data = doc.data()!;
            data['docId'] = doc.id;
            setState(() => _studentData = data);
          }
        });
      }
    });
  }

  void _showBillHistory() {
    if (_studentData == null || _schoolId == null) return;
    final stuId = (_studentData!['stuId'] ?? '').toString();

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: _cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 700, maxHeight: 500),
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Text('Bill History', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _textPrimary)),
              const Spacer(),
              IconButton(icon: const Icon(Icons.close_rounded, color: _textSecondary), onPressed: () => Navigator.pop(ctx)),
            ]),
            const SizedBox(height: 16),
            Expanded(
              child: FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
                future: FirebaseFirestore.instance
                    .collection('schools')
                    .doc(_schoolId)
                    .collection('bills')
                    .where('stuId', isEqualTo: stuId)
                    .where('isDeleted', isEqualTo: false)
                    .orderBy('billDate', descending: true)
                    .get(),
                builder: (ctx, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: _accentGreen));
                  }
                  if (!snap.hasData || snap.data!.docs.isEmpty) {
                    return const Center(child: Text('No bills found', style: TextStyle(color: _textSecondary)));
                  }

                  return SingleChildScrollView(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(_bgDark),
                        columns: const [
                          DataColumn(label: Text('Bill#', style: TextStyle(color: _accentGreen, fontWeight: FontWeight.bold, fontSize: 11))),
                          DataColumn(label: Text('Date', style: TextStyle(color: _accentGreen, fontWeight: FontWeight.bold, fontSize: 11))),
                          DataColumn(label: Text('Type', style: TextStyle(color: _accentGreen, fontWeight: FontWeight.bold, fontSize: 11))),
                          DataColumn(label: Text('Amount', style: TextStyle(color: _accentGreen, fontWeight: FontWeight.bold, fontSize: 11))),
                        ],
                        rows: snap.data!.docs.map((doc) {
                          final d = doc.data();
                          final date = (d['billDate'] as Timestamp?)?.toDate();
                          return DataRow(cells: [
                            DataCell(Text('${d['billId'] ?? ''}', style: const TextStyle(color: _textPrimary, fontSize: 12))),
                            DataCell(Text(date != null ? DateFormat('dd/MM/yyyy').format(date) : '', style: const TextStyle(color: _textPrimary, fontSize: 12))),
                            DataCell(Text((d['revenueType'] ?? '').toString(), style: const TextStyle(color: _textSecondary, fontSize: 12))),
                            DataCell(Text('₹${((d['revenueAmount'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)}',
                                style: const TextStyle(color: _accentGreen, fontWeight: FontWeight.bold, fontSize: 12))),
                          ]);
                        }).toList(),
                      ),
                    ),
                  );
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }

  void _clearSelection() {
    setState(() {
      _selectedClass = null;
      _selectedSection = null;
      _selectedStudentDocId = null;
      _studentData = null;
      _sections = [];
      _students = [];
    });
  }

  // Helper widgets
  Widget _buildLabel(String text) {
    return Text(text, style: const TextStyle(color: _textSecondary, fontSize: 12, fontWeight: FontWeight.w500));
  }

  Widget _buildDropdown(
      {required String hint,
      required String? value,
      required List<String> items,
      required Function(String?) onChanged,
      String Function(String)? displayMapper,
      bool isMobile = false}) {
    return SearchableDropdown<String>(
      value: (value != null && items.contains(value)) ? value : null,
      hint: hint,
      items: items,
      itemLabel: (v) => displayMapper != null ? displayMapper(v) : v,
      onChanged: onChanged,
    );
  }

  Widget _detailRow(String label, String value, bool isMobile) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: isMobile ? 3 : 4),
      child: Row(children: [
        Text('$label: ', style: TextStyle(color: _textSecondary, fontSize: isMobile ? 11 : 12)),
        Expanded(child: Text(value, style: TextStyle(color: _textPrimary, fontWeight: FontWeight.w500, fontSize: isMobile ? 11 : 12))),
      ]),
    );
  }

  Widget _summaryRow(String label, String value, Color color, bool isMobile) {
    return Row(children: [
      Icon(Icons.circle, size: isMobile ? 6 : 8, color: color),
      SizedBox(width: isMobile ? 6 : 8),
      Text(label, style: TextStyle(color: _textSecondary, fontSize: isMobile ? 11 : 12)),
      const Spacer(),
      Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: isMobile ? 13 : 14)),
    ]);
  }
}
