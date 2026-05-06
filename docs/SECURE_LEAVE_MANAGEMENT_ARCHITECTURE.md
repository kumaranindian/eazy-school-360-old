# 🔒 Secure Leave Management Architecture

## Overview

This document explains the **production-ready, secure leave management system** using a hybrid architecture where:

- **Client (Flutter)**: Creates leave applications only
- **Backend (Cloud Functions)**: Handles ALL balance updates and audit trails
- **Security Rules**: Prevents client-side tampering

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         FLUTTER CLIENT                          │
│                                                                 │
│  Staff User Actions:                                           │
│  ✅ Create leave application (leaves collection)               │
│  ✅ Read own balances                                          │
│  ❌ CANNOT update leaveBalances                                │
│  ❌ CANNOT create balanceMutations                             │
└──────────────────────┬──────────────────────────────────────────┘
                       │
                       │ onCreate trigger
                       ▼
┌─────────────────────────────────────────────────────────────────┐
│                    CLOUD FUNCTION (Backend)                     │
│                                                                 │
│  handleLeaveApplicationCreate:                                 │
│  1. Validates sufficient balance                              │
│  2. Reserves balance (atomic transaction)                     │
│  3. Creates audit mutation record                             │
│  4. All operations are server-side (secure)                   │
└─────────────────────────────────────────────────────────────────┘
```

---

## 📂 Firestore Collections

### `schools/{schoolId}/leaves/{leaveId}`
**Purpose**: Leave applications submitted by staff

**Fields**:
```javascript
{
  schoolId: string,
  staffId: string,
  userId: string,
  leaveTypeId: string,
  totalDays: number,
  academicYear: string,
  status: "PENDING" | "APPROVED" | "REJECTED",
  startDate: timestamp,
  endDate: timestamp,
  reason: string,
  createdAt: timestamp
}
```

**Security Rules**:
- ✅ Staff can CREATE (with validation)
- ✅ Staff can READ their own
- ✅ Admins can READ all
- ⚠️ Only admins can UPDATE status

---

### `schools/{schoolId}/leaveBalances/{balanceId}`
**Purpose**: Track available, pending, and used leave days

**Document ID Format**: `{staffId}_{leaveTypeId}_{academicYear}`

**Fields**:
```javascript
{
  schoolId: string,
  staffId: string,
  userId: string,
  leaveTypeId: string,
  academicYear: string,
  quota: number,        // Total allocated
  available: number,    // Can still apply
  pending: number,      // Reserved (applications pending approval)
  used: number,         // Approved and consumed
  updatedAt: timestamp,
  updatedBy: string
}
```

**Security Rules**:
- ✅ Staff can READ their own balances
- ❌ Staff CANNOT WRITE (backend only)
- 🔒 **ONLY Cloud Functions can update**

---

### `schools/{schoolId}/balanceMutations/{mutationId}`
**Purpose**: Immutable audit trail of all balance changes

**Fields**:
```javascript
{
  schoolId: string,
  staffId: string,
  userId: string,
  leaveTypeId: string,
  academicYear: string,
  mutationType: "PENDING_ADDED" | "APPROVED" | "REJECTED" | "CANCELLED",
  previousValue: number,
  newValue: number,
  delta: number,
  referenceId: string,  // leaveId
  reason: string,
  createdAt: timestamp,
  createdBy: string,    // "system_leave_create_function"
  metadata: object
}
```

**Security Rules**:
- ✅ Admins can READ
- ❌ Staff CANNOT READ (sensitive audit data)
- ❌ NO ONE can UPDATE or DELETE (immutable)
- 🔒 **ONLY Cloud Functions can create**

---

## 🔐 Security Rules

### Leave Applications
```javascript
match /schools/{schoolId}/leaves/{leaveId} {
  // Staff can create leave applications
  allow create: if isSignedIn() && belongsToSchool(schoolId);
  
  // Staff can read their own, admins can read all
  allow read: if isSignedIn() && (
    isSuperAdmin() || 
    (isStaff() && belongsToSchool(schoolId))
  );
  
  // Only admins can update (approve/reject)
  allow update: if isSignedIn() && isActive() && (
    isSuperAdmin() || 
    (isTenantAdmin() && belongsToSchool(schoolId))
  );
}
```

### Leave Balances (Backend Only)
```javascript
match /leaveBalances/{balanceId} {
  // Staff can read their own balances
  allow read: if isSignedIn() && (
    isSuperAdmin() || 
    belongsToSchool(schoolId)
  );
  
  // ONLY backend can write - prevents tampering
  allow write: if false;
}
```

### Balance Mutations (Backend Only)
```javascript
match /balanceMutations/{mutationId} {
  // Only admins can read audit trail
  allow read: if isSignedIn() && isActive() && (
    isSuperAdmin() || 
    (isTenantAdmin() && belongsToSchool(schoolId))
  );
  
  // ONLY backend can create - immutable audit trail
  allow create: if false;
  allow update: if false;
  allow delete: if false;
}
```

---

## ⚙️ Cloud Function

### `handleLeaveApplicationCreate`

**Trigger**: `onCreate` of `schools/{schoolId}/leaves/{leaveId}`

**Flow**:

1. **Extract Data** from leave application
   - staffId, userId, leaveTypeId, totalDays, academicYear

2. **Validate**
   - Required fields present
   - Status is PENDING
   - Balance document exists
   - Sufficient available days
   - Staff belongs to school

3. **Atomic Transaction**
   - Update `leaveBalances`:
     - `pending += totalDays`
     - `available -= totalDays`
   - Create `balanceMutations` record

4. **Error Handling**
   - Insufficient balance → `failed-precondition`
   - Invalid staff → `permission-denied`
   - Missing data → `invalid-argument`

**Key Features**:
- ✅ Atomic transaction (all-or-nothing)
- ✅ Race condition prevention
- ✅ Complete audit trail
- ✅ Structured error messages
- ✅ Comprehensive logging

---

## 📱 Flutter Client Implementation

### Example: Create Leave Application

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

class LeaveApplicationRepository {
  final FirebaseFirestore _firestore;
  
  LeaveApplicationRepository(this._firestore);
  
  /// Submit leave application (client-side)
  /// Backend will handle balance updates via Cloud Function
  Future<String> createLeaveApplication({
    required String schoolId,
    required String staffId,
    required String userId,
    required String leaveTypeId,
    required int totalDays,
    required String academicYear,
    required DateTime startDate,
    required DateTime endDate,
    required String reason,
  }) async {
    try {
      // 1. Generate leave ID using auto-generated ID
      final leaveRef = _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('leaves')
          .doc();
      
      final leaveId = 'LV_${leaveRef.id}';
      
      // 2. Create leave application document
      // Backend Cloud Function will handle balance updates
      await leaveRef.set({
        'id': leaveRef.id,
        'leaveCode': leaveId,
        'schoolId': schoolId,
        'staffId': staffId,
        'userId': userId,
        'leaveTypeId': leaveTypeId,
        'totalDays': totalDays,
        'academicYear': academicYear,
        'startDate': Timestamp.fromDate(startDate),
        'endDate': Timestamp.fromDate(endDate),
        'reason': reason,
        'status': 'PENDING', // Important: triggers Cloud Function
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      print('✅ Leave application created: $leaveId');
      print('⏳ Waiting for backend to reserve balance...');
      
      return leaveRef.id;
      
    } catch (e) {
      print('❌ Failed to create leave application: $e');
      
      // Parse Cloud Function errors
      if (e.toString().contains('INSUFFICIENT_LEAVE_BALANCE')) {
        throw Exception('Insufficient leave balance');
      } else if (e.toString().contains('UNAUTHORIZED')) {
        throw Exception('You are not authorized to apply for this leave type');
      }
      
      rethrow;
    }
  }
  
  /// Read leave balances (read-only)
  Stream<LeaveBalance?> getLeaveBalance({
    required String schoolId,
    required String staffId,
    required String leaveTypeId,
    required String academicYear,
  }) {
    final balanceId = '${staffId}_${leaveTypeId}_$academicYear';
    
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('leaveBalances')
        .doc(balanceId)
        .snapshots()
        .map((doc) {
          if (!doc.exists) return null;
          return LeaveBalance.fromFirestore(doc);
        });
  }
}
```

