# 🌍 Firebase Multi-Environment Setup Guide

## Overview

This guide explains how to run the EazySchool 360 app with multiple Firebase environments (dev, test, UAT, prod).

---

## 📂 File Structure

```
lib/
├── config/
│   ├── environment_config.dart          # Environment manager
│   ├── firebase_options_dev.dart        # DEV Firebase config
│   ├── firebase_options_test.dart       # TEST Firebase config
│   ├── firebase_options_uat.dart        # UAT Firebase config
│   └── firebase_options_prod.dart       # PROD Firebase config
├── main.dart                            # Default entry (uses prod)
├── main_common.dart                     # Shared app initialization
├── main_dev.dart                        # DEV entry point
├── main_test.dart                       # TEST entry point
├── main_uat.dart                        # UAT entry point
└── main_prod.dart                       # PROD entry point
```

---

## 🔧 Setup Steps

### Step 1: Create Firebase Projects

Create 4 Firebase projects in Firebase Console:

1. **eazyschool-360-dev** (Development)
2. **eazyschool-360-test** (Testing)
3. **eazyschool-360-uat** (User Acceptance Testing)
4. **eazy-school-360** (Production - already exists)

### Step 2: Add Web Apps to Each Project

For each Firebase project:

1. Go to Project Settings
2. Click "Add app" → Web
3. Register app with name: "EazySchool 360 Web"
4. Copy the Firebase configuration

### Step 3: Update Configuration Files

Update the Firebase config files with your project credentials:

#### `lib/config/firebase_options_dev.dart`
✅ Already configured with your DEV project

#### `lib/config/firebase_options_test.dart`
Replace placeholders with TEST project values:
```dart
static const FirebaseOptions web = FirebaseOptions(
  apiKey: 'YOUR_TEST_API_KEY',
  appId: 'YOUR_TEST_APP_ID',
  messagingSenderId: 'YOUR_TEST_SENDER_ID',
  projectId: 'eazyschool-360-test',
  authDomain: 'eazyschool-360-test.firebaseapp.com',
  storageBucket: 'eazyschool-360-test.firebasestorage.app',
  measurementId: 'YOUR_TEST_MEASUREMENT_ID',
);
```

#### `lib/config/firebase_options_uat.dart`
Replace placeholders with UAT project values

#### `lib/config/firebase_options_prod.dart`
Replace placeholders with PROD project values

---

## 🚀 Running Different Environments

### Development Environment
```bash
flutter run -t lib/main_dev.dart -d chrome
```

### Test Environment
```bash
flutter run -t lib/main_test.dart -d chrome
```

### UAT Environment
```bash
flutter run -t lib/main_uat.dart -d chrome
```

### Production Environment
```bash
flutter run -t lib/main_prod.dart -d chrome
```

Or use default main.dart (currently points to prod):
```bash
flutter run -d chrome
```

---

## 📱 Building for Different Environments

### Web Build

**Development**:
```bash
flutter build web -t lib/main_dev.dart --release
```

**Test**:
```bash
flutter build web -t lib/main_test.dart --release
```

**UAT**:
```bash
flutter build web -t lib/main_uat.dart --release
```

**Production**:
```bash
flutter build web -t lib/main_prod.dart --release
```

### Android Build

**Development**:
```bash
flutter build apk -t lib/main_dev.dart --release
```

**Production**:
```bash
flutter build apk -t lib/main_prod.dart --release
```

### iOS Build

**Development**:
```bash
flutter build ios -t lib/main_dev.dart --release
```

**Production**:
```bash
flutter build ios -t lib/main_prod.dart --release
```

---

## 🎨 VS Code Launch Configurations

