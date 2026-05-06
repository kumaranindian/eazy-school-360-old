import 'dart:typed_data';

import 'package:excel/excel.dart';

import '../../domain/entities/fee_structure_v2.dart';
import '../../domain/entities/fee_term.dart';

/// Long-format Excel schema for bulk fee-structure import.
/// One row per **term**. Rows that share `StructureName + AcademicYear` are
/// grouped into a single structure.
///
/// The downloaded template carries one sheet per fee-frequency type so the
/// admin can pick the relevant tab(s) to fill in:
///
///   * **Yearly**     — one annual fee per class, due at the end of the AY (31-May).
///   * **Monthly**    — 12 instalments (Jun → May), due 5th of each month.
///   * **Term-wise**  — 3 terms, due 10th of June / Oct / Feb.
///   * **Custom**     — 4 quarterly instalments — edit at will.
///   * **Instructions** — a read-me sheet explaining the schema.
///
/// Each data sheet shares the same column layout so any of them can be
/// uploaded back in isolation:
///  1. ClassNames        — comma-separated class names (e.g. "I,II,III" or "LKG,UKG")
///  2. StructureName     — display name (e.g. "Class V Termly 2026-2027")
///  3. Type              — MONTHLY | TERM_WISE | YEARLY | CUSTOM
///  4. AcademicYear      — e.g. "2026-2027"
///  5. TermName          — e.g. "Term 1" / "April" / "Annual Fee"
///  6. TermSequence      — 1, 2, 3 …
///  7. Amount            — number (₹)
///  8. DueDate           — yyyy-MM-dd
///  9. LateFeeAmount     — optional, defaults 0
/// 10. GraceDays         — optional, defaults 0
class FeeStructureExcelService {
  static const String sheetYearly = 'Yearly';
  static const String sheetMonthly = 'Monthly';
  static const String sheetTermWise = 'Term-wise';
  static const String sheetCustom = 'Custom';
  static const String sheetInstructions = 'Instructions';

  /// Sheets that contain actual fee-structure data (skip the read-me).
  static const List<String> dataSheetNames = [
    sheetYearly,
    sheetMonthly,
    sheetTermWise,
    sheetCustom,
  ];

  /// Legacy single-sheet name kept as a fallback when parsing older files.
  static const String sheetName = 'FeeStructures';

  /// Class roster used to seed the sample template (LKG → XII).
  static const List<String> _allClasses = [
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
    'XII',
  ];

  static const List<String> headers = [
    'ClassNames',
    'StructureName',
    'Type',
    'AcademicYear',
    'TermName',
    'TermSequence',
    'Amount',
    'DueDate',
    'LateFeeAmount',
    'GraceDays',
  ];

  /// Generates a sample template (xlsx bytes) that the user can download,
  /// fill in, and upload back.
  ///
  /// The template contains four data sheets — one per fee-frequency type —
  /// each pre-populated with rows for **every class from LKG to XII** so
  /// admins can simply edit amounts/dates and re-upload the relevant tab.
  Uint8List buildTemplate({String academicYear = '2026-2027'}) {
    final xl = Excel.createExcel();
    // Drop default Sheet1.
    if (xl.sheets.containsKey('Sheet1') && xl.sheets.length > 0) {
      xl.delete('Sheet1');
    }

    _buildInstructionsSheet(xl);
    _buildYearlySheet(xl, academicYear: academicYear);
    _buildMonthlySheet(xl, academicYear: academicYear);
    _buildTermWiseSheet(xl, academicYear: academicYear);
    _buildCustomSheet(xl, academicYear: academicYear);

    final bytes = xl.encode();
    if (bytes == null) {
      throw Exception('Failed to encode Excel template');
    }
    return Uint8List.fromList(bytes);
  }

  // ─── per-sheet builders ────────────────────────────────────────────────

