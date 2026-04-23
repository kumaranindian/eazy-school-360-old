import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../domain/entities/academic_year.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Aggregated stats for the finance dashboard
class FinanceDashboardStats {
  final int totalStudents;
  final int studentsWithOutstandingFees;
  final int fullyPaidStudents;
  final double totalFeesExpected;
  final double totalFeesCollected;
  final double totalOutstandingFees;
  final double totalArrears;
  final double totalExpenses;
  final double todayCollection;
  final double todayExpenses;
  final double monthCollection;
  final double monthExpenses;
  final int outstandingArrearsCount;
  final Map<String, double> classWiseCollection;
  final Map<String, double> classWiseExpected;
  final Map<String, double> monthlyCollection; // last 6 months

  const FinanceDashboardStats({
    this.totalStudents = 0,
    this.studentsWithOutstandingFees = 0,
    this.fullyPaidStudents = 0,
    this.totalFeesExpected = 0,
    this.totalFeesCollected = 0,
    this.totalOutstandingFees = 0,
    this.totalArrears = 0,
    this.totalExpenses = 0,
    this.todayCollection = 0,
    this.todayExpenses = 0,
    this.monthCollection = 0,
    this.monthExpenses = 0,
    this.outstandingArrearsCount = 0,
    this.classWiseCollection = const {},
    this.classWiseExpected = const {},
    this.monthlyCollection = const {},
  });

  double get netIncome => totalFeesCollected - totalExpenses;
  double get collectionRate => totalFeesExpected == 0 ? 0 : (totalFeesCollected / totalFeesExpected) * 100;
}

/// Represents a recent financial activity (payment or expense)
class RecentActivity {
  final String id;
  final String type; // 'payment' | 'expense'
  final String title;
  final String subtitle;
  final double amount;
  final DateTime date;

  const RecentActivity({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.date,
  });
}

class FinanceDashboardService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<FinanceDashboardStats> getDashboardStats(String schoolId) async {
    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final monthStart = DateTime(now.year, now.month, 1);

      // Run independent queries in parallel
      final results = await Future.wait([
        _getStudentStats(schoolId),
        _getFeeSummary(schoolId),
        _getBillsStats(schoolId, todayStart, monthStart),
        _getArrearsStats(schoolId),
        _getMonthlyCollection(schoolId, now),
      ]);

      final studentStats = results[0];
      final feeSummary = results[1];
      final billsStats = results[2];
      final arrearsStats = results[3];
      final monthlyCollection = results[4] as Map<String, double>;

      // Pull per-class student counts (from the students collection)
      final studentsByClass = Map<String, int>.from(
          studentStats['studentsByClass'] as Map? ?? const {});

      // Fetch fee structures and compute expected fees = sum over classes of
      // (totalFees for that class * number of students in the class).
      final feeStructures = await _getFeeStructuresByClass(schoolId);
      double expectedFromStructure = 0.0;
      final classWiseExpected = <String, double>{};
      studentsByClass.forEach((className, numStudents) {
        final perStudent = feeStructures[className] ?? 0.0;
        final classExpected = perStudent * numStudents;
        expectedFromStructure += classExpected;
        if (classExpected > 0) classWiseExpected[className] = classExpected;
      });

      // Actual collected comes from the bills transaction log (source of truth).
      final billsCollection = billsStats['totalCollection'] as double;
      final feeDetailsCollected = feeSummary['collectedFees'] as double;
      final actualCollected =
          billsCollection > feeDetailsCollected ? billsCollection : feeDetailsCollected;

      // Expected = sum of all fees (from fee structures * student counts).
      // Fall back to the student_fee_details total or at least the collected amount
      // if fee structures aren't configured yet.
      final feeDetailsExpected = feeSummary['totalFees'] as double;
      double actualExpected = expectedFromStructure;
      if (actualExpected < feeDetailsExpected) actualExpected = feeDetailsExpected;
      if (actualExpected < actualCollected) actualExpected = actualCollected;

