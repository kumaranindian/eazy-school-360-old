import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../widgets/custom_button.dart';
import '../../dashboard/screens/admin_dashboard_screen.dart';
import 'enhanced_login_screen.dart';

class WaitingActivationScreen extends ConsumerWidget {
  const WaitingActivationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo and App Name
                Column(
                  children: [
                    Icon(
                      Icons.hourglass_bottom_rounded,
                      size: 80,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      AppConstants.appName,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Account Pending Activation',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Message
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Your school account is pending activation by the administrator.',
                        style: Theme.of(context).textTheme.bodyLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Please contact support for more information or to expedite the activation process.',
                        style: Theme.of(context).textTheme.bodyLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Once your account is activated, you will be able to log in and access all features.',
                        style: Theme.of(context).textTheme.bodyLarge,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Contact Support Button
                CustomButton(
                  text: 'Contact Support',
                  onPressed: () {
                    // TODO: Implement contact support functionality
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Support contact: support@eazyschool360.com'),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),

                // Try Again Button
                CustomButton(
                  text: 'Try Again',
                  onPressed: () async {
                    // Refresh user data and check if activated
                    final user = ref.read(authRepositoryProvider).currentUser;
                    if (user != null) {
                      final appUser = await ref.read(authRepositoryProvider).getUserDetails(user.uid);
                      if (appUser != null && appUser.isActive) {
                        // User is now active, redirect to dashboard
                        if (context.mounted) {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (context) => const AdminDashboardScreen()),
                          );
                        }
                      } else {
                        // Still not activated
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Your account is still pending activation.'),
                            ),
                          );
                        }
                      }
                    }
                  },
                  buttonType: ButtonType.outlined,
                ),
                const SizedBox(height: 16),

                // Sign Out Button
                TextButton(
                  onPressed: () async {
                    await ref.read(authRepositoryProvider).signOut();
                    if (context.mounted) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => const EnhancedLoginScreen()),
                      );
                    }
                  },
                  child: const Text('Sign Out'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
