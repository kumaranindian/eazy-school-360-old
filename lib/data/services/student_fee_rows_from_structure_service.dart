import 'dart:typed_data';

import 'package:excel/excel.dart';

import '../../domain/entities/fee_structure_v2.dart';
import '../../domain/entities/fee_payment.dart';
import '../../domain/entities/student.dart';
import 'fee_structure_to_payment_mapper.dart';

/// Generates an Excel sheet containing one row per **student‑term** for
/// bulk fee payment upload. The schema mirrors the existing payment flow:
///
/// Columns (header row is required, must match exactly):
///  1. StudentId        — internal student ID
///  2. StudentName      — display name
///  3. ClassName        — e.g. "IX"
///  4. Section          — e.g. "A"
///  5. AcademicYear     — e.g. "2026-27"
///  6. TermName         — e.g. "June" / "Term 1" / "Annual"
///   7. DueDate         — yyyy-MM-dd
///  8. AdmissionFee     — optional, defaults 0
///  9. TuitionFee       — optional, defaults 0
/// 10. ExamFee          — optional, defaults 0
/// 11. VanFee           — optional, defaults 0
/// 12. Arrears          — optional, defaults 0
/// 13. TotalAmount      — sum of the above components (must be > 0)
/// 14. PaymentMode      — CASH | UPI | CARD | CHEQUE | BANK_TRANSFER | OTHER
/// 15. Remarks          — optional free‑text
///
/// The service iterates over the provided students and the structure's terms,
/// maps each term to a component using FeeStructureToPaymentMapper, and writes
/// a row. The output can be downloaded and later uploaded via the existing
/// bulk‑payment flow (or a new one that reads this schema).
class StudentFeeRowsFromStructureService {
  static const List<String> headers = [
    'StudentId',
    'StudentName',
    'ClassName',
    'Section',
    'AcademicYear',
    'TermName',
    'DueDate',
    'AdmissionFee',
    'TuitionFee',
    'ExamFee',
    'VanFee',
    'Arrears',
    'TotalAmount',
    'PaymentMode',
    'Remarks',
  ];

  /// Generates an Excel workbook with a single sheet containing one row per
  /// student‑term for the given structure and student list.
  Uint8List build({
    required FeeStructureV2 structure,
    required List<Student> students,
    PaymentMode defaultPaymentMode = PaymentMode.CASH,
    String? defaultRemarks,
  }) {
    final xl = Excel.createExcel();
    // Remove default Sheet1
    if (xl.sheets.containsKey('Sheet1') && xl.sheets.length > 0) {
      xl.delete('Sheet1');
    }
    final sheet = xl['StudentFeeRows'];

    // Header row
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

    var rowIdx = 1;
    for (final student in students) {
      for (final term in structure.terms) {
        final components = FeeStructureToPaymentMapper.mapTermToComponents(term);
        final admission = components['admissionFeePaid'] ?? 0.0;
        final tuition = components['tuitionFeePaid'] ?? 0.0;
        final exam = components['examFeePaid'] ?? 0.0;
        final van = components['vanFeePaid'] ?? 0.0;
        final total = term.amount;

        final row = <Object>[
          student.id,
          student.name,
          student.className,
          student.section,
          structure.academicYear,
          term.termName,
          _formatDate(term.dueDate),
          admission,
          tuition,
          exam,
          van,
          0.0, // Arrears always 0 for generated rows
          total,
          defaultPaymentMode.name,
          defaultRemarks ?? '',
        ];

        _writeRow(sheet, rowIdx, row);
        rowIdx++;
      }
    }

    final bytes = xl.encode();
    if (bytes == null) {
      throw Exception('Failed to encode student fee rows Excel');
    }
    return Uint8List.fromList(bytes);
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

  String _formatDate(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}
