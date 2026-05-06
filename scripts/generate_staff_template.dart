import 'dart:io';
import 'package:excel/excel.dart';

void main() {
  final excel = Excel.createExcel();
  
  // Remove default sheet and create Staff Data sheet
  excel.delete('Sheet1');
  final sheet = excel['Staff Data'];
  
  // Define headers
  final headers = [
    'Name*',
    'Email*',
    'Staff Type*',
    'Designation',
    'Phone Number',
    'Address',
    'Emergency Contact',
    'Joining Date (DD/MM/YYYY)',
    'Birth Date (DD/MM/YYYY)',
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

  // Add 50 sample teachers with phone number +918508196981
  final designations = [
    'Senior Teacher', 'Teacher', 'Associate Teacher', 'Assistant Teacher',
    'Subject Teacher', 'Class Teacher', 'HOD', 'Vice Principal', 'Principal'
  ];
  final staffTypes = ['TEACHING', 'TEACHING', 'TEACHING', 'TEACHING', 'TEACHING', 'TEACHING', 'TEACHING', 'TEACHING', 'TEACHING'];
  
  for (int row = 0; row < 50; row++) {
    final designation = designations[row % designations.length];
    final staffType = staffTypes[row % staffTypes.length];
    final exampleData = [
      'Teacher ${row + 1}',
      'teacher${row + 1}@school.com',
      staffType,
      designation,
      '+918508196981',
      'Address ${row + 1}, City',
      '+918508196981',
      '${(row % 28 + 1).toString().padLeft(2, '0')}/01/2024',
      '${(row % 28 + 1).toString().padLeft(2, '0')}/${(row % 12 + 1).toString().padLeft(2, '0')}/1980',
    ];

    for (int i = 0; i < exampleData.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: row + 1));
      cell.value = TextCellValue(exampleData[i]);
    }
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
    '- Staff Type*: TEACHING or NON_TEACHING',
    '- Designation: Job title (e.g., Senior Teacher, Lab Assistant)',
    '- Phone Number: Contact number',
    '- Address: Residential address',
    '- Emergency Contact: Emergency contact number',
    '- Joining Date: Date of joining in DD/MM/YYYY format',
    '- Birth Date: Date of birth in DD/MM/YYYY format',
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
  sheet.setColumnWidth(2, 15); // Staff Type
  sheet.setColumnWidth(3, 20); // Designation
  sheet.setColumnWidth(4, 18); // Phone
  sheet.setColumnWidth(5, 35); // Address
  sheet.setColumnWidth(6, 18); // Emergency Contact
  sheet.setColumnWidth(7, 20); // Joining Date
  sheet.setColumnWidth(8, 20); // Birth Date

  // Set default sheet
  excel.setDefaultSheet('Staff Data');

  // Save to file
  final bytes = excel.encode()!;
  final file = File('assets/STAFF_UPLOAD_TEMPLATE.xlsx');
  file.writeAsBytesSync(bytes);
  print('Template generated successfully: ${file.path}');
}
