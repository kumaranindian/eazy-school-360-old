# WhatsApp Integration Guide

## Overview

This document describes the production-ready WhatsApp notification system for Eazy School 360. The system uses Meta's WhatsApp Business Cloud API to send:

1. **Fee Due Reminders** - Automated reminders to parents when fees are due
2. **Payment Confirmations** - Instant notifications when payments are received
3. **Admin Summaries** - Daily collection reports to school administrators

## Architecture

### Components

1. **WhatsAppService** (`lib/core/services/whatsapp_service.dart`)
   - Core service for sending WhatsApp messages
   - Handles API communication with Meta's WhatsApp Business API
   - Manages phone number formatting and validation
   - Logs all notifications for audit trail

2. **Cloud Functions** (`functions/src/whatsapp-fee-reminders.js`)
   - `sendFeeDueReminders` - Scheduled daily at 9:00 AM IST
   - `sendDailyCollectionSummary` - Scheduled daily at 6:00 PM IST
   - Includes rate limiting and error handling

3. **Admin Configuration** (`lib/presentation/admin/screens/whatsapp_settings_screen.dart`)
   - UI for configuring WhatsApp credentials
   - Admin phone number management
   - Test configuration functionality

## Setup Instructions

### 1. Meta WhatsApp Business API Setup

