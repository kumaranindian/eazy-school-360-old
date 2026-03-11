# FINAL PRODUCTION FIRESTORE SECURITY RULES
## Multi-Tenant School Staff Leave & Permission Management System

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // ============================================================================
    // HELPER FUNCTIONS - STRICT TENANT ISOLATION
    // ============================================================================
    
    function isAuthenticated() {
      return request.auth != null;
    }
    
    function getUserRole() {
      return get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role;
    }
    
    function getUserSchoolId() {
      return get(/databases/$(database)/documents/users/$(request.auth.uid)).data.schoolId;
    }
    
    function isUserActive() {
      return get(/databases/$(database)/documents/users/$(request.auth.uid)).data.status == 'ACTIVE';
    }
    
    function isSuperAdmin() {
      return isAuthenticated() && getUserRole() == 'SUPER_ADMIN';
    }
    
    function isAdmin() {
      return isAuthenticated() && getUserRole() == 'ADMIN';
    }
    
    function isStaff() {
      return isAuthenticated() && getUserRole() == 'STAFF';
    }
    
    function belongsToSchool(schoolId) {
      return getUserSchoolId() == schoolId;
    }
    
    function canAccessSchool(schoolId) {
      return isSuperAdmin() || (isUserActive() && belongsToSchool(schoolId));
    }
    
    function isOwner(resourceUserId) {
      return request.auth.uid == resourceUserId;
    }
    
    function immutableFieldsUnchanged(immutableFields) {
      return immutableFields.diff(resource.data).unchangedKeys().hasAll(immutableFields);
    }
    
    // ============================================================================
    // USERS COLLECTION - STRICT ACCESS CONTROL
    // ============================================================================
    
    match /users/{userId} {
      allow read: if isOwner(userId) || 
        (isAdmin() && belongsToSchool(resource.data.schoolId)) ||
        isSuperAdmin();
      
      allow create: if (
        (isSuperAdmin() && request.resource.data.role in ['SUPER_ADMIN', 'ADMIN']) ||
        (isAdmin() && request.resource.data.role == 'STAFF' && 
         belongsToSchool(request.resource.data.schoolId))
      ) && request.resource.data.uid == userId;
      
      allow update: if (
        (isOwner(userId) && 
         request.resource.data.diff(resource.data).affectedKeys()
         .hasOnly(['displayName', 'profile', 'updatedAt', 'lastLoginAt', 'fcmToken', 'fcmTokenUpdatedAt'])) ||
        (isAdmin() && belongsToSchool(resource.data.schoolId) && 
         request.resource.data.diff(resource.data).affectedKeys()
         .hasOnly(['status', 'displayName', 'profile', 'updatedAt'])) ||
        isSuperAdmin()
      ) && immutableFieldsUnchanged(['uid', 'email', 'role', 'schoolId', 'createdAt', 'createdBy']);
      
      allow delete: if isSuperAdmin();
    }
    
    // ============================================================================
    // SCHOOLS COLLECTION - TENANT ROOT
    // ============================================================================
    
    match /schools/{schoolId} {
      allow read: if canAccessSchool(schoolId);
      allow create: if isSuperAdmin();
      allow update: if isSuperAdmin() || (isAdmin() && canAccessSchool(schoolId));
      allow delete: if isSuperAdmin();
      
      // ========================================================================
      // HOLIDAYS SUBCOLLECTION - TENANT SCOPED
      // ========================================================================
      
      match /holidays/{holidayId} {
        allow read: if canAccessSchool(schoolId);
        allow create: if isAdmin() && canAccessSchool(schoolId)
          && request.resource.data.schoolId == schoolId
          && request.resource.data.createdBy == request.auth.uid;
        allow update: if isAdmin() && canAccessSchool(schoolId)
          && immutableFieldsUnchanged(['schoolId', 'createdAt', 'createdBy']);
        allow delete: if isAdmin() && canAccessSchool(schoolId);
      }
      
      // ========================================================================
      // WEEKEND CONFIGURATION SUBCOLLECTION
      // ========================================================================
      
      match /weekendConfig/{configId} {
        allow read: if canAccessSchool(schoolId);
        allow write: if isAdmin() && canAccessSchool(schoolId)
          && request.resource.data.schoolId == schoolId;
      }
      
      // ========================================================================
      // LEAVE TYPE CONFIGURATIONS - ADMIN ONLY
      // ========================================================================
      
      match /leaveTypes/{leaveTypeId} {
        allow read: if canAccessSchool(schoolId);
        allow create: if isAdmin() && canAccessSchool(schoolId)
          && request.resource.data.schoolId == schoolId
          && request.resource.data.createdBy == request.auth.uid;
        allow update: if isAdmin() && canAccessSchool(schoolId)
          && immutableFieldsUnchanged(['schoolId', 'code', 'createdAt', 'createdBy']);
        allow delete: if false; // Force soft delete only
      }
      
      // ========================================================================
      // LEAVE BALANCES - BACKEND ONLY (NO CLIENT UPDATES)
      // ========================================================================
      
      match /leaveBalances/{balanceId} {
        allow read: if canAccessSchool(schoolId) && 
          (isAdmin() || (isStaff() && isOwner(resource.data.userId)));
        allow create, update, delete: if false; // BACKEND ONLY
      }
      
      // ========================================================================
      // BALANCE MUTATIONS - IMMUTABLE AUDIT TRAIL
      // ========================================================================
      
      match /balanceMutations/{mutationId} {
        allow read: if canAccessSchool(schoolId) && 
          (isAdmin() || (isStaff() && isOwner(resource.data.userId)));
        allow create, update, delete: if false; // BACKEND ONLY
      }
      
      // ========================================================================
      // LEAVE APPLICATIONS - CONTROLLED ACCESS
      // ========================================================================
      
      match /leaves/{leaveId} {
        allow read: if canAccessSchool(schoolId) && 
          (isAdmin() || (isStaff() && isOwner(resource.data.applicantId)));
        
        allow create: if canAccessSchool(schoolId) && 
          (isAdmin() || isStaff()) &&
          request.resource.data.applicantId == request.auth.uid &&
          request.resource.data.schoolId == schoolId &&
          request.resource.data.status == 'PENDING';
        
        allow update: if canAccessSchool(schoolId) && (
          (isAdmin() && !isOwner(resource.data.applicantId) &&
           request.resource.data.diff(resource.data).affectedKeys()
           .hasOnly(['status', 'approvedBy', 'approvedAt', 'rejectionReason', 'updatedAt', 'updatedBy'])) ||
          (isOwner(resource.data.applicantId) && resource.data.status == 'PENDING' &&
           request.resource.data.status == 'CANCELLED')
        ) && immutableFieldsUnchanged(['applicantId', 'schoolId', 'leaveTypeId', 'academicYear', 
                                      'startDate', 'endDate', 'totalDays', 'createdAt']);
        
        allow delete: if isAdmin() && canAccessSchool(schoolId);
      }
      
      // ========================================================================
      // LEAVE CANCELLATIONS - CONTROLLED ACCESS
      // ========================================================================
      
      match /leaveCancellations/{cancellationId} {
        allow read: if canAccessSchool(schoolId) && 
          (isAdmin() || (isStaff() && isOwner(resource.data.applicantId)));
        
        allow create: if canAccessSchool(schoolId) && isStaff() &&
          request.resource.data.applicantId == request.auth.uid &&
          request.resource.data.schoolId == schoolId &&
          request.resource.data.status == 'PENDING';
        
        allow update: if isAdmin() && canAccessSchool(schoolId) &&
          request.resource.data.diff(resource.data).affectedKeys()
          .hasOnly(['status', 'approvedBy', 'approvedAt', 'rejectionReason', 'adminRemarks', 'updatedAt']) &&
          immutableFieldsUnchanged(['schoolId', 'leaveApplicationId', 'applicantId', 'createdAt']);
        
        allow delete: if false; // No deletion allowed
      }
      
      // ========================================================================
      // PERMISSION REQUESTS - CONTROLLED ACCESS
      // ========================================================================
      
      match /permissions/{permissionId} {
        allow read: if canAccessSchool(schoolId) && 
          (isAdmin() || (isStaff() && isOwner(resource.data.applicantId)));
        
        allow create: if canAccessSchool(schoolId) && 
          (isAdmin() || isStaff()) &&
          request.resource.data.applicantId == request.auth.uid &&
          request.resource.data.schoolId == schoolId &&
          request.resource.data.status == 'PENDING';
        
        allow update: if canAccessSchool(schoolId) && (
          (isAdmin() && !isOwner(resource.data.applicantId) &&
           request.resource.data.diff(resource.data).affectedKeys()
           .hasOnly(['status', 'approvedBy', 'approvedAt', 'rejectionReason', 'updatedAt'])) ||
          (isOwner(resource.data.applicantId) && resource.data.status == 'PENDING' &&
           request.resource.data.status == 'CANCELLED')
        ) && immutableFieldsUnchanged(['applicantId', 'schoolId', 'requestDate', 'startTime', 'endTime', 'createdAt']);
        
        allow delete: if isAdmin() && canAccessSchool(schoolId);
      }
      
      // ========================================================================
      // PERMISSION CONFIGURATION - ADMIN ONLY
      // ========================================================================
      
      match /permissionConfig/{configId} {
        allow read: if canAccessSchool(schoolId);
        allow write: if isAdmin() && canAccessSchool(schoolId)
          && request.resource.data.schoolId == schoolId;
      }
      
      // ========================================================================
      // MONTHLY PERMISSION USAGE - BACKEND ONLY
      // ========================================================================
      
      match /monthlyPermissionUsage/{usageId} {
        allow read: if canAccessSchool(schoolId) && 
          (isAdmin() || (isStaff() && isOwner(resource.data.userId)));
        allow create, update, delete: if false; // BACKEND ONLY
      }
      
      // ========================================================================
      // STAFF SUBCOLLECTION - CONTROLLED ACCESS
      // ========================================================================
      
      match /staff/{staffId} {
        allow read: if canAccessSchool(schoolId) && 
          (isAdmin() || (isStaff() && isOwner(resource.data.userId)));
        
        allow create: if isAdmin() && canAccessSchool(schoolId)
          && request.resource.data.schoolId == schoolId
          && request.resource.data.createdBy == request.auth.uid;
        
        allow update: if canAccessSchool(schoolId) && (
          (isAdmin() && 
           request.resource.data.diff(resource.data).affectedKeys()
           .hasOnly(['name', 'department', 'staffType', 'status', 'joiningDate', 
                    'phoneNumber', 'address', 'emergencyContact', 'designation', 'updatedAt'])) ||
          (isStaff() && isOwner(resource.data.userId) && 
           request.resource.data.diff(resource.data).affectedKeys()
           .hasOnly(['phoneNumber', 'address', 'emergencyContact', 'updatedAt']))
        ) && immutableFieldsUnchanged(['userId', 'schoolId', 'employeeId', 'email', 'createdAt', 'createdBy']);
        
        allow delete: if false; // Force soft delete only
      }
      
      // ========================================================================
      // AUDIT LOGS - READ ONLY FOR ADMINS, BACKEND WRITE ONLY
      // ========================================================================
      
      match /auditLogs/{logId} {
        allow read: if isAdmin() && canAccessSchool(schoolId);
        allow create, update, delete: if false; // BACKEND ONLY - IMMUTABLE
      }
      
      // ========================================================================
      // IN-APP NOTIFICATIONS - USER SCOPED
      // ========================================================================
      
      match /notifications/{notificationId} {
        allow read: if canAccessSchool(schoolId) && 
          (isAdmin() || (isStaff() && isOwner(resource.data.recipientUid)));
        
        allow update: if canAccessSchool(schoolId) && 
          isOwner(resource.data.recipientUid) &&
          request.resource.data.diff(resource.data).affectedKeys()
          .hasOnly(['isRead', 'readAt']) &&
          immutableFieldsUnchanged(['schoolId', 'recipientUid', 'title', 'message', 'createdAt']);
        
        allow create, delete: if false; // BACKEND ONLY
      }
      
      // ========================================================================
      // DASHBOARD STATISTICS - READ ONLY
      // ========================================================================
      
      match /dashboardStats/{statsId} {
        allow read: if canAccessSchool(schoolId) && (isAdmin() || isStaff());
        allow create, update, delete: if false; // BACKEND ONLY
      }
      
      // ========================================================================
      // ACADEMIC YEARS - READ ONLY
      // ========================================================================
      
      match /academicYears/{academicYear} {
        allow read: if canAccessSchool(schoolId);
        allow create, update, delete: if false; // BACKEND ONLY
      }
    }
    
    // ============================================================================
    // SYSTEM ALERTS - SUPER ADMIN ONLY
    // ============================================================================
    
    match /systemAlerts/{alertId} {
      allow read: if isSuperAdmin() || 
        (isAdmin() && resource.data.schoolId != null && canAccessSchool(resource.data.schoolId));
      allow update: if (isSuperAdmin() || 
        (isAdmin() && resource.data.schoolId != null && canAccessSchool(resource.data.schoolId))) &&
        request.resource.data.diff(resource.data).affectedKeys().hasOnly(['resolved', 'resolvedAt', 'resolvedBy']);
      allow create, delete: if false; // BACKEND ONLY
    }
    
    // ============================================================================
    // SYSTEM COLLECTIONS - SUPER ADMIN ONLY
    // ============================================================================
    
    match /systemSettings/{settingId} {
      allow read, write: if isSuperAdmin();
    }
    
    match /subscriptions/{subscriptionId} {
      allow read, write: if isSuperAdmin();
    }
    
    // ============================================================================
    // GLOBAL AUDIT LOGS - SUPER ADMIN READ ONLY
    // ============================================================================
    
    match /globalAuditLogs/{logId} {
      allow read: if isSuperAdmin();
      allow create, update, delete: if false; // BACKEND ONLY
    }
    
    // ============================================================================
    // DEFAULT DENY ALL - SECURITY FIRST
    // ============================================================================
    
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

