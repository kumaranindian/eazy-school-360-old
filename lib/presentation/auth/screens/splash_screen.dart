import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../domain/entities/app_user.dart';
import '../../widgets/app_logo.dart';
import '../../dashboard/screens/admin_dashboard_screen.dart';
import '../../dashboard/screens/finance_dashboard_screen.dart';
import '../../dashboard/screens/staff_dashboard_screen.dart';
import '../../dashboard/screens/super_admin_dashboard_screen.dart';
import '../../dashboard/screens/parent_dashboard_screen.dart';
import 'enhanced_login_screen.dart';
import 'school_chooser_screen.dart';
import 'waiting_activation_screen.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthState();
  }

  Future<void> _checkAuthState() async {
    // Give the splash some minimum visible time and the auth provider a chance
    // to finish its own initialization (it's already running in the
    // background from app startup).
    await Future.delayed(const Duration(milliseconds: 1200));

    // Wait for the auth provider to leave the initial/loading state so we
    // have an up-to-date session (including memberships) before routing.
    try {
      await _waitForAuthReady();
    } catch (_) {/* fall through to routing logic */}

    if (!mounted) return;

    final session = ref.read(currentSessionProvider);
    final authState = ref.read(authProvider);

    // No Firebase user or session -> login screen.
    if (session == null || authState == AuthState.unauthenticated) {
      _navigateToLogin();
      return;
    }

    // Inactive user OR inactive active membership -> waiting activation.
    if (!session.isActive) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const WaitingActivationScreen()),
      );
      return;
    }

    // Multi-tenant user with no resolved active school -> school chooser.
    final needsChooser = session.role != UserRole.SUPER_ADMIN &&
        session.schoolId == null &&
        session.memberships.length > 1;
    if (needsChooser) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => SchoolChooserScreen(
            routeBuilder: (m) => _routeNameForRole(m.primaryRole),
          ),
        ),
      );
      return;
    }

    // Resolve effective role: use session.role, or if NONE fall back to the
    // single membership's primary role (multi-tenant user with one school).
    UserRole role = session.role;
    if (role == UserRole.NONE && session.memberships.length == 1) {
      role = session.memberships.first.primaryRole;
    }

    _navigateByRole(role);
  }

  /// Poll the auth provider briefly until it's no longer initial/loading.
  Future<void> _waitForAuthReady() async {
    const maxAttempts = 20; // ~3s max (20 * 150ms)
    for (int i = 0; i < maxAttempts; i++) {
      final s = ref.read(authProvider);
      if (s != AuthState.initial && s != AuthState.loading) return;
      await Future.delayed(const Duration(milliseconds: 150));
    }
  }

  void _navigateByRole(UserRole role) {
    if (!mounted) return;
    switch (role) {
      case UserRole.SUPER_ADMIN:
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => const SuperAdminDashboardScreen()));
        break;
      case UserRole.ADMIN:
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => const AdminDashboardScreen()));
        break;
      case UserRole.FINANCE:
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => const FinanceDashboardScreen()));
        break;
      case UserRole.STAFF:
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => const StaffDashboardScreen()));
        break;
      case UserRole.PARENT:
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => const ParentDashboardScreen()));
        break;
      case UserRole.NONE:
        _navigateToLogin();
        break;
    }
  }

  String _routeNameForRole(UserRole role) {
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

  void _navigateToLogin() {
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const EnhancedLoginScreen()),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo
            const AppLogo(
              size: 120,
              useImage: true,
            ),
            const SizedBox(height: 24),
            
            // App Name
            Text(
              AppConstants.appName,
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFE6EDF3),
                  ),
            ),
            const SizedBox(height: 8),
            
            // Tagline
            Text(
              'School Management Made Easy',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: const Color(0xFF8B949E),
                  ),
            ),
            const SizedBox(height: 48),
            
            // Loading Indicator
            CircularProgressIndicator(
              color: const Color(0xFF4CAF50),
            ),
          ],
        ),
      ),
    );
  }
}
