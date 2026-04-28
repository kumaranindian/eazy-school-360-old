import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/fee_structure_v2_repository.dart';
import '../../../data/repositories/student_fee_ledger_repository.dart';
import '../../../data/repositories/student_repository.dart';
import '../../../domain/entities/fee_structure_v2.dart';
import '../../../domain/entities/student.dart';

const Color _bgDark = Color(0xFF0D1117);
const Color _cardDark = Color(0xFF161B22);
const Color _accentGreen = Color(0xFF4CAF50);
const Color _accentBlue = Color(0xFF3B82F6);
const Color _accentRed = Color(0xFFEF4444);
const Color _textPrimary = Color(0xFFE6EDF3);
const Color _textSecondary = Color(0xFF8B949E);
const Color _borderColor = Color(0xFF30363D);

/// Assigns a fee structure to a selectable list of students.
/// - Filter students by class.
/// - Multi-select (or "select all in class").
/// - Calls [StudentFeeLedgerRepository.assignToStudent] per selection.
class AssignFeeStructureScreen extends ConsumerStatefulWidget {
  const AssignFeeStructureScreen({
    super.key,
    required this.schoolId,
    required this.structureId,
  });

  final String schoolId;
  final String structureId;

  @override
  ConsumerState<AssignFeeStructureScreen> createState() =>
      _AssignFeeStructureScreenState();
}

