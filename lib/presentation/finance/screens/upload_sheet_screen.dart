import 'dart:typed_data';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../domain/entities/academic_year.dart';

const Color _bgDark = Color(0xFF0D1117);
const Color _cardDark = Color(0xFF161B22);
const Color _accentGreen = Color(0xFF4CAF50);
const Color _textPrimary = Color(0xFFE6EDF3);
const Color _textSecondary = Color(0xFF8B949E);
const Color _borderColor = Color(0xFF30363D);

class UploadSheetScreen extends ConsumerStatefulWidget {
  const UploadSheetScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<UploadSheetScreen> createState() => _UploadSheetScreenState();
}

class _UploadSheetScreenState extends ConsumerState<UploadSheetScreen> {
  String _selectedType = 'Auto-Detect (All Sheets)';
  bool _isUploading = false;
  String _statusMessage = '';
  int _processedCount = 0;
  int _totalCount = 0;
  List<String> _errors = [];
  List<List<String>> _previewData = [];

  /// Academic year the sheet data will be attached to. Defaults to the
  /// current year, but can be overridden manually (e.g. importing last
  /// year's rolls into a freshly-created school).
  String _selectedAcademicYear = AcademicYear.getCurrentYearCode();

  /// Set to `true` when the parsed sheet already contains an
  /// `academicYear` / `yearCode` column per row. In that case the
  /// per-row value wins over [_selectedAcademicYear].
  bool _sheetProvidesAcademicYear = false;

  String? get _schoolId => ref.read(currentSessionProvider)?.schoolId;

  /// Resolves the academic-year for a single upload row. Priority:
  ///   1. Non-empty `academicYear`/`yearCode`/`year` value on the row.
  ///   2. The user-picked [_selectedAcademicYear] fallback.
  String _resolveAcademicYear(Map<String, dynamic> data) {
    for (final key in const ['academicYear', 'yearCode', 'year']) {
      final v = data[key]?.toString().trim();
      if (v != null && v.isNotEmpty) return v;
    }
    return _selectedAcademicYear;
  }

  /// Scans an excel sheet's header row for an academicYear-like column and
  /// returns its index, or null when not present.
  int? _findYearColumn(List<List<Data?>> rows) {
    if (rows.isEmpty) {
      debugPrint('🔍 _findYearColumn: rows empty');
      return null;
    }
    final header = rows.first;
    final headerStrings = header.map((c) => c?.value?.toString().trim().toLowerCase() ?? '').toList();
    debugPrint('🔍 _findYearColumn header: $headerStrings');
    for (int i = 0; i < header.length; i++) {
      final h = headerStrings[i];
      if (h == 'academicyear' || h == 'yearcode' || h == 'year') {
        debugPrint('✅ _findYearColumn matched at index $i: "$h"');
        return i;
      }
    }
    debugPrint('❌ _findYearColumn: no match');
    return null;
  }