### Example: Display Leave Balance (Read-Only)

```dart
class LeaveBalanceWidget extends StatelessWidget {
  final String schoolId;
  final String staffId;
  final String leaveTypeId;
  final String academicYear;
  
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<LeaveBalance?>(
      stream: ref.watch(leaveApplicationRepositoryProvider).getLeaveBalance(
        schoolId: schoolId,
        staffId: staffId,
        leaveTypeId: leaveTypeId,
        academicYear: academicYear,
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return CircularProgressIndicator();
        }
        
        final balance = snapshot.data!;
        
        return Card(
          child: Column(
            children: [
              Text('Available: ${balance.available} days'),
              Text('Pending: ${balance.pending} days'),
              Text('Used: ${balance.used} days'),
              Text('Quota: ${balance.quota} days'),
            ],
          ),
        );
      },
    );
  }
}
```

---

## 🔄 Complete Flow

### 1. Staff Applies for Leave

```
Flutter App → Firestore
  └─ Create document in schools/{schoolId}/leaves/{leaveId}
     └─ status: "PENDING"
     └─ totalDays: 3
```

### 2. Cloud Function Triggered

```
Cloud Function: handleLeaveApplicationCreate
  ├─ Validates: sufficient balance?
  ├─ Transaction START
  │  ├─ Update leaveBalances:
  │  │  ├─ available: 12 → 9
  │  │  └─ pending: 0 → 3
  │  └─ Create balanceMutations:
  │     ├─ mutationType: "PENDING_ADDED"
  │     ├─ delta: 3
  │     └─ referenceId: leaveId
  └─ Transaction COMMIT
```

