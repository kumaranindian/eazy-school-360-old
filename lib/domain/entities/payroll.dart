import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a single salary component (e.g., Basic Pay, HRA, PF Deduction)
class SalaryComponent {
  final String name;
  final double amount;
  final SalaryComponentType type; // EARNING or DEDUCTION

  const SalaryComponent({
    required this.name,
    required this.amount,
    required this.type,
  });

  factory SalaryComponent.fromMap(Map<String, dynamic> map) {
    return SalaryComponent(
      name: map['name'] as String? ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      type: _parseComponentType(map['type']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'amount': amount,
      'type': type.name,
    };
  }

  static SalaryComponentType _parseComponentType(dynamic type) {
    if (type == null) return SalaryComponentType.EARNING;
    switch (type.toString().toUpperCase()) {
      case 'DEDUCTION':
        return SalaryComponentType.DEDUCTION;
      default:
        return SalaryComponentType.EARNING;
    }
  }

  SalaryComponent copyWith({String? name, double? amount, SalaryComponentType? type}) {
    return SalaryComponent(
      name: name ?? this.name,
      amount: amount ?? this.amount,
      type: type ?? this.type,
    );
  }
}

enum SalaryComponentType { EARNING, DEDUCTION }

/// Payroll configuration for a staff member (stored in schools/{schoolId}/payrollConfig/{staffId})
class PayrollConfig {
  final String id; // same as staffId
  final String staffId;
  final String staffName;
  final String employeeId;
  final double basicPay;
  final List<SalaryComponent> earnings;
  final List<SalaryComponent> deductions;
  final double grossSalary;
  final double totalDeductions;
  final double netSalary;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String updatedBy;

  const PayrollConfig({
    required this.id,
    required this.staffId,
    required this.staffName,
    required this.employeeId,
    required this.basicPay,
    required this.earnings,
    required this.deductions,
    required this.grossSalary,
    required this.totalDeductions,
    required this.netSalary,
    required this.createdAt,
    required this.updatedAt,
    required this.updatedBy,
  });

  factory PayrollConfig.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final now = DateTime.now();

    final earningsList = (data['earnings'] as List<dynamic>?)
            ?.map((e) => SalaryComponent.fromMap(e as Map<String, dynamic>))
            .toList() ??
        [];
    final deductionsList = (data['deductions'] as List<dynamic>?)
            ?.map((e) => SalaryComponent.fromMap(e as Map<String, dynamic>))
            .toList() ??
        [];

    return PayrollConfig(
      id: doc.id,
      staffId: data['staffId'] as String? ?? doc.id,
      staffName: data['staffName'] as String? ?? '',
      employeeId: data['employeeId'] as String? ?? '',
      basicPay: (data['basicPay'] as num?)?.toDouble() ?? 0.0,
      earnings: earningsList,
      deductions: deductionsList,
      grossSalary: (data['grossSalary'] as num?)?.toDouble() ?? 0.0,
      totalDeductions: (data['totalDeductions'] as num?)?.toDouble() ?? 0.0,
      netSalary: (data['netSalary'] as num?)?.toDouble() ?? 0.0,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : now,
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : now,
      updatedBy: data['updatedBy'] as String? ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'staffId': staffId,
      'staffName': staffName,
      'employeeId': employeeId,
      'basicPay': basicPay,
      'earnings': earnings.map((e) => e.toMap()).toList(),
      'deductions': deductions.map((e) => e.toMap()).toList(),
      'grossSalary': grossSalary,
      'totalDeductions': totalDeductions,
      'netSalary': netSalary,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'updatedBy': updatedBy,
    };
  }

