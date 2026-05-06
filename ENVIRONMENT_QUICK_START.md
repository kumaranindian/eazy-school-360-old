# 🚀 Environment Quick Start Guide

## ✅ What's Done

- ✅ Multi-environment structure created
- ✅ DEV environment configured
- ✅ TEST, UAT, PROD placeholders created
- ✅ Environment manager implemented
- ✅ Entry points for all environments created

---

## 📋 Next Steps

### Step 1: Create Firebase Projects

Create 3 new Firebase projects (DEV already configured):

1. **eazyschool-360-test** (Testing)
2. **eazyschool-360-uat** (UAT)
3. Keep **eazy-school-360** (Production - already exists)

### Step 2: Get Firebase Config

For each project:

1. Go to Firebase Console → Project Settings
2. Scroll to "Your apps" section
3. Click "Add app" → Web (</>) icon
4. Register app
5. Copy the `firebaseConfig` object

### Step 3: Update Config Files

Replace placeholders in these files:

- `lib/config/firebase_options_test.dart` - TEST project config
- `lib/config/firebase_options_uat.dart` - UAT project config
- `lib/config/firebase_options_prod.dart` - PROD project config

---

## 🎯 Running the App

### Development (Already Configured)
```bash
flutter run -t lib/main_dev.dart -d chrome
```

### Test (After you configure)
```bash
flutter run -t lib/main_test.dart -d chrome
```

### UAT (After you configure)
```bash
flutter run -t lib/main_uat.dart -d chrome
```

### Production (After you configure)
```bash
flutter run -t lib/main_prod.dart -d chrome
```

---

## 📊 Environment Info

When you run the app, you'll see:

```
═══════════════════════════════════════════════════════
🚀 EAZYSCHOOL 360 - DEV ENVIRONMENT
═══════════════════════════════════════════════════════
📦 Project ID: eazyschool-360-dev
🌐 API Base URL: https://dev-api.eazyschool360.com
📱 App Name: EazySchool 360 [DEV]
🐛 Debug Logging: ENABLED
📊 Analytics: DISABLED
💥 Crash Reporting: DISABLED
═══════════════════════════════════════════════════════
```

---

## 🔧 Deploying Cloud Functions

### To DEV
```bash
firebase use eazyschool-360-dev
firebase deploy --only functions
```

### To TEST
```bash
firebase use eazyschool-360-test
firebase deploy --only functions
```

### To UAT
```bash
firebase use eazyschool-360-uat
firebase deploy --only functions
```

### To PROD
```bash
firebase use eazy-school-360
firebase deploy --only functions
```

---

## 📝 Current Status

| Environment | Status | Project ID |
|-------------|--------|------------|
| **DEV** | ✅ Configured | eazyschool-360-dev |
| **TEST** | ⏳ Pending Setup | eazyschool-360-test |
| **UAT** | ⏳ Pending Setup | eazyschool-360-uat |
| **PROD** | ⏳ Pending Setup | eazy-school-360 |

---

## 📚 Full Documentation

See `docs/FIREBASE_MULTI_ENVIRONMENT_SETUP.md` for complete guide.

---

## ⚡ Quick Tips

1. **Always check which environment you're running**:
   - Look for the environment banner in console output
   - Check the app title (has [DEV], [TEST], [UAT] suffix)

2. **Deploy to environments in order**:
   - DEV → TEST → UAT → PROD

3. **Keep data separate**:
   - Never use production data in dev/test/UAT
   - Each environment has its own Firebase project

4. **Test before deploying**:
   - Test in DEV first
   - Run automated tests in TEST
   - User acceptance in UAT
   - Deploy to PROD only after approval

---

## 🎉 You're Ready!

Once you configure TEST, UAT, and PROD projects, you'll have a complete multi-environment setup ready for production use!