Add to `.vscode/launch.json`:

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "EazySchool 360 (DEV)",
      "request": "launch",
      "type": "dart",
      "program": "lib/main_dev.dart",
      "args": [
        "--dart-define=ENVIRONMENT=dev"
      ]
    },
    {
      "name": "EazySchool 360 (TEST)",
      "request": "launch",
      "type": "dart",
      "program": "lib/main_test.dart",
      "args": [
        "--dart-define=ENVIRONMENT=test"
      ]
    },
    {
      "name": "EazySchool 360 (UAT)",
      "request": "launch",
      "type": "dart",
      "program": "lib/main_uat.dart",
      "args": [
        "--dart-define=ENVIRONMENT=uat"
      ]
    },
    {
      "name": "EazySchool 360 (PROD)",
      "request": "launch",
      "type": "dart",
      "program": "lib/main_prod.dart",
      "args": [
        "--dart-define=ENVIRONMENT=prod"
      ]
    }
  ]
}
```

---

## 🔐 Deploying Cloud Functions

Each environment has its own Cloud Functions.

### Deploy to DEV
```bash
firebase use eazyschool-360-dev
firebase deploy --only functions
```

### Deploy to TEST
```bash
firebase use eazyschool-360-test
firebase deploy --only functions
```

### Deploy to UAT
```bash
firebase use eazyschool-360-uat
firebase deploy --only functions
```

### Deploy to PROD
```bash
firebase use eazy-school-360
firebase deploy --only functions
```

---

## 📋 Deploying Firestore Rules

### Deploy to DEV
```bash
firebase use eazyschool-360-dev
firebase deploy --only firestore:rules
```

### Deploy to TEST
```bash
firebase use eazyschool-360-test
firebase deploy --only firestore:rules
```

### Deploy to UAT
```bash
firebase use eazyschool-360-uat
firebase deploy --only firestore:rules
```

### Deploy to PROD
```bash
firebase use eazy-school-360
firebase deploy --only firestore:rules
```

---

## 🎯 Environment Configuration

The `EnvironmentConfig` class provides environment-specific settings:

```dart
// Get current environment
Environment env = EnvironmentConfig.current;

// Get project ID
String projectId = EnvironmentConfig.projectId;

// Get app name
String appName = EnvironmentConfig.appName;

// Check environment
bool isProd = EnvironmentConfig.isProduction;
bool isDev = EnvironmentConfig.isDevelopment;

// Get API base URL
String apiUrl = EnvironmentConfig.apiBaseUrl;

// Feature flags
bool enableDebugLogging = EnvironmentConfig.enableDebugLogging;
bool enableAnalytics = EnvironmentConfig.enableAnalytics;
bool enableCrashReporting = EnvironmentConfig.enableCrashReporting;
```

---

## 🔄 Environment-Specific Features

### Debug Logging
- **Enabled**: DEV, TEST, UAT
- **Disabled**: PROD

### Analytics
- **Enabled**: PROD only
- **Disabled**: DEV, TEST, UAT

### Crash Reporting
- **Enabled**: UAT, PROD
- **Disabled**: DEV, TEST

### Debug Banner
- **Shown**: DEV, TEST, UAT
- **Hidden**: PROD

---

## 📊 Environment Comparison

| Feature | DEV | TEST | UAT | PROD |
|---------|-----|------|-----|------|
| **Project ID** | eazyschool-360-dev | eazyschool-360-test | eazyschool-360-uat | eazy-school-360 |
| **Debug Logging** | ✅ | ✅ | ✅ | ❌ |
| **Analytics** | ❌ | ❌ | ❌ | ✅ |
| **Crash Reporting** | ❌ | ❌ | ✅ | ✅ |
| **Debug Banner** | ✅ | ✅ | ✅ | ❌ |
| **App Name** | EazySchool 360 [DEV] | EazySchool 360 [TEST] | EazySchool 360 [UAT] | EazySchool 360 |

---

## 🛠️ Troubleshooting

### Issue: "Firebase project not found"
**Solution**: Make sure you've created the Firebase project and updated the config file with correct credentials.

### Issue: "Permission denied"
**Solution**: Deploy Firestore rules to the specific environment:
```bash
firebase use <project-id>
firebase deploy --only firestore:rules
```

### Issue: "Cloud Functions not working"
**Solution**: Deploy functions to the specific environment:
```bash
firebase use <project-id>
firebase deploy --only functions
```

### Issue: "Wrong environment loading"
**Solution**: Make sure you're using the correct entry point:
```bash
flutter run -t lib/main_dev.dart  # For DEV
flutter run -t lib/main_prod.dart # For PROD
```

---

## 📝 Best Practices

### 1. Data Isolation
- Keep data completely separate between environments
- Never use production data in dev/test/UAT
- Use test data generators for non-prod environments

### 2. Deployment Workflow
```
DEV → TEST → UAT → PROD
```
- Develop and test in DEV
- Run automated tests in TEST
- User acceptance testing in UAT
- Deploy to PROD only after UAT approval

### 3. Security Rules
- Test rules in DEV first
- Deploy to TEST for automated testing
- Verify in UAT with real users
- Deploy to PROD after verification

### 4. Cloud Functions
- Develop functions in DEV
- Test thoroughly in TEST environment
- Verify performance in UAT
- Deploy to PROD with monitoring

### 5. Version Control
- Commit all environment config files
- Use feature branches for development
- Merge to main only after UAT approval
- Tag releases for production deployments

---

## 🚀 CI/CD Integration

### GitHub Actions Example

```yaml
name: Deploy to Environments

