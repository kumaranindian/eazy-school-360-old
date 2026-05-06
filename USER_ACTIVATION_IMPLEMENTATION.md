# User Activation via Password Reset Implementation

## Overview
This document describes the implementation of the new user activation flow where staff and finance users are activated only after they set their password via email reset link.

## Problem Statement
Previously, users were created with default passwords (email+phone combination), which had security concerns and didn't properly activate users. The `isActive` field check in Firestore rules was failing because users weren't being properly activated.

## Solution
Implement a password-reset-based activation flow:
1. Admin creates user with random password (never shared)
2. Password reset email sent immediately
3. User clicks email link and sets their password
4. User logs in for the first time
5. **Dart service activates the user automatically** (no Cloud Functions required)
6. User can now access the system

**Important**: This implementation uses Firestore directly (Dart) instead of Cloud Functions to keep the project on the Firebase Spark (free) plan.

## Implementation Details

### 1. Firestore Rules (Reverted)
**File**: `firestore.rules`

Reverted the rules to require `isActive` check for:
- Reading permission config (line 589)
- Creating leave applications (line 161)
- Creating permission requests (line 563)

This ensures only activated users can use the system.

### 2. Staff Creation Logic Updated
**File**: `lib/data/repositories/staff_management_repository.dart`

**Changes**:
- Added `dart:math` import for secure random password generation
- Added `_generateRandomPassword()` method - creates 16-character random password
- Added `_sendPasswordResetEmail()` method - sends Firebase password reset email
- Updated `createStaff()` method:
  - Uses random password instead of email+phone pattern
  - Sets `onboardingStatus` to `PENDING_ACTIVATION`
  - Sends password reset email immediately
  - Returns message about email sent (no password in response)

**Before**:
```dart
final tempPassword = _generateTemporaryPassword(
  email: request.email,
  phoneNumber: request.phoneNumber ?? '0000000000',
);
// ... create user with tempPassword
// ... return tempPassword to admin
```

**After**:
```dart
final randomPassword = _generateRandomPassword();
// ... create user with randomPassword
onboardingStatus: OnboardingStatus.PENDING_ACTIVATION,
// ... send password reset email
await _sendPasswordResetEmail(request.email, request.name);
// ... return message (no password)
```

### 3. AppUser Entity Updated
**File**: `lib/domain/entities/app_user.dart`

**Changes**:
- Updated `toFirestore()` method to set `isActive` based on both `status` and `onboardingStatus`

**Before**:
```dart
'isActive': status == UserStatus.ACTIVE,
```

**After**:
```dart
'isActive': status == UserStatus.ACTIVE && onboardingStatus != OnboardingStatus.PENDING_ACTIVATION,
```

This ensures users are only marked as active when:
1. Status is ACTIVE, AND
2. Onboarding is complete (not PENDING_ACTIVATION)

### 4. User Activation Service (Dart)
**File**: `lib/data/services/user_activation_service.dart`

**New Service**: `UserActivationService`

Provides `checkAndActivateUser()` method that:
1. Checks current user's onboarding status from Firestore
2. If `onboardingStatus` is `PENDING_ACTIVATION`:
   - Updates Firestore document directly
   - Sets `isActive: true`
   - Sets `onboardingStatus: ACTIVE`
   - Sets `activatedAt` timestamp
   - Forces Firebase token refresh
3. Returns `ActivationResult` with success/failure info

**Benefits**:
- No Cloud Functions required (works on free tier)
- Direct Firestore access
- Simpler architecture
- No billing account needed

### 6. UI Updates
**File**: `lib/presentation/admin/screens/add_staff_screen.dart`

**Changes**:
- Updated success dialog to show password reset email message
- Removed display of temporary password
- Shows informative message about activation process

**Before**:
```dart
_buildInfoRow('Password', staffData['tempPassword']?.toString() ?? 'N/A'),
// ... message about login credentials sent
```

**After**:
```dart
// No password row
// ... message about password reset email and activation
```

## User Flow

### Admin Creates Staff Member
1. Admin fills out staff creation form
2. Admin clicks "Save"
3. System creates Firebase Auth user with random password
4. System creates Firestore user document with:
   - `status`: ACTIVE
   - `onboardingStatus`: PENDING_ACTIVATION
   - `isActive`: false (computed)
5. System sends password reset email to staff
6. Admin sees success message with email confirmation

### Staff Member Activates Account
1. Staff receives password reset email
2. Staff clicks link in email
3. Staff sets their password
4. Staff navigates to login page
5. Staff enters email and new password
6. System authenticates user
7. **System calls activation service** (to be integrated)
8. Cloud Function activates user:
   - Sets `isActive`: true
   - Sets `onboardingStatus`: ACTIVE
   - Updates custom claims
9. Staff is redirected to dashboard
10. Staff can now use the system

## Pending Integration

### Auth Provider Integration
**File**: `lib/core/providers/auth_provider.dart`

