import 'package:cloud_firestore/cloud_firestore.dart';

class PermissionType {
  final String id;
  final String schoolId;
  final String name;
  final int defaultLimit;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PermissionType({
    required this.id,
    required this.schoolId,
    required this.name,
    required this.defaultLimit,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PermissionType.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return PermissionType(
      id: doc.id,
      schoolId: data['schoolId'] as String? ?? '',
      name: data['name'] as String? ?? '',
      defaultLimit: data['defaultLimit'] as int? ?? 0,
      isActive: data['isActive'] as bool? ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'schoolId': schoolId,
      'name': name,
      'defaultLimit': defaultLimit,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  PermissionType copyWith({
    String? id,
    String? schoolId,
    String? name,
    int? defaultLimit,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PermissionType(
      id: id ?? this.id,
      schoolId: schoolId ?? this.schoolId,
      name: name ?? this.name,
      defaultLimit: defaultLimit ?? this.defaultLimit,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PermissionType && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

class CreatePermissionTypeRequest {
  final String name;
  final int defaultLimit;

  const CreatePermissionTypeRequest({
    required this.name,
    required this.defaultLimit,
  });
}

class UpdatePermissionTypeRequest {
  final String? name;
  final int? defaultLimit;
  final bool? isActive;

  const UpdatePermissionTypeRequest({
    this.name,
    this.defaultLimit,
    this.isActive,
  });
}
