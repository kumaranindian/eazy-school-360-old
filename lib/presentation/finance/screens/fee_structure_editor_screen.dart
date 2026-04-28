import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../data/repositories/fee_structure_v2_repository.dart';
import '../../../data/repositories/student_repository.dart';
import '../../../domain/entities/academic_year.dart';
import '../../../domain/entities/fee_structure_v2.dart';
import '../../../domain/entities/fee_term.dart';
import 'assign_fee_structure_screen.dart';

const Color _bgDark = Color(0xFF0D1117);
const Color _cardDark = Color(0xFF161B22);
const Color _accentGreen = Color(0xFF4CAF50);
const Color _accentBlue = Color(0xFF3B82F6);
const Color _accentRed = Color(0xFFEF4444);
const Color _textPrimary = Color(0xFFE6EDF3);
const Color _textSecondary = Color(0xFF8B949E);
const Color _borderColor = Color(0xFF30363D);

/// Opens the fee-structure editor as a constrained dialog (popup) instead of
/// pushing a new full-screen route. Returns when the dialog is dismissed.
Future<void> showFeeStructureEditorDialog({
  required BuildContext context,
  required String schoolId,
  String? structureId,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black87,
    builder: (ctx) {
      final size = MediaQuery.of(ctx).size;
      // On small screens use full-screen-ish; on desktop cap dimensions.
      final dialogWidth = size.width < 720 ? size.width : 880.0;
      final dialogHeight = size.height < 720 ? size.height : size.height * 0.92;
      return Dialog(
        backgroundColor: _bgDark,
        insetPadding: EdgeInsets.symmetric(
          horizontal: size.width < 720 ? 8 : 24,
          vertical: size.height < 720 ? 8 : 24,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: dialogWidth,
          height: dialogHeight,
          child: FeeStructureEditorScreen(
            schoolId: schoolId,
            structureId: structureId,
          ),
        ),
      );
    },
  );
}

class FeeStructureEditorScreen extends ConsumerStatefulWidget {
  const FeeStructureEditorScreen({
    super.key,
    required this.schoolId,
    this.structureId,
  });

  final String schoolId;
  final String? structureId;

  @override
  ConsumerState<FeeStructureEditorScreen> createState() =>
      _FeeStructureEditorScreenState();
}

