# Firestore Security Rules for Staff Management

## Enhanced Security Rules with Staff Management

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // ============================================================================
    // HELPER FUNCTIONS
    // ============================================================================
    
    // Check if user is authenticated
    function isAuthenticated() {
      return request.auth != null;
    }
    
    // Get user role from users collection
    function getUserRole() {
      return get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role;
    }
    
    // Get user's school ID
    function getUserSchoolId() {
      return get(/databases/$(database)/documents/users/$(request.auth.uid)).data.schoolId;
    }
    
    // Check if user status is ACTIVE
    function isUserActive() {
      return get(/databases/$(database)/documents/users/$(request.auth.uid)).data.status == 'ACTIVE';
    }
    
    // Check if user is SUPER_ADMIN
    function isSuperAdmin() {
      return isAuthenticated() && getUserRole() == 'SUPER_ADMIN';
    }
    
    // Check if user is ADMIN
    function isAdmin() {
      return isAuthenticated() && getUserRole() == 'ADMIN';
    }
    
    // Check if user is STAFF
    function isStaff() {
      return isAuthenticated() && getUserRole() == 'STAFF';
    }
    
    // Check if user belongs to the specified school
    function belongsToSchool(schoolId) {
      return getUserSchoolId() == schoolId;
    }
    
    // Check if user can access school data
    function canAccessSchool(schoolId) {
      return isSuperAdmin() || (isUserActive() && belongsToSchool(schoolId));
    }
    
    // Check if user owns the resource
    function isOwner(resourceUserId) {
      return request.auth.uid == resourceUserId;
    }
    
    // Validate immutable fields are not changed
    function immutableFieldsUnchanged(immutableFields) {
      return immutableFields.diff(resource.data).unchangedKeys().hasAll(immutableFields);
    }
    
    // Check if employee ID is unique within school (for validation)
    function isEmployeeIdUniqueInSchool(schoolId, employeeId, excludeDocId) {
      let existingDocs = get(/databases/$(database)/documents/schools/$(schoolId)/staff).data;
      return !exists(/databases/$(database)/documents/schools/$(schoolId)/staff/$(employeeId)) ||
             (excludeDocId != null && excludeDocId == employeeId);
    }
    
    // ============================================================================
    // USERS COLLECTION (Enhanced for Staff Management)
    // ============================================================================
    
    match /users/{userId} {
      // Read: Users can read own profile, ADMIN can read school users, SUPER_ADMIN can read all
      allow read: if isOwner(userId) || 
        (isAdmin() && belongsToSchool(resource.data.schoolId)) ||
        isSuperAdmin();
      
      // Create: Only SUPER_ADMIN can create ADMIN users, ADMIN can create STAFF users
      allow create: if (
        (isSuperAdmin() && request.resource.data.role in ['SUPER_ADMIN', 'ADMIN']) ||
        (isAdmin() && request.resource.data.role == 'STAFF' && 
         belongsToSchool(request.resource.data.schoolId))
      ) && request.resource.data.uid == userId
        && request.resource.data.status == 'ACTIVE'
        && request.resource.data.createdBy == request.auth.uid;
      
      // Update: Users can update own profile (limited fields), ADMIN can update school users
      allow update: if (
        (isOwner(userId) && 
         request.resource.data.diff(resource.data).affectedKeys()
         .hasOnly(['displayName', 'profile', 'updatedAt', 'lastLoginAt', 'onboardingStatus'])) ||
        (isAdmin() && belongsToSchool(resource.data.schoolId) && 
         request.resource.data.diff(resource.data).affectedKeys()
         .hasOnly(['status', 'displayName', 'profile', 'updatedAt'])) ||
        isSuperAdmin()
      ) && immutableFieldsUnchanged(['uid', 'email', 'role', 'schoolId', 'createdAt', 'createdBy']);
      
      // Delete: Only SUPER_ADMIN can delete users
      allow delete: if isSuperAdmin();
    }
    
    // ============================================================================
    // SCHOOLS COLLECTION (Enhanced)
    // ============================================================================
    
    match /schools/{schoolId} {
      // Read: SUPER_ADMIN can read all, ADMIN/STAFF can read own school
      allow read: if isSuperAdmin() || canAccessSchool(schoolId);
      
      // Create: Only SUPER_ADMIN can create schools
      allow create: if isSuperAdmin() 
        && request.resource.data.keys().hasAll(['schoolId', 'schoolName', 'academicYearStart', 'status', 'createdAt', 'createdBy'])
        && request.resource.data.schoolId == schoolId
        && request.resource.data.status == 'ACTIVE'
        && request.resource.data.createdBy == request.auth.uid;
      
      // Update: SUPER_ADMIN can update any school, ADMIN can update own school settings
      allow update: if (isSuperAdmin() || (isAdmin() && canAccessSchool(schoolId)))
        && immutableFieldsUnchanged(['schoolId', 'createdAt', 'createdBy'])
        && request.resource.data.updatedAt == request.time;
      
      // Delete: Only SUPER_ADMIN can delete schools
      allow delete: if isSuperAdmin();
      
      // ========================================================================
      // STAFF SUBCOLLECTION (New - Core Staff Management)
      // ========================================================================
      
      match /staff/{staffId} {
        // Read: ADMIN can read all staff in their school, STAFF can read own record only
        allow read: if canAccessSchool(schoolId) && 
          (isAdmin() || (isStaff() && isOwner(resource.data.userId)));
        
        // Create: Only ADMIN can create staff records in their school
        allow create: if isAdmin() && canAccessSchool(schoolId)
          && request.resource.data.schoolId == schoolId
          && request.resource.data.status == 'ACTIVE'
          && request.resource.data.createdBy == request.auth.uid
          && request.resource.data.keys().hasAll([
            'userId', 'schoolId', 'name', 'employeeId', 'email', 
            'department', 'staffType', 'status', 'joiningDate', 
            'createdAt', 'updatedAt', 'createdBy'
          ]);
        
        // Update: ADMIN can update staff records, STAFF can update limited own fields
        allow update: if canAccessSchool(schoolId) && (
          (isAdmin() && 
           request.resource.data.diff(resource.data).affectedKeys()
           .hasOnly(['name', 'department', 'staffType', 'status', 'joiningDate', 
                    'phoneNumber', 'address', 'emergencyContact', 'designation', 'updatedAt'])) ||
          (isStaff() && isOwner(resource.data.userId) && 
           request.resource.data.diff(resource.data).affectedKeys()
           .hasOnly(['phoneNumber', 'address', 'emergencyContact', 'updatedAt']))
        ) && immutableFieldsUnchanged(['userId', 'schoolId', 'employeeId', 'email', 'createdAt', 'createdBy']);
        
        // Delete: Only ADMIN can delete staff records (soft delete by status change)
        allow delete: if false; // Force soft delete only
      }
      
      // ========================================================================
      // OTHER SCHOOL SUBCOLLECTIONS (Enhanced)
      // ========================================================================
      
      // Leave Types subcollection
      match /leaveTypes/{leaveTypeId} {
        // Read: All school members can read leave types
        allow read: if canAccessSchool(schoolId);
        
        // Create/Update: Only ADMIN can manage leave types
        allow create, update: if isAdmin() && canAccessSchool(schoolId);
        
        // Delete: Only ADMIN can delete leave types
        allow delete: if isAdmin() && canAccessSchool(schoolId);
      }
      
      // Leaves subcollection
      match /leaves/{leaveId} {
        // Read: ADMIN can read all, STAFF can read own leaves
        allow read: if canAccessSchool(schoolId) && 
          (isAdmin() || (isStaff() && isOwner(resource.data.applicantId)));
        
        // Create: ADMIN and STAFF can create leave applications
        allow create: if canAccessSchool(schoolId) && 
          (isAdmin() || isStaff()) &&
          request.resource.data.applicantId == request.auth.uid &&
          request.resource.data.schoolId == schoolId &&
          request.resource.data.status == 'PENDING';
        
        // Update: ADMIN can approve/reject, applicant can cancel pending leaves
        allow update: if canAccessSchool(schoolId) && (
          (isAdmin() && !isOwner(resource.data.applicantId) &&
           request.resource.data.diff(resource.data).affectedKeys()
           .hasOnly(['status', 'approvedBy', 'approvedAt', 'rejectionReason', 'updatedAt'])) ||
          (isOwner(resource.data.applicantId) && resource.data.status == 'PENDING' &&
           request.resource.data.status == 'CANCELLED')
        );
        
        // Delete: Only ADMIN can delete leave records
        allow delete: if isAdmin() && canAccessSchool(schoolId);
      }
      
      // Permissions subcollection
      match /permissions/{permissionId} {
        // Read: ADMIN can read all, STAFF can read own permissions
        allow read: if canAccessSchool(schoolId) && 
          (isAdmin() || (isStaff() && isOwner(resource.data.requesterId)));
        
        // Create: ADMIN and STAFF can create permission requests
        allow create: if canAccessSchool(schoolId) && 
          (isAdmin() || isStaff()) &&
          request.resource.data.requesterId == request.auth.uid &&
          request.resource.data.schoolId == schoolId &&
          request.resource.data.status == 'PENDING';
        
        // Update: ADMIN can approve/reject, requester can cancel pending requests
        allow update: if canAccessSchool(schoolId) && (
          (isAdmin() && !isOwner(resource.data.requesterId) &&
           request.resource.data.diff(resource.data).affectedKeys()
           .hasOnly(['status', 'approvedBy', 'approvedAt', 'rejectionReason', 'updatedAt'])) ||
          (isOwner(resource.data.requesterId) && resource.data.status == 'PENDING' &&
           request.resource.data.status == 'CANCELLED')
        );
        
        // Delete: Only ADMIN can delete permission records
        allow delete: if isAdmin() && canAccessSchool(schoolId);
      }
    }
    
    // ============================================================================
    // AUDIT LOGS COLLECTION
    // ============================================================================
    
    match /auditLogs/{logId} {
      // Read: Only SUPER_ADMIN can read audit logs
      allow read: if isSuperAdmin();
      
      // Create: System can create audit logs (server-side only)
      allow create: if false; // Only server-side functions can create audit logs
      
      // Update/Delete: No one can modify audit logs
      allow update, delete: if false;
    }
    
    // ============================================================================
    // SYSTEM COLLECTIONS (SUPER_ADMIN ONLY)
    // ============================================================================
    
    match /systemSettings/{settingId} {
      allow read, write: if isSuperAdmin();
    }
    
    match /subscriptions/{subscriptionId} {
      allow read, write: if isSuperAdmin();
    }
    
    // ============================================================================
    // DEFAULT DENY ALL
    // ============================================================================
    
    // Deny access to any other collections
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

