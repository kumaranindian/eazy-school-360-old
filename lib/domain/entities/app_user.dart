import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { SUPER_ADMIN, ADMIN, FINANCE, STAFF, PARENT, NONE }
enum StaffType { TEACHING, NON_TEACHING }
enum UserStatus { ACTIVE, DISABLED }
enum OnboardingStatus { PENDING_ACTIVATION, EMAIL_VERIFIED, PROFILE_COMPLETED, ACTIVE }

class UserProfile {
  final String? phoneNumber;
  final String? department;
  final String? designation;
  final String? employeeId;
  final DateTime? joiningDate;
  final Map<String, dynamic>? address;
  final Map<String, dynamic>? emergencyContact;

  const UserProfile({
    this.phoneNumber,
    this.department,
    this.designation,
    this.employeeId,
    this.joiningDate,
    this.address,
    this.emergencyContact,
  });

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      phoneNumber: map['phoneNumber'] as String?,
      department: map['department'] as String?,
      designation: map['designation'] as String?,
      employeeId: map['employeeId'] as String?,
      joiningDate: (map['joiningDate'] as Timestamp?)?.toDate(),
      address: map['address'] as Map<String, dynamic>?,
      emergencyContact: map['emergencyContact'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'phoneNumber': phoneNumber,
      'department': department,
      'designation': designation,
      'employeeId': employeeId,
      'joiningDate': joiningDate != null ? Timestamp.fromDate(joiningDate!) : null,
      'address': address,
      'emergencyContact': emergencyContact,
    };
  }
}

class UserPermissions {
  final bool canManageStaff;
  final bool canApproveLeaves;
  final bool canViewReports;
  final bool canManageSettings;
  final bool canApplyLeave;
  final bool canRequestPermission;
  final bool canViewOwnData;
  final bool canCreateSchools;
  final bool canViewAllSchools;
  final bool canManageSubscriptions;
  final bool canAssignAdmins;

  const UserPermissions({
    this.canManageStaff = false,
    this.canApproveLeaves = false,
    this.canViewReports = false,
    this.canManageSettings = false,
    this.canApplyLeave = false,
    this.canRequestPermission = false,
    this.canViewOwnData = false,
    this.canCreateSchools = false,
    this.canViewAllSchools = false,
    this.canManageSubscriptions = false,
    this.canAssignAdmins = false,
  });

  factory UserPermissions.fromMap(Map<String, dynamic> map) {
    return UserPermissions(
      canManageStaff: map['canManageStaff'] as bool? ?? false,
      canApproveLeaves: map['canApproveLeaves'] as bool? ?? false,
      canViewReports: map['canViewReports'] as bool? ?? false,
      canManageSettings: map['canManageSettings'] as bool? ?? false,
      canApplyLeave: map['canApplyLeave'] as bool? ?? false,
      canRequestPermission: map['canRequestPermission'] as bool? ?? false,
      canViewOwnData: map['canViewOwnData'] as bool? ?? false,
      canCreateSchools: map['canCreateSchools'] as bool? ?? false,
      canViewAllSchools: map['canViewAllSchools'] as bool? ?? false,
      canManageSubscriptions: map['canManageSubscriptions'] as bool? ?? false,
      canAssignAdmins: map['canAssignAdmins'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'canManageStaff': canManageStaff,
      'canApproveLeaves': canApproveLeaves,
      'canViewReports': canViewReports,
      'canManageSettings': canManageSettings,
      'canApplyLeave': canApplyLeave,
      'canRequestPermission': canRequestPermission,
      'canViewOwnData': canViewOwnData,
      'canCreateSchools': canCreateSchools,
      'canViewAllSchools': canViewAllSchools,
      'canManageSubscriptions': canManageSubscriptions,
      'canAssignAdmins': canAssignAdmins,
    };
  }

  static UserPermissions forRole(UserRole role) {
    switch (role) {
      case UserRole.SUPER_ADMIN:
        return const UserPermissions(
          canCreateSchools: true,
          canViewAllSchools: true,
          canManageSubscriptions: true,
          canAssignAdmins: true,
        );
      case UserRole.ADMIN:
        return const UserPermissions(
          canManageStaff: true,
          canApproveLeaves: true,
          canViewReports: true,
          canManageSettings: true,
          canApplyLeave: true,
          canRequestPermission: true,
          canViewOwnData: true,
        );
      case UserRole.FINANCE:
        return const UserPermissions(
          canManageStaff: false,
          canApproveLeaves: false,
          canViewReports: true,
          canManageSettings: false,
          canApplyLeave: true,
          canRequestPermission: true,
          canViewOwnData: true,
        );
      case UserRole.STAFF:
        return const UserPermissions(
          canApplyLeave: true,
          canRequestPermission: true,
          canViewOwnData: true,
        );
      case UserRole.PARENT:
        return const UserPermissions(
          canViewOwnData: true,
        );
      case UserRole.NONE:
        return const UserPermissions();
    }
  }
}

class AppUser {
  final String uid;
  final String email;
  final String displayName;
  final UserRole role;
  final String? schoolId; // Immutable after creation
  final StaffType? staffType;
  final UserStatus status;
  final OnboardingStatus onboardingStatus;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastLoginAt;
  final String? createdBy;
  final UserProfile profile;
  final UserPermissions permissions;