**TODO**: Add activation check after successful sign-in:

```dart
Future<AuthResult> signIn(String email, String password, {String? preferredSchoolId}) async {
  try {
    // Existing sign-in logic
    final credential = await _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    
    // NEW: Check and activate user if needed
    final activationService = UserActivationService();
    final activationResult = await activationService.checkAndActivateUser();
    
    if (activationResult.activated) {
      print('✅ [AUTH] User activated successfully');
      // Force token refresh to get updated claims
      await credential.user?.getIdToken(true);
    }
    
    // Continue with existing session creation logic
    // ...
  } catch (e) {
    // Error handling
  }
}
```

## Admin User Creation

**File**: `lib/data/repositories/staff_management_repository.dart`

**Method**: `createAdmin()`

**TODO**: Update to use same pattern as staff creation:
- Remove `_generateTemporaryPassword()` usage
- Use `_generateRandomPassword()` instead
- Set `onboardingStatus` to `PENDING_ACTIVATION`
- Send password reset email
- Update return value to not include password

## Finance User Creation

**File**: `lib/data/repositories/staff_management_repository.dart`

**Method**: `createFinanceAdmin()`

**TODO**: Update to use same pattern:
- Remove `_generateTemporaryPassword()` usage
- Use `_generateRandomPassword()` instead
- Set `onboardingStatus` to `PENDING_ACTIVATION`
- Send password reset email
- Update return value to not include password

## Bulk Staff Upload

**File**: `lib/data/services/bulk_staff_upload_service.dart`

**TODO**: Update bulk upload logic:
- Remove password generation and Excel export
- Send password reset emails to all created users
- Update success message to inform about activation emails
- Remove credentials Excel download feature

## Testing Checklist

### Staff Creation (Single)
- [ ] Admin can create staff member
- [ ] Password reset email is sent
- [ ] No password shown in UI
- [ ] User document has `onboardingStatus: PENDING_ACTIVATION`
- [ ] User document has `isActive: false`

### Staff Activation
- [ ] Staff receives password reset email
- [ ] Staff can set password via email link
- [ ] Staff can log in with new password
- [ ] Cloud Function activates user on first login
- [ ] User document updated to `isActive: true`
- [ ] User document updated to `onboardingStatus: ACTIVE`
- [ ] Custom claims updated with `isActive: true`

### System Access
- [ ] Activated staff can apply for leave
- [ ] Activated staff can request permission
- [ ] Activated staff can view dashboard
- [ ] Non-activated users get permission denied errors

### Admin Creation
- [ ] Admin can create admin users
- [ ] Password reset email sent to admin users
- [ ] Admin users follow same activation flow

### Finance User Creation
- [ ] Admin can create finance users
- [ ] Password reset email sent to finance users
- [ ] Finance users follow same activation flow

### Bulk Upload
- [ ] Bulk upload sends password reset emails
- [ ] No credentials Excel generated
- [ ] All users require activation

## Security Benefits

1. **No Default Passwords**: Random passwords never shared with anyone
2. **Email Verification**: User must have access to email to activate
3. **Secure Password**: User sets their own strong password
4. **Audit Trail**: `activatedAt` timestamp records when user activated
5. **Controlled Access**: Only activated users can use system features

## Deployment Steps

1. **Deploy Firestore Rules**:
   ```bash
   node firebase/deploy-rules.js
   ```

2. **Install Flutter Dependencies**:
   ```bash
   flutter pub get
   ```

3. **Test Staff Creation**:
   - Create a test staff member
   - Verify password reset email received
   - Complete password reset
   - Log in and verify activation

4. **Monitor Logs**:
   - Check Flutter app logs for activation messages
   - Check Firestore console for user document updates

## Rollback Plan

If issues arise:

1. **Revert Firestore Rules**: Remove `isActive()` checks temporarily
2. **Disable Activation**: Comment out activation service call in auth provider
3. **Manual Activation**: Use Firebase Console to set `isActive: true` manually

## Future Enhancements

1. **Resend Activation Email**: Add button for admins to resend password reset
2. **Activation Reminders**: Send reminder emails to non-activated users
3. **Activation Dashboard**: Admin view of pending activations
4. **Bulk Activation**: Admin can activate multiple users at once
5. **Custom Email Templates**: Branded password reset emails

## Related Files

- `firestore.rules` - Security rules requiring activation
- `functions/index.js` - Cloud Function for activation
- `lib/data/repositories/staff_management_repository.dart` - Staff creation logic
- `lib/domain/entities/app_user.dart` - User entity with activation logic
- `lib/data/services/user_activation_service.dart` - Activation service
- `lib/presentation/admin/screens/add_staff_screen.dart` - UI updates
- `pubspec.yaml` - Dependencies

## Conclusion

This implementation provides a secure, email-verified activation flow for new users. Users must set their own password before accessing the system, ensuring better security and proper user activation tracking.
