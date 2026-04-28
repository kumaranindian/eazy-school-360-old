import 'dart:typed_data';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../data/repositories/fee_structure_v2_repository.dart';
import '../../../data/services/fee_structure_excel_service.dart';
import '../../../domain/entities/fee_structure_v2.dart';
import 'fee_structure_editor_screen.dart';
import 'fee_structure_bulk_import_screen.dart';

const Color _bgDark = Color(0xFF0D1117);
const Color _cardDark = Color(0xFF161B22);
const Color _accentGreen = Color(0xFF4CAF50);
const Color _accentBlue = Color(0xFF3B82F6);
const Color _textPrimary = Color(0xFFE6EDF3);
const Color _textSecondary = Color(0xFF8B949E);
const Color _borderColor = Color(0xFF30363D);

class FeeStructureListScreen extends ConsumerStatefulWidget {
  const FeeStructureListScreen({super.key});

  @override
  ConsumerState<FeeStructureListScreen> createState() =>
      _FeeStructureListScreenState();
}

class _FeeStructureListScreenState
    extends ConsumerState<FeeStructureListScreen> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(currentSessionProvider);
    final schoolId = session?.schoolId;

    if (schoolId == null) {
      return const Scaffold(
        backgroundColor: _bgDark,
        body: Center(
          child: Text('Access Denied', style: TextStyle(color: _textPrimary)),
        ),
      );
    }

    final structuresAsync = ref.watch(feeStructuresV2Provider(schoolId));

    return Scaffold(
      backgroundColor: _bgDark,
      appBar: AppBar(
        backgroundColor: _bgDark,
        elevation: 0,
        title: const Text('Fee Structures',
            style: TextStyle(color: _textPrimary, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: _textPrimary),
        actions: [
          IconButton(
            tooltip: 'Download Excel template',
            icon: const Icon(Icons.download_rounded, color: _accentBlue),
            onPressed: _busy ? null : _downloadTemplate,
          ),
          IconButton(
            tooltip: 'Bulk import from Excel',
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        color: _accentBlue, strokeWidth: 2),
                  )
                : const Icon(Icons.upload_file_rounded, color: _accentBlue),
            onPressed: _busy ? null : () => _pickAndPreviewExcel(schoolId),
          ),
          TextButton.icon(
            onPressed: () => _openEditor(context, schoolId, null),
            icon: const Icon(Icons.add, color: _accentGreen),
            label: const Text('New Structure',
                style: TextStyle(color: _accentGreen)),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: structuresAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: _accentGreen)),
        error: (e, _) => Center(
            child: Text('Error: $e',
                style: const TextStyle(color: _textSecondary))),
        data: (list) {
          if (list.isEmpty) {
            return _emptyState(context, schoolId);
          }
          return Padding(
            padding: const EdgeInsets.all(16),
            child: GridView.builder(
              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 380,
                mainAxisExtent: 200,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: list.length,
              itemBuilder: (_, i) =>
                  _StructureCard(structure: list[i], schoolId: schoolId),
            ),
          );
        },
      ),
    );
  }

  Widget _emptyState(BuildContext ctx, String schoolId) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.receipt_long_outlined,
              size: 64, color: _textSecondary),
          const SizedBox(height: 16),
          const Text('No fee structures yet',
              style: TextStyle(color: _textPrimary, fontSize: 18)),
          const SizedBox(height: 8),
          const Text(
              'Create one to start collecting term-wise / installment fees.',
              style: TextStyle(color: _textSecondary)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentGreen,
              foregroundColor: Colors.white,
            ),
            onPressed: () => _openEditor(ctx, schoolId, null),
            icon: const Icon(Icons.add),
            label: const Text('Create Structure'),
          ),
        ],
      ),
    );
  }

  void _openEditor(BuildContext ctx, String schoolId, String? structureId) {
    showFeeStructureEditorDialog(
      context: ctx,
      schoolId: schoolId,
      structureId: structureId,
    );
  }

  Future<void> _downloadTemplate() async {
    setState(() => _busy = true);
    try {
      final bytes = FeeStructureExcelService().buildTemplate();
      final blob = html.Blob(
        [bytes],
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute('download', 'fee_structures_template.xlsx')
        ..click();
      html.Url.revokeObjectUrl(url);
      _toast('Template downloaded — fill it and re-upload.');
    } catch (e) {
      _toast('Could not generate template: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickAndPreviewExcel(String schoolId) async {
    setState(() => _busy = true);
    Uint8List? bytes;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      bytes = result.files.first.bytes;
      if (bytes == null) {
        _toast('Could not read file bytes.', error: true);
        return;
      }

      final svc = FeeStructureExcelService();

      // 1. Inspect available data sheets.
      final sheets = svc.listSheets(bytes);
      if (sheets.isEmpty) {
        _toast('No data sheets found in the workbook.', error: true);
        return;
      }

      // 2. Ask the admin which sheet(s) to import.
      List<String>? chosen;
      if (sheets.length == 1) {
        chosen = sheets;
      } else {
        if (!mounted) return;
        chosen = await _pickSheetsDialog(sheets);
        if (chosen == null || chosen.isEmpty) return;
      }

      // 3. Parse only the chosen sheets and merge results.
      final parsed = svc.parse(bytes, sheetNames: chosen);
      if (parsed.structures.isEmpty) {
        _toast('Selected sheet(s) had no valid rows.', error: true);
        return;
      }
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => FeeStructureBulkImportScreen(
          schoolId: schoolId,
          parsed: parsed,
        ),
      ));
    } on FeeStructureExcelParseException catch (e) {
      _showParseErrors(e.message);
    } catch (e) {
      _toast('Failed to parse Excel: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Multi-select dialog letting the admin pick which sheet(s) to import.
  /// Defaults to all data sheets selected.
  Future<List<String>?> _pickSheetsDialog(List<String> sheets) {
    final selected = {...sheets};
    return showDialog<List<String>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSt) {
          return AlertDialog(
            backgroundColor: _cardDark,
            title: const Row(children: [
              Icon(Icons.layers, color: _accentBlue),
              SizedBox(width: 8),
              Text('Choose sheet(s) to import',
                  style: TextStyle(color: _textPrimary)),
            ]),
            content: SizedBox(
              width: 380,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text(
                      'The uploaded file has multiple sheets. Pick the ones you actually want to commit. Other sheets will be ignored.',
                      style: TextStyle(
                          color: _textSecondary, fontSize: 12),
                    ),
                  ),
                  ...sheets.map((s) {
                    final isOn = selected.contains(s);
                    return CheckboxListTile(
                      value: isOn,
                      onChanged: (v) => setSt(() {
                        if (v == true) {
                          selected.add(s);
                        } else {
                          selected.remove(s);
                        }
                      }),
                      activeColor: _accentGreen,
                      checkColor: Colors.white,
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(s,
                          style: const TextStyle(color: _textPrimary)),
                    );
                  }),
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
                onPressed: () => setSt(() {
                  if (selected.length == sheets.length) {
                    selected.clear();
                  } else {
                    selected
                      ..clear()
                      ..addAll(sheets);
                  }
                }),
                child: Text(
                  selected.length == sheets.length
                      ? 'Clear all'
                      : 'Select all',
                  style: const TextStyle(color: _accentBlue),
                ),
              ),
              TextButton(
                onPressed: selected.isEmpty
                    ? null
                    : () => Navigator.of(ctx).pop(
                        // preserve original sheet order
                        sheets.where(selected.contains).toList()),
                child: Text(
                  'Import (${selected.length})',
                  style: TextStyle(
                    color: selected.isEmpty
                        ? _textSecondary
                        : _accentGreen,
                  ),
                ),
              ),
            ],
          );
        });
      },
    );
  }

  void _showParseErrors(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardDark,
        title: const Text('Excel validation failed',
            style: TextStyle(color: _textPrimary)),
        content: SingleChildScrollView(
          child: SelectableText(
            message,
            style: const TextStyle(color: _textSecondary, fontSize: 12),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close',
                style: TextStyle(color: _accentBlue)),
          ),
        ],
      ),
    );
  }

  void _toast(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor:
            error ? const Color(0xFFEF4444) : _accentGreen,
      ),
    );
  }
}

