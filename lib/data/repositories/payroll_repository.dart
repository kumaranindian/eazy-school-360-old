import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:eazy_school_360/domain/entities/payroll.dart';
import 'package:eazy_school_360/domain/entities/staff_profile.dart';

class PayrollRepository {
  final FirebaseFirestore _firestore;

  PayrollRepository(this._firestore);

  // ══════════════════════════════════════════════════════════════════
  // PAYROLL CONFIG (salary structure per staff)
  // Path: schools/{schoolId}/payrollConfig/{staffId}
  // ══════════════════════════════════════════════════════════════════

  /// Get payroll config for a specific staff member
  Future<PayrollConfig?> getPayrollConfig(String schoolId, String staffId) async {
    try {
      final doc = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('payrollConfig')
          .doc(staffId)
          .get();
      if (!doc.exists) return null;
      return PayrollConfig.fromFirestore(doc);
    } catch (e) {
      print('Error getting payroll config: $e');
      return null;
    }
  }

  /// Get all payroll configs for a school
  Stream<List<PayrollConfig>> getAllPayrollConfigs(String schoolId) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('payrollConfig')
        .orderBy('staffName')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PayrollConfig.fromFirestore(doc))
            .toList());
  }

  /// Save/update payroll config for a staff member
  Future<void> savePayrollConfig(String schoolId, PayrollConfig config) async {
    final recalculated = PayrollConfig.recalculate(config);
    await _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('payrollConfig')
        .doc(config.staffId)
        .set(recalculated.toFirestore(), SetOptions(merge: true));
  }

  /// Delete payroll config
  Future<void> deletePayrollConfig(String schoolId, String staffId) async {
    await _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('payrollConfig')
        .doc(staffId)
        .delete();
  }

  // ══════════════════════════════════════════════════════════════════
  // PAYROLL RECORDS (monthly processed payroll)
  // Path: schools/{schoolId}/payrollRecords/{recordId}
  // ══════════════════════════════════════════════════════════════════

  /// Get all payroll records for a month/year (Admin view)
  Stream<List<PayrollRecord>> getMonthlyPayroll(String schoolId, int month, int year) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('payrollRecords')
        .where('month', isEqualTo: month)
        .where('year', isEqualTo: year)
        .orderBy('staffName')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PayrollRecord.fromFirestore(doc))
            .toList());
  }

  /// Get payroll records for a specific staff member (Teacher view - only approved)
  Stream<List<PayrollRecord>> getStaffPayrollRecords(String schoolId, String userId) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('payrollRecords')
        .where('userId', isEqualTo: userId)
        .where('status', whereIn: ['APPROVED', 'PAID'])
        .orderBy('year', descending: true)
        .orderBy('month', descending: true)
        .snapshots()
        .handleError((error) {
          print('Error getting staff payroll records: $error');
        })
        .map((snapshot) => snapshot.docs
            .map((doc) => PayrollRecord.fromFirestore(doc))
            .toList());
  }

  /// Check if payroll already exists for a staff member in a given month/year
  Future<PayrollRecord?> getExistingPayrollRecord(
      String schoolId, String staffId, int month, int year) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('payrollRecords')
          .where('staffId', isEqualTo: staffId)
          .where('month', isEqualTo: month)
          .where('year', isEqualTo: year)
          .limit(1)
          .get();
      if (snapshot.docs.isEmpty) return null;
      return PayrollRecord.fromFirestore(snapshot.docs.first);
    } catch (e) {
      print('Error checking existing payroll: $e');
      return null;
    }
  }

  // ══════════════════════════════════════════════════════════════════
  // LEAVE DATA HELPERS
  // ══════════════════════════════════════════════════════════════════

  /// Fetch approved leaves for a staff member that fall within a specific month
  Future<List<Map<String, dynamic>>> _getApprovedLeavesForMonth(
      String schoolId, String staffId, String applicantId, int month, int year) async {
    final monthStart = DateTime(year, month, 1);
    final monthEnd = DateTime(year, month + 1, 0, 23, 59, 59); // last day of month

    // Query by applicantId (teacher UID) with APPROVED status
    final snapshot = await _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('leaves')
        .where('applicantId', isEqualTo: applicantId)
        .where('status', isEqualTo: 'APPROVED')
        .get();

    final leavesInMonth = <Map<String, dynamic>>[];
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final startDate = (data['startDate'] as Timestamp).toDate();
      final endDate = (data['endDate'] as Timestamp).toDate();
      // Check overlap with the payroll month
      if (startDate.isBefore(monthEnd.add(const Duration(days: 1))) &&
          endDate.isAfter(monthStart.subtract(const Duration(days: 1)))) {
        // Calculate days that fall within this month
        final effectiveStart = startDate.isBefore(monthStart) ? monthStart : startDate;
        final effectiveEnd = endDate.isAfter(monthEnd) ? monthEnd : endDate;
        final daysInMonth = effectiveEnd.difference(effectiveStart).inDays + 1;
        leavesInMonth.add({
          ...data,
          'daysInMonth': daysInMonth,
          'leaveId': doc.id,
        });
      }
    }

    // Also query by staffId for legacy data
    final snapshot2 = await _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('leaves')
        .where('staffId', isEqualTo: staffId)
        .where('status', isEqualTo: 'APPROVED')
        .get();

    final existingIds = leavesInMonth.map((l) => l['leaveId']).toSet();
    for (final doc in snapshot2.docs) {
      if (existingIds.contains(doc.id)) continue;
      final data = doc.data();
      final startDate = (data['startDate'] as Timestamp).toDate();
      final endDate = (data['endDate'] as Timestamp).toDate();
      if (startDate.isBefore(monthEnd.add(const Duration(days: 1))) &&
          endDate.isAfter(monthStart.subtract(const Duration(days: 1)))) {
        final effectiveStart = startDate.isBefore(monthStart) ? monthStart : startDate;
        final effectiveEnd = endDate.isAfter(monthEnd) ? monthEnd : endDate;
        final daysInMonth = effectiveEnd.difference(effectiveStart).inDays + 1;
        leavesInMonth.add({
          ...data,
          'daysInMonth': daysInMonth,
          'leaveId': doc.id,
        });
      }
    }

    return leavesInMonth;
  }

  /// Fetch leave balances for a staff member
  Future<List<Map<String, dynamic>>> _getLeaveBalances(
      String schoolId, String staffId) async {
    final currentYear = DateTime.now().year;
    final currentMonth = DateTime.now().month;
    final academicYear = currentMonth >= 6
        ? '$currentYear-${currentYear + 1}'
        : '${currentYear - 1}-$currentYear';

    final snapshot = await _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('leaveBalances')
        .where('staffId', isEqualTo: staffId)
        .where('academicYear', isEqualTo: academicYear)
        .get();

    return snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList();
  }

  /// Fetch leave type configs for the school (to know isPaid flag)
  Future<Map<String, Map<String, dynamic>>> _getLeaveTypeConfigs(String schoolId) async {
    final snapshot = await _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('leaveTypes')
        .where('isActive', isEqualTo: true)
        .get();

    final map = <String, Map<String, dynamic>>{};
    for (final doc in snapshot.docs) {
      map[doc.id] = {...doc.data(), 'id': doc.id};
    }
    return map;
  }

  // ══════════════════════════════════════════════════════════════════
  // PROCESS PAYROLL
  // ══════════════════════════════════════════════════════════════════

  /// Process payroll for a single staff member for a given month
  /// Automatically fetches leave data and calculates paid/unpaid/LOP
  Future<String> processPayroll({
    required String schoolId,
    required String adminUserId,
    required PayrollConfig config,
    required StaffProfile staff,
    required int month,
    required int year,
    int workingDays = 26,
    Map<String, Map<String, dynamic>>? leaveTypeConfigs,
  }) async {
    // Check if already processed
    final existing = await getExistingPayrollRecord(schoolId, config.staffId, month, year);
    if (existing != null && existing.status != PayrollStatus.DRAFT && existing.status != PayrollStatus.REJECTED) {
      throw Exception('Payroll already processed for ${config.staffName} for ${DateFormat('MMMM yyyy').format(DateTime(year, month))}');
    }

    final recalculated = PayrollConfig.recalculate(config);

    // ── Fetch leave data ──
    final leaveConfigs = leaveTypeConfigs ?? await _getLeaveTypeConfigs(schoolId);
    final approvedLeaves = await _getApprovedLeavesForMonth(
        schoolId, config.staffId, staff.userId, month, year);
    final leaveBalances = await _getLeaveBalances(schoolId, config.staffId);

    // Build a map of leaveTypeId -> balance data
    final balanceMap = <String, Map<String, dynamic>>{};
    for (final b in leaveBalances) {
      balanceMap[b['leaveTypeId'] as String] = b;
    }

    // ── Calculate leave breakdown per type ──
    final leaveByType = <String, int>{}; // leaveTypeId -> days taken this month
    int totalLeaveDaysThisMonth = 0;

    for (final leave in approvedLeaves) {
      final typeId = leave['leaveTypeId'] as String? ?? '';
      final daysInMonth = leave['daysInMonth'] as int? ?? 0;
      leaveByType[typeId] = (leaveByType[typeId] ?? 0) + daysInMonth;
      totalLeaveDaysThisMonth += daysInMonth;
    }

    // ── Determine paid vs unpaid ──
    int totalPaidLeaveDays = 0;
    int totalUnpaidLeaveDays = 0;
    int totalLeaveAllowed = 0;
    int totalLeaveUsedYTD = 0;
    final breakdownItems = <LeaveBreakdownItem>[];

    for (final entry in leaveByType.entries) {
      final typeId = entry.key;
      final daysThisMonth = entry.value;
      final typeConfig = leaveConfigs[typeId];
      final balance = balanceMap[typeId];

      final isPaid = typeConfig?['isPaid'] as bool? ?? true;
      final allowed = balance?['totalAllowed'] as int? ?? (typeConfig?['annualQuota'] as int? ?? 0);
      final used = balance?['used'] as int? ?? 0;
      final available = balance?['available'] as int? ?? 0;
      final typeName = typeConfig?['name'] as String? ??
          (balance?['leaveTypeCode'] as String? ?? typeId);
      final typeCode = typeConfig?['code'] as String? ??
          (balance?['leaveTypeCode'] as String? ?? '');

      totalLeaveAllowed += allowed;
      totalLeaveUsedYTD += used;

      if (isPaid && available >= 0) {
        // Leave is paid and within quota
        totalPaidLeaveDays += daysThisMonth;
      } else {
        // Unpaid leave type OR leave balance exhausted
        totalUnpaidLeaveDays += daysThisMonth;
      }

      breakdownItems.add(LeaveBreakdownItem(
        leaveTypeName: typeName,
        leaveTypeCode: typeCode,
        isPaid: isPaid,
        allowed: allowed,
        used: used,
        takenThisMonth: daysThisMonth,
        balance: available,
      ));
    }

    // Also add leave types with 0 days this month (for context)
    for (final balance in leaveBalances) {
      final typeId = balance['leaveTypeId'] as String;
      if (!leaveByType.containsKey(typeId)) {
        final typeConfig = leaveConfigs[typeId];
        final allowed = balance['totalAllowed'] as int? ?? 0;
        final used = balance['used'] as int? ?? 0;
        final available = balance['available'] as int? ?? 0;
        final typeName = typeConfig?['name'] as String? ??
            (balance['leaveTypeCode'] as String? ?? typeId);
        final typeCode = typeConfig?['code'] as String? ??
            (balance['leaveTypeCode'] as String? ?? '');
        final isPaid = typeConfig?['isPaid'] as bool? ?? true;

        totalLeaveAllowed += allowed;
        totalLeaveUsedYTD += used;

        breakdownItems.add(LeaveBreakdownItem(
          leaveTypeName: typeName,
          leaveTypeCode: typeCode,
          isPaid: isPaid,
          allowed: allowed,
          used: used,
          takenThisMonth: 0,
          balance: available,
        ));
      }
    }

    // ── Calculate salary ──
    final perDaySalary = workingDays > 0 ? recalculated.grossSalary / workingDays : 0.0;
    final lopDeduction = totalUnpaidLeaveDays > 0 ? perDaySalary * totalUnpaidLeaveDays : 0.0;
    final presentDays = workingDays - totalLeaveDaysThisMonth;
    final adjustedNet = recalculated.netSalary - lopDeduction;

    final periodLabel = DateFormat('MMMM yyyy').format(DateTime(year, month));
    final now = DateTime.now();

    final record = PayrollRecord(
      id: existing?.id ?? '',
      staffId: config.staffId,
      staffName: config.staffName,
      employeeId: config.employeeId,
      userId: staff.userId,
      department: '',
      designation: staff.designation ?? '',
      month: month,
      year: year,
      periodLabel: periodLabel,
      basicPay: recalculated.basicPay,
      earnings: recalculated.earnings,
      deductions: recalculated.deductions,
      grossSalary: recalculated.grossSalary,
      totalDeductions: recalculated.totalDeductions + lopDeduction,
      netSalary: adjustedNet > 0 ? adjustedNet : 0,
      workingDays: workingDays,
      presentDays: presentDays > 0 ? presentDays : 0,
      leaveDaysTaken: totalLeaveDaysThisMonth,
      paidLeaveDays: totalPaidLeaveDays,
      unpaidLeaveDays: totalUnpaidLeaveDays,
      totalLeaveAllowed: totalLeaveAllowed,
      totalLeaveUsedYTD: totalLeaveUsedYTD,
      leaveBreakdown: breakdownItems,
      lopDeduction: lopDeduction,
      perDaySalary: perDaySalary,
      status: PayrollStatus.PROCESSED,
      processedBy: adminUserId,
      processedAt: now,
      approvedBy: null,
      approvedAt: null,
      rejectionReason: null,
      remarks: null,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );

    if (existing != null) {
      await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('payrollRecords')
          .doc(existing.id)
          .update(record.toFirestore());
      return existing.id;
    } else {
      final docRef = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('payrollRecords')
          .add(record.toFirestore());
      return docRef.id;
    }
  }

  /// Process payroll for ALL staff with payroll configs
  /// Fetches leave type configs once and reuses for all staff
  Future<int> processPayrollForAll({
    required String schoolId,
    required String adminUserId,
    required int month,
    required int year,
    required List<StaffProfile> staffList,
    int workingDays = 26,
  }) async {
    // Fetch leave type configs once for all staff
    final leaveTypeConfigs = await _getLeaveTypeConfigs(schoolId);

    final configs = await _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('payrollConfig')
        .get();

    int processedCount = 0;
    for (final configDoc in configs.docs) {
      final config = PayrollConfig.fromFirestore(configDoc);
      if (config.netSalary <= 0) continue;

      final staff = staffList.where((s) => s.id == config.staffId).firstOrNull;
      if (staff == null) continue;

      try {
        await processPayroll(
          schoolId: schoolId,
          adminUserId: adminUserId,
          config: config,
          staff: staff,
          month: month,
          year: year,
          workingDays: workingDays,
          leaveTypeConfigs: leaveTypeConfigs,
        );
        processedCount++;
      } catch (e) {
        print('Error processing payroll for ${config.staffName}: $e');
      }
    }
    return processedCount;
  }

  /// Approve a payroll record
  Future<void> approvePayroll(String schoolId, String recordId, String approvedBy) async {
    await _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('payrollRecords')
        .doc(recordId)
        .update({
      'status': PayrollStatus.APPROVED.name,
      'approvedBy': approvedBy,
      'approvedAt': Timestamp.fromDate(DateTime.now()),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Approve all PROCESSED payroll records for a month
  Future<int> approveAllPayroll(String schoolId, int month, int year, String approvedBy) async {
    final snapshot = await _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('payrollRecords')
        .where('month', isEqualTo: month)
        .where('year', isEqualTo: year)
        .where('status', isEqualTo: PayrollStatus.PROCESSED.name)
        .get();

    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {
        'status': PayrollStatus.APPROVED.name,
        'approvedBy': approvedBy,
        'approvedAt': Timestamp.fromDate(DateTime.now()),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    }
    await batch.commit();
    return snapshot.docs.length;
  }

  /// Reject a payroll record
  Future<void> rejectPayroll(String schoolId, String recordId, String rejectedBy, String reason) async {
    await _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('payrollRecords')
        .doc(recordId)
        .update({
      'status': PayrollStatus.REJECTED.name,
      'rejectionReason': reason,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Delete a draft/rejected payroll record
  Future<void> deletePayrollRecord(String schoolId, String recordId) async {
    await _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('payrollRecords')
        .doc(recordId)
        .delete();
  }
}

// ══════════════════════════════════════════════════════════════════
// PROVIDERS
// ══════════════════════════════════════════════════════════════════

final payrollRepositoryProvider = Provider<PayrollRepository>((ref) {
  return PayrollRepository(FirebaseFirestore.instance);
});

final payrollConfigProvider = FutureProvider.family<PayrollConfig?, ({String schoolId, String staffId})>((ref, params) {
  return ref.watch(payrollRepositoryProvider).getPayrollConfig(params.schoolId, params.staffId);
});

final allPayrollConfigsProvider = StreamProvider.family<List<PayrollConfig>, String>((ref, schoolId) {
  return ref.watch(payrollRepositoryProvider).getAllPayrollConfigs(schoolId);
});

final monthlyPayrollProvider = StreamProvider.family<List<PayrollRecord>, ({String schoolId, int month, int year})>((ref, params) {
  return ref.watch(payrollRepositoryProvider).getMonthlyPayroll(params.schoolId, params.month, params.year);
});

final staffPayrollRecordsProvider = StreamProvider.family<List<PayrollRecord>, ({String schoolId, String userId})>((ref, params) {
  return ref.watch(payrollRepositoryProvider).getStaffPayrollRecords(params.schoolId, params.userId);
});
