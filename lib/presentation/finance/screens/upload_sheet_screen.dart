import 'dart:typed_data';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/auth_provider.dart';

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

  String? get _schoolId => ref.read(currentSessionProvider)?.schoolId;

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
          _buildTemplateInfo(),
          const SizedBox(height: 20),
          _buildUploadArea(),
          if (_previewData.isNotEmpty) ...[
            const SizedBox(height: 20),
            _buildPreview(),
          ],
          if (_isUploading) ...[
            const SizedBox(height: 20),
            _buildProgressIndicator(),
          ],
          if (_errors.isNotEmpty) ...[
            const SizedBox(height: 20),
            _buildErrorLog(),
          ],
        ],
      ),
    );
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

  Widget _buildTemplateInfo() {
    final Map<String, List<String>> templates = {
      'Fee Structure': ['classInRoman', 'classTutionFees', 'classExamFees'],
      'Student Details': ['stuId', 'stuName', 'stuClass', 'stuSection', 'phoneNumber', 'isStuAvailVan'],
      'Student Fee Details': [
        'stuId', 'stuName', 'stuClass', 'stuSection', 'phoneNumber',
        'stuPendingFees', 'stuConcessionFees', 'isStuAvailVan', 'stuTotalVanFees',
        'stuPaidTutionFees', 'stuPaidExamFees', 'studPaidVanFees', 'stuPaidTotalFees',
        'stuBillDetails',
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

      // Headers — exact column order matching old app's file_upload_page.dart
      final stuHeaders = [
        'stuId',          // col 0
        'stuName',        // col 1
        'stuClass',       // col 2
        'stuSection',     // col 3
        'stuPendingFees', // col 4
        'stuConcessionFees', // col 5
        'isStuAvailVan',  // col 6  (y/n)
        'stuTotalVanFees',// col 7
        'stuPaidTutionFees', // col 8
        'stuPaidExamFees',   // col 9
        'studPaidVanFees',   // col 10
        'stuPaidTotalFees',  // col 11
        'phoneNumber',       // col 12
        'stuBillDetails',    // col 13 (leave blank / NA)
      ];
      for (int i = 0; i < stuHeaders.length; i++) {
        stuSheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
          ..value = TextCellValue(stuHeaders[i])
          ..cellStyle = CellStyle(bold: true, backgroundColorHex: ExcelColor.fromHexString('#1F4E79'), fontColorHex: ExcelColor.fromHexString('#FFFFFF'));
      }

      // Sample rows
      final stuSampleRows = [
        ['101', 'SAMPLE STUDENT 1', 'I', 'A', '0', '0', 'n', '0', '0', '0', '0', '0', '9999999999', 'NA'],
        ['102', 'SAMPLE STUDENT 2', 'I', 'A', '0', '0', 'y', '1200', '0', '0', '0', '0', '9999999998', 'NA'],
        ['103', 'SAMPLE STUDENT 3', 'II', 'B', '500', '200', 'n', '0', '3000', '300', '0', '3300', '9999999997', 'NA'],
      ];
      for (int r = 0; r < stuSampleRows.length; r++) {
        final row = stuSampleRows[r];
        stuSheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r + 1)).value = IntCellValue(int.tryParse(row[0]) ?? 0);
        stuSheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: r + 1)).value = TextCellValue(row[1]);
        stuSheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: r + 1)).value = TextCellValue(row[2]);
        stuSheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: r + 1)).value = TextCellValue(row[3]);
        for (int c = 4; c <= 11; c++) {
          stuSheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r + 1)).value = DoubleCellValue(double.tryParse(row[c]) ?? 0);
        }
        stuSheet.cell(CellIndex.indexByColumnRow(columnIndex: 12, rowIndex: r + 1)).value = TextCellValue(row[12]);
        stuSheet.cell(CellIndex.indexByColumnRow(columnIndex: 13, rowIndex: r + 1)).value = TextCellValue(row[13]);
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
                  ? _previewData.sublist(1, _previewData.length > 6 ? 6 : _previewData.length).map((r) => DataRow(
                      cells: r.map((c) => DataCell(Text(c, style: const TextStyle(color: _textPrimary, fontSize: 11)))).toList(),
                    )).toList()
                  : [],
            ),
          ),
          if (_previewData.length > 6) Padding(
            padding: const EdgeInsets.all(12),
            child: Text('...and ${_previewData.length - 6} more rows', style: const TextStyle(color: _textSecondary, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    final progress = _totalCount > 0 ? _processedCount / _totalCount : 0.0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _cardDark, borderRadius: BorderRadius.circular(12), border: Border.all(color: _borderColor)),
      child: Column(children: [
        Text(_statusMessage, style: const TextStyle(color: _textPrimary, fontWeight: FontWeight.w500)),
        const SizedBox(height: 12),
        LinearProgressIndicator(value: progress, backgroundColor: _bgDark, valueColor: const AlwaysStoppedAnimation<Color>(_accentGreen)),
        const SizedBox(height: 8),
        Text('$_processedCount / $_totalCount', style: const TextStyle(color: _textSecondary)),
      ]),
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
      if (excel.tables.containsKey('FEE_STRUCTURE') || excel.tables.containsKey('STUDENT_FEE_DETAILS')) {
        if (_selectedType == 'Fee Structure' && excel.tables.containsKey('FEE_STRUCTURE')) {
          targetSheet = 'FEE_STRUCTURE';
        } else if (_selectedType == 'Student Fee Details' && excel.tables.containsKey('STUDENT_FEE_DETAILS')) {
          targetSheet = 'STUDENT_FEE_DETAILS';
        } else {
          // Show available sheets for user to know
          final available = excel.tables.keys.join(', ');
          setState(() => _errors = ['Sheet not found for "$_selectedType". Available sheets: $available']);
          return;
        }
      } else {
        targetSheet = excel.tables.keys.first;
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

      setState(() {
        _previewData = preview;
        _errors = [];
        _statusMessage = 'Loaded ${preview.length - 1} rows from sheet "$targetSheet"';
      });
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
        return;
      }

      final bytes = result.files.first.bytes;
      if (bytes == null) {
        setState(() {
          _isUploading = false;
          _statusMessage = 'Failed to read file';
        });
        return;
      }

      final excel = Excel.decodeBytes(bytes);
      final Map<String, dynamic> classWiseFeeDetails = {};

      // Process FEE_STRUCTURE sheet first (to get class fees for student calculations)
      if (excel.tables.containsKey('FEE_STRUCTURE')) {
        setState(() => _statusMessage = 'Processing Fee Structure...');
        final sheet = excel.tables['FEE_STRUCTURE']!;
        int feeCount = 0;

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

            // Upload to Firestore
            await _uploadFeeStructure({
              'classInRoman': className,
              'classTutionFees': tuitionFee.toString(),
              'classExamFees': examFee.toString(),
            });

            feeCount++;
            setState(() {
              _processedCount = feeCount;
              _statusMessage = 'Processing Fee Structure... ($feeCount rows)';
            });
          } catch (e) {
            _errors.add('FEE_STRUCTURE row ${row.first?.rowIndex}: $e');
          }
        }
      }

      // Process STUDENT_FEE_DETAILS sheet
      if (excel.tables.containsKey('STUDENT_FEE_DETAILS')) {
        setState(() => _statusMessage = 'Processing Student Fee Details...');
        final sheet = excel.tables['STUDENT_FEE_DETAILS']!;
        int stuCount = 0;

        for (var row in sheet.rows) {
          if (row.first?.rowIndex == 0) continue; // Skip header

          try {
            final stuId = row[0]?.value?.toString() ?? '';
            if (stuId.isEmpty) continue;

            final stuName = row[1]?.value?.toString() ?? '';
            final stuClass = row[2]?.value?.toString() ?? '';
            final stuSection = row[3]?.value?.toString() ?? '';
            final stuPendingFees = double.tryParse(row[4]?.value?.toString() ?? '0') ?? 0;
            final stuConcessionFees = double.tryParse(row[5]?.value?.toString() ?? '0') ?? 0;
            final isStuAvailVan = row[6]?.value?.toString().toLowerCase() ?? 'n';
            final stuTotalVanFees = double.tryParse(row[7]?.value?.toString() ?? '0') ?? 0;
            final stuPaidTutionFees = double.tryParse(row[8]?.value?.toString() ?? '0') ?? 0;
            final stuPaidExamFees = double.tryParse(row[9]?.value?.toString() ?? '0') ?? 0;
            final studPaidVanFees = double.tryParse(row[10]?.value?.toString() ?? '0') ?? 0;
            final stuPaidTotalFees = double.tryParse(row[11]?.value?.toString() ?? '0') ?? 0;
            final phoneNumber = row[12]?.value?.toString() ?? '';
            final stuBillDetails = row[13]?.value?.toString() ?? 'NA';

            // Get class fees from previously loaded data
            final classTuitionFees = (classWiseFeeDetails['$stuClass-tutionFees'] as double?) ?? 0;
            final classExamFees = (classWiseFeeDetails['$stuClass-examFees'] as double?) ?? 0;

            // Upload student fee details with calculated values
            await _uploadStudentFeeDetailsWithClassFees({
              'stuId': stuId,
              'stuName': stuName,
              'stuClass': stuClass,
              'stuSection': stuSection,
              'stuPendingFees': stuPendingFees.toString(),
              'stuConcessionFees': stuConcessionFees.toString(),
              'isStuAvailVan': isStuAvailVan,
              'stuTotalVanFees': stuTotalVanFees.toString(),
              'stuPaidTutionFees': stuPaidTutionFees.toString(),
              'stuPaidExamFees': stuPaidExamFees.toString(),
              'studPaidVanFees': studPaidVanFees.toString(),
              'stuPaidTotalFees': stuPaidTotalFees.toString(),
              'phoneNumber': phoneNumber,
              'stuBillDetails': stuBillDetails,
            }, classTuitionFees, classExamFees);

            stuCount++;
            setState(() {
              _processedCount = stuCount;
              _statusMessage = 'Processing Student Fee Details... ($stuCount rows)';
            });
          } catch (e) {
            _errors.add('STUDENT_FEE_DETAILS row ${row.first?.rowIndex}: $e');
          }
        }
      }

      setState(() {
        _isUploading = false;
        _statusMessage = 'Upload complete!';
      });

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
    }
  }

  // Helper method to upload student fee details with pre-calculated class fees
  Future<void> _uploadStudentFeeDetailsWithClassFees(Map<String, dynamic> data, double classTuitionFees, double classExamFees) async {
    final stuId = (data['stuId'] ?? '').toString();
    final stuName = (data['stuName'] ?? '').toString();
    if (stuId.isEmpty || stuName.isEmpty) throw Exception('Missing stuId or stuName');

    double parseNum(String key) => double.tryParse((data[key] ?? '0').toString()) ?? 0.0;

    final stuPendingFees = parseNum('stuPendingFees');
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
    final stuBalTutionFees = stuTotalTutionFees + stuPendingFees - stuConcessionFees - stuPaidTutionFees;
    final stuBalExamFees = stuTotalExamFees - stuPaidExamFees;
    final stuBalVanFees = stuTotalVanFees - studPaidVanFees;
    final stuBalTotalFees = (stuTotalTutionFees + stuTotalExamFees + stuTotalVanFees + stuPendingFees) - stuConcessionFees - stuPaidTotalFees;

    final feeData = <String, dynamic>{
      'stuId': int.tryParse(stuId) ?? 0,
      'stuName': stuName,
      'studentName': stuName,
      'stuClass': (data['stuClass'] ?? '').toString(),
      'className': (data['stuClass'] ?? '').toString(),
      'stuSection': (data['stuSection'] ?? '').toString(),
      'section': (data['stuSection'] ?? '').toString(),
      'phoneNumber': (data['phoneNumber'] ?? '').toString(),
      'isStuAvailVan': isStuAvailVan,
      'stuPendingFees': stuPendingFees,
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
      'arrearTuitionFees': 0.0,
      'arrearExamFees': 0.0,
      'arrearAdmissionFees': 0.0,
      'arrearVanFees': 0.0,
      'stuPaidArrearTutionFees': 0.0,
      'stuPaidArrearExamFees': 0.0,
      'stuPaidArrearAdmissionFees': 0.0,
      'stuPaidArrearVanFees': 0.0,
      'balanceArrearTuitionFees': 0.0,
      'balanceArrearExamFees': 0.0,
      'balanceArrearAdmissionFees': 0.0,
      'balanceArrearVanFees': 0.0,
      'stuBillDetails': (data['stuBillDetails'] ?? 'NA').toString(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    // First, create/update student record in students collection
    final stuClass = (data['stuClass'] ?? '').toString();
    final stuSection = (data['stuSection'] ?? '').toString();
    final phoneNumber = (data['phoneNumber'] ?? '').toString();
    
    final studentData = {
      'studentId': stuId,
      'name': stuName,
      'className': stuClass,
      'section': stuSection,
      'phone': phoneNumber,
      'vanService': isStuAvailVan == 'y' || isStuAvailVan == 'yes',
      'status': 'active',
      'updatedAt': FieldValue.serverTimestamp(),
    };

    final existingStudent = await FirebaseFirestore.instance
        .collection('schools').doc(_schoolId).collection('students')
        .where('studentId', isEqualTo: stuId)
        .limit(1)
        .get();

    if (existingStudent.docs.isNotEmpty) {
      await existingStudent.docs.first.reference.update(studentData);
    } else {
      studentData['createdAt'] = FieldValue.serverTimestamp();
      await FirebaseFirestore.instance.collection('schools').doc(_schoolId).collection('students').add(studentData);
    }

    // Then, create/update student fee details
    final existing = await FirebaseFirestore.instance
        .collection('schools').doc(_schoolId).collection('student_fee_details')
        .where('stuId', isEqualTo: int.tryParse(stuId) ?? 0)
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
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      await FirebaseFirestore.instance.collection('schools').doc(_schoolId).collection('fee_structures').add({
        'className': className,
        'tuitionFee': tuitionFee,
        'examFee': examFee,
        'isActive': true,
        'academicYear': '${DateTime.now().year}-${DateTime.now().year + 1}',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> _uploadStudentFeeDetails(Map<String, dynamic> data) async {
    // Supports both master-sheet column order (old app) and named-column order
    // Master sheet cols: stuId(0) stuName(1) stuClass(2) stuSection(3)
    //   stuPendingFees(4) stuConcessionFees(5) isStuAvailVan(6) stuTotalVanFees(7)
    //   stuPaidTutionFees(8) stuPaidExamFees(9) studPaidVanFees(10) stuPaidTotalFees(11)
    //   phoneNumber(12) stuBillDetails(13)
    final stuId = (data['stuId'] ?? '').toString();
    final stuName = (data['stuName'] ?? '').toString();
    if (stuId.isEmpty || stuName.isEmpty) throw Exception('Missing stuId or stuName');

    final stuClass = (data['stuClass'] ?? '').toString();

    double parseNum(String key) => double.tryParse((data[key] ?? '0').toString()) ?? 0.0;

    final stuPendingFees = parseNum('stuPendingFees');
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

    // Derive totals exactly as old app does
    final stuTotalTutionFees = classTuitionFees;
    final stuTotalExamFees = classExamFees;
    final stuTotalFees = stuTotalTutionFees + stuTotalExamFees + stuTotalVanFees;
    final stuBalTutionFees = stuTotalTutionFees + stuPendingFees - stuConcessionFees - stuPaidTutionFees;
    final stuBalExamFees = stuTotalExamFees - stuPaidExamFees;
    final stuBalVanFees = stuTotalVanFees - studPaidVanFees;
    final stuBalTotalFees = (stuTotalTutionFees + stuTotalExamFees + stuTotalVanFees + stuPendingFees) - stuConcessionFees - stuPaidTotalFees;

    final feeData = <String, dynamic>{
      'stuId': int.tryParse(stuId) ?? 0,
      'stuName': stuName,
      'studentName': stuName,
      'stuClass': stuClass,
      'className': stuClass,
      'stuSection': (data['stuSection'] ?? '').toString(),
      'section': (data['stuSection'] ?? '').toString(),
      'phoneNumber': (data['phoneNumber'] ?? '').toString(),
      'isStuAvailVan': isStuAvailVan,
      'stuPendingFees': stuPendingFees,
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
      'arrearTuitionFees': 0.0,
      'arrearExamFees': 0.0,
      'arrearAdmissionFees': 0.0,
      'arrearVanFees': 0.0,
      'stuPaidArrearTutionFees': 0.0,
      'stuPaidArrearExamFees': 0.0,
      'stuPaidArrearAdmissionFees': 0.0,
      'stuPaidArrearVanFees': 0.0,
      'balanceArrearTuitionFees': 0.0,
      'balanceArrearExamFees': 0.0,
      'balanceArrearAdmissionFees': 0.0,
      'balanceArrearVanFees': 0.0,
      'stuBillDetails': (data['stuBillDetails'] ?? 'NA').toString(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    // First, create/update student record in students collection
    final stuSection = (data['stuSection'] ?? '').toString();
    final phoneNumber = (data['phoneNumber'] ?? '').toString();
    
    final studentData = {
      'studentId': stuId,
      'name': stuName,
      'className': stuClass,
      'section': stuSection,
      'phone': phoneNumber,
      'vanService': isStuAvailVan == 'y' || isStuAvailVan == 'yes',
      'status': 'active',
      'updatedAt': FieldValue.serverTimestamp(),
    };

    final existingStudent = await FirebaseFirestore.instance
        .collection('schools').doc(_schoolId).collection('students')
        .where('studentId', isEqualTo: stuId)
        .limit(1)
        .get();

    if (existingStudent.docs.isNotEmpty) {
      await existingStudent.docs.first.reference.update(studentData);
    } else {
      studentData['createdAt'] = FieldValue.serverTimestamp();
      await FirebaseFirestore.instance.collection('schools').doc(_schoolId).collection('students').add(studentData);
    }

    // Then, create/update student fee details
    final existing = await FirebaseFirestore.instance
        .collection('schools').doc(_schoolId).collection('student_fee_details')
        .where('stuId', isEqualTo: int.tryParse(stuId) ?? 0)
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
