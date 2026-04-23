import 'package:cloud_firestore/cloud_firestore.dart';

import 'app_user.dart';

/// Represents a user's membership in a specific school/tenant.
///
/// A single Firebase Auth account (email/uid) can have many memberships
/// — one per school the user belongs to. Within a single school, the same
/// user can also hold multiple roles (e.g. ADMIN + FINANCE), which is why
/// [roles] is a list rather than a single value.
///
/// Stored at:
///   `userMemberships/{uid}/schools/{schoolId}`
///
/// The document id is the `schoolId` so membership lookup / rules checks are
/// a single, cheap `get()` operation.
class Membership {
  /// Document id = schoolId.
  final String schoolId;
  final String schoolName;
  final String schoolShortCode;

  /// All roles this user holds within [schoolId]. Always at least one role.
  final List<UserRole> roles;

  /// Whether this specific membership is active (admin can deactivate a
  /// single tenant membership without touching the Firebase Auth account).
  final bool isActive;

  /// True if this user was the original registrar of the school.
  final bool isOwner;

  /// Whether the school itself is active (denormalised for cheap reads).
  final bool schoolIsActive;

  final DateTime joinedAt;
  final DateTime? lastAccessedAt;
  final String? createdBy;

  const Membership({
    required this.schoolId,
    required this.schoolName,
    this.schoolShortCode = '',
    required this.roles,
    this.isActive = true,
    this.isOwner = false,
    this.schoolIsActive = true,
    required this.joinedAt,
    this.lastAccessedAt,
    this.createdBy,
  });

  /// Primary role to display when the session is scoped to this school.
  /// Uses role precedence (SUPER_ADMIN > ADMIN > FINANCE > STAFF > PARENT).
  UserRole get primaryRole {
    if (roles.isEmpty) return UserRole.NONE;
    for (final candidate in [
      UserRole.SUPER_ADMIN,
      UserRole.ADMIN,
      UserRole.FINANCE,
      UserRole.STAFF,
      UserRole.PARENT,
    ]) {
      if (roles.contains(candidate)) return candidate;
    }
    return roles.first;
  }

  bool hasRole(UserRole role) => roles.contains(role);

  /// Effective permissions for this membership — the union of permissions
  /// granted by each role the user holds. Multi-role users get the superset.
  UserPermissions get effectivePermissions {
    if (roles.isEmpty) return const UserPermissions();
    var merged = UserPermissions.forRole(roles.first);
    for (final r in roles.skip(1)) {
      merged = _union(merged, UserPermissions.forRole(r));
    }
    return merged;
  }

  static UserPermissions _union(UserPermissions a, UserPermissions b) {
    return UserPermissions(
      canManageStaff: a.canManageStaff || b.canManageStaff,
      canApproveLeaves: a.canApproveLeaves || b.canApproveLeaves,
      canViewReports: a.canViewReports || b.canViewReports,
      canManageSettings: a.canManageSettings || b.canManageSettings,
      canApplyLeave: a.canApplyLeave || b.canApplyLeave,
      canRequestPermission: a.canRequestPermission || b.canRequestPermission,
      canViewOwnData: a.canViewOwnData || b.canViewOwnData,
      canCreateSchools: a.canCreateSchools || b.canCreateSchools,
      canViewAllSchools: a.canViewAllSchools || b.canViewAllSchools,
      canManageSubscriptions:
          a.canManageSubscriptions || b.canManageSubscriptions,
      canAssignAdmins: a.canAssignAdmins || b.canAssignAdmins,
    );
  }

  factory Membership.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Membership.fromMap(doc.id, data);
  }

  factory Membership.fromMap(String schoolId, Map<String, dynamic> data) {
    final rolesRaw = data['roles'];
    final parsedRoles = <UserRole>[];
    if (rolesRaw is List) {
      for (final r in rolesRaw) {
        final role = _parseRole(r);
        if (role != UserRole.NONE && !parsedRoles.contains(role)) {
          parsedRoles.add(role);
        }
      }
    }
    // Legacy fallback — some old docs stored a single `role` string.
    if (parsedRoles.isEmpty && data['role'] != null) {
      final r = _parseRole(data['role']);
      if (r != UserRole.NONE) parsedRoles.add(r);
    }

    DateTime parseDt(dynamic v) {
      if (v == null) return DateTime.now();
      if (v is Timestamp) return v.toDate();
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
      if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
      return DateTime.now();
    }

    return Membership(
      schoolId: schoolId,
      schoolName: (data['schoolName'] ?? data['name'] ?? '').toString(),
      schoolShortCode: (data['schoolShortCode'] ?? '').toString(),
      roles: parsedRoles.isEmpty ? [UserRole.NONE] : parsedRoles,
      isActive: data['isActive'] as bool? ?? true,
      isOwner: data['isOwner'] as bool? ?? false,
      schoolIsActive: data['schoolIsActive'] as bool? ?? true,
      joinedAt: parseDt(data['joinedAt'] ?? data['createdAt']),
      lastAccessedAt: data['lastAccessedAt'] == null
          ? null
          : parseDt(data['lastAccessedAt']),
      createdBy: data['createdBy'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'schoolId': schoolId,
        'schoolName': schoolName,
        'schoolShortCode': schoolShortCode,
        'roles': roles.map((r) => r.name).toList(),
        'isActive': isActive,
        'isOwner': isOwner,
        'schoolIsActive': schoolIsActive,
        'joinedAt': Timestamp.fromDate(joinedAt),
        if (lastAccessedAt != null)
          'lastAccessedAt': Timestamp.fromDate(lastAccessedAt!),
        if (createdBy != null) 'createdBy': createdBy,
      };

  Membership copyWith({
    String? schoolId,
    String? schoolName,
    String? schoolShortCode,
    List<UserRole>? roles,
    bool? isActive,
    bool? isOwner,
    bool? schoolIsActive,
    DateTime? joinedAt,
    DateTime? lastAccessedAt,
    String? createdBy,
  }) {
    return Membership(
      schoolId: schoolId ?? this.schoolId,
      schoolName: schoolName ?? this.schoolName,
      schoolShortCode: schoolShortCode ?? this.schoolShortCode,
      roles: roles ?? this.roles,
      isActive: isActive ?? this.isActive,
      isOwner: isOwner ?? this.isOwner,
      schoolIsActive: schoolIsActive ?? this.schoolIsActive,
      joinedAt: joinedAt ?? this.joinedAt,
      lastAccessedAt: lastAccessedAt ?? this.lastAccessedAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }

  static UserRole _parseRole(dynamic role) {
    if (role == null) return UserRole.NONE;
    switch (role.toString().toUpperCase()) {
      case 'SUPER_ADMIN':
      case 'SUPERADMIN':
        return UserRole.SUPER_ADMIN;
      case 'ADMIN':
      case 'TENANT_ADMIN':
      case 'TENANTADMIN':
        return UserRole.ADMIN;
      case 'FINANCE':
      case 'USER':
      case 'ACCOUNTS':
        return UserRole.FINANCE;
      case 'STAFF':
      case 'TEACHER':
        return UserRole.STAFF;
      case 'PARENT':
        return UserRole.PARENT;
      default:
        return UserRole.NONE;
    }
  }
}
