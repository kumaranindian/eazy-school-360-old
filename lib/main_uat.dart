import 'package:flutter/material.dart';
import 'config/environment_config.dart';
import 'main_common.dart';

void main() async {
  // Set environment to UAT
  EnvironmentConfig.setEnvironment(Environment.uat);
  
  // Print environment info
  EnvironmentConfig.printInfo();
  
  // Run common main
  await mainCommon();
}