### 3. Staff Sees Updated Balance

```
Flutter App ← Firestore (real-time)
  └─ leaveBalances/{balanceId}
     ├─ available: 9 days
     └─ pending: 3 days
```

### 4. Admin Approves Leave

```
Admin App → Firestore
  └─ Update schools/{schoolId}/leaves/{leaveId}
     └─ status: "APPROVED"
```

### 5. Another Cloud Function Triggered

```
Cloud Function: onLeaveStatusChange
  ├─ Transaction START
  │  ├─ Update leaveBalances:
  │  │  ├─ pending: 3 → 0
  │  │  └─ used: 0 → 3
  │  └─ Create balanceMutations:
  │     ├─ mutationType: "APPROVED"
  │     └─ delta: 3
  └─ Transaction COMMIT
```

---

## ✅ Benefits of This Architecture

### Security
- 🔒 **No client-side tampering** - balances can't be manipulated
- 🔒 **Backend validation** - all business logic server-side
- 🔒 **Immutable audit trail** - complete history of changes

### Reliability
- ⚡ **Atomic transactions** - no partial updates
- ⚡ **Race condition prevention** - concurrent applications handled
- ⚡ **Error handling** - clear error messages

### Maintainability
- 📝 **Single source of truth** - business logic in one place
- 📝 **Easy to test** - Cloud Functions can be unit tested
- 📝 **Clear separation** - client creates, backend processes

### Scalability
- 🚀 **Auto-scaling** - Cloud Functions scale automatically
- 🚀 **No client load** - heavy processing on backend
- 🚀 **Efficient** - only necessary data sent to client

---

## 🧪 Testing

### Test Cloud Function Locally

```bash
# Install Firebase emulator
npm install -g firebase-tools

# Start emulators
firebase emulators:start

# Test function
curl -X POST http://localhost:5001/eazy-school-360/us-central1/handleLeaveApplicationCreate
```

### Test Security Rules

```bash
# Run rules tests
firebase emulators:exec --only firestore "npm test"
```

---

## 📊 Monitoring

### Cloud Function Logs

```bash
# View logs
firebase functions:log

# Filter by function
firebase functions:log --only handleLeaveApplicationCreate
```

### Firestore Metrics

- Monitor in Firebase Console
- Track read/write operations
- Monitor function execution time
- Track error rates

---

## 🚀 Deployment

### Deploy Cloud Functions

```bash
# Deploy all functions
firebase deploy --only functions

# Deploy specific function
firebase deploy --only functions:handleLeaveApplicationCreate
```

### Deploy Security Rules

```bash
# Deploy rules
firebase deploy --only firestore:rules

# Or use custom script
node firebase/deploy-rules.js
```

---

## 📝 Summary

This architecture provides:

1. **Security**: Client can't tamper with balances
2. **Reliability**: Atomic transactions prevent data corruption
3. **Auditability**: Complete trail of all changes
4. **Scalability**: Backend handles heavy processing
5. **Maintainability**: Clear separation of concerns

**Key Principle**: **Client creates, backend processes** - this is the production-ready pattern for financial/critical data.
