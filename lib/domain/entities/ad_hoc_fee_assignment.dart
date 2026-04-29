import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a bulk fee assignment for ad-hoc or event-based fees.
/// This allows admins to assign fees to multiple students at once.
///
/// Examples:
/// - Sports Day fee for all students in Class I
/// - Annual Day fee for all students in the school
/// - Lab fee for Class X Science students only
class AdHocFeeAssignment {
  final String id;
  final String schoolId;
  final String academicYear;

  /// Fee category code (e.g., 'SPORTS_DAY', 'ANNUAL_DAY', 'LAB_FEE')
  final String categoryCode;

  /// Display name for this assignment (e.g., 'Sports Day 2026', 'Annual Day Fee')
  final String assignmentName;

  /// Description of this assignment
  final String description;

  /// Amount to be assigned
  final double amount;

  /// Due date for this fee
  final DateTime dueDate;

  /// Assignment scope: 'school', 'class', 'section', 'custom'
  final String scope;

  /// List of class IDs if scope is 'class'
  final List<String> classIds;

  /// List of section names if scope is 'section'
  final List<String> sections;

  /// List of specific student IDs if scope is 'custom'
  final List<String> studentIds;

  /// Number of students this assignment applies to
  final int studentCount;

  /// Number of students who have been assigned
  final int assignedCount;

  /// Total amount across all students
  final double totalAmount;

  /// Who created this assignment
  final String? createdBy;

  /// When this assignment was created
  final DateTime? createdAt;

  /// Status: 'draft', 'active', 'completed', 'cancelled'
  final String status;

  /// Optional notes
  final String? notes;

  /// Updated timestamp
  final DateTime? updatedAt;

  const AdHocFeeAssignment({
    required this.id,
    required this.schoolId,
    required this.academicYear,
    required this.categoryCode,
    required this.assignmentName,
    this.description = '',
    required this.amount,
    required this.dueDate,
    this.scope = 'school',
    this.classIds = const [],
    this.sections = const [],
    this.studentIds = const [],
    this.studentCount = 0,
    this.assignedCount = 0,
    this.totalAmount = 0,
    this.createdBy,
    this.createdAt,
    this.status = 'draft',
    this.notes,
    this.updatedAt,
  });

  factory AdHocFeeAssignment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AdHocFeeAssignment.fromMap(doc.id, data);
  }

  factory AdHocFeeAssignment.fromMap(String id, Map<String, dynamic> data) {
    return AdHocFeeAssignment(
      id: id,
      schoolId: data['schoolId']?.toString() ?? '',
      academicYear: data['academicYear']?.toString() ?? '',
      categoryCode: data['categoryCode']?.toString() ?? '',
      assignmentName: data['assignmentName']?.toString() ?? '',
      description: data['description']?.toString() ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      dueDate: _parseDate(data['dueDate']) ?? DateTime.now(),
      scope: data['scope']?.toString() ?? 'school',
      classIds: (data['classIds'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      sections: (data['sections'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      studentIds: (data['studentIds'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      studentCount: (data['studentCount'] as num?)?.toInt() ?? 0,
      assignedCount: (data['assignedCount'] as num?)?.toInt() ?? 0,
      totalAmount: (data['totalAmount'] as num?)?.toDouble() ?? 0,
      createdBy: data['createdBy']?.toString(),
      createdAt: _parseDate(data['createdAt']),
      status: data['status']?.toString() ?? 'draft',
      notes: data['notes']?.toString(),
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
        'academicYear': academicYear,
        'categoryCode': categoryCode,
        'assignmentName': assignmentName,
        'description': description,
        'amount': amount,
        'dueDate': Timestamp.fromDate(dueDate),
        'scope': scope,
        'classIds': classIds,
        'sections': sections,
        'studentIds': studentIds,
        'studentCount': studentCount,
        'assignedCount': assignedCount,
        'totalAmount': totalAmount,
        if (createdBy != null) 'createdBy': createdBy,
        if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
        'status': status,
        if (notes != null) 'notes': notes,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  AdHocFeeAssignment copyWith({
    String? id,
    String? schoolId,
    String? academicYear,
    String? categoryCode,
    String? assignmentName,
    String? description,
    double? amount,
    DateTime? dueDate,
    String? scope,
    List<String>? classIds,
    List<String>? sections,
    List<String>? studentIds,
    int? studentCount,
    int? assignedCount,
    double? totalAmount,
    String? createdBy,
    DateTime? createdAt,
    String? status,
    String? notes,
    DateTime? updatedAt,
  }) =>
      AdHocFeeAssignment(
        id: id ?? this.id,
        schoolId: schoolId ?? this.schoolId,
        academicYear: academicYear ?? this.academicYear,
        categoryCode: categoryCode ?? this.categoryCode,
        assignmentName: assignmentName ?? this.assignmentName,
        description: description ?? this.description,
        amount: amount ?? this.amount,
        dueDate: dueDate ?? this.dueDate,
        scope: scope ?? this.scope,
        classIds: classIds ?? this.classIds,
        sections: sections ?? this.sections,
        studentIds: studentIds ?? this.studentIds,
        studentCount: studentCount ?? this.studentCount,
        assignedCount: assignedCount ?? this.assignedCount,
        totalAmount: totalAmount ?? this.totalAmount,
        createdBy: createdBy ?? this.createdBy,
        createdAt: createdAt ?? this.createdAt,
        status: status ?? this.status,
        notes: notes ?? this.notes,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  /// Check if assignment is complete
  bool get isComplete => assignedCount >= studentCount && studentCount > 0;

  /// Check if assignment is active
  bool get isActive => status == 'active';

  /// Get completion percentage
  double get completionPercentage =>
      studentCount > 0 ? (assignedCount / studentCount) * 100 : 0;
}
