import 'package:cloud_firestore/cloud_firestore.dart';

enum PaymentType { ADMISSION, TUITION, EXAM, VAN, ARREARS, OTHER }
enum PaymentMode { CASH, UPI, CARD, CHEQUE, BANK_TRANSFER, OTHER }

class FeePayment {
  final String id;
  final String schoolId;
  final int billId;
  final String studentId;
  final String studentName;
  final String className;
  final String section;
  final String academicYear;
  final String fiscalYear;
  /// For arrears payments: the academic year the unpaid fees originated from.
  /// When empty, defaults to [academicYear] (regular current-year payment).
  final String originatingAcademicYear;
  /// For arrears payments: the class the student was in when the arrears were incurred.
  final String originatingClass;
  
  // Payment breakdown
  final double admissionFeePaid;
  final double tuitionFeePaid;
  final double examFeePaid;
  final double vanFeePaid;
  final double arrearsPaid;
  final double totalAmount;
  
  // Payment details
  final PaymentMode paymentMode;
  final String? transactionId;
  final String? remarks;
  final String cashierName;
  final DateTime paymentDate;
  
  // Status
  final bool isDeleted;
  final String? deletionReason;
  
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? createdBy;

  const FeePayment({
    required this.id,
    required this.schoolId,
    required this.billId,
    required this.studentId,
    required this.studentName,
    required this.className,
    required this.section,
    required this.academicYear,
    this.fiscalYear = '',
    this.originatingAcademicYear = '',
    this.originatingClass = '',
    this.admissionFeePaid = 0.0,
    this.tuitionFeePaid = 0.0,
    this.examFeePaid = 0.0,
    this.vanFeePaid = 0.0,
    this.arrearsPaid = 0.0,
    required this.totalAmount,
    required this.paymentMode,
    this.transactionId,
    this.remarks,
    required this.cashierName,
    required this.paymentDate,
    this.isDeleted = false,
    this.deletionReason,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy,
  });

