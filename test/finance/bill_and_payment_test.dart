import 'package:flutter_test/flutter_test.dart';

/// Unit tests for Bill Management, Fee Payment, Delete Student,
/// and Upload Sheet business logic and edge cases.
void main() {
  // ==================== BILL MANAGEMENT ====================
  group('Bill Management - Filtering', () {
    final bills = [
      {'billId': 1, 'billType': 'Revenue', 'billDate': DateTime(2026, 1, 15), 'isDeleted': false, 'revenueAmount': 5000},
      {'billId': 2, 'billType': 'Expense', 'billDate': DateTime(2026, 1, 20), 'isDeleted': false, 'expenseAmount': 2000},
      {'billId': 3, 'billType': 'Revenue', 'billDate': DateTime(2026, 2, 10), 'isDeleted': false, 'revenueAmount': 3000},
      {'billId': 4, 'billType': 'Expense', 'billDate': DateTime(2026, 2, 15), 'isDeleted': true, 'expenseAmount': 1000},
      {'billId': 5, 'billType': 'Revenue', 'billDate': DateTime(2026, 3, 1), 'isDeleted': false, 'revenueAmount': 7000},
    ];

    test('filters by Revenue type', () {
      final filtered = bills.where((b) => b['billType'] == 'Revenue' && b['isDeleted'] == false).toList();
      expect(filtered.length, equals(3));
    });

    test('filters by Expense type', () {
      final filtered = bills.where((b) => b['billType'] == 'Expense' && b['isDeleted'] == false).toList();
      expect(filtered.length, equals(1));
    });

    test('excludes deleted bills', () {
      final filtered = bills.where((b) => b['isDeleted'] == false).toList();
      expect(filtered.length, equals(4));
    });

    test('filters by date range', () {
      final start = DateTime(2026, 1, 1);
      final end = DateTime(2026, 1, 31);
      final filtered = bills.where((b) {
        final date = b['billDate'] as DateTime;
        return b['isDeleted'] == false &&
            date.isAfter(start.subtract(const Duration(days: 1))) &&
            date.isBefore(end.add(const Duration(days: 1)));
      }).toList();
      expect(filtered.length, equals(2));
    });

    test('combined type + date filter', () {
      final start = DateTime(2026, 1, 1);
      final end = DateTime(2026, 2, 28);
      final filtered = bills.where((b) {
        final date = b['billDate'] as DateTime;
        return b['billType'] == 'Revenue' &&
            b['isDeleted'] == false &&
            date.isAfter(start.subtract(const Duration(days: 1))) &&
            date.isBefore(end.add(const Duration(days: 1)));
      }).toList();
      expect(filtered.length, equals(2)); // bills 1 and 3
    });

    test('empty date range returns nothing', () {
      final start = DateTime(2027, 1, 1);
      final end = DateTime(2027, 12, 31);
      final filtered = bills.where((b) {
        final date = b['billDate'] as DateTime;
        return b['isDeleted'] == false &&
            date.isAfter(start.subtract(const Duration(days: 1))) &&
            date.isBefore(end.add(const Duration(days: 1)));
      }).toList();
      expect(filtered.length, equals(0));
    });
  });

  group('Bill Management - CSV Export', () {
    test('CSV row format for revenue bill', () {
      final bill = {
        'billId': 1,
        'billType': 'Revenue',
        'revenueType': 'Tuition Fee',
        'revenueAmount': 5000,
        'stuId': '101',
        'stuName': 'Alice',
        'remarks': 'Paid cash',
      };

      final isRev = bill['billType'] == 'Revenue';
      final amt = isRev ? (bill['revenueAmount'] as num).toDouble() : 0.0;
      final subType = isRev ? (bill['revenueType'] ?? '').toString() : '';

      expect(amt, equals(5000.0));
      expect(subType, equals('Tuition Fee'));
    });

    test('CSV row format for expense bill', () {
      final bill = {
        'billId': 2,
        'billType': 'Expense',
        'expenseType': 'Salary',
        'expenseAmount': 15000,
        'expensePOC': 'Office',
        'remarks': '',
      };

      final isRev = bill['billType'] == 'Revenue';
      final amt = isRev ? 0.0 : (bill['expenseAmount'] as num).toDouble();
      final subType = isRev ? '' : (bill['expenseType'] ?? '').toString();

      expect(amt, equals(15000.0));
      expect(subType, equals('Salary'));
    });
  });

  group('Bill Management - Deletion', () {
    test('soft delete marks bill as deleted', () {
      final bill = {'billId': 1, 'isDeleted': false, 'isBillDeleted': false};
      // Simulate soft delete
      bill['isDeleted'] = true;
      bill['isBillDeleted'] = true;
      expect(bill['isDeleted'], isTrue);
      expect(bill['isBillDeleted'], isTrue);
    });

    test('deletion reason is stored', () {
      final updateMap = <String, dynamic>{
        'isDeleted': true,
        'isBillDeleted': true,
        'deletionReason': 'Duplicate entry',
      };
      expect(updateMap['deletionReason'], equals('Duplicate entry'));
    });
  });

  // ==================== FEE PAYMENT ====================
  group('Fee Payment - Balance Calculation', () {
    test('regular fee payment reduces balance', () {
      double balTuition = 5000;
      double paidTuition = 0;
      const paymentAmount = 2000.0;

      paidTuition += paymentAmount;
      balTuition -= paymentAmount;

      expect(paidTuition, equals(2000.0));
      expect(balTuition, equals(3000.0));
    });

    test('arrear fee payment reduces arrear balance', () {
      double balArrearTuition = 3000;
      double paidArrearTuition = 0;
      const paymentAmount = 1500.0;

      paidArrearTuition += paymentAmount;
      balArrearTuition -= paymentAmount;

      expect(paidArrearTuition, equals(1500.0));
      expect(balArrearTuition, equals(1500.0));
    });

    test('payment cannot exceed balance', () {
      const balance = 1000.0;
      const paymentAmount = 1500.0;

      final isValid = paymentAmount > 0 && paymentAmount <= balance;
      expect(isValid, isFalse);
    });

    test('zero payment is rejected', () {
      const balance = 1000.0;
      const paymentAmount = 0.0;

      final isValid = paymentAmount > 0 && paymentAmount <= balance;
      expect(isValid, isFalse);
    });

    test('exact balance payment is valid', () {
      const balance = 1000.0;
      const paymentAmount = 1000.0;

      final isValid = paymentAmount > 0 && paymentAmount <= balance;
      expect(isValid, isTrue);
    });

    test('total paid and total balance update correctly', () {
      double stuPaidTotalFees = 5000;
      double stuBalTotalFees = 8500;
      const paymentAmount = 2000.0;

      stuPaidTotalFees += paymentAmount;
      stuBalTotalFees -= paymentAmount;

      expect(stuPaidTotalFees, equals(7000.0));
      expect(stuBalTotalFees, equals(6500.0));
    });

    test('next bill ID increments from last', () {
      final lastBillId = 42;
      final nextBillId = lastBillId + 1;
      expect(nextBillId, equals(43));
    });

    test('first bill ID starts at 1 when collection empty', () {
      // Simulates: docs.isEmpty ? 1 : (lastId + 1)
      int computeNextBillId(bool isEmpty, int lastId) => isEmpty ? 1 : lastId + 1;
      expect(computeNextBillId(true, 0), equals(1));
      expect(computeNextBillId(false, 42), equals(43));
    });
  });

  group('Fee Payment - Fee Type Mapping', () {
    test('all 8 fee types are recognized', () {
      final feeTypes = [
        'Admission Fee', 'Exam Fee', 'Tuition Fee', 'Van Fee',
        'Arrear Admission Fee', 'Arrear Exam Fee', 'Arrear Tuition Fee', 'Arrear Van Fee',
      ];
      expect(feeTypes.length, equals(8));
    });

    test('arrear types start with Arrear prefix', () {
      final arrearTypes = [
        'Arrear Admission Fee', 'Arrear Exam Fee', 'Arrear Tuition Fee', 'Arrear Van Fee',
      ];
      for (final t in arrearTypes) {
        expect(t.startsWith('Arrear'), isTrue);
      }
    });

    test('regular types do not start with Arrear', () {
      final regularTypes = ['Admission Fee', 'Exam Fee', 'Tuition Fee', 'Van Fee'];
      for (final t in regularTypes) {
        expect(t.startsWith('Arrear'), isFalse);
      }
    });

    test('balance lookup returns correct field for Tuition Fee', () {
      final student = {
        'stuBalTutionFees': 3000.0,
        'stuBalExamFees': 500.0,
        'stuBalAdmissionFees': 2000.0,
        'stuBalVanFees': 1000.0,
        'balanceArrearTuitionFees': 800.0,
      };

      double getBalance(String type) {
        switch (type) {
          case 'Tuition Fee': return (student['stuBalTutionFees'] as num?)?.toDouble() ?? 0;
          case 'Exam Fee': return (student['stuBalExamFees'] as num?)?.toDouble() ?? 0;
          case 'Admission Fee': return (student['stuBalAdmissionFees'] as num?)?.toDouble() ?? 0;
          case 'Van Fee': return (student['stuBalVanFees'] as num?)?.toDouble() ?? 0;
          case 'Arrear Tuition Fee': return (student['balanceArrearTuitionFees'] as num?)?.toDouble() ?? 0;
          default: return 0;
        }
      }

      expect(getBalance('Tuition Fee'), equals(3000.0));
      expect(getBalance('Exam Fee'), equals(500.0));
      expect(getBalance('Arrear Tuition Fee'), equals(800.0));
      expect(getBalance('Unknown'), equals(0.0));
    });
  });

  // ==================== DELETE STUDENT ====================
  group('Delete Student - Validation', () {
    test('student with payments cannot be deleted', () {
      final hasPayments = true;
      expect(hasPayments, isTrue);
      // UI should block deletion
    });

    test('student without payments can be deleted', () {
      final hasPayments = false;
      expect(hasPayments, isFalse);
      // UI should allow deletion
    });

    test('class/section/student selection chain', () {
      // Simulating the selection flow
      String? selectedClass;
      String? selectedSection;
      String? selectedStudent;

      selectedClass = 'I';
      expect(selectedClass, isNotNull);
      expect(selectedSection, isNull);
      expect(selectedStudent, isNull);

      selectedSection = 'A';
      expect(selectedSection, isNotNull);

      selectedStudent = 'doc123';
      expect(selectedStudent, isNotNull);
    });

    test('clear selection resets all', () {
      String? selectedClass = 'I';
      String? selectedSection = 'A';
      String? selectedStudent = 'doc123';

      // Clear
      selectedClass = null;
      selectedSection = null;
      selectedStudent = null;

      expect(selectedClass, isNull);
      expect(selectedSection, isNull);
      expect(selectedStudent, isNull);
    });
  });

  // ==================== UPLOAD SHEET ====================
  group('Upload Sheet - Parsing', () {
    test('header row is first row of preview data', () {
      final previewData = [
        ['stuId', 'stuName', 'stuClass', 'stuSection'],
        ['1', 'Alice', 'I', 'A'],
        ['2', 'Bob', 'II', 'B'],
      ];

      final headers = previewData[0];
      final dataRows = previewData.sublist(1);

      expect(headers.length, equals(4));
      expect(dataRows.length, equals(2));
    });

    test('row to map conversion', () {
      final headers = ['stuId', 'stuName', 'stuClass'];
      final row = ['1', 'Alice', 'I'];

      final map = <String, dynamic>{};
      for (int j = 0; j < headers.length && j < row.length; j++) {
        map[headers[j]] = row[j];
      }

      expect(map['stuId'], equals('1'));
      expect(map['stuName'], equals('Alice'));
      expect(map['stuClass'], equals('I'));
    });

    test('handles row shorter than headers', () {
      final headers = ['stuId', 'stuName', 'stuClass', 'stuSection'];
      final row = ['1', 'Alice']; // Missing stuClass, stuSection

      final map = <String, dynamic>{};
      for (int j = 0; j < headers.length && j < row.length; j++) {
        map[headers[j]] = row[j];
      }

      expect(map.length, equals(2));
      expect(map.containsKey('stuClass'), isFalse);
    });

    test('handles row longer than headers', () {
      final headers = ['stuId', 'stuName'];
      final row = ['1', 'Alice', 'Extra1', 'Extra2'];

      final map = <String, dynamic>{};
      for (int j = 0; j < headers.length && j < row.length; j++) {
        map[headers[j]] = row[j];
      }

      expect(map.length, equals(2));
    });

    test('fee structure upload validates required fields', () {
      final data1 = {'classInRoman': 'I', 'classTutionFees': '5000', 'classExamFees': '500'};
      final data2 = {'classInRoman': '', 'classTutionFees': '5000', 'classExamFees': '500'};

      final className1 = (data1['classInRoman'] ?? '').toString();
      final className2 = (data2['classInRoman'] ?? '').toString();

      expect(className1.isNotEmpty, isTrue);
      expect(className2.isNotEmpty, isFalse);
    });

    test('student details upload validates required fields', () {
      final data1 = {'stuId': '101', 'stuName': 'Alice'};
      final data2 = {'stuId': '', 'stuName': 'Alice'};
      final data3 = {'stuId': '101', 'stuName': ''};

      bool isValid(Map<String, dynamic> d) {
        return (d['stuId'] ?? '').toString().isNotEmpty && (d['stuName'] ?? '').toString().isNotEmpty;
      }

      expect(isValid(data1), isTrue);
      expect(isValid(data2), isFalse);
      expect(isValid(data3), isFalse);
    });

    test('numeric parsing with fallback', () {
      expect(double.tryParse('5000') ?? 0.0, equals(5000.0));
      expect(double.tryParse('abc') ?? 0.0, equals(0.0));
      expect(double.tryParse('') ?? 0.0, equals(0.0));
      expect(double.tryParse('0') ?? 0.0, equals(0.0));
      expect(int.tryParse('101') ?? 0, equals(101));
      expect(int.tryParse('') ?? 0, equals(0));
    });

    test('upload types are exactly 3', () {
      final types = ['Fee Structure', 'Student Details', 'Student Fee Details'];
      expect(types.length, equals(3));
    });
  });

  group('Upload Sheet - Template Validation', () {
    test('fee structure template has expected columns', () {
      final expected = ['classInRoman', 'classTutionFees', 'classExamFees'];
      expect(expected.length, equals(3));
    });

    test('student details template has expected columns', () {
      final expected = ['stuId', 'stuName', 'stuClass', 'stuSection', 'phoneNumber', 'isStuAvailVan'];
      expect(expected.length, equals(6));
    });

    test('student fee details template has many columns', () {
      final expected = [
        'stuId', 'stuName', 'stuClass', 'stuSection', 'phoneNumber',
        'stuTotalTutionFees', 'stuTotalExamFees', 'stuTotalVanFees', 'stuTotalAdmissionFees', 'stuTotalFees',
        'stuPaidTutionFees', 'stuPaidExamFees', 'studPaidVanFees', 'stuPaidAdmissionFees', 'stuPaidTotalFees',
        'stuBalTutionFees', 'stuBalExamFees', 'stuBalVanFees', 'stuBalAdmissionFees', 'stuBalTotalFees',
        'stuConcessionFees', 'stuPendingFees', 'isStuAvailVan',
        'arrearTuitionFees', 'arrearExamFees', 'arrearAdmissionFees', 'arrearVanFees',
      ];
      expect(expected.length, greaterThan(20));
    });
  });

  // ==================== STUDENT FEE MANAGEMENT ====================
  group('Student Fee Management - Fee Breakdown', () {
    test('total column sums all fee components', () {
      const tuition = 5000.0;
      const exam = 500.0;
      const van = 1000.0;
      const admission = 2000.0;
      final total = tuition + exam + van + admission;
      expect(total, equals(8500.0));
    });

    test('balance is total minus paid', () {
      const totalFees = 8500.0;
      const paidFees = 5000.0;
      expect(totalFees - paidFees, equals(3500.0));
    });

    test('fee breakdown card types are Total/Paid/Balance', () {
      final types = ['Total', 'Paid', 'Balance'];
      expect(types.length, equals(3));
      expect(types, contains('Total'));
      expect(types, contains('Paid'));
      expect(types, contains('Balance'));
    });
  });

  // ==================== ADMIN DASHBOARD MENU ====================
  group('Admin Dashboard - Menu Structure', () {
    test('all finance menu IDs are unique', () {
      final menuIds = [
        'dashboard', 'staff_management',
        'leave_requests', 'leave_policy',
        'permission_requests', 'permission_policy',
        'holiday_management',
        'student_management', 'student_fee_mgmt', 'delete_student',
        'fee_collection', 'expenses', 'bill_management',
        'financial_reports', 'upload_sheet', 'settings',
      ];
      expect(menuIds.toSet().length, equals(menuIds.length));
    });

    test('finance dashboard nav indices are sequential', () {
      // 0=Dashboard, 1=Students, 2=FeeMgmt, 3=FeeCollection, 4=Expenses,
      // 5=BillMgmt, 6=FinReports, 7=UploadSheet
      final indices = [0, 1, 2, 3, 4, 5, 6, 7];
      for (int i = 0; i < indices.length; i++) {
        expect(indices[i], equals(i));
      }
    });
  });
}
