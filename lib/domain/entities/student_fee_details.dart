import 'package:cloud_firestore/cloud_firestore.dart';

class StudentFeeDetails {
  final String id;
  final String schoolId;
  final String studentId;
  final String studentName;
  final String className;
  final String section;
  final String? phoneNumber;
  final String academicYear;
  
  // Total fees
  final double totalAdmissionFees;
  final double totalTuitionFees;
  final double totalExamFees;
  final double totalVanFees;
  final double totalFees;
  
  // Paid fees
  final double paidAdmissionFees;
  final double paidTuitionFees;
  final double paidExamFees;
  final double paidVanFees;
  final double paidTotalFees;
  
  // Balance fees
  final double balanceAdmissionFees;
  final double balanceTuitionFees;
  final double balanceExamFees;
  final double balanceVanFees;
  final double balanceTotalFees;
  
  // Arrears
  final double arrearTuitionFees;
  final double arrearExamFees;
  final double arrearAdmissionFees;
  final double arrearVanFees;
  final double paidArrearTuitionFees;
  final double paidArrearExamFees;
  final double paidArrearAdmissionFees;
  final double paidArrearVanFees;
  final double balanceArrearTuitionFees;
  final double balanceArrearExamFees;
  final double balanceArrearAdmissionFees;
  final double balanceArrearVanFees;
  
  // Concession
  final double concessionFees;
  
  // Van availability
  final bool isVanAvailed;
  
  // Bill details (JSON string)
  final String billDetails;
  
  final DateTime createdAt;
  final DateTime updatedAt;

  const StudentFeeDetails({
    required this.id,
    required this.schoolId,
    required this.studentId,
    required this.studentName,
    required this.className,
    required this.section,
    this.phoneNumber,
    required this.academicYear,
    this.totalAdmissionFees = 0.0,
    this.totalTuitionFees = 0.0,
    this.totalExamFees = 0.0,
    this.totalVanFees = 0.0,
    this.totalFees = 0.0,
    this.paidAdmissionFees = 0.0,
    this.paidTuitionFees = 0.0,
    this.paidExamFees = 0.0,
    this.paidVanFees = 0.0,
    this.paidTotalFees = 0.0,
    this.balanceAdmissionFees = 0.0,
    this.balanceTuitionFees = 0.0,
    this.balanceExamFees = 0.0,
    this.balanceVanFees = 0.0,
    this.balanceTotalFees = 0.0,
    this.arrearTuitionFees = 0.0,
    this.arrearExamFees = 0.0,
    this.arrearAdmissionFees = 0.0,
    this.arrearVanFees = 0.0,
    this.paidArrearTuitionFees = 0.0,
    this.paidArrearExamFees = 0.0,
    this.paidArrearAdmissionFees = 0.0,
    this.paidArrearVanFees = 0.0,
    this.balanceArrearTuitionFees = 0.0,
    this.balanceArrearExamFees = 0.0,
    this.balanceArrearAdmissionFees = 0.0,
    this.balanceArrearVanFees = 0.0,
    this.concessionFees = 0.0,
    this.isVanAvailed = false,
    this.billDetails = '[]',
    required this.createdAt,
    required this.updatedAt,
  });

  // Helper getters
  double get totalArrears => arrearTuitionFees + arrearExamFees + arrearAdmissionFees + arrearVanFees;
  double get totalPaidArrears => paidArrearTuitionFees + paidArrearExamFees + paidArrearAdmissionFees + paidArrearVanFees;
  double get totalBalanceArrears => balanceArrearTuitionFees + balanceArrearExamFees + balanceArrearAdmissionFees + balanceArrearVanFees;
  bool get hasArrears => totalArrears > 0;
  bool get hasPendingFees => balanceTotalFees > 0;