class _StructureCard extends ConsumerWidget {
  const _StructureCard({required this.structure, required this.schoolId});

  final FeeStructureV2 structure;
  final String schoolId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final money = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => showFeeStructureEditorDialog(
        context: context,
        schoolId: schoolId,
        structureId: structure.id,
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _cardDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _accentBlue.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.receipt_long,
                      color: _accentBlue, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    structure.name,
                    style: const TextStyle(
                      color: _textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (!structure.isActive)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _textSecondary.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('Inactive',
                        style: TextStyle(
                            color: _textSecondary, fontSize: 10)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _row('Type', structure.type.name.replaceAll('_', ' ')),
            _row('Academic Year', structure.academicYear),
            _row('Terms', structure.termCount.toString()),
            _row('Total', money.format(structure.totalAmount)),
            const Spacer(),
            Row(
              children: [
                Icon(Icons.school_outlined,
                    size: 14, color: _textSecondary.withOpacity(0.8)),
                const SizedBox(width: 4),
                Text(
                  '${structure.applicableToClassIds.length} classes assigned',
                  style:
                      const TextStyle(color: _textSecondary, fontSize: 11),
                ),
                const Spacer(),
                const Icon(Icons.chevron_right, color: _textSecondary, size: 18),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(label,
              style: const TextStyle(color: _textSecondary, fontSize: 12)),
          const Spacer(),
          Text(value,
              style: const TextStyle(
                  color: _textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
