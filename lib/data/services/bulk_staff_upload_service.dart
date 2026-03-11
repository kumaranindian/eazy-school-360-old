import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:eazy_school_360/data/repositories/staff_management_repository.dart';
import 'package:eazy_school_360/domain/entities/staff_profile.dart';
import 'package:eazy_school_360/domain/entities/app_user.dart';

class BulkStaffUploadService {
  final StaffManagementRepository _staffRepository;

  BulkStaffUploadService(this._staffRepository);

  /// Generate Excel template for bulk staff upload with dropdowns
  Uint8List generateExcelTemplate() {
    final excel = Excel.createExcel();
    
    // Remove default sheet and create Staff Data sheet
    excel.delete('Sheet1');
    final sheet = excel['Staff Data'];
    
    // Define headers
    final headers = [
      'Name*',
      'Email*',
      'Department*',
      'Staff Type*',
      'Designation',
      'Phone Number',
      'Address',
      'Emergency Contact',
      'Joining Date (DD/MM/YYYY)',
    ];

    // Header style
    final headerStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#1E3A5F'),
      fontColorHex: ExcelColor.white,
      horizontalAlign: HorizontalAlign.Center,
    );

    final mandatoryStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#DC2626'),
      fontColorHex: ExcelColor.white,
      horizontalAlign: HorizontalAlign.Center,
    );

    // Add headers
    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = headers[i].endsWith('*') ? mandatoryStyle : headerStyle;
    }

    // Add example row
    final exampleData = [
      'John Doe',
      'john.doe@school.com',
      'Mathematics',
      'TEACHING',
      'Senior Teacher',
      '9876543210',
      '123 Main Street, City',
      '9876543211',
      '01/01/2024',
    ];

    for (int i = 0; i < exampleData.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 1));
      cell.value = TextCellValue(exampleData[i]);
    }

    // Create a separate sheet for dropdown values (Staff Types)
    final dropdownSheet = excel['Dropdown Values'];
    dropdownSheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).value = TextCellValue('Staff Types');
    dropdownSheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1)).value = TextCellValue('TEACHING');
    dropdownSheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 2)).value = TextCellValue('NON_TEACHING');

    // Add instructions sheet
    final instructionsSheet = excel['Instructions'];
    final instructions = [
      'BULK STAFF UPLOAD INSTRUCTIONS',
      '',
      '1. Fill in the "Staff Data" sheet with staff details',
      '2. Fields marked with * (red headers) are MANDATORY',
      '3. Staff Type must be one of: TEACHING or NON_TEACHING',
      '4. Date format: DD/MM/YYYY (e.g., 01/01/2024)',
      '5. Employee ID will be auto-generated',
      '6. A temporary password will be set for each staff member',
      '7. Email will be used as the login username',
      '',
      'COLUMN DESCRIPTIONS:',
      '- Name*: Full name of the staff member',
      '- Email*: Valid email address (used for login)',
      '- Department*: Department name (e.g., Mathematics, Science)',
      '- Staff Type*: TEACHING or NON_TEACHING',
      '- Designation: Job title (e.g., Senior Teacher, Lab Assistant)',
      '- Phone Number: Contact number',
      '- Address: Residential address',
      '- Emergency Contact: Emergency contact number',
      '- Joining Date: Date of joining in DD/MM/YYYY format',
    ];

    for (int i = 0; i < instructions.length; i++) {
      final cell = instructionsSheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: i));
      cell.value = TextCellValue(instructions[i]);
      if (i == 0) {
        cell.cellStyle = CellStyle(bold: true, fontSize: 14);
      }
    }

    // Set column widths for Staff Data sheet
    sheet.setColumnWidth(0, 25); // Name
    sheet.setColumnWidth(1, 30); // Email
    sheet.setColumnWidth(2, 20); // Department
    sheet.setColumnWidth(3, 15); // Staff Type
    sheet.setColumnWidth(4, 20); // Designation
    sheet.setColumnWidth(5, 15); // Phone
    sheet.setColumnWidth(6, 35); // Address
    sheet.setColumnWidth(7, 18); // Emergency Contact
    sheet.setColumnWidth(8, 20); // Joining Date

    // Set default sheet
    excel.setDefaultSheet('Staff Data');

    return Uint8List.fromList(excel.encode()!);
  }

  /// Generate CSV template for bulk staff upload (fallback)
  String generateCsvTemplate() {
    final headers = [
      'Name*',
      'Email*',
      'Department*',
      'Staff Type* (TEACHING/NON_TEACHING)',
      'Designation',
      'Phone Number',
      'Address',
      'Emergency Contact',
      'Joining Date (DD/MM/YYYY)',
    ];

    final exampleRow = [
      'John Doe',
      'john.doe@school.com',
      'Mathematics',
      'TEACHING',
      'Senior Teacher',
      '9876543210',
      '123 Main Street, City',
      '9876543211',
      '01/01/2024',
    ];

    final instructions = [
      '# INSTRUCTIONS:',
      '# 1. Fields marked with * are mandatory',
      '# 2. Staff Type must be one of: TEACHING, NON_TEACHING',
      '# 3. Date format: DD/MM/YYYY',
      '# 4. Employee ID will be auto-generated',
      '# 5. A temporary password will be set for each staff member',
      '# 6. Remove these instruction lines before uploading',
      '',
    ];

    final csvData = [
      headers,
      exampleRow,
    ];

    final csvString = const ListToCsvConverter().convert(csvData);
    return '${instructions.join('\n')}\n$csvString';
  }

  /// Parse file (Excel or CSV) and return list of staff data
  Future<List<Map<String, dynamic>>> parseFile(PlatformFile file) async {
    final extension = file.extension?.toLowerCase() ?? '';
    
    if (extension == 'xlsx' || extension == 'xls') {
      return _parseExcelFile(file);
    } else if (extension == 'csv') {
      return _parseCsvFile(file);
    } else {
      throw Exception('Unsupported file format. Please use .xlsx or .csv files.');
    }
  }

  /// Parse Excel file and return list of staff data
  Future<List<Map<String, dynamic>>> _parseExcelFile(PlatformFile file) async {
    try {
      Uint8List bytes;
      
      if (kIsWeb) {
        if (file.bytes == null) {
          throw Exception('File bytes are null');
        }
        bytes = file.bytes!;
      } else {
        if (file.path == null) {
          throw Exception('File path is null');
        }
        bytes = await File(file.path!).readAsBytes();
      }

      final excel = Excel.decodeBytes(bytes);
      
      // Find the Staff Data sheet or use the first sheet
      String? sheetName;
      if (excel.tables.containsKey('Staff Data')) {
        sheetName = 'Staff Data';
      } else {
        // Use first sheet that's not Instructions or Dropdown Values
        for (final name in excel.tables.keys) {
          if (name != 'Instructions' && name != 'Dropdown Values') {
            sheetName = name;
            break;
          }
        }
      }

      if (sheetName == null || excel.tables[sheetName] == null) {
        throw Exception('No valid data sheet found in Excel file');
      }

      final sheet = excel.tables[sheetName]!;
      final rows = sheet.rows;

      if (rows.length < 2) {
        throw Exception('Excel file must have at least a header row and one data row');
      }

      // Get headers from first row
      final headers = rows[0].map((cell) => cell?.value?.toString().trim() ?? '').toList();
      
      final List<Map<String, dynamic>> staffList = [];

      for (int i = 1; i < rows.length; i++) {
        final row = rows[i];
        if (row.isEmpty || row.every((cell) => cell?.value == null || cell!.value.toString().trim().isEmpty)) {
          continue; // Skip empty rows
        }

        final rowValues = row.map((cell) => cell?.value?.toString().trim() ?? '').toList();
        final staffData = _parseRow(headers, rowValues, i + 1);
        if (staffData != null) {
          staffList.add(staffData);
        }
      }

      return staffList;
    } catch (e) {
      throw Exception('Failed to parse Excel file: $e');
    }
  }

  /// Parse CSV file and return list of staff data
  Future<List<Map<String, dynamic>>> _parseCsvFile(PlatformFile file) async {
    try {
      String csvString;
      
      if (kIsWeb) {
        if (file.bytes == null) {
          throw Exception('File bytes are null');
        }
        csvString = utf8.decode(file.bytes!);
      } else {
        if (file.path == null) {
          throw Exception('File path is null');
        }
        final fileContent = await File(file.path!).readAsString();
        csvString = fileContent;
      }

      // Remove comment lines (starting with #)
      final lines = csvString.split('\n')
          .where((line) => !line.trim().startsWith('#') && line.trim().isNotEmpty)
          .toList();
      
      if (lines.isEmpty) {
        throw Exception('CSV file is empty');
      }

      final cleanedCsv = lines.join('\n');
      final csvData = const CsvToListConverter().convert(cleanedCsv);

      if (csvData.length < 2) {
        throw Exception('CSV file must have at least a header row and one data row');
      }

      final headers = csvData[0].map((e) => e.toString().trim()).toList();
      final dataRows = csvData.skip(1).toList();

      final List<Map<String, dynamic>> staffList = [];

      for (int i = 0; i < dataRows.length; i++) {
        final row = dataRows[i];
        if (row.isEmpty || row.every((cell) => cell.toString().trim().isEmpty)) {
          continue; // Skip empty rows
        }

        final staffData = _parseRow(headers, row, i + 2);
        if (staffData != null) {
          staffList.add(staffData);
        }
      }

      return staffList;
    } catch (e) {
      throw Exception('Failed to parse CSV file: $e');
    }
  }

  Map<String, dynamic>? _parseRow(List<dynamic> headers, List<dynamic> row, int rowNumber) {
    try {
      String getValue(String headerPrefix) {
        final index = headers.indexWhere((h) => h.toString().toLowerCase().startsWith(headerPrefix.toLowerCase()));
        if (index >= 0 && index < row.length) {
          return row[index].toString().trim();
        }
        return '';
      }

      final name = getValue('name');
      final email = getValue('email');
      final department = getValue('department');
      final staffTypeStr = getValue('staff type');

      // Validate mandatory fields
      if (name.isEmpty) {
        throw Exception('Name is required');
      }
      if (email.isEmpty) {
        throw Exception('Email is required');
      }
      if (department.isEmpty) {
        throw Exception('Department is required');
      }

      // Parse staff type
      StaffType staffType;
      switch (staffTypeStr.toUpperCase()) {
        case 'TEACHING':
          staffType = StaffType.TEACHING;
          break;
        case 'NON_TEACHING':
          staffType = StaffType.NON_TEACHING;
          break;
        default:
          staffType = StaffType.TEACHING;
      }

      // Parse joining date
      DateTime joiningDate = DateTime.now();
      final joiningDateStr = getValue('joining date');
      if (joiningDateStr.isNotEmpty) {
        try {
          final parts = joiningDateStr.split('/');
          if (parts.length == 3) {
            joiningDate = DateTime(
              int.parse(parts[2]),
              int.parse(parts[1]),
              int.parse(parts[0]),
            );
          }
        } catch (_) {
          // Use default date if parsing fails
        }
      }

      return {
        'name': name,
        'email': email,
        'department': department,
        'staffType': staffType,
        'designation': getValue('designation'),
        'phoneNumber': getValue('phone'),
        'address': getValue('address'),
        'emergencyContact': getValue('emergency'),
        'joiningDate': joiningDate,
        'rowNumber': rowNumber,
      };
    } catch (e) {
      debugPrint('Error parsing row $rowNumber: $e');
      return null;
    }
  }

  /// Process bulk upload - create staff members
  Future<BulkUploadResult> processBulkUpload({
    required String schoolId,
    required String adminUserId,
    required List<Map<String, dynamic>> staffDataList,
  }) async {
    final List<String> successfulUploads = [];
    final List<Map<String, dynamic>> failedUploads = [];

    for (final staffData in staffDataList) {
      try {
        final request = CreateStaffRequest(
          name: staffData['name'] as String,
          email: staffData['email'] as String,
          department: staffData['department'] as String,
          staffType: staffData['staffType'] as StaffType,
          designation: staffData['designation'] as String? ?? '',
          phoneNumber: staffData['phoneNumber'] as String? ?? '',
          address: staffData['address'] as String? ?? '',
          emergencyContact: staffData['emergencyContact'] as String? ?? '',
          joiningDate: staffData['joiningDate'] as DateTime,
          employeeId: '', // Auto-generate
        );

        final result = await _staffRepository.createStaff(schoolId, adminUserId, request);
        successfulUploads.add('${staffData['name']} (${result['employeeId']})');
      } catch (e) {
        failedUploads.add({
          'row': staffData['rowNumber'],
          'name': staffData['name'],
          'error': e.toString().replaceAll('Exception: ', ''),
        });
      }
    }

    return BulkUploadResult(
      totalProcessed: staffDataList.length,
      successCount: successfulUploads.length,
      failedCount: failedUploads.length,
      successfulUploads: successfulUploads,
      failedUploads: failedUploads,
    );
  }

}

class BulkUploadResult {
  final int totalProcessed;
  final int successCount;
  final int failedCount;
  final List<String> successfulUploads;
  final List<Map<String, dynamic>> failedUploads;

  BulkUploadResult({
    required this.totalProcessed,
    required this.successCount,
    required this.failedCount,
    required this.successfulUploads,
    required this.failedUploads,
  });

  bool get hasFailures => failedCount > 0;
  bool get allSuccessful => failedCount == 0 && successCount > 0;
}
