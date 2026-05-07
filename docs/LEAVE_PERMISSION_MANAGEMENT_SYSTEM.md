# Leave and Permission Management System

## Overview
Comprehensive leave and permission management system with balance tracking, approval workflows, and automatic deductions.

## Features
- ✅ Leave application and approval workflow
- ✅ Permission request and approval workflow
- ✅ Automatic balance deduction on approval
- ✅ Balance adjustment by admins
- ✅ Overlap detection for leaves
- ✅ Secure balance management (backend-only writes)

---

## Cloud Functions

### Leave Management

#### 1. **applyLeave**
Staff can apply for leave based on available balance.

**Parameters:**
```javascript
{
  schoolId: string,
  leaveType: string,        // e.g., "CASUAL_LEAVE", "SICK_LEAVE"
  startDate: string,        // YYYY-MM-DD
  endDate: string,          // YYYY-MM-DD
  reason: string,
  halfDay: boolean          // optional, default: false
}
```

**Validations:**
- Checks available leave balance
- Detects overlapping leave applications
- Calculates number of days automatically

**Response:**
```javascript
{
  success: true,
  leaveId: "doc_id",
  message: "Leave application submitted successfully"
}
```

**Firestore Structure:**
```
schools/{schoolId}/leaves/{leaveId}
{
  staffId: string,
  staffName: string,
  employeeId: string,
  leaveType: string,
  startDate: string,
  endDate: string,
  days: number,
  halfDay: boolean,
  reason: string,
  status: "PENDING",
  appliedAt: Timestamp,
  appliedBy: string,
  schoolId: string
}
```

---

#### 2. **approveLeave**
Admin approves leave and deducts from balance (atomic transaction).

**Parameters:**
```javascript
{
  schoolId: string,
  leaveId: string,
  remarks: string          // optional
}
```

**Process:**
1. Verifies admin role
2. Checks leave status is PENDING
3. Verifies sufficient balance
4. Updates leave status to APPROVED
5. Deducts from leave balance (atomic)

**Response:**
```javascript
{
  success: true,
  message: "Leave approved successfully"
}
```

**Updated Fields:**
```javascript
{
  status: "APPROVED",
  approvedAt: Timestamp,
  approvedBy: string,
  approverName: string,
  remarks: string
}
```

---

#### 3. **rejectLeave**
Admin rejects leave application.

**Parameters:**
```javascript
{
  schoolId: string,
  leaveId: string,
  remarks: string          // required
}
```

**Response:**
```javascript
{
  success: true,
  message: "Leave rejected successfully"
}
```

---

#### 4. **cancelLeave**
Staff can cancel their own pending leave.

**Parameters:**
```javascript
{
  schoolId: string,
  leaveId: string
}
```

**Validations:**
- Only pending leaves can be cancelled
- Only owner can cancel

---

### Permission Management

#### 5. **applyPermission**
Staff can request permission for partial day absence.

**Parameters:**
```javascript
{
  schoolId: string,
  date: string,            // YYYY-MM-DD
  startTime: string,       // HH:MM
  endTime: string,         // HH:MM
  reason: string
}
```

**Validations:**
- Checks available permission balance (hours)
- Calculates duration automatically
- Prevents duplicate permissions for same date

**Response:**
```javascript
{
  success: true,
  permissionId: "doc_id",
  message: "Permission request submitted successfully"
}
```

**Firestore Structure:**
```
schools/{schoolId}/permissions/{permissionId}
{
  staffId: string,
  staffName: string,
  employeeId: string,
  date: string,
  startTime: string,
  endTime: string,
  hours: number,
  reason: string,
  status: "PENDING",
  appliedAt: Timestamp,
  appliedBy: string,
  schoolId: string
}
```

---

#### 6. **approvePermission**
Admin approves permission and deducts from balance (atomic transaction).

**Parameters:**
```javascript
{
  schoolId: string,
  permissionId: string,
  remarks: string          // optional
}
```

**Process:**
1. Verifies admin role
2. Checks permission status is PENDING
3. Verifies sufficient balance (hours)
4. Updates permission status to APPROVED
5. Deducts from permission balance (atomic)

---

#### 7. **rejectPermission**
Admin rejects permission request.

**Parameters:**
```javascript
{
  schoolId: string,
  permissionId: string,
  remarks: string          // required
}
```

---

### Balance Management

#### 8. **adjustLeaveBalance**
Admin can manually adjust leave balance.

