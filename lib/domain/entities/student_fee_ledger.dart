import 'package:cloud_firestore/cloud_firestore.dart';

enum TermPaymentStatus { UNPAID, PARTIAL, PAID, OVERDUE }

class TermLedgerEntry {
  final String termId;
  final String termName;
  final int sequence;
  final double amount;
  final DateTime dueDate;
  final double paidAmount;
  final double lateFeeApplied;
  final TermPaymentStatus status;
  final DateTime? paidAt;
  final List<String> paymentIds;

  const TermLedgerEntry({
    required this.termId,
    required this.termName,
    required this.sequence,
    required this.amount,
    required this.dueDate,
    this.paidAmount = 0,
    this.lateFeeApplied = 0,
    this.status = TermPaymentStatus.UNPAID,
    this.paidAt,
    this.paymentIds = const [],
  });

  double get balanceAmount => (amount + lateFeeApplied - paidAmount).clamp(0, double.infinity);

  factory TermLedgerEntry.fromMap(Map<String, dynamic> data) {
    return TermLedgerEntry(
      termId: data['termId']?.toString() ?? '',
      termName: data['termName']?.toString() ?? '',
      sequence: (data['sequence'] as num?)?.toInt() ?? 0,
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      dueDate: _parseDate(data['dueDate']) ?? DateTime.now(),
      paidAmount: (data['paidAmount'] as num?)?.toDouble() ?? 0,
      lateFeeApplied: (data['lateFeeApplied'] as num?)?.toDouble() ?? 0,
      status: _parseStatus(data['status']),
      paidAt: _parseDate(data['paidAt']),
      paymentIds: (data['paymentIds'] as List?)?.map((e) => e.toString()).toList() ?? const [],
    );
  }

  static TermPaymentStatus _parseStatus(dynamic v) {
    final s = v?.toString().toUpperCase() ?? 'UNPAID';
    return TermPaymentStatus.values.firstWhere(
      (e) => e.name == s,
      orElse: () => TermPaymentStatus.UNPAID,
    );
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  Map<String, dynamic> toMap() => {
        'termId': termId,
        'termName': termName,
        'sequence': sequence,
        'amount': amount,
        'dueDate': Timestamp.fromDate(dueDate),
        'paidAmount': paidAmount,
        'lateFeeApplied': lateFeeApplied,
        'balanceAmount': balanceAmount,
        'status': status.name,
        if (paidAt != null) 'paidAt': Timestamp.fromDate(paidAt!),
        'paymentIds': paymentIds,
      };

  TermLedgerEntry copyWith({
    String? termId,
    String? termName,
    int? sequence,
    double? amount,
    DateTime? dueDate,
    double? paidAmount,
    double? lateFeeApplied,
    TermPaymentStatus? status,
    DateTime? paidAt,
    List<String>? paymentIds,
  }) =>
      TermLedgerEntry(
        termId: termId ?? this.termId,
        termName: termName ?? this.termName,
        sequence: sequence ?? this.sequence,
        amount: amount ?? this.amount,
        dueDate: dueDate ?? this.dueDate,
        paidAmount: paidAmount ?? this.paidAmount,
        lateFeeApplied: lateFeeApplied ?? this.lateFeeApplied,
        status: status ?? this.status,
        paidAt: paidAt ?? this.paidAt,
        paymentIds: paymentIds ?? this.paymentIds,
      );
}

class StudentFeeLedger {
  final String id;
  final String schoolId;
  final String studentId;
  final String studentName;
  final String className;
  final String section;
  final String academicYear;
  final String feeStructureId;
  final String feeStructureName;
  final double totalAssigned;
  final double totalPaid;
  final double totalPending;
  final double totalOverdue;
  final double totalLateFee;
  final List<TermLedgerEntry> termStatus;
  final bool remindersEnabled;
  final DateTime? lastReminderSentAt;
  final String? parentPhone;
  final String? parentName;
  final DateTime createdAt;
  final DateTime updatedAt;

