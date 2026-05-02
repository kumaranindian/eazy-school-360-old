import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/responsive_theme.dart';
import 'core/security/firebase_rules_verifier.dart';
import 'core/security/firebase_indexes_verifier.dart';
import 'core/providers/theme_provider.dart';
import 'presentation/auth/screens/splash_screen.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  try {
    print('Initializing Firebase...');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
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
            title: 'Eazy School 360',
            debugShowCheckedModeBanner: false,
            theme: ResponsiveTheme.getThemeData(isDark: false),
            darkTheme: ResponsiveTheme.getThemeData(isDark: true),
            themeMode: ThemeMode.system,
            home: const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            ),
          );
        }

        if (snapshot.hasError || snapshot.data == false) {
          return MaterialApp(
            title: 'Eazy School 360',
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
              title: 'Eazy School 360',
              debugShowCheckedModeBanner: false,
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
        projectId: 'your-firebase-project-id', // Replace with actual project ID
        enforceInProduction: true,
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