## Security Validation Matrix

### Access Control Validation

| Role | Schools | Users | Leave Balances | Leave Applications | Permissions | Audit Logs |
|------|---------|-------|----------------|-------------------|-------------|------------|
| **SUPER_ADMIN** | Full Access | Full Access | Read All | Full Access | Full Access | Read All |
| **ADMIN** | Own School | School Users | Read School | Approve/Reject School | Approve/Reject School | Read School |
| **STAFF** | Read Own School | Read Own | Read Own | Create/Cancel Own | Create/Cancel Own | None |
| **Client-Side** | - | - | **NO ACCESS** | Limited | Limited | **NO ACCESS** |

### Critical Security Enforcements

#### 1. **ZERO CLIENT-SIDE BALANCE MUTATIONS**
```javascript
match /leaveBalances/{balanceId} {
  allow create, update, delete: if false; // BACKEND ONLY
}
```

#### 2. **IMMUTABLE AUDIT TRAIL**
```javascript
match /auditLogs/{logId} {
  allow create, update, delete: if false; // BACKEND ONLY - IMMUTABLE
}
```

#### 3. **STRICT TENANT ISOLATION**
```javascript
function canAccessSchool(schoolId) {
  return isSuperAdmin() || (isUserActive() && belongsToSchool(schoolId));
}
```

