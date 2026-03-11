import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:eazy_school_360/domain/entities/app_user.dart';

class StaffProfile {
  final String id;
  final String userId; // Reference to users collection
  final String schoolId;
  final String name;
  final String employeeId; // Unique per school
  final String email;
  final String department;
  final StaffType staffType;
  final UserStatus status;
  final DateTime joiningDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;
  final String? phoneNumber;
  final String? address;
  final String? emergencyContact;
  final String? designation;
  final bool isClassTeacher;
  final String? assignedClass;
  final String? assignedSection;

  const StaffProfile({
    required this.id,
    required this.userId,
    required this.schoolId,
    required this.name,
    required this.employeeId,
    required this.email,
    required this.department,
    required this.staffType,
    required this.status,
    required this.joiningDate,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
    this.phoneNumber,
    this.address,
    this.emergencyContact,
    this.designation,
    this.isClassTeacher = false,
    this.assignedClass,
    this.assignedSection,
  });

  factory StaffProfile.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final now = DateTime.now();
    return StaffProfile(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      schoolId: data['schoolId'] as String? ?? '',
      name: data['name'] as String? ?? 'Unknown',
      employeeId: data['employeeId'] as String? ?? '',
      email: data['email'] as String? ?? '',
      department: data['department'] as String? ?? 'General',
      staffType: _parseStaffType(data['staffType']),
      status: _parseStatus(data['status']),
      joiningDate: data['joiningDate'] != null 
          ? (data['joiningDate'] as Timestamp).toDate() 
          : now,
      createdAt: data['createdAt'] != null 
          ? (data['createdAt'] as Timestamp).toDate() 
          : now,
      updatedAt: data['updatedAt'] != null 
          ? (data['updatedAt'] as Timestamp).toDate() 
          : now,
      createdBy: data['createdBy'] as String? ?? 'system',
      phoneNumber: data['phoneNumber'] as String?,
      address: data['address'] as String?,
      emergencyContact: data['emergencyContact'] as String?,
      designation: data['designation'] as String?,
      isClassTeacher: data['isClassTeacher'] as bool? ?? false,
      assignedClass: data['assignedClass'] as String?,
      assignedSection: data['assignedSection'] as String?,
    );
  }

  static StaffType _parseStaffType(dynamic staffType) {
    if (staffType == null) return StaffType.TEACHING;
    switch (staffType.toString().toUpperCase()) {
      case 'TEACHING':
        return StaffType.TEACHING;
      case 'NON_TEACHING':
        return StaffType.NON_TEACHING;
      default:
        return StaffType.TEACHING;
    }
  }

  static UserStatus _parseStatus(dynamic status) {
    if (status == null) return UserStatus.ACTIVE;
    switch (status.toString().toUpperCase()) {
      case 'ACTIVE':
        return UserStatus.ACTIVE;
      case 'DISABLED':
        return UserStatus.DISABLED;
      default:
        return UserStatus.ACTIVE;
    }
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'schoolId': schoolId,
      'name': name,
      'employeeId': employeeId,
      'email': email,
      'department': department,
      'staffType': staffType.name,
      'status': status.name,
      'joiningDate': Timestamp.fromDate(joiningDate),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'createdBy': createdBy,
      'phoneNumber': phoneNumber,
      'address': address,
      'emergencyContact': emergencyContact,
      'designation': designation,
      'isClassTeacher': isClassTeacher,
      'assignedClass': assignedClass,
      'assignedSection': assignedSection,
    };
  }

  StaffProfile copyWith({
    String? id,
    String? userId,
    String? schoolId,
    String? name,
    String? employeeId,
    String? email,
    String? department,
    StaffType? staffType,
    UserStatus? status,
    DateTime? joiningDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    String? phoneNumber,
    String? address,
    String? emergencyContact,
    String? designation,
    bool? isClassTeacher,
    String? assignedClass,
    String? assignedSection,
  }) {
    return StaffProfile(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      schoolId: schoolId ?? this.schoolId,
      name: name ?? this.name,
      employeeId: employeeId ?? this.employeeId,
      email: email ?? this.email,
      department: department ?? this.department,
      staffType: staffType ?? this.staffType,
      status: status ?? this.status,
      joiningDate: joiningDate ?? this.joiningDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      address: address ?? this.address,
      emergencyContact: emergencyContact ?? this.emergencyContact,
      designation: designation ?? this.designation,
      isClassTeacher: isClassTeacher ?? this.isClassTeacher,
      assignedClass: assignedClass ?? this.assignedClass,
      assignedSection: assignedSection ?? this.assignedSection,
    );
  }

  bool get isActive => status == UserStatus.ACTIVE;
  bool get isTeaching => staffType == StaffType.TEACHING;
  bool get isNonTeaching => staffType == StaffType.NON_TEACHING;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is StaffProfile && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'StaffProfile(id: $id, name: $name, employeeId: $employeeId, schoolId: $schoolId, status: $status)';
  }
}

/// Request model for creating new staff
class CreateStaffRequest {
  final String name;
  final String employeeId;
  final String email;
  final String department;
  final StaffType staffType;
  final DateTime joiningDate;
  final String? phoneNumber;
  final String? address;
  final String? emergencyContact;
  final String? designation;

  const CreateStaffRequest({
    required this.name,
    required this.employeeId,
    required this.email,
    required this.department,
    required this.staffType,
    required this.joiningDate,
    this.phoneNumber,
    this.address,
    this.emergencyContact,
    this.designation,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'employeeId': employeeId,
      'email': email,
      'department': department,
      'staffType': staffType.name,
      'joiningDate': joiningDate.toIso8601String(),
      'phoneNumber': phoneNumber,
      'address': address,
      'emergencyContact': emergencyContact,
      'designation': designation,
    };
  }
}

/// Request model for updating staff
class UpdateStaffRequest {
  final String? name;
  final String? department;
  final StaffType? staffType;
  final UserStatus? status;
  final DateTime? joiningDate;
  final String? phoneNumber;
  final String? address;
  final String? emergencyContact;
  final String? designation;

  const UpdateStaffRequest({
    this.name,
    this.department,
    this.staffType,
    this.status,
    this.joiningDate,
    this.phoneNumber,
    this.address,
    this.emergencyContact,
    this.designation,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{};
    if (name != null) map['name'] = name;
    if (department != null) map['department'] = department;
    if (staffType != null) map['staffType'] = staffType!.name;
    if (status != null) map['status'] = status!.name;
    if (joiningDate != null) map['joiningDate'] = Timestamp.fromDate(joiningDate!);
    if (phoneNumber != null) map['phoneNumber'] = phoneNumber;
    if (address != null) map['address'] = address;
    if (emergencyContact != null) map['emergencyContact'] = emergencyContact;
    if (designation != null) map['designation'] = designation;
    map['updatedAt'] = FieldValue.serverTimestamp();
    return map;
  }

  bool get hasChanges => 
    name != null || 
    department != null || 
    staffType != null || 
    status != null || 
    joiningDate != null || 
    phoneNumber != null || 
    address != null || 
    emergencyContact != null || 
    designation != null;
}