  factory FeePayment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FeePayment(
      id: doc.id,
      schoolId: data['schoolId'] as String? ?? '',
      billId: (data['billId'] as num?)?.toInt() ?? 0,
      studentId: (data['studentId'] ?? data['stuId'])?.toString() ?? '',
      studentName: (data['studentName'] ?? data['stuName'])?.toString() ?? '',
      className: data['className'] as String? ?? '',
      section: data['section'] as String? ?? '',
      academicYear: data['academicYear'] as String? ?? '',
      fiscalYear: data['fiscalYear'] as String? ?? '',
      originatingAcademicYear: data['originatingAcademicYear'] as String? ?? '',
      originatingClass: data['originatingClass'] as String? ?? '',
      admissionFeePaid: (data['admissionFeePaid'] as num?)?.toDouble() ?? 0.0,
      tuitionFeePaid: (data['tuitionFeePaid'] as num?)?.toDouble() ?? 0.0,
      examFeePaid: (data['examFeePaid'] as num?)?.toDouble() ?? 0.0,
      vanFeePaid: (data['vanFeePaid'] as num?)?.toDouble() ?? 0.0,
      arrearsPaid: (data['arrearsPaid'] as num?)?.toDouble() ?? 0.0,
      totalAmount: ((data['totalAmount'] ?? data['revenueAmount']) as num?)?.toDouble() ?? 0.0,
      paymentMode: _parsePaymentMode(data['paymentMode']),
      transactionId: data['transactionId'] as String?,
      remarks: data['remarks'] as String?,
      cashierName: (data['cashierName'] ?? data['billCashierName'])?.toString() ?? '',
      paymentDate: _parseDateTime(data['paymentDate'] ?? data['billDate']) ?? DateTime.now(),
      isDeleted: (data['isDeleted'] ?? data['isBillDeleted']) == true,
      deletionReason: data['deletionReason'] as String?,
      createdAt: _parseDateTime(data['createdAt']) ?? DateTime.now(),
      updatedAt: _parseDateTime(data['updatedAt']) ?? DateTime.now(),
      createdBy: data['createdBy'] as String?,
    );
  }

  static PaymentMode _parsePaymentMode(dynamic mode) {
    if (mode == null) return PaymentMode.CASH;
    switch (mode.toString().toUpperCase()) {
      case 'CASH': return PaymentMode.CASH;
      case 'UPI': return PaymentMode.UPI;
      case 'CARD': return PaymentMode.CARD;
      case 'CHEQUE': return PaymentMode.CHEQUE;
      case 'BANK_TRANSFER': return PaymentMode.BANK_TRANSFER;
      default: return PaymentMode.OTHER;
    }
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  Map<String, dynamic> toFirestore() {
    return {
      'schoolId': schoolId,
      'billId': billId,
      'billType': 'Revenue',
      'studentId': studentId,
      'stuId': studentId,
      'studentName': studentName,
      'stuName': studentName,
      'className': className,
      'section': section,
      'academicYear': academicYear,
      'fiscalYear': fiscalYear,
      'originatingAcademicYear': originatingAcademicYear.isEmpty ? academicYear : originatingAcademicYear,
      'originatingClass': originatingClass.isEmpty ? className : originatingClass,
      'admissionFeePaid': admissionFeePaid,
      'tuitionFeePaid': tuitionFeePaid,
      'examFeePaid': examFeePaid,
      'vanFeePaid': vanFeePaid,
      'arrearsPaid': arrearsPaid,
      'totalAmount': totalAmount,
      'revenueAmount': totalAmount,
      'revenueType': 'Fee Payment',
      'paymentMode': paymentMode.name,
      'transactionId': transactionId,
      'remarks': remarks,
      'cashierName': cashierName,
      'billCashierName': cashierName,
      'paymentDate': Timestamp.fromDate(paymentDate),
      'billDate': Timestamp.fromDate(paymentDate),
      'isDeleted': isDeleted,
      'isBillDeleted': isDeleted,
      'deletionReason': deletionReason,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'createdBy': createdBy,
      // Expense fields (zero for revenue)
      'expenseAmount': 0.0,
      'expenseType': '',
      'expenseDesc': '',
      'expensePOC': '',
      'isMissedExpense': 'No',
    };
  }

  FeePayment copyWith({
    String? id,
    String? schoolId,
    int? billId,
    String? studentId,
    String? studentName,
    String? className,
    String? section,
    String? academicYear,
    String? fiscalYear,
    String? originatingAcademicYear,
    String? originatingClass,
    double? admissionFeePaid,
    double? tuitionFeePaid,
    double? examFeePaid,
    double? vanFeePaid,
    double? arrearsPaid,
    double? totalAmount,
    PaymentMode? paymentMode,
    String? transactionId,
    String? remarks,
    String? cashierName,
    DateTime? paymentDate,
    bool? isDeleted,
    String? deletionReason,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
  }) {
    return FeePayment(
      id: id ?? this.id,
      schoolId: schoolId ?? this.schoolId,
      billId: billId ?? this.billId,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      className: className ?? this.className,
      section: section ?? this.section,
      academicYear: academicYear ?? this.academicYear,
      fiscalYear: fiscalYear ?? this.fiscalYear,
      originatingAcademicYear: originatingAcademicYear ?? this.originatingAcademicYear,
      originatingClass: originatingClass ?? this.originatingClass,
      admissionFeePaid: admissionFeePaid ?? this.admissionFeePaid,
      tuitionFeePaid: tuitionFeePaid ?? this.tuitionFeePaid,
      examFeePaid: examFeePaid ?? this.examFeePaid,
      vanFeePaid: vanFeePaid ?? this.vanFeePaid,
      arrearsPaid: arrearsPaid ?? this.arrearsPaid,
      totalAmount: totalAmount ?? this.totalAmount,
      paymentMode: paymentMode ?? this.paymentMode,
      transactionId: transactionId ?? this.transactionId,
      remarks: remarks ?? this.remarks,
      cashierName: cashierName ?? this.cashierName,
      paymentDate: paymentDate ?? this.paymentDate,
      isDeleted: isDeleted ?? this.isDeleted,
      deletionReason: deletionReason ?? this.deletionReason,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }
}