**Parameters:**
```javascript
{
  schoolId: string,
  staffId: string,
  leaveType: string,
  adjustment: number,      // positive to add, negative to deduct
  reason: string
}
```

**Example:**
```javascript
// Add 2 days of casual leave
{
  schoolId: "school123",
  staffId: "staff456",
  leaveType: "CASUAL_LEAVE",
  adjustment: 2,
  reason: "Bonus leave for excellent performance"
}
```

**Updated Fields:**
```javascript
{
  available: FieldValue.increment(adjustment),
  updatedAt: Timestamp,
  lastAdjustment: {
    amount: number,
    reason: string,
    adjustedBy: string,
    adjustedAt: Timestamp
  }
}
```

---

#### 9. **adjustPermissionBalance**
Admin can manually adjust permission balance.

**Parameters:**
```javascript
{
  schoolId: string,
  staffId: string,
  adjustment: number,      // hours (positive to add, negative to deduct)
  reason: string
}
```

---

## Firestore Structure

### Leave Balance
```
schools/{schoolId}/staff/{staffId}/leave_balances/{leaveType}
{
  available: number,       // Days available
  used: number,            // Days used
  total: number,           // Total allocated
  updatedAt: Timestamp,
  lastAdjustment: {
    amount: number,
    reason: string,
    adjustedBy: string,
    adjustedAt: Timestamp
  }
}
```

### Permission Balance
```
schools/{schoolId}/staff/{staffId}/permission_balances/current_year
{
  availableHours: number,  // Hours available
  usedHours: number,       // Hours used
  totalHours: number,      // Total allocated
  updatedAt: Timestamp,
  lastAdjustment: {
    amount: number,
    reason: string,
    adjustedBy: string,
    adjustedAt: Timestamp
  }
}
```

---

## Security Rules

### Leave and Permission Applications
- **Read**: Staff can read their own, admins can read all
- **Create**: Any authenticated staff can create
- **Update**: Admins can approve/reject, staff can cancel pending
- **Delete**: Only admins

### Balances (leave_balances, permission_balances)
- **Read**: Staff can read their own, admins can read all
- **Write**: ❌ **BLOCKED** - Only Cloud Functions can write
  - Prevents tampering
  - Ensures data integrity
  - Maintains audit trail

---

## Firestore Indexes

Required composite indexes:

```json
{
  "collectionGroup": "leaves",
  "fields": [
    { "fieldPath": "staffId", "order": "ASCENDING" },
    { "fieldPath": "status", "order": "ASCENDING" },
    { "fieldPath": "appliedAt", "order": "DESCENDING" }
  ]
},
{
  "collectionGroup": "leaves",
  "fields": [
    { "fieldPath": "staffId", "order": "ASCENDING" },
    { "fieldPath": "status", "order": "ASCENDING" },
    { "fieldPath": "startDate", "order": "ASCENDING" }
  ]
},
{
  "collectionGroup": "permissions",
  "fields": [
    { "fieldPath": "staffId", "order": "ASCENDING" },
    { "fieldPath": "status", "order": "ASCENDING" },
    { "fieldPath": "date", "order": "ASCENDING" }
  ]
},
{
  "collectionGroup": "permissions",
  "fields": [
    { "fieldPath": "staffId", "order": "ASCENDING" },
    { "fieldPath": "date", "order": "ASCENDING" },
    { "fieldPath": "status", "order": "ASCENDING" }
  ]
}
```

---

## Usage Examples

### Frontend Implementation (Flutter/Dart)

#### Apply for Leave
```dart
final callable = FirebaseFunctions.instance.httpsCallable('applyLeave');

try {
  final result = await callable.call({
    'schoolId': schoolId,
    'leaveType': 'CASUAL_LEAVE',
    'startDate': '2025-05-10',
    'endDate': '2025-05-12',
    'reason': 'Family function',
    'halfDay': false,
  });
  
  print('Leave applied: ${result.data['leaveId']}');
} catch (e) {
  print('Error: $e');
}
```

#### Approve Leave (Admin)
```dart
final callable = FirebaseFunctions.instance.httpsCallable('approveLeave');

try {
  final result = await callable.call({
    'schoolId': schoolId,
    'leaveId': leaveId,
    'remarks': 'Approved for family function',
  });
  
  print('Leave approved successfully');
} catch (e) {
  print('Error: $e');
}
```

