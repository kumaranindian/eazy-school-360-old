# Custom Claims Setup & Verification Guide

## What Changed

Your Firestore security rules now use **Firebase Auth custom claims** instead of reading from Firestore documents. This fixes the `permission-denied` error on queries.

### Old Structure (Doesn't Work for Queries)
```js
// Rules tried to read: get(/databases/.../users/{uid}).data.role
// This fails for list queries
```

### New Structure (Works for Queries)
```js
// Rules read: request.auth.token.admin, request.auth.token.schoolId
// This works for all operations including list queries
```

## Custom Claims Format

Your Auth tokens now contain:

```json
{
  "superAdmin": false,
  "admin": true,           // true for ADMIN or tenant_admin roles
  "staff": false,          // true for STAFF role
  "schoolId": "3uloakcJRa8w1R4TRQhi",
  "isActive": true
}
```

## Deployment Steps

### 1. Deploy Updated Cloud Functions

```bash
cd d:/workspace/eazy-school-360
firebase deploy --only functions
```

This will deploy:
- `onUserDocumentWrite` - Automatically sets claims when user docs are created/updated
- `setCustomClaims` - Callable function to manually refresh claims

### 2. Fix Existing User Claims

For your current admin user:

```bash
cd functions
node fix-existing-user-claims.js DTNRix56ENeDACP89VdCGD9IaVt1
```

Or fix all existing users at once:

```bash
cd functions
node fix-existing-user-claims.js --all
```

Expected output:
```
✅ Fixed claims for user DTNRix56ENeDACP89VdCGD9IaVt1:
   Role: tenant_admin
   Claims: { superAdmin: false, admin: true, staff: false, schoolId: '3uloakcJRa8w1R4TRQhi', isActive: true }
```

### 3. Flutter: Force Token Refresh

After claims are set, users **must** refresh their ID token. Add this to your login flow:

```dart
// After successful login
final user = FirebaseAuth.instance.currentUser;
if (user != null) {
  // Force token refresh to get new claims
  await user.getIdToken(true);
  
  // Debug: verify claims are present
  final tokenResult = await user.getIdTokenResult();
  print('🔍 Token claims: ${tokenResult.claims}');
}
```

## Verification Steps

### Step 1: Check Cloud Functions Logs

After deploying, create a new user or update an existing one. Check Firebase Console > Functions > Logs:

```
✅ Custom claims set for user DTNRix56ENeDACP89VdCGD9IaVt1: {superAdmin: false, admin: true, staff: false, schoolId: "3uloakcJRa8w1R4TRQhi", isActive: true}
```

### Step 2: Verify Token Claims in Flutter

Add debug logging in your Flutter app:

```dart
Future<void> debugTokenClaims() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;
  
  final tokenResult = await user.getIdTokenResult();
  final claims = tokenResult.claims;
  
  print('🔍 [DEBUG] Token Claims:');
  print('   admin: ${claims?['admin']}');
  print('   staff: ${claims?['staff']}');
  print('   superAdmin: ${claims?['superAdmin']}');
  print('   schoolId: ${claims?['schoolId']}');
  print('   isActive: ${claims?['isActive']}');
}
```

Expected output for tenant_admin:
```
🔍 [DEBUG] Token Claims:
   admin: true
   staff: false
   superAdmin: false
   schoolId: 3uloakcJRa8w1R4TRQhi
   isActive: true
```

### Step 3: Test Staff Query

After token refresh, try the staff query:

```dart
final staffQuery = FirebaseFirestore.instance
    .collection('schools')
    .doc('3uloakcJRa8w1R4TRQhi')
    .collection('staff');

final snapshot = await staffQuery.get();
print('✅ Staff query succeeded! Found ${snapshot.docs.length} staff members');
```

Should now succeed without `permission-denied` error.

## How It Works for New Users

### When Creating Admin

```dart
// 1. Create Auth user
final credential = await FirebaseAuth.instance
    .createUserWithEmailAndPassword(email: email, password: password);

// 2. Create Firestore user doc
await FirebaseFirestore.instance
    .collection('users')
    .doc(credential.user!.uid)
    .set({
      'email': email,
      'role': 'tenant_admin',  // or 'ADMIN'
      'schoolId': schoolId,
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
    });

// 3. Cloud Function automatically sets claims (onUserDocumentWrite trigger)
// 4. Force token refresh
await credential.user!.getIdToken(true);

// 5. User can now query staff/leaves for their school
```

### When Creating Teacher (STAFF)

```dart
// Same flow, but with role: 'STAFF'
await FirebaseFirestore.instance
    .collection('users')
    .doc(uid)
    .set({
      'email': email,
      'role': 'STAFF',
      'schoolId': schoolId,
      'isActive': true,
      // ...
    });

// Cloud Function sets: { staff: true, admin: false, superAdmin: false, schoolId: ... }
```

## Troubleshooting

### Issue: Still getting permission-denied

**Check 1:** Verify claims are in the token
```dart
final tokenResult = await user.getIdTokenResult();
print(tokenResult.claims);
```

If claims are missing:
- Run the fix script again
- Sign out and sign in
- Call `user.getIdToken(true)` to force refresh

**Check 2:** Verify schoolId matches
```dart
final claims = tokenResult.claims;
print('Token schoolId: ${claims?['schoolId']}');
print('Query schoolId: $schoolId');
// These must match exactly
```

**Check 3:** Check Cloud Functions logs
- Firebase Console > Functions > Logs
- Look for "Custom claims set" messages
- Check for errors

### Issue: Claims not updating after role change

Users must **sign out and sign in** or call `getIdToken(true)` after any role/school change.

### Issue: New users don't get claims

Check that `onUserDocumentWrite` function is deployed:
```bash
firebase functions:list
```

Should show: `onUserDocumentWrite`

## Security Rules Reference

Your rules now check:

```js
function isAdmin() {
  return request.auth.token.admin == true;
}

function belongsToSchool(schoolId) {
  return request.auth.token.schoolId == schoolId;
}

// Staff list query
allow list: if isSignedIn() && (
  isSuperAdmin() || 
  (isAdmin() && belongsToSchool(schoolId))
);
```

This works for queries because it only uses `request.auth.token.*`, not `get()` calls.

## Summary

✅ **Rules updated** - Now use token claims instead of Firestore reads  
✅ **Cloud Functions updated** - Automatically set correct claim structure  
✅ **Fix script created** - Can fix existing users  
✅ **New users** - Will automatically get claims on creation  

**Next Steps:**
1. Deploy functions: `firebase deploy --only functions`
2. Fix existing user: `node functions/fix-existing-user-claims.js DTNRix56ENeDACP89VdCGD9IaVt1`
3. Sign out and sign in in Flutter app
4. Verify claims with debug logging
5. Test staff/leaves queries
