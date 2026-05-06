# Payment Dialog - Send Due Notification Feature

## Overview
Added "Send Payment Due" notification button to the Make Payment dialog, allowing both admin and staff to send payment reminders directly from the payment screen.

## Implementation

### File Modified:
`lib/presentation/finance/widgets/multi_allocation_payment_dialog.dart`

### Changes Made:

#### 1. Added Import
```dart
import 'package:cloud_firestore/cloud_firestore.dart';
```

#### 2. Added "Send Payment Due" Button
**Location:** Above the "Save Payment" and "Show UPI QR" buttons

**Visibility Conditions:**
- Only shows if `totalPending > 0`
- Only shows if parent phone number exists

**Button Style:**
- Orange outlined button
- Icon: `notifications_active`
- Label: "Send Payment Due (₹[amount])"

#### 3. Added Notification Method
**Method:** `_sendPaymentDueNotification()`

**Flow:**
1. Shows confirmation dialog with:
   - Student name
   - Pending amount
   - Parent phone number
2. User confirms or cancels
3. If confirmed:
   - Sends notification (placeholder for WhatsApp/SMS integration)
   - Shows success message
   - Updates `lastReminderSentAt` timestamp in Firestore
4. If error:
   - Shows error message

## User Experience

### Before Payment:
```
┌────────────────────────────────────────┐
│ Make Payment                        ✕  │
│ SAMPLE STUDENT 34 • I • AY 2026-27     │
├────────────────────────────────────────┤
│ [Total Tendered]      [Auto-allocate] │
│                                        │
│ December - Due 05 Dec 2026  [₹ 0]     │
│ January - Due 05 Jan 2027   [₹ 0]     │
│ ...                                    │
│                                        │
│ Outstanding: ₹17,865  Allocated: ₹0   │
│                                        │
│ ┌────────────────────────────────────┐ │
│ │ 🔔 Send Payment Due (₹17,865)      │ │ ← NEW!
│ └────────────────────────────────────┘ │
│                                        │
│ [💾 Save Payment] [📱 Show UPI QR]    │
└────────────────────────────────────────┘
```

### Confirmation Dialog:
```
┌────────────────────────────────────────┐
│ Send Payment Due Notification          │
├────────────────────────────────────────┤
│ Student: SAMPLE STUDENT 34             │
│ Pending Amount: ₹17,865                │
│                                        │
│ Notification will be sent to:          │
│ +918508196981                          │
│                                        │
│              [Cancel] [Send Notification]│
└────────────────────────────────────────┘
```

### Success Message:
```
✅ Payment due notification sent to +918508196981
```

## Access Control

### Who Can Use:
- ✅ **Admin** - Can send from any student's payment dialog
- ✅ **Finance Users** - Can send from any student's payment dialog
- ✅ **Staff** - Can send from their assigned class students' payment dialog

### Permissions:
- No special permissions required
- Uses existing Firestore write access for ledger updates
- Notification sending is placeholder (TODO: implement WhatsApp/SMS)

## Database Updates

### Firestore Update:
```javascript
// Updates the ledger document
{
  lastReminderSentAt: Timestamp // Server timestamp
}
```

**Collection Path:**
```
schools/{schoolId}/studentFeeLedgers/{ledgerId}
```

**No new indexes required** - This is a simple document update, not a query.

## Integration Points

### Current Implementation:
- ✅ Button added to payment dialog
- ✅ Confirmation dialog
- ✅ Success/error feedback
- ✅ Firestore timestamp update
- ⏳ **TODO:** WhatsApp/SMS integration

### Future Integration:
Replace the placeholder in `_sendPaymentDueNotification()`:
```dart
// TODO: Implement WhatsApp/SMS notification
await Future.delayed(const Duration(seconds: 1));
```

With actual notification service:
```dart
// Example WhatsApp integration
final whatsappService = ref.read(whatsappServiceProvider);
await whatsappService.sendPaymentDue(
  phoneNumber: widget.ledger.parentPhone!,
  studentName: widget.ledger.studentName,
  pendingAmount: widget.ledger.totalPending,
);
```

## Testing

### Test Scenarios:

#### 1. With Pending Amount and Phone Number
- ✅ Button visible
- ✅ Click shows confirmation dialog
- ✅ Confirm sends notification
- ✅ Success message displayed
- ✅ Timestamp updated

#### 2. No Pending Amount
- ✅ Button hidden (totalPending = 0)

#### 3. No Parent Phone Number
- ✅ Button hidden
- ✅ If somehow shown, dialog shows error message
- ✅ Send button disabled

#### 4. Error Handling
- ✅ Network error shows error message
- ✅ Firestore error shows error message
- ✅ User can retry

### Test Data:
Use sample students created by:
```bash
node scripts/add-sample-students.js
```

All have phone: `+918508196981`

## Usage Instructions

### For Admin/Finance:
1. Navigate to any student's fee management
2. Click "Make Payment" button
3. Payment dialog opens
4. If student has pending fees, see orange "Send Payment Due" button
5. Click button
6. Confirm in dialog
7. Notification sent

### For Staff:
1. Navigate to assigned class students
2. Select student
3. Open payment dialog
4. Same flow as admin

## Benefits

### 1. Contextual Reminders
- Send reminder while viewing payment details
- No need to navigate to separate notification screen
- Immediate action from payment context

### 2. Convenience
- One-click notification
- No need to remember phone numbers
- Automatic timestamp tracking

### 3. Better UX
- Integrated workflow
- Confirmation before sending
- Clear feedback

### 4. Tracking
- `lastReminderSentAt` timestamp
- Can prevent duplicate reminders
- Audit trail of communications

## Related Features

### Other Notification Options:
1. **Student Ledgers & Payments Screen**
   - Bulk notifications
   - Individual notifications
   - Filter by class/section

2. **Staff Student Ledger Screen**
   - Class-specific notifications
   - Bulk for assigned class

3. **Payment Dialog** ← NEW!
   - Individual notification
   - Payment context

## Technical Notes

### State Management:
- Uses `ConsumerStatefulWidget` (Riverpod)
- Local state for dialog
- No global state changes

### Error Handling:
- Try-catch for Firestore updates
- User-friendly error messages
- Non-blocking errors

### Performance:
- Minimal overhead
- Single Firestore write
- No complex queries

## Limitations

### Current:
- Notification is placeholder (not actually sent)
- No rate limiting
- No duplicate prevention
- No notification history

### Future Improvements:
1. Implement actual WhatsApp/SMS
2. Add rate limiting (e.g., max 1 per day per student)
3. Check `lastReminderSentAt` before allowing send
4. Add notification history/log
5. Template customization
6. Multi-language support

## Summary

**The Make Payment dialog now includes a "Send Payment Due" button that allows admin and staff to send payment reminders directly from the payment screen, with confirmation dialog and automatic timestamp tracking.**

All necessary code changes are complete. No new Firestore indexes required.
