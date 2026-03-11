import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../models/user_session.dart';
import '../../domain/entities/app_user.dart';
import 'role_policy.dart';

/// Centralized Role Guard Service
/// Single source of truth for all role-based UI and action checks
class RoleGuardService {
  final UserSession? _session;

  RoleGuardService(this._session);

  /// Check if current user has access to UI module
  bool hasUIAccess(UIModule module) {
    if (_session == null) return false;
    return RolePolicy.hasUIAccess(_session!.role, module);
  }

  /// Check if current user can perform backend action
  bool canPerformAction(BackendAction action) {
    if (_session == null) return false;
    return RolePolicy.canPerformAction(_session!.role, action);
  }

  /// Check if current user can access route
  bool canAccessRoute(String route) {
    if (_session == null) return false;
    return RolePolicy.canAccessRoute(_session!.role, route);
  }

  /// Check if current user can access specific school data
  bool canAccessSchool(String? targetSchoolId) {
    if (_session == null) return false;
    return RolePolicy.canAccessSchool(_session!.role, _session!.schoolId, targetSchoolId);
  }

  /// Check if current user can access specific user data
  bool canAccessUserData(String targetUserId) {
    if (_session == null) return false;
    return RolePolicy.canAccessUserData(_session!.role, _session!.uid, targetUserId);
  }

  /// Check if current user can manage another user role
  bool canManageRole(UserRole targetRole) {
    if (_session == null) return false;
    return RolePolicy.canManageRole(_session!.role, targetRole);
  }

  /// Get current user role
  UserRole? get currentRole => _session?.role;

  /// Get current user school ID
  String? get currentSchoolId => _session?.schoolId;

  /// Get current user ID
  String? get currentUserId => _session?.uid;

  /// Check if user is authenticated
  bool get isAuthenticated => _session != null && _session!.isValid();

  /// Check if user is Super Admin
  bool get isSuperAdmin => _session?.isSuperAdmin ?? false;

  /// Check if user is Admin
  bool get isAdmin => _session?.isAdmin ?? false;

  /// Check if user is Staff
  bool get isStaff => _session?.isStaff ?? false;

  /// Validate action with comprehensive checks
  RoleValidationResult validateAction(BackendAction action, {
    String? targetSchoolId,
    String? targetUserId,
  }) {
    // Check authentication
    if (!isAuthenticated) {
      return RoleValidationResult.failure(
        RoleValidationError.notAuthenticated,
        'User not authenticated',
      );
    }

    // Check action permission
    if (!canPerformAction(action)) {
      return RoleValidationResult.failure(
        RoleValidationError.insufficientPermissions,
        'User role ${_session!.role.name} cannot perform action ${action.name}',
      );
    }

    // Check school access if required
    if (targetSchoolId != null && !canAccessSchool(targetSchoolId)) {
      return RoleValidationResult.failure(
        RoleValidationError.schoolAccessDenied,
        'User cannot access school $targetSchoolId',
      );
    }

    // Check user data access if required
    if (targetUserId != null && !canAccessUserData(targetUserId)) {
      return RoleValidationResult.failure(
        RoleValidationError.userDataAccessDenied,
        'User cannot access data for user $targetUserId',
      );
    }

    return RoleValidationResult.success();
  }

  /// Get allowed navigation items for current role
  List<NavigationItem> getAllowedNavigationItems() {
    if (_session == null) return [];

    final allowedModules = RolePolicy.getAllowedUIModules(_session!.role);
    return _getNavigationItemsForModules(allowedModules);
  }

