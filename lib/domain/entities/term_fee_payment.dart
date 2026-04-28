import 'package:cloud_firestore/cloud_firestore.dart';

enum TermPaymentMode { CASH, UPI, CARD, CHEQUE, BANK_TRANSFER, ONLINE, OTHER }

class TermFeePayment {
  final String id;
  final String schoolId;
  final String studentId;
  final String studentName;
  final String className;
  final String section;
  final String ledgerId;
  final String feeStructureId;
  final String termId;
  final String termName;
  final String academicYear;
  final double amount;
  final double lateFeeAmount;
  final TermPaymentMode paymentMode;
  final String? transactionRef;
  final String receiptNumber;
  final int billId;
  final List<Map<String, dynamic>> components;
  final String? collectedBy;
  final String? collectedByName;
  final DateTime paidAt;
  final String? notes;
  final bool isDeleted;
  final String? deletionReason;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TermFeePayment({
    required this.id,
    required this.schoolId,
    required this.studentId,
    required this.studentName,
    this.className = '',
    this.section = '',
    required this.ledgerId,
    required this.feeStructureId,
    required this.termId,
    required this.termName,
    required this.academicYear,
    required this.amount,
    this.lateFeeAmount = 0,
    this.paymentMode = TermPaymentMode.CASH,
    this.transactionRef,
    required this.receiptNumber,
    this.billId = 0,
    this.components = const [],
    this.collectedBy,
    this.collectedByName,
    required this.paidAt,
    this.notes,
    this.isDeleted = false,
    this.deletionReason,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TermFeePayment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TermFeePayment(
      id: doc.id,
      schoolId: data['schoolId']?.toString() ?? '',
      studentId: data['studentId']?.toString() ?? '',
      studentName: data['studentName']?.toString() ?? '',
      className: data['className']?.toString() ?? '',
      section: data['section']?.toString() ?? '',
      ledgerId: data['ledgerId']?.toString() ?? '',
      feeStructureId: data['feeStructureId']?.toString() ?? '',
      termId: data['termId']?.toString() ?? '',
      termName: data['termName']?.toString() ?? '',
      academicYear: data['academicYear']?.toString() ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      lateFeeAmount: (data['lateFeeAmount'] as num?)?.toDouble() ?? 0,
      paymentMode: _parseMode(data['paymentMode']),
      transactionRef: data['transactionRef']?.toString(),
      receiptNumber: data['receiptNumber']?.toString() ?? '',
      billId: (data['billId'] as num?)?.toInt() ?? 0,
      components: ((data['components'] as List?) ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      collectedBy: data['collectedBy']?.toString(),
      collectedByName: data['collectedByName']?.toString(),
      paidAt: _parseDate(data['paidAt']) ?? DateTime.now(),
      notes: data['notes']?.toString(),
      isDeleted: data['isDeleted'] as bool? ?? false,
      deletionReason: data['deletionReason']?.toString(),
      createdAt: _parseDate(data['createdAt']) ?? DateTime.now(),
      updatedAt: _parseDate(data['updatedAt']) ?? DateTime.now(),
    );
  }

  static TermPaymentMode _parseMode(dynamic v) {
    final s = v?.toString().toUpperCase() ?? 'CASH';
    return TermPaymentMode.values.firstWhere(
      (e) => e.name == s,
      orElse: () => TermPaymentMode.CASH,
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
        'ledgerId': ledgerId,
        'feeStructureId': feeStructureId,
        'termId': termId,
        'termName': termName,
        'academicYear': academicYear,
        'amount': amount,
        'lateFeeAmount': lateFeeAmount,
        'paymentMode': paymentMode.name,
        if (transactionRef != null) 'transactionRef': transactionRef,
        'receiptNumber': receiptNumber,
        'billId': billId,
        'components': components,
        if (collectedBy != null) 'collectedBy': collectedBy,
        if (collectedByName != null) 'collectedByName': collectedByName,
        'paidAt': Timestamp.fromDate(paidAt),
        if (notes != null) 'notes': notes,
        'isDeleted': isDeleted,
        if (deletionReason != null) 'deletionReason': deletionReason,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      };
}
