import 'package:flutter/material.dart';
import 'app_logger.dart';

/// Centralized error handling for production readiness
/// Provides consistent error messages and logging
class ErrorHandler {
  /// Handle and log errors with user-friendly messages
  static String handleError(Object error, {String? context}) {
    final tag = context ?? 'ERROR_HANDLER';
    
    String userMessage;
    
    if (error is NetworkException) {
      userMessage = 'Network error. Please check your connection and try again.';
      AppLogger.error(tag, 'Network error: ${error.message}');
    } else if (error is AuthException) {
      userMessage = error.userMessage;
      AppLogger.error(tag, 'Auth error: ${error.message}');
    } else if (error is ValidationException) {
      userMessage = error.message;
      AppLogger.warning(tag, 'Validation error: ${error.message}');
    } else if (error is PermissionException) {
      userMessage = 'You do not have permission to perform this action.';
      AppLogger.warning(tag, 'Permission denied: ${error.message}');
    } else if (error.toString().contains('permission-denied')) {
      userMessage = 'You do not have permission to perform this action.';
      AppLogger.warning(tag, 'Firebase permission denied');
    } else if (error.toString().contains('network')) {
      userMessage = 'Network error. Please check your connection.';
      AppLogger.error(tag, 'Network error: $error');
    } else if (error.toString().contains('not-found')) {
      userMessage = 'The requested resource was not found.';
      AppLogger.warning(tag, 'Resource not found: $error');
    } else {
      userMessage = 'An unexpected error occurred. Please try again.';
      AppLogger.error(tag, 'Unexpected error: $error');
    }
    
    return userMessage;
  }

  /// Show error snackbar with consistent styling
  static void showErrorSnackBar(BuildContext context, String message) {
    if (!context.mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  /// Show success snackbar
  static void showSuccessSnackBar(BuildContext context, String message) {
    if (!context.mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Show warning snackbar
  static void showWarningSnackBar(BuildContext context, String message) {
    if (!context.mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning_amber_outlined, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.orange.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }
}

/// Custom exception types for better error handling
class NetworkException implements Exception {
  final String message;
  NetworkException(this.message);
  
  @override
  String toString() => 'NetworkException: $message';
}

class AuthException implements Exception {
  final String message;
  final String userMessage;
  
  AuthException(this.message, {String? userMessage}) 
      : userMessage = userMessage ?? 'Authentication error. Please try again.';
  
  @override
  String toString() => 'AuthException: $message';
}

class ValidationException implements Exception {
  final String message;
  ValidationException(this.message);
  
  @override
  String toString() => 'ValidationException: $message';
}

class PermissionException implements Exception {
  final String message;
  PermissionException(this.message);
  
  @override
  String toString() => 'PermissionException: $message';
}

class DataException implements Exception {
  final String message;
  DataException(this.message);
  
  @override
  String toString() => 'DataException: $message';
}
