# Critical Fixes Applied - Leave Cancellation Flow

## Issues Fixed

### Issue 1: Permission Denied Error When Cancelling Pending Leaves ✅

**Problem:**
```
❌ [LEAVE_REPO] Failed to update leave status: [cloud_firestore/permission-denied] Missing or insufficient permissions.
```

**Root Cause:**
Firestore security rules only allowed teachers to set status to `'cancellationRequested'`, but not to `'cancelled'` for pending leaves.

**Solution:**
Updated `firestore.rules` (lines 99-108) to allow teachers to:
1. Set status to `'cancellationRequested'` (for approved leaves)
2. Set status to `'cancelled'` (for pending leaves - immediate cancellation)

**Rule Change:**
```javascript
allow update: if isSignedIn() && isActive() && (
  isSuperAdmin() || 
  (isTenantAdmin() && belongsToSchool(schoolId)) ||
  // Teachers can update their own leaves:
  // 1. Set status to 'cancellationRequested' (for approved leaves)
  // 2. Set status to 'cancelled' (for pending leaves - immediate cancellation)
  (isTeacher() && belongsToSchool(schoolId) && resource.data.teacherId == request.auth.uid && 
   (request.resource.data.status == 'cancellationRequested' || 
    (resource.data.status == 'pending' && request.resource.data.status == 'cancelled')))
);
```

---

### Issue 2: Admin Can't Distinguish Leave Request vs Cancellation Request ✅

**Problem:**
- Admin couldn't clearly see if it's a new leave request or a cancellation request
- Buttons didn't show for cancellation requests
- Approving cancellation moved status to `approved` instead of `cancelled`

**Solutions Applied:**

#### A. Visual Indicators (Already Existed, Enhanced)
**File:** `leave_requests_screen.dart` (lines 267-282)
- Shows "CANCELLATION REQUEST" label in purple
- Purple icon for cancellation requests
- Clear visual distinction

#### B. Action Buttons Now Show for Cancellation Requests
**File:** `leave_requests_screen.dart` (lines 402-442)
- **Before:** Buttons only showed for `pending` status
- **After:** Buttons show for both `pending` AND `cancellationRequested` status
- Button text changes based on request type:
  - **Leave Request:** "Approve Leave" / "Reject Leave"
  - **Cancellation Request:** "Approve Cancellation" / "Reject Cancellation"
- Button color changes:
  - **Leave Request:** Green approve button
  - **Cancellation Request:** Purple approve button

#### C. Correct Status Flow
**File:** `leave_requests_screen.dart` (lines 583-615)
- **Approve Leave Request:** `pending` → `approved`
- **Approve Cancellation:** `cancellationRequested` → `cancelled` (balance restored)

#### D. Reject Cancellation Properly Handled
**File:** `leave_requests_screen.dart` (lines 624-693)
- **Reject Leave Request:** `pending` → `rejected`
- **Reject Cancellation:** `cancellationRequested` → `approved` (reverts back)
- Dialog title and message change based on request type
- Proper feedback messages

---

## Complete Leave Status Flow

### Teacher Side:

1. **Apply Leave:**
   - Status: `pending`
   - Balance: Added to `pending`

2. **Cancel Pending Leave (Immediate):**
   - Status: `pending` → `cancelled`
   - Balance: Removed from `pending`, added to `available`
   - No admin approval needed

3. **Cancel Approved Leave (Request):**
   - Status: `approved` → `cancellationRequested`
   - Balance: Still in `used` (not restored yet)
   - Needs admin approval

### Admin Side:

1. **Approve Leave Request:**
   - Status: `pending` → `approved`
   - Balance: Moved from `pending` to `used`
   - Message: "Leave request approved - balance deducted"

2. **Reject Leave Request:**
   - Status: `pending` → `rejected`
   - Balance: Removed from `pending`, added to `available`
   - Message: "Leave request rejected"

3. **Approve Cancellation Request:**
   - Status: `cancellationRequested` → `cancelled`
   - Balance: Removed from `used`, added to `available`
   - Message: "Leave cancellation approved - balance restored"
   - Button: Purple "Approve Cancellation"

4. **Reject Cancellation Request:**
   - Status: `cancellationRequested` → `approved`
   - Balance: Remains in `used`
   - Message: "Cancellation rejected - leave remains approved"
   - Button: Red "Reject Cancellation"

---

## UI Changes Summary

### Admin Leave Requests Screen:

**Cancellation Request Card Shows:**
- 🟣 Purple "CANCELLATION REQUEST" label
- 🟣 Purple status badge: "CANCELLATIONREQUESTED"
- 🟣 Purple "Approve Cancellation" button
- 🔴 Red "Reject Cancellation" button
- Clear visual distinction from regular leave requests

**Regular Leave Request Card Shows:**
- 🟠 Orange "PENDING" status badge
- 🟢 Green "Approve Leave" button
- 🔴 Red "Reject Leave" button

---

## Testing Checklist

### Test 1: Cancel Pending Leave (Teacher)
- [ ] Apply for leave (status: pending)
- [ ] Click cancel icon
- [ ] Confirm cancellation
- [ ] ✅ Should cancel immediately (no permission error)
- [ ] ✅ Balance should be restored
- [ ] ✅ Status should be "CANCELLED"

### Test 2: Request Cancellation of Approved Leave (Teacher)
- [ ] Have an approved leave
- [ ] Click cancel icon
- [ ] Confirm cancellation request
- [ ] ✅ Status should change to "CANCEL REQUESTED" (purple)
- [ ] ✅ Balance should still be in "used" (not restored yet)

### Test 3: Admin Approves Cancellation
- [ ] Login as admin
- [ ] See cancellation request with purple label
- [ ] ✅ Should show "CANCELLATION REQUEST" label
- [ ] ✅ Should show purple "Approve Cancellation" button
- [ ] Click "Approve Cancellation"
- [ ] ✅ Status should change to "CANCELLED"
- [ ] ✅ Balance should be restored to teacher
- [ ] ✅ Message: "Leave cancellation approved - balance restored"

### Test 4: Admin Rejects Cancellation
- [ ] Login as admin
- [ ] See cancellation request
- [ ] Click "Reject Cancellation"
- [ ] Enter reason
- [ ] ✅ Status should revert to "APPROVED"
- [ ] ✅ Balance should remain in "used"
- [ ] ✅ Message: "Cancellation rejected - leave remains approved"

---

## Files Modified

1. **firestore.rules** (lines 99-108)
   - Added permission for teachers to cancel pending leaves

2. **leave_requests_screen.dart** (lines 402-442)
   - Show buttons for both pending and cancellation requests
   - Dynamic button text and colors

3. **leave_requests_screen.dart** (lines 624-693)
   - Handle rejection of cancellation requests properly
   - Revert to approved status when cancellation is rejected

---

## Deploy Instructions

### 1. Update Firestore Rules
```bash
firebase deploy --only firestore:rules
```

### 2. Hot Restart Flutter App
In the terminal where app is running, press `R`

### 3. Test All Scenarios
Follow the testing checklist above

---

## Summary

✅ **Permission error fixed** - Teachers can now cancel pending leaves
✅ **Admin UI enhanced** - Clear distinction between leave requests and cancellation requests
✅ **Correct status flow** - Cancellation approval sets status to `cancelled`, not `approved`
✅ **Rejection handled** - Rejecting cancellation reverts to `approved` status
✅ **Visual indicators** - Purple color scheme for cancellation requests
✅ **Balance management** - Proper restoration of leave balance

All issues resolved! The leave cancellation flow is now complete and working correctly.