class _AssignFeeStructureScreenState
    extends ConsumerState<AssignFeeStructureScreen> {
  String? _classFilter;
  final Set<String> _selectedIds = {};
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final structureAsync = ref.watch(feeStructureV2DetailProvider(
      (schoolId: widget.schoolId, structureId: widget.structureId),
    ));
    final studentsAsync = ref.watch(schoolStudentsProvider(widget.schoolId));

    return Scaffold(
      backgroundColor: _bgDark,
      appBar: AppBar(
        backgroundColor: _bgDark,
        elevation: 0,
        title: const Text('Assign Fee Structure',
            style: TextStyle(color: _textPrimary, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: _textPrimary),
        actions: [
          TextButton.icon(
            onPressed: _saving || _selectedIds.isEmpty
                ? null
                : () => _assign(structureAsync.value),
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        color: _accentGreen, strokeWidth: 2))
                : const Icon(Icons.check, color: _accentGreen),
            label: Text(
              _saving ? 'Assigning…' : 'Assign (${_selectedIds.length})',
              style: const TextStyle(color: _accentGreen),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: structureAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: _accentGreen)),
        error: (e, _) => Center(
          child: Text('Error: $e',
              style: const TextStyle(color: _textSecondary)),
        ),
        data: (structure) {
          if (structure == null) {
            return const Center(
                child: Text('Structure not found',
                    style: TextStyle(color: _textSecondary)));
          }
          return Column(
            children: [
              _structureBanner(structure),
              Expanded(
                child: studentsAsync.when(
                  loading: () => const Center(
                      child: CircularProgressIndicator(color: _accentGreen)),
                  error: (e, _) => Center(
                    child: Text('Error: $e',
                        style: const TextStyle(color: _textSecondary)),
                  ),
                  data: (students) =>
                      _studentsBody(students, structure),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _structureBanner(FeeStructureV2 s) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _accentBlue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _accentBlue.withOpacity(0.3)),
      ),
      child: Row(children: [
        const Icon(Icons.receipt_long, color: _accentBlue),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.name,
                  style: const TextStyle(
                      color: _textPrimary, fontWeight: FontWeight.bold)),
              Text(
                  '${s.type.name.replaceAll('_', ' ')} • AY ${s.academicYear} • ${s.termCount} terms',
                  style: const TextStyle(
                      color: _textSecondary, fontSize: 12)),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _studentsBody(List<Student> all, FeeStructureV2 structure) {
    final classes = all.map((s) => s.className).toSet().toList()..sort();
    final filtered = _classFilter == null
        ? all
        : all.where((s) => s.className == _classFilter).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: _cardDark,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _borderColor),
                ),
                child: DropdownButton<String?>(
                  value: _classFilter,
                  isExpanded: true,
                  underline: const SizedBox(),
                  dropdownColor: _cardDark,
                  iconEnabledColor: _textSecondary,
                  hint: const Text('Filter by class…',
                      style: TextStyle(color: _textSecondary)),
                  style: const TextStyle(color: _textPrimary),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('All classes'),
                    ),
                    ...classes.map((c) =>
                        DropdownMenuItem<String?>(value: c, child: Text(c))),
                  ],
                  onChanged: (v) => setState(() => _classFilter = v),
                ),
              ),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: () => setState(() {
                final allSelected =
                    filtered.every((s) => _selectedIds.contains(s.id));
                if (allSelected) {
                  _selectedIds.removeAll(filtered.map((s) => s.id));
                } else {
                  _selectedIds.addAll(filtered.map((s) => s.id));
                }
              }),
              icon: const Icon(Icons.checklist, color: _accentBlue, size: 18),
              label: const Text('Select all',
                  style: TextStyle(color: _accentBlue)),
            ),
          ]),
        ),
        Expanded(
          child: filtered.isEmpty
              ? const Center(
                  child: Text('No students match.',
                      style: TextStyle(color: _textSecondary)),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (_, i) {
                    final s = filtered[i];
                    final selected = _selectedIds.contains(s.id);
                    return InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => setState(() {
                        if (selected) {
                          _selectedIds.remove(s.id);
                        } else {
                          _selectedIds.add(s.id);
                        }
                      }),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _cardDark,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: selected
                                  ? _accentGreen
                                  : _borderColor),
                        ),
                        child: Row(children: [
                          Icon(
                            selected
                                ? Icons.check_box
                                : Icons.check_box_outline_blank,
                            color: selected
                                ? _accentGreen
                                : _textSecondary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(s.name,
                                    style: const TextStyle(
                                        color: _textPrimary,
                                        fontWeight: FontWeight.w600)),
                                Text(
                                    '${s.className} • ${s.section}'
                                    '${s.parentPhone != null && s.parentPhone!.isNotEmpty ? ' • ${s.parentPhone}' : ''}',
                                    style: const TextStyle(
                                        color: _textSecondary,
                                        fontSize: 12)),
                              ],
                            ),
                          ),
                        ]),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _assign(FeeStructureV2? structure) async {
    if (structure == null) return;
    final all = ref.read(schoolStudentsProvider(widget.schoolId)).value ?? [];
    final picked = all.where((s) => _selectedIds.contains(s.id)).toList();
    if (picked.isEmpty) return;

    setState(() => _saving = true);
    final repo = ref.read(studentFeeLedgerRepositoryProvider);

    try {
      // 1. Pre-flight: discover what each pick would do without mutating.
      final targets = picked
          .map((s) => AssignTarget(
                studentId: s.id,
                studentName: s.name,
                className: s.className,
                section: s.section,
                parentName: s.parentName,
                parentPhone: s.parentPhone,
              ))
          .toList();
      final plan = await repo.planAssignment(
        schoolId: widget.schoolId,
        structure: structure,
        students: targets,
      );

      // 2. If there are conflicts, ask the admin how to handle them.
      ConflictAction action = ConflictAction.SKIP;
      if (plan.hasAnyConflict) {
        final chosen = await _showConflictDialog(plan);
        if (chosen == null) {
          // User cancelled.
          return;
        }
        action = chosen;
      }

      // 3. Commit using the chosen policy.
      final results = await repo.assignToStudents(
        schoolId: widget.schoolId,
        structureId: widget.structureId,
        students: targets,
        onConflict: action,
      );

      if (!mounted) return;
      _showResultSummary(results);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed: $e'),
        backgroundColor: _accentRed,
      ));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<ConflictAction?> _showConflictDialog(AssignmentPlan plan) {
    return showDialog<ConflictAction>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: _cardDark,
          title: const Row(children: [
            Icon(Icons.warning_amber_rounded, color: _accentRed),
            SizedBox(width: 8),
            Text('Conflicts detected',
                style: TextStyle(color: _textPrimary)),
          ]),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _summaryLine(
                    Icons.fiber_new, _accentGreen, 'New assignments',
                    plan.newCount),
                _summaryLine(Icons.check_circle, _accentGreen,
                    'Already on this structure (will refresh)',
                    plan.alreadyAssignedCount),
                _summaryLine(Icons.swap_horiz, Colors.orange,
                    'Have a different structure (no payments yet)',
                    plan.conflictNoPaidCount),
                _summaryLine(Icons.attach_money, _accentRed,
                    'Have a different structure WITH PAYMENTS',
                    plan.conflictWithPaidCount),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _accentRed.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _accentRed.withOpacity(0.3)),
                  ),
                  child: Text(
                    plan.hasPaidConflict
                        ? 'WARNING: ${plan.conflictWithPaidCount} student(s) already paid into a '
                            'different fee structure for ${plan.structure.academicYear}. '
                            'Replacing will archive their old ledger (history preserved) '
                            'and start a fresh ledger on "${plan.structure.name}". '
                            'They will not be double-billed but you must reconcile any '
                            'paid amounts manually.'
                        : 'Some students already have a different fee structure for '
                            '${plan.structure.academicYear}. Choose how to proceed.',
                    style: const TextStyle(
                        color: _textPrimary, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: const Text('Cancel',
                  style: TextStyle(color: _textSecondary)),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(ctx).pop(ConflictAction.SKIP),
              child: const Text('Skip conflicts',
                  style: TextStyle(color: _accentBlue)),
            ),
            TextButton(
              onPressed: () async {
                if (plan.hasPaidConflict) {
                  final confirmed = await _confirmReplaceWithPaid(
                      ctx, plan.conflictWithPaidCount);
                  if (confirmed != true) return;
                }
                if (ctx.mounted) {
                  Navigator.of(ctx).pop(ConflictAction.REPLACE);
                }
              },
              child: Text(
                plan.hasPaidConflict
                    ? 'Replace (archive old)'
                    : 'Replace existing',
                style: const TextStyle(color: _accentRed),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<bool?> _confirmReplaceWithPaid(BuildContext ctx, int count) {
    return showDialog<bool>(
      context: ctx,
      builder: (innerCtx) => AlertDialog(
        backgroundColor: _cardDark,
        title: const Text('Confirm replacement',
            style: TextStyle(color: _accentRed)),
        content: Text(
          '$count student(s) have already paid into their current fee structure. '
          'Replacing will archive their old ledger (audit history preserved) and create '
          'a fresh ledger on the new structure with ZERO paid balance. '
          '\n\nYou will need to reconcile their paid amounts manually. '
          '\n\nAre you sure?',
          style: const TextStyle(color: _textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(innerCtx).pop(false),
            child: const Text('Cancel',
                style: TextStyle(color: _textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(innerCtx).pop(true),
            child: const Text('Yes, replace',
                style: TextStyle(color: _accentRed)),
          ),
        ],
      ),
    );
  }

  Widget _summaryLine(
      IconData icon, Color color, String label, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label,
              style: const TextStyle(color: _textPrimary, fontSize: 13)),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text('$count',
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 13)),
        ),
      ]),
    );
  }

  void _showResultSummary(List<AssignmentResult> results) {
    final newCount =
        results.where((r) => r.outcome == AssignmentOutcome.NEW).length;
    final refreshed = results
        .where((r) => r.outcome == AssignmentOutcome.ALREADY_ASSIGNED)
        .length;
    final replaced = results
        .where((r) =>
            r.outcome == AssignmentOutcome.REPLACED ||
            r.outcome == AssignmentOutcome.REPLACED_WITH_PAID)
        .length;
    final skipped = results.where((r) => r.skipped).length;
    final errors =
        results.where((r) => r.outcome == AssignmentOutcome.ERROR).toList();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardDark,
        title: const Text('Bulk assignment complete',
            style: TextStyle(color: _textPrimary)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (newCount > 0)
                _summaryLine(
                    Icons.fiber_new, _accentGreen, 'New ledgers created', newCount),
              if (refreshed > 0)
                _summaryLine(Icons.refresh, _accentBlue,
                    'Existing refreshed (paid amounts preserved)', refreshed),
              if (replaced > 0)
                _summaryLine(Icons.swap_horiz, Colors.orange,
                    'Replaced (old archived)', replaced),
              if (skipped > 0)
                _summaryLine(Icons.skip_next, _textSecondary,
                    'Skipped due to conflict', skipped),
              if (errors.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Errors (${errors.length}):',
                    style: const TextStyle(
                        color: _accentRed, fontWeight: FontWeight.bold)),
                ...errors.map((e) => Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('• ${e.error ?? "Unknown error"}',
                          style: const TextStyle(
                              color: _textSecondary, fontSize: 11)),
                    )),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              if (errors.isEmpty) {
                Navigator.of(context).pop();
              }
            },
            child: const Text('OK',
                style: TextStyle(color: _accentBlue)),
          ),
        ],
      ),
    );
  }
}