  const StudentFeeLedger({
    required this.id,
    required this.schoolId,
    required this.studentId,
    required this.studentName,
    this.className = '',
    this.section = '',
    required this.academicYear,
    required this.feeStructureId,
    this.feeStructureName = '',
    this.totalAssigned = 0,
    this.totalPaid = 0,
    this.totalPending = 0,
    this.totalOverdue = 0,
    this.totalLateFee = 0,
    this.termStatus = const [],
    this.remindersEnabled = true,
    this.lastReminderSentAt,
    this.parentPhone,
    this.parentName,
    required this.createdAt,
    required this.updatedAt,
  });

  factory StudentFeeLedger.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return StudentFeeLedger(
      id: doc.id,
      schoolId: data['schoolId']?.toString() ?? '',
      studentId: data['studentId']?.toString() ?? '',
      studentName: data['studentName']?.toString() ?? '',
      className: data['className']?.toString() ?? '',
      section: data['section']?.toString() ?? '',
      academicYear: data['academicYear']?.toString() ?? '',
      feeStructureId: data['feeStructureId']?.toString() ?? '',
      feeStructureName: data['feeStructureName']?.toString() ?? '',
      totalAssigned: (data['totalAssigned'] as num?)?.toDouble() ?? 0,
      totalPaid: (data['totalPaid'] as num?)?.toDouble() ?? 0,
      totalPending: (data['totalPending'] as num?)?.toDouble() ?? 0,
      totalOverdue: (data['totalOverdue'] as num?)?.toDouble() ?? 0,
      totalLateFee: (data['totalLateFee'] as num?)?.toDouble() ?? 0,
      termStatus: ((data['termStatus'] as List?) ?? [])
          .map((e) => TermLedgerEntry.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      remindersEnabled: data['remindersEnabled'] as bool? ?? true,
      lastReminderSentAt: _parseDate(data['lastReminderSentAt']),
      parentPhone: data['parentPhone']?.toString(),
      parentName: data['parentName']?.toString(),
      createdAt: _parseDate(data['createdAt']) ?? DateTime.now(),
      updatedAt: _parseDate(data['updatedAt']) ?? DateTime.now(),
    );
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  Map<String, dynamic> toFirestore() => {
        'schoolId': schoolId,
        'studentId': studentId,
        'studentName': studentName,
        'className': className,
        'section': section,
        'academicYear': academicYear,
        'feeStructureId': feeStructureId,
        'feeStructureName': feeStructureName,
        'totalAssigned': totalAssigned,
        'totalPaid': totalPaid,
        'totalPending': totalPending,
        'totalOverdue': totalOverdue,
        'totalLateFee': totalLateFee,
        'termStatus': termStatus.map((t) => t.toMap()).toList(),
        'remindersEnabled': remindersEnabled,
        if (lastReminderSentAt != null) 'lastReminderSentAt': Timestamp.fromDate(lastReminderSentAt!),
        if (parentPhone != null) 'parentPhone': parentPhone,
        if (parentName != null) 'parentName': parentName,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      };

  StudentFeeLedger copyWith({
    String? id,
    String? feeStructureName,
    double? totalAssigned,
    double? totalPaid,
    double? totalPending,
    double? totalOverdue,
    double? totalLateFee,
    List<TermLedgerEntry>? termStatus,
    bool? remindersEnabled,
    DateTime? lastReminderSentAt,
    String? parentPhone,
    String? parentName,
    DateTime? updatedAt,
  }) =>
      StudentFeeLedger(
        id: id ?? this.id,
        schoolId: schoolId,
        studentId: studentId,
        studentName: studentName,
        className: className,
        section: section,
        academicYear: academicYear,
        feeStructureId: feeStructureId,
        feeStructureName: feeStructureName ?? this.feeStructureName,
        totalAssigned: totalAssigned ?? this.totalAssigned,
        totalPaid: totalPaid ?? this.totalPaid,
        totalPending: totalPending ?? this.totalPending,
        totalOverdue: totalOverdue ?? this.totalOverdue,
        totalLateFee: totalLateFee ?? this.totalLateFee,
        termStatus: termStatus ?? this.termStatus,
        remindersEnabled: remindersEnabled ?? this.remindersEnabled,
        lastReminderSentAt: lastReminderSentAt ?? this.lastReminderSentAt,
        parentPhone: parentPhone ?? this.parentPhone,
        parentName: parentName ?? this.parentName,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
