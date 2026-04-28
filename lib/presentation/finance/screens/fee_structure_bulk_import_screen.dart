import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../data/repositories/fee_structure_v2_repository.dart';
import '../../../data/services/fee_structure_excel_service.dart';
import '../../../domain/entities/fee_structure_v2.dart';

const Color _bgDark = Color(0xFF0D1117);
const Color _cardDark = Color(0xFF161B22);
const Color _accentGreen = Color(0xFF4CAF50);
const Color _accentBlue = Color(0xFF3B82F6);
const Color _accentRed = Color(0xFFEF4444);
const Color _accentAmber = Color(0xFFF59E0B);
const Color _textPrimary = Color(0xFFE6EDF3);
const Color _textSecondary = Color(0xFF8B949E);
const Color _borderColor = Color(0xFF30363D);

/// Lets the user review the parsed Excel content before committing it to
/// Firestore. They can untick individual structures, then press **Import**.
class FeeStructureBulkImportScreen extends ConsumerStatefulWidget {
  const FeeStructureBulkImportScreen({
    super.key,
    required this.schoolId,
    required this.parsed,
  });

  final String schoolId;
  final ParsedFeeStructureImport parsed;

  @override
  ConsumerState<FeeStructureBulkImportScreen> createState() =>
      _FeeStructureBulkImportScreenState();
}

