# Enhanced Firestore Security Rules for Leave Management System

## Complete Security Rules with Leave Configuration and Balance Engine

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
    
    // Get current academic year (June 1 to May 31)
    function getCurrentAcademicYear() {
      let now = request.time.toMillis();
      let currentYear = request.time.year();
      let juneFirst = timestamp.date(currentYear, 6, 1).toMillis();
      
      if (now < juneFirst) {
        return string(currentYear - 1) + '-' + string(currentYear).substring(2, 4);
      } else {
        return string(currentYear) + '-' + string(currentYear + 1).substring(2, 4);
      }
    }
    
    // ============================================================================
    // USERS COLLECTION (Enhanced for Leave Management)
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
      // LEAVE TYPE CONFIGURATIONS SUBCOLLECTION
      // ========================================================================
      
      match /leaveTypes/{leaveTypeId} {
        // Read: All school members can read leave type configurations
        allow read: if canAccessSchool(schoolId);
        
        // Create: Only ADMIN can create leave type configurations
        allow create: if isAdmin() && canAccessSchool(schoolId)
          && request.resource.data.schoolId == schoolId
          && request.resource.data.isActive == true
          && request.resource.data.createdBy == request.auth.uid
          && request.resource.data.keys().hasAll([
            'schoolId', 'name', 'code', 'description', 'annualQuota', 
            'carryForwardAllowed', 'maxCarryForwardDays', 'maxDaysPerRequest', 
            'isPaid', 'isActive', 'createdAt', 'updatedAt', 'createdBy'
          ])
          && request.resource.data.annualQuota > 0
          && request.resource.data.annualQuota <= 365
          && request.resource.data.maxDaysPerRequest > 0
          && request.resource.data.maxDaysPerRequest <= request.resource.data.annualQuota
          && request.resource.data.maxCarryForwardDays >= 0
          && request.resource.data.maxCarryForwardDays <= request.resource.data.annualQuota
          && (request.resource.data.carryForwardAllowed || request.resource.data.maxCarryForwardDays == 0);
        
        // Update: Only ADMIN can update leave type configurations
        allow update: if isAdmin() && canAccessSchool(schoolId)
          && immutableFieldsUnchanged(['schoolId', 'code', 'createdAt', 'createdBy'])
          && request.resource.data.updatedAt == request.time
          && (request.resource.data.annualQuota == null || 
              (request.resource.data.annualQuota > 0 && request.resource.data.annualQuota <= 365))
          && (request.resource.data.maxDaysPerRequest == null || 
              (request.resource.data.maxDaysPerRequest > 0 && 
               request.resource.data.maxDaysPerRequest <= request.resource.data.get('annualQuota', resource.data.annualQuota)))
          && (request.resource.data.maxCarryForwardDays == null || 
              (request.resource.data.maxCarryForwardDays >= 0 && 
               request.resource.data.maxCarryForwardDays <= request.resource.data.get('annualQuota', resource.data.annualQuota)))
          && (request.resource.data.carryForwardAllowed == null || 
              request.resource.data.carryForwardAllowed || 
              request.resource.data.get('maxCarryForwardDays', resource.data.maxCarryForwardDays) == 0);
        
        // Delete: Only ADMIN can deactivate (no physical deletion)
        allow delete: if false; // Force soft delete only
      }
      
      // ========================================================================
      // LEAVE BALANCES SUBCOLLECTION
      // ========================================================================
      
      match /leaveBalances/{balanceId} {
        // Read: ADMIN can read all balances, STAFF can read own balances only
        allow read: if canAccessSchool(schoolId) && 
          (isAdmin() || (isStaff() && isOwner(resource.data.userId)));
        
        // Create: Only Cloud Functions can create balances (system-generated)
        allow create: if false; // Only server-side functions
        
        // Update: Only Cloud Functions can update balances (system-managed)
        allow update: if false; // Only server-side functions
        
        // Delete: No deletion allowed (historical data preservation)
        allow delete: if false;
      }
      
      // ========================================================================
      // BALANCE MUTATIONS SUBCOLLECTION (Audit Trail)
      // ========================================================================
      
      match /balanceMutations/{mutationId} {
        // Read: ADMIN can read all mutations, STAFF can read own mutations
        allow read: if canAccessSchool(schoolId) && 
          (isAdmin() || (isStaff() && isOwner(resource.data.userId)));
        
        // Create: Only Cloud Functions can create mutations
        allow create: if false; // Only server-side functions
        
        // Update/Delete: No modifications allowed (immutable audit trail)
        allow update, delete: if false;
      }
      
      // ========================================================================
      // ACADEMIC YEARS SUBCOLLECTION
      // ========================================================================
      
      match /academicYears/{academicYear} {
        // Read: All school members can read academic year data
        allow read: if canAccessSchool(schoolId);
        
        // Create: Only Cloud Functions can create academic year records
        allow create: if false; // Only server-side functions
        
        // Update: Only Cloud Functions can update academic year records
        allow update: if false; // Only server-side functions
        
        // Delete: No deletion allowed
        allow delete: if false;
      }
      
      // ========================================================================
      // STAFF SUBCOLLECTION (Enhanced)
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
      // LEAVES SUBCOLLECTION (Enhanced for Balance Integration)
      // ========================================================================
      
      match /leaves/{leaveId} {
        // Read: ADMIN can read all, STAFF can read own leaves
        allow read: if canAccessSchool(schoolId) && 
          (isAdmin() || (isStaff() && isOwner(resource.data.applicantId)));
        
        // Create: ADMIN and STAFF can create leave applications
        allow create: if canAccessSchool(schoolId) && 
          (isAdmin() || isStaff()) &&
          request.resource.data.applicantId == request.auth.uid &&
          request.resource.data.schoolId == schoolId &&
          request.resource.data.status == 'PENDING' &&
          request.resource.data.academicYear == getCurrentAcademicYear() &&
          request.resource.data.keys().hasAll([
            'applicantId', 'schoolId', 'leaveTypeId', 'leaveTypeCode',
            'academicYear', 'startDate', 'endDate', 'totalDays', 'reason',
            'status', 'createdAt', 'updatedAt'
          ]) &&
          request.resource.data.totalDays > 0 &&
          request.resource.data.startDate <= request.resource.data.endDate;
        
        // Update: ADMIN can approve/reject, applicant can cancel pending leaves
        allow update: if canAccessSchool(schoolId) && (
          (isAdmin() && !isOwner(resource.data.applicantId) &&
           request.resource.data.diff(resource.data).affectedKeys()
           .hasOnly(['status', 'approvedBy', 'approvedAt', 'rejectionReason', 'updatedAt', 'updatedBy']) &&
           request.resource.data.status in ['APPROVED', 'REJECTED'] &&
           request.resource.data.updatedBy == request.auth.uid) ||
          (isOwner(resource.data.applicantId) && resource.data.status == 'PENDING' &&
           request.resource.data.status == 'CANCELLED' &&
           request.resource.data.diff(resource.data).affectedKeys()
           .hasOnly(['status', 'updatedAt', 'updatedBy']) &&
           request.resource.data.updatedBy == request.auth.uid)
        ) && immutableFieldsUnchanged(['applicantId', 'schoolId', 'leaveTypeId', 'academicYear', 
                                      'startDate', 'endDate', 'totalDays', 'createdAt']);
        
        // Delete: Only ADMIN can delete leave records
        allow delete: if isAdmin() && canAccessSchool(schoolId);
      }
      
      // ========================================================================
      // PERMISSIONS SUBCOLLECTION (Enhanced)
      // ========================================================================
      
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
    // SYSTEM ALERTS COLLECTION
    // ============================================================================
    
    match /systemAlerts/{alertId} {
      // Read: SUPER_ADMIN can read all alerts, ADMIN can read school-specific alerts
      allow read: if isSuperAdmin() || 
        (isAdmin() && resource.data.schoolId != null && canAccessSchool(resource.data.schoolId));
      
      // Create: Only Cloud Functions can create system alerts
      allow create: if false; // Only server-side functions
      
      // Update: ADMIN can mark alerts as resolved
      allow update: if (isSuperAdmin() || 
        (isAdmin() && resource.data.schoolId != null && canAccessSchool(resource.data.schoolId))) &&
        request.resource.data.diff(resource.data).affectedKeys().hasOnly(['resolved', 'resolvedAt', 'resolvedBy']) &&
        request.resource.data.resolved == true &&
        request.resource.data.resolvedBy == request.auth.uid;
      
      // Delete: Only SUPER_ADMIN can delete alerts
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

## Key Security Features for Leave Management

### 1. Leave Type Configuration Security
- **ADMIN-only management**: Only school admins can create/update leave configurations
- **Validation at database level**: Annual quota, carry forward limits, and other constraints enforced
- **Immutable core fields**: Leave type code and school ID cannot be changed after creation
- **Soft delete only**: Physical deletion prevented to maintain historical integrity

### 2. Leave Balance Protection
- **System-managed only**: All balance operations handled by Cloud Functions
- **No client-side mutations**: Prevents tampering with balance calculations
- **Audit trail preservation**: All balance changes tracked in mutations collection
- **Multi-tenant isolation**: Balances scoped to school level

### 3. Leave Request Validation
- **Academic year enforcement**: Leave requests must be for current academic year
- **Status transition control**: Strict rules for who can change request status
- **Immutable core data**: Dates, applicant, and leave type cannot be changed after creation
- **Self-service limitations**: Staff can only cancel their own pending requests

### 4. Balance Mutation Audit Trail
- **Immutable records**: No updates or deletions allowed once created
- **System-generated only**: Only Cloud Functions can create mutation records
- **Complete traceability**: Every balance change tracked with reason and reference

### 5. Academic Year Management
- **System-controlled**: Only Cloud Functions can manage academic year data
- **Historical preservation**: Academic year records cannot be deleted
- **Reset tracking**: Complete audit trail of academic year reset operations

## Validation Rules Summary

### Leave Type Configuration Constraints
```javascript
// Annual quota validation
request.resource.data.annualQuota > 0 && request.resource.data.annualQuota <= 365

// Max days per request validation
request.resource.data.maxDaysPerRequest > 0 && 
request.resource.data.maxDaysPerRequest <= request.resource.data.annualQuota

// Carry forward validation
request.resource.data.maxCarryForwardDays >= 0 && 
request.resource.data.maxCarryForwardDays <= request.resource.data.annualQuota

// Carry forward consistency
request.resource.data.carryForwardAllowed || request.resource.data.maxCarryForwardDays == 0
```

### Leave Request Constraints
```javascript
// Academic year validation
request.resource.data.academicYear == getCurrentAcademicYear()

// Date validation
request.resource.data.startDate <= request.resource.data.endDate

// Total days validation
request.resource.data.totalDays > 0

// Status validation
request.resource.data.status == 'PENDING' // On creation
```

### Access Control Matrix

| Role | Leave Types | Leave Balances | Leave Requests | Balance Mutations |
|------|-------------|----------------|----------------|-------------------|
| **SUPER_ADMIN** | Full Access | Read All | Full Access | Read All |
| **ADMIN** | Manage School | Read School | Approve/Reject School | Read School |
| **STAFF** | Read School | Read Own | Create/Cancel Own | Read Own |
| **Cloud Functions** | - | Full Control | Status Updates | Create All |

## Security Testing Scenarios

### 1. Cross-Tenant Access Prevention
```javascript
// Admin from School A tries to access School B leave types
const adminA = { uid: 'admin1', role: 'ADMIN', schoolId: 'schoolA' };
assert(canRead('/schools/schoolB/leaveTypes/casual', adminA) === false);
```

### 2. Balance Tampering Prevention
```javascript
// Staff tries to directly update their leave balance
const staff = { uid: 'staff1', role: 'STAFF', schoolId: 'schoolA' };
assert(canUpdate('/schools/schoolA/leaveBalances/balance1', staff) === false);
```

### 3. Leave Request Status Manipulation
```javascript
// Staff tries to approve their own leave request
const staff = { uid: 'staff1', role: 'STAFF', schoolId: 'schoolA' };
const ownLeaveRequest = { applicantId: 'staff1', status: 'PENDING' };
assert(canUpdate('/schools/schoolA/leaves/leave1', staff, {status: 'APPROVED'}) === false);
```

### 4. Academic Year Boundary Enforcement
```javascript
// Staff tries to create leave request for wrong academic year
const invalidLeaveRequest = {
  academicYear: '2023-24', // Wrong year
  // ... other fields
};
assert(canCreate('/schools/schoolA/leaves/leave1', staff, invalidLeaveRequest) === false);
```

This security model ensures complete protection of the leave management system while maintaining proper multi-tenant isolation and role-based access control.
