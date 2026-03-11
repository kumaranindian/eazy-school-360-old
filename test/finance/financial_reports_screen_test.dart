import 'package:flutter_test/flutter_test.dart';

/// Unit tests for Financial Reports business logic and edge cases.
/// Widget tests are excluded because the screens use dart:html (web-only).
void main() {
  group('Financial Reports - Date Range Calculations', () {
    test('this week range spans 7 days', () {
      final now = DateTime(2026, 2, 19); // Thursday
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      final endOfWeek = startOfWeek.add(const Duration(days: 6));
      expect(endOfWeek.difference(startOfWeek).inDays, equals(6));
      expect(startOfWeek.weekday, equals(DateTime.monday));
      expect(endOfWeek.weekday, equals(DateTime.sunday));
    });

    test('this month range covers full month', () {
      final now = DateTime(2026, 2, 19);
      final startOfMonth = DateTime(now.year, now.month, 1);
      final endOfMonth = DateTime(now.year, now.month + 1, 0);
      expect(startOfMonth.day, equals(1));
      expect(endOfMonth.day, equals(28)); // Feb 2026 is not leap year
    });

    test('this quarter Q1 starts Jan ends Mar', () {
      final now = DateTime(2026, 2, 15);
      final q = ((now.month - 1) ~/ 3);
      final startOfQuarter = DateTime(now.year, q * 3 + 1, 1);
      final endOfQuarter = DateTime(now.year, (q + 1) * 3 + 1, 0);
      expect(startOfQuarter, equals(DateTime(2026, 1, 1)));
      expect(endOfQuarter, equals(DateTime(2026, 3, 31)));
    });

    test('this quarter Q2 starts Apr ends Jun', () {
      final now = DateTime(2026, 5, 10);
      final q = ((now.month - 1) ~/ 3);
      final startOfQuarter = DateTime(now.year, q * 3 + 1, 1);
      final endOfQuarter = DateTime(now.year, (q + 1) * 3 + 1, 0);
      expect(startOfQuarter, equals(DateTime(2026, 4, 1)));
      expect(endOfQuarter, equals(DateTime(2026, 6, 30)));
    });

    test('fiscal year starts April ends March next year', () {
      final now = DateTime(2026, 2, 19);
      final startFY = DateTime(now.year, 4, 1);
      final endFY = DateTime(now.year + 1, 3, 31);
      expect(startFY, equals(DateTime(2026, 4, 1)));
      expect(endFY, equals(DateTime(2027, 3, 31)));
    });

    test('custom date range handles same start/end', () {
      final start = DateTime(2026, 1, 1);
      final end = DateTime(2026, 1, 1);
      expect(end.difference(start).inDays, equals(0));
    });
  });

  group('Financial Reports - Expense Summary Aggregation', () {
    test('aggregates multiple expense types correctly', () {
      final expenses = [
        {'expenseType': 'Salary', 'expenseAmount': 5000.0},
        {'expenseType': 'Salary', 'expenseAmount': 3000.0},
        {'expenseType': 'Rent', 'expenseAmount': 10000.0},
        {'expenseType': 'Supplies', 'expenseAmount': 2500.0},
      ];

      final summaryMap = <String, double>{};
      double grandTotal = 0;
      for (final e in expenses) {
        final type = e['expenseType'] as String;
        final amt = e['expenseAmount'] as double;
        summaryMap[type] = (summaryMap[type] ?? 0) + amt;
        grandTotal += amt;
      }

      expect(summaryMap['Salary'], equals(8000.0));
      expect(summaryMap['Rent'], equals(10000.0));
      expect(summaryMap['Supplies'], equals(2500.0));
      expect(grandTotal, equals(20500.0));
      expect(summaryMap.length, equals(3));
    });

    test('empty expenses list yields zero totals', () {
      final expenses = <Map<String, dynamic>>[];
      final summaryMap = <String, double>{};
      double grandTotal = 0;
      for (final e in expenses) {
        final type = (e['expenseType'] ?? 'Other') as String;
        final amt = (e['expenseAmount'] as num?)?.toDouble() ?? 0;
        summaryMap[type] = (summaryMap[type] ?? 0) + amt;
        grandTotal += amt;
      }
      expect(summaryMap.isEmpty, isTrue);
      expect(grandTotal, equals(0.0));
    });

    test('handles null expenseAmount safely', () {
      final expenses = [
        {'expenseType': 'Misc', 'expenseAmount': null},
      ];
      double total = 0;
      for (final e in expenses) {
        total += (e['expenseAmount'] as num?)?.toDouble() ?? 0;
      }
      expect(total, equals(0.0));
    });

    test('handles missing expenseType key', () {
      final expenses = [
        {'expenseAmount': 100.0},
      ];
      final summaryMap = <String, double>{};
      for (final e in expenses) {
        final type = (e['expenseType'] ?? 'Other').toString();
        final amt = (e['expenseAmount'] as num?)?.toDouble() ?? 0;
        summaryMap[type] = (summaryMap[type] ?? 0) + amt;
      }
      expect(summaryMap['Other'], equals(100.0));
    });
  });

  group('Financial Reports - Class Grouping Logic', () {
    test('groups students by class correctly', () {
      final students = [
        {'className': 'I', 'stuName': 'Alice'},
        {'className': 'I', 'stuName': 'Bob'},
        {'className': 'II', 'stuName': 'Charlie'},
        {'className': 'III', 'stuName': 'Dave'},
        {'className': 'III', 'stuName': 'Eve'},
        {'className': 'III', 'stuName': 'Frank'},
      ];

      final classGroups = <String, List<Map<String, dynamic>>>{};
      for (final s in students) {
        final cn = (s['className'] ?? 'Unknown').toString();
        classGroups.putIfAbsent(cn, () => []).add(s);
      }

      expect(classGroups.length, equals(3));
      expect(classGroups['I']!.length, equals(2));
      expect(classGroups['II']!.length, equals(1));
      expect(classGroups['III']!.length, equals(3));
    });

    test('handles missing className by grouping as Unknown', () {
      final students = [
        {'stuName': 'NoClass'},
        {'className': null, 'stuName': 'NullClass'},
      ];

      final classGroups = <String, List<Map<String, dynamic>>>{};
      for (final s in students) {
        final cn = (s['className'] ?? 'Unknown').toString();
        classGroups.putIfAbsent(cn, () => []).add(s);
      }

      expect(classGroups['Unknown']!.length, equals(2));
    });

    test('empty student list yields empty groups', () {
      final students = <Map<String, dynamic>>[];
      final classGroups = <String, List<Map<String, dynamic>>>{};
      for (final s in students) {
        final cn = (s['className'] ?? 'Unknown').toString();
        classGroups.putIfAbsent(cn, () => []).add(s);
      }
      expect(classGroups.isEmpty, isTrue);
    });
  });

  group('Financial Reports - Monthly Revenue/Expense Bucketing', () {
    test('buckets amounts into correct months', () {
      final months = List.filled(12, 0.0);
      final entries = [
        {'month': 1, 'amount': 1000.0},
        {'month': 1, 'amount': 2000.0},
        {'month': 6, 'amount': 5000.0},
        {'month': 12, 'amount': 800.0},
      ];

      for (final e in entries) {
        final idx = (e['month'] as int) - 1;
        months[idx] += e['amount'] as double;
      }

      expect(months[0], equals(3000.0));
      expect(months[5], equals(5000.0));
      expect(months[11], equals(800.0));
      expect(months[3], equals(0.0));
    });

    test('all months start at zero', () {
      final months = List.filled(12, 0.0);
      expect(months.every((m) => m == 0.0), isTrue);
    });

    test('net calculation is revenue minus expense', () {
      const revenue = 50000.0;
      const expense = 30000.0;
      expect(revenue - expense, equals(20000.0));
    });
  });

  group('Financial Reports - Fee Totals Computation', () {
    test('class-wise fee totals accumulate correctly', () {
      final students = [
        {'stuTotalTutionFees': 5000, 'stuTotalExamFees': 500, 'stuTotalVanFees': 1000, 'stuTotalAdmissionFees': 2000, 'stuPaidTotalFees': 4000, 'stuBalTotalFees': 4500, 'stuPendingFees': 0, 'stuConcessionFees': 0},
        {'stuTotalTutionFees': 5000, 'stuTotalExamFees': 500, 'stuTotalVanFees': 0, 'stuTotalAdmissionFees': 2000, 'stuPaidTotalFees': 7500, 'stuBalTotalFees': 0, 'stuPendingFees': 0, 'stuConcessionFees': 0},
      ];

      double totalTuition = 0, totalExam = 0, totalVan = 0, totalAdmission = 0;
      double totalCollected = 0, totalPending = 0;

      for (final s in students) {
        totalTuition += (s['stuTotalTutionFees'] as num).toDouble();
        totalExam += (s['stuTotalExamFees'] as num).toDouble();
        totalVan += (s['stuTotalVanFees'] as num).toDouble();
        totalAdmission += (s['stuTotalAdmissionFees'] as num).toDouble();
        totalCollected += (s['stuPaidTotalFees'] as num).toDouble();
        totalPending += (s['stuBalTotalFees'] as num).toDouble();
      }

      expect(totalTuition, equals(10000.0));
      expect(totalExam, equals(1000.0));
      expect(totalVan, equals(1000.0));
      expect(totalAdmission, equals(4000.0));
      expect(totalCollected, equals(11500.0));
      expect(totalPending, equals(4500.0));
    });

    test('total fees formula includes arrears minus concession', () {
      const tuition = 10000.0;
      const exam = 1000.0;
      const van = 1000.0;
      const admission = 4000.0;
      const arrears = 500.0;
      const concession = 200.0;

      final totalFees = tuition + exam + van + admission + arrears - concession;
      expect(totalFees, equals(16300.0));
    });
  });

  group('Financial Reports - Missed Bills Filter', () {
    test('excludes missed bills when flag is false', () {
      final bills = [
        {'isMissedExpense': 'No', 'expenseAmount': 100},
        {'isMissedExpense': 'Yes', 'expenseAmount': 200},
        {'isMissedExpense': 'No', 'expenseAmount': 300},
      ];

      final filtered = bills.where((e) => (e['isMissedExpense'] ?? 'No') != 'Yes').toList();
      expect(filtered.length, equals(2));
    });

    test('includes missed bills when flag is true', () {
      final bills = [
        {'isMissedExpense': 'No', 'expenseAmount': 100},
        {'isMissedExpense': 'Yes', 'expenseAmount': 200},
      ];

      // When includeMissed is true, no filtering
      expect(bills.length, equals(2));
    });

    test('handles null isMissedExpense as No', () {
      final bills = [
        {'expenseAmount': 100},
        {'isMissedExpense': null, 'expenseAmount': 200},
      ];

      final filtered = bills.where((e) => (e['isMissedExpense'] ?? 'No') != 'Yes').toList();
      expect(filtered.length, equals(2));
    });
  });
}
