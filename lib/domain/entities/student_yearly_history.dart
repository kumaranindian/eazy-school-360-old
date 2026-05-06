import 'package:cloud_firestore/cloud_firestore.dart';

/// Per-academic-year snapshot of a student's class, fees and balances.
///
/// Stored at `schools/{schoolId}/students/{studentId}/yearly_history/{academicYear}`.
/// This is the source of truth for "what class was the student in during
/// academic year X, and what fees did they owe/pay that year".
///
/// The document id is the academic year code (e.g. `2025-2026`) so lookups
/// are trivial.
class StudentYearlyHistory {
  final String id; // academicYear code, also the doc id
  final String schoolId;
  final String studentId; // Firestore doc id of the student
  final String studentDocId; // Firestore doc id (duplicate for compatibility)
  final String studentNumericId; // Numeric student ID (e.g., "149")
  final String studentName;

  final String academicYear; // e.g. "2025-2026"
  final String className;
  final String section;

  // Fee structure applied for this student this year
  final double totalFees;
  final double totalAdmissionFees;
  final double totalTuitionFees;
  final double totalExamFees;
  final double totalVanFees;

  // Fees actually paid within this AY
  final double paidAdmissionFees;
  final double paidTuitionFees;
  final double paidExamFees;
  final double paidVanFees;
  final double paidTotalFees;

  // Arrears carried into this AY from previous years
  final double arrearsCarriedIn;
  // Arrears paid in this AY (regardless of originating year)
  final double arrearsPaid;
  // Unpaid balance at EOY (what carries forward as next year's arrears)
  final double balanceAtEndOfYear;

  final bool isCurrent;
  final DateTime? promotedOn; // set when student was promoted out of this year
  final DateTime createdAt;
  final DateTime updatedAt;

  const StudentYearlyHistory({
    required this.id,
    required this.schoolId,
    required this.studentId,
    required this.studentDocId,
    required this.studentNumericId,
    required this.studentName,
    required this.academicYear,
    required this.className,
    required this.section,
    this.totalFees = 0.0,
    this.totalAdmissionFees = 0.0,
    this.totalTuitionFees = 0.0,
    this.totalExamFees = 0.0,
    this.totalVanFees = 0.0,
    this.paidAdmissionFees = 0.0,
    this.paidTuitionFees = 0.0,
    this.paidExamFees = 0.0,
    this.paidVanFees = 0.0,
    this.paidTotalFees = 0.0,
    this.arrearsCarriedIn = 0.0,
    this.arrearsPaid = 0.0,
    this.balanceAtEndOfYear = 0.0,
    this.isCurrent = false,
    this.promotedOn,
    required this.createdAt,
    required this.updatedAt,
  });

  factory StudentYearlyHistory.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    double n(String k) => (data[k] as num?)?.toDouble() ?? 0.0;
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is Timestamp) return v.toDate();
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
      if (v is String) return DateTime.tryParse(v);
      return null;
    }

    return StudentYearlyHistory(
      id: doc.id,
      schoolId: data['schoolId'] as String? ?? '',
      studentId: data['studentDocId'] as String? ?? data['studentId'] as String? ?? '',
      studentDocId: data['studentDocId'] as String? ?? '',
      studentNumericId: data['studentNumericId']?.toString() ?? '',
      studentName: data['studentName'] as String? ?? '',
      academicYear: data['academicYear'] as String? ?? doc.id,
      className: data['className'] as String? ?? '',
      section: data['section'] as String? ?? '',
      totalFees: n('totalFees'),
      totalAdmissionFees: n('totalAdmissionFees'),
      totalTuitionFees: n('totalTuitionFees'),
      totalExamFees: n('totalExamFees'),
      totalVanFees: n('totalVanFees'),
      paidAdmissionFees: n('paidAdmissionFees'),
      paidTuitionFees: n('paidTuitionFees'),
      paidExamFees: n('paidExamFees'),
      paidVanFees: n('paidVanFees'),
      paidTotalFees: n('paidTotalFees'),
      arrearsCarriedIn: n('arrearsCarriedIn'),
      arrearsPaid: n('arrearsPaid'),
      balanceAtEndOfYear: n('balanceAtEndOfYear'),
      isCurrent: data['isCurrent'] as bool? ?? false,
      promotedOn: parseDate(data['promotedOn']),
      createdAt: parseDate(data['createdAt']) ?? DateTime.now(),
      updatedAt: parseDate(data['updatedAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'schoolId': schoolId,
        'studentDocId': studentDocId,
        'studentNumericId': studentNumericId,
        'studentName': studentName,
        'academicYear': academicYear,
        'className': className,
        'section': section,
        'totalFees': totalFees,
        'totalAdmissionFees': totalAdmissionFees,
        'totalTuitionFees': totalTuitionFees,
        'totalExamFees': totalExamFees,
        'totalVanFees': totalVanFees,
        'paidAdmissionFees': paidAdmissionFees,
        'paidTuitionFees': paidTuitionFees,
        'paidExamFees': paidExamFees,
        'paidVanFees': paidVanFees,
        'paidTotalFees': paidTotalFees,
        'arrearsCarriedIn': arrearsCarriedIn,
        'arrearsPaid': arrearsPaid,
        'balanceAtEndOfYear': balanceAtEndOfYear,
        'isCurrent': isCurrent,
        if (promotedOn != null) 'promotedOn': Timestamp.fromDate(promotedOn!),
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      };
}
