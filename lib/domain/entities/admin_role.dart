import 'package:cloud_firestore/cloud_firestore.dart';

/// Admin role types for admin provisioning
enum AdminRoleType {
  superAdmin,
  hrAdmin,
  payrollAdmin,
  attendanceAdmin,
  academicAdmin,
  tenantAdmin,
}

/// Extension to provide display names and permissions for admin roles
extension AdminRoleTypeExtension on AdminRoleType {
  String get displayName {
    switch (this) {
      case AdminRoleType.superAdmin:
        return 'Super Admin';
      case AdminRoleType.hrAdmin:
        return 'HR Admin';
      case AdminRoleType.payrollAdmin:
        return 'Payroll Admin';
      case AdminRoleType.attendanceAdmin:
        return 'Attendance Admin';
      case AdminRoleType.academicAdmin:
        return 'Academic Admin';
      case AdminRoleType.tenantAdmin:
        return 'Tenant Admin';
    }
  }

  String get value {
    switch (this) {
      case AdminRoleType.superAdmin:
        return 'super_admin';
      case AdminRoleType.hrAdmin:
        return 'hr_admin';
      case AdminRoleType.payrollAdmin:
        return 'payroll_admin';
      case AdminRoleType.attendanceAdmin:
        return 'attendance_admin';
      case AdminRoleType.academicAdmin:
        return 'academic_admin';
      case AdminRoleType.tenantAdmin:
        return 'tenant_admin';
    }
  }

  String get description {
    switch (this) {
      case AdminRoleType.superAdmin:
        return 'Full access to all system features and settings';
      case AdminRoleType.hrAdmin:
        return 'Manage staff, leave, and HR-related operations';
      case AdminRoleType.payrollAdmin:
        return 'Manage salary structures and payroll processing';
      case AdminRoleType.attendanceAdmin:
        return 'Manage attendance tracking and reports';
      case AdminRoleType.academicAdmin:
        return 'Manage academic schedules, classes, and curriculum';
      case AdminRoleType.tenantAdmin:
        return 'Full access to school-specific features';
    }
  }

  /// Menu items visible to this admin role
  List<String> get allowedMenuItems {
    switch (this) {
      case AdminRoleType.superAdmin:
        return [
          'dashboard',
          'schools',
          'admin_provisioning',
          'staff',
          'leave_management',
          'payroll',
          'attendance',
          'settings',
          'reports',
        ];
      case AdminRoleType.hrAdmin:
        return [
          'dashboard',
          'staff',
          'leave_management',
          'reports',
        ];
      case AdminRoleType.payrollAdmin:
        return [
          'dashboard',
          'staff',
          'payroll',
          'reports',
        ];
      case AdminRoleType.attendanceAdmin:
        return [
          'dashboard',
          'staff',
          'attendance',
          'reports',
        ];
      case AdminRoleType.academicAdmin:
        return [
          'dashboard',
          'staff',
          'academics',
          'reports',
        ];
      case AdminRoleType.tenantAdmin:
        return [
          'dashboard',
          'admin_provisioning',
          'staff',
          'leave_management',
          'payroll',
          'attendance',
          'settings',
          'reports',
        ];
    }
  }

  /// Permissions for this admin role
  List<String> get permissions {
    switch (this) {
      case AdminRoleType.superAdmin:
        return [
          'manage_schools',
          'manage_admins',
          'manage_staff',
          'manage_leave',
          'manage_payroll',
          'manage_attendance',
          'manage_settings',
          'view_reports',
          'manage_academics',
        ];
      case AdminRoleType.hrAdmin:
        return [
          'manage_staff',
          'manage_leave',
          'view_reports',
        ];
      case AdminRoleType.payrollAdmin:
        return [
          'view_staff',
          'manage_payroll',
          'view_reports',
        ];
      case AdminRoleType.attendanceAdmin:
        return [
          'view_staff',
          'manage_attendance',
          'view_reports',
        ];
      case AdminRoleType.academicAdmin:
        return [
          'view_staff',
          'manage_academics',
          'view_reports',
        ];
      case AdminRoleType.tenantAdmin:
        return [
          'manage_admins',
          'manage_staff',
          'manage_leave',
          'manage_payroll',
          'manage_attendance',
          'manage_settings',
          'view_reports',
        ];
    }
  }

