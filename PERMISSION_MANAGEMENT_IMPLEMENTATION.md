# Permission Management - Complete Implementation Guide

## ✅ COMPLETED CHANGES

### 1. Permission Status Enum Updated
**File:** `lib/domain/entities/permission_request.dart`

```dart
enum PermissionStatus {
  pending,
  approved,
  rejected,
  cancellationRequested,  // ✅ ADDED
  cancelled,              // ✅ ADDED
}
```

### 2. Status Parsing Fixed
**File:** `lib/domain/entities/permission_request.dart` (lines 150-167)

```dart
static PermissionStatus _parsePermissionStatus(String? value) {
  if (value == null) return PermissionStatus.pending;
  
  switch (value.toLowerCase()) {
    case 'approved':
      return PermissionStatus.approved;
    case 'rejected':
      return PermissionStatus.rejected;
    case 'cancellationrequested':  // ✅ ADDED
      return PermissionStatus.cancellationRequested;
    case 'cancelled':  // ✅ ADDED
      return PermissionStatus.cancelled;
    case 'pending':
      return PermissionStatus.pending;
    default:
      return PermissionStatus.pending;
  }
}
```

### 3. Firestore Security Rules Updated
**File:** `firestore.rules` (lines 155-173)

Teachers can now:
- Set status to `'cancellationRequested'` for approved permissions
- Set status to `'cancelled'` for pending permissions (immediate cancellation)

### 4. Permission Repository Enhanced
**File:** `lib/data/repositories/permission_repository.dart`

**New Methods Added:**

#### A. `updatePermissionStatus()` (lines 420-462)
- Updates permission status (for cancellations)
- Calls balance restoration when cancelled

#### B. `_restorePermissionBalance()` (lines 464-508)
- Restores permission balance when cancelled
- Handles both pending and approved permissions
- Updates: pending, used, available counts

**Balance Logic:**
- **Pending Permission Cancelled:** Reduces `pending` count, increases `available`
- **Approved Permission Cancelled:** Reduces `used` count, increases `available`

---

## 🔄 REMAINING IMPLEMENTATION

### Step 1: Add Cancellation UI to Teacher Dashboard

**File:** `lib/presentation/dashboard/screens/teacher_dashboard_screen.dart`

**Location:** Around line 952 (permission requests stream)

**Changes Needed:**

1. **Add Cancel Icon to Permission Cards**
   - Show cancel icon for `pending` and `approved` permissions
   - Hide cancel icon for `cancellationRequested` and `cancelled`

2. **Add Cancel Dialog**
   ```dart
   void _showCancelPermissionDialog(PermissionRequest permission) {
     // Similar to leave cancellation dialog
     // - Pending: Immediate cancellation
     // - Approved: Request cancellation (needs admin approval)
   }
   ```

3. **Add Cancel Logic**
   ```dart
   Future<void> _cancelPermission(PermissionRequest permission) async {
     if (permission.status == PermissionStatus.pending) {
       // Immediate cancellation
       await ref.read(permissionRepositoryProvider).updatePermissionStatus(
         _currentUser!.schoolId!,
         permission.id,
         PermissionStatus.cancelled,
         _currentUser!.id,
         'Cancelled by teacher',
       );
     } else if (permission.status == PermissionStatus.approved) {
       // Request cancellation
       await ref.read(permissionRepositoryProvider).updatePermissionStatus(
         _currentUser!.schoolId!,
         permission.id,
         PermissionStatus.cancellationRequested,
         _currentUser!.id,
         'Cancellation requested by teacher',
       );
     }
   }
   ```

4. **Update Status Display**
   - Add purple color for `cancellationRequested`
   - Add grey color for `cancelled`

---

### Step 2: Update Admin Permission Requests Screen

**File:** `lib/presentation/permission/screens/permission_requests_screen.dart`

**Changes Needed:**

1. **Add Prominent Banner for Cancellation Requests**
   ```dart
   if (permission.status == PermissionStatus.cancellationRequested) ...[
     Container(
       padding: const EdgeInsets.all(12),
       decoration: BoxDecoration(
         color: Colors.purple.shade50,
         borderRadius: BorderRadius.circular(8),
         border: Border.all(color: Colors.purple.shade300, width: 2),
       ),
       child: Row(
         children: [
           Icon(Icons.cancel_schedule_send, color: Colors.purple.shade700, size: 20),
           const SizedBox(width: 8),
           Text(
             '🔔 PERMISSION CANCELLATION REQUEST',
             style: TextStyle(
               color: Colors.purple.shade700,
               fontSize: 14,
               fontWeight: FontWeight.bold,
             ),
           ),
         ],
       ),
     ),
   ],
   ```