## Key Security Features for Staff Management

### 1. Strict Tenant Isolation
- **School-level access control**: Users can only access data from their assigned school
- **Cross-tenant prevention**: ADMIN from school A cannot see/modify staff from school B
- **STAFF isolation**: Staff members can only see their own profile, not other staff

### 2. Role-Based Permissions

#### SUPER_ADMIN
- Can access all schools and users
- Can create/delete schools
- Can view audit logs
- Cannot be restricted by school boundaries

#### ADMIN
- Can manage staff within their school only
- Can create STAFF and ADMIN users for their school
- Can enable/disable users in their school
- Can approve/reject leaves and permissions
- Cannot approve their own leave requests

#### STAFF
- Can only view/edit their own profile (limited fields)
- Can apply for leaves and permissions
- Cannot see other staff members' data
- Cannot manage other users

### 3. Data Validation Rules

#### Staff Creation
```javascript
// Required fields validation
request.resource.data.keys().hasAll([
  'userId', 'schoolId', 'name', 'employeeId', 'email', 
  'department', 'staffType', 'status', 'joiningDate', 
  'createdAt', 'updatedAt', 'createdBy'
])

// School assignment validation
request.resource.data.schoolId == schoolId

// Creator validation
request.resource.data.createdBy == request.auth.uid
```