1. **Create Meta Business Account**
   - Go to [business.facebook.com](https://business.facebook.com)
   - Create a new business account or use existing

2. **Set up WhatsApp Business API**
   - Navigate to [developers.facebook.com](https://developers.facebook.com)
   - Create a new app or use existing
   - Add "WhatsApp" product to your app
   - Complete the setup wizard

3. **Get Credentials**
   - **Access Token**: From App Dashboard > WhatsApp > API Setup
   - **Phone Number ID**: From WhatsApp > API Setup > Phone Numbers
   - **Business Account ID**: From Business Settings

4. **Create Message Templates**
   
   You need to create and get approved the following templates in Meta Business Manager:

   #### Fee Due Reminder Template
   ```
   Name: fee_due_reminder
   Category: UTILITY
   Language: English
   
   Body:
   Dear Parent,
   
   This is a reminder that {{1}}'s {{2}} fee of {{3}} is due on {{4}}.
   
   Please make the payment at your earliest convenience to avoid late fees.
   
   Thank you!
   ```

   #### Payment Confirmation Template
   ```
   Name: payment_confirmation
   Category: UTILITY
   Language: English
   
   Body:
   Dear Parent,
   
   Payment received for {{1}}.
   
   Amount Paid: {{2}}
   Receipt No: {{3}}
   Date: {{4}}
   Balance Due: {{5}}
   
   Thank you for your payment!
   ```

   #### Admin Daily Summary Template
   ```
   Name: admin_daily_summary
   Category: UTILITY
   Language: English
   
   Body:
   Daily Fee Collection Summary - {{1}}
   
   Total Collected: {{2}}
   Number of Transactions: {{3}}
   
   Login to the admin portal for detailed reports.
   ```

### 2. Firebase Configuration

1. **Install Dependencies**
   ```bash
   cd functions
   npm install axios
   ```

2. **Deploy Cloud Functions**
   ```bash
   firebase deploy --only functions:sendFeeDueReminders,functions:sendDailyCollectionSummary
   ```

3. **Set up Firestore Security Rules**
   
   Add to `firestore.rules`:
   ```
   match /schools/{schoolId}/settings/whatsapp {
     allow read: if isSchoolAdmin(schoolId);
     allow write: if isSchoolAdmin(schoolId);
   }
   
   match /schools/{schoolId}/whatsappNotifications/{notificationId} {
     allow read: if isSchoolAdmin(schoolId);
     allow create: if true; // Allow system to create logs
   }
   ```

### 3. Application Configuration

1. **Navigate to WhatsApp Settings**
   - Login as admin
   - Go to Settings > WhatsApp Configuration

2. **Enter Credentials**
   - Access Token (from Meta)
   - Phone Number ID (from Meta)
   - Template names (must match approved templates)

3. **Configure Admin Numbers**
   - Add admin phone numbers in E.164 format (+919876543210)
   - These numbers will receive daily summaries

4. **Test Configuration**
   - Enter a test phone number
   - Click "Test" to send a test message
   - Verify message is received

5. **Enable Service**
   - Toggle "Enabled" switch
   - Click "Save Settings"

## Usage

### Automatic Fee Reminders

The system automatically sends reminders for:

1. **Due Today** - Sent on the due date at 9:00 AM
2. **Due in 3 Days** - Advance reminder sent 3 days before due date
3. **Overdue** - Sent every 7 days for overdue fees

### Payment Notifications

When a payment is recorded:

1. Parent receives instant WhatsApp confirmation
2. Includes payment amount, receipt number, and balance
3. Sent automatically from payment screen

### Admin Summaries

Daily at 6:00 PM:

1. All configured admin numbers receive summary
2. Includes total collection and transaction count
3. Covers all payments for that day

## Integration Points

### 1. Payment Recording

Add to `term_fee_payment_repository.dart` after successful payment:

```dart
// Send WhatsApp payment confirmation
final whatsappService = WhatsAppService();
await whatsappService.sendPaymentConfirmation(
  schoolId: schoolId,
  phoneNumber: parentPhone,
  studentName: studentName,
  paidAmount: amount,
  receiptNumber: receiptNumber,
  paymentDate: DateTime.now(),
  balanceAmount: remainingBalance,
);
```

### 2. Manual Reminders

Add button in fee management screen:

```dart
ElevatedButton(
  onPressed: () async {
    final whatsappService = WhatsAppService();
    await whatsappService.sendFeeDueReminder(
      schoolId: schoolId,
      phoneNumber: parentPhone,
      studentName: studentName,
      dueAmount: balance,
      dueDate: dueDate,
      termName: termName,
    );
  },
  child: Text('Send Reminder'),
)
```

## Phone Number Format

All phone numbers must be in E.164 format:
- Include country code with + prefix
- Example: +919876543210 (India)
- The system auto-formats Indian numbers (adds +91 if missing)

## Rate Limiting

- Cloud Functions: 100ms delay between messages
- Prevents API throttling
- Ensures reliable delivery

## Monitoring

### View Notification History

Query Firestore:
```dart
final notifications = await FirebaseFirestore.instance
  .collection('schools')
  .doc(schoolId)
  .collection('whatsappNotifications')
  .orderBy('sentAt', descending: true)
  .limit(100)
  .get();
```

### Check Logs

Cloud Functions logs:
```bash
firebase functions:log --only sendFeeDueReminders
firebase functions:log --only sendDailyCollectionSummary
```

## Troubleshooting

### Messages Not Sending

1. **Check Configuration**
   - Verify Access Token is valid
   - Confirm Phone Number ID is correct
   - Ensure templates are approved

2. **Check Phone Numbers**
   - Must be in E.164 format
   - Must be opted-in to receive messages
   - Cannot send to landlines

3. **Check Template Names**
   - Must exactly match approved template names
   - Case-sensitive

4. **Check Quotas**
   - Meta has daily message limits
   - Check Business Manager for quota status

### Test Message Fails

1. Use Meta's default "hello_world" template first
2. Verify credentials in Meta Business Manager
3. Check phone number is registered with WhatsApp
4. Review Cloud Functions logs for errors

## Security Best Practices

1. **Access Token**
   - Store securely in Firestore
   - Never commit to version control
   - Rotate periodically

2. **Phone Numbers**
   - Validate before storing
   - Encrypt sensitive data
   - Comply with data protection regulations

3. **Rate Limiting**
   - Implemented to prevent abuse
   - Monitor usage patterns
   - Set up alerts for unusual activity

## Cost Considerations

Meta WhatsApp Business API pricing (as of 2024):

- **Utility Messages**: ~$0.005 - $0.01 per message (India)
- **Marketing Messages**: Higher rates
- **Free Tier**: 1,000 conversations/month

Estimate monthly costs:
- 500 students × 3 reminders/month = 1,500 messages
- 500 payments × 1 confirmation = 500 messages
- 30 days × 5 admins = 150 summaries
- **Total**: ~2,150 messages/month ≈ $15-20/month

## Support

For issues or questions:
1. Check Meta WhatsApp Business API documentation
2. Review Cloud Functions logs
3. Check Firestore notification logs
4. Contact Meta Business Support for API issues

## Future Enhancements

Potential improvements:
1. Multi-language support
2. Rich media messages (PDFs, images)
3. Interactive buttons
4. Chatbot for FAQs
5. Bulk messaging for announcements
6. Parent opt-in/opt-out management
