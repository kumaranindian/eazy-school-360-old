import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../data/repositories/student_repository.dart';
import '../../../data/repositories/fee_repository.dart';
import '../../../domain/entities/student.dart';
import '../../../domain/entities/fee_payment.dart';
import '../../../domain/entities/academic_year.dart';

class FeeCollectionScreen extends ConsumerStatefulWidget {
  const FeeCollectionScreen({super.key});

  @override
  ConsumerState<FeeCollectionScreen> createState() => _FeeCollectionScreenState();
}

class _FeeCollectionScreenState extends ConsumerState<FeeCollectionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _searchController = TextEditingController();
  final _admissionFeeController = TextEditingController(text: '0');
  final _tuitionFeeController = TextEditingController(text: '0');
  final _examFeeController = TextEditingController(text: '0');
  final _vanFeeController = TextEditingController(text: '0');
  final _arrearsController = TextEditingController(text: '0');
  final _remarksController = TextEditingController();
  
  Student? _selectedStudent;
  PaymentMode _paymentMode = PaymentMode.CASH;
  bool _isLoading = false;
  List<Student> _searchResults = [];
  bool _showSearchResults = false;

  // Dark theme colors
  static const Color _bgDark = Color(0xFF0D1117);
  static const Color _cardDark = Color(0xFF161B22);
  static const Color _accentBlue = Color(0xFF4CAF50);
  static const Color _textPrimary = Color(0xFFE6EDF3);
  static const Color _textSecondary = Color(0xFF8B949E);
  static const Color _borderColor = Color(0xFF30363D);

  double get _totalAmount {
    return (double.tryParse(_admissionFeeController.text) ?? 0) +
        (double.tryParse(_tuitionFeeController.text) ?? 0) +
        (double.tryParse(_examFeeController.text) ?? 0) +
        (double.tryParse(_vanFeeController.text) ?? 0) +
        (double.tryParse(_arrearsController.text) ?? 0);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _admissionFeeController.dispose();
    _tuitionFeeController.dispose();
    _examFeeController.dispose();
    _vanFeeController.dispose();
    _arrearsController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(currentSessionProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 900;

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
            child: _buildCollectionForm(context, session.schoolId!, isDesktop),
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
                      padding: const EdgeInsets.all(20),
                      child: const Text('Recent Payments', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _textPrimary)),
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

  Widget _buildCollectionForm(BuildContext context, String schoolId, bool isDesktop) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isDesktop ? 24 : 16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [_accentBlue.withOpacity(0.15), _accentBlue.withOpacity(0.05)]),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _accentBlue.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: _accentBlue.withOpacity(0.2), shape: BoxShape.circle),
                    child: const Icon(Icons.account_balance_wallet_rounded, color: _accentBlue, size: 28),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Fee Collection', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _textPrimary)),
                        SizedBox(height: 4),
                        Text('Collect fees from students', style: TextStyle(color: _textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Student Search
            const Text('Search Student *', style: TextStyle(color: _textPrimary, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
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

            // Fee Breakdown
            const Text('Fee Breakdown', style: TextStyle(color: _textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            
            Row(
              children: [
                Expanded(child: _buildFeeField('Admission Fee', _admissionFeeController)),
                const SizedBox(width: 12),
                Expanded(child: _buildFeeField('Tuition Fee', _tuitionFeeController)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildFeeField('Exam Fee', _examFeeController)),
                const SizedBox(width: 12),
                Expanded(child: _buildFeeField('Van Fee', _vanFeeController)),
              ],
            ),
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

  void _selectStudent(Student student) {
    setState(() {
      _selectedStudent = student;
      _searchController.text = student.name;
      _searchResults = [];
      _showSearchResults = false;
    });
  }

  Future<void> _submitPayment(String schoolId) async {
    if (_selectedStudent == null || _totalAmount <= 0) return;

    setState(() => _isLoading = true);

    try {
      final session = ref.read(currentSessionProvider);
      final repo = ref.read(feeRepositoryProvider);
      final billId = await repo.getNextBillId(schoolId);
      final now = DateTime.now();

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
        admissionFeePaid: double.tryParse(_admissionFeeController.text) ?? 0,
        tuitionFeePaid: double.tryParse(_tuitionFeeController.text) ?? 0,
        examFeePaid: double.tryParse(_examFeeController.text) ?? 0,
        vanFeePaid: double.tryParse(_vanFeeController.text) ?? 0,
        arrearsPaid: double.tryParse(_arrearsController.text) ?? 0,
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
    _admissionFeeController.text = '0';
    _tuitionFeeController.text = '0';
    _examFeeController.text = '0';
    _vanFeeController.text = '0';
    _arrearsController.text = '0';
    _remarksController.clear();
    setState(() {
      _selectedStudent = null;
      _paymentMode = PaymentMode.CASH;
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
