import 'package:flutter/material.dart';
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