  /// Builds the list of selectable academic years: current year +/- 3.
  List<String> _academicYearOptions() {
    final current = DateTime.now();
    final base = current.month >= 5 ? current.year : current.year - 1;
    return List.generate(7, (i) {
      final start = base - 3 + i;
      return '$start-${(start + 1) % 100}';
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 1024;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isDesktop ? 28 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(isDesktop),
          const SizedBox(height: 24),
          _buildUploadTypeSelector(),
          const SizedBox(height: 20),
          _buildAcademicYearSelector(),
          const SizedBox(height: 20),
          _buildTemplateInfo(),
          const SizedBox(height: 20),
          _buildUploadArea(),
          if (_previewData.isNotEmpty) ...[
            const SizedBox(height: 20),
            _buildPreview(),
          ],
          // Progress is now shown in a modal dialog
          if (_errors.isNotEmpty) ...[
            const SizedBox(height: 20),
            _buildErrorLog(),
          ],
        ],
      ),
    );
  }

  Widget _buildUploadProgressDialog() {
    if (!_isUploading) return const SizedBox.shrink();
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: _cardDark,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 32,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animated rotating icon
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 1200),
              builder: (_, value, __) => Transform.rotate(
                angle: value * 2 * 3.14159,
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: _accentGreen.withOpacity(0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: _accentGreen.withOpacity(0.3), width: 2),
                  ),
                  child: const Icon(
                    Icons.cloud_upload_rounded,
                    color: _accentGreen,
                    size: 32,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _statusMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            // Progress bar
            Container(
              height: 6,
              decoration: BoxDecoration(
                color: _bgDark,
                borderRadius: BorderRadius.circular(3),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: _totalCount > 0 ? _processedCount / _totalCount : 0.0,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_accentGreen, Color(0xFF22C55E)],
                    ),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '$_processedCount / $_totalCount records',
              style: const TextStyle(color: _textSecondary, fontSize: 13),
            ),
            if (_errors.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_errors.length} error${_errors.length == 1 ? '' : 's'}',
                      style: const TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    ..._errors.take(3).map((e) => Text(
                      '• $e',
                      style: const TextStyle(color: Color(0xFFEF4444), fontSize: 11),
                    )),
                    if (_errors.length > 3)
                      Text('...and ${_errors.length - 3} more', style: const TextStyle(color: Color(0xFFEF4444), fontSize: 11)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showUploadProgressDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => WillPopScope(
        onWillPop: () async => false,
        child: _buildUploadProgressDialog(),
      ),
    );
  }

  void _hideUploadProgressDialog() {
    if (mounted) Navigator.of(context).pop();
  }

  Widget _buildHeader(bool isDesktop) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.upload_file_rounded, color: Colors.white, size: 28),
        ),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Upload Data Sheet', style: TextStyle(fontSize: isDesktop ? 24 : 20, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 4),
          Text('Import fee structures, students, and fee details from Excel', style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.9))),
        ])),
      ]),
    );
  }

  Widget _buildUploadTypeSelector() {
    final types = ['Auto-Detect (All Sheets)', 'Fee Structure', 'Student Fee Details'];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _cardDark, borderRadius: BorderRadius.circular(12), border: Border.all(color: _borderColor)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Upload Type', style: TextStyle(color: _textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: types.map((t) => ChoiceChip(
              label: Text(t),
              selected: _selectedType == t,
              selectedColor: _accentGreen,
              backgroundColor: _bgDark,
              labelStyle: TextStyle(color: _selectedType == t ? Colors.white : _textSecondary, fontWeight: FontWeight.w500),
              side: BorderSide(color: _selectedType == t ? _accentGreen : _borderColor),
              onSelected: (_) => setState(() { _selectedType = t; _previewData = []; _errors = []; }),
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAcademicYearSelector() {
    final options = _academicYearOptions();
    final detected = _sheetProvidesAcademicYear;
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
          Row(
            children: [
              const Icon(Icons.event_rounded, color: _accentGreen, size: 18),
              const SizedBox(width: 8),
              const Text('Academic Year',
                  style: TextStyle(
                      color: _textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
              const SizedBox(width: 10),
              if (detected)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _accentGreen.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: _accentGreen.withOpacity(0.4), width: 1),
                  ),
                  child: const Text('Detected in sheet',
                      style: TextStyle(
                          color: _accentGreen,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            detected
                ? 'Your sheet contains an `academicYear` column — each row will use its own value. The fallback below is used only for rows where the column is blank.'
                : 'Your sheet does not specify an academic year. Pick the year these records belong to. Fee structures and students will be tagged with this year.',
            style: const TextStyle(color: _textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options.map((yr) {
              final isSelected = _selectedAcademicYear == yr;
              final isCurrent = yr == AcademicYear.getCurrentYearCode();
              return ChoiceChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(yr),
                    if (isCurrent) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text('CURRENT',
                            style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.w700,
                                color: isSelected
                                    ? Colors.white
                                    : _textSecondary)),
                      ),
                    ],
                  ],
                ),
                selected: isSelected,
                selectedColor: _accentGreen,
                backgroundColor: _bgDark,
                labelStyle: TextStyle(
                    color: isSelected ? Colors.white : _textSecondary,
                    fontWeight: FontWeight.w600),
                side: BorderSide(
                    color: isSelected ? _accentGreen : _borderColor),
                onSelected: _isUploading
                    ? null
                    : (_) => setState(() => _selectedAcademicYear = yr),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateInfo() {
    final Map<String, List<String>> templates = {
      'Fee Structure': ['classInRoman', 'classTutionFees', 'classExamFees'],
      'Student Details': ['stuId', 'stuName', 'stuClass', 'stuSection', 'phoneNumber', 'isStuAvailVan'],
      'Student Fee Details': [
        'stuId', 'stuName', 'stuClass', 'stuSection',
        'arrearTuitionFees', 'arrearExamFees', 'arrearVanFees',
        'stuConcessionFees', 'isStuAvailVan', 'stuTotalVanFees',
        'stuPaidTutionFees', 'stuPaidExamFees', 'studPaidVanFees', 'stuPaidTotalFees',
        'phoneNumber', 'stuBillDetails',
      ],
    };

    final columns = templates[_selectedType] ?? [];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _cardDark, borderRadius: BorderRadius.circular(12), border: Border.all(color: _borderColor)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.info_outline_rounded, color: Color(0xFF3B82F6), size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text('Template: "$_selectedType"', style: const TextStyle(color: _textPrimary, fontWeight: FontWeight.bold))),
            ElevatedButton.icon(
              icon: const Icon(Icons.download_rounded, size: 16),
              label: const Text('Download Template'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                textStyle: const TextStyle(fontSize: 12),
              ),
              onPressed: _downloadTemplate,
            ),
          ]),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: columns.map((c) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: _bgDark, borderRadius: BorderRadius.circular(6), border: Border.all(color: _borderColor)),
              child: Text(c, style: const TextStyle(color: _accentGreen, fontSize: 12, fontFamily: 'monospace')),
            )).toList(),
          ),
          const SizedBox(height: 12),
          const Text(
            'Download the template, fill in your data, then upload the same file. '
            'The master sheet contains FEE_STRUCTURE and STUDENT_FEE_DETAILS tabs.',
            style: TextStyle(color: _textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }

  /// Generates and downloads the master Excel template with two sheets:
  /// FEE_STRUCTURE and STUDENT_FEE_DETAILS — matching the old app's format exactly.
  void _downloadTemplate() {
    try {
      final excel = Excel.createExcel();

      // ── Sheet 1: FEE_STRUCTURE ──────────────────────────────────────────
      final feeSheet = excel['FEE_STRUCTURE'];
      excel.setDefaultSheet('FEE_STRUCTURE');

      // Headers
      final feeHeaders = ['classInRoman', 'classTutionFees', 'classExamFees'];
      for (int i = 0; i < feeHeaders.length; i++) {
        feeSheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
          ..value = TextCellValue(feeHeaders[i])
          ..cellStyle = CellStyle(bold: true, backgroundColorHex: ExcelColor.fromHexString('#1F4E79'), fontColorHex: ExcelColor.fromHexString('#FFFFFF'));
      }

      // Sample rows
      final feeSampleRows = [
        ['KG', '5000', '500'],
        ['I', '6000', '600'],
        ['II', '6000', '600'],
        ['III', '7000', '700'],
        ['IV', '7000', '700'],
        ['V', '8000', '800'],
        ['VI', '9000', '900'],
        ['VII', '9000', '900'],
        ['VIII', '10000', '1000'],
        ['IX', '11000', '1100'],
        ['X', '12000', '1200'],
        ['XI', '13000', '1300'],
        ['XII', '13000', '1300'],
      ];
      for (int r = 0; r < feeSampleRows.length; r++) {
        final row = feeSampleRows[r];
        feeSheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r + 1)).value = TextCellValue(row[0]);
        feeSheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: r + 1)).value = DoubleCellValue(double.tryParse(row[1]) ?? 0);
        feeSheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: r + 1)).value = DoubleCellValue(double.tryParse(row[2]) ?? 0);
      }

      // ── Sheet 2: STUDENT_FEE_DETAILS ───────────────────────────────────
      final stuSheet = excel['STUDENT_FEE_DETAILS'];

      // Headers
      final stuHeaders = [
        'stuId',              // col 0
        'stuName',            // col 1
        'stuClass',           // col 2
        'stuSection',         // col 3
        'arrearTuitionFees',  // col 4
        'arrearExamFees',     // col 5
        'arrearVanFees',      // col 6
        'stuConcessionFees',  // col 7
        'isStuAvailVan',      // col 8  (y/n)
        'stuTotalVanFees',    // col 9
        'stuPaidTutionFees',  // col 10
        'stuPaidExamFees',    // col 11
        'studPaidVanFees',    // col 12
        'stuPaidTotalFees',   // col 13
        'phoneNumber',        // col 14
        'stuBillDetails',     // col 15 (leave blank / NA)
      ];
      for (int i = 0; i < stuHeaders.length; i++) {
        stuSheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
          ..value = TextCellValue(stuHeaders[i])
          ..cellStyle = CellStyle(bold: true, backgroundColorHex: ExcelColor.fromHexString('#1F4E79'), fontColorHex: ExcelColor.fromHexString('#FFFFFF'));
      }

      // Sample rows (16 cols: 0-3 text, 4-13 numbers, 14 phone, 15 text)
      final stuSampleRows = [
        ['101', 'SAMPLE STUDENT 1', 'I', 'A', '0', '0', '0', '0', 'n', '0', '0', '0', '0', '0', '9999999999', 'NA'],
        ['102', 'SAMPLE STUDENT 2', 'I', 'A', '0', '0', '0', '0', 'y', '1200', '0', '0', '0', '0', '9999999998', 'NA'],
        ['103', 'SAMPLE STUDENT 3', 'II', 'B', '500', '100', '0', '200', 'n', '0', '3000', '300', '0', '3300', '9999999997', 'NA'],
      ];
      for (int r = 0; r < stuSampleRows.length; r++) {
        final row = stuSampleRows[r];
        stuSheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r + 1)).value = IntCellValue(int.tryParse(row[0]) ?? 0);
        stuSheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: r + 1)).value = TextCellValue(row[1]);
        stuSheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: r + 1)).value = TextCellValue(row[2]);
        stuSheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: r + 1)).value = TextCellValue(row[3]);
        for (int c = 4; c <= 13; c++) {
          final cv = row[c];
          if (cv == 'n' || cv == 'y') {
            stuSheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r + 1)).value = TextCellValue(cv);
          } else {
            stuSheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r + 1)).value = DoubleCellValue(double.tryParse(cv) ?? 0);
          }
        }
        stuSheet.cell(CellIndex.indexByColumnRow(columnIndex: 14, rowIndex: r + 1)).value = TextCellValue(row[14]);
        stuSheet.cell(CellIndex.indexByColumnRow(columnIndex: 15, rowIndex: r + 1)).value = TextCellValue(row[15]);
      }

      // Remove default "Sheet1" if present
      if (excel.sheets.containsKey('Sheet1')) {
        excel.delete('Sheet1');
      }

      // Encode and trigger download
      final bytes = excel.encode();
      if (bytes == null) throw Exception('Failed to encode Excel');

      final blob = html.Blob([Uint8List.fromList(bytes)],
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      final url = html.Url.createObjectUrlFromBlob(blob);
      (html.AnchorElement(href: url)
        ..setAttribute('download', 'SAMPLE_FEE_SHEET.xlsx')
        ..click());
      html.Url.revokeObjectUrl(url);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Template downloaded: SAMPLE_FEE_SHEET.xlsx'),
            backgroundColor: Color(0xFF3B82F6),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildUploadArea() {
    return InkWell(
      onTap: _isUploading ? null : _pickFile,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 48),
        decoration: BoxDecoration(
          color: _cardDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _accentGreen.withOpacity(0.3), width: 2, strokeAlign: BorderSide.strokeAlignInside),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_upload_rounded, size: 48, color: _accentGreen.withOpacity(0.7)),
            const SizedBox(height: 12),
            const Text('Click to upload Excel file (.xlsx)', style: TextStyle(color: _textPrimary, fontSize: 16, fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            const Text('Supports .xlsx format only', style: TextStyle(color: _textSecondary, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview() {
    return Container(
      decoration: BoxDecoration(color: _cardDark, borderRadius: BorderRadius.circular(12), border: Border.all(color: _borderColor)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              const Text('Preview', style: TextStyle(color: _textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: _accentGreen.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                child: Text('${_previewData.length - 1} rows', style: const TextStyle(color: _accentGreen, fontSize: 12)),
              ),
              const Spacer(),
              ElevatedButton.icon(
                icon: const Icon(Icons.upload_rounded, size: 16),
                label: const Text('Upload to Firestore'),
                style: ElevatedButton.styleFrom(backgroundColor: _accentGreen, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                onPressed: _isUploading ? null : _uploadData,
              ),
            ]),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(_bgDark),
              columns: _previewData.isNotEmpty
                  ? _previewData[0].map((h) => DataColumn(label: Text(h, style: const TextStyle(color: _accentGreen, fontWeight: FontWeight.bold, fontSize: 11)))).toList()
                  : [],
              rows: _previewData.length > 1
                  ? _previewData.sublist(1).map((r) => DataRow(
                      cells: r.map((c) => DataCell(Text(c, style: const TextStyle(color: _textPrimary, fontSize: 11)))).toList(),
                    )).toList()
                  : [],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorLog() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFFEF4444).withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.3))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Errors (${_errors.length})', style: const TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ..._errors.take(10).map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text('• $e', style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12)),
          )),
          if (_errors.length > 10) Text('...and ${_errors.length - 10} more errors', style: const TextStyle(color: _textSecondary, fontSize: 12)),
        ],
      ),
    );
  }

  // ============ FILE PICKER ============
  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;
      final bytes = result.files.first.bytes;
      if (bytes == null) return;

      _parseExcel(bytes);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error picking file: $e'), backgroundColor: Colors.red));
      }
    }
  }

  void _parseExcel(Uint8List bytes) {
    try {
      final excel = Excel.decodeBytes(bytes);

      // If the file has FEE_STRUCTURE or STUDENT_FEE_DETAILS sheets (master file),
      // auto-select the sheet matching the current upload type.
      String? targetSheet;
      final allSheets = excel.tables.keys.toList();
      debugPrint('📋 Auto-detect: found sheets: $allSheets');
      debugPrint('📋 Auto-detect: current type = $_selectedType');
      
      if (allSheets.contains('FEE_STRUCTURE') || allSheets.contains('STUDENT_FEE_DETAILS')) {
        if (_selectedType == 'Fee Structure' && allSheets.contains('FEE_STRUCTURE')) {
          targetSheet = 'FEE_STRUCTURE';
          debugPrint('✅ Auto-detected FEE_STRUCTURE sheet');
        } else if (_selectedType == 'Student Fee Details' && allSheets.contains('STUDENT_FEE_DETAILS')) {
          targetSheet = 'STUDENT_FEE_DETAILS';
          debugPrint('✅ Auto-detected STUDENT_FEE_DETAILS sheet');
        } else {
          // Show available sheets for user to know
          final available = allSheets.join(', ');
          debugPrint('❌ No matching sheet for "$_selectedType". Available: $available');
          // Instead of error, fall back to first sheet and warn the user
          targetSheet = allSheets.first;
          debugPrint('⚠️ Falling back to first sheet: $targetSheet');
          // Optionally show a warning in the UI
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Sheet "$_selectedType" not found. Using sheet "$targetSheet" instead.'),
                backgroundColor: const Color(0xFFF59E0B),
                duration: const Duration(seconds: 4),
              ),
            );
          }
        }
      } else {
        targetSheet = allSheets.first;
        debugPrint('⚠️ No master sheet names found; falling back to first sheet: $targetSheet');
      }

      final sheet = excel.tables[targetSheet];
      if (sheet == null || sheet.rows.isEmpty) {
        setState(() => _errors = ['Empty or invalid sheet: $targetSheet']);
        return;
      }

      final preview = <List<String>>[];
      for (final row in sheet.rows) {
        preview.add(row.map((cell) => cell?.value?.toString() ?? '').toList());
      }

      // Detect whether the sheet carries its own academic-year column. We
      // only trust it when at least one data row has a non-empty value so
      // an empty "academicYear" header alone doesn't trigger the badge.
      bool hasYearColumn = false;
      if (preview.isNotEmpty) {
        final headers = preview.first.map((h) => h.trim().toLowerCase()).toList();
        debugPrint('📋 Headers detected: $headers');
        int? yearIdx;
        for (int i = 0; i < headers.length; i++) {
          final h = headers[i];
          if (h == 'academicyear' || h == 'yearcode' || h == 'year') {
            yearIdx = i;
            debugPrint('📋 Found year column at index $i: "$h"');
            break;
          }
        }
        if (yearIdx != null) {
          for (int r = 1; r < preview.length; r++) {
            final val = preview[r][yearIdx];
            if (yearIdx < preview[r].length && val.trim().isNotEmpty) {
              hasYearColumn = true;
              debugPrint('✅ Row $r has non-empty year value: "$val"');
              break;
            }
          }
          if (!hasYearColumn) {
            debugPrint('⚠️ Year column header present but all rows are empty');
          }
        } else {
          debugPrint('⚠️ No academicYear/yearCode/year column found');
        }
      }

      setState(() {
        _previewData = preview;
        _sheetProvidesAcademicYear = hasYearColumn;
        _errors = [];
        _statusMessage = 'Loaded ${preview.length - 1} rows from sheet "$targetSheet"';
      });

      // Show a brief toast indicating which sheet was used
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Using sheet: "$targetSheet"'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() => _errors = ['Failed to parse Excel: $e']);
    }
  }

  // ============ UPLOAD DATA ============
  Future<void> _uploadData() async {
    if (_schoolId == null) return;

    // If Auto-Detect, process all sheets from the Excel file
    if (_selectedType == 'Auto-Detect (All Sheets)') {
      await _uploadAllSheets();
      return;
    }

    // Otherwise, process single sheet preview
    if (_previewData.length < 2) return;

    setState(() {
      _isUploading = true;
      _processedCount = 0;
      _totalCount = _previewData.length - 1;
      _errors = [];
      _statusMessage = 'Uploading $_selectedType...';
    });
    _showUploadProgressDialog();

    try {
      final headers = _previewData[0];
      final dataRows = _previewData.sublist(1);

      for (int i = 0; i < dataRows.length; i++) {
        try {
          final row = dataRows[i];
          final map = <String, dynamic>{};
          for (int j = 0; j < headers.length && j < row.length; j++) {
            map[headers[j]] = row[j];
          }

          switch (_selectedType) {
            case 'Fee Structure':
              await _uploadFeeStructure(map);
              break;
            case 'Student Fee Details':
              await _uploadStudentFeeDetails(map);
              break;
          }

          setState(() {
            _processedCount = i + 1;
            _statusMessage = 'Uploading $_selectedType... (${i + 1}/$_totalCount)';
          });
        } catch (e) {
          _errors.add('Row ${i + 2}: $e');
        }
      }

      setState(() {
        _isUploading = false;
        _statusMessage = 'Upload complete!';
      });
      _hideUploadProgressDialog();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Uploaded $_processedCount/$_totalCount records. ${_errors.length} errors.'),
            backgroundColor: _errors.isEmpty ? _accentGreen : const Color(0xFFF59E0B),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isUploading = false;
        _errors.add('Upload failed: $e');
      });
      _hideUploadProgressDialog();
    }
  }

  // Upload all sheets from Excel file (like old app)
  Future<void> _uploadAllSheets() async {
    if (_schoolId == null) return;

    setState(() {
      _isUploading = true;
      _processedCount = 0;
      _totalCount = 0;
      _errors = [];
      _statusMessage = 'Processing all sheets...';
    });
    _showUploadProgressDialog();

    try {
      // Re-pick the file to get all sheets
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        setState(() {
          _isUploading = false;
          _statusMessage = 'No file selected';
        });
        _hideUploadProgressDialog();
        return;
      }

      final bytes = result.files.first.bytes;
      if (bytes == null) {
        setState(() {
          _isUploading = false;
          _statusMessage = 'Failed to read file';
        });
        _hideUploadProgressDialog();
        return;
      }

      final excel = Excel.decodeBytes(bytes);
      final Map<String, dynamic> classWiseFeeDetails = {};
      final allSheets = excel.tables.keys.toList();
      debugPrint('🚀 Auto-Detect upload: sheets in file = $allSheets');

      // Calculate total rows for progress bar
      int totalRows = 0;
      if (excel.tables.containsKey('FEE_STRUCTURE')) {
        final sheet = excel.tables['FEE_STRUCTURE']!;
        totalRows += sheet.rows.where((row) => row.first?.rowIndex != 0).length; // Exclude header
      }
      if (excel.tables.containsKey('STUDENT_FEE_DETAILS')) {
        final sheet = excel.tables['STUDENT_FEE_DETAILS']!;
        totalRows += sheet.rows.where((row) => row.first?.rowIndex != 0).length; // Exclude header
      }
      
      setState(() {
        _totalCount = totalRows;
        _processedCount = 0;
      });
      debugPrint('📊 Total rows to process: $_totalCount');

      // Process FEE_STRUCTURE sheet first (to get class fees for student calculations)
      if (excel.tables.containsKey('FEE_STRUCTURE')) {
        setState(() => _statusMessage = 'Processing Fee Structure...');
        final sheet = excel.tables['FEE_STRUCTURE']!;

        // Detect optional academicYear column.
        final feeYearIdx = _findYearColumn(sheet.rows);

        for (var row in sheet.rows) {
          if (row.first?.rowIndex == 0) continue; // Skip header

          try {
            final className = row[0]?.value?.toString() ?? '';
            if (className.isEmpty) continue;

            final tuitionFee = double.tryParse(row[1]?.value?.toString() ?? '0') ?? 0;
            final examFee = double.tryParse(row[2]?.value?.toString() ?? '0') ?? 0;

            // Store for student calculations
            classWiseFeeDetails['$className-tutionFees'] = tuitionFee;
            classWiseFeeDetails['$className-examFees'] = examFee;

            final rowYear = feeYearIdx != null && feeYearIdx < row.length
                ? (row[feeYearIdx]?.value?.toString() ?? '')
                : '';

            // Upload to Firestore
            await _uploadFeeStructure({
              'classInRoman': className,
              'classTutionFees': tuitionFee.toString(),
              'classExamFees': examFee.toString(),
              if (rowYear.isNotEmpty) 'academicYear': rowYear,
            });

            // Update cumulative progress
            setState(() {
              _processedCount++;
              _statusMessage = 'Processing Fee Structure... ($_processedCount/$_totalCount rows)';
            });
          } catch (e) {
            _errors.add('FEE_STRUCTURE row ${row.first?.rowIndex}: $e');
            // Still increment progress for error rows
            setState(() {
              _processedCount++;
            });
          }
        }
      }

      // Process STUDENT_FEE_DETAILS sheet
      if (excel.tables.containsKey('STUDENT_FEE_DETAILS')) {
        setState(() => _statusMessage = 'Processing Student Fee Details...');
        final sheet = excel.tables['STUDENT_FEE_DETAILS']!;

        final stuYearIdx = _findYearColumn(sheet.rows);

        for (var row in sheet.rows) {
          if (row.first?.rowIndex == 0) continue; // Skip header

          try {
            final stuId = row[0]?.value?.toString() ?? '';
            if (stuId.isEmpty) {
              // Still increment progress for empty rows
              setState(() {
                _processedCount++;
              });
              continue;
            }

            final stuName = row[1]?.value?.toString() ?? '';
            final stuClass = row[2]?.value?.toString() ?? '';
            final stuSection = row[3]?.value?.toString() ?? '';
            final arrearTuitionFees = double.tryParse(row[4]?.value?.toString() ?? '0') ?? 0;
            final arrearExamFees = double.tryParse(row[5]?.value?.toString() ?? '0') ?? 0;
            final arrearVanFees = double.tryParse(row[6]?.value?.toString() ?? '0') ?? 0;
            final stuConcessionFees = double.tryParse(row[7]?.value?.toString() ?? '0') ?? 0;
            final isStuAvailVan = row[8]?.value?.toString().toLowerCase() ?? 'n';
            final stuTotalVanFees = double.tryParse(row[9]?.value?.toString() ?? '0') ?? 0;
            final stuPaidTutionFees = double.tryParse(row[10]?.value?.toString() ?? '0') ?? 0;
            final stuPaidExamFees = double.tryParse(row[11]?.value?.toString() ?? '0') ?? 0;
            final studPaidVanFees = double.tryParse(row[12]?.value?.toString() ?? '0') ?? 0;
            final stuPaidTotalFees = double.tryParse(row[13]?.value?.toString() ?? '0') ?? 0;
            final phoneNumber = row[14]?.value?.toString() ?? '';
            final stuBillDetails = row[15]?.value?.toString() ?? 'NA';

            // Get class fees from previously loaded data
            final classTuitionFees = (classWiseFeeDetails['$stuClass-tutionFees'] as double?) ?? 0;
            final classExamFees = (classWiseFeeDetails['$stuClass-examFees'] as double?) ?? 0;

            final rowYear = stuYearIdx != null && stuYearIdx < row.length
                ? (row[stuYearIdx]?.value?.toString() ?? '')
                : '';

            // Upload student fee details with calculated values
            await _uploadStudentFeeDetailsWithClassFees({
              'stuId': stuId,
              'stuName': stuName,
              'stuClass': stuClass,
              'stuSection': stuSection,
              'arrearTuitionFees': arrearTuitionFees.toString(),
              'arrearExamFees': arrearExamFees.toString(),
              'arrearVanFees': arrearVanFees.toString(),
              'stuConcessionFees': stuConcessionFees.toString(),
              'isStuAvailVan': isStuAvailVan,
              'stuTotalVanFees': stuTotalVanFees.toString(),
              'stuPaidTutionFees': stuPaidTutionFees.toString(),
              'stuPaidExamFees': stuPaidExamFees.toString(),
              'studPaidVanFees': studPaidVanFees.toString(),
              'stuPaidTotalFees': stuPaidTotalFees.toString(),
              'phoneNumber': phoneNumber,
              'stuBillDetails': stuBillDetails,
              if (rowYear.isNotEmpty) 'academicYear': rowYear,
            }, classTuitionFees, classExamFees);

            // Update cumulative progress
            setState(() {
              _processedCount++;
              _statusMessage = 'Processing Student Fee Details... ($_processedCount/$_totalCount rows)';
            });
          } catch (e) {
            _errors.add('STUDENT_FEE_DETAILS row ${row.first?.rowIndex}: $e');
            // Still increment progress for error rows
            setState(() {
              _processedCount++;
            });
          }
        }
      }

      setState(() {
        _isUploading = false;
        _statusMessage = 'Upload complete!';
      });
      _hideUploadProgressDialog();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Uploaded all sheets successfully. ${_errors.length} errors.'),
            backgroundColor: _errors.isEmpty ? _accentGreen : const Color(0xFFF59E0B),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isUploading = false;
        _errors.add('Upload failed: $e');
      });
      _hideUploadProgressDialog();
    }
  }

  // Helper method to upload student fee details with pre-calculated class fees
  Future<void> _uploadStudentFeeDetailsWithClassFees(Map<String, dynamic> data, double classTuitionFees, double classExamFees) async {
    final stuId = (data['stuId'] ?? '').toString();
    final stuName = (data['stuName'] ?? '').toString();
    if (stuId.isEmpty || stuName.isEmpty) throw Exception('Missing stuId or stuName');

    double parseNum(String key) => double.tryParse((data[key] ?? '0').toString()) ?? 0.0;

    final arrearTuitionFees = parseNum('arrearTuitionFees');
    final arrearExamFees = parseNum('arrearExamFees');
    final arrearVanFees = parseNum('arrearVanFees');
    final stuConcessionFees = parseNum('stuConcessionFees');
    final isStuAvailVan = (data['isStuAvailVan'] ?? 'n').toString().toLowerCase();
    final stuTotalVanFees = parseNum('stuTotalVanFees');
    final stuPaidTutionFees = parseNum('stuPaidTutionFees');
    final stuPaidExamFees = parseNum('stuPaidExamFees');
    final studPaidVanFees = parseNum('studPaidVanFees');
    final stuPaidTotalFees = parseNum('stuPaidTotalFees');

    // Use provided class fees instead of looking them up
    final stuTotalTutionFees = classTuitionFees;
    final stuTotalExamFees = classExamFees;
    final stuTotalFees = stuTotalTutionFees + stuTotalExamFees + stuTotalVanFees;
    final totalArrears = arrearTuitionFees + arrearExamFees + arrearVanFees;

    // Concession adjusts tuition only
    final stuBalTutionFees = stuTotalTutionFees + arrearTuitionFees - stuConcessionFees - stuPaidTutionFees;
    final stuBalExamFees = stuTotalExamFees + arrearExamFees - stuPaidExamFees;
    final stuBalVanFees = stuTotalVanFees + arrearVanFees - studPaidVanFees;
    final stuBalTotalFees = stuBalTutionFees + stuBalExamFees + stuBalVanFees;

    final stuClass = (data['stuClass'] ?? '').toString();
    final stuSection = (data['stuSection'] ?? '').toString();
    final phoneNumber = (data['phoneNumber'] ?? '').toString();
    final academicYear = _resolveAcademicYear(data);

    final feeData = <String, dynamic>{
      'stuId': int.tryParse(stuId) ?? 0,
      'stuName': stuName,
      'studentName': stuName,
      'stuClass': stuClass,
      'className': stuClass,
      'stuSection': stuSection,
      'section': stuSection,
      'phoneNumber': phoneNumber,
      'isStuAvailVan': isStuAvailVan,
      'stuConcessionFees': stuConcessionFees,
      'stuTotalTutionFees': stuTotalTutionFees,
      'stuTotalExamFees': stuTotalExamFees,
      'stuTotalVanFees': stuTotalVanFees,
      'stuTotalAdmissionFees': 0.0,
      'stuTotalFees': stuTotalFees,
      'stuPaidTutionFees': stuPaidTutionFees,
      'stuPaidExamFees': stuPaidExamFees,
      'studPaidVanFees': studPaidVanFees,
      'stuPaidAdmissionFees': 0.0,
      'stuPaidTotalFees': stuPaidTotalFees,
      'stuBalTutionFees': stuBalTutionFees,
      'stuBalExamFees': stuBalExamFees,
      'stuBalVanFees': stuBalVanFees,
      'stuBalAdmissionFees': 0.0,
      'stuBalTotalFees': stuBalTotalFees,
      'arrearTuitionFees': arrearTuitionFees,
      'arrearExamFees': arrearExamFees,
      'arrearAdmissionFees': 0.0,
      'arrearVanFees': arrearVanFees,
      'stuPaidArrearTutionFees': 0.0,
      'stuPaidArrearExamFees': 0.0,
      'stuPaidArrearAdmissionFees': 0.0,
      'stuPaidArrearVanFees': 0.0,
      'balanceArrearTuitionFees': arrearTuitionFees,
      'balanceArrearExamFees': arrearExamFees,
      'balanceArrearAdmissionFees': 0.0,
      'balanceArrearVanFees': arrearVanFees,
      'stuBillDetails': (data['stuBillDetails'] ?? 'NA').toString(),
      'academicYear': academicYear,
      'fiscalYear': FiscalYear.getCurrentYearCode(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    // Create/update student record in students collection (proper field names)
    final stuIdInt = int.tryParse(stuId) ?? 0;
    final studentData = <String, dynamic>{
      'schoolId': _schoolId,
      'studentId': stuIdInt,
      'name': stuName,
      'className': stuClass,
      'section': stuSection,
      'phoneNumber': phoneNumber,
      'isVanAvailed': isStuAvailVan == 'y' || isStuAvailVan == 'yes',
      'status': 'ACTIVE',
      'academicYearCode': academicYear,
      'arrears': totalArrears,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    final existingStudent = await FirebaseFirestore.instance
        .collection('schools').doc(_schoolId).collection('students')
        .where('studentId', isEqualTo: stuIdInt)
        .limit(1)
        .get();

    if (existingStudent.docs.isNotEmpty) {
      await existingStudent.docs.first.reference.update(studentData);
    } else {
      studentData['createdAt'] = FieldValue.serverTimestamp();
      await FirebaseFirestore.instance.collection('schools').doc(_schoolId).collection('students').add(studentData);
    }

    // Create/update student fee details
    final existing = await FirebaseFirestore.instance
        .collection('schools').doc(_schoolId).collection('student_fee_details')
        .where('stuId', isEqualTo: stuIdInt)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      await existing.docs.first.reference.update(feeData);
    } else {
      feeData['createdAt'] = FieldValue.serverTimestamp();
      await FirebaseFirestore.instance.collection('schools').doc(_schoolId).collection('student_fee_details').add(feeData);
    }
  }

  Future<void> _uploadFeeStructure(Map<String, dynamic> data) async {
    final className = (data['classInRoman'] ?? '').toString();
    if (className.isEmpty) throw Exception('Missing classInRoman');

    final tuitionFee = double.tryParse((data['classTutionFees'] ?? '0').toString()) ?? 0;
    final examFee = double.tryParse((data['classExamFees'] ?? '0').toString()) ?? 0;

    // Check if fee structure already exists for this class
    final existing = await FirebaseFirestore.instance
        .collection('schools').doc(_schoolId).collection('fee_structures')
        .where('className', isEqualTo: className)
        .where('isActive', isEqualTo: true)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      await existing.docs.first.reference.update({
        'tuitionFee': tuitionFee,
        'examFee': examFee,
        'totalFees': tuitionFee + examFee,
        'academicYear': _resolveAcademicYear(data),
        'fiscalYear': FiscalYear.getCurrentYearCode(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      await FirebaseFirestore.instance.collection('schools').doc(_schoolId).collection('fee_structures').add({
        'schoolId': _schoolId,
        'className': className,
        'tuitionFee': tuitionFee,
        'examFee': examFee,
        'totalFees': tuitionFee + examFee,
        'academicYear': _resolveAcademicYear(data),
        'fiscalYear': FiscalYear.getCurrentYearCode(),
        'isActive': true,  // Add this field to make the fee structure active
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> _uploadStudentFeeDetails(Map<String, dynamic> data) async {
    final stuId = (data['stuId'] ?? '').toString();
    final stuName = (data['stuName'] ?? '').toString();
    if (stuId.isEmpty || stuName.isEmpty) throw Exception('Missing stuId or stuName');

    final stuClass = (data['stuClass'] ?? '').toString();

    double parseNum(String key) => double.tryParse((data[key] ?? '0').toString()) ?? 0.0;

    final arrearTuitionFees = parseNum('arrearTuitionFees');
    final arrearExamFees = parseNum('arrearExamFees');
    final arrearVanFees = parseNum('arrearVanFees');
    final stuConcessionFees = parseNum('stuConcessionFees');
    final isStuAvailVan = (data['isStuAvailVan'] ?? 'n').toString().toLowerCase();
    final stuTotalVanFees = parseNum('stuTotalVanFees');
    final stuPaidTutionFees = parseNum('stuPaidTutionFees');
    final stuPaidExamFees = parseNum('stuPaidExamFees');
    final studPaidVanFees = parseNum('studPaidVanFees');
    final stuPaidTotalFees = parseNum('stuPaidTotalFees');

    // Look up fee structure for this class to compute totals/balances
    double classTuitionFees = 0;
    double classExamFees = 0;
    if (_schoolId != null && stuClass.isNotEmpty) {
      final feeSnap = await FirebaseFirestore.instance
          .collection('schools').doc(_schoolId).collection('fee_structures')
          .where('className', isEqualTo: stuClass)
          .limit(1).get();
      if (feeSnap.docs.isNotEmpty) {
        final fd = feeSnap.docs.first.data();
        classTuitionFees = (fd['tuitionFee'] as num?)?.toDouble() ?? 0;
        classExamFees = (fd['examFee'] as num?)?.toDouble() ?? 0;
      }
    }

    final stuTotalTutionFees = classTuitionFees;
    final stuTotalExamFees = classExamFees;
    final stuTotalFees = stuTotalTutionFees + stuTotalExamFees + stuTotalVanFees;
    final totalArrears = arrearTuitionFees + arrearExamFees + arrearVanFees;

    // Concession adjusts tuition only
    final stuBalTutionFees = stuTotalTutionFees + arrearTuitionFees - stuConcessionFees - stuPaidTutionFees;
    final stuBalExamFees = stuTotalExamFees + arrearExamFees - stuPaidExamFees;
    final stuBalVanFees = stuTotalVanFees + arrearVanFees - studPaidVanFees;
    final stuBalTotalFees = stuBalTutionFees + stuBalExamFees + stuBalVanFees;

    final stuSection = (data['stuSection'] ?? '').toString();
    final phoneNumber = (data['phoneNumber'] ?? '').toString();
    final academicYear = _resolveAcademicYear(data);

    final feeData = <String, dynamic>{
      'stuId': int.tryParse(stuId) ?? 0,
      'stuName': stuName,
      'studentName': stuName,
      'stuClass': stuClass,
      'className': stuClass,
      'stuSection': stuSection,
      'section': stuSection,
      'phoneNumber': phoneNumber,
      'isStuAvailVan': isStuAvailVan,
      'stuConcessionFees': stuConcessionFees,
      'stuTotalTutionFees': stuTotalTutionFees,
      'stuTotalExamFees': stuTotalExamFees,
      'stuTotalVanFees': stuTotalVanFees,
      'stuTotalAdmissionFees': 0.0,
      'stuTotalFees': stuTotalFees,
      'stuPaidTutionFees': stuPaidTutionFees,
      'stuPaidExamFees': stuPaidExamFees,
      'studPaidVanFees': studPaidVanFees,
      'stuPaidAdmissionFees': 0.0,
      'stuPaidTotalFees': stuPaidTotalFees,
      'stuBalTutionFees': stuBalTutionFees,
      'stuBalExamFees': stuBalExamFees,
      'stuBalVanFees': stuBalVanFees,
      'stuBalAdmissionFees': 0.0,
      'stuBalTotalFees': stuBalTotalFees,
      'arrearTuitionFees': arrearTuitionFees,
      'arrearExamFees': arrearExamFees,
      'arrearAdmissionFees': 0.0,
      'arrearVanFees': arrearVanFees,
      'stuPaidArrearTutionFees': 0.0,
      'stuPaidArrearExamFees': 0.0,
      'stuPaidArrearAdmissionFees': 0.0,
      'stuPaidArrearVanFees': 0.0,
      'balanceArrearTuitionFees': arrearTuitionFees,
      'balanceArrearExamFees': arrearExamFees,
      'balanceArrearAdmissionFees': 0.0,
      'balanceArrearVanFees': arrearVanFees,
      'stuBillDetails': (data['stuBillDetails'] ?? 'NA').toString(),
      'academicYear': academicYear,
      'fiscalYear': FiscalYear.getCurrentYearCode(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    // Create/update student record in students collection (proper field names)
    final stuIdInt = int.tryParse(stuId) ?? 0;
    final studentData = <String, dynamic>{
      'schoolId': _schoolId,
      'studentId': stuIdInt,
      'name': stuName,
      'className': stuClass,
      'section': stuSection,
      'phoneNumber': phoneNumber,
      'isVanAvailed': isStuAvailVan == 'y' || isStuAvailVan == 'yes',
      'status': 'ACTIVE',
      'academicYearCode': academicYear,
      'arrears': totalArrears,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    final existingStudent = await FirebaseFirestore.instance
        .collection('schools').doc(_schoolId).collection('students')
        .where('studentId', isEqualTo: stuIdInt)
        .limit(1)
        .get();

    if (existingStudent.docs.isNotEmpty) {
      await existingStudent.docs.first.reference.update(studentData);
    } else {
      studentData['createdAt'] = FieldValue.serverTimestamp();
      await FirebaseFirestore.instance.collection('schools').doc(_schoolId).collection('students').add(studentData);
    }

    // Create/update student fee details
    final existing = await FirebaseFirestore.instance
        .collection('schools').doc(_schoolId).collection('student_fee_details')
        .where('stuId', isEqualTo: stuIdInt)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      await existing.docs.first.reference.update(feeData);
    } else {
      feeData['createdAt'] = FieldValue.serverTimestamp();
      await FirebaseFirestore.instance.collection('schools').doc(_schoolId).collection('student_fee_details').add(feeData);
    }
  }
}