  /// Get navigation items for specific modules
  List<NavigationItem> _getNavigationItemsForModules(Set<UIModule> modules) {
    final items = <NavigationItem>[];

    // Super Admin Navigation
    if (modules.contains(UIModule.systemDashboard)) {
      items.add(NavigationItem(
        route: '/super-admin-dashboard',
        label: 'System Dashboard',
        icon: 'dashboard',
        module: UIModule.systemDashboard,
      ));
    }
    if (modules.contains(UIModule.schoolManagement)) {
      items.add(NavigationItem(
        route: '/school-management',
        label: 'Schools',
        icon: 'school',
        module: UIModule.schoolManagement,
      ));
    }
    if (modules.contains(UIModule.globalStaffManagement)) {
      items.add(NavigationItem(
        route: '/global-staff-management',
        label: 'Global Staff',
        icon: 'people',
        module: UIModule.globalStaffManagement,
      ));
    }

    // Admin Navigation
    if (modules.contains(UIModule.adminDashboard)) {
      items.add(NavigationItem(
        route: '/admin-dashboard',
        label: 'Dashboard',
        icon: 'dashboard',
        module: UIModule.adminDashboard,
      ));
    }
    if (modules.contains(UIModule.staffManagement)) {
      items.add(NavigationItem(
        route: '/staff-management',
        label: 'Staff',
        icon: 'people',
        module: UIModule.staffManagement,
      ));
    }
    if (modules.contains(UIModule.leaveApproval)) {
      items.add(NavigationItem(
        route: '/leave-approval',
        label: 'Leave Approval',
        icon: 'approval',
        module: UIModule.leaveApproval,
      ));
    }

    // Staff Navigation
    if (modules.contains(UIModule.staffDashboard)) {
      items.add(NavigationItem(
        route: '/staff-dashboard',
        label: 'Dashboard',
        icon: 'dashboard',
        module: UIModule.staffDashboard,
      ));
    }
    if (modules.contains(UIModule.applyLeave)) {
      items.add(NavigationItem(
        route: '/apply-leave',
        label: 'Apply Leave',
        icon: 'event_available',
        module: UIModule.applyLeave,
      ));
    }
    if (modules.contains(UIModule.requestPermission)) {
      items.add(NavigationItem(
        route: '/request-permission',
        label: 'Request Permission',
        icon: 'schedule',
        module: UIModule.requestPermission,
      ));
    }

    return items;
  }
}

/// Role validation result
class RoleValidationResult {
  final bool isValid;
  final RoleValidationError? error;
  final String? message;

  RoleValidationResult._(this.isValid, this.error, this.message);

  factory RoleValidationResult.success() {
    return RoleValidationResult._(true, null, null);
  }

  factory RoleValidationResult.failure(RoleValidationError error, String message) {
    return RoleValidationResult._(false, error, message);
  }
}

/// Role validation error types
enum RoleValidationError {
  notAuthenticated,
  insufficientPermissions,
  schoolAccessDenied,
  userDataAccessDenied,
}

/// Navigation item model
class NavigationItem {
  final String route;
  final String label;
  final String icon;
  final UIModule module;

  NavigationItem({
    required this.route,
    required this.label,
    required this.icon,
    required this.module,
  });
}

/// Role Guard Service Provider
final roleGuardServiceProvider = Provider<RoleGuardService>((ref) {
  final session = ref.watch(currentSessionProvider);
  return RoleGuardService(session);
});

/// Convenience providers for common checks
final canAccessAdminFeaturesProvider = Provider<bool>((ref) {
  final roleGuard = ref.watch(roleGuardServiceProvider);
  return roleGuard.hasUIAccess(UIModule.adminDashboard);
});

final canAccessStaffFeaturesProvider = Provider<bool>((ref) {
  final roleGuard = ref.watch(roleGuardServiceProvider);
  return roleGuard.hasUIAccess(UIModule.staffDashboard);
});

final canAccessSuperAdminFeaturesProvider = Provider<bool>((ref) {
  final roleGuard = ref.watch(roleGuardServiceProvider);
  return roleGuard.hasUIAccess(UIModule.systemDashboard);
});

final allowedNavigationItemsProvider = Provider<List<NavigationItem>>((ref) {
  final roleGuard = ref.watch(roleGuardServiceProvider);
  return roleGuard.getAllowedNavigationItems();
});
