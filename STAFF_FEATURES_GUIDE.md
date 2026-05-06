# Staff Dashboard Features Guide

## Quick Navigation Reference

### Staff Dashboard Navigation Menu

```
📊 Dashboard (Index 0)
   ├── Welcome Banner
   ├── Leave Balances (Cards showing remaining days)
   ├── Permission Overview (Monthly usage)
   ├── Quick Actions
   └── Today's Info

📝 Apply Leave (Index 1)
   ├── Select Leave Type
   ├── Choose Date Range
   ├── Enter Reason
   └── Submit Application

⏰ Request Permission (Index 2)
   ├── Select Permission Type
   ├── Choose Date & Time
   ├── Enter Reason
   └── Submit Request

👤 My Profile (Index 3)
   └── View/Edit Profile Information

📋 My Leaves (Index 4)
   ├── View All Leave Applications
   ├── See Status (Pending/Approved/Rejected)
   └── Cancel Pending Leaves

✅ My Permissions (Index 5)
   ├── View All Permission Requests
   ├── See Status (Pending/Approved/Rejected)
   └── Cancel Pending Permissions

📅 Holiday Calendar (Index 6)
   └── View School Holidays

💰 My Payslips (Index 7)
   └── View Salary Slips

🎓 Student Leaves (Index 8)
   └── Manage Class Students' Leaves (Class Teachers)

📂 Leave Types (Index 9) ⭐ NEW
   ├── View All Configured Leave Types
   ├── See Annual Quotas
   ├── Check Paid/Unpaid Status
   └── View Carry Forward Rules

📋 Permission Types (Index 10) ⭐ NEW
   ├── View All Configured Permission Types
   └── See Default Limits
```

## Feature Details

### 1. View Leave Types (NEW)
**Purpose**: See what types of leaves are available and their rules

**Information Displayed**:
- Leave Type Name (e.g., "Casual Leave", "Sick Leave")
- Leave Code (e.g., "CL", "SL")
- Annual Quota (e.g., "12 days/year")
- Paid or Unpaid status
- Carry Forward eligibility
- Maximum days per request
- Description

**Example Card**:
```
┌─────────────────────────────────────────┐
│ 📝 Casual Leave                         │
│                                         │
│ For personal matters and emergencies    │
│                                         │
│ [CL] [12 days/year] [Paid]             │
│ [Carry Forward] [Max 3 days/request]   │
└─────────────────────────────────────────┘
```

### 2. View Permission Types (NEW)
**Purpose**: See what types of permissions you can request

**Information Displayed**:
- Permission Type Name (e.g., "Medical Appointment", "Personal Work")
- Default Limit (e.g., "5 times")
- Active Status

**Example Card**:
```
┌─────────────────────────────────────────┐
│ ⏰ Medical Appointment                  │
│                                         │
│ [Default: 5 times] [Active]            │
└─────────────────────────────────────────┘
```

### 3. Apply for Leave
**Purpose**: Request time off from work

**Steps**:
1. Select leave type from dropdown
2. Choose start date
3. Choose end date
4. System calculates working days
5. Enter reason for leave
6. Add any additional remarks (optional)
7. Submit application

**Validations**:
- Checks if you have sufficient balance
- Excludes weekends and holidays
- Validates date range
- Ensures reason is provided

### 4. Request Permission
**Purpose**: Request short-time permission during work hours

**Steps**:
1. Select permission type from dropdown
2. Choose date
3. Select start time
4. Select end time
5. System calculates duration
6. Enter reason for permission
7. Add any additional remarks (optional)
8. Submit request

**Validations**:
- Checks monthly limit
- Validates time range
- Ensures reason is provided

## Admin Approval Process

### For Admins

**Leave Approval Screen**:
```
Admin Dashboard → Leave Requests
├── View All Pending Leave Applications
├── See Staff Details
├── Review Leave Type and Dates
├── Check Balance
├── Approve or Reject
└── Add Rejection Reason (if rejecting)
```

**Permission Approval Screen**:
```
Admin Dashboard → Permissions
├── View All Pending Permission Requests
├── See Staff Details
├── Review Permission Type and Time
├── Approve or Reject
└── Add Rejection Reason (if rejecting)
```

## Status Flow

### Leave Application Status
```
Staff Submits → [Pending] → Admin Reviews
                    ↓
              ┌─────┴─────┐
              ↓           ↓
         [Approved]  [Rejected]
```

### Permission Request Status
```
Staff Submits → [Pending] → Admin Reviews
                    ↓
              ┌─────┴─────┐
              ↓           ↓
         [Approved]  [Rejected]
```

## Color Coding

- 🟢 **Green (#4CAF50)**: Success, Available Balance, Staff Theme
- 🔵 **Blue (#3B82F6)**: Leave-related items
- 🟣 **Purple (#8B5CF6)**: Permission-related items
- 🟡 **Amber (#F59E0B)**: Warnings, Unpaid Leaves
- 🟢 **Emerald (#10B981)**: Approved Status
- 🔴 **Red**: Rejected Status, Errors
- ⚪ **Gray**: Pending Status

## Quick Tips

### For Staff
1. **Check Leave Types First**: Before applying for leave, check the "Leave Types" section to understand available options and quotas
2. **Check Permission Types**: Review "Permission Types" to see what permissions you can request
3. **Monitor Your Balance**: Dashboard shows your current leave balance for each type
4. **Track Usage**: Permission overview shows how many times you've used each permission type this month
5. **Cancel if Needed**: You can cancel pending applications from "My Leaves" or "My Permissions"

### For Admins
1. **Configure First**: Set up leave types and permission types before staff can use them
2. **Review Regularly**: Check pending approvals daily
3. **Provide Feedback**: Add clear rejection reasons when denying requests
4. **Monitor Trends**: Use the dashboard to see overall leave and permission usage

## Troubleshooting

### "No Leave Types Configured"
- **Solution**: Contact your administrator to configure leave types
- **Admin Action**: Go to Admin Dashboard → Leave Types → Add Leave Types

### "No Permission Types Configured"
- **Solution**: Contact your administrator to configure permission types
- **Admin Action**: Go to Admin Dashboard → Permission Types → Add Permission Types

### "Insufficient Balance"
- **Cause**: You don't have enough leave days remaining
- **Solution**: Check your balance on the dashboard or choose a different leave type

### "Permission Limit Exceeded"
- **Cause**: You've used all allowed permissions for this month
- **Solution**: Wait for next month or contact admin for special approval

## Best Practices

### When Applying for Leave
1. Apply well in advance
2. Provide clear and concise reasons
3. Check team calendar to avoid conflicts
4. Ensure handover of responsibilities
5. Update your out-of-office status

### When Requesting Permission
1. Request as early as possible
2. Keep permissions brief and necessary
3. Inform your team
4. Complete urgent tasks before leaving
5. Be available via phone if needed

## Support

For any issues or questions:
1. Check this guide first
2. Contact your HR department
3. Reach out to system administrator
4. Report bugs to IT support

---

**Last Updated**: Implementation Date
**Version**: 1.0
**Maintained By**: Development Team