  factory StudentFeeDetails.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return StudentFeeDetails(
      id: doc.id,
      schoolId: data['schoolId'] as String? ?? '',
      studentId: data['studentId'] as String? ?? '',
      studentName: data['studentName'] as String? ?? '',
      className: data['className'] as String? ?? '',
      section: data['section'] as String? ?? '',
      phoneNumber: data['phoneNumber'] as String?,
      academicYear: data['academicYear'] as String? ?? '',
      totalAdmissionFees: (data['totalAdmissionFees'] as num?)?.toDouble() ?? 0.0,
      totalTuitionFees: (data['totalTuitionFees'] as num?)?.toDouble() ?? 0.0,
      totalExamFees: (data['totalExamFees'] as num?)?.toDouble() ?? 0.0,
      totalVanFees: (data['totalVanFees'] as num?)?.toDouble() ?? 0.0,
      totalFees: (data['totalFees'] as num?)?.toDouble() ?? 0.0,
      paidAdmissionFees: (data['paidAdmissionFees'] as num?)?.toDouble() ?? 0.0,
      paidTuitionFees: (data['paidTuitionFees'] as num?)?.toDouble() ?? 0.0,
      paidExamFees: (data['paidExamFees'] as num?)?.toDouble() ?? 0.0,
      paidVanFees: (data['paidVanFees'] as num?)?.toDouble() ?? 0.0,
      paidTotalFees: (data['paidTotalFees'] as num?)?.toDouble() ?? 0.0,
      balanceAdmissionFees: (data['balanceAdmissionFees'] as num?)?.toDouble() ?? 0.0,
      balanceTuitionFees: (data['balanceTuitionFees'] as num?)?.toDouble() ?? 0.0,
      balanceExamFees: (data['balanceExamFees'] as num?)?.toDouble() ?? 0.0,
      balanceVanFees: (data['balanceVanFees'] as num?)?.toDouble() ?? 0.0,
      balanceTotalFees: (data['balanceTotalFees'] as num?)?.toDouble() ?? 0.0,
      arrearTuitionFees: (data['arrearTuitionFees'] as num?)?.toDouble() ?? 0.0,
      arrearExamFees: (data['arrearExamFees'] as num?)?.toDouble() ?? 0.0,
      arrearAdmissionFees: (data['arrearAdmissionFees'] as num?)?.toDouble() ?? 0.0,
      arrearVanFees: (data['arrearVanFees'] as num?)?.toDouble() ?? 0.0,
      paidArrearTuitionFees: (data['paidArrearTuitionFees'] as num?)?.toDouble() ?? 0.0,
      paidArrearExamFees: (data['paidArrearExamFees'] as num?)?.toDouble() ?? 0.0,
      paidArrearAdmissionFees: (data['paidArrearAdmissionFees'] as num?)?.toDouble() ?? 0.0,
      paidArrearVanFees: (data['paidArrearVanFees'] as num?)?.toDouble() ?? 0.0,
      balanceArrearTuitionFees: (data['balanceArrearTuitionFees'] as num?)?.toDouble() ?? 0.0,
      balanceArrearExamFees: (data['balanceArrearExamFees'] as num?)?.toDouble() ?? 0.0,
      balanceArrearAdmissionFees: (data['balanceArrearAdmissionFees'] as num?)?.toDouble() ?? 0.0,
      balanceArrearVanFees: (data['balanceArrearVanFees'] as num?)?.toDouble() ?? 0.0,
      concessionFees: (data['concessionFees'] as num?)?.toDouble() ?? 0.0,
      isVanAvailed: data['isVanAvailed'] as bool? ?? false,
      billDetails: data['billDetails'] as String? ?? '[]',
      createdAt: _parseDateTime(data['createdAt']) ?? DateTime.now(),
      updatedAt: _parseDateTime(data['updatedAt']) ?? DateTime.now(),
    );
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
      'studentId': studentId,
      'studentName': studentName,
      'className': className,
      'section': section,
      'phoneNumber': phoneNumber,
      'academicYear': academicYear,
      'totalAdmissionFees': totalAdmissionFees,
      'totalTuitionFees': totalTuitionFees,
      'totalExamFees': totalExamFees,
      'totalVanFees': totalVanFees,
      'totalFees': totalFees,
      'paidAdmissionFees': paidAdmissionFees,
      'paidTuitionFees': paidTuitionFees,
      'paidExamFees': paidExamFees,
      'paidVanFees': paidVanFees,
      'paidTotalFees': paidTotalFees,
      'balanceAdmissionFees': balanceAdmissionFees,
      'balanceTuitionFees': balanceTuitionFees,
      'balanceExamFees': balanceExamFees,
      'balanceVanFees': balanceVanFees,
      'balanceTotalFees': balanceTotalFees,
      'arrearTuitionFees': arrearTuitionFees,
      'arrearExamFees': arrearExamFees,
      'arrearAdmissionFees': arrearAdmissionFees,
      'arrearVanFees': arrearVanFees,
      'paidArrearTuitionFees': paidArrearTuitionFees,
      'paidArrearExamFees': paidArrearExamFees,
      'paidArrearAdmissionFees': paidArrearAdmissionFees,
      'paidArrearVanFees': paidArrearVanFees,
      'balanceArrearTuitionFees': balanceArrearTuitionFees,
      'balanceArrearExamFees': balanceArrearExamFees,
      'balanceArrearAdmissionFees': balanceArrearAdmissionFees,
      'balanceArrearVanFees': balanceArrearVanFees,
      'concessionFees': concessionFees,
      'isVanAvailed': isVanAvailed,
      'billDetails': billDetails,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
