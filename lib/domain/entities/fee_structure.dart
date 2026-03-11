import 'package:cloud_firestore/cloud_firestore.dart';

class FeeStructure {
  final String id;
  final String schoolId;
  final String className;
  final String academicYear;
  final double tuitionFees;
  final double examFees;
  final double admissionFees;
  final double vanFees;
  final double totalFees;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? createdBy;

  const FeeStructure({
    required this.id,
    required this.schoolId,
    required this.className,
    required this.academicYear,
    required this.tuitionFees,
    required this.examFees,
    required this.admissionFees,
    required this.vanFees,
    required this.totalFees,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy,
  });

  factory FeeStructure.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FeeStructure(
      id: doc.id,
      schoolId: data['schoolId'] as String? ?? '',
      className: data['className'] as String? ?? '',
      academicYear: data['academicYear'] as String? ?? '',
      tuitionFees: (data['tuitionFees'] as num?)?.toDouble() ?? 0.0,
      examFees: (data['examFees'] as num?)?.toDouble() ?? 0.0,
      admissionFees: (data['admissionFees'] as num?)?.toDouble() ?? 0.0,
      vanFees: (data['vanFees'] as num?)?.toDouble() ?? 0.0,
      totalFees: (data['totalFees'] as num?)?.toDouble() ?? 0.0,
      isActive: data['isActive'] as bool? ?? true,
      createdAt: _parseDateTime(data['createdAt']) ?? DateTime.now(),
      updatedAt: _parseDateTime(data['updatedAt']) ?? DateTime.now(),
      createdBy: data['createdBy'] as String?,
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
      'className': className,
      'academicYear': academicYear,
      'tuitionFees': tuitionFees,
      'examFees': examFees,
      'admissionFees': admissionFees,
      'vanFees': vanFees,
      'totalFees': totalFees,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'createdBy': createdBy,
    };
  }

  FeeStructure copyWith({
    String? id,
    String? schoolId,
    String? className,
    String? academicYear,
    double? tuitionFees,
    double? examFees,
    double? admissionFees,
    double? vanFees,
    double? totalFees,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
  }) {
    return FeeStructure(
      id: id ?? this.id,
      schoolId: schoolId ?? this.schoolId,
      className: className ?? this.className,
      academicYear: academicYear ?? this.academicYear,
      tuitionFees: tuitionFees ?? this.tuitionFees,
      examFees: examFees ?? this.examFees,
      admissionFees: admissionFees ?? this.admissionFees,
      vanFees: vanFees ?? this.vanFees,
      totalFees: totalFees ?? this.totalFees,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }
}
