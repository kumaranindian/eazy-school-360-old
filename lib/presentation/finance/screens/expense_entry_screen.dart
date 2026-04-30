import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/expense_category_provider.dart';
import '../../../data/repositories/expense_repository.dart';
import '../../../domain/entities/expense.dart';
import '../../../domain/entities/expense_category.dart';
import '../../../domain/entities/academic_year.dart';
import '../../../presentation/shared/widgets/searchable_dropdown.dart';

class ExpenseEntryScreen extends ConsumerStatefulWidget {
  const ExpenseEntryScreen({super.key});

  @override
  ConsumerState<ExpenseEntryScreen> createState() => _ExpenseEntryScreenState();
}

class _ExpenseEntryScreenState extends ConsumerState<ExpenseEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _pocController = TextEditingController();
  final _remarksController = TextEditingController();
  
  ExpenseCategory _selectedCategory = ExpenseCategory.OTHER;
  ExpenseCategoryItem? _selectedCategoryItem;
  DateTime _expenseDate = DateTime.now();
  bool _isMissedExpense = false;
  bool _isLoading = false;
  List<ExpenseCategoryItem> _customCategories = [];

  // Dark theme colors
  static const Color _bgDark = Color(0xFF0D1117);
  static const Color _cardDark = Color(0xFF161B22);
  static const Color _accentBlue = Color(0xFF4CAF50);
  static const Color _textPrimary = Color(0xFFE6EDF3);
  static const Color _textSecondary = Color(0xFF8B949E);
  static const Color _borderColor = Color(0xFF30363D);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCustomCategories();
    });
  }

  Future<void> _loadCustomCategories() async {
    final session = ref.read(currentSessionProvider);
    if (session?.schoolId == null) return;
    
    final repo = ref.read(expenseCategoryRepositoryProvider);
    try {
      final categories = await repo.getCategories(session!.schoolId!);
      setState(() => _customCategories = categories);
    } catch (e) {
      print('Error loading custom categories: $e');
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _pocController.dispose();
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

    final expensesAsync = ref.watch(expensesProvider(session.schoolId!));

    return Scaffold(
      backgroundColor: _bgDark,
      body: Row(
        children: [
          // Left side - Form
          Expanded(
            flex: isDesktop ? 1 : 1,
            child: _buildExpenseForm(context, session.schoolId!, isDesktop, isMobile),
          ),
          // Right side - Recent Expenses (desktop only)
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
                      child: Text('Recent Expenses', style: TextStyle(fontSize: isMobile ? 16 : 18, fontWeight: FontWeight.bold, color: _textPrimary)),
                    ),
                    Expanded(
                      child: expensesAsync.when(
                        loading: () => const Center(child: CircularProgressIndicator(color: _accentBlue)),
                        error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: _textSecondary))),
                        data: (expenses) => _buildRecentExpensesList(expenses.take(10).toList()),
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

  Widget _buildExpenseForm(BuildContext context, String schoolId, bool isDesktop, bool isMobile) {
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
                gradient: LinearGradient(colors: [Colors.red.withOpacity(0.15), Colors.red.withOpacity(0.05)]),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(isMobile ? 10 : 12),
                    decoration: BoxDecoration(color: Colors.red.withOpacity(0.2), shape: BoxShape.circle),
                    child: Icon(Icons.money_off_rounded, color: Colors.red, size: isMobile ? 24 : 28),
                  ),
                  SizedBox(width: isMobile ? 12 : 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Record Expense', style: TextStyle(fontSize: isMobile ? 18 : 20, fontWeight: FontWeight.bold, color: _textPrimary)),
                        SizedBox(height: isMobile ? 2 : 4),
                        Text('Track school expenditures', style: TextStyle(fontSize: isMobile ? 12 : 13, color: _textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: isMobile ? 16 : 24),

            // Expense Category
            Text('Expense Category *', style: TextStyle(color: _textPrimary, fontWeight: FontWeight.w500, fontSize: isMobile ? 13 : 14)),
            SizedBox(height: isMobile ? 6 : 8),
            Row(
              children: [
                Expanded(
                  child: _buildCategoryDropdown(schoolId),
                ),
                SizedBox(width: isMobile ? 6 : 8),
                IconButton(
                  icon: Icon(Icons.refresh, color: _accentBlue, size: isMobile ? 18 : 20),
                  tooltip: 'Feed Default Categories',
                  onPressed: () => _feedDefaultCategories(schoolId),
                ),
                IconButton(
                  icon: Icon(Icons.add_circle_outline, color: _accentBlue, size: isMobile ? 18 : 20),
                  tooltip: 'Add New Category',
                  onPressed: () => _showAddCategoryDialog(schoolId),
                ),
              ],
            ),
            SizedBox(height: isMobile ? 12 : 16),

            // Amount
            Text('Amount (₹) *', style: TextStyle(color: _textPrimary, fontWeight: FontWeight.w500, fontSize: isMobile ? 13 : 14)),
            SizedBox(height: isMobile ? 6 : 8),
            TextFormField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
              style: TextStyle(color: _textPrimary, fontSize: isMobile ? 16 : 18, fontWeight: FontWeight.bold),
              decoration: _inputDecoration('Enter amount', Icons.currency_rupee),
              validator: (value) {
                if (value == null || value.isEmpty) return 'Amount is required';
                final amount = double.tryParse(value);
                if (amount == null || amount <= 0) return 'Enter a valid amount';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Date
            const Text('Expense Date *', style: TextStyle(color: _textPrimary, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            InkWell(
              onTap: () => _selectDate(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                decoration: BoxDecoration(color: _cardDark, borderRadius: BorderRadius.circular(10), border: Border.all(color: _borderColor)),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, color: _textSecondary, size: 20),
                    const SizedBox(width: 12),
                    Text(DateFormat('dd MMM yyyy').format(_expenseDate), style: const TextStyle(color: _textPrimary, fontSize: 14)),
                    const Spacer(),
                    const Icon(Icons.keyboard_arrow_down, color: _textSecondary),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Description
            const Text('Description *', style: TextStyle(color: _textPrimary, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descriptionController,
              maxLines: 2,
              style: const TextStyle(color: _textPrimary),
              decoration: _inputDecoration('Enter expense description', Icons.description_outlined),
              validator: (value) => value == null || value.isEmpty ? 'Description is required' : null,
            ),
            const SizedBox(height: 16),

            // Point of Contact
            const Text('Point of Contact', style: TextStyle(color: _textPrimary, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _pocController,
              style: const TextStyle(color: _textPrimary),
              decoration: _inputDecoration('Vendor/Person name', Icons.person_outline),
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
            const SizedBox(height: 16),

            // Missed Expense Checkbox
            CheckboxListTile(
              value: _isMissedExpense,
              onChanged: (value) => setState(() => _isMissedExpense = value ?? false),
              title: const Text('This is a missed/backdated expense', style: TextStyle(color: _textPrimary, fontSize: 14)),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              activeColor: _accentBlue,
              checkColor: Colors.white,
            ),
            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : () => _submitExpense(schoolId),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _isLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Record Expense', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
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
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.red)),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expenseDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(primary: _accentBlue, surface: _cardDark),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _expenseDate = picked);
    }
  }

  Future<void> _submitExpense(String schoolId) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final session = ref.read(currentSessionProvider);
      final repo = ref.read(expenseRepositoryProvider);
      final billId = await repo.getNextBillId(schoolId);
      final now = DateTime.now();

      final expense = Expense(
        id: '',
        schoolId: schoolId,
        billId: billId,
        category: _selectedCategory,
        categoryName: Expense.getCategoryDisplayName(_selectedCategory),
        amount: double.parse(_amountController.text),
        description: _descriptionController.text.trim(),
        pointOfContact: _pocController.text.trim(),
        expenseDate: _expenseDate,
        isMissedExpense: _isMissedExpense,
        remarks: _remarksController.text.trim().isEmpty ? null : _remarksController.text.trim(),
        cashierName: session?.displayName ?? 'Unknown',
        academicYear: AcademicYear.getCurrentYearCode(),
        fiscalYear: FiscalYear.getCurrentYearCode(),
        createdAt: now,
        updatedAt: now,
        createdBy: session?.uid,
      );

      await repo.createExpense(schoolId, expense);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Expense recorded successfully'), backgroundColor: _accentBlue),
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
    _amountController.clear();
    _descriptionController.clear();
    _pocController.clear();
    _remarksController.clear();
    setState(() {
      _selectedCategory = ExpenseCategory.OTHER;
      _expenseDate = DateTime.now();
      _isMissedExpense = false;
    });
  }

  Widget _buildCategoryDropdown(String schoolId) {
    // Only use Firestore categories (no hardcoded enum values)
    final allCategories = <ExpenseCategoryItem>[];
    
    // Add categories from Firestore
    for (final customCat in _customCategories) {
      if (!allCategories.any((c) => c.name == customCat.name)) {
        allCategories.add(customCat);
      }
    }
    
    // If no categories, show placeholder
    if (allCategories.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _cardDark,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _borderColor),
        ),
        child: Row(
          children: [
            const Icon(Icons.category, color: _textSecondary, size: 20),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'No categories yet. Click + to add',
                style: TextStyle(color: _textSecondary, fontSize: 14),
              ),
            ),
            const Icon(Icons.keyboard_arrow_down, color: _textSecondary),
          ],
        ),
      );
    }

    return SearchableDropdown<ExpenseCategoryItem>(
      value: _selectedCategoryItem,
      items: allCategories,
      itemLabel: (c) => c.name,
      hint: 'Select expense category',
      onChanged: (v) {
        setState(() {
          _selectedCategoryItem = v;
          // Try to match to enum, otherwise keep as OTHER
          if (v != null) {
            try {
              _selectedCategory = ExpenseCategory.values.firstWhere(
                (c) => Expense.getCategoryDisplayName(c) == v.name,
                orElse: () => ExpenseCategory.OTHER,
              );
            } catch (_) {
              _selectedCategory = ExpenseCategory.OTHER;
            }
          }
        });
      },
    );
  }

  Future<void> _feedDefaultCategories(String schoolId) async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(expenseCategoryRepositoryProvider);
      await repo.feedDefaultCategories(schoolId);
      await _loadCustomCategories();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Default categories loaded successfully'), backgroundColor: _accentBlue),
        );
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

  Future<void> _showAddCategoryDialog(String schoolId) async {
    final nameController = TextEditingController();
    final codeController = TextEditingController();
    
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardDark,
        title: const Text('Add New Category', style: TextStyle(color: _textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: const TextStyle(color: _textPrimary),
              decoration: const InputDecoration(
                labelText: 'Category Name',
                labelStyle: TextStyle(color: _textSecondary),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: _borderColor)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: _accentBlue)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: codeController,
              style: const TextStyle(color: _textPrimary),
              decoration: const InputDecoration(
                labelText: 'Category Code (optional)',
                labelStyle: TextStyle(color: _textSecondary),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: _borderColor)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: _accentBlue)),
              ),
              textCapitalization: TextCapitalization.characters,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: _textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: _accentBlue),
            child: const Text('Add', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (result == true && nameController.text.isNotEmpty) {
      final name = nameController.text.trim();
      final code = codeController.text.trim().isEmpty 
          ? name.toUpperCase().replaceAll(' ', '_') 
          : codeController.text.trim().toUpperCase().replaceAll(' ', '_');
      
      try {
        final repo = ref.read(expenseCategoryRepositoryProvider);
        await repo.addCategory(schoolId, name, code);
        await _loadCustomCategories();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Category added successfully'), backgroundColor: _accentBlue),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }

    nameController.dispose();
    codeController.dispose();
  }

  Widget _buildRecentExpensesList(List<Expense> expenses) {
    if (expenses.isEmpty) {
      return const Center(child: Text('No recent expenses', style: TextStyle(color: _textSecondary)));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: expenses.length,
      itemBuilder: (context, index) {
        final expense = expenses[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: _cardDark, borderRadius: BorderRadius.circular(10), border: Border.all(color: _borderColor)),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.red.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.money_off, color: Colors.red, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(expense.categoryName, style: const TextStyle(color: _textPrimary, fontWeight: FontWeight.w500, fontSize: 13), overflow: TextOverflow.ellipsis),
                    Text(DateFormat('dd MMM yyyy').format(expense.expenseDate), style: const TextStyle(color: _textSecondary, fontSize: 11)),
                  ],
                ),
              ),
              Text('₹${expense.amount.toStringAsFixed(0)}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
        );
      },
    );
  }
}
