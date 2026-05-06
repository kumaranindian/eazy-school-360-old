# Payment Due Notify Button Troubleshooting

## Issue
Payment due notification buttons not showing next to fee rows in the Make Payment dialog.

## Root Causes

### 1. Missing Parent Phone Number
**Most Common Issue**

The notify button only shows if:
```dart
e.balanceAmount > 0 && 
widget.ledger.parentPhone != null && 
widget.ledger.parentPhone!.isNotEmpty
```

**Solution:** Ensure the student ledger has a parent phone number set.

**Check in Firestore:**
```javascript
schools/{schoolId}/studentFeeLedgers/{ledgerId}
{
  parentPhone: "+918508196981"  // Must be set!
}
```

### 2. Zero Balance Amount
If `e.balanceAmount` is 0, the button won't show (no point sending reminder for paid fees).

### 3. Debug Logging Added
Added console logging to help diagnose:
```dart
debugPrint('[AllocationRow] ${e.termName}: balance=${e.balanceAmount}, phone=${widget.ledger.parentPhone}, showNotify=$shouldShowNotify');
```

**Check Console Output:**
- Open browser DevTools console
- Look for `[AllocationRow]` messages
- Check if `showNotify=true` or `false`
- If `false`, check which condition failed

## How to Fix

### Option 1: Add Parent Phone to Ledger
**Via Firestore Console:**
1. Go to Firestore
2. Navigate to: `schools/{schoolId}/studentFeeLedgers/{ledgerId}`
3. Add field: `parentPhone` = `"+918508196981"`
4. Save
5. Refresh the app

### Option 2: Update Student Record
**Via Student Management:**
1. Go to Student Management
2. Find the student
3. Edit student details
4. Add parent phone number
5. Save
6. Ledger should inherit the phone number

### Option 3: Bulk Update Script
**For multiple students:**
```javascript
// Run in Firebase Console or Node.js script
const db = admin.firestore();
const schoolId = "BQs5pYYblCCD0H72v9JS";

const ledgers = await db
  .collection('schools')
  .doc(schoolId)
  .collection('studentFeeLedgers')
  .get();

for (const doc of ledgers.docs) {
  await doc.ref.update({
    parentPhone: "+918508196981"  // Use actual parent phone
  });
}
```

## Testing

### 1. Check Console Logs
After hot reload, open Make Payment dialog and check console:
```
[AllocationRow] June: balance=3000.0, phone=+918508196981, showNotify=true
[AllocationRow] July: balance=3000.0, phone=+918508196981, showNotify=true
```

### 2. Expected UI
If `showNotify=true`, you should see:
```
TUITION  June
Due 05 Jun 2026 • Bal ₹3,000
                       [₹ 0] 🔔
                              ↑ Button here!
```

### 3. If Still Not Showing
- Check if Row is wrapping due to width constraints
- Check if button is off-screen (scroll right?)
- Verify Flutter hot reload worked
- Try full restart

## RFID Cards Issue

### Problem
"Loaded 0 available cards" even after registering RFID card via API.

### Root Cause
Cloud Function `register-rfid` wasn't setting required fields:
- Missing `staffId` field (should be empty string for unassigned)
- Missing `uuid` field
- Missing `cardType` field
- Missing `assignedAt` field

### Fix Applied
Updated `functions/src/rfid-attendance/controllers/rfidController.js`:
```javascript
const rfidCard = {
  uuid: rfidTag,        // Added
  rfidTag,
  schoolId,
  staffId: '',          // Added - empty for unassigned
  staffName: '',        // Added - empty for unassigned
  cardType: 'primary',  // Added - default type
  registeredBy: deviceId,
  registeredAt: admin.firestore.FieldValue.serverTimestamp(),
  assignedAt: admin.firestore.FieldValue.serverTimestamp(),  // Added
  isActive: true,
  isAssigned: false,
  metadata: {
    deviceName,
    registrationDevice: deviceId
  }
};
```

### After Deployment
1. **Delete old card** (TAG1234567890) from Firestore
2. **Register new card** using the API again
3. **Refresh RFID Management screen**
4. **Should see:** "Loaded 1 available cards"
5. **Dropdown will show** the card

### Manual Fix for Existing Cards
If you don't want to re-register, update existing cards in Firestore:
```javascript
// For each card in schools/{schoolId}/rfid_cards
{
  uuid: "TAG1234567890",      // Add if missing
  staffId: "",                // Add if missing (empty string!)
  staffName: "",              // Add if missing
  cardType: "primary",        // Add if missing
  assignedAt: Timestamp.now() // Add if missing
}
```

## Summary

**Payment Notify Buttons:**
- ✅ Code is correct
- ⚠️ Requires parent phone number in ledger
- 🔍 Check console logs to diagnose

**RFID Cards:**
- ✅ Cloud Function fixed
- 🚀 Deploy in progress
- 🔄 Re-register cards or manually update Firestore

**Next Steps:**
1. Add parent phone to student ledgers
2. Wait for Cloud Function deployment
3. Re-register RFID cards
4. Test both features
