# Staff Membership Creation Permission Fix

## Issue
When creating a new staff member, the system was failing with a permission-denied error:
```
❌ [STAFF_REPO] Failed to create membership: [cloud_firestore/permission-denied] Missing or insufficient permissions.
```

## Root Cause
The Firestore security rules for the `userMemberships/{uid}/schools/{schoolId}` collection were too restrictive. The CREATE rule only allowed:
1. Super admins
2. Users creating their own membership
3. Creating memberships with ADMIN or FINANCE roles

This meant that when an ADMIN tried to create a STAFF membership for a new staff member, the operation was denied.

## Solution
Updated the Firestore rules in `firebase/firestore.rules` to allow active admins to create memberships for other users in their school:

### Before
```firestore
allow create: if isSignedIn() && (
  isSuperAdmin() ||
  isOwner(uid) ||
  request.resource.data.roles.hasAny(['ADMIN', 'FINANCE'])
);
```

### After
```firestore
allow create: if isSignedIn() && (
  isSuperAdmin() ||
  isOwner(uid) ||
  request.resource.data.roles.hasAny(['ADMIN', 'FINANCE']) ||
  // Allow active admins to create memberships for other users in their school
  (isActive() && hasRoleAt(schoolId, ['ADMIN']))
);
```

## Changes Made
1. **File**: `firebase/firestore.rules` (lines 152-158)
   - Added condition to allow active admins to create memberships for any user in their school
   - Uses `hasRoleAt(schoolId, ['ADMIN'])` to verify the admin belongs to the target school
   - Requires `isActive()` to ensure only active admins can create memberships

2. **Deployment**: Rules deployed to Firebase using `firebase deploy --only firestore:rules`

## Testing
After deploying the fix, admins should be able to:
- Create staff members with STAFF role
- Create finance users with FINANCE role
- Create admin users with ADMIN role

All within their own school, as long as they are active admins.

## Related Files
- `firebase/firestore.rules` - Firestore security rules
- `lib/data/repositories/staff_management_repository.dart` - Staff creation logic
- `lib/data/services/membership_service.dart` - Membership management service

## Date
May 4, 2026
