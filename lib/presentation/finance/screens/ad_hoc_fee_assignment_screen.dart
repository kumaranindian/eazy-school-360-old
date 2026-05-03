import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../data/repositories/fee_category_repository.dart';
import '../../../data/services/ad_hoc_fee_assignment_service.dart';
import '../../../domain/entities/fee_category.dart';

const Color _bgDark = Color(0xFF0D1117);
const Color _cardDark = Color(0xFF161B22);
const Color _accentGreen = Color(0xFF4CAF50);
const Color _accentBlue = Color(0xFF3B82F6);
const Color _accentAmber = Color(0xFFF59E0B);
const Color _accentRed = Color(0xFFEF4444);
const Color _textPrimary = Color(0xFFE6EDF3);
const Color _textSecondary = Color(0xFF8B949E);
const Color _borderColor = Color(0xFF30363D);

/// Screen for creating ad-hoc fee assignments (event fees, bulk assignments).
/// Allows admins to assign fees to multiple students at once based on scope.
class AdHocFeeAssignmentScreen extends ConsumerStatefulWidget {
  const AdHocFeeAssignmentScreen({
    super.key,
    required this.schoolId,
    required this.academicYear,
    this.onSuccess,
  });

  final String schoolId;
  final String academicYear;
  final VoidCallback? onSuccess;

  @override
  ConsumerState<AdHocFeeAssignmentScreen> createState() =>
      _AdHocFeeAssignmentScreenState();
}

