# Deploy Firestore Indexes to All Environments

## ✅ What Was Done

### 1. Fixed Index File Location
- **Issue:** Indexes were added to wrong file (`firestore.indexes.json` at root)
- **Solution:** Added indexes to correct file (`firebase/firestore.indexes.json`)
- **Config:** `firebase.json` points to `firebase/firestore.indexes.json`

### 2. Added RFID Indexes

All RFID-related indexes have been added to `firebase/firestore.indexes.json`:

#### RFID Cards Collection
```json
{
  "collectionGroup": "rfid_cards",
  "fields": [
    { "fieldPath": "schoolId", "order": "ASCENDING" },
    { "fieldPath": "isActive", "order": "ASCENDING" },
    { "fieldPath": "registeredAt", "order": "DESCENDING" }
  ]
}

{
  "collectionGroup": "rfid_cards",
  "fields": [
    { "fieldPath": "schoolId", "order": "ASCENDING" },
    { "fieldPath": "isAssigned", "order": "ASCENDING" }
  ]
}

{
  "collectionGroup": "rfid_cards",
  "fields": [
    { "fieldPath": "schoolId", "order": "ASCENDING" },
    { "fieldPath": "staffId", "order": "ASCENDING" }
  ]
}

{
  "collectionGroup": "rfid_cards",
  "fields": [
    { "fieldPath": "schoolId", "order": "ASCENDING" },
    { "fieldPath": "studentId", "order": "ASCENDING" }
  ]
}
```

#### Devices Collection
```json
{
  "collectionGroup": "devices",
  "fields": [
    { "fieldPath": "schoolId", "order": "ASCENDING" },
    { "fieldPath": "isActive", "order": "ASCENDING" }
  ]
}

{
  "collectionGroup": "devices",
  "fields": [
    { "fieldPath": "schoolId", "order": "ASCENDING" },
    { "fieldPath": "deviceKey", "order": "ASCENDING" }
  ]
}
```

#### Attendance Collection
```json
{
  "collectionGroup": "attendance",
  "fields": [
    { "fieldPath": "schoolId", "order": "ASCENDING" },
    { "fieldPath": "rfidTag", "order": "ASCENDING" },
    { "fieldPath": "scannedAt", "order": "DESCENDING" }
  ]
}

{
  "collectionGroup": "attendance",
  "fields": [
    { "fieldPath": "schoolId", "order": "ASCENDING" },
    { "fieldPath": "staffId", "order": "ASCENDING" },
    { "fieldPath": "scannedAt", "order": "DESCENDING" }
  ]
}

{
  "collectionGroup": "attendance",
  "fields": [
    { "fieldPath": "schoolId", "order": "ASCENDING" },
    { "fieldPath": "studentId", "order": "ASCENDING" },
    { "fieldPath": "scannedAt", "order": "DESCENDING" }
  ]
}

{
  "collectionGroup": "attendance",
  "fields": [
    { "fieldPath": "rfidTag", "order": "ASCENDING" },
    { "fieldPath": "scannedAt", "order": "DESCENDING" }
  ]
}
```

### 3. Fixed studentFeeItems Index
```json
{
  "collectionGroup": "studentFeeItems",
  "fields": [
    { "fieldPath": "isActive", "order": "ASCENDING" },
    { "fieldPath": "updatedAt", "order": "DESCENDING" },
    { "fieldPath": "__name__", "order": "ASCENDING" }
  ]
}
```
**Note:** Removed `paidAmount` field that was causing the error.

## 📋 Deployment Status

### ✅ DEV Environment
- **Project:** `eazyschool-360-dev`
- **Status:** DEPLOYED
- **Command:** `firebase deploy --only firestore:indexes --project eazyschool-360-dev`

### ⏳ TEST Environment
- **Project:** `eazyschool-360-test`
- **Status:** PENDING
- **Command:** `firebase deploy --only firestore:indexes --project eazyschool-360-test`

### ⏳ UAT Environment
- **Project:** `eazyschool-360-uat`
- **Status:** PENDING
- **Command:** `firebase deploy --only firestore:indexes --project eazyschool-360-uat`

### ⏳ PROD Environment
- **Project:** `eazy-school-360`
- **Status:** PENDING
- **Command:** `firebase deploy --only firestore:indexes --project eazy-school-360`

## 🚀 How to Deploy to Remaining Environments

### Option 1: Manual Deployment (Recommended)

Run these commands one by one:

```bash
# Deploy to TEST
firebase deploy --only firestore:indexes --project eazyschool-360-test

# Deploy to UAT
firebase deploy --only firestore:indexes --project eazyschool-360-uat

# Deploy to PROD
firebase deploy --only firestore:indexes --project eazy-school-360
```

### Option 2: Using Batch Script (Windows)

Run the provided script:
```bash
.\scripts\deploy-indexes.bat
```

### Option 3: Using PowerShell Script

Run the provided script:
```powershell
.\scripts\deploy-indexes-all-env.ps1
```

## ⚠️ Important Notes

### 1. Indexes Cannot Be Created Programmatically
Firestore indexes **MUST** be created through:
- ✅ Firebase Console (manual)
- ✅ Firebase CLI deployment (what we're doing)
- ✅ Following auto-generated error link

**You CANNOT create indexes at runtime via code.**

### 2. Index Building Takes Time
After deployment:
- Indexes show as "Building" in Firebase Console
- Small collections: few seconds
- Large collections: several minutes to hours
- You can use the app while indexes build
- Queries will fail until indexes are ready

### 3. Check Index Status
View index status in Firebase Console:
```
https://console.firebase.google.com/project/{project-id}/firestore/indexes
```

Or via CLI:
```bash
firebase firestore:indexes --project {project-id}
```

## 🔍 Verification

After deployment, verify indexes are building:

1. **Firebase Console:**
   - Go to Firestore → Indexes
   - Check for "Building" or "Enabled" status

2. **CLI:**
   ```bash
   firebase firestore:indexes --project eazyschool-360-dev
   ```

3. **Test the App:**
   - Try accessing RFID Management screen
   - Try accessing Finance dashboard
   - Errors should be gone once indexes are ready

## 📁 Files Modified

1. `firebase/firestore.indexes.json` - Added RFID and fixed studentFeeItems indexes
2. `scripts/deploy-indexes.bat` - Batch script for deployment
3. `scripts/deploy-indexes-all-env.ps1` - PowerShell script for deployment

## 🎯 Next Steps

1. ✅ DEV indexes deployed
2. ⏳ Deploy to TEST environment
3. ⏳ Deploy to UAT environment
4. ⏳ Deploy to PROD environment
5. ⏳ Wait for indexes to build (check console)
6. ⏳ Test RFID functionality
7. ⏳ Test Finance dashboard

## 🐛 Troubleshooting

### Error: "Index already exists"
- This is normal if you've deployed before
- Firebase will skip duplicate indexes

### Error: "Invalid project"
- Check project ID in `.firebaserc`
- Ensure you have access to the project
- Try: `firebase login` and re-authenticate

### Indexes Not Showing
- Wait a few minutes for deployment to propagate
- Check Firebase Console directly
- Verify you're looking at the correct project

### Query Still Failing
- Indexes may still be building
- Check index status in console
- Large collections take longer to index

## 📚 Reference

- [Firebase Indexes Documentation](https://firebase.google.com/docs/firestore/query-data/indexing)
- [Index Configuration](https://firebase.google.com/docs/firestore/reference/rest/v1beta1/projects.databases.indexes)
- [Deploy Indexes](https://firebase.google.com/docs/firestore/query-data/index-overview#use_the_firebase_cli)