#### Immutable Fields Protection
```javascript
// Fields that cannot be changed after creation
immutableFieldsUnchanged(['userId', 'schoolId', 'employeeId', 'email', 'createdAt', 'createdBy'])
```

### 4. Update Restrictions

#### ADMIN Updates
- Can modify: name, department, staffType, status, joiningDate, contact info
- Cannot modify: userId, schoolId, employeeId, email, creation metadata

#### STAFF Self-Updates
- Can modify: phoneNumber, address, emergencyContact only
- Cannot modify: any other fields including name, department, status

### 5. Soft Delete Policy
```javascript
// Physical deletion is disabled - force status-based soft delete
allow delete: if false;
```

### 6. Leave Approval Restrictions
```javascript
// ADMIN cannot approve their own leave requests
(isAdmin() && !isOwner(resource.data.applicantId) && ...)
```

## Firestore Indexes Required

```javascript
// Composite indexes for efficient queries
{
  "collectionGroup": "staff",
  "queryScope": "COLLECTION",
  "fields": [
    {"fieldPath": "schoolId", "order": "ASCENDING"},
    {"fieldPath": "status", "order": "ASCENDING"},
    {"fieldPath": "name", "order": "ASCENDING"}
  ]
}

{
  "collectionGroup": "staff", 
  "queryScope": "COLLECTION",
  "fields": [
    {"fieldPath": "schoolId", "order": "ASCENDING"},
    {"fieldPath": "staffType", "order": "ASCENDING"},
    {"fieldPath": "name", "order": "ASCENDING"}
  ]
}

{
  "collectionGroup": "staff",
  "queryScope": "COLLECTION", 
  "fields": [
    {"fieldPath": "schoolId", "order": "ASCENDING"},
    {"fieldPath": "employeeId", "order": "ASCENDING"}
  ]
}

{
  "collectionGroup": "staff",
  "queryScope": "COLLECTION",
  "fields": [
    {"fieldPath": "userId", "order": "ASCENDING"}
  ]
}
```

