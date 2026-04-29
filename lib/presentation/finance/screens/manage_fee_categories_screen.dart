import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../data/repositories/fee_category_repository.dart';
import '../../../data/repositories/student_repository.dart';
import '../../../domain/entities/fee_category.dart';

const Color _bgDark = Color(0xFF0D1117);
const Color _cardDark = Color(0xFF161B22);
const Color _accentGreen = Color(0xFF4CAF50);
const Color _accentBlue = Color(0xFF3B82F6);
const Color _accentRed = Color(0xFFEF4444);
const Color _textPrimary = Color(0xFFE6EDF3);
const Color _textSecondary = Color(0xFF8B949E);
const Color _borderColor = Color(0xFF30363D);

/// School-level catalog of fee categories. Lets admins add custom categories
/// like "Sports Fee", "Library Fee", etc., toggle their active state, and
/// restrict each one to specific classes. Standard categories (ADMISSION,
/// TUITION, EXAM, VAN) cannot be deleted but can be deactivated.
class ManageFeeCategoriesScreen extends ConsumerWidget {
  const ManageFeeCategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schoolId = ref.watch(currentSessionProvider)?.schoolId;
    if (schoolId == null) {
      return const Scaffold(
        backgroundColor: _bgDark,
        body: Center(
          child: Text('Access Denied',
              style: TextStyle(color: _textPrimary)),
        ),
      );
    }

    final categoriesAsync = ref.watch(feeCategoriesProvider(schoolId));

    return Scaffold(
      backgroundColor: _bgDark,
      appBar: AppBar(
        backgroundColor: _bgDark,
        elevation: 0,
        title: const Text('Fee Categories',
            style: TextStyle(
                color: _textPrimary, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: _textPrimary),
        actions: [
          TextButton.icon(
            onPressed: () => _openEditor(context, ref, schoolId, null),
            icon: const Icon(Icons.add, color: _accentGreen),
            label: const Text('Add Category',
                style: TextStyle(color: _accentGreen)),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: categoriesAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: _accentGreen)),
        error: (e, _) => Center(
            child: Text('Error: $e',
                style: const TextStyle(color: _textSecondary))),
        data: (categories) {
          if (categories.isEmpty) {
            return _emptyState(() =>
                _openEditor(context, ref, schoolId, null));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _infoBanner(),
              const SizedBox(height: 16),
              ...categories
                  .map((c) => _categoryCard(context, ref, schoolId, c))
                  .toList(),
            ],
          );
        },
      ),
    );
  }

  Widget _infoBanner() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _accentBlue.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _accentBlue.withOpacity(0.3)),
        ),
        child: Row(children: const [
          Icon(Icons.info_outline, color: _accentBlue, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Fee categories are the buckets that show up on every fee structure '
              'and on the payment screen. The four standard categories (Admission, '
              'Tuition, Exam, Van) are built in. Add custom ones (e.g. Sports, '
              'Library, Lab) and assign them to specific classes.',
              style: TextStyle(color: _textSecondary, fontSize: 12),
            ),
          ),
        ]),
      );

  Widget _emptyState(VoidCallback onAdd) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.category_outlined,
              size: 64, color: _textSecondary),
          const SizedBox(height: 16),
          const Text('No fee categories yet',
              style: TextStyle(color: _textPrimary, fontSize: 18)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentGreen,
              foregroundColor: Colors.white,
            ),
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Add Category'),
          ),
        ]),
      );

  Widget _categoryCard(BuildContext context, WidgetRef ref, String schoolId,
      FeeCategory cat) {
    final classes = cat.applicableClassIds.isEmpty
        ? 'All classes'
        : '${cat.applicableClassIds.length} class${cat.applicableClassIds.length == 1 ? '' : 'es'}';
    final money = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardDark,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _borderColor),
      ),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: (cat.isActive ? _accentGreen : _textSecondary)
                .withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Icon(
            cat.isStandard ? Icons.lock_outline : Icons.label_outline,
            color: cat.isActive ? _accentGreen : _textSecondary,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text(cat.name,
                    style: const TextStyle(
                        color: _textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
                const SizedBox(width: 8),
                if (cat.isStandard) _chip('STANDARD', _accentBlue),
                if (!cat.isActive) ...[
                  const SizedBox(width: 6),
                  _chip('INACTIVE', _textSecondary),
                ],
                if (cat.defaultAmount > 0) ...[
                  const SizedBox(width: 6),
                  _chip(money.format(cat.defaultAmount), _accentGreen),
                ],
              ]),
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.qr_code,
                    size: 12, color: _textSecondary),
                const SizedBox(width: 4),
                Text(cat.code,
                    style: const TextStyle(
                        color: _textSecondary,
                        fontFamily: 'monospace',
                        fontSize: 11)),
                const SizedBox(width: 12),
                const Icon(Icons.school_outlined,
                    size: 12, color: _textSecondary),
                const SizedBox(width: 4),
                Text(classes,
                    style: const TextStyle(
                        color: _textSecondary, fontSize: 11)),
              ]),
              if (cat.description.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(cat.description,
                    style: const TextStyle(
                        color: _textSecondary, fontSize: 11)),
              ],
            ],
          ),
        ),
        IconButton(
          tooltip: 'Edit',
          onPressed: () => _openEditor(context, ref, schoolId, cat),
          icon: const Icon(Icons.edit_outlined,
              color: _accentBlue, size: 18),
        ),
        if (!cat.isStandard)
          IconButton(
            tooltip: 'Delete',
            onPressed: () => _confirmDelete(context, ref, schoolId, cat),
            icon: const Icon(Icons.delete_outline,
                color: _accentRed, size: 18),
          ),
      ]),
    );
  }

  Widget _chip(String label, Color color) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(label,
            style: TextStyle(
                color: color,
                fontSize: 9,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5)),
      );

  void _openEditor(BuildContext context, WidgetRef ref, String schoolId,
      FeeCategory? existing) {
    showDialog(
      context: context,
      builder: (ctx) => _CategoryEditorDialog(
          schoolId: schoolId, existing: existing),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref,
      String schoolId, FeeCategory cat) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardDark,
        title: const Text('Delete category?',
            style: TextStyle(color: _textPrimary)),
        content: Text(
            'Delete "${cat.name}"? Existing structures and payments that '
            'reference this category will keep working but the category '
            'will no longer appear in new fee structures.',
            style: const TextStyle(color: _textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel',
                style: TextStyle(color: _textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: _accentRed,
                foregroundColor: Colors.white),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref
          .read(feeCategoryRepositoryProvider)
          .delete(schoolId, cat.code);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Deleted "${cat.name}"'),
              backgroundColor: _accentGreen),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed: $e'),
              backgroundColor: _accentRed),
        );
      }
    }
  }
}

