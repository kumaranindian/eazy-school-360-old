# Eazy School 360 - User Manual

## Table of Contents
1. [Getting Started](#getting-started)
2. [Login & Authentication](#login--authentication)
3. [Dashboard Overview](#dashboard-overview)
4. [Staff Management](#staff-management)
5. [Leave Management](#leave-management)
6. [Permission Management](#permission-management)
7. [Settings & Configuration](#settings--configuration)
8. [Troubleshooting](#troubleshooting)

---

## Getting Started

### System Requirements
- **Web Browser**: Chrome, Firefox, Safari, or Edge (latest versions)
- **Mobile**: Android 5.0+ or iOS 12.0+
- **Internet Connection**: Required for all operations

### Accessing the Application
1. Open your web browser
2. Navigate to the application URL
3. You will see the login screen

---

## Login & Authentication

### Logging In

1. **Enter Email**: Type your registered email address
2. **Enter Password**: Type your password
3. **Click "Sign In"**: Press the login button

![Login Screen]

### First-Time Login
If this is your first time logging in:
1. Use the temporary password provided by your administrator
2. You may be prompted to change your password
3. Complete your profile information if required

### Forgot Password
1. Click "Forgot Password?" on the login screen
2. Enter your registered email address
3. Check your email for password reset instructions
4. Follow the link to create a new password

### Logging Out
1. Click on your profile icon in the top-right corner
2. Select "Logout" from the dropdown menu
3. You will be redirected to the login screen

---

## Dashboard Overview

After logging in, you will see the dashboard with key information at a glance.

### Admin Dashboard

The Admin Dashboard displays:

| Card | Description |
|------|-------------|
| **Total Staff** | Number of active staff members |
| **Pending Leaves** | Leave applications awaiting approval |
| **Pending Permissions** | Permission requests awaiting approval |
| **On Leave Today** | Staff members on leave today |

### Staff Dashboard

The Staff Dashboard displays real-time data from Firebase:

| Section | Description |
|---------|-------------|
| **Leave Balances** | Your current leave balance for each leave type (Casual, Sick, Earned, etc.) |
| **Quick Actions** | Shortcuts to apply leave, request permission, view history |
| **Recent Requests** | Your recent leave and permission requests with status |

#### Leave Balance Cards
Each leave type shows:
- **Available**: Remaining days you can use
- **Total**: Annual quota for the leave type
- **Progress Bar**: Visual indicator of usage

#### Recent Requests
Shows your last 5 combined leave and permission requests with:
- Request type (Leave type name or "Permission")
- Date or date range
- Current status (Pending, Approved, Rejected)

### Navigation Menu

**Desktop View (Sidebar)**:
- Dashboard
- Staff Management
- Leave Requests
- Leave Policy
- Permission Policy

**Mobile View (Bottom Navigation)**:
- Dashboard
- Staff
- Leaves
- Settings

---

## Staff Management

### Viewing Staff List

1. Click **"Staff Management"** in the navigation menu
2. View the list of all staff members
3. Use filters to narrow down the list:
   - **Status**: Active / Disabled
   - **Staff Type**: Teaching / Non-Teaching
   - **Department**: Filter by department

### Adding New Staff

1. Click the **"+ Add Staff"** button
2. Complete the **3-step form**:

**Step 1: Basic Information**
| Field | Required | Description |
|-------|:--------:|-------------|
| Full Name | ✅ | Staff member's full name |
| Employee ID | ❌ | Leave empty for auto-generation (e.g., ES360001) |
| Email Address | ✅ | Valid email for login credentials |

**Step 2: Role & Department**
| Field | Required | Description |
|-------|:--------:|-------------|
| Role | ✅ | Staff or Admin |
| Staff Type | ✅ | Teaching or Non-Teaching |
| Department | ✅ | Department name |
| Designation | ❌ | Job title |
| Joining Date | ✅ | Date of joining |

**Step 3: Contact Information**
| Field | Required | Description |
|-------|:--------:|-------------|
| Phone Number | ✅ | Contact number |
| Address | ✅ | Residential address |
| Emergency Contact | ✅ | Emergency contact details |

3. Click **"Submit"** to create the staff member
4. The staff member will receive login credentials via email

### Editing Staff

1. Find the staff member in the list
2. Click the **Edit** icon (pencil) or staff name
3. Modify the required fields
4. Click **"Save Changes"**

### Deactivating Staff

1. Find the staff member in the list
2. Click the **More Options** menu (three dots)
3. Select **"Deactivate"**
4. Confirm the action

> **Note**: Deactivated staff cannot log in but their data is preserved.

---

## Leave Management

### For Staff Members

#### Applying for Leave

1. Navigate to **"Apply Leave"** section
2. Fill in the leave application form:

| Field | Description |
|-------|-------------|
| Leave Type | Select from available leave types |
| Start Date | First day of leave |
| End Date | Last day of leave |
| Reason | Reason for leave request |
| Remarks | Additional notes (optional) |

3. Review the calculated working days
4. Click **"Submit Application"**

#### Viewing Leave Balance

1. Go to your **Dashboard** or **Leave Balance** section
2. View available balance for each leave type:
   - **Total Allowed**: Annual quota
   - **Used**: Days already taken
   - **Pending**: Days in pending requests
   - **Available**: Remaining balance

#### Viewing Leave History

1. Navigate to **"My Leaves"** section
2. View all your leave applications
3. Filter by status: Pending, Approved, Rejected, Cancelled

#### Cancelling Leave

1. Find the pending leave application
2. Click **"Cancel"** button
3. Confirm the cancellation

> **Note**: Only pending leaves can be cancelled.

---

### For Administrators

#### Viewing Leave Requests

1. Navigate to **"Leave Requests"** in the menu
2. View all leave applications from staff
3. Use tabs to filter:
   - **Pending**: Awaiting approval
   - **Approved**: Approved leaves
   - **Rejected**: Rejected leaves
   - **All**: All applications

#### Approving Leave

1. Find the pending leave request
2. Review the details:
   - Staff name and department
   - Leave type and dates
   - Reason for leave
   - Current leave balance
3. Click **"Approve"** button
4. Add remarks if needed
5. Confirm approval

#### Rejecting Leave

1. Find the pending leave request
2. Click **"Reject"** button
3. **Enter rejection reason** (required)
4. Confirm rejection

> **Important**: Always provide a clear reason for rejection.

---

## Leave Policy Configuration

### Viewing Leave Types

1. Navigate to **"Leave Policy"** in settings
2. View all configured leave types with:
   - Name and code
   - Annual quota
   - Carry forward settings
   - Paid/unpaid status

### Adding New Leave Type

1. Click **"+ Add Leave Type"** button
2. Fill in the configuration:

| Field | Description |
|-------|-------------|
| Leave Type Name | Display name (e.g., "Casual Leave") |
| Code | Short code (e.g., "CL") |
| Annual Quota | Total days per year |
| Max Days/Request | Maximum days per single request |
| Description | Optional description |
| Paid Leave | Toggle on/off |
| Carry Forward | Toggle on/off |

3. Click **"Add Leave Type"**

### Editing Leave Type

1. Find the leave type in the list
2. Click **Edit** icon
3. Modify the settings
4. Save changes

### Deleting Leave Type

1. Find the leave type
2. Click **Delete** icon
3. Confirm deletion

> **Warning**: Deleting a leave type may affect existing balances.

---

## Permission Management

### Permission Types

Permission types define short-duration absences (hours, not days):
- Medical Appointment
- Personal Emergency
- Late Arrival
- Early Departure

### Configuring Permission Types

1. Navigate to **"Permission Policy"**
2. Add new permission type:

| Field | Description |
|-------|-------------|
| Permission Type Name | Name of permission |
| Max Hours | Maximum hours allowed |
| Frequency | Daily, Weekly, Monthly, Yearly |
| Requires Approval | Toggle on/off |
| Deductible | Deduct from salary/leave |
| Description | Optional description |

3. Click **"Add Permission Type"**

---

## Settings & Configuration

### School Settings

Administrators can configure:
- **Timezone**: School timezone
- **Currency**: Currency for financial calculations
- **Working Days**: Select working days of the week
- **Max Leave Carry Forward**: Maximum days that can be carried to next year

### Academic Year

The system uses academic year for leave calculations:
- Academic year runs from **June 1** to **May 31**
- Leave balances reset at the start of each academic year
- Carry forward is calculated automatically

---

## Troubleshooting

### Common Issues

#### Cannot Login
- **Check email**: Ensure you're using the correct email
- **Check password**: Verify password is correct
- **Account disabled**: Contact your administrator
- **Clear browser cache**: Try clearing cookies and cache

#### Leave Balance Shows 0
- **New staff**: Balance is initialized when staff is created
- **New academic year**: Balance resets at year start
- **Contact admin**: Ask administrator to verify balance

#### Cannot Submit Leave Application
- **Insufficient balance**: Check available balance
- **Date conflict**: Check for overlapping leaves
- **Past dates**: Cannot apply for past dates
- **Weekend/holiday**: Selected dates may be non-working days

#### Page Not Loading
- **Check internet**: Verify internet connection
- **Refresh page**: Press F5 or click refresh
- **Clear cache**: Clear browser cache and cookies
- **Try different browser**: Test with another browser

### Error Messages

| Error | Solution |
|-------|----------|
| "Permission Denied" | You don't have access to this feature. Contact admin. |
| "Session Expired" | Log in again |
| "Network Error" | Check internet connection |
| "Invalid Credentials" | Verify email and password |

### Getting Help

If you encounter issues not covered here:
1. Note the error message
2. Take a screenshot if possible
3. Contact your school administrator
4. Provide details about what you were trying to do

---

## Quick Reference

### Keyboard Shortcuts (Web)

| Shortcut | Action |
|----------|--------|
| Enter | Submit form |
| Escape | Close dialog |
| Tab | Navigate between fields |

### Status Colors

| Color | Meaning |
|-------|---------|
| 🟢 Green | Active / Approved |
| 🟡 Yellow/Orange | Pending |
| 🔴 Red | Rejected / Disabled |
| 🔵 Blue | Information |

### Leave Status Flow

```
PENDING → APPROVED → (Leave Taken)
    ↓
REJECTED
    ↓
CANCELLED (by applicant)
```

---

## Glossary

| Term | Definition |
|------|------------|
| **Academic Year** | June 1 to May 31 of the following year |
| **Annual Quota** | Total leave days allowed per year |
| **Carry Forward** | Unused leave days transferred to next year |
| **Employee ID** | Unique identifier for staff (auto-generated) |
| **Leave Balance** | Available leave days for a staff member |
| **Multi-tenant** | Multiple schools using the same system independently |
| **Working Days** | Days excluding weekends and holidays |

---

---

## My Profile

### Viewing Your Profile

1. Click on **"My Profile"** in the navigation menu
2. View your profile information:
   - **Profile Card**: Photo, name, designation, department
   - **Contact Information**: Email, Employee ID, phone, address, emergency contact
   - **Employment Details**: Staff type, joining date, status

### Editing Your Profile

1. Click the **Edit** icon in the header
2. Modify editable fields:
   - Phone Number
   - Address
   - Emergency Contact
3. Click **"Save Changes"** to update

> **Note**: Some fields like Email and Employee ID cannot be edited. Contact your administrator for changes.

---

*User Manual for Eazy School 360 v1.1.0*
*Last Updated: February 2026*
