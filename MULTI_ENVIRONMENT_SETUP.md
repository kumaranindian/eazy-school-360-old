# Multi-Environment Setup Guide

This guide explains how to use the multi-environment configuration for Eazy School 360.

## 📋 Overview

The app supports 4 environments:
- **DEV** (`eazyschool-360-dev`) - Development environment
- **TEST** (`eazyschool-360-test`) - Testing environment
- **UAT** (`eazyschool-360-uat`) - User Acceptance Testing
- **PROD** (`eazy-school-360`) - Production environment

## 🚀 Running the App

### Option 1: VS Code (Recommended)

1. Open VS Code
2. Press `F5` or go to **Run and Debug**
3. Select the environment from the dropdown:
   - 🔵 DEV (eazyschool-360-dev)
   - 🟡 TEST (eazyschool-360-test)
   - 🟠 UAT (eazyschool-360-uat)
   - 🔴 PROD (eazy-school-360)

### Option 2: Command Line

```bash
# Run DEV environment
flutter run -d chrome lib/main_dev.dart

# Run TEST environment
flutter run -d chrome lib/main_test.dart

# Run UAT environment
flutter run -d chrome lib/main_uat.dart

# Run PROD environment
flutter run -d chrome lib/main_prod.dart
```

### Option 3: Build for Production

```bash
# Build DEV
flutter build web --dart-define-from-file=.env.dev lib/main_dev.dart

# Build PROD
flutter build web --dart-define-from-file=.env.prod lib/main_prod.dart
```

## 🔧 Firebase Projects

| Environment | Project ID | Firebase Console |
|---|---|---|
| DEV | `eazyschool-360-dev` | [Console](https://console.firebase.google.com/project/eazyschool-360-dev) |
| TEST | `eazyschool-360-test` | [Console](https://console.firebase.google.com/project/eazyschool-360-test) |
| UAT | `eazyschool-360-uat` | [Console](https://console.firebase.google.com/project/eazyschool-360-uat) |
| PROD | `eazy-school-360` | [Console](https://console.firebase.google.com/project/eazy-school-360) |

## 📁 Configuration Files

### Firebase Options
- `lib/config/firebase_options_dev.dart` - DEV Firebase config
- `lib/config/firebase_options_test.dart` - TEST Firebase config
- `lib/config/firebase_options_uat.dart` - UAT Firebase config
- `lib/config/firebase_options_prod.dart` - PROD Firebase config

### Entry Points
- `lib/main_dev.dart` - DEV entry point
- `lib/main_test.dart` - TEST entry point
- `lib/main_uat.dart` - UAT entry point
- `lib/main_prod.dart` - PROD entry point
- `lib/main_common.dart` - Shared main logic

### Environment Config
- `lib/config/environment_config.dart` - Central environment configuration

## 🔐 Firebase Authentication

**Important:** Firebase Authentication is global across all Firebase projects. Your user account (`hi@avail404.com`) exists independently.

**To separate data by environment:**
- Each Firebase project has its own Firestore database
- Each environment has separate schools, staff, attendance records
- Use different email accounts for testing different environments

## 🌐 Cloud Functions Region

All Cloud Functions are deployed to `asia-south1` (Mumbai) for low latency in India.

## 📊 Environment-Specific Features

| Feature | DEV | TEST | UAT | PROD |
|---|---|---|---|---|
| Debug Logging | ✅ | ✅ | ✅ | ❌ |
| Analytics | ❌ | ❌ | ❌ | ✅ |
| Crash Reporting | ❌ | ❌ | ✅ | ✅ |
| Debug Banner | ✅ | ✅ | ✅ | ❌ |

## 🔍 Environment Detection

The app automatically detects the environment based on the entry point used. You can check the current environment in code:

```dart
import 'config/environment_config.dart';

// Check current environment
if (EnvironmentConfig.isDevelopment) {
  // DEV-specific code
}

if (EnvironmentConfig.isProduction) {
  // PROD-specific code
}

// Get project ID
print(EnvironmentConfig.projectId); // e.g., 'eazyschool-360-dev'

// Get app name
print(EnvironmentConfig.appName); // e.g., 'EazySchool 360 [DEV]'
```

## 🔄 Switching Firebase Projects

To switch Firebase projects for Cloud Functions deployment:

```bash
# Switch to DEV
firebase use eazyschool-360-dev

# Switch to PROD
firebase use eazy-school-360

# List all projects
firebase projects:list
```

## 📝 Adding a New Environment

1. Create new Firebase project
2. Generate Firebase options: `flutterfire configure`
3. Create `lib/config/firebase_options_newenv.dart`
4. Create `lib/main_newenv.dart`
5. Add environment to `lib/config/environment_config.dart`
6. Add VS Code launch configuration in `.vscode/launch.json`

## ⚠️ Important Notes

1. **Never run PROD in development mode** - Always use the PROD entry point
2. **Keep PROD data separate** - Don't mix test data with production
3. **Deploy functions to correct project** - Always check `firebase use` before deploying
4. **Environment-specific configs** - Each environment has its own Firebase project

## 🐛 Troubleshooting

### App shows wrong Firebase project
- Check which entry point you're using (main_dev.dart vs main_prod.dart)
- Verify Firebase options in the corresponding config file

### Functions deployed to wrong region
- Check `functions/src/*.js` files for `.region('asia-south1')`
- Verify `.firebaserc` has correct project

### Authentication issues
- Firebase Auth is global - same credentials work across projects
- Firestore data is project-specific - check correct project in console
