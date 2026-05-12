# Communication Logs Firestore Rules Fix

## Issue
The Communication Logs screen was showing Firestore permission errors for admin users because the Firestore security rules were completely missing for the `communicationLogs` collection.

## Root Cause
The application uses the `schools/{schoolId}/communicationLogs/{logId}` collection to store audit trails of all outgoing messages (WhatsApp, SMS, Email, etc.), but there were **no Firestore security rules** defined for this collection.

The Communication Logs Repository (`lib/data/repositories/communication_log_repository.dart`) performs the following operations:
- **Read**: Fetch paginated logs with filters (status, purpose, channel, recipient type, date range)
- **Create**: Log new outgoing messages from various features (payment notifications, attendance alerts, etc.)
- **Update**: Update message status (delivered, read, failed) from webhooks
- **Delete**: Remove old logs (admin cleanup)

Without proper security rules, all these operations were being blocked by Firestore's default deny-all policy.

## Solution
Added comprehensive Firestore security rules for the `communicationLogs` collection:

```javascript
// COMMUNICATION LOGS (audit trail for all outgoing messages)
match /communicationLogs/{logId} {
  // Admin and staff can read all communication logs for their school
  allow read: if isSignedIn() && (isSuperAdmin() || (belongsToSchool(schoolId) && (isAdmin() || isStaff())));
  // Any authenticated user from the school can create logs (automated systems)
  allow create: if isSignedIn() && belongsToSchool(schoolId);
  // Only admin can update logs (e.g., status updates from webhooks)
  allow update: if isSignedIn() && (isSuperAdmin() || (isAdmin() && belongsToSchool(schoolId)));
  // Only admin can delete logs
  allow delete: if isSignedIn() && (isSuperAdmin() || (isAdmin() && belongsToSchool(schoolId)));
}
```

### Permissions Breakdown

#### Read Access
- ✅ **Super Admin**: Can read all logs across all schools
- ✅ **Admin**: Can read all logs for their school
- ✅ **Staff**: Can read all logs for their school (useful for teachers to see communication history)
- ❌ **Others**: Cannot read logs

#### Create Access
- ✅ **Any authenticated user from the school**: Can create logs
  - This is intentionally permissive to allow automated systems (payment notifications, attendance alerts, etc.) to log messages
  - The `belongsToSchool(schoolId)` check ensures users can only create logs for their own school

#### Update Access
- ✅ **Super Admin**: Can update any log
- ✅ **Admin**: Can update logs for their school
  - Needed for webhook status updates (delivered, read, failed)
- ❌ **Staff/Others**: Cannot update logs

#### Delete Access
- ✅ **Super Admin**: Can delete any log
- ✅ **Admin**: Can delete logs for their school
  - Useful for cleanup of old logs
- ❌ **Staff/Others**: Cannot delete logs

## Security Features

1. **School Isolation**: All rules enforce `belongsToSchool(schoolId)` to ensure users can only access data from their own school
2. **Role-Based Access**: Different permissions for Super Admin, Admin, and Staff roles
3. **Audit Trail Protection**: Only admins can modify or delete logs, preventing tampering
4. **Automated Logging**: Any authenticated school user can create logs, enabling automated systems to function
5. **Read Access for Staff**: Staff can view communication logs, useful for transparency and tracking

## Collections Used
- `schools/{schoolId}/communicationLogs/{logId}` - Communication audit trail

### Log Entry Structure
Each log entry contains:
- **Recipient Info**: name, phone, email, type (parent/staff/student)
- **Message Content**: subject, message body
- **Metadata**: purpose (fee reminder, payment receipt, attendance, etc.), channel (WhatsApp, SMS, email)
- **Status**: pending, sent, delivered, read, failed
- **Timestamps**: sentAt, deliveredAt, readAt, failedAt
- **Sender Info**: sentByUserId, sentByName
- **Related Entity**: relatedEntityId, relatedEntityType (e.g., studentFeeLedger)
- **Error Info**: errorMessage (if failed)

## Features Using Communication Logs

1. **Payment Notifications**: Fee reminders and payment receipts sent via WhatsApp
2. **Attendance Alerts**: Daily attendance notifications to parents
3. **Leave Updates**: Leave approval/rejection notifications
4. **Announcements**: School-wide announcements
5. **Custom Messages**: Ad-hoc messages from admin panel

## Deployment
The rules have been deployed to Firebase using:
```bash
firebase deploy --only firestore:rules
```

## Testing
After deployment, the Communication Logs screen should work correctly for:
- ✅ Admin users can view all logs with filters and pagination
- ✅ Staff users can view all logs for their school
- ✅ Automated systems can create new log entries
- ✅ Webhook handlers can update message status
- ✅ Admins can delete old logs

## Related Files
- `firestore.rules` - Security rules (lines 582-592)
- `lib/presentation/admin/screens/communication_logs_screen.dart` - UI screen
- `lib/data/repositories/communication_log_repository.dart` - Data access layer
- `lib/domain/entities/communication_log.dart` - Entity definition
- `lib/presentation/finance/widgets/multi_allocation_payment_dialog.dart` - Example usage (payment notifications)