  static AdminRoleType fromString(String? value) {
    if (value == null) return AdminRoleType.tenantAdmin;
    
    switch (value.toLowerCase()) {
      case 'super_admin':
      case 'superadmin':
        return AdminRoleType.superAdmin;
      case 'hr_admin':
      case 'hradmin':
        return AdminRoleType.hrAdmin;
      case 'payroll_admin':
      case 'payrolladmin':
        return AdminRoleType.payrollAdmin;
      case 'attendance_admin':
      case 'attendanceadmin':
        return AdminRoleType.attendanceAdmin;
      case 'academic_admin':
      case 'academicadmin':
        return AdminRoleType.academicAdmin;
      case 'tenant_admin':
      case 'tenantadmin':
        return AdminRoleType.tenantAdmin;
      default:
        return AdminRoleType.tenantAdmin;
    }
  }
}

/// Admin User entity for admin provisioning
class AdminUser {
  final String id;
  final String userId; // Firebase Auth User ID
  final String schoolId;
  final String name;
  final String email;
  final String phone;
  final List<AdminRoleType> roles;
  final bool isActive;
  final DateTime? lastLoginAt;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  AdminUser({
    required this.id,
    required this.userId,
    required this.schoolId,
    required this.name,
    required this.email,
    this.phone = '',
    required this.roles,
    this.isActive = true,
    this.lastLoginAt,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Check if admin has a specific permission
  bool hasPermission(String permission) {
    for (final role in roles) {
      if (role.permissions.contains(permission)) {
        return true;
      }
    }
    return false;
  }

  /// Check if admin can access a specific menu item
  bool canAccessMenuItem(String menuItem) {
    for (final role in roles) {
      if (role.allowedMenuItems.contains(menuItem)) {
        return true;
      }
    }
    return false;
  }

  /// Get all permissions for this admin
  Set<String> get allPermissions {
    final permissions = <String>{};
    for (final role in roles) {
      permissions.addAll(role.permissions);
    }
    return permissions;
  }

  /// Get all allowed menu items for this admin
  Set<String> get allAllowedMenuItems {
    final menuItems = <String>{};
    for (final role in roles) {
      menuItems.addAll(role.allowedMenuItems);
    }
    return menuItems;
  }

  /// Get display string for roles
  String get rolesDisplay {
    return roles.map((r) => r.displayName).join(', ');
  }

  factory AdminUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    // Parse roles - can be a single string or a list
    List<AdminRoleType> parsedRoles = [];
    final rolesData = data['roles'];
    if (rolesData is List) {
      parsedRoles = rolesData
          .map((r) => AdminRoleTypeExtension.fromString(r as String?))
          .toList();
    } else if (rolesData is String) {
      parsedRoles = [AdminRoleTypeExtension.fromString(rolesData)];
    } else {
      parsedRoles = [AdminRoleType.tenantAdmin];
    }

    return AdminUser(
      id: doc.id,
      userId: (data['userId'] as String?) ?? '',
      schoolId: (data['schoolId'] as String?) ?? '',
      name: (data['name'] as String?) ?? '',
      email: (data['email'] as String?) ?? '',
      phone: (data['phone'] as String?) ?? '',
      roles: parsedRoles,
      isActive: (data['isActive'] as bool?) ?? true,
      lastLoginAt: data['lastLoginAt'] != null
          ? (data['lastLoginAt'] as Timestamp).toDate()
          : null,
      createdBy: data['createdBy'] as String?,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'schoolId': schoolId,
      'name': name,
      'email': email,
      'phone': phone,
      'roles': roles.map((r) => r.value).toList(),
      'isActive': isActive,
      'lastLoginAt': lastLoginAt,
      'createdBy': createdBy,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  AdminUser copyWith({
    String? id,
    String? userId,
    String? schoolId,
    String? name,
    String? email,
    String? phone,
    List<AdminRoleType>? roles,
    bool? isActive,
    DateTime? lastLoginAt,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AdminUser(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      schoolId: schoolId ?? this.schoolId,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      roles: roles ?? this.roles,
      isActive: isActive ?? this.isActive,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
