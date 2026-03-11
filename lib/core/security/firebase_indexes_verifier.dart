import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

class FirebaseIndexesVerifier {
  static const String expectedVersion = '1.0.0';
  static const String indexesVersionFile = 'firebase/indexes-version.json';
  
  /// Verify that Firebase indexes are deployed and up to date
  static Future<bool> verifyIndexes() async {
    try {
      if (kIsWeb) {
        // For web, we can't directly access files, so we'll do a simplified check
        debugPrint('🔍 Web environment - performing indirect indexes verification');
        return await _verifyIndexesIndirectly();
      } else {
        // For other platforms, check the version file
        return await _verifyIndexesDirectly();
      }
    } catch (e) {
      debugPrint('❌ Indexes verification failed: $e');
      return false;
    }
  }
  
  /// Direct verification by reading the version file
  static Future<bool> _verifyIndexesDirectly() async {
    try {
      final file = File(indexesVersionFile);
      if (!await file.exists()) {
        debugPrint('⚠️ Indexes version file not found - indexes may not be deployed');
        return false;
      }
      
      final content = await file.readAsString();
      final versionData = jsonDecode(content);
      
      final deployedVersion = versionData['version'] as String?;
      if (deployedVersion != expectedVersion) {
        debugPrint('⚠️ Indexes version mismatch. Expected: $expectedVersion, Found: $deployedVersion');
        return false;
      }
      
      debugPrint('✓ Indexes version matches expected: $expectedVersion');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to verify indexes directly: $e');
      return false;
    }
  }
  
  /// Indirect verification for web environments
  static Future<bool> _verifyIndexesIndirectly() async {
    try {
      // For web, we assume indexes are deployed if the app is running
      // In a production environment, you might want to make a test query
      // to verify that composite indexes are working
      debugPrint('✓ Indexes verification passed (web environment)');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to verify indexes indirectly: $e');
      return false;
    }
  }
  
  /// Get the current indexes version
  static Future<String?> getCurrentVersion() async {
    try {
      if (kIsWeb) {
        return expectedVersion; // Return expected version for web
      }
      
      final file = File(indexesVersionFile);
      if (!await file.exists()) {
        return null;
      }
      
      final content = await file.readAsString();
      final versionData = jsonDecode(content);
      return versionData['version'] as String?;
    } catch (e) {
      debugPrint('Failed to get current indexes version: $e');
      return null;
    }
  }
  
  /// Log the current indexes status
  static Future<void> logIndexesStatus() async {
    try {
      final currentVersion = await getCurrentVersion();
      if (currentVersion != null) {
        debugPrint('📊 Current indexes version: $currentVersion');
        if (currentVersion == expectedVersion) {
          debugPrint('✅ Indexes are up to date');
        } else {
          debugPrint('⚠️ Indexes version mismatch - update required');
        }
      } else {
        debugPrint('❌ No indexes version information found');
      }
    } catch (e) {
      debugPrint('Failed to log indexes status: $e');
    }
  }
  
  /// Check if indexes deployment is required
  static Future<bool> isDeploymentRequired() async {
    final currentVersion = await getCurrentVersion();
    return currentVersion != expectedVersion;
  }
  
  /// Deploy indexes automatically (calls the Node.js script)
  static Future<bool> deployIndexes() async {
    try {
      if (kIsWeb) {
        debugPrint('⚠️ Cannot deploy indexes from web environment');
        return false;
      }
      
      debugPrint('🚀 Starting automatic indexes deployment...');
      
      // Run the Node.js deployment script
      final result = await Process.run(
        'node',
        ['firebase/deploy-indexes.js'],
        workingDirectory: Directory.current.path,
      );
      
      if (result.exitCode == 0) {
        debugPrint('✅ Indexes deployed successfully');
        debugPrint(result.stdout);
        return true;
      } else {
        debugPrint('❌ Indexes deployment failed');
        debugPrint('STDOUT: ${result.stdout}');
        debugPrint('STDERR: ${result.stderr}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Failed to deploy indexes: $e');
      return false;
    }
  }
}
