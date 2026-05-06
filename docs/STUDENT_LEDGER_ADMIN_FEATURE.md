# Student Ledger & Payment Due Notifications - Admin Feature

## Overview
Enhanced student directory for admin with integrated fee ledger view and payment due notification system.

## Features Implemented

### 1. **Student Directory with Ledger Integration**
- **File:** `lib/presentation/admin/screens/student_directory_with_ledger_screen.dart`
- **Access:** Admin Dashboard → Student Ledgers

#### Key Features:
- ✅ List all students with fee ledger data
- ✅ Display payment status (Pending/Cleared)
- ✅ Show total assigned, paid, and pending amounts
- ✅ Filter by class, section, and payment status
- ✅ Search by student name, ID, parent info
- ✅ Responsive design (mobile, tablet, desktop)

### 2. **Payment Due Notifications**

#### Individual Notification:
- Click notification icon next to student with pending fees
- Sends payment reminder to parent's phone number
- Updates `lastReminderSentAt` timestamp in ledger
- Confirmation dialog before sending

#### Bulk Notifications:
- **Button:** "Send Payment Due Alerts" (top right)
- Sends notifications to all students with:
  - Pending fees > 0
  - Valid parent phone number
- Shows progress indicator
- Reports success/failure count

### 3. **Fee Status Display**

#### Desktop View (Table):
- Student ID, Name, Class
- Fee Status chip showing:
  - Status: Pending (orange) / Cleared (green)
  - Amount: ₹Pending / ₹Total
- Action buttons: View Ledger, Send Due

#### Mobile View (Cards):
- Student avatar and basic info
- Fee status card with breakdown:
  - Total Assigned
  - Paid
  - Pending
- Action buttons below

### 4. **Ledger Integration**
- Click "View Ledger" to open full ledger detail screen
- Shows all terms, payments, and history
- Integrated with existing `StudentFeeLedgerDetailScreen`

## Navigation

### Admin Dashboard:
```
Admin Dashboard
  └── Student Management
      ├── Student Directory (existing)
      └── Student Ledgers (NEW) ← Payment due features
```

### Access Path:
1. Login as Admin
2. Navigate to "Student Ledgers" in sidebar
3. Or select from Student Management section

## UI/UX Features

### Responsive Design:
- **Desktop (>900px):** Table layout with all columns
- **Tablet (>600px):** Optimized card layout
- **Mobile (<600px):** Full-width cards with stacked info

### Color Coding:
- 🟢 **Green:** Fees cleared, no pending amount
- 🟠 **Orange:** Pending fees, payment due
- ⚫ **Grey:** No ledger data available

### Filters:
- **Search:** Name, ID, parent name/phone
- **Class:** Dropdown with all classes
- **Section:** Dropdown (dynamic based on class)
- **Payment Status:** All / Pending / Paid

## Data Flow

### Loading Sequence:
1. Load all active students from Firestore
2. Load fee ledgers for each student (cached)
3. Display combined data with status indicators

### Notification Flow:
```
User clicks "Send Due"
  ↓
Confirmation dialog
  ↓
Send notification (WhatsApp/SMS)
  ↓
Update lastReminderSentAt
  ↓
Show success message
```

## Database Integration

### Collections Used:
- `schools/{schoolId}/students` - Student data
- `schools/{schoolId}/studentFeeLedgers` - Fee ledger data

### Fields Updated:
- `lastReminderSentAt` - Timestamp of last notification sent

## Implementation Details

### Key Components:

#### 1. Student List with Ledger Cache:
```dart
List<Student> _allStudents = [];
Map<String, StudentFeeLedger?> _ledgerCache = {};
```

#### 2. Fee Status Calculation:
```dart
final hasPending = ledger != null && ledger.totalPending > 0;
```

#### 3. Notification System:
```dart
Future<void> _sendPaymentDueNotification(Student, StudentFeeLedger)
Future<void> _sendBulkPaymentDueNotifications()
```

### Responsive Breakpoints:
- Wide Screen: `width > 900px` → Table layout
- Tablet: `width > 600px` → Card layout
- Mobile: `width <= 600px` → Full-width cards

## TODO: Integration Points

### 1. WhatsApp/SMS Integration:
```dart
// TODO: Implement WhatsApp/SMS notification
// Current: Simulated with delay
await Future.delayed(const Duration(seconds: 1));
```