  void _writeHeaderRow(Sheet sheet) {
    for (var c = 0; c < headers.length; c++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(
        columnIndex: c,
        rowIndex: 0,
      ));
      cell.value = TextCellValue(headers[c]);
      cell.cellStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('#1F2937'),
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      );
    }
  }

  void _writeRow(Sheet sheet, int rowIndex, List<Object> row) {
    for (var c = 0; c < row.length; c++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(
        columnIndex: c,
        rowIndex: rowIndex,
      ));
      final v = row[c];
      if (v is num) {
        cell.value = DoubleCellValue(v.toDouble());
      } else {
        cell.value = TextCellValue(v.toString());
      }
    }
  }

  /// Picks a representative annual fee amount for a class band.
  /// Values are deliberately multiples of 12 so that monthly (÷12),
  /// term-wise (÷3) and custom (÷4) splits all come out as round figures.
  double _yearlyAmountFor(String klass) {
    switch (klass) {
      case 'LKG':
      case 'UKG':
      case 'KG':
        return 24000; // monthly 2,000 / term 8,000 / installment 6,000
      case 'I':
      case 'II':
      case 'III':
      case 'IV':
      case 'V':
        return 36000; // monthly 3,000 / term 12,000 / installment 9,000
      case 'VI':
      case 'VII':
      case 'VIII':
        return 48000; // monthly 4,000 / term 16,000 / installment 12,000
      case 'IX':
      case 'X':
        return 60000; // monthly 5,000 / term 20,000 / installment 15,000
      case 'XI':
      case 'XII':
        return 72000; // monthly 6,000 / term 24,000 / installment 18,000
      default:
        return 36000;
    }
  }

  String _yearStartFromAY(String ay) {
    final m = RegExp(r'^(\d{4})').firstMatch(ay);
    return m?.group(1) ?? DateTime.now().year.toString();
  }

  String _yearEndFromAY(String ay) {
    final m = RegExp(r'^(\d{4})').firstMatch(ay);
    final start = m == null ? DateTime.now().year : int.parse(m.group(1)!);
    return (start + 1).toString();
  }

  void _buildYearlySheet(Excel xl, {required String academicYear}) {
    final sheet = xl[sheetYearly];
    _writeHeaderRow(sheet);
    final endYear = _yearEndFromAY(academicYear);
    // Due date: end of the academic year (31-May of the next year, since
    // the AY runs June → May).
    final dueDate = '$endYear-05-31';
    var rowIdx = 1;
    for (final klass in _allClasses) {
      _writeRow(sheet, rowIdx++, [
        klass,
        'Class $klass Yearly $academicYear',
        'YEARLY',
        academicYear,
        'Annual Fee',
        1,
        _yearlyAmountFor(klass),
        dueDate,
        500,
        7,
      ]);
    }
  }

  void _buildMonthlySheet(Excel xl, {required String academicYear}) {
    final sheet = xl[sheetMonthly];
    _writeHeaderRow(sheet);
    final startYear = int.parse(_yearStartFromAY(academicYear));
    // Indian AY (school): June start, May end of next year.
    const monthLabels = [
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
      'January',
      'February',
      'March',
      'April',
      'May'
    ];
    final dueDates = List<String>.generate(12, (i) {
      // i=0 → June of startYear ; i=7 → January of startYear+1 ; i=11 → May of startYear+1
      final monthOffset = 6 + i; // 6..17
      final calendarMonth = ((monthOffset - 1) % 12) + 1;
      final year = monthOffset > 12 ? startYear + 1 : startYear;
      return '$year-${calendarMonth.toString().padLeft(2, '0')}-05';
    });

    var rowIdx = 1;
    for (final klass in _allClasses) {
      final monthly = (_yearlyAmountFor(klass) / 12).round();
      for (var i = 0; i < 12; i++) {
        _writeRow(sheet, rowIdx++, [
          klass,
          'Class $klass Monthly $academicYear',
          'MONTHLY',
          academicYear,
          monthLabels[i],
          i + 1,
          monthly,
          dueDates[i],
          100,
          5,
        ]);
      }
    }
  }

  void _buildTermWiseSheet(Excel xl, {required String academicYear}) {
    final sheet = xl[sheetTermWise];
    _writeHeaderRow(sheet);
    final startYear = int.parse(_yearStartFromAY(academicYear));
    // 10th of June (Term 1), October (Term 2), February next year (Term 3).
    final dueDates = [
      '$startYear-06-10',
      '$startYear-10-10',
      '${startYear + 1}-02-10',
    ];
    final termNames = [
      'Term 1 (Jun-Sep)',
      'Term 2 (Oct-Jan)',
      'Term 3 (Feb-May)'
    ];

    var rowIdx = 1;
    for (final klass in _allClasses) {
      final perTerm = (_yearlyAmountFor(klass) / 3).round();
      for (var i = 0; i < 3; i++) {
        _writeRow(sheet, rowIdx++, [
          klass,
          'Class $klass Termly $academicYear',
          'TERM_WISE',
          academicYear,
          termNames[i],
          i + 1,
          perTerm,
          dueDates[i],
          200,
          7,
        ]);
      }
    }
  }

  void _buildCustomSheet(Excel xl, {required String academicYear}) {
    final sheet = xl[sheetCustom];
    _writeHeaderRow(sheet);
    final startYear = int.parse(_yearStartFromAY(academicYear));
    // 4 quarterly installments — June 10, September 10, December 10, March 10.
    final dueDates = [
      '$startYear-06-10',
      '$startYear-09-10',
      '$startYear-12-10',
      '${startYear + 1}-03-10',
    ];

    var rowIdx = 1;
    for (final klass in _allClasses) {
      final perInstall = (_yearlyAmountFor(klass) / 4).round();
      for (var i = 0; i < 4; i++) {
        _writeRow(sheet, rowIdx++, [
          klass,
          'Class $klass Custom $academicYear',
          'CUSTOM',
          academicYear,
          'Installment ${i + 1}',
          i + 1,
          perInstall,
          dueDates[i],
          300,
          7,
        ]);
      }
    }
  }

  void _buildInstructionsSheet(Excel xl) {
    final sheet = xl[sheetInstructions];
    final lines = <String>[
      'FEE STRUCTURES — Excel template',
      '',
      'Academic year convention: June → May (next year). Yearly fees are due 31-May.',
      '',
      'This workbook contains four data sheets, one per fee-frequency type:',
      '   • Yearly      — one row per class (LKG → XII), due 31-May.',
      '   • Monthly     — 12 rows per class (June → May), due 5th of each month.',
      '   • Term-wise   — 3 rows per class (Term 1 / 2 / 3), due 10th of June / Oct / Feb.',
      '   • Custom      — 4 quarterly installments per class, due 10th of June / Sep / Dec / Mar.',
      '',
      'How to use:',
      '   1. Pick the sheet that matches the structure you want to create.',
      '   2. Adjust ClassNames, Amounts, and DueDates as needed.',
      '   3. Add or remove rows freely — rows sharing the same StructureName + AcademicYear',
      '      are grouped into one structure with multiple terms.',
      '   4. Upload the file from the Fee Structures screen — you will be asked which sheet(s)',
      '      to import.',
      '',
      'Column rules:',
      '   ClassNames     — comma-separated (e.g. "I,II,III"). Multiple classes share one structure.',
      '   StructureName  — display name for the structure (must be unique per AY).',
      '   Type           — YEARLY | MONTHLY | TERM_WISE | CUSTOM.',
      '   AcademicYear   — e.g. 2026-2027.',
      '   TermName       — "Annual Fee" / "April" / "Term 1" / "Installment 1" etc.',
      '   TermSequence   — 1, 2, 3 …  (terms are auto-renumbered after import).',
      '   Amount         — number, > 0.',
      '   DueDate        — yyyy-MM-dd  (must strictly increase within a structure).',
      '   LateFeeAmount  — optional, defaults to 0 (no late fee).',
      '   GraceDays      — optional, defaults to 0.',
      '',
      'Conflict handling on upload:',
      '   • Existing structures with the same StructureName + AcademicYear are skipped.',
      '   • To overwrite, delete the existing structure first or rename the one you upload.',
    ];
    for (var i = 0; i < lines.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(
        columnIndex: 0,
        rowIndex: i,
      ));
      cell.value = TextCellValue(lines[i]);
      if (i == 0) {
        cell.cellStyle = CellStyle(bold: true);
      }
    }
  }

  // ─── inspection helpers used by the upload flow ────────────────────────

  /// Returns the data-sheet names present in the uploaded workbook (preserves
  /// the original sheet order). Excludes the read-only Instructions sheet.
  List<String> listSheets(Uint8List bytes) {
    final xl = Excel.decodeBytes(bytes);
    return xl.tables.keys
        .where((k) =>
            k.toLowerCase() != sheetInstructions.toLowerCase() &&
            (xl.tables[k]?.maxRows ?? 0) > 0)
        .toList();
  }

  /// Parses uploaded xlsx bytes into a list of structures (with their terms).
  /// If [sheetNames] is provided, only those sheets are parsed and merged.
  /// Throws [FeeStructureExcelParseException] on validation errors.
  ParsedFeeStructureImport parse(
    Uint8List bytes, {
    List<String>? sheetNames,
  }) {
    final xl = Excel.decodeBytes(bytes);

    // Determine which sheet(s) to read.
    final List<MapEntry<String, Sheet>> targets;
    if (sheetNames != null && sheetNames.isNotEmpty) {
      targets = [];
      for (final name in sheetNames) {
        final sh = xl.tables[name];
        if (sh == null) {
          throw FeeStructureExcelParseException(
              'Sheet "$name" not found in the uploaded file.');
        }
        targets.add(MapEntry(name, sh));
      }
    } else {
      // Fallback for older single-sheet files.
      Sheet? sheet = xl.tables[sheetName];
      sheet ??= xl.tables.values.isNotEmpty ? xl.tables.values.first : null;
      if (sheet == null) {
        throw FeeStructureExcelParseException('No sheet found in Excel file.');
      }
      targets = [MapEntry(sheet.sheetName, sheet)];
    }

    // group key -> structure-in-progress (shared across all chosen sheets so
    // that re-using a structure name in two sheets merges into one).
    final byKey = <String, _StructureBuilder>{};
    final errors = <String>[];

    for (final entry in targets) {
      _parseSheetInto(
        sheetLabel: entry.key,
        sheet: entry.value,
        byKey: byKey,
        errors: errors,
      );
    }

    if (errors.isNotEmpty) {
      throw FeeStructureExcelParseException(
          'Found ${errors.length} problem(s):\n${errors.join("\n")}');
    }

    return _finaliseStructures(byKey);
  }

  void _parseSheetInto({
    required String sheetLabel,
    required Sheet sheet,
    required Map<String, _StructureBuilder> byKey,
    required List<String> errors,
  }) {
    if (sheet.maxRows < 2) {
      // Empty sheet — silently skip rather than fail the entire upload.
      return;
    }

    // Header validation (case-insensitive, trimmed).
    final headerRow = sheet.row(0);
    final actualHeaders = headerRow
        .map((c) => (c?.value?.toString() ?? '').trim().toLowerCase())
        .toList();
    final expected = headers.map((h) => h.toLowerCase()).toList();
    final headerIndex = <String, int>{};
    for (var i = 0; i < expected.length; i++) {
      final h = expected[i];
      final idx = actualHeaders.indexOf(h);
      if (idx < 0) {
        throw FeeStructureExcelParseException(
            'Sheet "$sheetLabel": missing required column "${headers[i]}". '
            'Expected headers: ${headers.join(", ")}.');
      }
      headerIndex[h] = idx;
    }

    for (var r = 1; r < sheet.maxRows; r++) {
      final row = sheet.row(r);
      // skip fully blank rows
      if (row.every((c) => (c?.value?.toString() ?? '').trim().isEmpty)) {
        continue;
      }
      try {
        final classes = _readString(row, headerIndex, 'classnames');
        final name = _readString(row, headerIndex, 'structurename');
        final typeRaw = _readString(row, headerIndex, 'type');
        final ay = _readString(row, headerIndex, 'academicyear');
        final termName = _readString(row, headerIndex, 'termname');
        final seq = _readInt(row, headerIndex, 'termsequence');
        final amount = _readNumber(row, headerIndex, 'amount');
        final due = _readDate(row, headerIndex, 'duedate');
        final lateFee =
            _readNumberOptional(row, headerIndex, 'latefeeamount') ?? 0;
        final grace = _readIntOptional(row, headerIndex, 'gracedays') ?? 0;

        if (name.isEmpty) {
          throw 'StructureName is required';
        }
        if (ay.isEmpty) {
          throw 'AcademicYear is required';
        }
        if (termName.isEmpty) {
          throw 'TermName is required';
        }
        if (amount <= 0) {
          throw 'Amount must be > 0';
        }

        final type = FeeStructureType.values.firstWhere(
          (t) => t.name == typeRaw.toUpperCase(),
          orElse: () => throw 'Invalid Type "$typeRaw" '
              '(expected: ${FeeStructureType.values.map((e) => e.name).join("|")})',
        );

        final classList = classes
            .split(RegExp(r'[,;|]'))
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
        if (classList.isEmpty) {
          throw 'ClassNames must list at least one class';
        }

        final key = '${name.toLowerCase()}__${ay.toLowerCase()}';
        final builder = byKey.putIfAbsent(
            key,
            () => _StructureBuilder(
                  name: name,
                  type: type,
                  academicYear: ay,
                  classes: <String>{},
                ));
        if (builder.type != type) {
          throw 'Conflicting Type for "$name" — '
              'rows mix ${builder.type.name} and ${type.name}';
        }
        builder.classes.addAll(classList);
        builder.terms.add(_TermDraft(
          termName: termName,
          sequence: seq,
          amount: amount,
          dueDate: due,
          lateFeeAmount: lateFee.toDouble(),
          graceDays: grace,
        ));
      } catch (e) {
        errors.add('[$sheetLabel] Row ${r + 1}: $e');
      }
    }
  }

  ParsedFeeStructureImport _finaliseStructures(
      Map<String, _StructureBuilder> byKey) {
    final errors = <String>[];
    final structures = <ParsedFeeStructure>[];
    for (final b in byKey.values) {
      // Sort terms by sequence
      b.terms.sort((a, c) => a.sequence.compareTo(c.sequence));

      // Validate strictly-increasing due dates within structure
      for (var i = 1; i < b.terms.length; i++) {
        if (!b.terms[i].dueDate.isAfter(b.terms[i - 1].dueDate)) {
          errors.add(
              '"${b.name}" / ${b.academicYear}: due dates must be strictly increasing — '
              '"${b.terms[i].termName}" is not after "${b.terms[i - 1].termName}".');
        }
      }

      final feeTerms = <FeeTerm>[];
      for (var i = 0; i < b.terms.length; i++) {
        final t = b.terms[i];
        feeTerms.add(FeeTerm(
          id: 'tmp-imp-$i-${DateTime.now().millisecondsSinceEpoch + i}',
          termName: t.termName,
          sequence: i + 1,
          amount: t.amount,
          dueDate: t.dueDate,
          lateFee: LateFeeRule(
            enabled: t.lateFeeAmount > 0,
            amount: t.lateFeeAmount,
            graceDays: t.graceDays,
          ),
        ));
      }
      structures.add(ParsedFeeStructure(
        name: b.name,
        academicYear: b.academicYear,
        type: b.type,
        classes: b.classes.toList()..sort(),
        terms: feeTerms,
        totalAmount: feeTerms.fold(0, (s, t) => s + t.amount),
      ));
    }

    if (errors.isNotEmpty) {
      throw FeeStructureExcelParseException(errors.join('\n'));
    }

    return ParsedFeeStructureImport(structures: structures);
  }

  // ───── helpers ─────
  String _readString(List<Data?> row, Map<String, int> idx, String header) {
    final i = idx[header]!;
    if (i >= row.length) return '';
    return (row[i]?.value?.toString() ?? '').trim();
  }

  int _readInt(List<Data?> row, Map<String, int> idx, String header) {
    final s = _readString(row, idx, header);
    final v = int.tryParse(s);
    if (v == null) throw '$header must be an integer (got "$s")';
    return v;
  }

  int? _readIntOptional(List<Data?> row, Map<String, int> idx, String header) {
    final s = _readString(row, idx, header);
    if (s.isEmpty) return null;
    return int.tryParse(s);
  }

  double _readNumber(List<Data?> row, Map<String, int> idx, String header) {
    final s = _readString(row, idx, header);
    final v = double.tryParse(s);
    if (v == null) throw '$header must be a number (got "$s")';
    return v;
  }

  double? _readNumberOptional(
      List<Data?> row, Map<String, int> idx, String header) {
    final s = _readString(row, idx, header);
    if (s.isEmpty) return null;
    return double.tryParse(s);
  }

  DateTime _readDate(List<Data?> row, Map<String, int> idx, String header) {
    final i = idx[header]!;
    if (i >= row.length || row[i] == null) {
      throw '$header is required';
    }
    final cell = row[i]!;
    final v = cell.value;
    if (v is DateCellValue) {
      return DateTime(v.year, v.month, v.day);
    }
    if (v is DateTimeCellValue) {
      return DateTime(v.year, v.month, v.day);
    }
    final s = v?.toString().trim() ?? '';
    if (s.isEmpty) throw '$header is required';
    // Accept yyyy-MM-dd, dd/MM/yyyy, dd-MM-yyyy
    final iso = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$').firstMatch(s);
    if (iso != null) {
      return DateTime(int.parse(iso.group(1)!), int.parse(iso.group(2)!),
          int.parse(iso.group(3)!));
    }
    final dmy = RegExp(r'^(\d{1,2})[/-](\d{1,2})[/-](\d{4})$').firstMatch(s);
    if (dmy != null) {
      return DateTime(int.parse(dmy.group(3)!), int.parse(dmy.group(2)!),
          int.parse(dmy.group(1)!));
    }
    final parsed = DateTime.tryParse(s);
    if (parsed != null) return DateTime(parsed.year, parsed.month, parsed.day);
    throw '$header must be a date (yyyy-MM-dd or dd/MM/yyyy), got "$s"';
  }
}

