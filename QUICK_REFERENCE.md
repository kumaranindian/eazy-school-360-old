# Quick Reference - Multi-Environment Setup

## 🎯 Run App

```bash
# DEV
flutter run -d chrome lib/main_dev.dart

# TEST  
flutter run -d chrome lib/main_test.dart

# UAT
flutter run -d chrome lib/main_uat.dart

# PROD
flutter run -d chrome lib/main_prod.dart
```

## 🚀 Deploy Backend

```powershell
# DEV
.\scripts\deploy-dev.ps1

# TEST
.\scripts\deploy-test.ps1

# UAT
.\scripts\deploy-uat.ps1

# PROD (requires confirmation)
.\scripts\deploy-prod.ps1
```

## 🔄 Switch Firebase Project

```bash
firebase use dev     # eazyschool-360-dev
firebase use test    # eazyschool-360-test
firebase use uat     # eazyschool-360-uat
firebase use prod    # eazy-school-360
```

## 📊 Check Current Project

```bash
firebase use
```

## 🔍 View Functions

```bash
firebase functions:list
```

## 📝 View Logs

```bash
firebase functions:log
firebase functions:log --only functionName
```

## 🏗️ Build Flutter

```bash
# DEV
flutter build web lib/main_dev.dart

# PROD
flutter build web lib/main_prod.dart
```

## 📱 Firebase Console Links

- **DEV**: https://console.firebase.google.com/project/eazyschool-360-dev
- **TEST**: https://console.firebase.google.com/project/eazyschool-360-test
- **UAT**: https://console.firebase.google.com/project/eazyschool-360-uat
- **PROD**: https://console.firebase.google.com/project/eazy-school-360

## 🔐 Environment Check in Code

```dart
import 'config/environment_config.dart';

// Check environment
EnvironmentConfig.isDevelopment  // true in DEV
EnvironmentConfig.isProduction   // true in PROD
EnvironmentConfig.projectId      // Current project ID
EnvironmentConfig.environmentName // "DEV", "TEST", "UAT", "PROD"
```

## ⚡ VS Code Launch

Press `F5` and select:
- 🔵 DEV (eazyschool-360-dev)
- 🟡 TEST (eazyschool-360-test)
- 🟠 UAT (eazyschool-360-uat)
- 🔴 PROD (eazy-school-360)