/// Modal editor for a single FeeCategory.
class _CategoryEditorDialog extends ConsumerStatefulWidget {
  final String schoolId;
  final FeeCategory? existing;
  const _CategoryEditorDialog({required this.schoolId, this.existing});

  @override
  ConsumerState<_CategoryEditorDialog> createState() =>
      _CategoryEditorDialogState();
}

class _CategoryEditorDialogState
    extends ConsumerState<_CategoryEditorDialog> {
  final _nameCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _sortCtrl = TextEditingController(text: '100');
  final _amountCtrl = TextEditingController();
  bool _isActive = true;
  final Set<String> _classes = {};
  bool _saving = false;

  bool get _isEditing => widget.existing != null;
  bool get _isStandard => widget.existing?.isStandard ?? false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _nameCtrl.text = e.name;
      _codeCtrl.text = e.code;
      _descCtrl.text = e.description;
      _sortCtrl.text = e.sortOrder.toString();
      _amountCtrl.text = e.defaultAmount > 0 ? e.defaultAmount.toStringAsFixed(0) : '';
      _isActive = e.isActive;
      _classes.addAll(e.applicableClassIds);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    _descCtrl.dispose();
    _sortCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _cardDark,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 640),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.label_outline,
                    color: _accentBlue, size: 22),
                const SizedBox(width: 10),
                Text(
                  _isEditing ? 'Edit category' : 'Add fee category',
                  style: const TextStyle(
                      color: _textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close,
                      color: _textSecondary, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ]),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('Display name *'),
                      TextField(
                        controller: _nameCtrl,
                        style: const TextStyle(color: _textPrimary),
                        decoration: _input('e.g. Sports Fee'),
                        onChanged: (v) {
                          // Auto-derive code from name unless editing.
                          if (!_isEditing && _codeCtrl.text.isEmpty) {
                            _codeCtrl.text = _slug(v);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      _label('Code (UPPER_SNAKE_CASE) *'),
                      TextField(
                        controller: _codeCtrl,
                        enabled: !_isEditing && !_isStandard,
                        textCapitalization: TextCapitalization.characters,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'[A-Z0-9_]')),
                        ],
                        style: const TextStyle(
                            color: _textPrimary,
                            fontFamily: 'monospace'),
                        decoration: _input('e.g. SPORTS_FEE'),
                      ),
                      if (_isEditing)
                        const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Text(
                              'Code is immutable once created.',
                              style: TextStyle(
                                  color: _textSecondary,
                                  fontSize: 11)),
                        ),
                      const SizedBox(height: 12),
                      _label('Description (optional)'),
                      TextField(
                        controller: _descCtrl,
                        maxLines: 2,
                        style: const TextStyle(color: _textPrimary),
                        decoration: _input(
                            'Optional note shown in the admin UI'),
                      ),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _label('Default Amount (₹)'),
                              TextField(
                                controller: _amountCtrl,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))
                                ],
                                style: const TextStyle(color: _textPrimary),
                                decoration: _input('e.g. 5000'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _label('Sort order'),
                              TextField(
                                controller: _sortCtrl,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly
                                ],
                                style: const TextStyle(
                                    color: _textPrimary),
                                decoration: _input('100'),
                              ),
                            ],
                          ),
                        ),
                      ]),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _label('Status'),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12),
                                decoration: BoxDecoration(
                                  color: _bgDark,
                                  borderRadius: BorderRadius.circular(8),
                                  border:
                                      Border.all(color: _borderColor),
                                ),
                                child: Row(children: [
                                  const Text('Active',
                                      style: TextStyle(
                                          color: _textPrimary)),
                                  const Spacer(),
                                  Switch(
                                    value: _isActive,
                                    activeColor: _accentGreen,
                                    onChanged: (v) =>
                                        setState(() => _isActive = v),
                                  ),
                                ]),
                              ),
                            ],
                          ),
                        ),
                      ]),
                      const SizedBox(height: 16),
                      _label(
                          'Applicable classes (empty = all classes)'),
                      const SizedBox(height: 6),
                      _classPicker(),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('Cancel',
                        style: TextStyle(color: _textSecondary)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accentGreen,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white))
                        : Text(_isEditing ? 'Update' : 'Create'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _classPicker() {
    final studentsAsync =
        ref.watch(schoolStudentsProvider(widget.schoolId));
    return studentsAsync.when(
      loading: () => const SizedBox(
          height: 24,
          child: LinearProgressIndicator(color: _accentBlue)),
      error: (e, _) => Text('Failed to load classes: $e',
          style: const TextStyle(color: _accentRed, fontSize: 12)),
      data: (students) {
        final classes = students
            .map((s) => s.className)
            .where((c) => c.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
        // Include any pre-existing classes that are not in the student set
        final union = {...classes, ..._classes}.toList()..sort();
        if (union.isEmpty) {
          return const Text(
              'No classes available — add students first.',
              style: TextStyle(
                  color: _textSecondary, fontSize: 12));
        }
        return Wrap(
          spacing: 6,
          runSpacing: 6,
          children: union.map((c) {
            final selected = _classes.contains(c);
            return FilterChip(
              label: Text(c),
              selected: selected,
              onSelected: (_) => setState(() {
                if (selected) {
                  _classes.remove(c);
                } else {
                  _classes.add(c);
                }
              }),
              selectedColor: _accentGreen,
              backgroundColor: _bgDark,
              checkmarkColor: Colors.white,
              labelStyle: TextStyle(
                color: selected ? Colors.white : _textPrimary,
                fontSize: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
                side: BorderSide(
                    color: selected ? _accentGreen : _borderColor),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(text,
            style:
                const TextStyle(color: _textSecondary, fontSize: 12)),
      );

  InputDecoration _input(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: _textSecondary),
        filled: true,
        fillColor: _bgDark,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 10, vertical: 12),
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
          borderSide: const BorderSide(color: _accentGreen),
        ),
      );

  String _slug(String input) {
    return input
        .trim()
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final code = _codeCtrl.text.trim().toUpperCase();
    if (name.isEmpty) {
      _toast('Name is required', err: true);
      return;
    }
    if (code.isEmpty) {
      _toast('Code is required', err: true);
      return;
    }
    if (!RegExp(r'^[A-Z][A-Z0-9_]*$').hasMatch(code)) {
      _toast('Code must be UPPER_SNAKE_CASE and start with a letter',
          err: true);
      return;
    }

    setState(() => _saving = true);
    try {
      final repo = ref.read(feeCategoryRepositoryProvider);
      final category = FeeCategory(
        code: code,
        name: name,
        description: _descCtrl.text.trim(),
        isStandard: _isStandard,
        isActive: _isActive,
        applicableClassIds: _classes.toList()..sort(),
        sortOrder: int.tryParse(_sortCtrl.text.trim()) ?? 100,
        defaultAmount: double.tryParse(_amountCtrl.text.trim()) ?? 0,
        createdAt: widget.existing?.createdAt,
      );
      await repo.upsert(widget.schoolId, category);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(_isEditing ? 'Updated $name' : 'Created $name'),
              backgroundColor: _accentGreen),
        );
      }
    } catch (e) {
      _toast('Failed: $e', err: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toast(String msg, {bool err = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: err ? _accentRed : _accentGreen,
      ),
    );
  }
}
