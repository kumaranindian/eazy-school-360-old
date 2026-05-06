import 'package:cloud_firestore/cloud_firestore.dart';

enum ArrearsStatus { PENDING, PAID, PARTIALLY_PAID, WAIVED }

/// Represents pending fees carried forward from previous academic year
class Arrears {
  final String id;
  final String schoolId;
  final String studentId;
  final String studentName;
  final int studentNumericId;
  final String className;
  final String section;
  final String fromAcademicYear; // e.g., "2023-2024"
  final String toAcademicYear; // e.g., "2024-2025"
  final double totalFeesForYear; // Total fees for the from year
  final double totalPaidForYear; // Total paid in the from year
  final double arrearsAmount; // Pending amount = totalFees - totalPaid
  final double paidAmount; // Amount paid towards arrears
  final double remainingAmount; // arrearsAmount - paidAmount
  final ArrearsStatus status;
  final String? description;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;

  const Arrears({
    required this.id,
    required this.schoolId,
    required this.studentId,
    required this.studentName,
    required this.studentNumericId,
    required this.className,
    required this.section,
    required this.fromAcademicYear,
    required this.toAcademicYear,
    required this.totalFeesForYear,
    required this.totalPaidForYear,
    required this.arrearsAmount,
    required this.paidAmount,
    required this.remainingAmount,
    required this.status,
    this.description,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
  });

  factory Arrears.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Arrears(
      id: doc.id,
      schoolId: data['schoolId'] as String? ?? '',
      studentId: data['studentId'] as String? ?? '',
      studentName: data['studentName'] as String? ?? '',
      studentNumericId: (data['studentNumericId'] as num?)?.toInt() ?? 0,
      className: data['className'] as String? ?? '',
      section: data['section'] as String? ?? '',
      fromAcademicYear: data['fromAcademicYear'] as String? ?? '',
      toAcademicYear: data['toAcademicYear'] as String? ?? '',
      totalFeesForYear: (data['totalFeesForYear'] as num?)?.toDouble() ?? 0.0,
      totalPaidForYear: (data['totalPaidForYear'] as num?)?.toDouble() ?? 0.0,
      arrearsAmount: (data['arrearsAmount'] as num?)?.toDouble() ?? 0.0,
      paidAmount: (data['paidAmount'] as num?)?.toDouble() ?? 0.0,
      remainingAmount: (data['remainingAmount'] as num?)?.toDouble() ?? 0.0,
      status: _parseStatus(data['status']),
      description: data['description'] as String?,
      createdAt: _parseDate(data['createdAt']),
      updatedAt: _parseDate(data['updatedAt']),
      createdBy: data['createdBy'] as String? ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'schoolId': schoolId,
      'studentId': studentId,
      'studentName': studentName,
      'studentNumericId': studentNumericId,
      'className': className,
      'section': section,
      'fromAcademicYear': fromAcademicYear,
      'toAcademicYear': toAcademicYear,
      'totalFeesForYear': totalFeesForYear,
      'totalPaidForYear': totalPaidForYear,
      'arrearsAmount': arrearsAmount,
      'paidAmount': paidAmount,
      'remainingAmount': remainingAmount,
      'status': status.name,
      'description': description,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'createdBy': createdBy,
    };
  }

  static ArrearsStatus _parseStatus(dynamic value) {
    if (value == null) return ArrearsStatus.PENDING;
    switch (value.toString().toUpperCase()) {
      case 'PAID': return ArrearsStatus.PAID;
      case 'PARTIALLY_PAID': return ArrearsStatus.PARTIALLY_PAID;
      case 'WAIVED': return ArrearsStatus.WAIVED;
      default: return ArrearsStatus.PENDING;
    }
  }

  static DateTime _parseDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }

  bool get isPending => status == ArrearsStatus.PENDING;
  bool get isPaid => status == ArrearsStatus.PAID;
  bool get isPartiallyPaid => status == ArrearsStatus.PARTIALLY_PAID;
  bool get isWaived => status == ArrearsStatus.WAIVED;

  String get statusLabel {
    switch (status) {
      case ArrearsStatus.PENDING: return 'Pending';
      case ArrearsStatus.PAID: return 'Paid';
      case ArrearsStatus.PARTIALLY_PAID: return 'Partially Paid';
      case ArrearsStatus.WAIVED: return 'Waived';
    }
  }

  Arrears copyWith({
    String? id,
    String? schoolId,
    String? studentId,
    String? studentName,
    int? studentNumericId,
    String? className,
    String? section,
    String? fromAcademicYear,
    String? toAcademicYear,
    double? totalFeesForYear,
    double? totalPaidForYear,
    double? arrearsAmount,
    double? paidAmount,
    double? remainingAmount,
    ArrearsStatus? status,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
  }) {
    return Arrears(
      id: id ?? this.id,
      schoolId: schoolId ?? this.schoolId,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      studentNumericId: studentNumericId ?? this.studentNumericId,
      className: className ?? this.className,
      section: section ?? this.section,
      fromAcademicYear: fromAcademicYear ?? this.fromAcademicYear,
      toAcademicYear: toAcademicYear ?? this.toAcademicYear,
      totalFeesForYear: totalFeesForYear ?? this.totalFeesForYear,
      totalPaidForYear: totalPaidForYear ?? this.totalPaidForYear,
      arrearsAmount: arrearsAmount ?? this.arrearsAmount,
      paidAmount: paidAmount ?? this.paidAmount,
      remainingAmount: remainingAmount ?? this.remainingAmount,
      status: status ?? this.status,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }

  @override
  String toString() => 'Arrears($studentName, $fromAcademicYear -> $toAcademicYear, ₹$remainingAmount)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Arrears && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
