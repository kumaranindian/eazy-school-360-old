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
import '../../../data/repositories/fee_repository.dart';
import '../../../data/services/fee_structure_to_payment_mapper.dart';

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
  String _selectedType = 'Student Fee Details';
  bool _isUploading = false;
  String _statusMessage = '';
  int _processedCount = 0;
  int _totalCount = 0;
  List<String> _errors = [];
  List<List<String>> _previewData = [];
  Uint8List? _fileBytes;

  /// Bumped every time progress (count, status, errors) changes so the
  /// modal progress dialog – which lives in a separate Overlay route and
  /// therefore does NOT rebuild when the parent calls setState – can
  /// listen and refresh.
  final ValueNotifier<int> _progressTick = ValueNotifier<int>(0);
  void _bumpProgress() => _progressTick.value++;

  @override
  void dispose() {
    _progressTick.dispose();
    super.dispose();
  }

  /// Academic year the sheet data will be attached to. Defaults to the
  /// current year, but can be overridden manually (e.g. importing last
  /// year's rolls into a freshly-created school).
  String _selectedAcademicYear = AcademicYear.getCurrentYearCode();

  /// Admin-configured active academic year (the doc with `isCurrent == true`
  /// in `schools/{schoolId}/academicYears`). Drives which chip shows the
  /// "CURRENT" badge. Falls back to the date-derived year until the
  /// async load resolves.
  String _activeAcademicYear = AcademicYear.getCurrentYearCode();

  /// Flag to track if active academic year has been loaded from Firestore
  bool _activeAyLoaded = false;

  /// Set to `true` when the parsed sheet already contains an
  /// `academicYear` / `yearCode` column per row. In that case the
  /// per-row value wins over [_selectedAcademicYear].
  bool _sheetProvidesAcademicYear = false;

  String? get _schoolId => ref.read(currentSessionProvider)?.schoolId;

  @override
  void initState() {
    super.initState();
    // Defer until after first frame so `ref.read` is safe to use.
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _loadActiveAcademicYear());
  }

  /// Reads the school's admin-configured active academic year from
  /// `schools/{schoolId}/academicYears` (the doc with `isCurrent == true`).
  /// Falls back silently to the date-derived current year if the school
  /// hasn't configured one yet.
  Future<void> _loadActiveAcademicYear() async {
    if (_schoolId == null) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('schools')
          .doc(_schoolId)
          .collection('academicYears')
          .where('isCurrent', isEqualTo: true)
          .limit(1)
          .get();
      debugPrint(
          '[UploadSheet] Active AY query returned ${snap.docs.length} docs for school $_schoolId');
      if (snap.docs.isEmpty) {
        debugPrint(
            '[UploadSheet] No active AY found in Firestore, checking all AY docs...');
        // Try to fetch all AY docs to see what's available
        final allSnap = await FirebaseFirestore.instance
            .collection('schools')
            .doc(_schoolId)
            .collection('academicYears')
            .get();
        debugPrint('[UploadSheet] Total AY docs: ${allSnap.docs.length}');
        for (final doc in allSnap.docs) {
          final data = doc.data();
          debugPrint(
              '[UploadSheet] AY doc: ${data['yearCode']} (isCurrent: ${data['isCurrent']})');
        }
        debugPrint(
            '[UploadSheet] Using date-derived AY: $_selectedAcademicYear');
        return;
      }
      if (!mounted) return;
      final code = (snap.docs.first.data()['yearCode'] ?? '').toString();
      debugPrint('[UploadSheet] Active AY from Firestore: $code');
      if (code.isEmpty) return;
      setState(() {
        _selectedAcademicYear = code;
        _activeAcademicYear = code;
        _activeAyLoaded = true;
      });
      debugPrint(
          '[UploadSheet] Set selected AY to: $code (activeLoaded: $_activeAyLoaded)');
    } catch (e) {
      debugPrint('[UploadSheet] Could not load active academic year: $e');
    }
  }

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

  /// Gets the previous academic year code from the current year code
  /// Example: "2024-25" -> "2023-24"
  String _getPreviousAcademicYear(String currentYear) {
    final parts = currentYear.split('-');
    if (parts.length != 2) return currentYear;
    final startYear = int.tryParse(parts[0]) ?? 0;
    final prevStartYear = startYear - 1;
    return '$prevStartYear-${(prevStartYear + 1) % 100}';
  }

  /// Scans an excel sheet's header row for an academicYear-like column and
  /// returns its index, or null when not present.
  int? _findYearColumn(List<List<Data?>> rows) {
    if (rows.isEmpty) {
      debugPrint('🔍 _findYearColumn: rows empty');
      return null;
    }
    final header = rows.first;
    final headerStrings = header
        .map((c) => c?.value?.toString().trim().toLowerCase() ?? '')
        .toList();
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

  /// Builds a map from normalized header name (lowercase, alphanumerics
  /// only) to column index. Lets row-level code resolve fields by header
  /// regardless of position or punctuation/whitespace differences.
  Map<String, int> _buildHeaderIndex(List<List<Data?>> rows) {
    final out = <String, int>{};
    if (rows.isEmpty) return out;
    final header = rows.first;
    for (int i = 0; i < header.length; i++) {
      final raw = header[i]?.value?.toString().trim().toLowerCase() ?? '';
      if (raw.isEmpty) continue;
      // Keep two forms: original-lowercase and stripped (no underscores
      // or spaces) so callers can use whichever is most natural.
      out[raw] = i;
      final stripped = raw.replaceAll(RegExp(r'[\s_]+'), '');
      out.putIfAbsent(stripped, () => i);
    }
    return out;
  }

  /// Resolves tuition + exam fees for a class. Tries FeeStructureV2 first
  /// (the new model the user is migrating to), then falls back to the legacy
  /// `fee_structures` collection so existing data and single-sheet uploads
  /// keep producing correct totals.
  ///
  /// Returns a tuple `(tuitionFees, examFees, source)` where source is one of
  /// 'v2', 'legacy', or 'none'. The source is used for diagnostic logging /
  /// warnings shown to the user after upload.
  Future<({double tuition, double exam, String source})> _resolveClassFees(
      String className, String academicYear) async {
    if (_schoolId == null || className.isEmpty) {
      return (tuition: 0.0, exam: 0.0, source: 'none');
    }

    // 1. Try FeeStructureV2 for the requested academic year (preferred)
    try {
      final repo = ref.read(feeRepositoryProvider);
      final v2 = await repo.getFeeStructureV2ByClass(
          _schoolId!, className, academicYear);
      if (v2 != null) {
        final tuition = FeeStructureToPaymentMapper.totalAmountForStructure(v2);
        return (tuition: tuition, exam: 0.0, source: 'v2');
      }
      // 1b. Soft fallback: pick any active V2 structure for the class
      // even if the academic year doesn't match. Avoids "totals = 0"
      // when admins upload last year's roll into a freshly created
      // school whose only V2 structures are for the upcoming year.
      final any =
          await repo.getAnyActiveFeeStructureV2ByClass(_schoolId!, className);
      if (any != null) {
        final tuition =
            FeeStructureToPaymentMapper.totalAmountForStructure(any.structure);
        debugPrint(
            'ℹ️ Reusing V2 structure for $className from AY ${any.academicYear} (requested $academicYear)');
        return (tuition: tuition, exam: 0.0, source: 'v2-${any.academicYear}');
      }
    } catch (e) {
      debugPrint('⚠️ V2 lookup failed for $className/$academicYear: $e');
      // Surface to the visible errors panel so silent index/perm failures
      // don't masquerade as "no fee structure exists" and produce 0 totals.
      _errors.add('V2 lookup error for class "$className": $e');
    }

    // 2. Fallback: legacy fee_structures collection (what the FEE_STRUCTURE
    //    sheet of the master template writes to).
    try {
      final feeSnap = await FirebaseFirestore.instance
          .collection('schools')
          .doc(_schoolId)
          .collection('fee_structures')
          .where('className', isEqualTo: className)
          .limit(1)
          .get();
      if (feeSnap.docs.isNotEmpty) {
        final fd = feeSnap.docs.first.data();
        final tuition = (fd['tuitionFee'] as num?)?.toDouble() ?? 0;
        final exam = (fd['examFee'] as num?)?.toDouble() ?? 0;
        return (tuition: tuition, exam: exam, source: 'legacy');
      }
    } catch (e) {
      debugPrint('⚠️ Legacy lookup failed for $className: $e');
    }

    return (tuition: 0.0, exam: 0.0, source: 'none');
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
                    border: Border.all(
                        color: _accentGreen.withOpacity(0.3), width: 2),
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
                widthFactor:
                    _totalCount > 0 ? _processedCount / _totalCount : 0.0,
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
                  border: Border.all(
                      color: const Color(0xFFEF4444).withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_errors.length} error${_errors.length == 1 ? '' : 's'}',
                      style: const TextStyle(
                          color: Color(0xFFEF4444),
                          fontWeight: FontWeight.w600,
                          fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    ..._errors.map((e) => Text(
                          '• $e',
                          style: const TextStyle(
                              color: Color(0xFFEF4444), fontSize: 11),
                        )),
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
        // Rebuild the dialog body whenever progress changes. The dialog
        // is in a separate overlay route that does not see parent state
        // updates, so this listenable is what drives live progress.
        child: ValueListenableBuilder<int>(
          valueListenable: _progressTick,
          builder: (_, __, ___) => _buildUploadProgressDialog(),
        ),
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
        gradient: const LinearGradient(
            colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.upload_file_rounded,
              color: Colors.white, size: 28),
        ),
        const SizedBox(width: 16),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Upload Data Sheet',
              style: TextStyle(
                  fontSize: isDesktop ? 24 : 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
          const SizedBox(height: 4),
          Text('Import fee structures, students, and fee details from Excel',
              style: TextStyle(
                  fontSize: 14, color: Colors.white.withOpacity(0.9))),
        ])),
      ]),
    );
  }

  Widget _buildUploadTypeSelector() {
    final types = ['Student Fee Details'];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: _cardDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _borderColor)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Upload Type',
              style: TextStyle(
                  color: _textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: types
                .map((t) => ChoiceChip(
                      label: Text(t),
                      selected: _selectedType == t,
                      selectedColor: _accentGreen,
                      backgroundColor: _bgDark,
                      labelStyle: TextStyle(
                          color: _selectedType == t
                              ? Colors.white
                              : _textSecondary,
                          fontWeight: FontWeight.w500),
                      side: BorderSide(
                          color:
                              _selectedType == t ? _accentGreen : _borderColor),
                      onSelected: (_) => setState(() {
                        _selectedType = t;
                        _previewData = [];
                        _errors = [];
                      }),
                    ))
                .toList(),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
              final isCurrent = yr == _activeAcademicYear;
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
                side:
                    BorderSide(color: isSelected ? _accentGreen : _borderColor),
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
      'Student Details': [
        'stuId',
        'stuName',
        'stuClass',
        'stuSection',
        'phoneNumber',
        'isStuAvailVan'
      ],
      'Student Fee Details': [
        'stuId',
        'stuName',
        'stuClass',
        'stuSection',
        'academicYear',
        'arrearsAcademicYear',
        'arrearTuitionFees',
        'arrearExamFees',
        'arrearVanFees',
        'stuConcessionFees',
        'isStuAvailVan',
        'stuTotalVanFees',
        'stuPaidTutionFees',
        'stuPaidExamFees',
        'studPaidVanFees',
        'stuPaidTotalFees',
        'phoneNumber',
        'stuBillDetails',
      ],
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: _cardDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _borderColor)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.info_outline_rounded,
                color: Color(0xFF3B82F6), size: 20),
            const SizedBox(width: 8),
            Expanded(
                child: Text('Template: "$_selectedType"',
                    style: const TextStyle(
                        color: _textPrimary, fontWeight: FontWeight.bold))),
            ElevatedButton.icon(
              icon: const Icon(Icons.download_rounded, size: 16),
              label: const Text('Download Template'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                textStyle: const TextStyle(fontSize: 12),
              ),
              onPressed: () async {
                await _downloadTemplate();
              },
            ),
          ]),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: (templates[_selectedType] ?? [])
                .map((c) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                          color: _bgDark,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: _borderColor)),
                      child: Text(c,
                          style: const TextStyle(
                              color: _accentGreen,
                              fontSize: 12,
                              fontFamily: 'monospace')),
                    ))
                .toList(),
          ),
          const SizedBox(height: 12),
          const Text(
            'Download the template, fill in your data, then upload the same file. '
            'The sheet contains STUDENT_FEE_DETAILS tab with 100 sample students.',
            style: TextStyle(color: _textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }

  /// Generates and downloads the Excel template with STUDENT_FEE_DETAILS sheet only.
  Future<void> _downloadTemplate() async {
    print('=== DOWNLOAD TEMPLATE FUNCTION CALLED ===');

    // Directly query Firestore for active AY to ensure we get the correct value
    String ayToUse = _selectedAcademicYear;
    try {
      if (_schoolId != null) {
        final snap = await FirebaseFirestore.instance
            .collection('schools')
            .doc(_schoolId)
            .collection('academicYears')
            .where('isCurrent', isEqualTo: true)
            .limit(1)
            .get();
        if (snap.docs.isNotEmpty) {
          ayToUse = (snap.docs.first.data()['yearCode'] ?? '').toString();
          print('[UploadSheet] Active AY from Firestore: $ayToUse');
        } else {
          print(
              '[UploadSheet] No active AY found, using selected: $_selectedAcademicYear');
        }
      }
    } catch (e) {
      print(
          '[UploadSheet] Error fetching AY: $e, using selected: $_selectedAcademicYear');
    }

    print('[UploadSheet] Final AY to use: $ayToUse');

    // Calculate previous academic year for arrears
    final previousAy = _getPreviousAcademicYear(ayToUse);
    print('[UploadSheet] Previous AY for arrears: $previousAy');

    try {
      final excel = Excel.createExcel();

      // ── Sheet: STUDENT_FEE_DETAILS ───────────────────────────────────
      final stuSheet = excel['STUDENT_FEE_DETAILS'];
      excel.setDefaultSheet('STUDENT_FEE_DETAILS');

      // Headers
      final stuHeaders = [
        'stuId', // col 0
        'stuName', // col 1
        'stuClass', // col 2
        'stuSection', // col 3
        'academicYear', // col 4
        'arrearsAcademicYear', // col 5 - AY for arrears (optional, defaults to previous AY)
        'arrearTuitionFees', // col 6
        'arrearExamFees', // col 7
        'arrearVanFees', // col 8
        'stuConcessionFees', // col 9
        'isStuAvailVan', // col 10  (y/n)
        'stuTotalVanFees', // col 11
        'stuPaidTutionFees', // col 12
        'stuPaidExamFees', // col 13
        'studPaidVanFees', // col 14
        'stuPaidTotalFees', // col 15
        'phoneNumber', // col 16
        'stuBillDetails', // col 17 (leave blank / NA)
      ];
      for (int i = 0; i < stuHeaders.length; i++) {
        stuSheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
          ..value = TextCellValue(stuHeaders[i])
          ..cellStyle = CellStyle(
              bold: true,
              backgroundColorHex: ExcelColor.fromHexString('#1F4E79'),
              fontColorHex: ExcelColor.fromHexString('#FFFFFF'));
      }

      // Sample rows (18 cols: 0-3 text, 4 academicYear, 5 arrearsAcademicYear, 6-15 numbers, 16 phone, 17 text)
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
      final sections = ['A', 'B', 'C'];
      final stuSampleRows = <List<String>>[];

      for (int i = 1; i <= 100; i++) {
        final classIndex = (i - 1) % classes.length;
        final sectionIndex = (i - 1) % sections.length;
        final className = classes[classIndex];
        final section = sections[sectionIndex];
        final hasArrears = i % 3 == 0; // Every 3rd student has arrears
        final hasVan = i % 4 == 0; // Every 4th student uses van

        stuSampleRows.add([
          (100 + i).toString(),
          'SAMPLE STUDENT $i',
          className,
          section,
          ayToUse,
          hasArrears
              ? previousAy
              : '', // arrearsAcademicYear - previous AY for arrears
          hasArrears
              ? (500 + (i % 10) * 100).toString()
              : '0', // arrearTuitionFees
          hasArrears ? (100 + (i % 5) * 50).toString() : '0', // arrearExamFees
          hasArrears
              ? (i % 3 == 0 ? '200' : '0').toString()
              : '0', // arrearVanFees
          '0', // stuConcessionFees
          hasVan ? 'y' : 'n', // isStuAvailVan
          hasVan ? '1200' : '0', // stuTotalVanFees
          '0', // stuPaidTutionFees
          '0', // stuPaidExamFees
          '0', // studPaidVanFees
          '0', // stuPaidTotalFees
          '9876543${(i % 10)}00', // phoneNumber
          'NA', // stuBillDetails
        ]);
      }
      for (int r = 0; r < stuSampleRows.length; r++) {
        final row = stuSampleRows[r];
        stuSheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r + 1))
            .value = IntCellValue(int.tryParse(row[0]) ?? 0);
        stuSheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: r + 1))
            .value = TextCellValue(row[1]);
        stuSheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: r + 1))
            .value = TextCellValue(row[2]);
        stuSheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: r + 1))
            .value = TextCellValue(row[3]);
        // Column 4: academicYear (text)
        stuSheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: r + 1))
            .value = TextCellValue(row[4]);
        // Column 5: arrearsAcademicYear (text)
        stuSheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: r + 1))
            .value = TextCellValue(row[5]);
        // Columns 6-15: numeric values (with y/n check for isStuAvailVan at col 10)
        for (int c = 6; c <= 15; c++) {
          final cv = row[c];
          if (cv == 'n' || cv == 'y') {
            stuSheet
                .cell(
                    CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r + 1))
                .value = TextCellValue(cv);
          } else {
            stuSheet
                .cell(
                    CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r + 1))
                .value = DoubleCellValue(double.tryParse(cv) ?? 0);
          }
        }
        // Columns 16-17: text values (phone, bill details)
        stuSheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 16, rowIndex: r + 1))
            .value = TextCellValue(row[16]);
        stuSheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 17, rowIndex: r + 1))
            .value = TextCellValue(row[17]);
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
      final filename = 'SAMPLE_FEE_SHEET_$ayToUse.xlsx';
      (html.AnchorElement(href: url)
        ..setAttribute('download', filename)
        ..click());
      html.Url.revokeObjectUrl(url);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Template downloaded: $filename'),
            backgroundColor: const Color(0xFF3B82F6),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Download failed: $e'),
              backgroundColor: Colors.red),
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
          border: Border.all(
              color: _accentGreen.withOpacity(0.3),
              width: 2,
              strokeAlign: BorderSide.strokeAlignInside),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_upload_rounded,
                size: 48, color: _accentGreen.withOpacity(0.7)),
            const SizedBox(height: 12),
            const Text('Click to upload Excel file (.xlsx)',
                style: TextStyle(
                    color: _textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            const Text('Supports .xlsx format only',
                style: TextStyle(color: _textSecondary, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview() {
    return Container(
      decoration: BoxDecoration(
          color: _cardDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _borderColor)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              const Text('Preview',
                  style: TextStyle(
                      color: _textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                    color: _accentGreen.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10)),
                child: Text('${_previewData.length - 1} rows',
                    style: const TextStyle(color: _accentGreen, fontSize: 12)),
              ),
              const Spacer(),
              ElevatedButton.icon(
                icon: const Icon(Icons.upload_rounded, size: 16),
                label: const Text('Upload to Firestore'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: _accentGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8))),
                onPressed: _isUploading ? null : _uploadData,
              ),
            ]),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(_bgDark),
              columns: _previewData.isNotEmpty
                  ? _previewData[0]
                      .map((h) => DataColumn(
                          label: Text(h,
                              style: const TextStyle(
                                  color: _accentGreen,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11))))
                      .toList()
                  : [],
              rows: _previewData.length > 1
                  ? _previewData
                      .sublist(1)
                      .map((r) => DataRow(
                            cells: r
                                .map((c) => DataCell(Text(c,
                                    style: const TextStyle(
                                        color: _textPrimary, fontSize: 11))))
                                .toList(),
                          ))
                      .toList()
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
      decoration: BoxDecoration(
          color: const Color(0xFFEF4444).withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.3))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Errors (${_errors.length})',
              style: const TextStyle(
                  color: Color(0xFFEF4444), fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ..._errors.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('• $e',
                    style: const TextStyle(
                        color: Color(0xFFEF4444), fontSize: 12)),
              )),
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

      _fileBytes = bytes;
      _parseExcel(bytes);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error picking file: $e'),
            backgroundColor: Colors.red));
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

      if (allSheets.contains('FEE_STRUCTURE') ||
          allSheets.contains('STUDENT_FEE_DETAILS')) {
        if (_selectedType == 'Fee Structure' &&
            allSheets.contains('FEE_STRUCTURE')) {
          targetSheet = 'FEE_STRUCTURE';
          debugPrint('✅ Auto-detected FEE_STRUCTURE sheet');
        } else if (_selectedType == 'Student Fee Details' &&
            allSheets.contains('STUDENT_FEE_DETAILS')) {
          targetSheet = 'STUDENT_FEE_DETAILS';
          debugPrint('✅ Auto-detected STUDENT_FEE_DETAILS sheet');
        } else {
          // Show available sheets for user to know
          final available = allSheets.join(', ');
          debugPrint(
              '❌ No matching sheet for "$_selectedType". Available: $available');
          // Instead of error, fall back to first sheet and warn the user
          targetSheet = allSheets.first;
          debugPrint('⚠️ Falling back to first sheet: $targetSheet');
          // Optionally show a warning in the UI
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    'Sheet "$_selectedType" not found. Using sheet "$targetSheet" instead.'),
                backgroundColor: const Color(0xFFF59E0B),
                duration: const Duration(seconds: 4),
              ),
            );
          }
        }
      } else {
        targetSheet = allSheets.first;
        debugPrint(
            '⚠️ No master sheet names found; falling back to first sheet: $targetSheet');
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
        final headers =
            preview.first.map((h) => h.trim().toLowerCase()).toList();
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
        _statusMessage =
            'Loaded ${preview.length - 1} rows from sheet "$targetSheet"';
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

    // Process single sheet preview
    if (_previewData.length < 2) return;

    setState(() {
      _isUploading = true;
      _processedCount = 0;
      _totalCount = _previewData.length - 1;
      _errors = [];
      _statusMessage = 'Uploading $_selectedType...';
    });
    _bumpProgress();
    _showUploadProgressDialog();

    try {
      final headers = _previewData[0];
      final dataRows = _previewData.sublist(1);

      // Process in batches of 20 students in parallel for better performance
      const batchSize = 20;
      for (int batchStart = 0;
          batchStart < dataRows.length;
          batchStart += batchSize) {
        final batchEnd = (batchStart + batchSize).clamp(0, dataRows.length);
        final batch = dataRows.sublist(batchStart, batchEnd);

        // Process batch in parallel
        final futures = <Future<void>>[];
        for (int i = 0; i < batch.length; i++) {
          futures.add(() async {
            try {
              final row = batch[i];
              final map = <String, dynamic>{};
              for (int j = 0; j < headers.length && j < row.length; j++) {
                map[headers[j]] = row[j];
              }

              await _uploadStudentFeeDetails(map);

              if (mounted) {
                setState(() {
                  _processedCount++;
                  _statusMessage =
                      'Uploading $_selectedType... ($_processedCount/$_totalCount)';
                });
                _bumpProgress();
              }
            } catch (e) {
              if (mounted) {
                setState(() {
                  _errors.add('Row ${batchStart + i + 2}: $e');
                });
              }
            }
          }());
        }

        await Future.wait(futures, eagerError: false);
      }

      setState(() {
        _isUploading = false;
        _statusMessage = 'Upload complete!';
      });
      _hideUploadProgressDialog();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Uploaded $_processedCount/$_totalCount records. ${_errors.length} errors.'),
            backgroundColor:
                _errors.isEmpty ? _accentGreen : const Color(0xFFF59E0B),
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

  Future<void> _uploadStudentFeeDetails(Map<String, dynamic> data) async {
    final stuId = (data['stuId'] ?? '').toString();
    final stuName = (data['stuName'] ?? '').toString();
    if (stuId.isEmpty || stuName.isEmpty)
      throw Exception('Missing stuId or stuName');

    double parseNum(String key) =>
        double.tryParse((data[key] ?? '0').toString()) ?? 0.0;

    final arrearTuitionFees = parseNum('arrearTuitionFees');
    final arrearExamFees = parseNum('arrearExamFees');
    final arrearVanFees = parseNum('arrearVanFees');
    final totalArrears = arrearTuitionFees + arrearExamFees + arrearVanFees;

    final stuConcessionFees = parseNum('stuConcessionFees');
    final isStuAvailVan =
        (data['isStuAvailVan'] ?? 'n').toString().toLowerCase();
    final stuTotalVanFees = parseNum('stuTotalVanFees');
    final stuPaidTutionFees = parseNum('stuPaidTutionFees');
    final stuPaidExamFees = parseNum('stuPaidExamFees');
    final studPaidVanFees = parseNum('studPaidVanFees');
    final stuPaidTotalFees = parseNum('stuPaidTotalFees');

    // Use provided class fees instead of looking them up
    final stuClass = (data['stuClass'] ?? '').toString();
    final academicYear = _resolveAcademicYear(data);
    final resolved = await _resolveClassFees(stuClass, academicYear);
    final classTuitionFees = resolved.tuition;
    final classExamFees = resolved.exam;
    if (resolved.source == 'none') {
      _errors.add(
          'No fee structure found for class "$stuClass" (AY $academicYear) — totals set to 0. Create one via Finance → Fee Structures.');
    } else if (resolved.source.startsWith('v2-') && resolved.source != 'v2') {
      final usedAy = resolved.source.substring(3);
      _errors.add(
          'Class "$stuClass": no V2 structure for AY $academicYear; reused active structure from AY $usedAy.');
    }

    final stuTotalTutionFees = classTuitionFees;
    final stuTotalExamFees = classExamFees;
    final stuTotalFees =
        stuTotalTutionFees + stuTotalExamFees + stuTotalVanFees;

    // Concession adjusts tuition only (exclude arrears from current year balance)
    final stuBalTutionFees =
        stuTotalTutionFees - stuConcessionFees - stuPaidTutionFees;
    final stuBalExamFees = stuTotalExamFees - stuPaidExamFees;
    final stuBalVanFees = stuTotalVanFees - studPaidVanFees;
    final stuBalTotalFees = stuBalTutionFees + stuBalExamFees + stuBalVanFees;

    final stuSection = (data['stuSection'] ?? '').toString();
    final phoneNumber = (data['phoneNumber'] ?? '').toString();

    // Fetch next due date and reminder dates from FeeStructureV2
    DateTime? nextDueDate;
    DateTime? reminderDate1;
    DateTime? reminderDate2;
    if (_schoolId != null && stuClass.isNotEmpty) {
      final repo = ref.read(feeRepositoryProvider);
      final nextTerm =
          await repo.getNextDueTermForClass(_schoolId!, stuClass, academicYear);
      if (nextTerm != null) {
        nextDueDate = nextTerm.dueDate;
        // Set reminder dates based on the term's reminder config
        final reminderDays = nextTerm.reminderConfig.beforeDueDays;
        if (reminderDays.isNotEmpty) {
          // First reminder
          reminderDate1 = nextDueDate.subtract(Duration(days: reminderDays[0]));
          // Second reminder if available
          if (reminderDays.length > 1) {
            reminderDate2 =
                nextDueDate.subtract(Duration(days: reminderDays[1]));
          }
        }
      }
    }

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
      // Add due date and reminder dates from FeeStructureV2
      if (nextDueDate != null) 'nextDueDate': Timestamp.fromDate(nextDueDate),
      if (reminderDate1 != null)
        'reminderDate1': Timestamp.fromDate(reminderDate1),
      if (reminderDate2 != null)
        'reminderDate2': Timestamp.fromDate(reminderDate2),
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
      // Include arrears from upload in current year fee details
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
      'arrearsAcademicYear': _getPreviousAcademicYear(academicYear),
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
        .collection('schools')
        .doc(_schoolId)
        .collection('students')
        .where('studentId', isEqualTo: stuIdInt)
        .where('academicYearCode', isEqualTo: academicYear)
        .limit(1)
        .get();

    if (existingStudent.docs.isNotEmpty) {
      await existingStudent.docs.first.reference.update(studentData);
    } else {
      studentData['createdAt'] = FieldValue.serverTimestamp();
      await FirebaseFirestore.instance
          .collection('schools')
          .doc(_schoolId)
          .collection('students')
          .add(studentData);
    }

    // Create/update student fee details for current year
    final existing = await FirebaseFirestore.instance
        .collection('schools')
        .doc(_schoolId)
        .collection('student_fee_details')
        .where('stuId', isEqualTo: stuIdInt)
        .where('academicYear', isEqualTo: academicYear)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      await existing.docs.first.reference.update(feeData);
    } else {
      feeData['createdAt'] = FieldValue.serverTimestamp();
      await FirebaseFirestore.instance
          .collection('schools')
          .doc(_schoolId)
          .collection('student_fee_details')
          .add(feeData);
    }

    // Arrears are now handled in the current AY's student_fee_details record
    // No separate arrears record is created in student_fee_details collection
  }

  Future<void> _uploadFeeStructure(Map<String, dynamic> data) async {
    final className = (data['classInRoman'] ?? '').toString();
    if (className.isEmpty) throw Exception('Missing classInRoman');

    final tuitionFee =
        double.tryParse((data['classTutionFees'] ?? '0').toString()) ?? 0;
    final examFee =
        double.tryParse((data['classExamFees'] ?? '0').toString()) ?? 0;

    // Check if fee structure already exists for this class
    final existing = await FirebaseFirestore.instance
        .collection('schools')
        .doc(_schoolId)
        .collection('fee_structures')
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
      await FirebaseFirestore.instance
          .collection('schools')
          .doc(_schoolId)
          .collection('fee_structures')
          .add({
        'schoolId': _schoolId,
        'className': className,
        'tuitionFee': tuitionFee,
        'examFee': examFee,
        'totalFees': tuitionFee + examFee,
        'academicYear': _resolveAcademicYear(data),
        'fiscalYear': FiscalYear.getCurrentYearCode(),
        'isActive': true, // Add this field to make the fee structure active
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }
}