class _FeeStructureEditorScreenState
    extends ConsumerState<FeeStructureEditorScreen> {
  final _nameCtrl = TextEditingController();
  final _yearCtrl = TextEditingController();
  FeeStructureType _type = FeeStructureType.TERM_WISE;
  bool _isActive = true;
  bool _isLoading = false;
  bool _initialised = false;

  final List<FeeTerm> _terms = [];
  final Set<String> _selectedClasses = {};

  bool get _isEditing => widget.structureId != null;

  @override
  void initState() {
    super.initState();
    _yearCtrl.text = AcademicYear.getCurrentYearCode();
    if (_isEditing) {
      _hydrate();
    } else {
      _initialised = true;
      // Default with one term for term-wise type.
      _terms.add(_blankTerm(1));
    }
  }

  Future<void> _hydrate() async {
    final repo = ref.read(feeStructureV2RepositoryProvider);
    final detail =
        await repo.getWithTerms(widget.schoolId, widget.structureId!);
    if (detail == null || !mounted) return;
    setState(() {
      _nameCtrl.text = detail.name;
      _yearCtrl.text = detail.academicYear;
      _type = detail.type;
      _isActive = detail.isActive;
      _terms
        ..clear()
        ..addAll(detail.terms);
      _selectedClasses
        ..clear()
        ..addAll(detail.applicableToClassIds);
      _initialised = true;
    });
  }

  FeeTerm _blankTerm(int seq) {
    // Anchor the next term's due date to the most recent existing term so the
    // user always starts with a strictly increasing sequence.
    final anchor = _terms.isEmpty
        ? DateTime.now()
        : _terms.last.dueDate;
    final due = anchor.add(const Duration(days: 60));
    return FeeTerm(
      id: 'tmp-$seq-${DateTime.now().millisecondsSinceEpoch}',
      termName: 'Term $seq',
      sequence: seq,
      amount: 0,
      dueDate: DateTime(due.year, due.month, due.day),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _yearCtrl.dispose();
    super.dispose();
  }

  double get _total => _terms.fold(0, (s, t) => s + t.amount);

  @override
  Widget build(BuildContext context) {
    if (!_initialised) {
      return const Scaffold(
        backgroundColor: _bgDark,
        body: Center(child: CircularProgressIndicator(color: _accentGreen)),
      );
    }
    return Scaffold(
      backgroundColor: _bgDark,
      appBar: AppBar(
        backgroundColor: _bgDark,
        elevation: 0,
        title: Text(_isEditing ? 'Edit Fee Structure' : 'New Fee Structure',
            style: const TextStyle(
                color: _textPrimary, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: _textPrimary),
        actions: [
          if (_isEditing) ...[
            IconButton(
              tooltip: 'Assign to students',
              icon: const Icon(Icons.group_add, color: _accentBlue),
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => AssignFeeStructureScreen(
                    schoolId: widget.schoolId,
                    structureId: widget.structureId!,
                  ),
                ));
              },
            ),
            IconButton(
              tooltip: _isActive ? 'Disable' : 'Enable',
              icon: Icon(_isActive ? Icons.toggle_on : Icons.toggle_off,
                  color: _isActive ? _accentGreen : _textSecondary, size: 28),
              onPressed: () => setState(() => _isActive = !_isActive),
            ),
          ],
          TextButton.icon(
            onPressed: _isLoading ? null : _save,
            icon: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        color: _accentGreen, strokeWidth: 2))
                : const Icon(Icons.save, color: _accentGreen),
            label: const Text('Save', style: TextStyle(color: _accentGreen)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _section('Basic Info', _basicInfoCard()),
            const SizedBox(height: 16),
            _section('Applicable Classes', _classesCard()),
            const SizedBox(height: 16),
            _section(
              'Terms (${_terms.length})',
              Column(children: [
                _generateBar(),
                const SizedBox(height: 8),
                for (int i = 0; i < _terms.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _TermEditorCard(
                      term: _terms[i],
                      onChanged: (t) => setState(() => _terms[i] = t),
                      onRemove: _terms.length > 1
                          ? () => setState(() => _terms.removeAt(i))
                          : null,
                    ),
                  ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => setState(
                        () => _terms.add(_blankTerm(_terms.length + 1))),
                    icon: const Icon(Icons.add, color: _accentBlue),
                    label: const Text('Add Term',
                        style: TextStyle(color: _accentBlue)),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 16),
            _totalsCard(),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, Widget child) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title,
          style: const TextStyle(
              color: _textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      child,
    ]);
  }

  Widget _basicInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Structure Name *',
              style: TextStyle(color: _textSecondary, fontSize: 12)),
          const SizedBox(height: 4),
          TextField(
            controller: _nameCtrl,
            style: const TextStyle(color: _textPrimary),
            decoration: _input('e.g. Standard Yearly 2026-27'),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Academic Year *',
                      style:
                          TextStyle(color: _textSecondary, fontSize: 12)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _yearCtrl,
                    style: const TextStyle(color: _textPrimary),
                    decoration: _input('2026-27'),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Type',
                      style:
                          TextStyle(color: _textSecondary, fontSize: 12)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: _bgDark,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _borderColor),
                    ),
                    child: DropdownButton<FeeStructureType>(
                      value: _type,
                      isExpanded: true,
                      underline: const SizedBox(),
                      dropdownColor: _cardDark,
                      iconEnabledColor: _textSecondary,
                      style: const TextStyle(color: _textPrimary),
                      items: FeeStructureType.values
                          .map((t) => DropdownMenuItem(
                                value: t,
                                child: Text(t.name.replaceAll('_', ' ')),
                              ))
                          .toList(),
                      onChanged: (v) => setState(
                          () => _type = v ?? FeeStructureType.TERM_WISE),
                    ),
                  ),
                ],
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _classesCard() {
    final studentsAsync = ref.watch(schoolStudentsProvider(widget.schoolId));
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor),
      ),
      child: studentsAsync.when(
        loading: () => const SizedBox(
          height: 40,
          child: Center(
              child: CircularProgressIndicator(
                  color: _accentGreen, strokeWidth: 2)),
        ),
        error: (e, _) => Text('Could not load classes: $e',
            style: const TextStyle(color: _textSecondary)),
        data: (students) {
          // Union of: classes that exist on students + classes already saved
          // on this structure (imported via Excel may have classes the school
          // hasn't enrolled students into yet).
          final fromStudents =
              students.map((s) => s.className).where((c) => c.isNotEmpty).toSet();
          final union = {...fromStudents, ..._selectedClasses}.toList()..sort();
          if (union.isEmpty) {
            return const Text(
                'No classes found. Add students first or import via Excel.',
                style: TextStyle(color: _textSecondary));
          }
          final classes = union;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: _accentBlue.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _accentBlue.withOpacity(0.25)),
                ),
                child: Row(children: [
                  const Icon(Icons.info_outline,
                      color: _accentBlue, size: 16),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'This list is metadata only — it does NOT auto-assign students. '
                      'Editing it here will not double-bill or remove anyone. '
                      'Use "Assign to students" (group icon, top right) to actually create or replace student ledgers, with full conflict-detection.',
                      style: TextStyle(
                          color: _textPrimary, fontSize: 11, height: 1.4),
                    ),
                  ),
                  if (_isEditing) ...[
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => AssignFeeStructureScreen(
                            schoolId: widget.schoolId,
                            structureId: widget.structureId!,
                          ),
                        ));
                      },
                      icon: const Icon(Icons.group_add,
                          color: _accentBlue, size: 16),
                      label: const Text('Assign now',
                          style: TextStyle(color: _accentBlue)),
                    ),
                  ],
                ]),
              ),
              Row(children: [
                const Expanded(
                  child: Text(
                    'Pick the classes this structure applies to. '
                    'Used by bulk-assign + reports.',
                    style: TextStyle(color: _textSecondary, fontSize: 12),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    if (_selectedClasses.length == classes.length) {
                      _selectedClasses.clear();
                    } else {
                      _selectedClasses
                        ..clear()
                        ..addAll(classes);
                    }
                  }),
                  child: Text(
                    _selectedClasses.length == classes.length
                        ? 'Clear all'
                        : 'Select all',
                    style: const TextStyle(color: _accentBlue),
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: classes.map((c) {
                  final selected = _selectedClasses.contains(c);
                  return FilterChip(
                    label: Text(c),
                    selected: selected,
                    onSelected: (_) => setState(() {
                      if (selected) {
                        _selectedClasses.remove(c);
                      } else {
                        _selectedClasses.add(c);
                      }
                    }),
                    selectedColor: _accentGreen,
                    backgroundColor: _bgDark,
                    side: BorderSide(
                      color: selected ? _accentGreen : _borderColor,
                    ),
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : _textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  );
                }).toList(),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _generateBar() {
    final label = switch (_type) {
      FeeStructureType.MONTHLY => 'Generate 12 monthly terms',
      FeeStructureType.TERM_WISE => 'Generate 3 quarterly terms',
      FeeStructureType.YEARLY => 'Generate 1 annual term',
      FeeStructureType.CUSTOM => 'Generate 4 installments',
    };
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _accentBlue.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _accentBlue.withOpacity(0.25)),
      ),
      child: Row(children: [
        const Icon(Icons.auto_fix_high, color: _accentBlue, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Quick start: $label. Replaces existing draft terms.',
            style: const TextStyle(color: _textPrimary, fontSize: 12),
          ),
        ),
        TextButton(
          onPressed: _confirmAndGenerate,
          child: const Text('Generate',
              style: TextStyle(color: _accentBlue)),
        ),
      ]),
    );
  }

  Future<void> _confirmAndGenerate() async {
    if (_terms.isNotEmpty) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: _cardDark,
          title: const Text('Replace existing terms?',
              style: TextStyle(color: _textPrimary)),
          content: const Text(
              'This will discard the current term list and create new ones from the selected type.',
              style: TextStyle(color: _textSecondary)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel',
                  style: TextStyle(color: _textSecondary)),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Replace',
                  style: TextStyle(color: _accentRed)),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    setState(() {
      _terms
        ..clear()
        ..addAll(_generateTerms(_type));
    });
  }

  /// Generates a sensible default set of terms for a given frequency type.
  /// Indian school AY runs **June → May (next year)**:
  ///   * Yearly      → due 31-May of next year (end of session).
  ///   * Term-wise   → 3 terms, due 5-Jun / 5-Oct / 5-Feb.
  ///   * Monthly     → 12 entries June → May, due 5th of each month.
  ///   * Custom      → 4 quarterly installments, due 5-Jun / 5-Sep / 5-Dec / 5-Mar.
  List<FeeTerm> _generateTerms(FeeStructureType type) {
    final ay = _yearCtrl.text.trim();
    int startYear = DateTime.now().year;
    final m = RegExp(r'^(\d{4})').firstMatch(ay);
    if (m != null) startYear = int.parse(m.group(1)!);
    final base = DateTime(startYear, 6, 5); // 5-June of start year.

    DateTime addMonths(DateTime d, int months) {
      final y = d.year + ((d.month - 1 + months) ~/ 12);
      final mo = ((d.month - 1 + months) % 12) + 1;
      final lastDay = DateTime(y, mo + 1, 0).day;
      final day = d.day > lastDay ? lastDay : d.day;
      return DateTime(y, mo, day);
    }

    String tmpId(int i) =>
        'tmp-gen-$i-${DateTime.now().millisecondsSinceEpoch + i}';

    switch (type) {
      case FeeStructureType.YEARLY:
        return [
          FeeTerm(
            id: tmpId(1),
            termName: 'Annual Fee',
            sequence: 1,
            amount: 0,
            dueDate: DateTime(startYear + 1, 5, 31), // end of AY
          ),
        ];
      case FeeStructureType.TERM_WISE:
        return List.generate(3, (i) {
          return FeeTerm(
            id: tmpId(i + 1),
            termName: 'Term ${i + 1}',
            sequence: i + 1,
            amount: 0,
            dueDate: addMonths(base, i * 4),
          );
        });
      case FeeStructureType.MONTHLY:
        const months = [
          'June', 'July', 'August', 'September', 'October', 'November',
          'December', 'January', 'February', 'March', 'April', 'May'
        ];
        return List.generate(12, (i) {
          return FeeTerm(
            id: tmpId(i + 1),
            termName: months[i],
            sequence: i + 1,
            amount: 0,
            dueDate: addMonths(base, i),
          );
        });
      case FeeStructureType.CUSTOM:
        return List.generate(4, (i) {
          return FeeTerm(
            id: tmpId(i + 1),
            termName: 'Installment ${i + 1}',
            sequence: i + 1,
            amount: 0,
            dueDate: addMonths(base, i * 3),
          );
        });
    }
  }

  Widget _totalsCard() {
    final money =
        NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _accentGreen.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _accentGreen.withOpacity(0.3)),
      ),
      child: Row(children: [
        const Icon(Icons.functions, color: _accentGreen),
        const SizedBox(width: 12),
        const Expanded(
            child: Text('Total (sum of all terms)',
                style: TextStyle(
                    color: _textPrimary, fontWeight: FontWeight.w500))),
        Text(money.format(_total),
            style: const TextStyle(
                color: _accentGreen,
                fontWeight: FontWeight.bold,
                fontSize: 20)),
      ]),
    );
  }

  InputDecoration _input(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: _textSecondary),
        filled: true,
        fillColor: _bgDark,
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
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      );

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      _toast('Please enter a structure name', error: true);
      return;
    }
    if (_yearCtrl.text.trim().isEmpty) {
      _toast('Please enter an academic year', error: true);
      return;
    }
    if (_terms.isEmpty) {
      _toast('Add at least one term', error: true);
      return;
    }
    for (final t in _terms) {
      if (t.termName.trim().isEmpty) {
        _toast('All terms must have a name', error: true);
        return;
      }
      if (t.amount <= 0) {
        _toast('All terms must have an amount > 0', error: true);
        return;
      }
    }
    // Due dates must be strictly increasing in the same order the terms appear.
    for (var i = 1; i < _terms.length; i++) {
      final prev = _terms[i - 1];
      final curr = _terms[i];
      if (!curr.dueDate.isAfter(prev.dueDate)) {
        _toast(
          'Due date of "${curr.termName}" (${DateFormat('dd MMM yyyy').format(curr.dueDate)}) '
          'must be after "${prev.termName}" (${DateFormat('dd MMM yyyy').format(prev.dueDate)}).',
          error: true,
        );
        return;
      }
    }

    setState(() => _isLoading = true);
    try {
      final repo = ref.read(feeStructureV2RepositoryProvider);
      final session = ref.read(currentSessionProvider);
      final now = DateTime.now();

      // Re-sequence + assign sequential IDs for new terms only (existing keep their ids).
      final normalized = <FeeTerm>[];
      for (var i = 0; i < _terms.length; i++) {
        final t = _terms[i];
        normalized.add(t.copyWith(sequence: i + 1));
      }

      if (_isEditing) {
        final structure = FeeStructureV2(
          id: widget.structureId!,
          schoolId: widget.schoolId,
          name: _nameCtrl.text.trim(),
          academicYear: _yearCtrl.text.trim(),
          type: _type,
          totalAmount: _total,
          termCount: normalized.length,
          applicableToClassIds: _selectedClasses.toList()..sort(),
          isActive: _isActive,
          createdBy: session?.uid,
          createdAt: now,
          updatedAt: now,
        );
        await repo.update(
            widget.schoolId, widget.structureId!, structure, normalized);
      } else {
        final structure = FeeStructureV2(
          id: '',
          schoolId: widget.schoolId,
          name: _nameCtrl.text.trim(),
          academicYear: _yearCtrl.text.trim(),
          type: _type,
          totalAmount: _total,
          termCount: normalized.length,
          applicableToClassIds: _selectedClasses.toList()..sort(),
          isActive: _isActive,
          createdBy: session?.uid,
          createdAt: now,
          updatedAt: now,
        );
        await repo.create(widget.schoolId, structure, normalized);
      }

      if (mounted) {
        _toast('Fee structure saved');
        Navigator.of(context).pop();
      }
    } catch (e) {
      _toast('Failed to save: $e', error: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _toast(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? _accentRed : _accentGreen,
      ),
    );
  }
}