**Integration needed:**
- WhatsApp Business API
- SMS gateway (Twilio, MSG91, etc.)
- Message template with payment details

### 2. Academic Year Selection:
```dart
String? get _academicYear => '2024-25'; // TODO: Get from settings
```

**Integration needed:**
- Get from app settings/preferences
- Allow admin to select academic year

### 3. Notification Templates:
```
Dear [Parent Name],

Payment reminder for [Student Name] (Class [Class]-[Section]):
- Total Fees: ₹[Total]
- Paid: ₹[Paid]
- Pending: ₹[Pending]

Please make the payment at your earliest convenience.

Thank you,
[School Name]
```

## Testing Checklist

### Functional Testing:
- [ ] Load students with ledgers
- [ ] Filter by class/section
- [ ] Filter by payment status
- [ ] Search functionality
- [ ] View individual ledger
- [ ] Send individual notification
- [ ] Send bulk notifications
- [ ] Handle students without ledgers
- [ ] Handle students without phone numbers

### UI Testing:
- [ ] Desktop layout (table)
- [ ] Tablet layout (cards)
- [ ] Mobile layout (full-width)
- [ ] Filter dropdowns
- [ ] Search bar
- [ ] Loading states
- [ ] Empty states
- [ ] Error handling

### Edge Cases:
- [ ] No students
- [ ] No ledgers
- [ ] No pending fees
- [ ] Missing phone numbers
- [ ] Network errors
- [ ] Concurrent notifications

## Performance Considerations

### Optimization:
1. **Ledger Caching:** Prevents repeated Firestore queries
2. **Lazy Loading:** Ledgers loaded after students
3. **Filtered Queries:** Only active students loaded
4. **Debounced Search:** Prevents excessive re-renders

### Scalability:
- Handles 100+ students efficiently
- Cached ledger data reduces Firestore reads
- Pagination can be added if needed

## Security

### Access Control:
- ✅ Admin role required
- ✅ School ID validation
- ✅ Firestore security rules apply

### Data Privacy:
- Parent phone numbers protected
- Payment data secured
- Audit trail via `lastReminderSentAt`

## Future Enhancements

### Phase 2:
1. **Scheduled Notifications:**
   - Auto-send reminders on due dates
   - Recurring reminders for overdue payments

2. **Notification History:**
   - Track all sent notifications
   - View notification status (delivered/failed)

3. **Custom Templates:**
   - Admin can customize message templates
   - Multi-language support

4. **Payment Links:**
   - Include payment gateway links in notifications
   - Track payment from notification

5. **Analytics:**
   - Notification delivery rates
   - Payment conversion from notifications
   - Overdue payment trends

## Files Modified

### New Files:
- `lib/presentation/admin/screens/student_directory_with_ledger_screen.dart`
- `docs/STUDENT_LEDGER_ADMIN_FEATURE.md`

### Modified Files:
- `lib/presentation/dashboards/admin_dashboard_screen.dart`
  - Added import for new screen
  - Added navigation item "Student Ledgers"
  - Added case 11 in navigation handler

## Deployment Notes

### Prerequisites:
- Firestore indexes deployed (already done)
- Student ledgers created for students
- Parent phone numbers populated

### Configuration:
1. Set academic year in app settings
2. Configure WhatsApp/SMS provider
3. Set up notification templates
4. Test with sample data

### Rollout:
1. Deploy to TEST environment
2. Test with sample students
3. Verify notifications work
4. Deploy to UAT
5. Admin training
6. Deploy to PROD

## Support & Maintenance

### Common Issues:
1. **No ledgers showing:** Ensure ledgers are created for students
2. **Notifications not sending:** Check phone number format, API credentials
3. **Slow loading:** Check Firestore indexes, optimize queries

### Monitoring:
- Track notification success/failure rates
- Monitor Firestore read counts
- Log notification errors

## Summary

This feature provides admins with a comprehensive view of student fee ledgers and enables efficient payment reminder management. The responsive design ensures usability across all devices, while the bulk notification feature saves time when sending reminders to multiple parents.

**Key Benefits:**
- ✅ Single screen for student ledgers and payments
- ✅ Quick payment status overview
- ✅ Efficient bulk notification system
- ✅ Responsive and user-friendly UI
- ✅ Integrated with existing ledger system
