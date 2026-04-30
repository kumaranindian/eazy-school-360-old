import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../data/repositories/fee_category_repository.dart';
import '../../../data/repositories/student_repository.dart';
import '../../../data/repositories/fee_repository.dart';
import '../../../domain/entities/fee_category.dart';
import '../../../domain/entities/student.dart';
import '../../../domain/entities/fee_payment.dart';
import '../../../domain/entities/fee_structure_v2.dart';
import '../../../domain/entities/fee_term.dart';
import '../../../domain/entities/academic_year.dart';
import '../../../data/services/fee_structure_to_payment_mapper.dart';
import '../../../data/services/student_fee_rows_from_structure_service.dart';

class FeeCollectionScreen extends ConsumerStatefulWidget {
  const FeeCollectionScreen({super.key});

  @override
  ConsumerState<FeeCollectionScreen> createState() => _FeeCollectionScreenState();
}

class _FeeCollectionScreenState extends ConsumerState<FeeCollectionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _searchController = TextEditingController();

  /// One TextEditingController per fee-category code (e.g. TUITION,
  /// SPORTS_FEE). Built dynamically from the school catalog filtered by
  /// the selected student's class.
  final Map<String, TextEditingController> _categoryControllers = {};

  /// Categories applicable to the currently selected student, in the order
  /// they should be rendered.
  List<FeeCategory> _activeCategories = const [];

  final _arrearsController = TextEditingController(text: '0');
  final _remarksController = TextEditingController();

  Student? _selectedStudent;
  PaymentMode _paymentMode = PaymentMode.CASH;
  bool _isLoading = false;
  List<Student> _searchResults = [];
  bool _showSearchResults = false;

  // FeeStructureV2 integration
  FeeStructureV2? _activeStructure;
  FeeTerm? _nextDueTerm;

  // Dark theme colors
  static const Color _bgDark = Color(0xFF0D1117);
  static const Color _cardDark = Color(0xFF161B22);
  static const Color _accentBlue = Color(0xFF4CAF50);
  static const Color _textPrimary = Color(0xFFE6EDF3);
  static const Color _textSecondary = Color(0xFF8B949E);
  static const Color _borderColor = Color(0xFF30363D);

  double get _totalAmount {
    double sum = double.tryParse(_arrearsController.text) ?? 0;
    for (final c in _categoryControllers.values) {
      sum += double.tryParse(c.text) ?? 0;
    }
    return sum;
  }

  /// Returns the controller for a category code, creating it on first
  /// access. Defaults the text to '0'.
  TextEditingController _controllerFor(String code) =>
      _categoryControllers.putIfAbsent(
          code, () => TextEditingController(text: '0'));

  @override
  void dispose() {
    _searchController.dispose();
    for (final c in _categoryControllers.values) {
      c.dispose();
    }
    _categoryControllers.clear();
    _arrearsController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(currentSessionProvider);
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final isDesktop = screenWidth > 900;
    final isMobile = screenWidth < 600;

    if (session == null || session.schoolId == null) {
      return const Scaffold(backgroundColor: _bgDark, body: Center(child: Text('Access Denied', style: TextStyle(color: _textPrimary))));
    }

    final paymentsAsync = ref.watch(feePaymentsProvider(session.schoolId!));

    return Scaffold(
      backgroundColor: _bgDark,
      body: Row(
        children: [
          // Left side - Form
          Expanded(
            flex: isDesktop ? 1 : 1,
            child: _buildCollectionForm(context, session.schoolId!, isDesktop, isMobile),
          ),
          // Right side - Recent Payments (desktop only)
          if (isDesktop)
            Expanded(
              flex: 1,
              child: Container(
                decoration: const BoxDecoration(border: Border(left: BorderSide(color: _borderColor))),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: EdgeInsets.all(isMobile ? 16 : 20),
                      child: Text('Recent Payments', style: TextStyle(fontSize: isMobile ? 16 : 18, fontWeight: FontWeight.bold, color: _textPrimary)),
                    ),
                    Expanded(
                      child: paymentsAsync.when(
                        loading: () => const Center(child: CircularProgressIndicator(color: _accentBlue)),
                        error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: _textSecondary))),
                        data: (payments) => _buildRecentPaymentsList(payments.take(10).toList()),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCollectionForm(BuildContext context, String schoolId, bool isDesktop, bool isMobile) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 12 : isDesktop ? 24 : 16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(isMobile ? 14 : 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [_accentBlue.withOpacity(0.15), _accentBlue.withOpacity(0.05)]),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _accentBlue.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(isMobile ? 10 : 12),
                    decoration: BoxDecoration(color: _accentBlue.withOpacity(0.2), shape: BoxShape.circle),
                    child: Icon(Icons.account_balance_wallet_rounded, color: _accentBlue, size: isMobile ? 24 : 28),
                  ),
                  SizedBox(width: isMobile ? 12 : 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Fee Collection', style: TextStyle(fontSize: isMobile ? 18 : 20, fontWeight: FontWeight.bold, color: _textPrimary)),
                        SizedBox(height: isMobile ? 2 : 4),
                        Text('Collect fees from students', style: TextStyle(fontSize: isMobile ? 12 : 13, color: _textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: isMobile ? 16 : 24),

            // Student Search
            Text('Search Student *', style: TextStyle(color: _textPrimary, fontWeight: FontWeight.w500, fontSize: isMobile ? 13 : 14)),
            SizedBox(height: isMobile ? 6 : 8),
            Stack(
              children: [
                Column(
                  children: [
                    TextFormField(
                      controller: _searchController,
                      style: const TextStyle(color: _textPrimary),
                      decoration: _inputDecoration('Search by name, ID, or phone...', Icons.search),
                      onChanged: (value) => _searchStudents(schoolId, value),
                    ),
                    if (_showSearchResults && _searchResults.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        constraints: const BoxConstraints(maxHeight: 200),
                        decoration: BoxDecoration(color: _cardDark, borderRadius: BorderRadius.circular(10), border: Border.all(color: _borderColor)),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _searchResults.length,
                          itemBuilder: (context, index) {
                            final student = _searchResults[index];
                            return ListTile(
                              leading: CircleAvatar(backgroundColor: _accentBlue.withOpacity(0.2), child: Text(student.name[0].toUpperCase(), style: const TextStyle(color: _accentBlue))),
                              title: Text(student.name, style: const TextStyle(color: _textPrimary)),
                              subtitle: Text('ID: ${student.studentId} • Class ${student.className}', style: const TextStyle(color: _textSecondary, fontSize: 12)),
                              onTap: () => _selectStudent(student),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ],
            ),
            
            // Selected Student Card
            if (_selectedStudent != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: _accentBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: _accentBlue.withOpacity(0.3))),
                child: Row(
                  children: [
                    CircleAvatar(backgroundColor: _accentBlue, radius: 24, child: Text(_selectedStudent!.name[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18))),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_selectedStudent!.name, style: const TextStyle(color: _textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 4),
                          Text('ID: ${_selectedStudent!.studentId} • Class ${_selectedStudent!.className} - ${_selectedStudent!.section}', style: const TextStyle(color: _textSecondary, fontSize: 12)),
                          if (_selectedStudent!.phoneNumber != null) Text(_selectedStudent!.phoneNumber!, style: const TextStyle(color: _textSecondary, fontSize: 12)),
                        ],
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.close, color: _textSecondary), onPressed: () => setState(() => _selectedStudent = null)),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),

            // Helper buttons
            if (_selectedStudent != null) ...[
              Row(
                children: [
                  if (_nextDueTerm != null)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _autoFillFromNextTerm,
                        icon: const Icon(Icons.auto_awesome, size: 16),
                        label: const Text('Auto‑fill from Next Term'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _accentBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  if (_nextDueTerm != null && _activeStructure != null) const SizedBox(width: 12),
                  if (_activeStructure != null)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _downloadClassFeeRows,
                        icon: const Icon(Icons.download, size: 16),
                        label: const Text('Download Class Rows'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _accentBlue,
                          side: const BorderSide(color: _accentBlue),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            // Fee Breakdown
            Row(children: [
              const Text('Fee Breakdown', style: TextStyle(color: _textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(width: 8),
              if (_activeCategories.isEmpty && _selectedStudent != null)
                const Text('(no categories — defaulting to legacy buckets)',
                    style: TextStyle(color: _textSecondary, fontSize: 11)),
            ]),
            const SizedBox(height: 12),

            _buildCategoryGrid(),
            const SizedBox(height: 12),
            _buildFeeField('Arrears', _arrearsController),
            const SizedBox(height: 16),

            // Total Amount
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: _accentBlue.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Amount', style: TextStyle(color: _textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
                  Text('₹${_totalAmount.toStringAsFixed(2)}', style: const TextStyle(color: _accentBlue, fontWeight: FontWeight.bold, fontSize: 22)),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Payment Mode
            const Text('Payment Mode', style: TextStyle(color: _textPrimary, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: PaymentMode.values.map((mode) => ChoiceChip(
                label: Text(_getPaymentModeName(mode)),
                selected: _paymentMode == mode,
                onSelected: (selected) => setState(() => _paymentMode = mode),
                selectedColor: _accentBlue,
                backgroundColor: _cardDark,
                labelStyle: TextStyle(color: _paymentMode == mode ? Colors.white : _textPrimary),
              )).toList(),
            ),
            const SizedBox(height: 16),

            // Remarks
            const Text('Remarks', style: TextStyle(color: _textPrimary, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _remarksController,
              maxLines: 2,
              style: const TextStyle(color: _textPrimary),
              decoration: _inputDecoration('Additional notes (optional)', Icons.notes_outlined),
            ),
            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: (_isLoading || _selectedStudent == null || _totalAmount <= 0) ? null : () => _submitPayment(schoolId),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accentBlue,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: _accentBlue.withOpacity(0.3),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _isLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Collect Payment', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Renders a 2-column grid of fee inputs, one per active category.
  /// Falls back to the four standard buckets when no catalog is loaded yet
  /// (so the screen is never empty).
  Widget _buildCategoryGrid() {
    final categories = _activeCategories.isEmpty
        ? FeeCategory.defaults
        : _activeCategories;

    final widgets = <Widget>[];
    for (var i = 0; i < categories.length; i += 2) {
      final left = categories[i];
      final right = (i + 1 < categories.length) ? categories[i + 1] : null;
      widgets.add(Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(children: [
          Expanded(
              child: _buildFeeField(left.name, _controllerFor(left.code))),
          const SizedBox(width: 12),
          if (right != null)
            Expanded(
                child:
                    _buildFeeField(right.name, _controllerFor(right.code)))
          else
            const Expanded(child: SizedBox.shrink()),
        ]),
      ));
    }
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: widgets);
  }

  Widget _buildFeeField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: _textSecondary, fontSize: 12)),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
          style: const TextStyle(color: _textPrimary, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            prefixText: '₹ ',
            prefixStyle: const TextStyle(color: _textSecondary),
            filled: true,
            fillColor: _cardDark,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _borderColor)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _borderColor)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _accentBlue)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _textSecondary),
      prefixIcon: Icon(icon, color: _textSecondary, size: 20),
      filled: true,
      fillColor: _cardDark,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _borderColor)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _borderColor)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _accentBlue)),
    );
  }

  String _getPaymentModeName(PaymentMode mode) {
    switch (mode) {
      case PaymentMode.CASH: return 'Cash';
      case PaymentMode.UPI: return 'UPI';
      case PaymentMode.CARD: return 'Card';
      case PaymentMode.CHEQUE: return 'Cheque';
      case PaymentMode.BANK_TRANSFER: return 'Bank Transfer';
      case PaymentMode.OTHER: return 'Other';
    }
  }

  Future<void> _searchStudents(String schoolId, String query) async {
    if (query.length < 2) {
      setState(() {
        _searchResults = [];
        _showSearchResults = false;
      });
      return;
    }

    try {
      final repo = ref.read(studentRepositoryProvider);
      final results = await repo.searchStudents(schoolId, query);
      setState(() {
        _searchResults = results;
        _showSearchResults = true;
      });
    } catch (e) {
      debugPrint('Search error: $e');
    }
  }

  void _selectStudent(Student student) async {
    setState(() {
      _selectedStudent = student;
      _searchController.text = student.name;
      _searchResults = [];
      _showSearchResults = false;
    });
    await _loadActiveStructure(student);
  }

  Future<void> _loadActiveStructure(Student student) async {
    final schoolId = ref.read(currentSessionProvider)!.schoolId!;
    final repo = ref.read(feeRepositoryProvider);
    final catRepo = ref.read(feeCategoryRepositoryProvider);
    final ay = AcademicYear.getCurrentYearCode();

    final structure =
        await repo.getFeeStructureV2ByClass(schoolId, student.className, ay);
    final nextTerm = structure != null
        ? await repo.getNextDueTermForClass(schoolId, student.className, ay)
        : null;

    // Load the catalog and filter to categories applicable to this class.
    final all = await catRepo.listCategories(schoolId);
    final applicable = all
        .where((c) => c.isActive && c.appliesTo(student.className))
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    // Reset controllers so previously selected student's values don't leak.
    for (final c in _categoryControllers.values) {
      c.dispose();
    }
    _categoryControllers.clear();
    for (final c in applicable) {
      _categoryControllers[c.code] = TextEditingController(text: '0');
    }
    _arrearsController.text = '0';

    if (mounted) {
      setState(() {
        _activeStructure = structure;
        _nextDueTerm = nextTerm;
        _activeCategories = applicable;
      });
    }
  }

  /// Auto‑fill the fee breakdown fields from the next due term. Whichever
  /// category the term maps to gets the term amount; everything else stays
  /// at 0.
  void _autoFillFromNextTerm() {
    if (_nextDueTerm == null) return;
    // Reset all category fields first.
    for (final c in _categoryControllers.values) {
      c.text = '0';
    }
    final components =
        FeeStructureToPaymentMapper.mapTermToComponents(_nextDueTerm!);
    components.forEach((key, value) {
      final code = _categoryCodeForComponentKey(key);
      final ctrl = _controllerFor(code);
      ctrl.text = value.toStringAsFixed(0);
    });
    setState(() {}); // refresh total
  }

  /// Translates a mapper component key (e.g. `tuitionFeePaid`) back into the
  /// matching category code (e.g. `TUITION`). Custom keys are passed through
  /// unchanged.
  String _categoryCodeForComponentKey(String key) {
    switch (key) {
      case 'admissionFeePaid':
        return 'ADMISSION';
      case 'tuitionFeePaid':
        return 'TUITION';
      case 'examFeePaid':
        return 'EXAM';
      case 'vanFeePaid':
        return 'VAN';
      default:
        return key; // custom category code
    }
  }

  /// Download an Excel file with one row per student‑term for the selected student's class.
  Future<void> _downloadClassFeeRows() async {
    if (_activeStructure == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No fee structure assigned to this class.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    final studentRepo = ref.read(studentRepositoryProvider);
    final studentsAsync = await studentRepo.getStudentsByClassStream(
      ref.read(currentSessionProvider)!.schoolId!,
      _selectedStudent!.className,
    ).first;
    final svc = StudentFeeRowsFromStructureService();
    final bytes = svc.build(
      structure: _activeStructure!,
      students: studentsAsync,
      defaultPaymentMode: _paymentMode,
      defaultRemarks: _remarksController.text.trim().isEmpty ? null : _remarksController.text.trim(),
    );
    // TODO: trigger download via file_picker or a web download helper
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Generated ${studentsAsync.length * _activeStructure!.terms.length} rows for download.'),
        backgroundColor: _accentBlue,
      ),
    );
  }

  Future<void> _submitPayment(String schoolId) async {
    if (_selectedStudent == null || _totalAmount <= 0) return;

    setState(() => _isLoading = true);

    try {
      final session = ref.read(currentSessionProvider);
      final repo = ref.read(feeRepositoryProvider);
      final billId = await repo.getNextBillId(schoolId);
      final now = DateTime.now();

      // Split the dynamic category map into the four standard fields and a
      // residual map of custom category amounts.
      double admission = 0, tuition = 0, exam = 0, van = 0;
      final customAmounts = <String, double>{};
      _categoryControllers.forEach((code, ctrl) {
        final v = double.tryParse(ctrl.text) ?? 0;
        if (v <= 0) return;
        switch (code) {
          case 'ADMISSION':
            admission = v;
            break;
          case 'TUITION':
            tuition = v;
            break;
          case 'EXAM':
            exam = v;
            break;
          case 'VAN':
            van = v;
            break;
          default:
            customAmounts[code] = v;
        }
      });

      final payment = FeePayment(
        id: '',
        schoolId: schoolId,
        billId: billId,
        studentId: _selectedStudent!.id,
        studentName: _selectedStudent!.name,
        className: _selectedStudent!.className,
        section: _selectedStudent!.section,
        academicYear: AcademicYear.getCurrentYearCode(),
        fiscalYear: FiscalYear.getCurrentYearCode(),
        admissionFeePaid: admission,
        tuitionFeePaid: tuition,
        examFeePaid: exam,
        vanFeePaid: van,
        arrearsPaid: double.tryParse(_arrearsController.text) ?? 0,
        customCategoryAmounts: customAmounts,
        totalAmount: _totalAmount,
        paymentMode: _paymentMode,
        remarks: _remarksController.text.trim().isEmpty ? null : _remarksController.text.trim(),
        cashierName: session?.displayName ?? 'Unknown',
        paymentDate: now,
        createdAt: now,
        updatedAt: now,
        createdBy: session?.uid,
      );

      await repo.createFeePayment(schoolId, payment);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment of ₹${_totalAmount.toStringAsFixed(0)} collected successfully'), backgroundColor: _accentBlue),
        );
        _clearForm();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _clearForm() {
    _searchController.clear();
    for (final c in _categoryControllers.values) {
      c.text = '0';
    }
    _arrearsController.text = '0';
    _remarksController.clear();
    setState(() {
      _selectedStudent = null;
      _paymentMode = PaymentMode.CASH;
      _activeStructure = null;
      _nextDueTerm = null;
      _activeCategories = const [];
    });
  }

  Widget _buildRecentPaymentsList(List<FeePayment> payments) {
    if (payments.isEmpty) {
      return const Center(child: Text('No recent payments', style: TextStyle(color: _textSecondary)));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: payments.length,
      itemBuilder: (context, index) {
        final payment = payments[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: _cardDark, borderRadius: BorderRadius.circular(10), border: Border.all(color: _borderColor)),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: _accentBlue.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.receipt_rounded, color: _accentBlue, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(payment.studentName, style: const TextStyle(color: _textPrimary, fontWeight: FontWeight.w500, fontSize: 13), overflow: TextOverflow.ellipsis),
                    Text('Class ${payment.className} • ${DateFormat('dd MMM').format(payment.paymentDate)}', style: const TextStyle(color: _textSecondary, fontSize: 11)),
                  ],
                ),
              ),
              Text('₹${payment.totalAmount.toStringAsFixed(0)}', style: const TextStyle(color: _accentBlue, fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
        );
      },
    );
  }
}
