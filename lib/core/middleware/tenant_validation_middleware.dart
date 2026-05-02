import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';

/// Middleware for validating tenant (school) access
/// Ensures that all repository operations use the correct schoolId from the active session
class TenantValidationMiddleware {
  /// Validates that the provided schoolId matches the active session's schoolId
  /// Throws an exception if validation fails
  static void validateSchoolId(String? providedSchoolId, String? sessionSchoolId) {
    if (sessionSchoolId == null) {
      throw Exception('No active session found. Please log in.');
    }
    
    if (providedSchoolId == null) {
      throw Exception('SchoolId is required for this operation.');
    }
    
    if (providedSchoolId != sessionSchoolId) {
      throw Exception('Security violation: Attempted to access data for school "$providedSchoolId" while session is for school "$sessionSchoolId"');
    }
  }

  /// Validates schoolId using the current session from provider
  /// Returns true if valid, false otherwise
  static bool isValidSchoolId(WidgetRef ref, String? schoolId) {
    final session = ref.read(currentSessionProvider);
    if (session == null || session.schoolId == null) {
      return false;
    }
    return session.schoolId == schoolId;
  }

  /// Gets the current session schoolId
  /// Throws if no active session
  static String getCurrentSchoolId(WidgetRef ref) {
    final session = ref.read(currentSessionProvider);
    if (session == null || session.schoolId == null) {
      throw Exception('No active session or schoolId found');
    }
    return session.schoolId!;
  }

  /// Validates and returns the schoolId, ensuring it matches the active session
  static String validateAndReturnSchoolId(WidgetRef ref, String? providedSchoolId) {
    final sessionSchoolId = getCurrentSchoolId(ref);
    
    if (providedSchoolId == null) {
      throw Exception('SchoolId is required for this operation.');
    }
    
    if (providedSchoolId != sessionSchoolId) {
      throw Exception('Security violation: SchoolId mismatch');
    }
    
    return providedSchoolId;
  }
}
