# 🚀 RFID Attendance System - Deployment Guide

## 📋 Pre-Deployment Checklist

### 1. Firebase Project Setup
- [ ] Firebase project created
- [ ] Blaze plan enabled (required for Cloud Functions)
- [ ] Firestore database created
- [ ] Authentication enabled

### 2. Development Environment
- [ ] Node.js 18+ installed
- [ ] Firebase CLI installed (`npm install -g firebase-tools`)
- [ ] Flutter SDK 3.0+ installed
- [ ] Logged into Firebase CLI (`firebase login`)

---

## 🔧 Step 1: Deploy Cloud Functions

### Install Dependencies
```bash
cd functions
npm install
```

### Update package.json (if needed)
```json
{
  "name": "functions",
  "engines": {
    "node": "18"
  },
  "main": "lib/index.js",
  "dependencies": {
    "firebase-admin": "^12.0.0",
    "firebase-functions": "^5.0.0"
  },
  "devDependencies": {
    "typescript": "^5.0.0",
    "@types/node": "^20.0.0"
  },
  "scripts": {
    "build": "tsc",
    "serve": "npm run build && firebase emulators:start --only functions",
    "shell": "npm run build && firebase functions:shell",
    "deploy": "firebase deploy --only functions",
    "logs": "firebase functions:log"
  }
}
```

### Build TypeScript
```bash
npm run build
```

### Test Locally (Optional)
```bash
firebase emulators:start
```

### Deploy to Firebase
```bash
firebase deploy --only functions
```

**Expected Output:**
```
✔  functions[processRfidSwipe(us-central1)] Successful create operation.
✔  functions[dailyAttendanceFinalizer(us-central1)] Successful create operation.
✔  functions[validateLeaveApplication(us-central1)] Successful create operation.
✔  functions[updateLeaveBalanceOnApproval(us-central1)] Successful create operation.
✔  functions[validatePermissionRequest(us-central1)] Successful create operation.
✔  functions[updatePermissionUsageOnApproval(us-central1)] Successful create operation.
```

---

## 📊 Step 2: Create Firestore Indexes

### Create firestore.indexes.json
```json
{
  "indexes": [
    {
      "collectionGroup": "staffAttendance",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "staffId", "order": "ASCENDING" },
        { "fieldPath": "date", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "staffAttendance",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "date", "order": "ASCENDING" },
        { "fieldPath": "staffName", "order": "ASCENDING" }
      ]
    },
    {
      "collectionGroup": "leaveApplications",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "staffId", "order": "ASCENDING" },
        { "fieldPath": "status", "order": "ASCENDING" },
        { "fieldPath": "createdAt", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "leaveApplications",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "status", "order": "ASCENDING" },
        { "fieldPath": "leaveDates", "arrayConfig": "CONTAINS" }
      ]
    },
    {
      "collectionGroup": "permissionRequests",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "staffId", "order": "ASCENDING" },
        { "fieldPath": "status", "order": "ASCENDING" },
        { "fieldPath": "createdAt", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "permissionRequests",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "status", "order": "ASCENDING" },
        { "fieldPath": "requestDate", "order": "ASCENDING" }
      ]
    },
    {
      "collectionGroup": "rfidCards",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "uuid", "order": "ASCENDING" },
        { "fieldPath": "isActive", "order": "ASCENDING" }
      ]
    },
    {
      "collectionGroup": "rfidCards",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "staffId", "order": "ASCENDING" },
        { "fieldPath": "isActive", "order": "ASCENDING" }
      ]
    }
  ],
  "fieldOverrides": []
}
```

### Deploy Indexes
```bash
firebase deploy --only firestore:indexes
```

---

## 🔒 Step 3: Update Security Rules

