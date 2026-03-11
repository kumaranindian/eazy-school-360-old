import 'package:eazy_school_360/domain/entities/app_user.dart';

/// Global session model that holds authenticated user state
class UserSession {
  final String uid;
  final String email;
  final String displayName;
  final UserRole role;
  final String? schoolId;
  final UserStatus status;
  final OnboardingStatus onboardingStatus;
  final UserPermissions permissions;
  final DateTime lastLoginAt;

  const UserSession({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
    this.schoolId,
    required this.status,
    required this.onboardingStatus,
    required this.permissions,
    required this.lastLoginAt,
  });

  /// Create session from AppUser entity
  factory UserSession.fromAppUser(AppUser user) {
    return UserSession(
      uid: user.uid,
      email: user.email,
      displayName: user.displayName,
      role: user.role,
      schoolId: user.schoolId,
      status: user.status,
      onboardingStatus: user.onboardingStatus,
      permissions: user.permissions,
      lastLoginAt: DateTime.now(),
    );
  }

  /// Convert to JSON for persistence
  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'role': role.name,
      'schoolId': schoolId,
      'status': status.name,
      'onboardingStatus': onboardingStatus.name,
      'permissions': permissions.toMap(),
      'lastLoginAt': lastLoginAt.toIso8601String(),
    };
  }

  /// Create from JSON for persistence
  factory UserSession.fromJson(Map<String, dynamic> json) {
    return UserSession(
      uid: json['uid'] as String,
      email: json['email'] as String,
      displayName: json['displayName'] as String,
      role: UserRole.values.firstWhere((e) => e.name == json['role']),
      schoolId: json['schoolId'] as String?,
      status: UserStatus.values.firstWhere((e) => e.name == json['status']),
      onboardingStatus: OnboardingStatus.values.firstWhere((e) => e.name == json['onboardingStatus']),
      permissions: UserPermissions.fromMap(json['permissions'] as Map<String, dynamic>),
      lastLoginAt: DateTime.parse(json['lastLoginAt'] as String),
    );
  }

  /// Convenience getters
  bool get isActive => status == UserStatus.ACTIVE;
  bool get isSuperAdmin => role == UserRole.SUPER_ADMIN;
  bool get isAdmin => role == UserRole.ADMIN;
  bool get isStaff => role == UserRole.STAFF;
  bool get isParent => role == UserRole.PARENT;
  bool get isOnboardingComplete => onboardingStatus == OnboardingStatus.ACTIVE;
  bool get hasSchoolAccess => schoolId != null;

  /// Check if user has specific permission
  bool hasPermission(String permission) {
    final permissionMap = permissions.toMap();
    return permissionMap[permission] == true;
  }

  /// Get dashboard route based on role
  String get dashboardRoute {
    switch (role) {
      case UserRole.SUPER_ADMIN:
        return '/super-admin-dashboard';
      case UserRole.ADMIN:
        return '/admin-dashboard';
      case UserRole.FINANCE:
        return '/finance-dashboard';
      case UserRole.STAFF:
        return '/staff-dashboard';
      case UserRole.PARENT:
        return '/parent-dashboard';
      case UserRole.NONE:
        return '/login';
    }
  }

  /// Validate session integrity
  bool isValid() {
    // Check if user is active
    if (!isActive) return false;
    
    // Check if school access is required and present for admin/staff
    if ((isAdmin || isStaff) && !hasSchoolAccess) return false;
    
    // Check session age (optional - could expire sessions)
    final sessionAge = DateTime.now().difference(lastLoginAt);
    if (sessionAge.inDays > 30) return false; // 30 day session expiry
    
    return true;
  }

  UserSession copyWith({
    String? uid,
    String? email,
    String? displayName,
    UserRole? role,
    String? schoolId,
    UserStatus? status,
    OnboardingStatus? onboardingStatus,
    UserPermissions? permissions,
    DateTime? lastLoginAt,
  }) {
    return UserSession(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      schoolId: schoolId ?? this.schoolId,
      status: status ?? this.status,
      onboardingStatus: onboardingStatus ?? this.onboardingStatus,
      permissions: permissions ?? this.permissions,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserSession && other.uid == uid;
  }

  @override
  int get hashCode => uid.hashCode;

  @override
  String toString() {
    return 'UserSession(uid: $uid, email: $email, role: $role, schoolId: $schoolId, status: $status)';
  }
}
