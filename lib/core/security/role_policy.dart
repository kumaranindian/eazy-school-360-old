import '../../../domain/entities/app_user.dart';

/// Centralized Role-Based Access Control (RBAC) Policy
/// Single source of truth for all role permissions
class RolePolicy {
  // Private constructor to prevent instantiation
  RolePolicy._();

  /// UI Module Permissions
  static const Map<UserRole, Set<UIModule>> _uiModules = {
    UserRole.SUPER_ADMIN: {
      UIModule.systemDashboard,
      UIModule.schoolManagement,
      UIModule.globalStaffManagement,
      UIModule.systemReports,
      UIModule.systemSettings,
      UIModule.platformAnalytics,
    },
    UserRole.ADMIN: {
      UIModule.adminDashboard,
      UIModule.staffManagement,
      UIModule.leaveApproval,
      UIModule.permissionManagement,
      UIModule.schoolReports,
      UIModule.leaveConfiguration,
      UIModule.holidayManagement,
      UIModule.schoolSettings,
    },
    UserRole.FINANCE: {
      UIModule.financeDashboard,
      UIModule.studentManagement,
      UIModule.feeCollection,
      UIModule.feeStructure,
      UIModule.expenseEntry,
      UIModule.financeReports,
      UIModule.printBills,
      UIModule.applyLeave,
      UIModule.requestPermission,
      UIModule.viewOwnProfile,
    },
    UserRole.STAFF: {
      UIModule.staffDashboard,
      UIModule.applyLeave,
      UIModule.requestPermission,
      UIModule.viewOwnProfile,
      UIModule.viewOwnBalance,
      UIModule.viewOwnHistory,
    },
    UserRole.PARENT: {
      UIModule.viewOwnProfile,
      UIModule.viewOwnHistory,
    },
  };

  /// Backend Action Permissions
  static const Map<UserRole, Set<BackendAction>> _backendActions = {
    UserRole.SUPER_ADMIN: {
      // School Management
      BackendAction.createSchool,
      BackendAction.updateSchool,
      BackendAction.deleteSchool,
      BackendAction.viewAllSchools,
      
      // User Management
      BackendAction.assignAdmin,
      BackendAction.revokeAdmin,
      BackendAction.viewAllUsers,
      BackendAction.activateUser,
      BackendAction.deactivateUser,
      
      // System Operations
      BackendAction.viewSystemMetrics,
      BackendAction.configureSystemSettings,
      BackendAction.viewAuditLogs,
      BackendAction.exportSystemData,
    },
    UserRole.ADMIN: {
      // Staff Management (Own School Only)
      BackendAction.createStaff,
      BackendAction.updateStaff,
      BackendAction.viewSchoolStaff,
      BackendAction.activateStaff,
      BackendAction.deactivateStaff,
      
      // Leave Management
      BackendAction.approveLeave,
      BackendAction.rejectLeave,
      BackendAction.viewLeaveRequests,
      BackendAction.configureLeaveTypes,
      BackendAction.viewLeaveReports,
      
      // Permission Management
      BackendAction.approvePermission,
      BackendAction.rejectPermission,
      BackendAction.viewPermissionRequests,
      BackendAction.configurePermissionTypes,
      
      // School Configuration
      BackendAction.configureHolidays,
      BackendAction.configureWeekends,
      BackendAction.viewSchoolReports,
      BackendAction.exportSchoolData,
    },
    UserRole.STAFF: {
      // Leave Operations
      BackendAction.applyLeave,
      BackendAction.cancelOwnLeave,
      BackendAction.viewOwnLeaves,
      
      // Permission Operations
      BackendAction.applyPermission,
      BackendAction.cancelOwnPermission,
      BackendAction.viewOwnPermissions,
      
      // Profile Operations
      BackendAction.viewOwnProfile,
      BackendAction.updateOwnProfile,
      BackendAction.viewOwnBalance,
      BackendAction.viewOwnHistory,
    },
    UserRole.PARENT: {
      BackendAction.viewOwnProfile,
      BackendAction.viewOwnHistory,
    },
  };

  /// Route Access Permissions
  static const Map<UserRole, Set<String>> _allowedRoutes = {
    UserRole.SUPER_ADMIN: {
      '/super-admin-dashboard',
      '/school-management',
      '/global-staff-management',
      '/system-reports',
      '/system-settings',
      '/platform-analytics',
    },
    UserRole.ADMIN: {
      '/admin-dashboard',
      '/staff-management',
      '/leave-approval',
      '/permission-management',
      '/school-reports',
      '/leave-configuration',
      '/holiday-management',
      '/school-settings',
    },
    UserRole.STAFF: {
      '/staff-dashboard',
      '/apply-leave',
      '/request-permission',
      '/staff-profile',
      '/leave-balance',
      '/leave-history',
    },
    UserRole.PARENT: {
      '/parent-dashboard',
    },
  };

