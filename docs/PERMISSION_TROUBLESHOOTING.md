# Permission Details Not Showing - Troubleshooting Guide

## ✅ Issue Fixed!

### **What Was Wrong**
1. Permission configuration document didn't exist in Firestore
2. Firestore rules didn't allow staff to read permission settings
3. Function returned error when config was missing

### **What We Fixed**
1. ✅ Created permission configuration via setup script
2. ✅ Updated Firestore rules to allow staff to read `settings/permission`
3. ✅ Updated `getPermissionConfig` to return default values if config missing
4. ✅ Updated `applyPermission` to use default config if not found

---

## 🔧 Verification Steps

### **1. Check Permission Configuration Exists**
```javascript
// In Firebase Console or via script
schools/{schoolId}/settings/permission
{
  enabled: true,
  minHours: 0.5,
  maxHoursPerDay: 4,
  requiresApproval: true,
  allowedDays: ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"],
  description: "Permission requests for partial day absence"
}
```

### **2. Check Staff Has Permission Balance**
```javascript
schools/{schoolId}/staff/{staffId}/permission_balances/current_year
{
  availableHours: 24,
  usedHours: 0,
  totalHours: 24,
  updatedAt: Timestamp
}
```

### **3. Test getPermissionConfig Function**
```dart
final result = await FirebaseFunctions.instance
  .httpsCallable('getPermissionConfig')
  .call({'schoolId': schoolId});

print(result.data);
// Should return: { success: true, config: {...} }
```

---

## 🎯 Frontend Integration

### **Fetch Permission Config**
```dart
Future<PermissionConfig> getPermissionConfig() async {
  try {
    final callable = FirebaseFunctions.instance
      .httpsCallable('getPermissionConfig');
    
    final result = await callable.call({'schoolId': schoolId});
    
    if (result.data['success']) {
      final config = result.data['config'];
      
      // Check if using default config
      if (config['isDefault'] == true) {
        print('Using default permission configuration');
      }
      
      return PermissionConfig.fromMap(config);
    }
  } catch (e) {
    print('Error fetching permission config: $e');
    rethrow;
  }
}
```

### **Display Permission Details**
```dart
FutureBuilder<PermissionConfig>(
  future: getPermissionConfig(),
  builder: (context, snapshot) {
    if (snapshot.hasError) {
      return Text('Error: ${snapshot.error}');
    }
    
    if (!snapshot.hasData) {
      return CircularProgressIndicator();
    }
    
    final config = snapshot.data!;
    
    if (!config.enabled) {
      return Text('Permission requests are currently disabled');
    }
    
    return Column(
      children: [
        Text('Min Duration: ${config.minHours} hours'),
        Text('Max Duration: ${config.maxHoursPerDay} hours/day'),
        Text('Requires Approval: ${config.requiresApproval}'),
        // Show permission request form
      ],
    );
  },
)
```

### **Apply Permission**
```dart
Future<void> applyPermission({
  required String date,
  required String startTime,
  required String endTime,
  required String reason,
}) async {
  try {
    final callable = FirebaseFunctions.instance
      .httpsCallable('applyPermission');
    
    final result = await callable.call({
      'schoolId': schoolId,
      'date': date,
      'startTime': startTime,
      'endTime': endTime,
      'reason': reason,
    });
    
    if (result.data['success']) {
      print('Permission requested: ${result.data['permissionId']}');
      // Show success message
    }
  } on FirebaseFunctionsException catch (e) {
    // Handle specific errors
    switch (e.code) {
      case 'invalid-argument':
        print('Invalid duration or time range');
        break;
      case 'failed-precondition':
        print('Insufficient balance or permissions disabled');
        break;
      case 'already-exists':
        print('Permission already requested for this date');
        break;
      default:
        print('Error: ${e.message}');
    }
  }
}
```

---

## 🔐 Security Rules Update

The following rule now allows staff to read permission settings:

```javascript
match /settings/{settingId} {
  allow read: if isSignedIn() && (
    isSuperAdmin() || 
    belongsToSchool(schoolId) ||
    (isStaff() && belongsToSchool(schoolId) && settingId == 'permission')
  );
  allow write: if isSignedIn() && isActive() && 
    (isSuperAdmin() || (isTenantAdmin() && belongsToSchool(schoolId)));
}
```

---

## 📊 Default Configuration

If permission configuration doesn't exist, the system uses these defaults:

```javascript
{
  enabled: true,
  minHours: 0.5,
  maxHoursPerDay: 4,
  requiresApproval: true,
  allowedDays: ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'],
  description: 'Permission requests for partial day absence',
  isDefault: true,
  message: 'Using default permission configuration'
}
```

---

## 🚀 Quick Fix Commands

### **1. Run Setup Script**
```bash
node scripts/setup-leave-permission-config.js
```

### **2. Deploy Updates**
```bash
firebase deploy --only functions:getPermissionConfig,functions:applyPermission,firestore:rules
```

### **3. Test in App**
- Login as staff
- Navigate to permission request screen
- Should now see permission details and form

---

## ⚠️ Common Issues

### **Issue: "Permission configuration not found"**
**Solution:** Run the setup script or manually create the document

### **Issue: "Permission-denied" when reading config**
**Solution:** Deploy updated Firestore rules

### **Issue: "Insufficient permission balance"**
**Solution:** Create permission balance for the staff member:
```javascript
schools/{schoolId}/staff/{staffId}/permission_balances/current_year
{
  availableHours: 24,
  usedHours: 0,
  totalHours: 24
}
```

### **Issue: Permission form not showing**
**Solution:** 
1. Check `getPermissionConfig` returns data
2. Verify frontend is calling the function correctly
3. Check console for errors

---

## 📝 Testing Checklist

- [ ] Configuration exists in Firestore
- [ ] Staff can read permission settings
- [ ] `getPermissionConfig` returns valid data
- [ ] Permission balance exists for staff
- [ ] Frontend displays permission details
- [ ] Staff can submit permission request
- [ ] Validation works (min/max hours)
- [ ] Admin can approve/reject

---

## 🎉 Expected Behavior

After fixes:
1. ✅ Staff logs in
2. ✅ Navigates to permission request screen
3. ✅ Sees permission configuration details
4. ✅ Can select date and time range
5. ✅ System validates against min/max hours
6. ✅ Can submit permission request
7. ✅ Request appears in admin dashboard for approval

---

## 📚 Related Documentation
- [Leave & Permission Management System](./LEAVE_PERMISSION_MANAGEMENT_SYSTEM.md)
- [Quick Reference Guide](./LEAVE_PERMISSION_QUICK_REFERENCE.md)
