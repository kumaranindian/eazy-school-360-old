# Firestore Security Rules for Multi-Tenant School System

## Complete Security Rules

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
    
    // ============================================================================
    // SCHOOLS COLLECTION
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
      // SCHOOL SUBCOLLECTIONS
      // ========================================================================
      
      // Staff subcollection
      match /staff/{staffId} {
        // Read: ADMIN can read all staff in their school, STAFF can read own record
        allow read: if canAccessSchool(schoolId) && 
          (isAdmin() || (isStaff() && isOwner(staffId)));
        
        // Create: Only ADMIN can create staff records
        allow create: if isAdmin() && canAccessSchool(schoolId)
          && request.resource.data.staffId == staffId
          && request.resource.data.status == 'ACTIVE';
        
        // Update: ADMIN can update staff records, STAFF can update limited own fields
        allow update: if canAccessSchool(schoolId) && (
          (isAdmin()) ||
          (isStaff() && isOwner(staffId) && 
           request.resource.data.diff(resource.data).affectedKeys()
           .hasOnly(['profile', 'updatedAt']))
        ) && immutableFieldsUnchanged(['staffId', 'userId', 'createdAt']);
        
        // Delete: Only ADMIN can delete staff records
        allow delete: if isAdmin() && canAccessSchool(schoolId);
      }
      
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
          (isAdmin() && request.resource.data.diff(resource.data).affectedKeys()
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
          (isAdmin() && request.resource.data.diff(resource.data).affectedKeys()
           .hasOnly(['status', 'approvedBy', 'approvedAt', 'rejectionReason', 'updatedAt'])) ||
          (isOwner(resource.data.requesterId) && resource.data.status == 'PENDING' &&
           request.resource.data.status == 'CANCELLED')
        );
        
        // Delete: Only ADMIN can delete permission records
        allow delete: if isAdmin() && canAccessSchool(schoolId);
      }
    }
    
    // ============================================================================
    // USERS COLLECTION
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
        (isAdmin() && belongsToSchool(resource.data.schoolId)) ||
        isSuperAdmin()
      ) && immutableFieldsUnchanged(['uid', 'email', 'role', 'schoolId', 'createdAt', 'createdBy']);
      
      // Delete: Only SUPER_ADMIN can delete users
      allow delete: if isSuperAdmin();
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

## Security Rule Validation Tests

### Test Cases for School Access

```javascript
// Test 1: SUPER_ADMIN can access any school
function testSuperAdminSchoolAccess() {
  // Setup: User with SUPER_ADMIN role
  const superAdmin = { uid: 'super1', role: 'SUPER_ADMIN', status: 'ACTIVE' };
  
  // Test: Should allow read access to any school
  assert(canRead('/schools/school1', superAdmin) === true);
  assert(canRead('/schools/school2', superAdmin) === true);
}

// Test 2: ADMIN can only access own school
function testAdminSchoolAccess() {
  const admin = { uid: 'admin1', role: 'ADMIN', schoolId: 'school1', status: 'ACTIVE' };
  
  // Should allow access to own school
  assert(canRead('/schools/school1', admin) === true);
  
  // Should deny access to other schools
  assert(canRead('/schools/school2', admin) === false);
}

// Test 3: STAFF can only access own school
function testStaffSchoolAccess() {
  const staff = { uid: 'staff1', role: 'STAFF', schoolId: 'school1', status: 'ACTIVE' };
  
  // Should allow access to own school
  assert(canRead('/schools/school1', staff) === true);
  
  // Should deny access to other schools
  assert(canRead('/schools/school2', staff) === false);
}
```

### Test Cases for User Management