#### 4. **NO CROSS-TENANT ACCESS**
- All operations require `schoolId` matching
- User's `schoolId` validated on every request
- No admin can switch tenant context

#### 5. **ROLE-BASED FIELD RESTRICTIONS**
```javascript
// Staff can only update limited profile fields
(isStaff() && isOwner(resource.data.userId) && 
 request.resource.data.diff(resource.data).affectedKeys()
 .hasOnly(['phoneNumber', 'address', 'emergencyContact', 'updatedAt']))
```

### Exploit Prevention Checklist

- ✅ **Cross-Tenant Data Access**: Blocked by `schoolId` validation
- ✅ **Balance Manipulation**: All balance operations backend-only
- ✅ **Role Escalation**: Immutable role field with creation restrictions
- ✅ **Audit Log Tampering**: Immutable logs, backend-only writes
- ✅ **Unauthorized Approvals**: Role-based approval restrictions
- ✅ **Data Exfiltration**: Strict read permissions per role
- ✅ **Tenant Switching**: No admin can access other schools
- ✅ **Direct Database Writes**: All critical operations via Cloud Functions

### Production Security Validation

#### Test Cases for Security Validation:
1. **Cross-Tenant Access Test**: Admin from School A tries to access School B data
2. **Balance Manipulation Test**: Client attempts direct balance updates
3. **Role Escalation Test**: Staff user tries to approve leave requests
4. **Audit Log Tampering Test**: Any user tries to modify audit logs
5. **Unauthorized Read Test**: Staff tries to read other staff's data
6. **Tenant Switching Test**: Admin tries to change their schoolId

All tests must **FAIL** with permission denied errors for the security rules to be considered production-ready.
