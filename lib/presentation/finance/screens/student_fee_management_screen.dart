import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

import '../../../core/providers/auth_provider.dart';
import '../../../data/repositories/fee_repository.dart';
import '../../../data/services/fee_structure_to_payment_mapper.dart';
import '../../../domain/entities/academic_year.dart';
import '../../shared/widgets/searchable_dropdown.dart';
import '../widgets/ledger_fee_management_card.dart';

const Color _bgDark = Color(0xFF0D1117);
const Color _cardDark = Color(0xFF161B22);
const Color _accentGreen = Color(0xFF4CAF50);
const Color _accentBlue = Color(0xFF3B82F6);
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

  /// Source of the displayed tuition value. Used to surface a small badge
  /// so admins can tell whether the figure is coming from the V2 fee
  /// structure or from the legacy sheet upload.
  String _tuitionSource = 'stored';

  /// Picks the academic year to use when loading the [StudentFeeLedger].
  /// Prefers the value stored on the student record (set during sheet
  /// upload / onboarding) and falls back to the date-derived current AY
  /// so the screen still renders sensibly when the field is missing.
  String _resolveStudentAcademicYear() {
    final ay = _studentData?['academicYear']?.toString() ?? '';
    if (ay.isNotEmpty) return ay;
    return AcademicYear.getCurrentYearCode();
  }

  void _onStudentSelected(String? docId) {
    if (docId == null || docId.isEmpty) return;
    final student = _students.firstWhere(
        (s) => s['docId'].toString() == docId,
        orElse: () => {});
    if (student.isEmpty) return;
    setState(() {
      _selectedStudentDocId = docId;
      _studentData = Map<String, dynamic>.from(student);
      _tuitionSource = 'stored';
    });
    // Asynchronously override tuition + totals from the active V2 structure.
    _applyV2Override();
  }

  /// Looks up the active FeeStructureV2 for the selected student's class
  /// and, when found, overrides the tuition figure with the sum of all V2
  /// term amounts. Recomputes total/balance fields so the screen always
  /// reflects the source-of-truth structure even when the stored
  /// `student_fee_details` row was uploaded with stale values.
  Future<void> _applyV2Override() async {
    if (_schoolId == null || _studentData == null) return;
    final className = (_studentData!['stuClass'] ??
            _studentData!['className'] ??
            '')
        .toString();
    if (className.isEmpty) return;
    final ay = (_studentData!['academicYear']?.toString().isNotEmpty ?? false)
        ? _studentData!['academicYear'].toString()
        : AcademicYear.getCurrentYearCode();

    final repo = ref.read(feeRepositoryProvider);
    final v2 = await repo.getFeeStructureV2ByClass(_schoolId!, className, ay);
    if (v2 == null || !mounted) return;

    final v2Tuition = FeeStructureToPaymentMapper.totalAmountForStructure(v2);
    final s = _studentData!;
    final exam = (s['stuTotalExamFees'] as num?)?.toDouble() ?? 0;
    final van = (s['stuTotalVanFees'] as num?)?.toDouble() ?? 0;
    final admission =
        (s['stuTotalAdmissionFees'] as num?)?.toDouble() ?? 0;
    final concession = (s['stuConcessionFees'] as num?)?.toDouble() ?? 0;
    final paidTuition = (s['stuPaidTutionFees'] as num?)?.toDouble() ?? 0;
    final paidExam = (s['stuPaidExamFees'] as num?)?.toDouble() ?? 0;
    final paidVan = (s['studPaidVanFees'] as num?)?.toDouble() ?? 0;
    final paidAdmission =
        (s['stuPaidAdmissionFees'] as num?)?.toDouble() ?? 0;
    final arrearTuition = (s['arrearTuitionFees'] as num?)?.toDouble() ?? 0;
    final arrearExam = (s['arrearExamFees'] as num?)?.toDouble() ?? 0;
    final arrearVan = (s['arrearVanFees'] as num?)?.toDouble() ?? 0;
    final arrearAdmission =
        (s['arrearAdmissionFees'] as num?)?.toDouble() ?? 0;

    final newTotal = v2Tuition + exam + van + admission;
    final newBalTuition =
        v2Tuition + arrearTuition - concession - paidTuition;
    final newBalExam = exam + arrearExam - paidExam;
    final newBalVan = van + arrearVan - paidVan;
    final newBalAdmission =
        admission + arrearAdmission - paidAdmission;
    final newBalTotal =
        newBalTuition + newBalExam + newBalVan + newBalAdmission;

    setState(() {
      _studentData = {
        ..._studentData!,
        'stuTotalTutionFees': v2Tuition,
        'stuTotalFees': newTotal,
        'stuBalTutionFees': newBalTuition,
        'stuBalExamFees': newBalExam,
        'stuBalVanFees': newBalVan,
        'stuBalAdmissionFees': newBalAdmission,
        'stuBalTotalFees': newBalTotal,
      };
      _tuitionSource = 'v2';
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
              ? IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: _buildFilterCard(isMobile)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildStudentDetailsCard(isMobile)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildFeesSummaryCard(isMobile)),
                    ],
                  ),
                )
              : Column(children: [
                  _buildFilterCard(isMobile),
                  const SizedBox(height: 12),
                  _buildStudentDetailsCard(isMobile),
                  const SizedBox(height: 12),
                  _buildFeesSummaryCard(isMobile),
                ]),
          if (_studentData != null && _schoolId != null) ...[
            SizedBox(height: isMobile ? 16 : 20),
            // New ledger-driven Fee Management card. Renders dynamic
            // per-category rows for the current AY plus a separate group
            // per prior-AY arrears block carried forward by Year Close.
            LedgerFeeManagementCard(
              key: ValueKey('ledger-${_selectedStudentDocId}-${_resolveStudentAcademicYear()}'),
              schoolId: _schoolId!,
              studentId: (_studentData!['stuId'] ?? '').toString(),
              academicYear: _resolveStudentAcademicYear(),
              studentName: (_studentData!['stuName'] ?? '').toString(),
              className: (_studentData!['stuClass'] ?? '').toString(),
              section: (_studentData!['stuSection'] ?? '').toString(),
              parentName: (_studentData!['stuParentName'] ??
                      _studentData!['parentName'] ??
                      '')
                  .toString(),
              parentPhone: (_studentData!['stuParentMobile'] ??
                      _studentData!['parentPhone'] ??
                      '')
                  .toString(),
              onBillHistory: _showBillHistory,
            ),
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
          const SizedBox(width: 8),
          if (_tuitionSource == 'v2')
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _accentGreen.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: _accentGreen.withValues(alpha: 0.4)),
              ),
              child: const Text('TUITION FROM V2',
                  style: TextStyle(
                      color: _accentGreen,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5)),
            ),
        ]),
        SizedBox(height: isMobile ? 12 : 16),
        _summaryRow('Arrear Fees', '₹${totalArrears.toStringAsFixed(0)}', totalArrears > 0 ? const Color(0xFFEF4444) : _accentGreen, isMobile),
        SizedBox(height: isMobile ? 8 : 10),
        _summaryRow('Concession Fees', '₹${concession.toStringAsFixed(0)}', const Color(0xFF3B82F6), isMobile),
      ]),
    );
  }

  void _showBillHistory() {
    if (_studentData == null || _schoolId == null) return;
    final stuId = (_studentData!['stuId'] ?? '').toString();

    showDialog(
      context: context,
      builder: (ctx) => Builder(
        builder: (context) {
          final screenSize = MediaQuery.of(context).size;
          final isMobile = screenSize.width < 600;

          return Dialog(
            backgroundColor: _cardDark,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Container(
              constraints: BoxConstraints(
                maxWidth: isMobile ? double.infinity : 900,
                maxHeight: isMobile ? 600 : 700,
              ),
              width: isMobile ? double.infinity : null,
              padding: EdgeInsets.all(isMobile ? 16 : 24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    padding: EdgeInsets.all(isMobile ? 8 : 10),
                    decoration: BoxDecoration(
                      color: _accentGreen.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.receipt_long_rounded, color: _accentGreen, size: isMobile ? 20 : 24),
                  ),
                  SizedBox(width: isMobile ? 12 : 16),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Payment History', style: TextStyle(fontSize: isMobile ? 18 : 22, fontWeight: FontWeight.bold, color: _textPrimary)),
                      SizedBox(height: isMobile ? 2 : 4),
                      Text('View all fee payments and transactions', style: TextStyle(fontSize: isMobile ? 11 : 13, color: _textSecondary)),
                    ]),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: _textSecondary, size: isMobile ? 24 : 28),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ]),
                SizedBox(height: isMobile ? 16 : 20),
                Expanded(
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: _fetchPaymentHistory(stuId),
                    builder: (ctx, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator(color: _accentGreen));
                      }
                      if (!snap.hasData || snap.data!.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.receipt_long_outlined, color: _textSecondary.withOpacity(0.5), size: isMobile ? 48 : 64),
                              SizedBox(height: isMobile ? 12 : 16),
                              Text('No payments found', style: TextStyle(color: _textSecondary, fontSize: isMobile ? 14 : 16)),
                            ],
                          ),
                        );
                      }

                      if (isMobile) {
                        // Mobile: Card layout
                        return ListView.separated(
                          padding: EdgeInsets.zero,
                          itemCount: snap.data!.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (ctx, index) {
                            final d = snap.data![index];
                            final date = d['date'] as DateTime?;
                            final receipt = d['receipt'] ?? d['id'];
                            final description = d['description']?.toString() ?? '';
                            final amount = (d['amount'] as num?)?.toDouble() ?? 0;

                            return Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: _bgDark,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: _borderColor),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          receipt?.toString() ?? '',
                                          style: const TextStyle(color: _textSecondary, fontSize: 12),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Text(
                                        '₹${amount.toStringAsFixed(0)}',
                                        style: const TextStyle(color: _accentGreen, fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    description,
                                    style: const TextStyle(color: _textPrimary, fontSize: 14),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(Icons.calendar_today_rounded, color: _textSecondary, size: 14),
                                      const SizedBox(width: 4),
                                      Text(
                                        date != null ? DateFormat('dd MMM yyyy').format(date) : 'N/A',
                                        style: const TextStyle(color: _textSecondary, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.visibility_rounded, color: _accentBlue, size: 18),
                                        onPressed: () => _showBillDetails(d),
                                        tooltip: 'View Bill',
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                      const SizedBox(width: 16),
                                      IconButton(
                                        icon: const Icon(Icons.print_rounded, color: _textSecondary, size: 18),
                                        onPressed: () => _printBill(d),
                                        tooltip: 'Print Bill',
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                      const SizedBox(width: 16),
                                      IconButton(
                                        icon: const Icon(Icons.download_rounded, color: _textSecondary, size: 18),
                                        onPressed: () => _downloadBill(d),
                                        tooltip: 'Download Bill',
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      }

                      // Desktop: Table layout
                      return SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Table header
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: _bgDark,
                                borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
                                border: Border.all(color: _borderColor),
                              ),
                              child: const Row(
                                children: [
                                  Expanded(flex: 1, child: Text('Date', style: TextStyle(color: _accentGreen, fontWeight: FontWeight.bold, fontSize: 12))),
                                  Expanded(flex: 2, child: Text('Receipt #', style: TextStyle(color: _accentGreen, fontWeight: FontWeight.bold, fontSize: 12))),
                                  Expanded(flex: 3, child: Text('Description', style: TextStyle(color: _accentGreen, fontWeight: FontWeight.bold, fontSize: 12))),
                                  Expanded(flex: 1, child: Text('Amount', style: TextStyle(color: _accentGreen, fontWeight: FontWeight.bold, fontSize: 12))),
                                  Expanded(flex: 1, child: Text('Actions', style: TextStyle(color: _accentGreen, fontWeight: FontWeight.bold, fontSize: 12))),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...snap.data!.asMap().entries.map((entry) {
                              final index = entry.key;
                              final d = entry.value;
                              final date = d['date'] as DateTime?;
                              final receipt = d['receipt'] ?? d['id'];
                              final description = d['description']?.toString() ?? '';
                              final amount = (d['amount'] as num?)?.toDouble() ?? 0;

                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: index % 2 == 0 ? _bgDark : _cardDark,
                                  border: Border.all(color: _borderColor),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(flex: 1, child: Text(date != null ? DateFormat('dd/MM/yyyy').format(date) : 'N/A', style: const TextStyle(color: _textPrimary, fontSize: 12))),
                                    Expanded(flex: 2, child: Text(receipt?.toString() ?? '', style: const TextStyle(color: _textPrimary, fontSize: 12))),
                                    Expanded(flex: 3, child: Text(description, style: const TextStyle(color: _textPrimary, fontSize: 12))),
                                    Expanded(flex: 1, child: Text('₹${amount.toStringAsFixed(0)}', style: const TextStyle(color: _accentGreen, fontWeight: FontWeight.bold, fontSize: 12))),
                                    Expanded(
                                      flex: 1,
                                      child: Row(
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.visibility_rounded, color: _accentBlue, size: 18),
                                            onPressed: () => _showBillDetails(d),
                                            tooltip: 'View Bill',
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.print_rounded, color: _textSecondary, size: 18),
                                            onPressed: () => _printBill(d),
                                            tooltip: 'Print Bill',
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.download_rounded, color: _textSecondary, size: 18),
                                            onPressed: () => _downloadBill(d),
                                            tooltip: 'Download Bill',
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ]),
            ),
          );
        },
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _fetchPaymentHistory(String studentId) async {
    if (_schoolId == null) return [];
    
    print('[_fetchPaymentHistory] Fetching for studentId: $studentId, schoolId: $_schoolId');
    final results = <Map<String, dynamic>>[];
    
    // Fetch term fee payments
    try {
      final termPayments = await FirebaseFirestore.instance
          .collection('schools')
          .doc(_schoolId)
          .collection('termFeePayments')
          .where('studentId', isEqualTo: studentId)
          .where('isDeleted', isEqualTo: false)
          .orderBy('paidAt', descending: true)
          .get();
      
      print('[_fetchPaymentHistory] Found ${termPayments.docs.length} term payments');
      for (final doc in termPayments.docs) {
        final d = doc.data();
        final paidAt = (d['paidAt'] as Timestamp?)?.toDate();
        if (paidAt != null) {
          // Build description with fee breakdown
          String description = (d['termName'] ?? 'Term Fee').toString();
          
          // Check if this is a multi-term payment with components
          final components = d['components'] as List?;
          if (components != null && components.isNotEmpty) {
            final breakdown = components.map((c) {
              final comp = c as Map<String, dynamic>;
              // Handle both term allocations (termName) and ad-hoc allocations (itemName)
              final name = (comp['termName'] as String?) ?? 
                          (comp['itemName'] as String?) ?? 
                          (comp['categoryCode'] as String?) ?? 'Fee';
              final amount = (comp['amount'] as num?)?.toDouble() ?? 0;
              return '$name (₹${amount.toStringAsFixed(0)})';
            }).join(', ');
            description = breakdown;
          }
          
          results.add({
            'id': doc.id,
            'receipt': d['receiptNumber'],
            'date': paidAt,
            'description': description,
            'amount': d['amount'],
            'type': 'term',
          });
        }
      }
    } catch (e) {
      print('[_fetchPaymentHistory] Error fetching term payments: $e');
    }
    
    // Sort by date descending
    results.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));
    
    print('[_fetchPaymentHistory] Total results: ${results.length}');
    return results;
  }

  void _showBillDetails(Map<String, dynamic> billData) {
    showDialog(
      context: context,
      builder: (ctx) => Builder(
        builder: (context) {
          final screenSize = MediaQuery.of(context).size;
          final isMobile = screenSize.width < 600;

          return Dialog(
            backgroundColor: _cardDark,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              constraints: BoxConstraints(
                maxWidth: isMobile ? double.infinity : 600,
                maxHeight: isMobile ? 700 : 800,
              ),
              width: isMobile ? double.infinity : null,
              padding: EdgeInsets.all(isMobile ? 16 : 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Icon(Icons.receipt_rounded, color: _accentGreen, size: isMobile ? 24 : 28),
                      SizedBox(width: isMobile ? 8 : 12),
                      Expanded(
                        child: Text('Fee Receipt', style: TextStyle(fontSize: isMobile ? 18 : 20, fontWeight: FontWeight.bold, color: _textPrimary)),
                      ),
                      IconButton(
                        icon: Icon(Icons.close_rounded, color: _textSecondary, size: isMobile ? 24 : 28),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  SizedBox(height: isMobile ? 16 : 20),

                  // School Info
                  Container(
                    padding: EdgeInsets.all(isMobile ? 12 : 16),
                    decoration: BoxDecoration(
                      color: _bgDark,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('School Name', style: TextStyle(color: _textSecondary, fontSize: isMobile ? 11 : 12)),
                        SizedBox(height: isMobile ? 3 : 4),
                        Text((_studentData!['schoolName'] ?? 'School').toString(), style: TextStyle(color: _textPrimary, fontSize: isMobile ? 14 : 16, fontWeight: FontWeight.bold)),
                        SizedBox(height: isMobile ? 10 : 12),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Receipt #', style: TextStyle(color: _textSecondary, fontSize: isMobile ? 11 : 12)),
                                  Text((billData['receipt'] ?? '').toString(), style: TextStyle(color: _textPrimary, fontSize: isMobile ? 12 : 14, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Date', style: TextStyle(color: _textSecondary, fontSize: isMobile ? 11 : 12)),
                                  Text(billData['date'] != null ? DateFormat('dd MMM yyyy').format(billData['date'] as DateTime) : 'N/A', style: TextStyle(color: _textPrimary, fontSize: isMobile ? 12 : 14, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: isMobile ? 12 : 16),

                  // Student Info
                  Container(
                    padding: EdgeInsets.all(isMobile ? 12 : 16),
                    decoration: BoxDecoration(
                      color: _bgDark,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Student Details', style: TextStyle(color: _textSecondary, fontSize: isMobile ? 11 : 12)),
                        SizedBox(height: isMobile ? 6 : 8),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Name', style: TextStyle(color: _textSecondary, fontSize: isMobile ? 10 : 11)),
                                  Text((_studentData!['stuName'] ?? 'Student').toString(), style: TextStyle(color: _textPrimary, fontSize: isMobile ? 12 : 14)),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Class', style: TextStyle(color: _textSecondary, fontSize: isMobile ? 10 : 11)),
                                  Text((_studentData!['className'] ?? '-').toString(), style: TextStyle(color: _textPrimary, fontSize: isMobile ? 12 : 14)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: isMobile ? 8 : 12),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Section', style: TextStyle(color: _textSecondary, fontSize: isMobile ? 10 : 11)),
                                  Text((_studentData!['section'] ?? '-').toString(), style: TextStyle(color: _textPrimary, fontSize: isMobile ? 12 : 14)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: isMobile ? 12 : 16),

                  // Bill Description
                  Container(
                    padding: EdgeInsets.all(isMobile ? 12 : 16),
                    decoration: BoxDecoration(
                      color: _bgDark,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Bill Description', style: TextStyle(color: _textSecondary, fontSize: isMobile ? 11 : 12)),
                        SizedBox(height: isMobile ? 6 : 8),
                        Text(
                          (billData['description'] ?? 'Fee Payment').toString(),
                          style: TextStyle(color: _textPrimary, fontSize: isMobile ? 12 : 14),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: isMobile ? 12 : 16),

                  // Fee Breakdown Table
                  Container(
                    decoration: BoxDecoration(
                      color: _bgDark,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Table Header
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16, vertical: isMobile ? 10 : 12),
                          decoration: BoxDecoration(
                            color: _accentGreen.withOpacity(0.1),
                            borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
                          ),
                          child: Row(
                            children: [
                              Expanded(flex: 3, child: Text('Description', style: TextStyle(color: _accentGreen, fontWeight: FontWeight.bold, fontSize: isMobile ? 11 : 12))),
                              Expanded(flex: 1, child: Text('Amount', style: TextStyle(color: _accentGreen, fontWeight: FontWeight.bold, fontSize: isMobile ? 11 : 12))),
                            ],
                          ),
                        ),
                        // Table Rows
                        _buildFeeBreakdownRows(billData),
                        // Total
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16, vertical: isMobile ? 10 : 12),
                          decoration: BoxDecoration(
                            color: _accentGreen.withOpacity(0.1),
                            borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(12), bottomRight: Radius.circular(12)),
                          ),
                          child: Row(
                            children: [
                              Expanded(flex: 3, child: Text('Total', style: TextStyle(color: _textPrimary, fontWeight: FontWeight.bold, fontSize: isMobile ? 12 : 14))),
                              Expanded(flex: 1, child: Text('₹${((billData['amount'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)}', style: TextStyle(color: _accentGreen, fontWeight: FontWeight.bold, fontSize: isMobile ? 14 : 16))),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: isMobile ? 16 : 20),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _printBill(billData),
                          icon: Icon(Icons.print_rounded, size: isMobile ? 16 : 18),
                          label: Text('Print', style: TextStyle(fontSize: isMobile ? 14 : 16)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _accentBlue,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: isMobile ? 10 : 12),
                          ),
                        ),
                      ),
                      SizedBox(width: isMobile ? 8 : 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _downloadBill(billData),
                          icon: Icon(Icons.download_rounded, size: isMobile ? 16 : 18),
                          label: Text('Download', style: TextStyle(fontSize: isMobile ? 14 : 16)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _accentGreen,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: isMobile ? 10 : 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFeeBreakdownRows(Map<String, dynamic> billData) {
    final description = billData['description']?.toString() ?? '';
    
    // Parse the description to extract individual fee items
    // Format: "Term 1 (₹5000), Van Fees (₹2000), Sports Fees (₹1500)"
    final feeItems = description.split(',').map((item) {
      final match = RegExp(r'(.+?)\s*\(₹([\d,]+)\)').firstMatch(item.trim());
      if (match != null) {
        return {
          'name': match.group(1)?.trim() ?? item.trim(),
          'amount': double.tryParse(match.group(2)?.replaceAll(',', '') ?? '0') ?? 0.0,
        };
      }
      return {'name': item.trim(), 'amount': 0.0};
    }).toList();

    return Column(
      children: feeItems.map((fee) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: _borderColor, width: 0.5)),
          ),
          child: Row(
            children: [
              Expanded(flex: 3, child: Text((fee['name'] ?? '').toString(), style: const TextStyle(color: _textPrimary, fontSize: 12))),
              Expanded(flex: 1, child: Text('₹${double.tryParse(fee['amount'].toString())?.toStringAsFixed(0) ?? '0'}', style: const TextStyle(color: _textPrimary, fontSize: 12))),
            ],
          ),
        );
      }).toList(),
    );
  }

  void _printBill(Map<String, dynamic> billData) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Select Copy Type', style: TextStyle(color: _textPrimary, fontSize: 18)),
        content: const Text('Choose which copy to print:', style: TextStyle(color: _textSecondary)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _generateAndPrintBill(billData, 'Student Copy');
            },
            child: const Text('Student Copy', style: TextStyle(color: _accentGreen)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _generateAndPrintBill(billData, 'School Copy');
            },
            child: const Text('School Copy', style: TextStyle(color: _accentBlue)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: _textSecondary)),
          ),
        ],
      ),
    );
  }

  void _downloadBill(Map<String, dynamic> billData) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Select Copy Type', style: TextStyle(color: _textPrimary, fontSize: 18)),
        content: const Text('Choose which copy to download:', style: TextStyle(color: _textSecondary)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _generateAndDownloadBill(billData, 'Student Copy');
            },
            child: const Text('Student Copy', style: TextStyle(color: _accentGreen)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _generateAndDownloadBill(billData, 'School Copy');
            },
            child: const Text('School Copy', style: TextStyle(color: _accentBlue)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: _textSecondary)),
          ),
        ],
      ),
    );
  }

  Future<void> _generateAndPrintBill(Map<String, dynamic> billData, String copyType) async {
    final pdf = await _generateBillPDF(billData, copyType);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) => pdf,
      name: 'Fee_Receipt_${billData['receipt']}.pdf',
    );
  }

  Future<void> _generateAndDownloadBill(Map<String, dynamic> billData, String copyType) async {
    final pdf = await _generateBillPDF(billData, copyType);
    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/Fee_Receipt_${billData['receipt']}_$copyType.pdf';
    final file = File(path);
    await file.writeAsBytes(await pdf);
    
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Bill saved to: $path'),
        backgroundColor: _accentGreen,
      ),
    );
  }

  Future<Uint8List> _generateBillPDF(Map<String, dynamic> billData, String copyType) async {
    final pdf = pw.Document();
    
    final description = billData['description']?.toString() ?? '';
    final feeItems = description.split(',').map((item) {
      final match = RegExp(r'(.+?)\s*\(₹([\d,]+)\)').firstMatch(item.trim());
      if (match != null) {
        return {
          'name': match.group(1)?.trim() ?? item.trim(),
          'amount': double.tryParse(match.group(2)?.replaceAll(',', '') ?? '0') ?? 0.0,
        };
      }
      return {'name': item.trim(), 'amount': 0.0};
    }).toList();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(32),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          (_studentData!['schoolName'] ?? 'School').toString(),
                          style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
                        ),
                        pw.SizedBox(height: 8),
                        pw.Text(
                          'Fee Receipt',
                          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          copyType.toUpperCase(),
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 24),
                
                // Receipt Info
                pw.Container(
                  padding: const pw.EdgeInsets.all(16),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Row(
                    children: [
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('Receipt #', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                            pw.Text((billData['receipt'] ?? '').toString(), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                          ],
                        ),
                      ),
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('Date', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                            pw.Text(
                              billData['date'] != null ? DateFormat('dd MMM yyyy').format(billData['date'] as DateTime) : 'N/A',
                              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 16),
                
                // Student Info
                pw.Container(
                  padding: const pw.EdgeInsets.all(16),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Row(
                    children: [
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('Student Name', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                            pw.Text((_studentData!['stuName'] ?? 'Student').toString(), style: pw.TextStyle(fontSize: 14)),
                          ],
                        ),
                      ),
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('Class', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                            pw.Text((_studentData!['className'] ?? '-').toString(), style: pw.TextStyle(fontSize: 14)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 24),
                
                // Fee Breakdown Table
                pw.Container(
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    children: [
                      // Header
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: const pw.BoxDecoration(
                          color: PdfColors.blue100,
                        ),
                        child: pw.Row(
                          children: [
                            pw.Expanded(flex: 3, child: pw.Text('Description', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                            pw.Expanded(flex: 1, child: pw.Text('Amount', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                          ],
                        ),
                      ),
                      // Rows
                      ...feeItems.map((fee) {
                        return pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: const pw.BoxDecoration(
                            border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300)),
                          ),
                          child: pw.Row(
                            children: [
                              pw.Expanded(flex: 3, child: pw.Text((fee['name'] ?? '').toString())),
                              pw.Expanded(flex: 1, child: pw.Text('₹${double.tryParse(fee['amount'].toString())?.toStringAsFixed(0) ?? '0'}')),
                            ],
                          ),
                        );
                      }).toList(),
                      // Total
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: const pw.BoxDecoration(
                          color: PdfColors.blue100,
                        ),
                        child: pw.Row(
                          children: [
                            pw.Expanded(flex: 3, child: pw.Text('Total', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14))),
                            pw.Expanded(flex: 1, child: pw.Text('₹${((billData['amount'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 32),
                
                // Signature Area
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      children: [
                        pw.SizedBox(height: 40),
                        pw.Container(width: 150, child: pw.Divider()),
                        pw.SizedBox(height: 8),
                        pw.Text('Student Signature', style: pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                    pw.Column(
                      children: [
                        pw.SizedBox(height: 40),
                        pw.Container(width: 150, child: pw.Divider()),
                        pw.SizedBox(height: 8),
                        pw.Text('School Authority', style: pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 16),
                pw.Text(
                  'This is a computer-generated receipt.',
                  style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                ),
              ],
            ),
          );
        },
      ),
    );
    
    return pdf.save();
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