on:
  push:
    branches:
      - develop  # Deploy to DEV
      - test     # Deploy to TEST
      - uat      # Deploy to UAT
      - main     # Deploy to PROD

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      
      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        
      - name: Install dependencies
        run: flutter pub get
        
      - name: Build Web (DEV)
        if: github.ref == 'refs/heads/develop'
        run: flutter build web -t lib/main_dev.dart --release
        
      - name: Build Web (TEST)
        if: github.ref == 'refs/heads/test'
        run: flutter build web -t lib/main_test.dart --release
        
      - name: Build Web (UAT)
        if: github.ref == 'refs/heads/uat'
        run: flutter build web -t lib/main_uat.dart --release
        
      - name: Build Web (PROD)
        if: github.ref == 'refs/heads/main'
        run: flutter build web -t lib/main_prod.dart --release
        
      - name: Deploy to Firebase Hosting
        uses: FirebaseExtended/action-hosting-deploy@v0
        with:
          repoToken: '${{ secrets.GITHUB_TOKEN }}'
          firebaseServiceAccount: '${{ secrets.FIREBASE_SERVICE_ACCOUNT }}'
```

---

## ✅ Checklist

Before deploying to each environment:

### DEV
- [ ] Firebase project created
- [ ] Web app registered
- [ ] Config file updated
- [ ] Firestore rules deployed
- [ ] Cloud Functions deployed
- [ ] Test data seeded

### TEST
- [ ] Firebase project created
- [ ] Web app registered
- [ ] Config file updated
- [ ] Firestore rules deployed
- [ ] Cloud Functions deployed
- [ ] Automated tests passing

### UAT
- [ ] Firebase project created
- [ ] Web app registered
- [ ] Config file updated
- [ ] Firestore rules deployed
- [ ] Cloud Functions deployed
- [ ] User acceptance testing completed

### PROD
- [ ] Firebase project created (already exists)
- [ ] Web app registered
- [ ] Config file updated
- [ ] Firestore rules deployed
- [ ] Cloud Functions deployed
- [ ] Monitoring enabled
- [ ] Backup strategy in place

---

## 📞 Support

For issues or questions:
1. Check this documentation
2. Review Firebase Console logs
3. Check Cloud Functions logs
4. Review Firestore rules

---

## 🎉 Summary

You now have a complete multi-environment setup with:
- ✅ 4 separate Firebase projects
- ✅ Environment-specific configurations
- ✅ Easy switching between environments
- ✅ Production-ready deployment workflow
- ✅ Proper data isolation
- ✅ Environment-specific feature flags

**Happy coding!** 🚀