#### Apply for Permission
```dart
final callable = FirebaseFunctions.instance.httpsCallable('applyPermission');

try {
  final result = await callable.call({
    'schoolId': schoolId,
    'date': '2025-05-08',
    'startTime': '10:00',
    'endTime': '12:00',
    'reason': 'Doctor appointment',
  });
  
  print('Permission requested: ${result.data['permissionId']}');
} catch (e) {
  print('Error: $e');
}
```

#### Adjust Leave Balance (Admin)
```dart
final callable = FirebaseFunctions.instance.httpsCallable('adjustLeaveBalance');

try {
  final result = await callable.call({
    'schoolId': schoolId,
    'staffId': staffId,
    'leaveType': 'CASUAL_LEAVE',
    'adjustment': 2,  // Add 2 days
    'reason': 'Bonus leave for excellent performance',
  });
  
  print('Balance adjusted successfully');
} catch (e) {
  print('Error: $e');
}
```

---

## Error Handling

### Common Errors

| Error Code | Message | Cause |
|------------|---------|-------|
| `unauthenticated` | User must be authenticated | Not logged in |
| `permission-denied` | Only admins can approve leaves | Insufficient permissions |
| `invalid-argument` | Missing required fields | Invalid parameters |
| `not-found` | Staff not found | Invalid staff ID |
| `failed-precondition` | Insufficient leave balance | Not enough balance |
| `already-exists` | Overlapping leave exists | Duplicate leave dates |

---

## Workflow Diagrams

### Leave Application Flow
```
Staff → Apply Leave
  ↓
Check Balance
  ↓
Check Overlaps
  ↓
Create Application (PENDING)
  ↓
Admin Reviews
  ├─ Approve → Deduct Balance → Status: APPROVED
  └─ Reject → Status: REJECTED
```

### Permission Request Flow
```
Staff → Request Permission
  ↓
Check Balance (Hours)
  ↓
Check Duplicate
  ↓
Create Request (PENDING)
  ↓
Admin Reviews
  ├─ Approve → Deduct Hours → Status: APPROVED
  └─ Reject → Status: REJECTED
```

---

## Configuration Setup

### Initialize Leave Balances for Staff
```javascript
// Run once per staff member per leave type
await db
  .collection('schools')
  .doc(schoolId)
  .collection('staff')
  .doc(staffId)
  .collection('leave_balances')
  .doc('CASUAL_LEAVE')
  .set({
    available: 12,
    used: 0,
    total: 12,
    updatedAt: FieldValue.serverTimestamp()
  });
```

### Initialize Permission Balance for Staff
```javascript
// Run once per staff member per year
await db
  .collection('schools')
  .doc(schoolId)
  .collection('staff')
  .doc(staffId)
  .collection('permission_balances')
  .doc('current_year')
  .set({
    availableHours: 24,
    usedHours: 0,
    totalHours: 24,
    updatedAt: FieldValue.serverTimestamp()
  });
```

---

## Deployment

### Deploy Functions
```bash
firebase deploy --only functions:applyLeave,functions:approveLeave,functions:rejectLeave,functions:cancelLeave,functions:applyPermission,functions:approvePermission,functions:rejectPermission,functions:adjustLeaveBalance,functions:adjustPermissionBalance
```

### Deploy Indexes
```bash
firebase deploy --only firestore:indexes
```

### Deploy Rules
```bash
firebase deploy --only firestore:rules
```

---

## Testing

### Test Leave Application
```bash
# Using Firebase CLI
firebase functions:shell

> applyLeave({schoolId: 'test', leaveType: 'CASUAL_LEAVE', startDate: '2025-05-10', endDate: '2025-05-12', reason: 'Test'})
```

### Test Permission Request
```bash
> applyPermission({schoolId: 'test', date: '2025-05-08', startTime: '10:00', endTime: '12:00', reason: 'Test'})
```

---

## Best Practices

1. **Always use transactions** for balance updates to prevent race conditions
2. **Validate balances** before approval
3. **Check for overlaps** to prevent duplicate leaves
4. **Maintain audit trail** with timestamps and user IDs
5. **Use atomic operations** for balance increments/decrements
6. **Secure balances** - only Cloud Functions can write
7. **Provide clear error messages** for better UX

---

## Related Documentation
- [Attendance Finalization System](./ATTENDANCE_FINALIZATION_SYSTEM.md)
- [RFID Attendance System](./RFID_ATTENDANCE_SYSTEM_IMPLEMENTATION.md)
- [Firestore Indexes Reference](./FIRESTORE_INDEXES_REFERENCE.md)
