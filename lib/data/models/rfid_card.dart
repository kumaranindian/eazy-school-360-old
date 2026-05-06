class RfidCard {
  final String rfidTag;
  final String schoolId;
  final bool isAssigned;
  final String? staffId;
  final String? studentId;
  final String? staffName;
  final String? studentName;
  final DateTime? registeredAt;
  final DateTime? assignedAt;
  final bool isActive;

  RfidCard({
    required this.rfidTag,
    required this.schoolId,
    required this.isAssigned,
    this.staffId,
    this.studentId,
    this.staffName,
    this.studentName,
    this.registeredAt,
    this.assignedAt,
    required this.isActive,
  });

  factory RfidCard.fromJson(Map<String, dynamic> json) {
    return RfidCard(
      rfidTag: json['rfidTag'] as String,
      schoolId: json['schoolId'] as String,
      isAssigned: json['isAssigned'] as bool? ?? false,
      staffId: json['staffId'] as String?,
      studentId: json['studentId'] as String?,
      staffName: json['staffName'] as String?,
      studentName: json['studentName'] as String?,
      registeredAt: json['registeredAt'] != null 
          ? DateTime.parse(json['registeredAt'] as String) 
          : null,
      assignedAt: json['assignedAt'] != null 
          ? DateTime.parse(json['assignedAt'] as String) 
          : null,
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'rfidTag': rfidTag,
      'schoolId': schoolId,
      'isAssigned': isAssigned,
      'staffId': staffId,
      'studentId': studentId,
      'staffName': staffName,
      'studentName': studentName,
      'registeredAt': registeredAt?.toIso8601String(),
      'assignedAt': assignedAt?.toIso8601String(),
      'isActive': isActive,
    };
  }

  String get assignedPersonName {
    if (staffName != null) return staffName!;
    if (studentName != null) return studentName!;
    return 'Unassigned';
  }

  String get assignmentType {
    if (staffId != null) return 'Staff';
    if (studentId != null) return 'Student';
    return 'Unassigned';
  }
}
