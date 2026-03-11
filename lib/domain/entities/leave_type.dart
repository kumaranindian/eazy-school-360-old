import 'package:cloud_firestore/cloud_firestore.dart';

class LeaveType {
  final String id;
  final String schoolId;
  final String name;
  final int defaultBalance;
  final bool isPaid;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const LeaveType({
    required this.id,
    required this.schoolId,
    required this.name,
    required this.defaultBalance,
    required this.isPaid,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory LeaveType.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return LeaveType(
      id: doc.id,
      schoolId: data['schoolId'] as String? ?? '',
      name: data['name'] as String? ?? '',
      defaultBalance: data['defaultBalance'] as int? ?? 0,
      isPaid: data['isPaid'] as bool? ?? false,
      isActive: data['isActive'] as bool? ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'schoolId': schoolId,
      'name': name,
      'defaultBalance': defaultBalance,
      'isPaid': isPaid,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  LeaveType copyWith({
    String? id,
    String? schoolId,
    String? name,
    int? defaultBalance,
    bool? isPaid,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return LeaveType(
      id: id ?? this.id,
      schoolId: schoolId ?? this.schoolId,
      name: name ?? this.name,
      defaultBalance: defaultBalance ?? this.defaultBalance,
      isPaid: isPaid ?? this.isPaid,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LeaveType && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

class CreateLeaveTypeRequest {
  final String name;
  final int defaultBalance;
  final bool isPaid;

  const CreateLeaveTypeRequest({
    required this.name,
    required this.defaultBalance,
    required this.isPaid,
  });
}

class UpdateLeaveTypeRequest {
  final String? name;
  final int? defaultBalance;
  final bool? isPaid;
  final bool? isActive;

  const UpdateLeaveTypeRequest({
    this.name,
    this.defaultBalance,
    this.isPaid,
    this.isActive,
  });
}
