import 'package:flutter/foundation.dart';

/// Production-ready logging service with configurable log levels
/// Replaces print() statements for better production control
class AppLogger {
  static LogLevel _minLevel = kDebugMode ? LogLevel.debug : LogLevel.warning;
  
  /// Set minimum log level (useful for production vs debug)
  static void setMinLevel(LogLevel level) {
    _minLevel = level;
  }

  /// Debug level - only shown in debug mode
  static void debug(String tag, String message) {
    _log(LogLevel.debug, tag, message);
  }

  /// Info level - general information
  static void info(String tag, String message) {
    _log(LogLevel.info, tag, message);
  }

  /// Warning level - potential issues
  static void warning(String tag, String message) {
    _log(LogLevel.warning, tag, message);
  }

  /// Error level - errors that need attention
  static void error(String tag, String message, [Object? error, StackTrace? stackTrace]) {
    _log(LogLevel.error, tag, message);
    if (error != null) {
      _log(LogLevel.error, tag, 'Error: $error');
    }
    if (stackTrace != null && kDebugMode) {
      _log(LogLevel.error, tag, 'StackTrace: $stackTrace');
    }
  }

  /// Success indicator
  static void success(String tag, String message) {
    _log(LogLevel.info, tag, '✅ $message');
  }

  static void _log(LogLevel level, String tag, String message) {
    if (level.index < _minLevel.index) return;
    
    final prefix = _getLevelPrefix(level);
    
    // In production, you could send logs to a service like Firebase Crashlytics
    // For now, we use debugPrint which is throttled and safer than print()
    if (kDebugMode) {
      debugPrint('$prefix [$tag] $message');
    } else if (level == LogLevel.error || level == LogLevel.warning) {
      // In release mode, only log errors and warnings
      debugPrint('$prefix [$tag] $message');
    }
  }

  static String _getLevelPrefix(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return '🔍 DEBUG';
      case LogLevel.info:
        return 'ℹ️ INFO';
      case LogLevel.warning:
        return '⚠️ WARN';
      case LogLevel.error:
        return '❌ ERROR';
    }
  }
}

enum LogLevel {
  debug,
  info,
  warning,
  error,
}
