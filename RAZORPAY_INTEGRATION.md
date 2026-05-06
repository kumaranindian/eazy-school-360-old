# Razorpay Payment Gateway Integration

## Overview

This document describes the production-ready Razorpay payment gateway integration for Eazy School 360. The integration allows schools to accept online payments for fees via UPI, Cards, Net Banking, and Wallets.

## Features

✅ **Complete Payment Flow**
- Razorpay checkout integration
- Payment signature verification
- Transaction status tracking
- Automatic fee payment recording

✅ **Transaction Management**
- All transactions stored in Firestore
- Admin can view all transactions
- Filter by status, date range
- Transaction statistics and analytics

✅ **Security**
- Payment signature verification using HMAC SHA256
- Secure API key storage in Firestore
- Role-based access control via Firestore rules
- PCI DSS compliant (handled by Razorpay)

✅ **Admin Features**
- Configure Razorpay settings
- View transaction history
- Transaction analytics dashboard
- Export transaction reports

## Architecture

### Components

1. **Payment Transaction Entity** (`lib/domain/entities/payment_transaction.dart`)
   - Stores all payment details
   - Tracks payment status (INITIATED, SUCCESS, FAILED, PENDING, REFUNDED)
   - Links to student ledger and fee payments

2. **Razorpay Service** (`lib/core/services/razorpay_service.dart`)
   - Handles Razorpay SDK integration
   - Creates payment orders
   - Verifies payment signatures
   - Updates transaction status

3. **Transaction Repository** (`lib/data/repositories/payment_transaction_repository.dart`)
   - CRUD operations for transactions
   - Query transactions by filters
   - Generate transaction statistics

4. **UI Components**
   - `RazorpayPaymentWidget`: Payment initiation widget
   - `PaymentTransactionsScreen`: Admin transaction viewing
   - `RazorpaySettingsScreen`: Admin configuration

## Setup Instructions

### 1. Install Dependencies

```bash
flutter pub get
```

Dependencies added:
- `razorpay_flutter: ^1.3.7`
- `crypto: ^3.0.3`

### 2. Configure Razorpay

1. Create a Razorpay account at https://razorpay.com
2. Navigate to Settings → API Keys in Razorpay Dashboard
3. Generate API keys:
   - **Test Mode**: For testing (no real money)
   - **Live Mode**: For production

4. In the app, navigate to:
   - Admin → Settings → Razorpay Settings
   - Enter Key ID and Key Secret
   - Set Merchant Name
   - (Optional) Add Logo URL
   - Enable Razorpay
   - Save Settings

### 3. Deploy Firestore Rules

The security rules for `payment_transactions` and Razorpay settings are already added to `firestore.rules`.

Deploy them:
```bash
firebase deploy --only firestore:rules
```

### 4. Test the Integration

#### Test Mode Credentials
- **Test Card**: 4111 1111 1111 1111
- **CVV**: Any 3 digits
- **Expiry**: Any future date
- **OTP**: Any 6 digits

#### Test Payment Flow
1. Go to Student Fee Management
2. Click "Make Payment"
3. Select "ONLINE" payment mode
4. Enter amount
5. Click "Pay with Razorpay"
6. Complete test payment

## Usage

### Making a Payment

```dart
// In payment dialog, when user selects ONLINE mode
RazorpayPaymentWidget(
  schoolId: schoolId,
  ledger: studentLedger,
  amount: totalAmount,
  termAllocations: termAllocations,
  onSuccess: () {
    // Refresh ledger
    // Show success message
  },
  onCancel: () {
    // Handle cancellation
  },
)
```

### Viewing Transactions

```dart
// Navigate to transaction screen
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => PaymentTransactionsScreen(
      schoolId: schoolId,
    ),
  ),
);
```

### Configuring Razorpay

```dart
// Navigate to settings screen
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => RazorpaySettingsScreen(
      schoolId: schoolId,
    ),
  ),
);
```

## Database Schema

### Collection: `schools/{schoolId}/payment_transactions`

```javascript
{
  id: string,                    // Auto-generated
  schoolId: string,
  studentId: string,
  studentName: string,
  ledgerId: string,
  academicYear: string,
  
  amount: number,
  gateway: "RAZORPAY" | "MANUAL",
  status: "INITIATED" | "SUCCESS" | "FAILED" | "PENDING" | "REFUNDED",
  method: "CARD" | "UPI" | "NET_BANKING" | "WALLET" | "CASH" | "CHEQUE" | "BANK_TRANSFER" | "OTHER",
  
  razorpayOrderId: string?,
  razorpayPaymentId: string?,
  razorpaySignature: string?,
  
  transactionRef: string?,
  receiptNumber: string?,
  
  metadata: object?,
  errorMessage: string?,
  errorCode: string?,
  
  collectedBy: string?,
  collectedByName: string?,
  
  createdAt: timestamp,
  completedAt: timestamp?,
  refundedAt: timestamp?
}
```