2. **Show Action Buttons for Both Pending and Cancellation Requests**
   ```dart
   if (permission.status == PermissionStatus.pending || 
       permission.status == PermissionStatus.cancellationRequested) ...[
     Row(
       children: [
         // Reject button
         OutlinedButton.icon(
           onPressed: () => _showRejectDialog(permission),
           label: Text(
             permission.status == PermissionStatus.cancellationRequested 
                 ? 'Reject Cancellation' 
                 : 'Reject Permission'
           ),
         ),
         // Approve button
         ElevatedButton.icon(
           onPressed: () => _approvePermission(permission),
           label: Text(
             permission.status == PermissionStatus.cancellationRequested 
                 ? 'Approve Cancellation' 
                 : 'Approve Permission'
           ),
           style: ElevatedButton.styleFrom(
             backgroundColor: permission.status == PermissionStatus.cancellationRequested 
                 ? Colors.purple 
                 : Colors.green,
           ),
         ),
       ],
     ),
   ],
   ```

3. **Update Approve Logic**
   ```dart
   Future<void> _approvePermission(PermissionRequest permission) async {
     if (permission.status == PermissionStatus.cancellationRequested) {
       // Approve cancellation - cancel the permission
       await ref.read(permissionRepositoryProvider).updatePermissionStatus(
         _schoolId!,
         permission.id,
         PermissionStatus.cancelled,
         _currentUserId!,
         'Permission cancellation approved by admin',
       );
       SnackBarUtils.showSuccess(context, 'Permission cancellation approved - balance restored');
     } else {
       // Approve regular permission request
       await ref.read(permissionRepositoryProvider).approvePermissionRequest(
         _schoolId!,
         permission.id,
         _currentUserId!,
         'Permission approved by admin',
       );
       SnackBarUtils.showSuccess(context, 'Permission approved - balance updated');
     }
   }
   ```

4. **Update Reject Logic**
   ```dart
   Future<void> _rejectPermission(PermissionRequest permission, String remarks) async {
     if (permission.status == PermissionStatus.cancellationRequested) {
       // Reject cancellation - revert to approved
       await ref.read(permissionRepositoryProvider).updatePermissionStatus(
         _schoolId!,
         permission.id,
         PermissionStatus.approved,
         _currentUserId!,
         'Cancellation rejected: $remarks',
       );
       SnackBarUtils.showWarning(context, 'Cancellation rejected - permission remains approved');
     } else {
       // Reject regular permission request
       await ref.read(permissionRepositoryProvider).rejectPermissionRequest(
         _schoolId!,
         permission.id,
         _currentUserId!,
         remarks,
       );
       SnackBarUtils.showWarning(context, 'Permission request rejected');
     }
   }
   ```

---

### Step 3: Add Dashboard Metrics for Cancellation Requests

**File:** `lib/presentation/dashboard/screens/teacher_dashboard_screen.dart`

**Location:** Dashboard metrics section (around line 400-450)

**Changes Needed:**

1. **Add Cancellation Request Count Cards**
   ```dart
   Row(
     children: [
       Expanded(child: _buildPendingLeavesCard(colorScheme)),
       const SizedBox(width: 16),
       Expanded(child: _buildLeave CancellationRequestsCard(colorScheme)),  // NEW
       const SizedBox(width: 16),
       Expanded(child: _buildPermissionCancellationRequestsCard(colorScheme)),  // NEW
     ],
   ),
   ```

2. **Build Leave Cancellation Card**
   ```dart
   Widget _buildLeaveCancellationRequestsCard(ColorScheme colorScheme) {
     return StreamBuilder<QuerySnapshot>(
       stream: FirebaseFirestore.instance
           .collection('schools')
           .doc(_currentUser!.schoolId!)
           .collection('leaves')
           .where('status', isEqualTo: 'cancellationRequested')
           .snapshots(),
       builder: (context, snapshot) {
         final count = snapshot.data?.docs.length ?? 0;
         return _buildSummaryStatCard(
           'Leave Cancellations',
           count.toString(),
           '',
           Icons.cancel_schedule_send,
           Colors.purple,
           colorScheme,
         );
       },
     );
   }
   ```

