# Deployment Checklist - Multi-Environment

## 🎯 Before First Deployment (One-Time Setup)

### For Each Environment (DEV, TEST, UAT, PROD)

- [ ] **Create Firebase Project** in Firebase Console
- [ ] **Upgrade to Blaze Plan** (required for Cloud Functions)
- [ ] **Create Firestore Database**
  - Region: `asia-south1` (Mumbai)
  - Mode: **Native mode** (NOT Datastore)
  - Rules: Start in production mode
- [ ] **Enable Required APIs**
  - Cloud Functions API
  - Cloud Build API
  - Artifact Registry API
  - Cloud Scheduler API
  - Firestore API
  - Cloud Storage API

---

## 🚀 Deployment Steps

### Step 1: Deploy Firestore Rules & Indexes

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

**What gets deployed:**
1. ✅ Firestore Security Rules
2. ✅ Firestore Indexes (may take 5-10 minutes to build)
3. ✅ Cloud Functions (21 functions)
4. ✅ Storage Rules

---

## ✅ Post-Deployment Verification

### 1. Check Firestore Rules

```bash
firebase firestore:rules:list
```

Expected output: Rules version deployed successfully

### 2. Check Firestore Indexes

Visit: `https://console.firebase.google.com/project/PROJECT_ID/firestore/indexes`

**Required indexes for signup:**
- `schools` collection:
  - `schoolNameLower` (ASCENDING)
  - `schoolName` (ASCENDING)
  - `name` (ASCENDING)

Status should be: **Enabled** (green checkmark)

### 3. Check Cloud Functions

```bash
firebase functions:list
```

Expected: 21 functions in `asia-south1` region

### 4. Test Signup Flow

1. Run app: `flutter run -d chrome lib/main_dev.dart`
2. Navigate to signup page
3. Try creating a new school
4. Should NOT see permission errors

---

## 🐛 Troubleshooting

### Error: "Missing or insufficient permissions"

**Cause:** Firestore rules not deployed or indexes not built

**Fix:**
```powershell
# Redeploy rules
firebase deploy --only firestore:rules

# Check index status
# Visit: https://console.firebase.google.com/project/PROJECT_ID/firestore/indexes
```

### Error: "index already exists"

**Cause:** Indexes were manually created in console

**Fix:** This is safe to ignore. The indexes exist and will work.

### Error: "Firestore database does not exist"

**Cause:** Database not created in correct region

**Fix:**
1. Go to Firebase Console → Firestore
2. Create database in `asia-south1` region
3. Select **Native mode**
4. Redeploy

### Error: "invalid-credential"

**Cause:** User trying to sign in before account is activated

**Fix:** This is expected for new signups. Super admin must activate the account.

---

## 📊 Deployment Order (Best Practice)

1. **DEV** - Deploy and test all changes
2. **TEST** - Deploy for QA testing
3. **UAT** - Deploy for client/stakeholder testing
4. **PROD** - Deploy to production (requires confirmation)

---

## 🔐 Security Notes

1. **Always deploy rules BEFORE functions**
   - Rules protect the database
   - Functions depend on rules being in place

2. **Wait for indexes to build**
   - Indexes can take 5-10 minutes
   - App will fail if indexes aren't ready

3. **Test in DEV first**
   - Never deploy untested code to PROD
   - Use DEV for all development work

---

## 📝 Deployment Log Template

```
Date: ___________
Environment: ___________
Deployed By: ___________

Changes:
- [ ] Firestore Rules
- [ ] Firestore Indexes
- [ ] Cloud Functions
- [ ] Storage Rules

Verification:
- [ ] Rules deployed successfully
- [ ] Indexes built and enabled
- [ ] All 21 functions deployed
- [ ] Signup flow tested
- [ ] No permission errors

Notes:
_______________________________
_______________________________
```

---

## 🎯 Quick Commands

```bash
# Check current project
firebase use

# Switch project
firebase use dev    # or test, uat, prod

# View deployed rules
firebase firestore:rules:list

# View deployed functions
firebase functions:list

# View function logs
firebase functions:log

# Check index status (in browser)
https://console.firebase.google.com/project/PROJECT_ID/firestore/indexes
```
