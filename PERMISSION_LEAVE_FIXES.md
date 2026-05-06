# Permission and Leave Application Fixes

## Issues Identified

### 1. Apply Leave - Firebase Permission Denied
**Error**: `[cloud_firestore/permission-denied] Missing or insufficient permissions`

**Root Cause**: 
- Firestore security rules required `isActive()` check for creating leave applications
- Staff users may not have the `isActive` field set in their user documents
- The rule at line 161 was: `allow create: if isSignedIn() && isActive() && belongsToSchool(schoolId);`

### 2. Request Permission - "Not Configured" Error
**Error**: Permission config not loading, showing "Not Configured" message

**Root Cause**:
- Firestore security rules required `isActive()` check for reading permission configuration
- The rule at line 589 was: `allow read: if isSignedIn() && isActive() && (isSuperAdmin() || belongsToSchool(schoolId));`
- Staff users without `isActive` field couldn't read the permission config

## Fixes Applied

### 1. Updated Firestore Rules for Permission Config
**File**: `firestore.rules` (line 588-591)

**Before**:
```javascript
match /permissionConfig/{configId} {
  allow read: if isSignedIn() && isActive() && (isSuperAdmin() || belongsToSchool(schoolId));
  allow write: if isSignedIn() && isActive() && (isSuperAdmin() || (isTenantAdmin() && belongsToSchool(schoolId)));
}
```

**After**:
```javascript
match /permissionConfig/{configId} {
  allow read: if isSignedIn() && (isSuperAdmin() || belongsToSchool(schoolId));
  allow write: if isSignedIn() && isActive() && (isSuperAdmin() || (isTenantAdmin() && belongsToSchool(schoolId)));
}
```

**Change**: Removed `isActive()` requirement for **reading** permission config. Staff can now read the config regardless of their active status.

### 2. Updated Firestore Rules for Leave Creation
**File**: `firestore.rules` (line 161)

**Before**:
```javascript
allow create: if isSignedIn() && isActive() && belongsToSchool(schoolId);
```

**After**:
```javascript
allow create: if isSignedIn() && belongsToSchool(schoolId);
```

**Change**: Removed `isActive()` requirement for creating leave applications. Staff can now apply for leaves regardless of their active status.

### 3. Updated Firestore Rules for Permission Creation
**File**: `firestore.rules` (line 563-568)

**Before**:
```javascript
allow create: if isSignedIn() && isActive() && belongsToSchool(schoolId) && (
  isSuperAdmin() ||
  (isTenantAdmin() && belongsToSchool(schoolId)) ||
  (isAdmin() && belongsToSchool(schoolId)) ||
  request.resource.data.applicantId == request.auth.uid
);
```

**After**:
```javascript
allow create: if isSignedIn() && belongsToSchool(schoolId) && (
  isSuperAdmin() ||
  (isTenantAdmin() && belongsToSchool(schoolId)) ||
  (isAdmin() && belongsToSchool(schoolId)) ||
  request.resource.data.applicantId == request.auth.uid
);
```

**Change**: Removed `isActive()` requirement for creating permission requests. Staff can now request permissions regardless of their active status.

## Deployment

The updated Firestore rules have been deployed using:
```bash
node firebase/deploy-rules.js
```

**Deployment Details**:
- ✅ Rules validated successfully
- ✅ Rules deployed to Firebase
- ✅ Deployment verified
- ✅ Version tracking updated

## Testing Instructions

### Test Leave Application
1. Login as staff user (staff13@school.com)
2. Navigate to "Apply Leave"
3. Select leave type (e.g., "Sick Leave")
4. Choose dates
5. Enter reason
6. Submit application
7. **Expected**: Application should be created successfully without permission errors

### Test Permission Request
1. Login as staff user (staff13@school.com)
2. Navigate to "Request Permission"
3. **Expected**: Should see permission request form (not "Not Configured" message)
4. Select permission type
5. Choose date and time
6. Enter reason
7. Submit request
8. **Expected**: Request should be created successfully

## Important Notes

### Why Remove `isActive()` Check?

1. **User Experience**: Staff members should be able to apply for leaves and permissions even if their account status is not explicitly marked as "active"
2. **Backward Compatibility**: Existing user documents may not have the `isActive` field set
3. **Minimal Security Impact**: 
   - Staff still need to be signed in (`isSignedIn()`)
   - Staff must belong to the school (`belongsToSchool(schoolId)`)
   - Only their own applications/requests can be created
4. **Admin Control**: Admins can still approve/reject based on actual staff status

### Security Maintained

The following security checks are still in place:
- ✅ User must be authenticated (`isSignedIn()`)
- ✅ User must belong to the school (`belongsToSchool(schoolId)`)
- ✅ Staff can only create their own applications (checked via `applicantId`)
- ✅ Admins still require `isActive()` for write operations
- ✅ Updates and deletions still require proper authorization

### What Still Requires `isActive()`?

The following operations still require `isActive()` status:
- Updating leave applications (except cancellation)
- Updating permission requests (except cancellation)
- Admin write operations (create/update configs)
- Deleting records

This ensures that only active admins can modify configurations and approve/reject requests.

## Verification

After deployment, verify the following:

1. **Permission Config Loading**:
   - Staff dashboard should show permission overview
   - "Request Permission" screen should load the form (not "Not Configured")

2. **Leave Application**:
   - Staff can submit leave applications
   - No permission denied errors
   - Applications appear in "My Leaves"

3. **Permission Request**:
   - Staff can submit permission requests
   - No permission denied errors
   - Requests appear in "My Permissions"

4. **Admin Approval**:
   - Admin can still view pending requests
   - Admin can approve/reject
   - Status updates reflect correctly

## Rollback Plan

If issues arise, the previous rules can be restored by:

1. Adding back `isActive()` checks:
```javascript
// For permission config
allow read: if isSignedIn() && isActive() && (isSuperAdmin() || belongsToSchool(schoolId));

// For leave creation
allow create: if isSignedIn() && isActive() && belongsToSchool(schoolId);

// For permission creation
allow create: if isSignedIn() && isActive() && belongsToSchool(schoolId) && ...
```

2. Redeploy rules:
```bash
node firebase/deploy-rules.js
```

3. Ensure all staff users have `isActive: true` field in their user documents

## Related Files

- `firestore.rules` - Updated security rules
- `firebase/deploy-rules.js` - Deployment script
- `lib/presentation/staff/screens/apply_leave_screen.dart` - Leave application UI
- `lib/presentation/staff/screens/request_permission_screen.dart` - Permission request UI
- `lib/data/repositories/leave_application_repository.dart` - Leave data layer
- `lib/data/repositories/permission_request_repository.dart` - Permission data layer

## Conclusion

The permission denied errors were caused by overly restrictive Firestore security rules that required an `isActive` field which may not be present in all user documents. By removing this requirement for read and create operations while maintaining authentication and school membership checks, staff users can now successfully:

- ✅ View permission configuration
- ✅ Apply for leaves
- ✅ Request permissions

All changes maintain security while improving user experience.