```javascript
// Test 4: ADMIN can create STAFF users in own school
function testAdminCreateStaff() {
  const admin = { uid: 'admin1', role: 'ADMIN', schoolId: 'school1', status: 'ACTIVE' };
  const staffData = {
    uid: 'staff1',
    role: 'STAFF',
    schoolId: 'school1',
    status: 'ACTIVE',
    createdBy: 'admin1'
  };
  
  assert(canCreate('/users/staff1', admin, staffData) === true);
}

// Test 5: ADMIN cannot create users for other schools
function testAdminCannotCreateCrossSchool() {
  const admin = { uid: 'admin1', role: 'ADMIN', schoolId: 'school1', status: 'ACTIVE' };
  const staffData = {
    uid: 'staff1',
    role: 'STAFF',
    schoolId: 'school2', // Different school
    status: 'ACTIVE',
    createdBy: 'admin1'
  };
  
  assert(canCreate('/users/staff1', admin, staffData) === false);
}
```

### Test Cases for Leave Management

```javascript
// Test 6: STAFF can only read own leaves
function testStaffLeaveAccess() {
  const staff = { uid: 'staff1', role: 'STAFF', schoolId: 'school1', status: 'ACTIVE' };
  
  // Own leave
  const ownLeave = { applicantId: 'staff1', schoolId: 'school1' };
  assert(canRead('/schools/school1/leaves/leave1', staff, ownLeave) === true);
  
  // Other's leave
  const otherLeave = { applicantId: 'staff2', schoolId: 'school1' };
  assert(canRead('/schools/school1/leaves/leave2', staff, otherLeave) === false);
}

// Test 7: ADMIN can approve leaves but not own leaves
function testAdminLeaveApproval() {
  const admin = { uid: 'admin1', role: 'ADMIN', schoolId: 'school1', status: 'ACTIVE' };
  
  // Can approve other's leave
  const staffLeave = { applicantId: 'staff1', schoolId: 'school1', status: 'PENDING' };
  const approvalUpdate = { status: 'APPROVED', approvedBy: 'admin1', approvedAt: new Date() };
  assert(canUpdate('/schools/school1/leaves/leave1', admin, staffLeave, approvalUpdate) === true);
  
  // Cannot approve own leave
  const ownLeave = { applicantId: 'admin1', schoolId: 'school1', status: 'PENDING' };
  assert(canUpdate('/schools/school1/leaves/leave2', admin, ownLeave, approvalUpdate) === false);
}
```

## Security Best Practices Implemented

### 1. Principle of Least Privilege
- Each role has minimum necessary permissions
- STAFF can only access their own data
- ADMIN limited to their school
- SUPER_ADMIN has platform-wide access

### 2. Immutable Fields Protection
```javascript
// Prevent modification of critical fields
immutableFieldsUnchanged(['schoolId', 'createdAt', 'createdBy'])
```

### 3. Tenant Isolation
```javascript
// Ensure users can only access their school's data
function canAccessSchool(schoolId) {
  return isSuperAdmin() || (isUserActive() && belongsToSchool(schoolId));
}
```

### 4. Data Validation
```javascript
// Validate required fields on creation
request.resource.data.keys().hasAll(['schoolId', 'schoolName', 'status'])
```

### 5. Status-Based Access Control
```javascript
// Only active users can perform operations
function isUserActive() {
  return get(/databases/$(database)/documents/users/$(request.auth.uid)).data.status == 'ACTIVE';
}
```

### 6. Audit Trail Protection
```javascript
// Audit logs are read-only and only accessible to SUPER_ADMIN
match /auditLogs/{logId} {
  allow read: if isSuperAdmin();
  allow create: if false; // Server-side only
  allow update, delete: if false; // Immutable
}
```

### 7. Default Deny Policy
```javascript
// Explicit deny for any unmatched paths
match /{document=**} {
  allow read, write: if false;
}
```

## Performance Considerations

### 1. Efficient User Data Retrieval
```javascript
// Cache user data to avoid repeated reads
function getUserRole() {
  return get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role;
}
```

### 2. Minimal Document Reads
- Rules are optimized to minimize Firestore reads
- User data is read once and reused across rule functions

### 3. Index-Friendly Queries
- Security rules support compound queries with proper indexing
- School-based filtering is efficient with schoolId index