  PayrollConfig copyWith({
    String? id,
    String? staffId,
    String? staffName,
    String? employeeId,
    double? basicPay,
    List<SalaryComponent>? earnings,
    List<SalaryComponent>? deductions,
    double? grossSalary,
    double? totalDeductions,
    double? netSalary,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? updatedBy,
  }) {
    return PayrollConfig(
      id: id ?? this.id,
      staffId: staffId ?? this.staffId,
      staffName: staffName ?? this.staffName,
      employeeId: employeeId ?? this.employeeId,
      basicPay: basicPay ?? this.basicPay,
      earnings: earnings ?? this.earnings,
      deductions: deductions ?? this.deductions,
      grossSalary: grossSalary ?? this.grossSalary,
      totalDeductions: totalDeductions ?? this.totalDeductions,
      netSalary: netSalary ?? this.netSalary,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }

  /// Recalculate totals from components
  static PayrollConfig recalculate(PayrollConfig config) {
    final gross = config.basicPay +
        config.earnings.fold<double>(0.0, (sum, e) => sum + e.amount);
    final totalDed =
        config.deductions.fold<double>(0.0, (sum, d) => sum + d.amount);
    final net = gross - totalDed;
    return config.copyWith(
      grossSalary: gross,
      totalDeductions: totalDed,
      netSalary: net,
    );
  }
}

/// Status of a monthly payroll record
enum PayrollStatus { DRAFT, PROCESSED, APPROVED, PAID, REJECTED }

/// Leave breakdown per leave type for the payroll period
class LeaveBreakdownItem {
  final String leaveTypeName;
  final String leaveTypeCode;
  final bool isPaid;
  final int allowed; // total quota for the year
  final int used; // used so far this year (cumulative)
  final int takenThisMonth; // days taken in this payroll month
  final int balance; // remaining balance

  const LeaveBreakdownItem({
    required this.leaveTypeName,
    required this.leaveTypeCode,
    required this.isPaid,
    required this.allowed,
    required this.used,
    required this.takenThisMonth,
    required this.balance,
  });