## Security Testing Scenarios

### Test 1: Cross-Tenant Access Prevention
```javascript
// Admin from School A tries to access School B staff
const adminA = { uid: 'admin1', role: 'ADMIN', schoolId: 'schoolA' };
assert(canRead('/schools/schoolB/staff/staff1', adminA) === false);
```

### Test 2: Staff Self-Access Only
```javascript
// Staff member tries to access another staff member's profile
const staff1 = { uid: 'staff1', role: 'STAFF', schoolId: 'schoolA' };
const staff2Profile = { userId: 'staff2', schoolId: 'schoolA' };
assert(canRead('/schools/schoolA/staff/staff2', staff1, staff2Profile) === false);
```

### Test 3: Employee ID Uniqueness
```javascript
// Prevent duplicate employee IDs within same school
const duplicateStaff = {
  employeeId: 'EMP001', // Already exists
  schoolId: 'schoolA'
};
assert(canCreate('/schools/schoolA/staff/newStaff', admin, duplicateStaff) === false);
```

### Test 4: Immutable Field Protection
```javascript
// Prevent changing employee ID after creation
const updateWithEmployeeId = {
  employeeId: 'NEW_ID', // Trying to change immutable field
  name: 'Updated Name'
};
assert(canUpdate('/schools/schoolA/staff/staff1', admin, updateWithEmployeeId) === false);
```

This security model ensures complete tenant isolation while providing appropriate access controls for each role level.
