import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/responsive_theme.dart';
import 'core/security/firebase_rules_verifier.dart';
import 'core/security/firebase_indexes_verifier.dart';
import 'core/providers/theme_provider.dart';
import 'presentation/auth/screens/splash_screen.dart';
import 'config/environment_config.dart';

/// Common main function used by all environment entry points
Future<void> mainCommon() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with environment-specific options
  try {
    print('Initializing Firebase for ${EnvironmentConfig.environmentName}...');
    await Firebase.initializeApp(
      options: EnvironmentConfig.firebaseOptions,
    );
    print('Firebase initialized successfully');
  } catch (e) {
    print('Error initializing Firebase: $e');
  }

  runApp(
    const ProviderScope(
      child: EazySchool360App(),
    ),
  );
}

class EazySchool360App extends ConsumerWidget {
  const EazySchool360App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<bool>(
      future: _initializeApp(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return MaterialApp(
            title: EnvironmentConfig.appName,
            debugShowCheckedModeBanner: false,
            theme: ResponsiveTheme.getThemeData(isDark: false),
            darkTheme: ResponsiveTheme.getThemeData(isDark: true),
            themeMode: ThemeMode.system,
            home: Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      'Loading ${EnvironmentConfig.environmentName}...',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (snapshot.hasError || snapshot.data == false) {
          return MaterialApp(
            title: EnvironmentConfig.appName,
            debugShowCheckedModeBanner: false,
            theme: ResponsiveTheme.getThemeData(isDark: false),
            darkTheme: ResponsiveTheme.getThemeData(isDark: true),
            themeMode: ThemeMode.system,
            home: Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Security Verification Failed',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      snapshot.error?.toString() ?? 'Unknown error occurred',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Environment: ${EnvironmentConfig.environmentName}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Consumer(
          builder: (context, ref, child) {
            final themeMode = ref.watch(themeModeProvider);

            return MaterialApp(
              title: EnvironmentConfig.appName,
              debugShowCheckedModeBanner: !EnvironmentConfig.isProduction,
              theme: ResponsiveTheme.getThemeData(isDark: false),
              darkTheme: ResponsiveTheme.getThemeData(isDark: true),
              themeMode: themeMode,
              home: const SplashScreen(),
            );
          },
        );
      },
    );
  }

  Future<bool> _initializeApp() async {
    try {
      print('🔐 Verifying Firebase Security Rules...');
      // Verify Firebase security rules are deployed and up-to-date
      final rulesValid = await FirebaseRulesVerifier.shouldAllowAppStart(
        projectId: EnvironmentConfig.projectId,
        enforceInProduction: EnvironmentConfig.isProduction,
      );

      if (!rulesValid) {
        print('❌ Firebase security rules verification failed');
        return false;
      }

      print('🔍 Verifying Firebase Indexes...');
      // Verify Firebase indexes are deployed and up-to-date
      final indexesValid = await FirebaseIndexesVerifier.verifyIndexes();

      if (!indexesValid) {
        print(
            '⚠️ Firebase indexes verification failed - attempting auto-deployment');

        // Try to deploy indexes automatically
        final deploymentSuccess = await FirebaseIndexesVerifier.deployIndexes();
        if (!deploymentSuccess) {
          print('❌ Failed to deploy indexes automatically');
          return false;
        }

        // Verify again after deployment
        final indexesValidAfterDeploy =
            await FirebaseIndexesVerifier.verifyIndexes();
        if (!indexesValidAfterDeploy) {
          print('❌ Indexes still invalid after deployment');
          return false;
        }
      }

      // Log status
      await FirebaseIndexesVerifier.logIndexesStatus();

      print('✅ App start allowed - all verifications passed');
      return true;
    } catch (error) {
      print('App initialization failed: $error');
      return false;
    }
  }
}
