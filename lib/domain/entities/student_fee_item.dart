import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a single fee item assigned to a student for a specific category.
/// This is the new category-based fee tracking system that replaces term-based ledgers.
///
/// Examples:
/// - Tuition fee for June 2026
/// - Exam fee for the year
/// - Sports Day event fee
/// - Van fee for the academic year
///
/// Assignment levels:
/// - Class-wise: All students in a class get the same amount
/// - Student-wise: Individual student gets specific amount
/// - School-wide: All students get the same amount
class StudentFeeItem {
  final String id;
  final String schoolId;
  final String studentId;
  final String studentName;
  final String className;
  final String section;
  final String academicYear;

  /// Fee category code (e.g., 'TUITION', 'EXAM', 'VAN', 'SPORTS_DAY')
  final String categoryCode;

  /// Display name for this fee item (e.g., 'June Tuition', 'Exam Fee 2026-2027', 'Sports Day Fee')
  final String itemName;

  /// Total amount for this fee item
  final double amount;

  /// Amount paid so far
  final double paidAmount;

  /// Balance amount (amount - paidAmount)
  final double balanceAmount;

  /// Due date for this fee
  final DateTime dueDate;

  /// Source of this fee item
  /// - 'fee_structure': From fee structure assignment
  /// - 'ad_hoc': Manually assigned by admin
  /// - 'event': Event-based fee (Sports Day, Annual Day, etc.)
  final String source;

  /// ID of the fee structure if source is 'fee_structure'
  final String? feeStructureId;

  /// ID of the ad-hoc assignment if source is 'ad_hoc' or 'event'
  final String? adHocAssignmentId;

  /// Assignment level: 'class', 'student', 'school'
  final String assignmentLevel;

  /// Who assigned this fee
  final String? assignedBy;

  /// When this fee was assigned
  final DateTime? assignedAt;

  /// Optional notes
  final String? notes;

  /// Whether this item is active
  final bool isActive;

  /// Created timestamp
  final DateTime? createdAt;

  /// Updated timestamp
  final DateTime? updatedAt;

  const StudentFeeItem({
    required this.id,
    required this.schoolId,
    required this.studentId,
    required this.studentName,
    required this.className,
    required this.section,
    required this.academicYear,
    required this.categoryCode,
    required this.itemName,
    required this.amount,
    this.paidAmount = 0,
    this.balanceAmount = 0,
    required this.dueDate,
    this.source = 'ad_hoc',
    this.feeStructureId,
    this.adHocAssignmentId,
    this.assignmentLevel = 'student',
    this.assignedBy,
    this.assignedAt,
    this.notes,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  factory StudentFeeItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return StudentFeeItem.fromMap(doc.id, data);
  }

  factory StudentFeeItem.fromMap(String id, Map<String, dynamic> data) {
    return StudentFeeItem(
      id: id,
      schoolId: data['schoolId']?.toString() ?? '',
      studentId: data['studentId']?.toString() ?? '',
      studentName: data['studentName']?.toString() ?? '',
      className: data['className']?.toString() ?? '',
      section: data['section']?.toString() ?? '',
      academicYear: data['academicYear']?.toString() ?? '',
      categoryCode: data['categoryCode']?.toString() ?? '',
      itemName: data['itemName']?.toString() ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      paidAmount: (data['paidAmount'] as num?)?.toDouble() ?? 0,
      balanceAmount: (data['balanceAmount'] as num?)?.toDouble() ?? 0,
      dueDate: _parseDate(data['dueDate']) ?? DateTime.now(),
      source: data['source']?.toString() ?? 'ad_hoc',
      feeStructureId: data['feeStructureId']?.toString(),
      adHocAssignmentId: data['adHocAssignmentId']?.toString(),
      assignmentLevel: data['assignmentLevel']?.toString() ?? 'student',
      assignedBy: data['assignedBy']?.toString(),
      assignedAt: _parseDate(data['assignedAt']),
      notes: data['notes']?.toString(),
      isActive: data['isActive'] as bool? ?? true,
      createdAt: _parseDate(data['createdAt']),
      updatedAt: _parseDate(data['updatedAt']),
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  Map<String, dynamic> toFirestore() => {
        'schoolId': schoolId,
        'studentId': studentId,
        'studentName': studentName,
        'className': className,
        'section': section,
        'academicYear': academicYear,
        'categoryCode': categoryCode,
        'itemName': itemName,
        'amount': amount,
        'paidAmount': paidAmount,
        'balanceAmount': balanceAmount,
        'dueDate': Timestamp.fromDate(dueDate),
        'source': source,
        if (feeStructureId != null) 'feeStructureId': feeStructureId,
        if (adHocAssignmentId != null) 'adHocAssignmentId': adHocAssignmentId,
        'assignmentLevel': assignmentLevel,
        if (assignedBy != null) 'assignedBy': assignedBy,
        if (assignedAt != null) 'assignedAt': Timestamp.fromDate(assignedAt!),
        if (notes != null) 'notes': notes,
        'isActive': isActive,
        if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
        'updatedAt': FieldValue.serverTimestamp(),
      };

  StudentFeeItem copyWith({
    String? id,
    String? schoolId,
    String? studentId,
    String? studentName,
    String? className,
    String? section,
    String? academicYear,
    String? categoryCode,
    String? itemName,
    double? amount,
    double? paidAmount,
    double? balanceAmount,
    DateTime? dueDate,
    String? source,
    String? feeStructureId,
    String? adHocAssignmentId,
    String? assignmentLevel,
    String? assignedBy,
    DateTime? assignedAt,
    String? notes,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      StudentFeeItem(
        id: id ?? this.id,
        schoolId: schoolId ?? this.schoolId,
        studentId: studentId ?? this.studentId,
        studentName: studentName ?? this.studentName,
        className: className ?? this.className,
        section: section ?? this.section,
        academicYear: academicYear ?? this.academicYear,
        categoryCode: categoryCode ?? this.categoryCode,
        itemName: itemName ?? this.itemName,
        amount: amount ?? this.amount,
        paidAmount: paidAmount ?? this.paidAmount,
        balanceAmount: balanceAmount ?? this.balanceAmount,
        dueDate: dueDate ?? this.dueDate,
        source: source ?? this.source,
        feeStructureId: feeStructureId ?? this.feeStructureId,
        adHocAssignmentId: adHocAssignmentId ?? this.adHocAssignmentId,
        assignmentLevel: assignmentLevel ?? this.assignmentLevel,
        assignedBy: assignedBy ?? this.assignedBy,
        assignedAt: assignedAt ?? this.assignedAt,
        notes: notes ?? this.notes,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  /// Record a payment against this fee item
  StudentFeeItem recordPayment(double paymentAmount) {
    final newPaid = paidAmount + paymentAmount;
    final newBalance = amount - newPaid;
    return copyWith(
      paidAmount: newPaid,
      balanceAmount: newBalance > 0 ? newBalance : 0,
    );
  }

  /// Check if this fee item is fully paid
  bool get isFullyPaid => balanceAmount <= 0.001;

  /// Check if this fee item is overdue
  bool get isOverdue => !isFullyPaid && DateTime.now().isAfter(dueDate);
}