class _TermEditorCard extends StatelessWidget {
  const _TermEditorCard({
    required this.term,
    required this.onChanged,
    required this.onRemove,
  });

  final FeeTerm term;
  final ValueChanged<FeeTerm> onChanged;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final money =
        NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _accentBlue.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('#${term.sequence}',
                  style: const TextStyle(
                      color: _accentBlue, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                initialValue: term.termName,
                style: const TextStyle(
                    color: _textPrimary, fontWeight: FontWeight.w600),
                cursorColor: _accentGreen,
                decoration: const InputDecoration(
                  isDense: true,
                  filled: true,
                  fillColor: Colors.transparent,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  hintText: 'Term name',
                  hintStyle: TextStyle(color: _textSecondary),
                ),
                onChanged: (v) => onChanged(term.copyWith(termName: v)),
              ),
            ),
            if (onRemove != null)
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    color: _accentRed, size: 20),
                onPressed: onRemove,
              ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: _smallField(
                label: 'Amount',
                initial: term.amount > 0 ? term.amount.toStringAsFixed(0) : '',
                hint: '0',
                keyboard: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (v) =>
                    onChanged(term.copyWith(amount: double.tryParse(v) ?? 0)),
                prefix: '₹ ',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _DateField(
                label: 'Due date',
                value: term.dueDate,
                onChanged: (d) => onChanged(term.copyWith(dueDate: d)),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: _switch(
                label: 'Late fee',
                value: term.lateFee.enabled,
                onChanged: (b) => onChanged(term.copyWith(
                    lateFee: term.lateFee.copyWith(enabled: b))),
              ),
            ),
            Expanded(
              child: _switch(
                label: 'Reminders',
                value: term.reminderConfig.enabled,
                onChanged: (b) => onChanged(term.copyWith(
                    reminderConfig:
                        term.reminderConfig.copyWith(enabled: b))),
              ),
            ),
          ]),
          if (term.lateFee.enabled) ...[
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: _smallField(
                  label: 'Late fee ₹',
                  initial: term.lateFee.amount > 0
                      ? term.lateFee.amount.toStringAsFixed(0)
                      : '',
                  hint: '0',
                  keyboard:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (v) => onChanged(term.copyWith(
                      lateFee: term.lateFee
                          .copyWith(amount: double.tryParse(v) ?? 0))),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _smallField(
                  label: 'Grace days',
                  initial: term.lateFee.graceDays > 0
                      ? term.lateFee.graceDays.toString()
                      : '',
                  hint: '0',
                  keyboard: TextInputType.number,
                  onChanged: (v) => onChanged(term.copyWith(
                      lateFee: term.lateFee
                          .copyWith(graceDays: int.tryParse(v) ?? 0))),
                ),
              ),
            ]),
          ],
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: Text('Subtotal: ${money.format(term.amount)}',
                style:
                    const TextStyle(color: _textSecondary, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _smallField({
    required String label,
    required String initial,
    required String hint,
    required TextInputType keyboard,
    required ValueChanged<String> onChanged,
    String? prefix,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: _textSecondary, fontSize: 11)),
        const SizedBox(height: 4),
        TextFormField(
          initialValue: initial,
          keyboardType: keyboard,
          inputFormatters: keyboard == TextInputType.number
              ? [FilteringTextInputFormatter.digitsOnly]
              : [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
          style: const TextStyle(color: _textPrimary),
          decoration: InputDecoration(
            isDense: true,
            hintText: hint,
            hintStyle: const TextStyle(color: _textSecondary),
            prefixText: prefix,
            prefixStyle: const TextStyle(color: _textSecondary),
            filled: true,
            fillColor: _bgDark,
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
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _switch({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(children: [
      Switch(
        value: value,
        onChanged: onChanged,
        activeColor: _accentGreen,
      ),
      Expanded(
        child: Text(label,
            style: const TextStyle(color: _textSecondary, fontSize: 12)),
      ),
    ]);
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final DateTime value;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: _textSecondary, fontSize: 11)),
        const SizedBox(height: 4),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: value,
              firstDate: DateTime(2020),
              lastDate: DateTime(2035),
              builder: (c, child) => Theme(
                data: Theme.of(c).copyWith(
                  colorScheme: ColorScheme.dark(
                    primary: _accentGreen,
                    onPrimary: Colors.white,
                    surface: _cardDark,
                    onSurface: _textPrimary,
                  ),
                ),
                child: child!,
              ),
            );
            if (picked != null) onChanged(picked);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: _bgDark,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _borderColor),
            ),
            child: Row(children: [
              const Icon(Icons.event,
                  size: 14, color: _textSecondary),
              const SizedBox(width: 6),
              Text(DateFormat('dd MMM yyyy').format(value),
                  style: const TextStyle(
                      color: _textPrimary, fontSize: 13)),
            ]),
          ),
        ),
      ],
    );
  }
}
