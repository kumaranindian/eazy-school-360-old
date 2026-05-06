# Staff Active Status Implementation

## Overview
This document confirms that all staff creation flows (single and bulk) automatically set newly created staff members as **ACTIVE** by default. This ensures that admins, tenant admins, and owners can immediately create active staff members without additional activation steps.

## Implementation Status

### ✅ Single Staff Creation
**Location**: `lib/data/repositories/staff_management_repository.dart`

#### 1. `createStaff()` Method (Lines 248-450)
- **User Document**: Sets `status: UserStatus.ACTIVE` (line 317)
- **Staff Profile**: Sets `status: UserStatus.ACTIVE` (line 372)
- **Membership**: Sets `ensureActive: true` (line 354)
- **Onboarding Status**: Sets `onboardingStatus: OnboardingStatus.ACTIVE` (line 318)

#### 2. `createAdmin()` Method (Lines 552-646)
- **User Document**: Sets `status: UserStatus.ACTIVE` (line 591)
- **Staff Profile**: Sets `status: UserStatus.ACTIVE` (line 616)
- **Onboarding Status**: Sets `onboardingStatus: OnboardingStatus.PENDING_ACTIVATION` (line 592)
  - Note: Admin users require activation by super admin

#### 3. `createFinanceUser()` Method (Lines 659-793)
- **User Document** (new users): Sets `status: UserStatus.ACTIVE` (line 720)
- **Staff Profile**: Sets `status: UserStatus.ACTIVE` (line 760)
- **Membership**: Sets `ensureActive: true` (line 748)
- **Onboarding Status**: Sets `onboardingStatus: OnboardingStatus.PENDING_ACTIVATION` (line 721)

### ✅ Bulk Staff Upload
**Location**: `lib/data/services/bulk_staff_upload_service.dart`

The bulk upload service (lines 527-545) calls `_staffRepository.createStaff()` for each new staff member, which automatically sets them as ACTIVE.

```dart
final result = await _staffRepository.createStaff(
  schoolId,
  adminUserId,
  request,
  sendWelcomeEmail: false,
);
```

## Key Changes Made

### 1. AppUser Entity Enhancement
**File**: `lib/domain/entities/app_user.dart` (line 330)

Added `isActive` field to `toFirestore()` method for backward compatibility:

```dart
'isActive': status == UserStatus.ACTIVE, // For backward compatibility with security rules
```

**Why**: Firestore security rules check for BOTH:
- `data.isActive == true` (legacy field)
- `data.status == "ACTIVE"` (current field)

This ensures newly created staff are immediately recognized as active by the security rules.

### 2. Firestore Security Rules
**File**: `firebase/firestore.rules` (lines 17-22)

The `isActive()` helper function checks both fields:

```firestore
function isActive() {
  return isSignedIn() && hasUserDoc() && (
    get(/databases/$(database)/documents/users/$(request.auth.uid)).data.isActive == true ||
    get(/databases/$(database)/documents/users/$(request.auth.uid)).data.status == "ACTIVE"
  );
}
```

## Data Structure

### User Document (`users/{uid}`)
```json
{
  "uid": "...",
  "email": "staff@school.com",
  "displayName": "Staff Name",
  "role": "STAFF",
  "schoolId": "...",
  "staffType": "TEACHING",
  "status": "ACTIVE",           // ✅ Set to ACTIVE
  "isActive": true,             // ✅ Set to true
  "onboardingStatus": "ACTIVE", // ✅ Set to ACTIVE for staff
  "createdAt": "...",
  "updatedAt": "...",
  "createdBy": "...",
  "profile": { ... },
  "permissions": { ... }
}
```

### Staff Profile (`schools/{schoolId}/staff/{staffId}`)
```json
{
  "userId": "...",
  "schoolId": "...",
  "name": "Staff Name",
  "employeeId": "EMP001",
  "email": "staff@school.com",
  "staffType": "TEACHING",
  "status": "ACTIVE",  // ✅ Set to ACTIVE
  "joiningDate": "...",
  "createdAt": "...",
  "updatedAt": "...",
  "createdBy": "..."
}
```

### Membership (`userMemberships/{uid}/schools/{schoolId}`)
```json
{
  "schoolId": "...",
  "schoolName": "...",
  "roles": ["STAFF"],
  "isActive": true,        // ✅ Set to true via ensureActive
  "schoolIsActive": true,
  "joinedAt": "...",
  "createdBy": "..."
}
```

## Access Control

### Who Can Create Staff?
1. **Super Admin** - Can create staff in any school
2. **Admin/Tenant Admin** - Can create staff in their own school
3. **Owner** - Can create staff in their own school

### Firestore Rules
**File**: `firebase/firestore.rules` (lines 152-158)

```firestore
allow create: if isSignedIn() && (
  isSuperAdmin() ||
  isOwner(uid) ||
  request.resource.data.roles.hasAny(['ADMIN', 'FINANCE']) ||
  // Allow active admins to create memberships for other users in their school
  (isActive() && hasRoleAt(schoolId, ['ADMIN']))
);
```

## Testing Checklist

- [x] Single staff creation sets status to ACTIVE
- [x] Bulk staff upload sets status to ACTIVE
- [x] Admin creation sets status to ACTIVE
- [x] Finance user creation sets status to ACTIVE
- [x] User document has both `status` and `isActive` fields
- [x] Staff profile has `status` field
- [x] Membership has `isActive` field
- [x] Firestore rules allow active admins to create memberships

## Related Files
- `lib/domain/entities/app_user.dart` - User entity with isActive field
- `lib/domain/entities/staff_profile.dart` - Staff profile entity
- `lib/data/repositories/staff_management_repository.dart` - Staff creation logic
- `lib/data/services/bulk_staff_upload_service.dart` - Bulk upload service
- `lib/data/services/membership_service.dart` - Membership management
- `firebase/firestore.rules` - Security rules

## Date
May 4, 2026