### Update firestore.rules
Add these rules to your existing `firestore.rules` file:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Helper function to check user roles
    function hasRole(schoolId, role) {
      return exists(/databases/$(database)/documents/userMemberships/$(request.auth.uid)/schools/$(schoolId)) &&
             get(/databases/$(database)/documents/userMemberships/$(request.auth.uid)/schools/$(schoolId)).data.roles.hasAny([role]);
    }
    
    function isStaff(schoolId) {
      return hasRole(schoolId, 'STAFF') || hasRole(schoolId, 'ADMIN');
    }
    
    function isAdmin(schoolId) {
      return hasRole(schoolId, 'ADMIN') || hasRole(schoolId, 'SUPER_ADMIN');
    }
    
    // Staff Attendance Rules
    match /schools/{schoolId}/staffAttendance/{attendanceId} {
      allow read: if request.auth != null && 
                     (resource.data.staffId == request.auth.uid || isAdmin(schoolId));
      allow write: if isAdmin(schoolId);
    }
    
    // RFID Swipes (system/device only)
    match /schools/{schoolId}/rfidSwipes/{swipeId} {
      allow read: if isAdmin(schoolId);
      allow create: if request.auth != null; // Service account or device
      allow update, delete: if false;
    }
    
    // RFID Cards
    match /schools/{schoolId}/rfidCards/{cardId} {
      allow read: if request.auth != null && 
                     (resource.data.staffId == request.auth.uid || isAdmin(schoolId));
      allow write: if isAdmin(schoolId);
    }
    
    // Attendance Config
    match /schools/{schoolId}/attendanceConfig/{configId} {
      allow read: if isStaff(schoolId);
      allow write: if isAdmin(schoolId);
    }
    
    // Leave Applications
    match /schools/{schoolId}/leaveApplications/{applicationId} {
      // Read: own applications or admin
      allow read: if request.auth != null && 
                     (resource.data.applicantId == request.auth.uid || isAdmin(schoolId));
      
      // Create: staff can create their own pending applications
      allow create: if request.auth != null && 
                       request.resource.data.applicantId == request.auth.uid &&
                       request.resource.data.status == 'PENDING' &&
                       isStaff(schoolId);
      
      // Update: admin can approve/reject, staff can cancel their own pending
      allow update: if isAdmin(schoolId) ||
                       (request.auth != null && 
                        resource.data.applicantId == request.auth.uid &&
                        resource.data.status == 'PENDING' &&
                        request.resource.data.status == 'CANCELLED');
      
      allow delete: if false; // No deletions
    }
    
    // Permission Requests
    match /schools/{schoolId}/permissionRequests/{requestId} {
      allow read: if request.auth != null && 
                     (resource.data.applicantId == request.auth.uid || isAdmin(schoolId));
      
      allow create: if request.auth != null && 
                       request.resource.data.applicantId == request.auth.uid &&
                       request.resource.data.status == 'PENDING' &&
                       isStaff(schoolId);
      
      allow update: if isAdmin(schoolId) ||
                       (request.auth != null && 
                        resource.data.applicantId == request.auth.uid &&
                        resource.data.status == 'PENDING' &&
                        request.resource.data.status == 'CANCELLED');
      
      allow delete: if false;
    }
    
    // Monthly Permission Usage
    match /schools/{schoolId}/monthlyPermissionUsage/{usageId} {
      allow read: if request.auth != null && 
                     (resource.data.userId == request.auth.uid || isAdmin(schoolId));
      allow write: if false; // Only Cloud Functions can write
    }
    
    // Leave Balances
    match /schools/{schoolId}/leaveBalances/{balanceId} {
      allow read: if request.auth != null && 
                     (balanceId.split('_')[0] == request.auth.uid || isAdmin(schoolId));
      allow write: if isAdmin(schoolId); // Admin or Cloud Functions
    }
    
    // Holidays
    match /schools/{schoolId}/holidays/{holidayId} {
      allow read: if isStaff(schoolId);
      allow write: if isAdmin(schoolId);
    }
  }
}
```

### Deploy Security Rules
```bash
firebase deploy --only firestore:rules
```

---

## 🎯 Step 4: Initialize School Data

### Create Default Attendance Config
Run this once for each school:

```javascript
// In Firebase Console > Firestore
// Or via Flutter admin panel

schools/{schoolId}/attendanceConfig/default
{
  "schoolId": "YOUR_SCHOOL_ID",
  "lateThresholdTime": "09:30",
  "lateGraceMinutes": 5,
  "workingDays": ["MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY"],
  "autoMarkAbsent": true,
  "requireBothSwipes": true,
  "createdAt": Timestamp.now(),
  "updatedAt": Timestamp.now(),
  "createdBy": "ADMIN_USER_ID"
}
```

### Create Default Permission Config
```javascript
schools/{schoolId}/permissionConfig/default
{
  "schoolId": "YOUR_SCHOOL_ID",
  "monthlyLimit": 3,
  "maxDurationMinutes": 240,
  "requiresApproval": true,
  "isActive": true,
  "createdAt": Timestamp.now(),
  "updatedAt": Timestamp.now(),
  "createdBy": "ADMIN_USER_ID"
}
```

---

## 📱 Step 5: ESP32 Setup

### Hardware Requirements
- ESP32 Development Board
- MFRC522 RFID Reader Module
- RFID Cards/Tags
- Power Supply (5V)

### Wiring Diagram
```
MFRC522 → ESP32
SDA     → GPIO 5
SCK     → GPIO 18
MOSI    → GPIO 23
MISO    → GPIO 19
IRQ     → Not connected
GND     → GND
RST     → GPIO 22
3.3V    → 3.3V
```

### Install Arduino Libraries
1. Open Arduino IDE
2. Install libraries:
   - MFRC522 by GithubCommunity
   - WiFi (built-in)
   - HTTPClient (built-in)

### Upload ESP32 Code
See `RFID_ATTENDANCE_SYSTEM_IMPLEMENTATION.md` for complete ESP32 code.

### Configure Device
```cpp
// Update these values
const char* ssid = "YOUR_WIFI_SSID";
const char* password = "YOUR_WIFI_PASSWORD";
const char* serverUrl = "https://YOUR_REGION-YOUR_PROJECT.cloudfunctions.net/processRfidSwipe";
const char* schoolId = "YOUR_SCHOOL_ID";
```

---

## 🧪 Step 6: Testing

### Test RFID Swipe Processing
1. Register an RFID card in Firestore:
```javascript
schools/{schoolId}/rfidCards/{cardId}
{
  "uuid": "A1B2C3D4",
  "staffId": "staff123",
  "staffName": "John Doe",
  "cardType": "primary",
  "isActive": true,
  "assignedAt": Timestamp.now()
}
```

2. Swipe the card on ESP32
3. Check Firestore:
   - `schools/{schoolId}/rfidSwipes/{swipeId}` should be created
   - `schools/{schoolId}/staffAttendance/{staffId}_{date}` should be created/updated

### Test Leave Application
1. Create leave application via Flutter app
2. Check Cloud Function logs: `firebase functions:log`
3. Verify validation ran
4. Admin approves leave
5. Check leave balance deducted

### Test Daily Finalizer
```bash
# Manually trigger (for testing)
firebase functions:shell