3. **Build Permission Cancellation Card**
   ```dart
   Widget _buildPermissionCancellationRequestsCard(ColorScheme colorScheme) {
     return StreamBuilder<QuerySnapshot>(
       stream: FirebaseFirestore.instance
           .collection('schools')
           .doc(_currentUser!.schoolId!)
           .collection('permissionRequests')
           .where('status', isEqualTo: 'cancellationRequested')
           .snapshots(),
       builder: (context, snapshot) {
         final count = snapshot.data?.docs.length ?? 0;
         return _buildSummaryStatCard(
           'Permission Cancellations',
           count.toString(),
           '',
           Icons.cancel_schedule_send,
           Colors.purple,
           colorScheme,
         );
       },
     );
   }
   ```

---

## Complete Permission Flow

### Teacher Actions:

1. **Request Permission:**
   - Status: `pending`
   - Balance: Added to `pending`
   - Validation: Check available balance

2. **Cancel Pending Permission (Immediate):**
   - Status: `pending` → `cancelled`
   - Balance: Removed from `pending`, added to `available`
   - No admin approval needed

3. **Cancel Approved Permission (Request):**
   - Status: `approved` → `cancellationRequested`
   - Balance: Still in `used` (not restored yet)
   - Needs admin approval

### Admin Actions:

1. **Approve Permission Request:**
   - Status: `pending` → `approved`
   - Balance: Moved from `pending` to `used`

2. **Reject Permission Request:**
   - Status: `pending` → `rejected`
   - Balance: Removed from `pending`, added to `available`

3. **Approve Cancellation Request:**
   - Status: `cancellationRequested` → `cancelled`
   - Balance: Removed from `used`, added to `available`
   - Message: "Permission cancellation approved - balance restored"

4. **Reject Cancellation Request:**
   - Status: `cancellationRequested` → `approved`
   - Balance: Remains in `used`
   - Message: "Cancellation rejected - permission remains approved"

---

## Testing Checklist

### Test 1: Request Permission with Balance Validation
- [ ] Try to request permission when balance is 0
- [ ] ✅ Should show error: "No permissions available this month"
- [ ] Request permission when balance > 0
- [ ] ✅ Should succeed and add to pending

### Test 2: Cancel Pending Permission
- [ ] Request a permission (status: pending)
- [ ] Click cancel icon
- [ ] ✅ Should cancel immediately
- [ ] ✅ Balance should be restored
- [ ] ✅ Status should be "CANCELLED"

### Test 3: Request Cancellation of Approved Permission
- [ ] Have an approved permission
- [ ] Click cancel icon
- [ ] ✅ Status should change to "CANCELLATION REQUESTED" (purple)
- [ ] ✅ Balance should still be in "used"

### Test 4: Admin Approves Cancellation
- [ ] Login as admin
- [ ] See cancellation request with purple banner
- [ ] ✅ Should show "🔔 PERMISSION CANCELLATION REQUEST"
- [ ] ✅ Should show purple "Approve Cancellation" button
- [ ] Click "Approve Cancellation"
- [ ] ✅ Status should change to "CANCELLED"
- [ ] ✅ Balance should be restored

### Test 5: Admin Rejects Cancellation
- [ ] Login as admin
- [ ] See cancellation request
- [ ] Click "Reject Cancellation"
- [ ] ✅ Status should revert to "APPROVED"
- [ ] ✅ Balance should remain in "used"

---

## Files Modified

1. ✅ `lib/domain/entities/permission_request.dart` - Added cancellation statuses
2. ✅ `firestore.rules` - Updated permission rules
3. ✅ `lib/data/repositories/permission_repository.dart` - Added cancellation methods
4. 🔄 `lib/presentation/dashboard/screens/teacher_dashboard_screen.dart` - Add cancellation UI
5. 🔄 `lib/presentation/permission/screens/permission_requests_screen.dart` - Update admin UI
6. 🔄 Dashboard metrics - Add cancellation request counts

---

## Deploy Instructions

1. **Deploy Firestore Rules:**
   ```bash
   firebase deploy --only firestore:rules
   ```

2. **Hot Restart Flutter App:**
   Press `R` in terminal

3. **Test All Scenarios:**
   Follow testing checklist above

---

## Summary

✅ **Permission Status Enum** - Added `cancellationRequested` and `cancelled`
✅ **Status Parsing** - Fixed to recognize all statuses
✅ **Firestore Rules** - Teachers can cancel their own permissions
✅ **Balance Management** - Proper restoration on cancellation
🔄 **Teacher UI** - Need to add cancellation buttons and dialogs
🔄 **Admin UI** - Need to add purple banners and proper button handling
🔄 **Dashboard Metrics** - Need to add cancellation request counts

**Next Steps:** Implement the remaining UI changes in teacher dashboard and admin screens.
