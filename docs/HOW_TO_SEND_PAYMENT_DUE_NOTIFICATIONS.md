# How to Send Payment Due Notifications

## Quick Guide for Admin Users

### Step 1: Login as Admin
Login to the application with your admin credentials.

### Step 2: Navigate to Student Ledgers
From the admin dashboard sidebar, click on:
```
Students → Student Ledgers & Payments
```

**Location:** Left sidebar under "Students" section

**Icon:** 💰 Wallet icon

### Step 3: View Students with Fee Status
You'll see all students with their fee information:
- **Green Status:** Fees cleared, no pending amount
- **Orange Status:** Payment pending

Each student card shows:
- Student name and ID
- Class and section
- Total assigned fees
- Amount paid
- Amount pending

### Step 4: Send Individual Notification

**For a single student:**
1. Find the student with pending fees (orange status)
2. Click the **"Send Due"** button (orange button on the right)
3. Confirm in the dialog that appears
4. Notification will be sent to parent's phone number

### Step 5: Send Bulk Notifications

**For all students with pending fees:**
1. Click the **"Send Payment Due Alerts"** button at the top right
2. Review the count of students who will receive notifications
3. Click **"Send All"** to confirm
4. Wait for the process to complete
5. You'll see a success message with the count

## Filters Available

### Search:
- Search by student name
- Search by student ID
- Search by parent name
- Search by parent phone

### Filter by Class:
- Select specific class from dropdown
- Shows students from that class only

### Filter by Section:
- Available after selecting a class
- Select specific section

### Filter by Payment Status:
- **All Status:** Shows all students
- **Pending Fees:** Shows only students with pending payments
- **Fees Cleared:** Shows only students with no pending fees

## Features

### Individual Notification:
- ✅ Sends to specific parent
- ✅ Shows pending amount in confirmation
- ✅ Updates last reminder timestamp
- ✅ Shows success/error message

### Bulk Notification:
- ✅ Sends to all filtered students with pending fees
- ✅ Only sends to parents with valid phone numbers
- ✅ Shows progress indicator
- ✅ Reports success/failure count

### View Ledger:
- Click **"View Ledger"** button to see full fee details
- Shows all terms, payments, and history
- View payment breakdown by term

## Screenshots Guide

### 1. Dashboard Navigation
```
┌─────────────────────────────────┐
│ Admin Dashboard                 │
├─────────────────────────────────┤
│ ☰ Menu                          │
│   📊 Dashboard                  │
│   👥 Staff Management           │
│   📅 Leave Requests             │
│   ...                           │
│   ─────────────────────         │
│   👨‍🎓 Students                    │
│     📋 Student Directory         │
│     💰 Student Ledgers ← HERE   │
│     👨‍🏫 Class Teacher Assignment  │
│     ...                         │
└─────────────────────────────────┘
```

### 2. Student Ledgers Screen
```
┌──────────────────────────────────────────────────────────┐
│ 🎓 Student Directory & Ledgers                           │
│ View students with fee ledgers and send payment reminders│
│                                    [Send Payment Due Alerts]│
├──────────────────────────────────────────────────────────┤
│ [Search...] [Class ▼] [Section ▼] [Payment Status ▼] 🔄 │
├──────────────────────────────────────────────────────────┤
│ ┌────────────────────────────────────────────────────┐   │
│ │ 👤 Rahul Kumar                                     │   │
│ │ ID: 1001 • X-A                                     │   │
│ │ ┌──────────────────────────────────────────────┐   │   │
│ │ │ ⚠️ Payment Pending                           │   │   │
│ │ │ Total: ₹50,000  Paid: ₹30,000  Pending: ₹20,000│  │   │
│ │ └──────────────────────────────────────────────┘   │   │
│ │ [View Ledger] [Send Due]                           │   │
│ └────────────────────────────────────────────────────┘   │
│ ┌────────────────────────────────────────────────────┐   │
│ │ 👤 Priya Sharma                                    │   │
│ │ ID: 1002 • X-A                                     │   │
│ │ ┌──────────────────────────────────────────────┐   │   │
│ │ │ ✅ Fees Cleared                              │   │   │
│ │ │ Total: ₹50,000  Paid: ₹50,000  Pending: ₹0  │   │   │
│ │ └──────────────────────────────────────────────┘   │   │
│ │ [View Ledger]                                      │   │
│ └────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────┘
```

## For Staff Users

Staff members can also send payment due notifications for their assigned class students.

### Staff Access:
1. Login as Staff
2. Dashboard → Click **"Student Ledgers"** (green card)
3. View students from your assigned class only
4. Send notifications same way as admin

**Note:** Staff can only see students from their assigned class.

## Troubleshooting

### Issue: "Student Ledgers" option not visible
**Solution:** 
- Refresh the page (F5)
- Logout and login again
- Make sure you're logged in as Admin

### Issue: No students showing
**Solution:**
- Check if students exist in the system
- Check if students have fee ledgers created
- Try removing filters

### Issue: "No parent phone number available"
**Solution:**
- Update student record with parent phone number
- Go to Student Directory → Edit student → Add parent phone

### Issue: Notification not sending
**Solution:**
- Verify parent phone number is valid
- Check internet connection
- Contact support if issue persists

## Important Notes

### Phone Number Format:
- Must include country code (e.g., +918508196981)
- Must be valid mobile number
- Parent must have WhatsApp/SMS enabled

### Notification Content:
Currently shows:
- Student name
- Pending amount
- School name

### Frequency:
- No automatic limit on notifications
- Use responsibly to avoid spamming parents
- Check `lastReminderSentAt` timestamp before resending

### Privacy:
- Only admin and assigned class teachers can send notifications
- Parent phone numbers are protected
- All notifications are logged

## Best Practices

### 1. Filter Before Bulk Send
- Use filters to target specific classes/sections
- Review the count before sending
- Avoid sending to all students unnecessarily

### 2. Check Last Reminder
- View ledger to see when last reminder was sent
- Avoid sending multiple reminders in short time
- Maintain professional communication frequency

### 3. Verify Phone Numbers
- Ensure parent phone numbers are up to date
- Test with a few students first
- Update incorrect numbers promptly

### 4. Monitor Results
- Check success/failure count after bulk send
- Follow up on failed notifications
- Update records as needed

## Support

For technical issues or questions:
1. Check this documentation
2. Contact school admin
3. Reach out to technical support

## Related Documentation

- `STUDENT_LEDGER_ADMIN_FEATURE.md` - Full admin feature details
- `STAFF_PAYMENT_DUE_FEATURE.md` - Staff feature details
- `FIRESTORE_INDEXES_REFERENCE.md` - Database indexes info