class _AdHocFeeAssignmentScreenState
    extends ConsumerState<AdHocFeeAssignmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  String _selectedCategory = '';
  String _scope = 'school'; // school, class, section, custom
  DateTime _dueDate = DateTime.now().add(const Duration(days: 30));
  final Set<String> _selectedClasses = {};
  final Set<String> _selectedSections = {};
  bool _isLoading = false;
  AssignmentPreview? _preview;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPreview() async {
    if (_amountCtrl.text.trim().isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final service = ref.read(adHocFeeAssignmentServiceProvider);
      final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;

      final preview = await service.previewAssignment(
        schoolId: widget.schoolId,
        academicYear: widget.academicYear,
        scope: _scope,
        classIds: _selectedClasses.toList(),
        sections: _selectedSections.toList(),
        amount: amount,
      );

      setState(() => _preview = preview);
    } catch (e) {
      _showError('Failed to load preview: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _submit() async {
    // Prevent race condition - don't allow multiple submissions
    if (_isLoading) return;

    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategory.isEmpty) {
      _showError('Please select a fee category');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final service = ref.read(adHocFeeAssignmentServiceProvider);
      final session = ref.read(currentSessionProvider);
      final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;

      print('[AdHocFeeAssignmentScreen] Creating assignment...');
      print('[AdHocFeeAssignmentScreen] School ID: ${widget.schoolId}');
      print('[AdHocFeeAssignmentScreen] Academic Year: ${widget.academicYear}');
      print('[AdHocFeeAssignmentScreen] User ID: ${session?.uid}');
      print('[AdHocFeeAssignmentScreen] User Role: ${session?.role}');
      print('[AdHocFeeAssignmentScreen] Category: $_selectedCategory');
      print('[AdHocFeeAssignmentScreen] Scope: $_scope');

      final result = await service.createAndAssign(
        schoolId: widget.schoolId,
        academicYear: widget.academicYear,
        categoryCode: _selectedCategory,
        assignmentName: _nameCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        amount: amount,
        dueDate: _dueDate,
        scope: _scope,
        classIds: _selectedClasses.toList(),
        sections: _selectedSections.toList(),
        createdBy: session?.uid,
        notes: _notesCtrl.text.trim(),
      );

      if (mounted) {
        // Clear form data after successful submission
        _clearForm();

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: _accentGreen,
          content: Text(
              'Successfully assigned fee to ${result.studentsAssigned} students (₹${result.totalAmount.toStringAsFixed(0)})'),
          duration: const Duration(seconds: 3),
        ));

        // If callback provided (inline rendering), use it
        if (widget.onSuccess != null) {
          widget.onSuccess!();
        } else {
          // Otherwise try to pop (pushed as route)
          try {
            if (mounted && Navigator.of(context).canPop()) {
              Navigator.of(context).pop(true);
            }
          } catch (e) {
            print('[AdHocFeeAssignmentScreen] Navigation error: $e');
          }
        }
      }
    } catch (e) {
      _showError('Failed to create assignment: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _clearForm() {
    _nameCtrl.clear();
    _descCtrl.clear();
    _amountCtrl.clear();
    _notesCtrl.clear();
    setState(() {
      _selectedCategory = '';
      _scope = 'school';
      _dueDate = DateTime.now().add(const Duration(days: 30));
      _selectedClasses.clear();
      _selectedSections.clear();
      _preview = null;
    });
    _formKey.currentState?.reset();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: _accentRed,
      content: Text(message),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(feeCategoriesProvider(widget.schoolId));
    final money =
        NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return Scaffold(
      backgroundColor: _bgDark,
      appBar: AppBar(
        backgroundColor: _cardDark,
        elevation: 0,
        title: const Text('Create Fee Assignment',
            style: TextStyle(color: _textPrimary)),
        iconTheme: const IconThemeData(color: _textPrimary),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Assignment Name
              _buildTextField(
                controller: _nameCtrl,
                label: 'Assignment Name',
                hint: 'e.g., Sports Day 2026, Annual Day Fee',
                validator: (v) => v?.trim().isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              // Description
              _buildTextField(
                controller: _descCtrl,
                label: 'Description',
                hint: 'Optional description',
                maxLines: 2,
              ),
              const SizedBox(height: 16),

              // Category Selection
              categoriesAsync.when(
                loading: () => const CircularProgressIndicator(),
                error: (e, _) => Text('Error loading categories: $e',
                    style: const TextStyle(color: _accentRed)),
                data: (categories) {
                  final activeCategories =
                      categories.where((c) => c.isActive).toList();
                  return _buildCategoryDropdown(activeCategories);
                },
              ),
              const SizedBox(height: 16),

              // Amount
              _buildTextField(
                controller: _amountCtrl,
                label: 'Amount',
                hint: '0',
                keyboardType: TextInputType.number,
                prefix: '₹ ',
                validator: (v) {
                  if (v?.trim().isEmpty ?? true) return 'Required';
                  if (double.tryParse(v!) == null) return 'Invalid amount';
                  if (double.parse(v) <= 0) return 'Must be greater than 0';
                  return null;
                },
                onChanged: (_) => _loadPreview(),
              ),
              const SizedBox(height: 16),

              // Due Date
              _buildDatePicker(),
              const SizedBox(height: 16),

              // Scope Selection
              _buildScopeSelector(),
              const SizedBox(height: 16),

              // Preview
              if (_preview != null) _buildPreview(_preview!, money),
              const SizedBox(height: 16),

              // Notes
              _buildTextField(
                controller: _notesCtrl,
                label: 'Notes (Optional)',
                hint: 'Additional notes',
                maxLines: 2,
              ),
              const SizedBox(height: 24),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accentGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('Create Assignment',
                          style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? prefix,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: _textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: const TextStyle(color: _textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: _textSecondary),
            prefixText: prefix,
            prefixStyle: const TextStyle(color: _textSecondary),
            filled: true,
            fillColor: _cardDark,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _accentBlue),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          validator: validator,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildCategoryDropdown(List<FeeCategory> categories) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Fee Category',
            style: TextStyle(
                color: _textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: _selectedCategory.isEmpty ? null : _selectedCategory,
          dropdownColor: _cardDark,
          style: const TextStyle(color: _textPrimary),
          decoration: InputDecoration(
            hintText: 'Select category',
            hintStyle: const TextStyle(color: _textSecondary),
            filled: true,
            fillColor: _cardDark,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _borderColor),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          items: categories
              .map((cat) => DropdownMenuItem(
                    value: cat.code,
                    child: Text(cat.name),
                  ))
              .toList(),
          onChanged: (v) => setState(() => _selectedCategory = v ?? ''),
          validator: (v) => v == null ? 'Required' : null,
        ),
      ],
    );
  }

  Widget _buildDatePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Due Date',
            style: TextStyle(
                color: _textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _dueDate,
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (picked != null) {
              setState(() => _dueDate = picked);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: _cardDark,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _borderColor),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today,
                    color: _textSecondary, size: 18),
                const SizedBox(width: 8),
                Text(DateFormat('dd MMM yyyy').format(_dueDate),
                    style: const TextStyle(color: _textPrimary)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScopeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Assignment Scope',
            style: TextStyle(
                color: _textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            _scopeChip('School-wide', 'school'),
            _scopeChip('Class-wise', 'class'),
            _scopeChip('Section-wise', 'section'),
          ],
        ),
        if (_scope == 'class') ...[
          const SizedBox(height: 12),
          _buildClassSelector(),
        ],
        if (_scope == 'section') ...[
          const SizedBox(height: 12),
          _buildSectionSelector(),
        ],
      ],
    );
  }

  Widget _scopeChip(String label, String value) {
    final isSelected = _scope == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _scope = value;
          _selectedClasses.clear();
          _selectedSections.clear();
        });
        _loadPreview();
      },
      selectedColor: _accentBlue,
      backgroundColor: _cardDark,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : _textSecondary,
      ),
      side: BorderSide(color: isSelected ? _accentBlue : _borderColor),
    );
  }

  Widget _buildClassSelector() {
    // Simplified - in production, fetch from repository
    final classes = [
      'LKG',
      'UKG',
      'KG',
      'I',
      'II',
      'III',
      'IV',
      'V',
      'VI',
      'VII',
      'VIII',
      'IX',
      'X',
      'XI',
      'XII'
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: classes.map((cls) {
        final isSelected = _selectedClasses.contains(cls);
        return FilterChip(
          label: Text('Class $cls'),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              if (selected) {
                _selectedClasses.add(cls);
              } else {
                _selectedClasses.remove(cls);
              }
            });
            _loadPreview();
          },
          selectedColor: _accentGreen,
          backgroundColor: _cardDark,
          labelStyle: TextStyle(
            color: isSelected ? Colors.white : _textSecondary,
            fontSize: 12,
          ),
          side: BorderSide(color: isSelected ? _accentGreen : _borderColor),
        );
      }).toList(),
    );
  }

  Widget _buildSectionSelector() {
    final sections = ['A', 'B', 'C', 'D'];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: sections.map((sec) {
        final isSelected = _selectedSections.contains(sec);
        return FilterChip(
          label: Text('Section $sec'),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              if (selected) {
                _selectedSections.add(sec);
              } else {
                _selectedSections.remove(sec);
              }
            });
            _loadPreview();
          },
          selectedColor: _accentGreen,
          backgroundColor: _cardDark,
          labelStyle: TextStyle(
            color: isSelected ? Colors.white : _textSecondary,
            fontSize: 12,
          ),
          side: BorderSide(color: isSelected ? _accentGreen : _borderColor),
        );
      }).toList(),
    );
  }

  Widget _buildPreview(AssignmentPreview preview, NumberFormat money) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _accentBlue),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.preview, color: _accentBlue, size: 20),
              SizedBox(width: 8),
              Text('Preview',
                  style: TextStyle(
                      color: _textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          _previewRow('Students', '${preview.studentCount}'),
          _previewRow('Total Amount', money.format(preview.totalAmount)),
          if (preview.studentCount > 0) ...[
            const SizedBox(height: 8),
            Text(
                'Per student: ${money.format(preview.totalAmount / preview.studentCount)}',
                style: const TextStyle(color: _textSecondary, fontSize: 12)),
          ],
        ],
      ),
    );
  }

  Widget _previewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(color: _textSecondary, fontSize: 13)),
          Text(value,
              style: const TextStyle(
                  color: _textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