  factory LeaveBreakdownItem.fromMap(Map<String, dynamic> map) {
    return LeaveBreakdownItem(
      leaveTypeName: map['leaveTypeName'] as String? ?? '',
      leaveTypeCode: map['leaveTypeCode'] as String? ?? '',
      isPaid: map['isPaid'] as bool? ?? true,
      allowed: (map['allowed'] as num?)?.toInt() ?? 0,
      used: (map['used'] as num?)?.toInt() ?? 0,
      takenThisMonth: (map['takenThisMonth'] as num?)?.toInt() ?? 0,
      balance: (map['balance'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'leaveTypeName': leaveTypeName,
      'leaveTypeCode': leaveTypeCode,
      'isPaid': isPaid,
      'allowed': allowed,
      'used': used,
      'takenThisMonth': takenThisMonth,
      'balance': balance,
    };
  }
}

/// Monthly payroll record for a staff member
/// Stored in schools/{schoolId}/payrollRecords/{recordId}
class PayrollRecord {
  final String id;
  final String staffId;
  final String staffName;
  final String employeeId;
  final String userId; // Firebase Auth UID of the staff
  final String department;
  final String designation;
  final int month; // 1-12
  final int year;
  final String periodLabel; // e.g., "March 2026"
  final double basicPay;
  final List<SalaryComponent> earnings;
  final List<SalaryComponent> deductions;
  final double grossSalary;
  final double totalDeductions;
  final double netSalary;
  final int workingDays;
  final int presentDays;
  final int leaveDaysTaken; // total leave days this month
  final int paidLeaveDays; // leave days within allowed quota
  final int unpaidLeaveDays; // leave days beyond allowed quota (LOP)
  final int totalLeaveAllowed; // total annual leave quota
  final int totalLeaveUsedYTD; // cumulative leave used this year
  final List<LeaveBreakdownItem> leaveBreakdown; // per-type breakdown
  final double lopDeduction; // Loss of Pay deduction
  final double perDaySalary; // gross / working days
  final PayrollStatus status;
  final String? processedBy;
  final DateTime? processedAt;
  final String? approvedBy;
  final DateTime? approvedAt;
  final String? rejectionReason;
  final String? remarks;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PayrollRecord({
    required this.id,
    required this.staffId,
    required this.staffName,
    required this.employeeId,
    required this.userId,
    this.department = '',
    this.designation = '',
    required this.month,
    required this.year,
    required this.periodLabel,
    required this.basicPay,
    required this.earnings,
    required this.deductions,
    required this.grossSalary,
    required this.totalDeductions,
    required this.netSalary,
    required this.workingDays,
    required this.presentDays,
    required this.leaveDaysTaken,
    this.paidLeaveDays = 0,
    this.unpaidLeaveDays = 0,
    this.totalLeaveAllowed = 0,
    this.totalLeaveUsedYTD = 0,
    this.leaveBreakdown = const [],
    required this.lopDeduction,
    this.perDaySalary = 0,
    required this.status,
    this.processedBy,
    this.processedAt,
    this.approvedBy,
    this.approvedAt,
    this.rejectionReason,
    this.remarks,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PayrollRecord.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final now = DateTime.now();

    final earningsList = (data['earnings'] as List<dynamic>?)
            ?.map((e) => SalaryComponent.fromMap(e as Map<String, dynamic>))
            .toList() ??
        [];
    final deductionsList = (data['deductions'] as List<dynamic>?)
            ?.map((e) => SalaryComponent.fromMap(e as Map<String, dynamic>))
            .toList() ??
        [];

    final leaveBreakdownList = (data['leaveBreakdown'] as List<dynamic>?)
            ?.map((e) => LeaveBreakdownItem.fromMap(e as Map<String, dynamic>))
            .toList() ??
        [];

    return PayrollRecord(
      id: doc.id,
      staffId: data['staffId'] as String? ?? '',
      staffName: data['staffName'] as String? ?? '',
      employeeId: data['employeeId'] as String? ?? '',
      userId: data['userId'] as String? ?? '',
      department: data['department'] as String? ?? '',
      designation: data['designation'] as String? ?? '',
      month: (data['month'] as num?)?.toInt() ?? now.month,
      year: (data['year'] as num?)?.toInt() ?? now.year,
      periodLabel: data['periodLabel'] as String? ?? '',
      basicPay: (data['basicPay'] as num?)?.toDouble() ?? 0.0,
      earnings: earningsList,
      deductions: deductionsList,
      grossSalary: (data['grossSalary'] as num?)?.toDouble() ?? 0.0,
      totalDeductions: (data['totalDeductions'] as num?)?.toDouble() ?? 0.0,
      netSalary: (data['netSalary'] as num?)?.toDouble() ?? 0.0,
      workingDays: (data['workingDays'] as num?)?.toInt() ?? 0,
      presentDays: (data['presentDays'] as num?)?.toInt() ?? 0,
      leaveDaysTaken: (data['leaveDaysTaken'] as num?)?.toInt() ?? 0,
      paidLeaveDays: (data['paidLeaveDays'] as num?)?.toInt() ?? 0,
      unpaidLeaveDays: (data['unpaidLeaveDays'] as num?)?.toInt() ?? 0,
      totalLeaveAllowed: (data['totalLeaveAllowed'] as num?)?.toInt() ?? 0,
      totalLeaveUsedYTD: (data['totalLeaveUsedYTD'] as num?)?.toInt() ?? 0,
      leaveBreakdown: leaveBreakdownList,
      lopDeduction: (data['lopDeduction'] as num?)?.toDouble() ?? 0.0,
      perDaySalary: (data['perDaySalary'] as num?)?.toDouble() ?? 0.0,
      status: _parseStatus(data['status']),
      processedBy: data['processedBy'] as String?,
      processedAt: data['processedAt'] != null
          ? (data['processedAt'] as Timestamp).toDate()
          : null,
      approvedBy: data['approvedBy'] as String?,
      approvedAt: data['approvedAt'] != null
          ? (data['approvedAt'] as Timestamp).toDate()
          : null,
      rejectionReason: data['rejectionReason'] as String?,
      remarks: data['remarks'] as String?,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : now,
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : now,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'staffId': staffId,
      'staffName': staffName,
      'employeeId': employeeId,
      'userId': userId,
      'department': department,
      'designation': designation,
      'month': month,
      'year': year,
      'periodLabel': periodLabel,
      'basicPay': basicPay,
      'earnings': earnings.map((e) => e.toMap()).toList(),
      'deductions': deductions.map((e) => e.toMap()).toList(),
      'grossSalary': grossSalary,
      'totalDeductions': totalDeductions,
      'netSalary': netSalary,
      'workingDays': workingDays,
      'presentDays': presentDays,
      'leaveDaysTaken': leaveDaysTaken,
      'paidLeaveDays': paidLeaveDays,
      'unpaidLeaveDays': unpaidLeaveDays,
      'totalLeaveAllowed': totalLeaveAllowed,
      'totalLeaveUsedYTD': totalLeaveUsedYTD,
      'leaveBreakdown': leaveBreakdown.map((e) => e.toMap()).toList(),
      'lopDeduction': lopDeduction,
      'perDaySalary': perDaySalary,
      'status': status.name,
      'processedBy': processedBy,
      'processedAt':
          processedAt != null ? Timestamp.fromDate(processedAt!) : null,
      'approvedBy': approvedBy,
      'approvedAt':
          approvedAt != null ? Timestamp.fromDate(approvedAt!) : null,
      'rejectionReason': rejectionReason,
      'remarks': remarks,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  static PayrollStatus _parseStatus(dynamic status) {
    if (status == null) return PayrollStatus.DRAFT;
    switch (status.toString().toUpperCase()) {
      case 'PROCESSED':
        return PayrollStatus.PROCESSED;
      case 'APPROVED':
        return PayrollStatus.APPROVED;
      case 'PAID':
        return PayrollStatus.PAID;
      case 'REJECTED':
        return PayrollStatus.REJECTED;
      default:
        return PayrollStatus.DRAFT;
    }
  }

  PayrollRecord copyWith({
    String? id,
    String? staffId,
    String? staffName,
    String? employeeId,
    String? userId,
    String? department,
    String? designation,
    int? month,
    int? year,
    String? periodLabel,
    double? basicPay,
    List<SalaryComponent>? earnings,
    List<SalaryComponent>? deductions,
    double? grossSalary,
    double? totalDeductions,
    double? netSalary,
    int? workingDays,
    int? presentDays,
    int? leaveDaysTaken,
    int? paidLeaveDays,
    int? unpaidLeaveDays,
    int? totalLeaveAllowed,
    int? totalLeaveUsedYTD,
    List<LeaveBreakdownItem>? leaveBreakdown,
    double? lopDeduction,
    double? perDaySalary,
    PayrollStatus? status,
    String? processedBy,
    DateTime? processedAt,
    String? approvedBy,
    DateTime? approvedAt,
    String? rejectionReason,
    String? remarks,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PayrollRecord(
      id: id ?? this.id,
      staffId: staffId ?? this.staffId,
      staffName: staffName ?? this.staffName,
      employeeId: employeeId ?? this.employeeId,
      userId: userId ?? this.userId,
      department: department ?? this.department,
      designation: designation ?? this.designation,
      month: month ?? this.month,
      year: year ?? this.year,
      periodLabel: periodLabel ?? this.periodLabel,
      basicPay: basicPay ?? this.basicPay,
      earnings: earnings ?? this.earnings,
      deductions: deductions ?? this.deductions,
      grossSalary: grossSalary ?? this.grossSalary,
      totalDeductions: totalDeductions ?? this.totalDeductions,
      netSalary: netSalary ?? this.netSalary,
      workingDays: workingDays ?? this.workingDays,
      presentDays: presentDays ?? this.presentDays,
      leaveDaysTaken: leaveDaysTaken ?? this.leaveDaysTaken,
      paidLeaveDays: paidLeaveDays ?? this.paidLeaveDays,
      unpaidLeaveDays: unpaidLeaveDays ?? this.unpaidLeaveDays,
      totalLeaveAllowed: totalLeaveAllowed ?? this.totalLeaveAllowed,
      totalLeaveUsedYTD: totalLeaveUsedYTD ?? this.totalLeaveUsedYTD,
      leaveBreakdown: leaveBreakdown ?? this.leaveBreakdown,
      lopDeduction: lopDeduction ?? this.lopDeduction,
      perDaySalary: perDaySalary ?? this.perDaySalary,
      status: status ?? this.status,
      processedBy: processedBy ?? this.processedBy,
      processedAt: processedAt ?? this.processedAt,
      approvedBy: approvedBy ?? this.approvedBy,
      approvedAt: approvedAt ?? this.approvedAt,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      remarks: remarks ?? this.remarks,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get isApproved => status == PayrollStatus.APPROVED || status == PayrollStatus.PAID;
  bool get isDraft => status == PayrollStatus.DRAFT;
  bool get isProcessed => status == PayrollStatus.PROCESSED;
}
