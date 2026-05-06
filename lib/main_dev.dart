import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'config/environment_config.dart';
import 'main_common.dart';

void main() async {
  // Set environment to DEV
  EnvironmentConfig.setEnvironment(Environment.dev);
  
  // Print environment info
  EnvironmentConfig.printInfo();
  
  // Run common main
  await mainCommon();
}

// TEMPORARY: Print Firebase Auth Token for Postman testing
// Call this function after signing in to get the token
Future<void> printAuthToken() async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final idToken = await user.getIdToken();
      print('========================================');
      print('FIREBASE ID TOKEN FOR POSTMAN:');
      print(idToken);
      print('========================================');
    } else {
      print('No user signed in. Sign in first to get the token.');
    }
  } catch (e) {
    print('Error getting auth token: $e');
  }
}
