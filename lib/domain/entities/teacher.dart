import 'package:cloud_firestore/cloud_firestore.dart';

enum TeacherRole {
  teacher('Teacher'),
  hod('HOD');

  const TeacherRole(this.displayName);
  final String displayName;

  static TeacherRole fromString(String value) {
    return TeacherRole.values.firstWhere(
      (role) => role.name == value.toLowerCase(),
      orElse: () => TeacherRole.teacher,
    );
  }
}

class Teacher {
  final String teacherId;
  final String schoolId;
  final String name;
  final String email;
  final String phone;
  final TeacherRole role;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, int> leaveBalances;
  final Map<String, int> permissionLimits;

  const Teacher({
    required this.teacherId,
    required this.schoolId,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    required this.leaveBalances,
    required this.permissionLimits,
  });

  factory Teacher.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return Teacher(
      teacherId: doc.id,
      schoolId: data['schoolId'] as String? ?? '',
      name: data['name'] as String? ?? '',
      email: data['email'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      role: TeacherRole.fromString(data['role'] as String? ?? 'teacher'),
      isActive: data['isActive'] as bool? ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      leaveBalances: Map<String, int>.from(data['leaveBalances'] as Map<String, dynamic>? ?? {}),
      permissionLimits: Map<String, int>.from(data['permissionLimits'] as Map<String, dynamic>? ?? {}),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'schoolId': schoolId,
      'name': name,
      'email': email,
      'phone': phone,
      'role': role.name,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'leaveBalances': leaveBalances,
      'permissionLimits': permissionLimits,
    };
  }

  Teacher copyWith({
    String? teacherId,
    String? schoolId,
    String? name,
    String? email,
    String? phone,
    TeacherRole? role,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, int>? leaveBalances,
    Map<String, int>? permissionLimits,
  }) {
    return Teacher(
      teacherId: teacherId ?? this.teacherId,
      schoolId: schoolId ?? this.schoolId,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      leaveBalances: leaveBalances ?? this.leaveBalances,
      permissionLimits: permissionLimits ?? this.permissionLimits,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Teacher && other.teacherId == teacherId;
  }

  @override
  int get hashCode => teacherId.hashCode;
}

class CreateTeacherRequest {
  final String name;
  final String email;
  final String phone;
  final TeacherRole role;

  const CreateTeacherRequest({
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
  });
}

class UpdateTeacherRequest {
  final String? name;
  final String? email;
  final String? phone;
  final TeacherRole? role;
  final bool? isActive;

  const UpdateTeacherRequest({
    this.name,
    this.email,
    this.phone,
    this.role,
    this.isActive,
  });
}