class _FeeStructureBulkImportScreenState
    extends ConsumerState<FeeStructureBulkImportScreen> {
  late final Set<int> _selected;
  bool _saving = false;
  int _imported = 0;

  @override
  void initState() {
    super.initState();
    _selected = {for (var i = 0; i < widget.parsed.structures.length; i++) i};
  }

  @override
  Widget build(BuildContext context) {
    final structures = widget.parsed.structures;
    final money =
        NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return Scaffold(
      backgroundColor: _bgDark,
      appBar: AppBar(
        backgroundColor: _bgDark,
        elevation: 0,
        title: const Text('Bulk Import Preview',
            style: TextStyle(color: _textPrimary, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: _textPrimary),
        actions: [
          TextButton.icon(
            onPressed: _saving || _selected.isEmpty ? null : _commit,
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        color: _accentGreen, strokeWidth: 2),
                  )
                : const Icon(Icons.cloud_upload, color: _accentGreen),
            label: Text(
              _saving
                  ? 'Importing $_imported / ${_selected.length}…'
                  : 'Import (${_selected.length})',
              style: const TextStyle(color: _accentGreen),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _summaryBanner(structures, money),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: structures.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final s = structures[i];
                final selected = _selected.contains(i);
                return _StructurePreviewCard(
                  structure: s,
                  selected: selected,
                  money: money,
                  onToggle: () => setState(() {
                    if (selected) {
                      _selected.remove(i);
                    } else {
                      _selected.add(i);
                    }
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryBanner(
      List<ParsedFeeStructure> all, NumberFormat money) {
    final totalTerms =
        all.fold<int>(0, (s, p) => s + p.terms.length);
    final grand =
        all.fold<double>(0, (s, p) => s + p.totalAmount);
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _accentBlue.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _accentBlue.withOpacity(0.25)),
      ),
      child: Row(children: [
        const Icon(Icons.preview_outlined, color: _accentBlue),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${all.length} fee structure(s) • $totalTerms term(s) • '
                'total ${money.format(grand)}',
                style: const TextStyle(
                    color: _textPrimary, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              const Text(
                'Untick anything you don\'t want. Existing structures with the same name + AY will be skipped (not overwritten).',
                style: TextStyle(color: _textSecondary, fontSize: 11),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: () => setState(() {
            if (_selected.length == all.length) {
              _selected.clear();
            } else {
              _selected
                ..clear()
                ..addAll(List.generate(all.length, (i) => i));
            }
          }),
          child: Text(
            _selected.length == all.length ? 'Clear all' : 'Select all',
            style: const TextStyle(color: _accentBlue),
          ),
        ),
      ]),
    );
  }

  Future<void> _commit() async {
    setState(() {
      _saving = true;
      _imported = 0;
    });
    final session = ref.read(currentSessionProvider);
    final repo = ref.read(feeStructureV2RepositoryProvider);
    final now = DateTime.now();
    final picked = _selected.toList()..sort();
    final errors = <String>[];
    int ok = 0;

    try {
      // Pre-load existing structures so we can skip duplicates
      // (same name + academicYear).
      final existing = await repo.listAll(widget.schoolId);
      final existingKeys = existing
          .map((s) =>
              '${s.name.toLowerCase()}__${s.academicYear.toLowerCase()}')
          .toSet();

      for (final i in picked) {
        final p = widget.parsed.structures[i];
        final key = '${p.name.toLowerCase()}__${p.academicYear.toLowerCase()}';
        if (existingKeys.contains(key)) {
          errors.add('Skipped "${p.name}" / ${p.academicYear} (already exists)');
          if (mounted) setState(() => _imported++);
          continue;
        }
        try {
          final structure = FeeStructureV2(
            id: '',
            schoolId: widget.schoolId,
            name: p.name,
            academicYear: p.academicYear,
            type: p.type,
            totalAmount: p.totalAmount,
            termCount: p.terms.length,
            applicableToClassIds: p.classes,
            isActive: true,
            createdBy: session?.uid,
            createdAt: now,
            updatedAt: now,
          );
          await repo.create(widget.schoolId, structure, p.terms);
          ok++;
        } catch (e) {
          errors.add('"${p.name}": $e');
        }
        if (mounted) setState(() => _imported++);
      }
    } catch (e) {
      errors.add('Pre-flight failed: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }

    if (!mounted) return;
    if (errors.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Imported $ok fee structure(s)'),
        backgroundColor: _accentGreen,
      ));
      Navigator.of(context).pop();
    } else {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: _cardDark,
          title: Text('Import finished — $ok added',
              style: const TextStyle(color: _textPrimary)),
          content: SingleChildScrollView(
            child: SelectableText(
              errors.join('\n'),
              style: const TextStyle(
                  color: _textSecondary, fontSize: 12),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                if (ok > 0) Navigator.of(context).pop();
              },
              child: const Text('OK',
                  style: TextStyle(color: _accentBlue)),
            ),
          ],
        ),
      );
    }
  }
}

class _StructurePreviewCard extends StatelessWidget {
  const _StructurePreviewCard({
    required this.structure,
    required this.selected,
    required this.onToggle,
    required this.money,
  });

  final ParsedFeeStructure structure;
  final bool selected;
  final VoidCallback onToggle;
  final NumberFormat money;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _cardDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: selected ? _accentGreen : _borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(
                selected
                    ? Icons.check_box
                    : Icons.check_box_outline_blank,
                color: selected ? _accentGreen : _textSecondary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  structure.name,
                  style: const TextStyle(
                    color: _textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _accentBlue.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  structure.type.name.replaceAll('_', ' '),
                  style: const TextStyle(
                      color: _accentBlue,
                      fontSize: 10,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                _meta(Icons.calendar_month_outlined,
                    'AY ${structure.academicYear}'),
                _meta(Icons.school_outlined,
                    'Classes: ${structure.classes.join(", ")}'),
                _meta(
                    Icons.format_list_numbered,
                    '${structure.terms.length} term(s)'),
                _meta(Icons.attach_money,
                    'Total ${money.format(structure.totalAmount)}',
                    color: _accentGreen),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: _bgDark,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _borderColor),
              ),
              child: Column(
                children: structure.terms
                    .map((t) => Padding(
                          padding:
                              const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: _accentBlue.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text('#${t.sequence}',
                                    style: const TextStyle(
                                        color: _accentBlue,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${t.termName} • ${DateFormat('dd MMM yyyy').format(t.dueDate)}'
                                  '${t.lateFee.enabled ? ' • late ${money.format(t.lateFee.amount)} after ${t.lateFee.graceDays}d' : ''}',
                                  style: const TextStyle(
                                      color: _textPrimary,
                                      fontSize: 12),
                                ),
                              ),
                              Text(money.format(t.amount),
                                  style: const TextStyle(
                                      color: _accentAmber,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12)),
                            ],
                          ),
                        ))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _meta(IconData icon, String label, {Color? color}) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: color ?? _textSecondary),
      const SizedBox(width: 4),
      Text(label,
          style: TextStyle(color: color ?? _textSecondary, fontSize: 11)),
    ]);
  }
}

// Suppress unused warning for _accentRed (kept for parity with other screens).
// ignore: unused_element
const Color _kReservedRed = _accentRed;
