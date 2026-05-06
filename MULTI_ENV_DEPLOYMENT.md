# Multi-Environment Deployment Guide

Complete guide for deploying to all 4 Firebase environments.

## 🌍 Available Environments

| Environment | Project ID | Console | Region |
|---|---|---|---|
| 🔵 **DEV** | `eazyschool-360-dev` | [Console](https://console.firebase.google.com/project/eazyschool-360-dev) | asia-south1 |
| 🟡 **TEST** | `eazyschool-360-test` | [Console](https://console.firebase.google.com/project/eazyschool-360-test) | asia-south1 |
| 🟠 **UAT** | `eazyschool-360-uat` | [Console](https://console.firebase.google.com/project/eazyschool-360-uat) | asia-south1 |
| 🔴 **PROD** | `eazy-school-360` | [Console](https://console.firebase.google.com/project/eazy-school-360) | asia-south1 |

---

## 🚀 Quick Deployment

### Using PowerShell Scripts (Recommended)

```powershell
# Deploy to DEV
.\scripts\deploy-dev.ps1

# Deploy to TEST
.\scripts\deploy-test.ps1

# Deploy to UAT
.\scripts\deploy-uat.ps1

# Deploy to PROD (requires confirmation)
.\scripts\deploy-prod.ps1
```

### Manual Deployment

```bash
# 1. Switch to desired environment
firebase use dev    # or test, uat, prod

# 2. Build TypeScript functions
cd functions
npm run build
cd ..

# 3. Deploy
firebase deploy --only functions,firestore:rules,firestore:indexes,storage
```

---

## 📦 What Gets Deployed

Each deployment includes:
- ✅ **Cloud Functions** (21 functions in asia-south1)
- ✅ **Firestore Security Rules**
- ✅ **Firestore Indexes**
- ✅ **Storage Rules**

### Cloud Functions List

**Leave Management:**
- `handleLeaveApplicationCreate`
- `onLeaveStatusChange`
- `validateLeaveApplication`
- `updateLeaveBalanceOnApproval`

**Permission Management:**
- `handlePermissionRequestCreate`
- `onPermissionStatusChange`
- `validatePermissionRequest`
- `updatePermissionUsageOnApproval`

**RFID Attendance:**
- `processRfidSwipe`
- `dailyAttendanceFinalizer`
- `onAttendanceCreate`
- `rfidApi` (HTTP endpoint)

**Auth Management:**
- `handleUserCreate`
- `handlePasswordReset`
- `activateUser`
- `setCustomClaims`
- `setUserClaims`
- `onUserDocumentWrite`

**Data Triggers:**
- `onTeacherCreate`
- `onLeaveTypeCreate`
- `onPermissionTypeCreate`

---

## 🔄 Deployment Workflow

### 1. Development Cycle

```bash
# Work on features
git checkout -b feature/new-feature

# Test locally with DEV
flutter run -d chrome lib/main_dev.dart

# Deploy to DEV for testing
.\scripts\deploy-dev.ps1

# Commit changes
git add .
git commit -m "feat: new feature"
git push origin feature/new-feature
```

### 2. Testing Phase

```bash
# Merge to test branch
git checkout test
git merge feature/new-feature

# Deploy to TEST
.\scripts\deploy-test.ps1

# QA team tests on TEST environment
```

### 3. UAT Phase

```bash
# Merge to uat branch
git checkout uat
git merge test

# Deploy to UAT
.\scripts\deploy-uat.ps1

# Client/stakeholders test on UAT
```

### 4. Production Release

```bash
# Merge to main
git checkout main
git merge uat

# Deploy to PROD (requires confirmation)
.\scripts\deploy-prod.ps1
# Type: DEPLOY-PROD
```

---

## 🔐 Pre-Deployment Checklist

### For DEV/TEST
- [ ] Code compiles without errors
- [ ] Local tests pass
- [ ] Firebase project exists and is on Blaze plan

### For UAT
- [ ] All features tested in TEST
- [ ] No critical bugs
- [ ] Stakeholders notified

### For PROD
- [ ] All features tested in UAT
- [ ] Client approval received
- [ ] Backup current PROD data
- [ ] Schedule deployment during low-traffic hours
- [ ] Team on standby for rollback if needed

---

## 🔍 Verify Deployment

After deployment, verify:

```bash
# Check deployed functions
firebase functions:list

# Check Firestore rules version
firebase firestore:rules:list

# Test a function
curl https://asia-south1-PROJECT_ID.cloudfunctions.net/rfidApi
```

### In Firebase Console

1. **Functions** → Verify all 21 functions are deployed
2. **Firestore** → Check rules version is `1.0.0`
3. **Firestore** → Verify indexes exist
4. **Storage** → Check rules are deployed

---

## 🐛 Troubleshooting

### Wrong project deployed to

```bash
# Check current project
firebase use

# Switch to correct project
firebase use dev  # or test, uat, prod
```

### Functions not updating

```bash
# Force rebuild
cd functions
rm -rf lib/
npm run build
cd ..

# Redeploy
firebase deploy --only functions --force
```

### Firestore database not found

Each environment needs its own Firestore database:
1. Go to Firebase Console → Firestore
2. Create database in **asia-south1** region
3. Start in **production mode**

### Region mismatch

All functions are configured for `asia-south1`. If you see region errors:
- Check `functions/src/*.js` files have `.region('asia-south1')`
- Check `functions/src/*.ts` files have `.region('asia-south1')`

---

## 📊 Deployment History

Track deployments in a log:

```bash
# View deployment history
firebase deploy:history

# View function logs
firebase functions:log --only functionName
```

---

## 🔒 Security Notes

1. **Never deploy PROD accidentally** - The script requires confirmation
2. **Keep API keys secure** - Don't commit sensitive keys to git
3. **Use environment variables** - For sensitive configuration
4. **Review security rules** - Before each PROD deployment
5. **Monitor costs** - Check Firebase usage after deployment

---

## 📱 Flutter App Deployment

After deploying Firebase backend, deploy the Flutter app:

### Web Deployment

```bash
# Build for DEV
flutter build web --dart-define-from-file=.env.dev lib/main_dev.dart

# Build for PROD
flutter build web --dart-define-from-file=.env.prod lib/main_prod.dart

# Deploy to Firebase Hosting
firebase deploy --only hosting
```

### Mobile Deployment

```bash
# Android
flutter build apk --release lib/main_prod.dart

# iOS
flutter build ios --release lib/main_prod.dart
```

---

## 🎯 Best Practices

1. **Always test in DEV first**
2. **Use feature branches** for development
3. **Deploy to TEST** before UAT
4. **Get approval** before PROD deployment
5. **Monitor logs** after deployment
6. **Have rollback plan** ready
7. **Document changes** in changelog
8. **Notify team** of PROD deployments

---

## 📞 Support

If deployment fails:
1. Check Firebase Console for errors
2. Review function logs: `firebase functions:log`
3. Verify project is on Blaze plan
4. Check all APIs are enabled
5. Ensure Firestore database exists in correct region

---

## 🔄 Rollback Procedure

If PROD deployment fails:

```bash
# 1. Switch to PROD
firebase use prod

# 2. Rollback functions
firebase functions:delete FUNCTION_NAME --force

# 3. Redeploy previous version
git checkout PREVIOUS_TAG
firebase deploy --only functions

# 4. Notify team
```

---

## 📈 Monitoring

After deployment, monitor:
- **Firebase Console** → Functions → Metrics
- **Cloud Logging** → View function logs
- **Error Reporting** → Check for new errors
- **Performance Monitoring** → Track app performance