class _StructureBuilder {
  _StructureBuilder({
    required this.name,
    required this.type,
    required this.academicYear,
    required this.classes,
  });

  final String name;
  final FeeStructureType type;
  final String academicYear;
  final Set<String> classes;
  final List<_TermDraft> terms = [];
}

class _TermDraft {
  _TermDraft({
    required this.termName,
    required this.sequence,
    required this.amount,
    required this.dueDate,
    required this.lateFeeAmount,
    required this.graceDays,
  });

  final String termName;
  final int sequence;
  final double amount;
  final DateTime dueDate;
  final double lateFeeAmount;
  final int graceDays;
}

class ParsedFeeStructure {
  const ParsedFeeStructure({
    required this.name,
    required this.academicYear,
    required this.type,
    required this.classes,
    required this.terms,
    required this.totalAmount,
  });

  final String name;
  final String academicYear;
  final FeeStructureType type;
  final List<String> classes;
  final List<FeeTerm> terms;
  final double totalAmount;
}

class ParsedFeeStructureImport {
  const ParsedFeeStructureImport({required this.structures});
  final List<ParsedFeeStructure> structures;
}

class FeeStructureExcelParseException implements Exception {
  FeeStructureExcelParseException(this.message);
  final String message;
  @override
  String toString() => message;
}
