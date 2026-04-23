import 'package:cloud_firestore/cloud_firestore.dart';

enum StudentStatus { ACTIVE, INACTIVE, GRADUATED, TRANSFERRED }

class Student {
  final String id;
  final String schoolId;
  final int studentId; // Numeric student ID for display
  final String name;
  final String className;
  final String section;
  final String? phoneNumber;
  final String? parentName;
  final String? parentPhone;
  final String? parentEmail;
  final String? email;
  final String? address;
  final DateTime? dateOfBirth;
  final DateTime? admissionDate;
  final String? gender;
  final StudentStatus status;
  final bool isVanAvailed;
  final String? parentUserId;
  final String academicYearCode; // e.g., "2024-25"
  final double arrears; // Pending fees from previous years
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? createdBy;

  const Student({
    required this.id,
    required this.schoolId,
    required this.studentId,
    required this.name,
    required this.className,
    required this.section,
    this.phoneNumber,
    this.parentName,
    this.parentPhone,
    this.parentEmail,
    this.email,
    this.address,
    this.dateOfBirth,
    this.admissionDate,
    this.gender,
    required this.status,
    this.isVanAvailed = false,
    this.parentUserId,
    required this.academicYearCode,
    this.arrears = 0.0,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy,
  });

  factory Student.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Student(
      id: doc.id,
      schoolId: data['schoolId'] as String? ?? '',
      studentId: (data['studentId'] as num?)?.toInt() ?? 0,
      name: data['name'] as String? ?? '',
      className: data['className'] as String? ?? '',
      section: data['section'] as String? ?? '',
      phoneNumber: data['phoneNumber'] as String?,
      parentName: data['parentName'] as String?,
      parentPhone: data['parentPhone'] as String?,
      parentEmail: data['parentEmail'] as String?,
      email: data['email'] as String?,
      address: data['address'] as String?,
      dateOfBirth: _parseDateTime(data['dateOfBirth']),
      admissionDate: _parseDateTime(data['admissionDate']),
      gender: data['gender'] as String?,
      status: _parseStatus(data['status']),
      isVanAvailed: data['isVanAvailed'] as bool? ?? false,
      parentUserId: data['parentUserId'] as String?,
      academicYearCode: data['academicYearCode'] as String? ?? '',
      arrears: (data['arrears'] as num?)?.toDouble() ?? 0.0,
      createdAt: _parseDateTime(data['createdAt']) ?? DateTime.now(),
      updatedAt: _parseDateTime(data['updatedAt']) ?? DateTime.now(),
      createdBy: data['createdBy'] as String?,
    );
  }

  static StudentStatus _parseStatus(dynamic status) {
    if (status == null) return StudentStatus.ACTIVE;
    switch (status.toString().toUpperCase()) {
      case 'ACTIVE': return StudentStatus.ACTIVE;
      case 'INACTIVE': return StudentStatus.INACTIVE;
      case 'GRADUATED': return StudentStatus.GRADUATED;
      case 'TRANSFERRED': return StudentStatus.TRANSFERRED;
      default: return StudentStatus.ACTIVE;
    }
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
      'studentId': studentId,
      'name': name,
      'className': className,
      'section': section,
      'phoneNumber': phoneNumber,
      'parentName': parentName,
      'parentPhone': parentPhone,
      'parentEmail': parentEmail,
      'email': email,
      'address': address,
      'dateOfBirth': dateOfBirth != null ? Timestamp.fromDate(dateOfBirth!) : null,
      'admissionDate': admissionDate != null ? Timestamp.fromDate(admissionDate!) : null,
      'gender': gender,
      'status': status.name,
      'isVanAvailed': isVanAvailed,
      'parentUserId': parentUserId,
      'academicYearCode': academicYearCode,
      'arrears': arrears,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'createdBy': createdBy,
    };
  }

  Student copyWith({
    String? id,
    String? schoolId,
    int? studentId,
    String? name,
    String? className,
    String? section,
    String? phoneNumber,
    String? parentName,
    String? parentPhone,
    String? parentEmail,
    String? email,
    String? address,
    DateTime? dateOfBirth,
    DateTime? admissionDate,
    String? gender,
    StudentStatus? status,
    bool? isVanAvailed,
    String? parentUserId,
    String? academicYearCode,
    double? arrears,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
  }) {
    return Student(
      id: id ?? this.id,
      schoolId: schoolId ?? this.schoolId,
      studentId: studentId ?? this.studentId,
      name: name ?? this.name,
      className: className ?? this.className,
      section: section ?? this.section,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      parentName: parentName ?? this.parentName,
      parentPhone: parentPhone ?? this.parentPhone,
      parentEmail: parentEmail ?? this.parentEmail,
      email: email ?? this.email,
      address: address ?? this.address,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      admissionDate: admissionDate ?? this.admissionDate,
      gender: gender ?? this.gender,
      status: status ?? this.status,
      isVanAvailed: isVanAvailed ?? this.isVanAvailed,
      parentUserId: parentUserId ?? this.parentUserId,
      academicYearCode: academicYearCode ?? this.academicYearCode,
      arrears: arrears ?? this.arrears,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }
}
