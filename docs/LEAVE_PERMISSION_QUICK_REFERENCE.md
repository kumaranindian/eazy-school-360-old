# Leave & Permission Management - Quick Reference

## 🚀 Cloud Functions Deployed

### Leave Functions
| Function | Purpose | Who Can Use |
|----------|---------|-------------|
| `applyLeave` | Apply for leave | Staff |
| `approveLeave` | Approve leave application | Admin |
| `rejectLeave` | Reject leave application | Admin |
| `cancelLeave` | Cancel pending leave | Staff (own leaves) |
| `adjustLeaveBalance` | Manually adjust balance | Admin |

### Permission Functions
| Function | Purpose | Who Can Use |
|----------|---------|-------------|
| `applyPermission` | Request permission | Staff |
| `approvePermission` | Approve permission request | Admin |
| `rejectPermission` | Reject permission request | Admin |
| `adjustPermissionBalance` | Manually adjust balance | Admin |

---

## 📊 Data Structure

### Leave Balance Location
```
schools/{schoolId}/staff/{staffId}/leave_balances/{leaveType}
```

**Fields:**
- `available` - Days available
- `used` - Days used
- `total` - Total allocated
- `updatedAt` - Last update timestamp
- `lastAdjustment` - Last manual adjustment details

### Permission Balance Location
```
schools/{schoolId}/staff/{staffId}/permission_balances/current_year
```

**Fields:**
- `availableHours` - Hours available
- `usedHours` - Hours used
- `totalHours` - Total allocated
- `updatedAt` - Last update timestamp
- `lastAdjustment` - Last manual adjustment details

### Leave Application Location
```
schools/{schoolId}/leaves/{leaveId}
```

**Status Values:**
- `PENDING` - Awaiting approval
- `APPROVED` - Approved by admin
- `REJECTED` - Rejected by admin
- `CANCELLED` - Cancelled by staff

### Permission Request Location
```
schools/{schoolId}/permissions/{permissionId}
```

**Status Values:**
- `PENDING` - Awaiting approval
- `APPROVED` - Approved by admin
- `REJECTED` - Rejected by admin

---

## 🔐 Security

### Balance Protection
- ✅ Staff can **READ** their own balances
- ✅ Admin can **READ** all balances
- ❌ **NO ONE** can write balances from frontend
- ✅ Only Cloud Functions can update balances

### Leave/Permission Applications
- ✅ Staff can create and cancel their own
- ✅ Admin can approve/reject any
- ✅ All operations are logged with timestamps

---

## 💡 Common Use Cases

### 1. Staff Applies for Leave
```dart
final result = await FirebaseFunctions.instance
  .httpsCallable('applyLeave')
  .call({
    'schoolId': schoolId,
    'leaveType': 'CASUAL_LEAVE',
    'startDate': '2025-05-10',
    'endDate': '2025-05-12',
    'reason': 'Family function',
  });
```

### 2. Admin Approves Leave
```dart
final result = await FirebaseFunctions.instance
  .httpsCallable('approveLeave')
  .call({
    'schoolId': schoolId,
    'leaveId': leaveId,
    'remarks': 'Approved',
  });
```

### 3. Staff Requests Permission
```dart
final result = await FirebaseFunctions.instance
  .httpsCallable('applyPermission')
  .call({
    'schoolId': schoolId,
    'date': '2025-05-08',
    'startTime': '10:00',
    'endTime': '12:00',
    'reason': 'Doctor appointment',
  });
```

### 4. Admin Adjusts Balance
```dart
final result = await FirebaseFunctions.instance
  .httpsCallable('adjustLeaveBalance')
  .call({
    'schoolId': schoolId,
    'staffId': staffId,
    'leaveType': 'CASUAL_LEAVE',
    'adjustment': 2,  // Add 2 days
    'reason': 'Bonus leave',
  });
```

---

## 🎯 Validation Rules

### Leave Application
- ✅ Must have sufficient balance
- ✅ Cannot overlap with existing leaves
- ✅ End date must be >= start date
- ✅ Half-day counts as 0.5 days

### Permission Request
- ✅ Must have sufficient hours
- ✅ Cannot have duplicate on same date
- ✅ End time must be > start time
- ✅ Duration calculated automatically

---

## 🔄 Workflow

### Leave Approval Flow
```
1. Staff applies → Status: PENDING
2. Admin reviews
   ├─ Approve → Deduct balance → Status: APPROVED
   └─ Reject → Status: REJECTED
3. Staff can cancel if PENDING
```

### Permission Approval Flow
```
1. Staff requests → Status: PENDING
2. Admin reviews
   ├─ Approve → Deduct hours → Status: APPROVED
   └─ Reject → Status: REJECTED
```

---

## 📝 Initial Setup

### Create Leave Balance for Staff
```javascript
await db
  .collection('schools').doc(schoolId)
  .collection('staff').doc(staffId)
  .collection('leave_balances').doc('CASUAL_LEAVE')
  .set({
    available: 12,
    used: 0,
    total: 12,
    updatedAt: FieldValue.serverTimestamp()
  });
```

### Create Permission Balance for Staff
```javascript
await db
  .collection('schools').doc(schoolId)
  .collection('staff').doc(staffId)
  .collection('permission_balances').doc('current_year')
  .set({
    availableHours: 24,
    usedHours: 0,
    totalHours: 24,
    updatedAt: FieldValue.serverTimestamp()
  });
```

---

## ⚠️ Common Errors

| Error | Meaning | Solution |
|-------|---------|----------|
| `Insufficient leave balance` | Not enough days | Adjust balance or reject |
| `Overlapping leave exists` | Duplicate dates | Cancel existing or change dates |
| `Permission-denied` | Not admin | Use admin account |
| `Leave is already APPROVED` | Cannot modify | Leave is finalized |
| `Insufficient permission balance` | Not enough hours | Adjust balance or reject |

---

## 📈 Monitoring

### Check Function Logs
```bash
firebase functions:log --only applyLeave
firebase functions:log --only approveLeave
```

### View in Firebase Console
```
Functions → Select function → Logs tab
```

---

## 🛠️ Troubleshooting

### Balance Not Updating
- Check Cloud Function logs
- Verify transaction completed
- Check Firestore rules (should block client writes)

### Cannot Apply Leave
- Verify sufficient balance
- Check for overlapping leaves
- Ensure staff document exists

### Permission Denied
- Verify user role (must be admin for approval)
- Check authentication status
- Verify school membership

---

## 📚 Related Docs
- [Full Documentation](./LEAVE_PERMISSION_MANAGEMENT_SYSTEM.md)
- [Attendance System](./ATTENDANCE_FINALIZATION_SYSTEM.md)
- [Firestore Rules](../firestore.rules)