### Collection: `schools/{schoolId}/settings/razorpay`

```javascript
{
  keyId: string,              // Razorpay Key ID
  keySecret: string,          // Razorpay Key Secret (encrypted in production)
  merchantName: string,       // School name
  logoUrl: string?,          // Optional logo
  enabled: boolean           // Enable/disable gateway
}
```

## Security Considerations

### 1. API Key Storage
- Keys stored in Firestore with restricted access
- Only admins can read/write settings
- Consider encrypting keySecret in production

### 2. Payment Verification
- All payments verified using HMAC SHA256 signature
- Signature format: `orderId|paymentId`
- Prevents payment tampering

### 3. Firestore Rules
```javascript
match /payment_transactions/{transactionId} {
  allow read: if isSignedIn() && (isSuperAdmin() || belongsToSchool(schoolId) || isAdminOrFinance());
  allow create: if isSignedIn() && (isSuperAdmin() || ((isTenantAdmin() || isAdmin() || isFinance()) && belongsToSchool(schoolId)));
  allow update: if isSignedIn() && (isSuperAdmin() || ((isTenantAdmin() || isAdmin() || isFinance()) && belongsToSchool(schoolId)));
  allow delete: if isSignedIn() && (isSuperAdmin() || (isTenantAdmin() && belongsToSchool(schoolId)));
}
```

## Payment Flow

```
1. User initiates payment
   ↓
2. Create transaction record (status: INITIATED)
   ↓
3. Open Razorpay checkout
   ↓
4. User completes payment
   ↓
5. Razorpay callback with payment details
   ↓
6. Verify payment signature
   ↓
7. Update transaction (status: SUCCESS)
   ↓
8. Record fee payment in termFeePayments
   ↓
9. Update student ledger
   ↓
10. Send WhatsApp notification (if configured)
```

## Error Handling

### Payment Failures
- Transaction marked as FAILED
- Error code and message stored
- User can retry payment

### Network Issues
- Transaction remains in INITIATED state
- Admin can manually verify and update
- Webhook support for automatic reconciliation (future)

## Analytics

### Available Metrics
- Total transaction count
- Success/failure rate
- Total amount collected
- Gateway-wise breakdown (Razorpay vs Manual)
- Payment method breakdown (UPI, Card, etc.)
- Date range filtering

## Testing Checklist

- [ ] Configure Razorpay with test keys
- [ ] Make test payment with test card
- [ ] Verify payment signature
- [ ] Check transaction record created
- [ ] Verify fee payment recorded
- [ ] Check ledger updated correctly
- [ ] Test payment failure scenario
- [ ] Test payment cancellation
- [ ] Verify admin can view transactions
- [ ] Test transaction filtering
- [ ] Check analytics calculations
- [ ] Test with live keys (small amount)

## Production Deployment

### Pre-deployment
1. Switch to Live API keys in Razorpay Settings
2. Test with small real payment
3. Verify webhook configuration (if using)
4. Set up payment reconciliation process
5. Configure refund policy

### Post-deployment
1. Monitor transaction success rate
2. Set up alerts for failed payments
3. Regular reconciliation with Razorpay dashboard
4. Customer support for payment issues

## Troubleshooting

### Payment Not Initiating
- Check Razorpay is enabled in settings
- Verify API keys are correct
- Check Firestore rules allow transaction creation

### Payment Success But Not Recorded
- Check signature verification
- Verify fee payment recording logic
- Check Firestore write permissions

### Transactions Not Visible
- Check user has admin/finance role
- Verify Firestore rules allow read access
- Check schoolId matches

## Support

For Razorpay-specific issues:
- Razorpay Dashboard: https://dashboard.razorpay.com
- Razorpay Docs: https://razorpay.com/docs
- Support: https://razorpay.com/support

## Future Enhancements

- [ ] Webhook integration for automatic reconciliation
- [ ] Refund processing
- [ ] Partial payment support
- [ ] EMI options
- [ ] Payment links for parents
- [ ] Recurring payments for installments
- [ ] Multiple payment gateway support
- [ ] Payment reminders
- [ ] Automated receipt generation
- [ ] Export transactions to Excel/PDF

## License

This integration is part of Eazy School 360 and follows the same license terms.
