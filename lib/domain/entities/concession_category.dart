import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a concession category that can be applied to students.
/// Examples: RTE (Right To Education), Staff Ward, Sibling Discount, Merit Scholarship, etc.
class ConcessionCategory {
  final String id;
  final String code;
  final String name;
  final String description;
  final bool isDefault; // System default categories like RTE
  final bool isActive;
  final int sortOrder;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ConcessionCategory({
    required this.id,
    required this.code,
    required this.name,
    this.description = '',
    this.isDefault = false,
    this.isActive = true,
    this.sortOrder = 100,
    this.createdAt,
    this.updatedAt,
  });

  /// Default concession categories that every school starts with
  static const List<ConcessionCategory> defaults = [
    ConcessionCategory(
      id: 'RTE',
      code: 'RTE',
      name: 'RTE (Right To Education)',
      description: 'Government mandated free education under RTE Act',
      isDefault: true,
      sortOrder: 10,
    ),
    ConcessionCategory(
      id: 'STAFF_WARD',
      code: 'STAFF_WARD',
      name: 'Staff Ward',
      description: 'Concession for children of school staff',
      isDefault: true,
      sortOrder: 20,
    ),
    ConcessionCategory(
      id: 'SIBLING',
      code: 'SIBLING',
      name: 'Sibling Discount',
      description: 'Discount for siblings studying in the same school',
      isDefault: true,
      sortOrder: 30,
    ),
    ConcessionCategory(
      id: 'MERIT',
      code: 'MERIT',
      name: 'Merit Scholarship',
      description: 'Scholarship based on academic merit',
      isDefault: true,
      sortOrder: 40,
    ),
    ConcessionCategory(
      id: 'ECONOMICALLY_WEAKER',
      code: 'ECONOMICALLY_WEAKER',
      name: 'Economically Weaker Section',
      description: 'Concession for economically weaker families',
      isDefault: true,
      sortOrder: 50,
    ),
    ConcessionCategory(
      id: 'SPORTS',
      code: 'SPORTS',
      name: 'Sports Quota',
      description: 'Concession for students with sports achievements',
      isDefault: true,
      sortOrder: 60,
    ),
  ];

  factory ConcessionCategory.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ConcessionCategory.fromMap(doc.id, data);
  }

  factory ConcessionCategory.fromMap(String id, Map<String, dynamic> data) {
    return ConcessionCategory(
      id: id,
      code: data['code']?.toString() ?? id,
      name: data['name']?.toString() ?? id,
      description: data['description']?.toString() ?? '',
      isDefault: data['isDefault'] as bool? ?? false,
      isActive: data['isActive'] as bool? ?? true,
      sortOrder: (data['sortOrder'] as num?)?.toInt() ?? 100,
      createdAt: _parseDate(data['createdAt']),
      updatedAt: _parseDate(data['updatedAt']),
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
        'code': code,
        'name': name,
        'description': description,
        'isDefault': isDefault,
        'isActive': isActive,
        'sortOrder': sortOrder,
        if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
        'updatedAt': FieldValue.serverTimestamp(),
      };

  ConcessionCategory copyWith({
    String? id,
    String? code,
    String? name,
    String? description,
    bool? isDefault,
    bool? isActive,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      ConcessionCategory(
        id: id ?? this.id,
        code: code ?? this.code,
        name: name ?? this.name,
        description: description ?? this.description,
        isDefault: isDefault ?? this.isDefault,
        isActive: isActive ?? this.isActive,
        sortOrder: sortOrder ?? this.sortOrder,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
