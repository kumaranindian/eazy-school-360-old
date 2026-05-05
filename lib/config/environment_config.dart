import 'package:firebase_core/firebase_core.dart';
import 'firebase_options_dev.dart' as dev;
import 'firebase_options_test.dart' as test;
import 'firebase_options_uat.dart' as uat;
import 'firebase_options_prod.dart' as prod;

/// Environment types
enum Environment {
  dev,
  test,
  uat,
  prod,
}

/// Environment configuration manager
class EnvironmentConfig {
  static Environment _currentEnvironment = Environment.dev;

  /// Get current environment
  static Environment get current => _currentEnvironment;

  /// Set current environment
  static void setEnvironment(Environment environment) {
    _currentEnvironment = environment;
    print('🌍 [ENV] Environment set to: ${environment.name.toUpperCase()}');
  }

  /// Get Firebase options for current environment
  static FirebaseOptions get firebaseOptions {
    switch (_currentEnvironment) {
      case Environment.dev:
        return dev.DefaultFirebaseOptions.currentPlatform;
      case Environment.test:
        return test.DefaultFirebaseOptions.currentPlatform;
      case Environment.uat:
        return uat.DefaultFirebaseOptions.currentPlatform;
      case Environment.prod:
        return prod.DefaultFirebaseOptions.currentPlatform;
    }
  }

  /// Get project ID for current environment
  static String get projectId {
    switch (_currentEnvironment) {
      case Environment.dev:
        return 'eazyschool-360-dev';
      case Environment.test:
        return 'eazyschool-360-test';
      case Environment.uat:
        return 'eazyschool-360-uat';
      case Environment.prod:
        return 'eazy-school-360';
    }
  }

  /// Get environment name
  static String get environmentName => _currentEnvironment.name.toUpperCase();

  /// Check if current environment is production
  static bool get isProduction => _currentEnvironment == Environment.prod;

  /// Check if current environment is development
  static bool get isDevelopment => _currentEnvironment == Environment.dev;

  /// Check if current environment is test
  static bool get isTest => _currentEnvironment == Environment.test;

  /// Check if current environment is UAT
  static bool get isUAT => _currentEnvironment == Environment.uat;

  /// Get API base URL (if you have backend APIs)
  static String get apiBaseUrl {
    switch (_currentEnvironment) {
      case Environment.dev:
        return 'https://dev-api.eazyschool360.com';
      case Environment.test:
        return 'https://test-api.eazyschool360.com';
      case Environment.uat:
        return 'https://uat-api.eazyschool360.com';
      case Environment.prod:
        return 'https://api.eazyschool360.com';
    }
  }

  /// Get Firebase region for Cloud Functions
  static String get functionsRegion {
    return 'asia-south1';
  }

  /// Get app name with environment suffix
  static String get appName {
    switch (_currentEnvironment) {
      case Environment.dev:
        return 'EazySchool 360 [DEV]';
      case Environment.test:
        return 'EazySchool 360 [TEST]';
      case Environment.uat:
        return 'EazySchool 360 [UAT]';
      case Environment.prod:
        return 'EazySchool 360';
    }
  }

  /// Enable debug logging for non-production environments
  static bool get enableDebugLogging => !isProduction;

  /// Enable analytics for production only
  static bool get enableAnalytics => isProduction;

  /// Enable crash reporting
  static bool get enableCrashReporting => isProduction || isUAT;

  /// Print environment info
  static void printInfo() {
    print('');
    print('═══════════════════════════════════════════════════════');
    print('🚀 EAZYSCHOOL 360 - ${environmentName} ENVIRONMENT');
    print('═══════════════════════════════════════════════════════');
    print('📦 Project ID: $projectId');
    print('🌐 API Base URL: $apiBaseUrl');
    print('📱 App Name: $appName');
    print('🐛 Debug Logging: ${enableDebugLogging ? 'ENABLED' : 'DISABLED'}');
    print('📊 Analytics: ${enableAnalytics ? 'ENABLED' : 'DISABLED'}');
    print('💥 Crash Reporting: ${enableCrashReporting ? 'ENABLED' : 'DISABLED'}');
    print('═══════════════════════════════════════════════════════');
    print('');
  }
}