> dailyAttendanceFinalizer()
```

Check that absent staff are marked correctly.

---

## 📊 Step 7: Monitoring

### Enable Cloud Function Logs
```bash
# View real-time logs
firebase functions:log --only processRfidSwipe

# View all function logs
firebase functions:log
```

### Set Up Alerts
1. Go to Firebase Console > Functions
2. Click on each function
3. Set up alerts for:
   - Error rate > 5%
   - Execution time > 10s
   - Memory usage > 80%

### Monitor Firestore Usage
1. Firebase Console > Firestore > Usage
2. Monitor:
   - Document reads/writes
   - Storage size
   - Index usage

---

## 🔄 Step 8: Maintenance

### Daily Tasks
- [ ] Check Cloud Function logs for errors
- [ ] Verify daily finalizer ran successfully
- [ ] Monitor RFID swipe success rate

### Weekly Tasks
- [ ] Review pending leave/permission requests
- [ ] Check attendance statistics
- [ ] Verify leave balance accuracy

### Monthly Tasks
- [ ] Review and optimize Firestore indexes
- [ ] Analyze Cloud Function costs
- [ ] Update ESP32 firmware if needed
- [ ] Backup Firestore data

---

## 🆘 Troubleshooting

### RFID Swipes Not Creating Attendance
**Symptoms:** Swipes logged but no attendance record

**Solutions:**
1. Check RFID card is registered and active
2. Verify `processRfidSwipe` function deployed
3. Check function logs for errors
4. Ensure card UUID matches exactly

### Leave Applications Auto-Rejected
**Symptoms:** All leave requests rejected immediately

**Solutions:**
1. Check leave balance exists for staff
2. Verify leave type config has correct quotas
3. Check for overlapping leave dates
4. Review `validateLeaveApplication` logs

### Daily Finalizer Not Running
**Symptoms:** Absent staff not marked

**Solutions:**
1. Check scheduled function is deployed
2. Verify timezone setting (Asia/Kolkata)
3. Check function logs at 11 PM
4. Ensure working days configured correctly

### Late Marking Not Working
**Symptoms:** Staff marked present but not late

**Solutions:**
1. Check attendance config `lateThresholdTime`
2. Verify `lateGraceMinutes` setting
3. Check login time vs threshold
4. Review attendance record in Firestore

---

## 💰 Cost Estimation

### Firebase Blaze Plan (Pay-as-you-go)

**Cloud Functions:**
- processRfidSwipe: ~500 invocations/day = $0.00
- dailyAttendanceFinalizer: 1 invocation/day = $0.00
- Leave validators: ~50 invocations/day = $0.00
- **Monthly: ~$0-5**

**Firestore:**
- Reads: ~50,000/month = $0.18
- Writes: ~20,000/month = $0.18
- Storage: ~1 GB = $0.18
- **Monthly: ~$0.54**

**Total Estimated Cost: $5-10/month** (for 100 staff, 1 school)

---

## ✅ Post-Deployment Checklist

- [ ] All Cloud Functions deployed successfully
- [ ] Firestore indexes created
- [ ] Security rules updated
- [ ] ESP32 devices configured and tested
- [ ] Default configs created for schools
- [ ] RFID cards registered
- [ ] Test leave application flow
- [ ] Test permission request flow
- [ ] Daily finalizer tested
- [ ] Monitoring and alerts set up
- [ ] Documentation shared with admins
- [ ] Training provided to staff

---

## 🎉 Deployment Complete!

Your RFID Attendance & Leave Management System is now live!

**Next Steps:**
1. Train school admins on approval workflows
2. Register all staff RFID cards
3. Configure leave types and quotas
4. Set up holidays calendar
5. Monitor system for first week

**Support:**
- Check logs: `firebase functions:log`
- View metrics: Firebase Console > Functions
- Documentation: `RFID_ATTENDANCE_SYSTEM_IMPLEMENTATION.md`
