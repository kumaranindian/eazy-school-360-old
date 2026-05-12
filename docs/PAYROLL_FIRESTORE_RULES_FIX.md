# Payroll Firestore Rules Fix

## Issue
The payroll management screen was showing Firestore permission errors for admin users because the Firestore security rules were missing proper rules for the payroll collections.

## Root Cause
The application uses two collections for payroll management:
1. `schools/{schoolId}/payrollConfig/{staffId}` - Stores salary configuration for each staff member
2. `schools/{schoolId}/payrollRecords/{recordId}` - Stores monthly processed payroll records

However, the Firestore rules only had a legacy rule for `schools/{schoolId}/payroll/{payrollId}` which was not being used by the current implementation.

## Solution
Added proper Firestore security rules for both payroll collections:

### Payroll Config Rules (`payrollConfig`)
```javascript
match /payrollConfig/{staffId} {
  // Admin can read all configs
  allow read: if isSignedIn() && (isSuperAdmin() || (isAdmin() && belongsToSchool(schoolId)));
  // Only admin can create/update/delete payroll configs
  allow create, update: if isSignedIn() && isActive() && (isSuperAdmin() || (isAdmin() && belongsToSchool(schoolId)));
  allow delete: if isSignedIn() && isActive() && (isSuperAdmin() || (isAdmin() && belongsToSchool(schoolId)));
}
```

**Permissions:**
- **Read**: Super Admin or Admin of the school
- **Write**: Super Admin or Active Admin of the school
- **Delete**: Super Admin or Active Admin of the school

### Payroll Records Rules (`payrollRecords`)
```javascript
match /payrollRecords/{recordId} {
  // Admin can read all records, Staff can read only their approved/paid records
  allow read: if isSignedIn() && (
    isSuperAdmin() || 
    (isAdmin() && belongsToSchool(schoolId)) ||
    // Staff can read their own approved/paid payroll records
    (isStaff() && belongsToSchool(schoolId) && (
      resource.data.userId == request.auth.uid &&
      (resource.data.status == 'APPROVED' || resource.data.status == 'PAID')
    ))
  );
  // Only admin can create/update payroll records
  allow create, update: if isSignedIn() && isActive() && (isSuperAdmin() || (isAdmin() && belongsToSchool(schoolId)));
  // Only admin can delete payroll records
  allow delete: if isSignedIn() && isActive() && (isSuperAdmin() || (isAdmin() && belongsToSchool(schoolId)));
}
```

**Permissions:**
- **Read**: 
  - Super Admin (all records)
  - Admin of the school (all records)
  - Staff members (only their own APPROVED or PAID records)
- **Write**: Super Admin or Active Admin of the school
- **Delete**: Super Admin or Active Admin of the school

## Security Features

1. **Admin-Only Configuration**: Only admins can configure salary structures, preventing unauthorized salary modifications
2. **Staff Privacy**: Staff members can only view their own approved/paid payslips, not draft or processed records
3. **Status-Based Access**: Staff can only see payroll records with status 'APPROVED' or 'PAID', ensuring they don't see pending or rejected records
4. **School Isolation**: All rules enforce `belongsToSchool(schoolId)` to ensure users can only access data from their own school
5. **Active User Check**: Write operations require `isActive()` to ensure only active users can modify data

## Deployment
The rules have been deployed to Firebase using:
```bash
firebase deploy --only firestore:rules
```

## Testing
After deployment, the payroll management screen should work correctly for admin users without any permission errors. Staff members can view their payslips from the "My Payslips" screen.

## Collections Used
- `schools/{schoolId}/payrollConfig/{staffId}` - Salary configuration per staff
- `schools/{schoolId}/payrollRecords/{recordId}` - Monthly payroll records
- `schools/{schoolId}/staff/{staffId}` - Staff profiles (already had proper rules)
- `schools/{schoolId}/leaveTypes/{leaveTypeId}` - Leave type configurations (already had proper rules)
- `schools/{schoolId}/leaves/{leaveId}` - Leave applications (already had proper rules)
- `schools/{schoolId}/leaveBalances/{balanceId}` - Leave balances (already had proper rules)