      // Class-wise collection: prefer bills aggregation because
      // student_fee_details may be unpopulated.
      final classWiseFromBills =
          Map<String, double>.from(billsStats['classWiseCollection'] as Map);
      final classWiseFromDetails =
          Map<String, double>.from(feeSummary['classWiseCollection'] as Map);
      final mergedClassWise = <String, double>{};
      for (final e in classWiseFromBills.entries) {
        mergedClassWise[e.key] = e.value;
      }
      for (final e in classWiseFromDetails.entries) {
        // Use whichever number is larger (actual bills vs details)
        mergedClassWise[e.key] =
            (mergedClassWise[e.key] ?? 0.0) < e.value ? e.value : (mergedClassWise[e.key] ?? 0.0);
      }

      final outstandingFees = (actualExpected - actualCollected).clamp(0.0, double.infinity);
      final totalStudents = studentStats['totalStudents'] as int;

      return FinanceDashboardStats(
        totalStudents: totalStudents,
        studentsWithOutstandingFees: feeSummary['outstandingStudents'] as int,
        fullyPaidStudents: feeSummary['paidStudents'] as int,
        totalFeesExpected: actualExpected,
        totalFeesCollected: actualCollected,
        totalOutstandingFees: outstandingFees,
        totalArrears: arrearsStats['totalArrears'] as double,
        outstandingArrearsCount: arrearsStats['outstandingCount'] as int,
        totalExpenses: billsStats['totalExpenses'] as double,
        todayCollection: billsStats['todayCollection'] as double,
        todayExpenses: billsStats['todayExpenses'] as double,
        monthCollection: billsStats['monthCollection'] as double,
        monthExpenses: billsStats['monthExpenses'] as double,
        classWiseCollection: mergedClassWise,
        classWiseExpected: classWiseExpected,
        monthlyCollection: monthlyCollection,
      );
    } catch (e) {
      debugPrint('[FinanceDashboard] Error getting stats: $e');
      return const FinanceDashboardStats();
    }
  }

  Future<Map<String, dynamic>> _getStudentStats(String schoolId) async {
    try {
      debugPrint('[FinanceDashboard] Fetching students from: schools/$schoolId/students');
      // Don't filter by status server-side: legacy student records may not
      // have a `status` field at all, which would silently exclude them.
      final snap = await _firestore
          .collection('schools').doc(schoolId).collection('students')
          .get();
      debugPrint('[FinanceDashboard] Raw students doc count: ${snap.docs.length}');
      final studentsByClass = <String, int>{};
      int activeCount = 0;
      for (final d in snap.docs) {
        final data = d.data();
        // Skip system-seeded placeholder docs (legacy `_meta` seeds) so they
        // don't inflate the student count for freshly-provisioned schools.
        if (data['__system'] == true || data['isPlaceholder'] == true) continue;
        final status = data['status']?.toString().toUpperCase();
        // Treat missing status as ACTIVE (legacy records)
        if (status != null && status != 'ACTIVE') continue;
        activeCount++;
        final cls = (data['className'] ?? data['class'] ?? data['stuClass'])?.toString() ?? '';
        if (cls.isEmpty) continue;
        studentsByClass[cls] = (studentsByClass[cls] ?? 0) + 1;
      }
      debugPrint('[FinanceDashboard] Active students: $activeCount, byClass=$studentsByClass');

      // Fallback: if no students found at the expected path but bills reference
      // students, derive a count and class map from bills so the dashboard shows
      // something meaningful instead of zero.
      if (activeCount == 0) {
        debugPrint('[FinanceDashboard] No students at subcollection path; deriving from bills');
        final billsSnap = await _firestore
            .collection('schools').doc(schoolId).collection('bills')
            .where('billType', isEqualTo: 'Revenue')
            .get();
        final uniqueStudents = <String, String>{}; // stuId -> className
        for (final doc in billsSnap.docs) {
          final data = doc.data();
          final stuId = (data['stuId'] ?? data['studentId'])?.toString() ?? '';
          if (stuId.isEmpty) continue;
          final cls = (data['stuClass'] ?? data['className'])?.toString() ?? '';
          uniqueStudents[stuId] = cls;
        }
        activeCount = uniqueStudents.length;
        uniqueStudents.values.where((c) => c.isNotEmpty).forEach((c) {
          studentsByClass[c] = (studentsByClass[c] ?? 0) + 1;
        });
        debugPrint('[FinanceDashboard] Derived from bills: $activeCount students, byClass=$studentsByClass');
      }

      return {
        'totalStudents': activeCount,
        'studentsByClass': studentsByClass,
      };
    } catch (e, st) {
      debugPrint('[FinanceDashboard] student stats error: $e\n$st');
      return {'totalStudents': 0, 'studentsByClass': <String, int>{}};
    }
  }

  Future<Map<String, double>> _getFeeStructuresByClass(String schoolId) async {
    final result = <String, double>{};
    try {
      final snap = await _firestore
          .collection('schools').doc(schoolId).collection('fee_structures')
          .get();
      for (final doc in snap.docs) {
        final data = doc.data();
        final isActive = data['isActive'] as bool? ?? true;
        if (!isActive) continue;
        final className = data['className'] as String? ?? '';
        if (className.isEmpty) continue;
        final total = (data['totalFees'] as num?)?.toDouble() ??
            (((data['tuitionFees'] as num?)?.toDouble() ?? 0) +
                ((data['examFees'] as num?)?.toDouble() ?? 0) +
                ((data['admissionFees'] as num?)?.toDouble() ?? 0) +
                ((data['vanFees'] as num?)?.toDouble() ?? 0));
        // Keep the largest/latest value per class if multiple structures exist
        if ((result[className] ?? 0) < total) {
          result[className] = total;
        }
      }
    } catch (e) {
      debugPrint('[FinanceDashboard] fee structures error: $e');
    }
    return result;
  }

  Future<Map<String, dynamic>> _getFeeSummary(String schoolId) async {
    double totalFees = 0.0;
    double collectedFees = 0.0;
    double outstandingFees = 0.0;
    int paidStudents = 0;
    int outstandingStudents = 0;
    final classWise = <String, double>{};

    try {
      final snap = await _firestore
          .collection('schools').doc(schoolId).collection('student_fee_details')
          .get();

      for (final doc in snap.docs) {
        final data = doc.data();
        final total = (data['totalFees'] as num?)?.toDouble() ?? 0.0;
        final paid = (data['paidTotalFees'] as num?)?.toDouble() ?? 0.0;
        final balance = (data['balanceTotalFees'] as num?)?.toDouble() ?? (total - paid);
        final className = data['className'] as String? ?? 'Unknown';

        totalFees += total;
        collectedFees += paid;
        outstandingFees += balance;
        classWise[className] = (classWise[className] ?? 0.0) + paid;

        if (balance <= 0) {
          paidStudents++;
        } else {
          outstandingStudents++;
        }
      }
    } catch (e) {
      debugPrint('[FinanceDashboard] fee summary error: $e');
    }

    return {
      'totalFees': totalFees,
      'collectedFees': collectedFees,
      'outstandingFees': outstandingFees,
      'paidStudents': paidStudents,
      'outstandingStudents': outstandingStudents,
      'classWiseCollection': classWise,
    };
  }

  Future<Map<String, dynamic>> _getBillsStats(String schoolId, DateTime todayStart, DateTime monthStart) async {
    double totalExpenses = 0.0;
    double totalCollection = 0.0;
    double todayCollection = 0.0;
    double todayExpenses = 0.0;
    double monthCollection = 0.0;
    double monthExpenses = 0.0;
    final classWiseCollection = <String, double>{};

    // Dashboard defaults to the CURRENT academic year so historical years
    // (e.g. last year's paid fees) don't inflate current stats. Bills missing
    // an academicYear tag (legacy imports) are treated as current for
    // backward compatibility — migration is a separate concern.
    final currentAY = AcademicYear.getCurrentYearCode();

    try {
      final snap = await _firestore
          .collection('schools').doc(schoolId).collection('bills')
          .where('isDeleted', isEqualTo: false)
          .get();

      for (final doc in snap.docs) {
        final data = doc.data();
        final billType = data['billType'] as String? ?? '';
        final billDate = _parseDate(data['billDate']) ?? _parseDate(data['paymentDate']);
        final billAY = (data['academicYear'] as String?) ?? '';
        // Skip bills from other academic years (keep legacy untagged bills).
        if (billAY.isNotEmpty && billAY != currentAY) continue;

        if (billType == 'Expense') {
          // Existing expense records use `expenseAmount`; newer ones also write `amount`
          final amount = (data['expenseAmount'] as num?)?.toDouble() ??
              (data['amount'] as num?)?.toDouble() ??
              (data['totalAmount'] as num?)?.toDouble() ?? 0.0;
          totalExpenses += amount;
          if (billDate != null) {
            if (!billDate.isBefore(todayStart)) todayExpenses += amount;
            if (!billDate.isBefore(monthStart)) monthExpenses += amount;
          }
        } else if (billType == 'Revenue') {
          // Existing fee payment records use `revenueAmount`; newer ones also write `totalAmount`
          final amount = (data['revenueAmount'] as num?)?.toDouble() ??
              (data['totalAmount'] as num?)?.toDouble() ??
              (data['amount'] as num?)?.toDouble() ?? 0.0;
          totalCollection += amount;
          final className = (data['className'] ?? data['stuClass'])?.toString() ?? '';
          if (className.isNotEmpty) {
            classWiseCollection[className] = (classWiseCollection[className] ?? 0.0) + amount;
          }
          if (billDate != null) {
            if (!billDate.isBefore(todayStart)) todayCollection += amount;
            if (!billDate.isBefore(monthStart)) monthCollection += amount;
          }
        }
      }
    } catch (e) {
      debugPrint('[FinanceDashboard] bills stats error: $e');
    }

    return {
      'totalExpenses': totalExpenses,
      'totalCollection': totalCollection,
      'todayCollection': todayCollection,
      'todayExpenses': todayExpenses,
      'monthCollection': monthCollection,
      'monthExpenses': monthExpenses,
      'classWiseCollection': classWiseCollection,
    };
  }

  Future<Map<String, dynamic>> _getArrearsStats(String schoolId) async {
    double totalArrears = 0.0;
    int outstandingCount = 0;

    try {
      final snap = await _firestore
          .collection('schools').doc(schoolId).collection('arrears')
          .get();

      for (final doc in snap.docs) {
        final data = doc.data();
        final status = data['status'] as String? ?? 'PENDING';
        final amount = (data['pendingAmount'] as num?)?.toDouble() ??
            (data['amount'] as num?)?.toDouble() ?? 0.0;
        if (status == 'PENDING' || status == 'PARTIALLY_PAID') {
          totalArrears += amount;
          outstandingCount++;
        }
      }
    } catch (e) {
      debugPrint('[FinanceDashboard] arrears stats error: $e');
    }

    return {'totalArrears': totalArrears, 'outstandingCount': outstandingCount};
  }

  Future<Map<String, double>> _getMonthlyCollection(String schoolId, DateTime now) async {
    final result = <String, double>{};
    final sixMonthsAgo = DateTime(now.year, now.month - 5, 1);

    try {
      final snap = await _firestore
          .collection('schools').doc(schoolId).collection('bills')
          .where('billType', isEqualTo: 'Revenue')
          .where('isDeleted', isEqualTo: false)
          .where('billDate', isGreaterThanOrEqualTo: Timestamp.fromDate(sixMonthsAgo))
          .get();

      // Initialize last 6 months with 0
      for (int i = 5; i >= 0; i--) {
        final d = DateTime(now.year, now.month - i, 1);
        final key = '${d.year}-${d.month.toString().padLeft(2, '0')}';
        result[key] = 0.0;
      }

      for (final doc in snap.docs) {
        final data = doc.data();
        final amount = (data['revenueAmount'] as num?)?.toDouble() ??
            (data['totalAmount'] as num?)?.toDouble() ??
            (data['amount'] as num?)?.toDouble() ?? 0.0;
        final date = _parseDate(data['billDate']);
        if (date == null) continue;
        final key = '${date.year}-${date.month.toString().padLeft(2, '0')}';
        if (result.containsKey(key)) {
          result[key] = (result[key] ?? 0.0) + amount;
        }
      }
    } catch (e) {
      debugPrint('[FinanceDashboard] monthly collection error: $e');
    }

    return result;
  }

  Future<List<RecentActivity>> getRecentActivity(String schoolId, {int limit = 8}) async {
    final activities = <RecentActivity>[];

    try {
      final snap = await _firestore
          .collection('schools').doc(schoolId).collection('bills')
          .where('isDeleted', isEqualTo: false)
          .orderBy('billDate', descending: true)
          .limit(limit)
          .get();

      for (final doc in snap.docs) {
        final data = doc.data();
        final billType = data['billType'] as String? ?? '';
        final date = _parseDate(data['billDate']) ?? _parseDate(data['createdAt']) ?? DateTime.now();

        if (billType == 'Revenue') {
          final amount = (data['revenueAmount'] as num?)?.toDouble() ??
              (data['totalAmount'] as num?)?.toDouble() ??
              (data['amount'] as num?)?.toDouble() ?? 0.0;
          final studentName = (data['studentName'] ?? data['stuName'])?.toString() ?? 'Fee Payment';
          final className = (data['className'] ?? data['stuClass'])?.toString() ?? '-';
          final revenueType = (data['revenueType'] as String?) ?? 'Fee Payment';
          final paymentMode = (data['paymentMode'] as String?) ?? 'Cash';
          activities.add(RecentActivity(
            id: doc.id,
            type: 'payment',
            title: studentName,
            subtitle: 'Class $className • $revenueType • $paymentMode',
            amount: amount,
            date: date,
          ));
        } else if (billType == 'Expense') {
          final amount = (data['expenseAmount'] as num?)?.toDouble() ??
              (data['amount'] as num?)?.toDouble() ??
              (data['totalAmount'] as num?)?.toDouble() ?? 0.0;
          final description = (data['description'] ?? data['expenseDesc'])?.toString();
          final expenseType = (data['expenseType'] ?? data['categoryName'])?.toString() ?? 'General';
          activities.add(RecentActivity(
            id: doc.id,
            type: 'expense',
            title: (description != null && description.isNotEmpty) ? description : expenseType,
            subtitle: expenseType,
            amount: amount,
            date: date,
          ));
        }
      }
    } catch (e) {
      debugPrint('[FinanceDashboard] recent activity error: $e');
    }

    return activities;
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}

// Providers
final financeDashboardServiceProvider = Provider<FinanceDashboardService>((ref) {
  return FinanceDashboardService();
});

final financeDashboardStatsProvider =
    FutureProvider.family<FinanceDashboardStats, String>((ref, schoolId) {
  final service = ref.watch(financeDashboardServiceProvider);
  return service.getDashboardStats(schoolId);
});

final financeRecentActivityProvider =
    FutureProvider.family<List<RecentActivity>, String>((ref, schoolId) {
  final service = ref.watch(financeDashboardServiceProvider);
  return service.getRecentActivity(schoolId);
});
