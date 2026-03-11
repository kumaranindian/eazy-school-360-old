import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:eazy_school_360/core/providers/auth_provider.dart';
import 'package:eazy_school_360/core/models/user_session.dart';
import 'package:eazy_school_360/presentation/auth/screens/enhanced_login_screen.dart';
import 'package:eazy_school_360/presentation/auth/screens/splash_screen.dart';
import 'package:eazy_school_360/presentation/dashboards/super_admin_dashboard_screen.dart';
import 'package:eazy_school_360/presentation/dashboards/admin_dashboard_screen.dart';
import 'package:eazy_school_360/presentation/dashboards/staff_dashboard_screen.dart';
import 'package:eazy_school_360/presentation/dashboard/screens/parent_dashboard_screen.dart';

/// Route paths
class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String superAdminDashboard = '/super-admin-dashboard';
  static const String adminDashboard = '/admin-dashboard';
  static const String staffDashboard = '/staff-dashboard';
  static const String parentDashboard = '/parent-dashboard';
}

/// Route guard that checks authentication and authorization
class RouteGuard {
  final WidgetRef ref;

  RouteGuard(this.ref);

  /// Check if user is authenticated
  bool get isAuthenticated {
    return ref.read(isAuthenticatedProvider);
  }

  /// Get current user session
  UserSession? get currentSession {
    return ref.read(currentSessionProvider);
  }

  /// Check if user can access a specific route
  bool canAccessRoute(String route) {
    if (!isAuthenticated || currentSession == null) {
      return false;
    }

    final session = currentSession!;

    // Check if user account is active
    if (!session.isActive) {
      return false;
    }

    // Check if onboarding is complete
    if (!session.isOnboardingComplete) {
      return false;
    }

    // Route-specific access control
    switch (route) {
      case AppRoutes.superAdminDashboard:
        return session.isSuperAdmin;
      
      case AppRoutes.adminDashboard:
        return session.isAdmin && session.hasSchoolAccess;
      
      case AppRoutes.staffDashboard:
        return session.isStaff && session.hasSchoolAccess;
      
      case AppRoutes.parentDashboard:
        return session.isParent && session.hasSchoolAccess;

      default:
        return true;
    }
  }

  /// Get redirect route based on authentication state
  String? getRedirectRoute(String intendedRoute) {
    // If not authenticated, redirect to login
    if (!isAuthenticated) {
      return AppRoutes.login;
    }

    final session = currentSession;
    if (session == null) {
      return AppRoutes.login;
    }

    // If user is disabled, redirect to login
    if (!session.isActive) {
      // Force sign out for disabled users
      ref.read(authProvider.notifier).signOut();
      return AppRoutes.login;
    }

    // If onboarding is not complete, handle appropriately
    if (!session.isOnboardingComplete) {
      // For now, redirect to login. In future, could redirect to onboarding screen
      return AppRoutes.login;
    }

    // If trying to access a route they don't have permission for,
    // redirect to their appropriate dashboard
    if (!canAccessRoute(intendedRoute)) {
      return session.dashboardRoute;
    }

    return null; // No redirect needed
  }
}

/// App router configuration
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    redirect: (context, state) {
      final currentRoute = state.fullPath ?? state.matchedLocation;
      final isAuthenticated = ref.read(isAuthenticatedProvider);
      final currentSession = ref.read(currentSessionProvider);
      
      // Allow splash screen always
      if (currentRoute == AppRoutes.splash) {
        return null;
      }

      // Allow login screen for unauthenticated users
      if (currentRoute == AppRoutes.login && !isAuthenticated) {
        return null;
      }

      // If not authenticated, redirect to login
      if (!isAuthenticated) {
        return AppRoutes.login;
      }

      // If user is disabled, redirect to login
      if (currentSession != null && !currentSession.isActive) {
        ref.read(authProvider.notifier).signOut();
        return AppRoutes.login;
      }

      // If onboarding is not complete, redirect to login
      if (currentSession != null && !currentSession.isOnboardingComplete) {
        return AppRoutes.login;
      }

      // Route-specific access control
      if (currentSession != null) {
        switch (currentRoute) {
          case AppRoutes.superAdminDashboard:
            if (!currentSession.isSuperAdmin) {
              return currentSession.dashboardRoute;
            }
            break;
          case AppRoutes.adminDashboard:
            if (!currentSession.isAdmin || !currentSession.hasSchoolAccess) {
              return currentSession.dashboardRoute;
            }
            break;
          case AppRoutes.staffDashboard:
            if (!currentSession.isStaff || !currentSession.hasSchoolAccess) {
              return currentSession.dashboardRoute;
            }
            break;
          case AppRoutes.parentDashboard:
            if (!currentSession.isParent || !currentSession.hasSchoolAccess) {
              return currentSession.dashboardRoute;
            }
            break;
        }
      }

      return null; // No redirect needed
    },
    routes: [
      // Splash Screen
      GoRoute(
        path: AppRoutes.splash,
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),

      // Login Screen
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        builder: (context, state) => const EnhancedLoginScreen(),
      ),

      // Super Admin Dashboard
      GoRoute(
        path: AppRoutes.superAdminDashboard,
        name: 'super-admin-dashboard',
        builder: (context, state) => const SuperAdminDashboardScreen(),
      ),

      // Admin Dashboard
      GoRoute(
        path: AppRoutes.adminDashboard,
        name: 'admin-dashboard',
        builder: (context, state) => const AdminDashboardScreen(),
      ),

      // Staff Dashboard
      GoRoute(
        path: AppRoutes.staffDashboard,
        name: 'staff-dashboard',
        builder: (context, state) => const StaffDashboardScreen(),
      ),

      // Parent Dashboard
      GoRoute(
        path: AppRoutes.parentDashboard,
        name: 'parent-dashboard',
        builder: (context, state) => const ParentDashboardScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Page Not Found')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Page Not Found',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text('The page "${state.matchedLocation}" could not be found.'),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go(AppRoutes.login),
              child: const Text('Go to Login'),
            ),
          ],
        ),
      ),
    ),
  );
});

/// Navigation helper methods
extension AppNavigation on BuildContext {
  /// Navigate to login screen
  void goToLogin() => go(AppRoutes.login);

  /// Navigate to appropriate dashboard based on user role
  void goToDashboard() {
    final session = ProviderScope.containerOf(this).read(currentSessionProvider);
    if (session != null) {
      go(session.dashboardRoute);
    } else {
      goToLogin();
    }
  }

  /// Navigate to super admin dashboard
  void goToSuperAdminDashboard() => go(AppRoutes.superAdminDashboard);

  /// Navigate to admin dashboard
  void goToAdminDashboard() => go(AppRoutes.adminDashboard);

  /// Navigate to staff dashboard
  void goToStaffDashboard() => go(AppRoutes.staffDashboard);

  /// Navigate to parent dashboard
  void goToParentDashboard() => go(AppRoutes.parentDashboard);
}
