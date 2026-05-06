import 'package:eazy_school_360/domain/entities/app_user.dart';
import 'package:eazy_school_360/domain/entities/membership.dart';

/// Global session model that holds authenticated user state.
///
/// Multi-tenant model
/// ------------------
/// A single Firebase Auth account can belong to many schools (memberships)
/// and can hold several roles within a single school. The session therefore
/// tracks:
///   * [memberships]   — every school this user can act in
///   * [activeSchoolId]/[activeRoles] — the school currently in scope
///   * [schoolId]/[role]              — legacy single-school aliases
///     that delegate to the active values so existing callers keep working.
class UserSession {
  final String uid;
  final String email;
  final String displayName;

  /// Active membership's primary role (or the legacy single role for a
  /// user with no memberships yet). Kept as an alias for back-compat.
  final UserRole role;

  /// Active school's id — also exposed under the original `schoolId`
  /// getter that the rest of the codebase reads.
  final String? schoolId;

  final UserStatus status;
  final OnboardingStatus onboardingStatus;
  final UserPermissions permissions;
  final DateTime lastLoginAt;

  /// All memberships for this user across every school.
  final List<Membership> memberships;

  /// All roles the user holds at [activeSchoolId]. Contains at least one
  /// value when a school is active; empty for super-admin / setup flows.
  final List<UserRole> activeRoles;

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
    this.memberships = const [],
    this.activeRoles = const [],
  });

  /// Alias for [schoolId], for code that wants to be explicit about
  /// "the school currently in scope".
  String? get activeSchoolId => schoolId;

  Membership? get activeMembership {
    if (activeSchoolId == null) return null;
    for (final m in memberships) {
      if (m.schoolId == activeSchoolId) return m;
    }
    return null;
  }

  /// Build a session from an [AppUser] (legacy single-school) plus optional
  /// [memberships]. When memberships are provided, [activeSchoolId] determines
  /// which one is in scope; otherwise we fall back to the user's own
  /// `schoolId` / `role` for backward compatibility.
  factory UserSession.fromAppUser(
    AppUser user, {
    List<Membership> memberships = const [],
    String? activeSchoolId,
  }) {
    print('🔍 [SESSION] Creating session for user: ${user.email}');
    print('🔍 [SESSION] User role: ${user.role}');
    print('🔍 [SESSION] Memberships count: ${memberships.length}');
    print('🔍 [SESSION] Active school ID: $activeSchoolId');

    // Pick the active membership (if any).
    Membership? active;
    if (activeSchoolId != null) {
      for (final m in memberships) {
        if (m.schoolId == activeSchoolId) {
          active = m;
          break;
        }
      }
    }
    // If caller didn't specify, auto-select single-membership users.
    if (active == null && memberships.length == 1) {
      active = memberships.first;
    }

    print('🔍 [SESSION] Active membership: ${active?.schoolId}');
    print('🔍 [SESSION] Active membership primaryRole: ${active?.primaryRole}');
    print('🔍 [SESSION] Active membership roles: ${active?.roles}');

    final effRoles = active?.roles ?? const <UserRole>[];
    final effRole = active?.primaryRole ?? user.role;
    final effSchoolId = active?.schoolId ?? user.schoolId;
    final effPermissions =
        active?.effectivePermissions ?? user.permissions;

    print('🔍 [SESSION] Effective role: $effRole');
    print('🔍 [SESSION] Effective school ID: $effSchoolId');

    return UserSession(
      uid: user.uid,
      email: user.email,
      displayName: user.displayName,
      role: effRole,
      schoolId: effSchoolId,
      status: user.status,
      onboardingStatus: user.onboardingStatus,
      permissions: effPermissions,
      lastLoginAt: DateTime.now(),
      memberships: memberships,
      activeRoles: effRoles,
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
      'activeRoles': activeRoles.map((r) => r.name).toList(),
      // Memberships are re-hydrated from Firestore on the next boot so we
      // only persist a minimal projection (schoolId + schoolName + roles)
      // to keep SharedPreferences light and avoid stale role/permission
      // data sticking across logins.
      'memberships': memberships
          .map((m) => {
                'schoolId': m.schoolId,
                'schoolName': m.schoolName,
                'schoolShortCode': m.schoolShortCode,
                'roles': m.roles.map((r) => r.name).toList(),
                'isActive': m.isActive,
                'isOwner': m.isOwner,
                'schoolIsActive': m.schoolIsActive,
                'joinedAt': m.joinedAt.toIso8601String(),
              })
          .toList(),
    };
  }

  /// Create from JSON for persistence
  factory UserSession.fromJson(Map<String, dynamic> json) {
    final rawMemberships = (json['memberships'] as List?) ?? const [];
    final memberships = <Membership>[];
    for (final raw in rawMemberships) {
      if (raw is! Map) continue;
      final map = Map<String, dynamic>.from(raw);
      final sid = (map['schoolId'] as String?) ?? '';
      if (sid.isEmpty) continue;
      memberships.add(Membership.fromMap(sid, map));
    }
    final activeRolesRaw = (json['activeRoles'] as List?) ?? const [];
    final activeRoles = activeRolesRaw
        .map((r) => UserRole.values.firstWhere(
              (e) => e.name == r,
              orElse: () => UserRole.NONE,
            ))
        .where((r) => r != UserRole.NONE)
        .toList();

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
      memberships: memberships,
      activeRoles: activeRoles,
    );
  }

  /// Convenience getters
  bool get isActive {
    // For legacy single-school users, check user status
    if (memberships.isEmpty) {
      return status == UserStatus.ACTIVE;
    }
    
    // For multi-tenant users, check if user is active AND has at least one active membership
    if (status != UserStatus.ACTIVE) {
      return false;
    }
    
    // Check if there's at least one active membership
    return memberships.any((m) => m.isActive && m.schoolIsActive);
  }
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
