import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../domain/entities/app_user.dart';
import '../../widgets/app_logo.dart';
import '../../dashboard/screens/admin_dashboard_screen.dart';
import '../../dashboard/screens/finance_dashboard_screen.dart';
import '../../dashboard/screens/staff_dashboard_screen.dart';
import '../../dashboard/screens/super_admin_dashboard_screen.dart';
import '../../dashboard/screens/parent_dashboard_screen.dart';
import 'enhanced_login_screen.dart';
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
    await Future.delayed(const Duration(seconds: 2)); // Splash delay

    if (!mounted) return;

    try {
      final user = ref.read(authRepositoryProvider).currentUser;
      if (user != null) {
        final appUser = await ref.read(authRepositoryProvider).getUserDetails(user.uid);
        if (appUser != null) {
          if (!appUser.isActive) {
            // User is not active, redirect to waiting activation screen
            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const WaitingActivationScreen()),
              );
            }
            return;
          }

          // User is active, redirect to appropriate dashboard based on role
          if (mounted) {
            switch (appUser.role) {
              case UserRole.SUPER_ADMIN:
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const SuperAdminDashboardScreen()),
                );
                break;
              case UserRole.ADMIN:
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const AdminDashboardScreen()),
                );
                break;
              case UserRole.FINANCE:
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const FinanceDashboardScreen()),
                );
                break;
              case UserRole.STAFF:
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const StaffDashboardScreen()),
                );
                break;
              case UserRole.PARENT:
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const ParentDashboardScreen()),
                );
                break;
              case UserRole.NONE:
                // Handle NONE role - redirect to enhanced login
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const EnhancedLoginScreen()),
                );
                break;
            }
          }
        } else {
          // User details not found, go to login
          _navigateToLogin();
        }
      } else {
        // No user, redirect to login
        _navigateToLogin();
      }
    } catch (e) {
      print('Error checking auth state: $e');
      // On error, go to login
      _navigateToLogin();
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
