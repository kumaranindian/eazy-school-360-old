import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_session.dart';

/// Secure storage service for encrypting and storing session data
/// Uses Flutter Secure Storage for sensitive data and SharedPreferences for non-sensitive data
class SecureSessionStorage {
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  // Keys for secure storage
  static const String _keySessionData = 'session_data';
  static const String _keySessionToken = 'session_token';

  // Keys for shared preferences (non-sensitive data)
  static const String _keyThemeMode = 'theme_mode';
  static const String _keyLanguage = 'language';

  /// Save session data securely
  static Future<void> saveSession(UserSession session) async {
    try {
      final sessionJson = jsonEncode(session.toJson());
      await _secureStorage.write(key: _keySessionData, value: sessionJson);
      await _secureStorage.write(
        key: _keySessionToken,
        value: _generateSessionHash(session),
      );
    } catch (e) {
      print('Error saving session securely: $e');
      rethrow;
    }
  }

  /// Load session data securely
  static Future<UserSession?> loadSession() async {
    try {
      final sessionJson = await _secureStorage.read(key: _keySessionData);
      if (sessionJson == null) return null;

      final storedHash = await _secureStorage.read(key: _keySessionToken);
      if (storedHash == null) return null;

      final sessionData = jsonDecode(sessionJson) as Map<String, dynamic>;
      final session = UserSession.fromJson(sessionData);

      // Verify session integrity
      final currentHash = _generateSessionHash(session);
      if (storedHash != currentHash) {
        print('Session integrity check failed - clearing session');
        await clearSession();
        return null;
      }

      return session;
    } catch (e) {
      print('Error loading session securely: $e');
      return null;
    }
  }

  /// Clear session data securely
  static Future<void> clearSession() async {
    try {
      await _secureStorage.delete(key: _keySessionData);
      await _secureStorage.delete(key: _keySessionToken);

      // Also clear non-sensitive preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } catch (e) {
      print('Error clearing session securely: $e');
      rethrow;
    }
  }

  /// Save non-sensitive user preferences
  static Future<void> savePreference(String key, String value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, value);
    } catch (e) {
      print('Error saving preference: $e');
    }
  }

  /// Load non-sensitive user preferences
  static Future<String?> loadPreference(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(key);
    } catch (e) {
      print('Error loading preference: $e');
      return null;
    }
  }

  /// Generate a hash for session integrity verification
  static String _generateSessionHash(UserSession session) {
    final data =
        '${session.uid}|${session.email}|${session.schoolId}|${session.lastLoginAt.toIso8601String()}';
    final bytes = utf8.encode(data);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Verify session integrity
  static Future<bool> verifySessionIntegrity() async {
    try {
      final session = await loadSession();
      if (session == null) return false;

      final storedHash = await _secureStorage.read(key: _keySessionToken);
      final currentHash = _generateSessionHash(session);

      return storedHash == currentHash;
    } catch (e) {
      print('Error verifying session integrity: $e');
      return false;
    }
  }

  /// Update session school ID (for school switching)
  static Future<void> updateSchoolId(String newSchoolId) async {
    try {
      final session = await loadSession();
      if (session == null) return;

      final updatedSession = session.copyWith(schoolId: newSchoolId);
      await saveSession(updatedSession);
    } catch (e) {
      print('Error updating school ID: $e');
      rethrow;
    }
  }
}
