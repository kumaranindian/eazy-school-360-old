# Quick Start Guide (Without Cloud Functions)

Your Firebase project is on the **Spark (free) plan**, which doesn't support Cloud Functions. Here's how to set up custom claims without upgrading.

## Setup Steps

### 1. Download Service Account Key

1. Go to [Firebase Console](https://console.firebase.google.com/project/eazy-school-360/settings/serviceaccounts/adminsdk)
2. Click **"Generate New Private Key"**
3. Save the JSON file as `service-account-key.json` in your project root: `d:/workspace/eazy-school-360/`
4. **IMPORTANT:** Add to `.gitignore`:
   ```
   service-account-key.json
   ```

### 2. Install Dependencies

```bash
cd d:/workspace/eazy-school-360
npm install firebase-admin
```

### 3. Set Claims for Your Current Admin User

**Option A: By Email (Easiest)**
```bash
node scripts/set-user-claims.js --email ckarthikeyan60@yahoo.in
```

**Option B: By UID**
```bash
node scripts/set-user-claims.js DTNRix56ENeDACP89VdCGD9IaVt1
```

**Option C: Interactive Mode**
```bash
node scripts/set-user-claims.js
```

Expected output:
```
✅ Claims set for user DTNRix56ENeDACP89VdCGD9IaVt1:
   Email: ckarthikeyan60@yahoo.in
   Role: tenant_admin
   Claims: { superAdmin: false, admin: true, staff: false, schoolId: '3uloakcJRa8w1R4TRQhi', isActive: true }
```

### 4. Flutter: Sign Out and Sign In

In your Flutter app:
1. **Sign out completely**
2. **Sign in again**
3. The token will now contain the correct claims

### 5. Verify Claims

Add this debug code after login:

```dart
final user = FirebaseAuth.instance.currentUser;
if (user != null) {
  await user.getIdToken(true); // Force refresh
  final tokenResult = await user.getIdTokenResult();
  print('🔍 Token claims: ${tokenResult.claims}');
}
```

Expected output:
```
🔍 Token claims: {admin: true, schoolId: 3uloakcJRa8w1R4TRQhi, superAdmin: false, staff: false, isActive: true, ...}
```

### 6. Test Staff Query

Your `schools/3uloakcJRa8w1R4TRQhi/staff` query should now work! ✅

---

## For New Users (Manual Process)

Since you don't have Cloud Functions, you'll need to **manually set claims** after creating each new admin or teacher:

### When Creating a New Admin:

1. Create the user in your Flutter app (Auth + Firestore doc)
2. Run the script:
   ```bash
   node scripts/set-user-claims.js --email newadmin@school.com
   ```
3. User signs in → claims are active

### When Creating a New Teacher:

Same process - the script reads the `role` from Firestore and sets the correct claims automatically.

---

## Set Claims for All Existing Users

If you have multiple users already:

```bash
node scripts/set-user-claims.js --all
```

This will update claims for every user in your `users` collection.

---

## Troubleshooting

### Error: Cannot find module '../service-account-key.json'

You need to download the service account key from Firebase Console (see Step 1 above).

### Error: Permission denied

Make sure the service account key has the correct permissions. Re-download if needed.

### Claims still not working

1. Verify claims were set:
   ```bash
   node scripts/set-user-claims.js --email your@email.com
   ```
2. Sign out and sign in in Flutter
3. Call `user.getIdToken(true)` to force refresh
4. Check the token claims with debug logging

---

## Future: Upgrade to Blaze Plan

When you're ready for production, upgrade to the Blaze plan to enable automatic claim setting via Cloud Functions:

1. Upgrade at: https://console.firebase.google.com/project/eazy-school-360/usage/details
2. Deploy functions: `firebase deploy --only functions`
3. Claims will be set automatically on user creation/update (no manual script needed)

**Blaze plan is still free for low usage:**
- 2M function invocations/month free
- You'll only pay if you exceed free tier
- For a school system, you'll likely stay within free limits

---

## Summary

✅ **Rules updated** - Use token claims (no `get()` calls)  
✅ **Script created** - Manually set claims without Cloud Functions  
✅ **Works immediately** - No billing required  

**Next steps:**
1. Download service account key
2. Run: `node scripts/set-user-claims.js --email ckarthikeyan60@yahoo.in`
3. Sign out and sign in in Flutter
4. Test staff query - should work! ✅