  /// Check if user has access to UI module
  static bool hasUIAccess(UserRole role, UIModule module) {
    return _uiModules[role]?.contains(module) ?? false;
  }

  /// Check if user can perform backend action
  static bool canPerformAction(UserRole role, BackendAction action) {
    return _backendActions[role]?.contains(action) ?? false;
  }

  /// Check if user can access route
  static bool canAccessRoute(UserRole role, String route) {
    return _allowedRoutes[role]?.contains(route) ?? false;
  }

  /// Get all allowed UI modules for role
  static Set<UIModule> getAllowedUIModules(UserRole role) {
    return _uiModules[role] ?? {};
  }

  /// Get all allowed backend actions for role
  static Set<BackendAction> getAllowedActions(UserRole role) {
    return _backendActions[role] ?? {};
  }

  /// Get all allowed routes for role
  static Set<String> getAllowedRoutes(UserRole role) {
    return _allowedRoutes[role] ?? {};
  }

  /// Validate tenant access (schoolId scoping)
  static bool canAccessSchool(UserRole role, String? userSchoolId, String? targetSchoolId) {
    switch (role) {
      case UserRole.SUPER_ADMIN:
        // Super admin can access any school
        return true;
      case UserRole.ADMIN:
      case UserRole.FINANCE:
      case UserRole.STAFF:
      case UserRole.PARENT:
        // Admin, Finance, Staff, and Parent can only access their own school
        return userSchoolId != null && userSchoolId == targetSchoolId;
      case UserRole.NONE:
        return false;
    }
  }

  /// Validate user data access (uid scoping)
  static bool canAccessUserData(UserRole role, String currentUserId, String targetUserId) {
    switch (role) {
      case UserRole.SUPER_ADMIN:
        // Super admin can access any user data
        return true;
      case UserRole.ADMIN:
        // Admin can access staff data in their school (handled by school scoping)
        return true;
      case UserRole.FINANCE:
        // Finance can access student/fee data in their school
        return true;
      case UserRole.STAFF:
        // Staff can only access their own data
        return currentUserId == targetUserId;
      case UserRole.PARENT:
        // Parent can only access their own and linked student data
        return currentUserId == targetUserId;
      case UserRole.NONE:
        return false;
    }
  }

  /// Get role hierarchy level (for comparison)
  static int getRoleLevel(UserRole role) {
    switch (role) {
      case UserRole.SUPER_ADMIN:
        return 4;
      case UserRole.ADMIN:
        return 3;
      case UserRole.FINANCE:
        return 2;
      case UserRole.STAFF:
        return 1;
      case UserRole.PARENT:
        return 0;
      case UserRole.NONE:
        return 0;
    }
  }

  /// Check if role can manage another role
  static bool canManageRole(UserRole managerRole, UserRole targetRole) {
    return getRoleLevel(managerRole) > getRoleLevel(targetRole);
  }
}

/// UI Module Enumeration
enum UIModule {
  // Super Admin Modules
  systemDashboard,
  schoolManagement,
  globalStaffManagement,
  systemReports,
  systemSettings,
  platformAnalytics,

  // Admin Modules
  adminDashboard,
  staffManagement,
  leaveApproval,
  permissionManagement,
  schoolReports,
  leaveConfiguration,
  holidayManagement,
  schoolSettings,

  // Finance Modules
  financeDashboard,
  studentManagement,
  feeCollection,
  feeStructure,
  expenseEntry,
  financeReports,
  printBills,

  // Staff Modules
  staffDashboard,
  applyLeave,
  requestPermission,
  viewOwnProfile,
  viewOwnBalance,
  viewOwnHistory,
}

/// Backend Action Enumeration
enum BackendAction {
  // School Management Actions
  createSchool,
  updateSchool,
  deleteSchool,
  viewAllSchools,

  // User Management Actions
  assignAdmin,
  revokeAdmin,
  viewAllUsers,
  activateUser,
  deactivateUser,
  createStaff,
  updateStaff,
  viewSchoolStaff,
  activateStaff,
  deactivateStaff,

  // Leave Management Actions
  applyLeave,
  approveLeave,
  rejectLeave,
  cancelOwnLeave,
  viewLeaveRequests,
  viewOwnLeaves,
  configureLeaveTypes,
  viewLeaveReports,

  // Permission Management Actions
  applyPermission,
  approvePermission,
  rejectPermission,
  cancelOwnPermission,
  viewPermissionRequests,
  viewOwnPermissions,
  configurePermissionTypes,

  // Configuration Actions
  configureHolidays,
  configureWeekends,
  configureSystemSettings,

  // Profile Actions
  viewOwnProfile,
  updateOwnProfile,
  viewOwnBalance,
  viewOwnHistory,

  // Finance Actions
  manageStudents,
  collectFees,
  manageFeeStructure,
  recordExpense,
  viewFinanceReports,
  printReceipts,

  // Reporting Actions
  viewSchoolReports,
  viewSystemMetrics,
  exportSchoolData,
  exportSystemData,
  viewAuditLogs,
}
