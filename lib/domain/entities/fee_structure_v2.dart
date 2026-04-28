import 'package:cloud_firestore/cloud_firestore.dart';

import 'fee_term.dart';

enum FeeStructureType { YEARLY, TERM_WISE, MONTHLY, CUSTOM }

class FeeStructureV2 {
  final String id;
  final String schoolId;
  final String name;
  final String academicYear;
  final FeeStructureType type;
  final double totalAmount;
  final String currency;
  final int termCount;
  final List<String> applicableToClassIds;
  final bool isActive;
  final bool isDefault;
  final List<FeeTerm> terms; // hydrated client-side from subcollection
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const FeeStructureV2({
    required this.id,
    required this.schoolId,
    required this.name,
    required this.academicYear,
    this.type = FeeStructureType.TERM_WISE,
    this.totalAmount = 0,
    this.currency = 'INR',
    this.termCount = 0,
    this.applicableToClassIds = const [],
    this.isActive = true,
    this.isDefault = false,
    this.terms = const [],
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory FeeStructureV2.fromFirestore(DocumentSnapshot doc, {List<FeeTerm> terms = const []}) {
    final data = doc.data() as Map<String, dynamic>;
    return FeeStructureV2(
      id: doc.id,
      schoolId: data['schoolId']?.toString() ?? '',
      name: data['name']?.toString() ?? '',
      academicYear: data['academicYear']?.toString() ?? '',
      type: _parseType(data['type']),
      totalAmount: (data['totalAmount'] as num?)?.toDouble() ?? 0,
      currency: data['currency']?.toString() ?? 'INR',
      termCount: (data['termCount'] as num?)?.toInt() ?? 0,
      applicableToClassIds:
          (data['applicableToClassIds'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      isActive: data['isActive'] as bool? ?? true,
      isDefault: data['isDefault'] as bool? ?? false,
      terms: terms,
      createdBy: data['createdBy']?.toString(),
      createdAt: _parseDate(data['createdAt']) ?? DateTime.now(),
      updatedAt: _parseDate(data['updatedAt']) ?? DateTime.now(),
    );
  }

  static FeeStructureType _parseType(dynamic v) {
    final s = v?.toString().toUpperCase() ?? 'TERM_WISE';
    return FeeStructureType.values.firstWhere(
      (e) => e.name == s,
      orElse: () => FeeStructureType.TERM_WISE,
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
        'name': name,
        'academicYear': academicYear,
        'type': type.name,
        'totalAmount': totalAmount,
        'currency': currency,
        'termCount': termCount,
        'applicableToClassIds': applicableToClassIds,
        'isActive': isActive,
        'isDefault': isDefault,
        'createdBy': createdBy,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      };

  FeeStructureV2 copyWith({
    String? id,
    String? schoolId,
    String? name,
    String? academicYear,
    FeeStructureType? type,
    double? totalAmount,
    String? currency,
    int? termCount,
    List<String>? applicableToClassIds,
    bool? isActive,
    bool? isDefault,
    List<FeeTerm>? terms,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      FeeStructureV2(
        id: id ?? this.id,
        schoolId: schoolId ?? this.schoolId,
        name: name ?? this.name,
        academicYear: academicYear ?? this.academicYear,
        type: type ?? this.type,
        totalAmount: totalAmount ?? this.totalAmount,
        currency: currency ?? this.currency,
        termCount: termCount ?? this.termCount,
        applicableToClassIds: applicableToClassIds ?? this.applicableToClassIds,
        isActive: isActive ?? this.isActive,
        isDefault: isDefault ?? this.isDefault,
        terms: terms ?? this.terms,
        createdBy: createdBy ?? this.createdBy,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