  const AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
    this.schoolId,
    this.staffType,
    required this.status,
    required this.onboardingStatus,
    required this.createdAt,
    required this.updatedAt,
    this.lastLoginAt,
    this.createdBy,
    required this.profile,
    required this.permissions,
  });

  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppUser(
      uid: doc.id,
      email: data['email'] as String? ?? '',
      displayName: data['displayName'] as String? ?? '',
      role: _parseRole(data['role']),
      schoolId: data['schoolId'] as String?,
      staffType: _parseStaffType(data['staffType']),
      status: _parseStatus(data['status']),
      onboardingStatus: _parseOnboardingStatus(data['onboardingStatus']),
      createdAt: _parseDateTime(data['createdAt']) ?? DateTime.now(),
      updatedAt: _parseDateTime(data['updatedAt']) ?? DateTime.now(),
      lastLoginAt: _parseDateTime(data['lastLoginAt']),
      createdBy: data['createdBy'] as String?,
      profile: UserProfile.fromMap((data['profile'] as Map<String, dynamic>?) ?? {}),
      permissions: UserPermissions.fromMap((data['permissions'] as Map<String, dynamic>?) ?? {}),
    );
  }

  static UserRole _parseRole(dynamic role) {
    if (role == null) return UserRole.STAFF;
    switch (role.toString().toUpperCase()) {
      case 'SUPER_ADMIN':
        return UserRole.SUPER_ADMIN;
      // Legacy tenant admin roles should be treated as ADMIN
      case 'TENANT_ADMIN':
      case 'ADMIN':
        return UserRole.ADMIN;
      // Legacy teacher/staff roles should be treated as STAFF
      case 'FINANCE':
      case 'USER':
        return UserRole.FINANCE;
      case 'TEACHER':
      case 'STAFF':
        return UserRole.STAFF;
      case 'PARENT':
        return UserRole.PARENT;
      default:
        return UserRole.NONE;
    }
  }

  static StaffType? _parseStaffType(dynamic staffType) {
    if (staffType == null) return null;
    switch (staffType.toString().toUpperCase()) {
      case 'TEACHING':
        return StaffType.TEACHING;
      case 'NON_TEACHING':
        return StaffType.NON_TEACHING;
      default:
        return null;
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

  static bool _isActive(UserRole role, UserStatus status) {
    switch (role) {
      case UserRole.SUPER_ADMIN:
        return status == UserStatus.ACTIVE;
      case UserRole.ADMIN:
        return status == UserStatus.ACTIVE;
      case UserRole.FINANCE:
        return status == UserStatus.ACTIVE;
      case UserRole.STAFF:
        return status == UserStatus.ACTIVE;
      case UserRole.PARENT:
        return status == UserStatus.ACTIVE;
      case UserRole.NONE:
        return false;
    }
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    
    if (value is Timestamp) {
      return value.toDate();
    } else if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    } else if (value is String) {
      return DateTime.tryParse(value);
    }
    
    return null;
  }

  static OnboardingStatus _parseOnboardingStatus(dynamic onboardingStatus) {
    if (onboardingStatus == null) return OnboardingStatus.PENDING_ACTIVATION;
    switch (onboardingStatus.toString().toUpperCase()) {
      case 'PENDING_ACTIVATION':
        return OnboardingStatus.PENDING_ACTIVATION;
      case 'EMAIL_VERIFIED':
        return OnboardingStatus.EMAIL_VERIFIED;
      case 'PROFILE_COMPLETED':
        return OnboardingStatus.PROFILE_COMPLETED;
      case 'ACTIVE':
        return OnboardingStatus.ACTIVE;
      default:
        return OnboardingStatus.PENDING_ACTIVATION;
    }
  }

  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'role': role.name,
      'schoolId': schoolId,
      'staffType': staffType?.name,
      'status': status.name,
      'onboardingStatus': onboardingStatus.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'lastLoginAt': lastLoginAt != null ? Timestamp.fromDate(lastLoginAt!) : null,
      'createdBy': createdBy,
      'profile': profile.toMap(),
      'permissions': permissions.toMap(),
    };
  }

  AppUser copyWith({
    String? uid,
    String? email,
    String? displayName,
    UserRole? role,
    String? schoolId,
    StaffType? staffType,
    UserStatus? status,
    OnboardingStatus? onboardingStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastLoginAt,
    String? createdBy,
    UserProfile? profile,
    UserPermissions? permissions,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      schoolId: schoolId ?? this.schoolId,
      staffType: staffType ?? this.staffType,
      status: status ?? this.status,
      onboardingStatus: onboardingStatus ?? this.onboardingStatus,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      createdBy: createdBy ?? this.createdBy,
      profile: profile ?? this.profile,
      permissions: permissions ?? this.permissions,
    );
  }

  // Convenience getters
  String get id => uid; // For backward compatibility
  bool get isActive => status == UserStatus.ACTIVE;
  bool get isSuperAdmin => role == UserRole.SUPER_ADMIN;
  bool get isAdmin => role == UserRole.ADMIN;
  bool get isStaff => role == UserRole.STAFF;
  bool get isOnboardingComplete => onboardingStatus == OnboardingStatus.ACTIVE;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppUser && other.uid == uid;
  }

  @override
  int get hashCode => uid.hashCode;

  @override
  String toString() {
    return 'AppUser(uid: $uid, email: $email, role: $role, schoolId: $schoolId, status: $status)';
  }
}
