# Role-Based Access Control (RBAC) Matrix

## Role Hierarchy
```
SUPER_ADMIN (Platform Level)
    ↓
ADMIN (School Level)
    ↓
STAFF (School Level)
```

## Permission Matrix

| Resource/Action | SUPER_ADMIN | ADMIN | STAFF |
|----------------|-------------|-------|-------|
| **School Management** |
| Create School | ✅ | ❌ | ❌ |
| View All Schools | ✅ | ❌ | ❌ |
| Update School Settings | ✅ | ✅* | ❌ |
| Delete/Disable School | ✅ | ❌ | ❌ |
| View School Analytics | ✅ | ✅* | ❌ |
| **User Management** |
| Create ADMIN User | ✅ | ❌ | ❌ |
| Create STAFF User | ❌ | ✅* | ❌ |
| Update User Profile | ✅ | ✅* | ✅** |
| Delete/Disable User | ✅ | ✅* | ❌ |
| View All Users | ✅ | ✅* | ❌ |
| Reset User Password | ✅ | ✅* | ❌ |
| **Leave Management** |
| Create Leave Types | ✅ | ✅* | ❌ |
| Update Leave Types | ✅ | ✅* | ❌ |
| Apply for Leave | ❌ | ✅* | ✅* |
| Approve/Reject Leave | ✅ | ✅* | ❌ |
| View All Leaves | ✅ | ✅* | ❌ |
| View Own Leaves | ❌ | ✅* | ✅* |
| Cancel Leave | ❌ | ✅* | ✅** |
| **Permission Management** |
| Request Permission | ❌ | ✅* | ✅* |
| Approve/Reject Permission | ✅ | ✅* | ❌ |
| View All Permissions | ✅ | ✅* | ❌ |
| View Own Permissions | ❌ | ✅* | ✅* |
| **Reports & Analytics** |
| View School Reports | ✅ | ✅* | ❌ |
| Export Data | ✅ | ✅* | ❌ |
| View Staff Analytics | ✅ | ✅* | ❌ |
| **System Administration** |
| Manage Subscriptions | ✅ | ❌ | ❌ |
| View System Logs | ✅ | ❌ | ❌ |
| Platform Settings | ✅ | ❌ | ❌ |

**Legend:**
- ✅ = Full Access
- ❌ = No Access
- ✅* = Access limited to own school
- ✅** = Access limited to own data

## Detailed Permission Definitions

### SUPER_ADMIN Permissions
```typescript
interface SuperAdminPermissions {
  // Platform Management
  canCreateSchools: true;
  canViewAllSchools: true;
  canManageSubscriptions: true;
  canViewSystemLogs: true;
  canManagePlatformSettings: true;
  
  // User Management
  canAssignAdmins: true;
  canViewAllUsers: true;
  canResetAnyPassword: true;
  
  // Override Capabilities
  canOverrideSchoolSettings: true;
  canAccessAnySchoolData: true;
  
  // Billing & Analytics
  canViewPlatformAnalytics: true;
  canManageBilling: true;
}
```

### ADMIN Permissions
```typescript
interface AdminPermissions {
  // School Management (Own School Only)
  canManageSchoolSettings: true;
  canViewSchoolAnalytics: true;
  
  // Staff Management
  canCreateStaff: true;
  canUpdateStaff: true;
  canDisableStaff: true;
  canViewAllStaff: true;
  canResetStaffPasswords: true;
  
  // Leave Management
  canCreateLeaveTypes: true;
  canUpdateLeaveTypes: true;
  canApproveLeaves: true;
  canRejectLeaves: true;
  canViewAllLeaves: true;
  canApplyLeave: true;
  
  // Permission Management
  canApprovePermissions: true;
  canRejectPermissions: true;
  canViewAllPermissions: true;
  canRequestPermission: true;
  
  // Reports
  canViewReports: true;
  canExportData: true;
  
  // Constraints
  schoolId: string; // Immutable, limits access to own school
}
```

### STAFF Permissions
```typescript
interface StaffPermissions {
  // Personal Data
  canViewOwnData: true;
  canUpdateOwnProfile: true;
  
  // Leave Management
  canApplyLeave: true;
  canViewOwnLeaves: true;
  canCancelOwnPendingLeaves: true;
  
  // Permission Management
  canRequestPermission: true;
  canViewOwnPermissions: true;
  
  // Constraints
  schoolId: string; // Immutable, limits access to own school
  canOnlyAccessOwnData: true;
}
```

## Permission Validation Functions

### School-Level Access Control
```typescript
function validateSchoolAccess(userSchoolId: string, resourceSchoolId: string, userRole: string): boolean {
  // SUPER_ADMIN can access any school
  if (userRole === 'SUPER_ADMIN') {
    return true;
  }
  
  // ADMIN and STAFF can only access their own school
  if (userRole === 'ADMIN' || userRole === 'STAFF') {
    return userSchoolId === resourceSchoolId;
  }
  
  return false;
}
```

### Resource-Level Access Control
```typescript
function validateResourceAccess(
  user: User, 
  resource: string, 
  action: string, 
  resourceOwnerId?: string
): boolean {
  const permissions = getUserPermissions(user.role);
  
  // Check if user has permission for this action
  if (!permissions[`can${action}${resource}`]) {
    return false;
  }
  
  // For STAFF, ensure they can only access their own data
  if (user.role === 'STAFF' && resourceOwnerId && resourceOwnerId !== user.uid) {
    return false;
  }
  
  return true;
}
```

### Dynamic Permission Checking
```typescript
function checkPermission(
  user: User,
  resource: string,
  action: string,
  context?: {
    schoolId?: string;
    resourceOwnerId?: string;
    resourceData?: any;
  }
): boolean {
  // 1. Check if user is active
  if (user.status !== 'ACTIVE') {
    return false;
  }
  
  // 2. Check school-level access
  if (context?.schoolId && !validateSchoolAccess(user.schoolId, context.schoolId, user.role)) {
    return false;
  }
  
  // 3. Check resource-level access
  if (!validateResourceAccess(user, resource, action, context?.resourceOwnerId)) {
    return false;
  }
  
  // 4. Check custom business rules
  return validateBusinessRules(user, resource, action, context);
}
```

## Business Rules

### Leave Application Rules
```typescript
function validateLeaveApplicationRules(user: User, leaveData: any): boolean {
  // STAFF can only apply for their own leaves
  if (user.role === 'STAFF' && leaveData.applicantId !== user.uid) {
    return false;
  }
  
  // ADMIN can apply for their own leaves or on behalf of staff (if enabled)
  if (user.role === 'ADMIN') {
    if (leaveData.applicantId === user.uid) {
      return true; // Own leave
    }
    
    // Check if applying on behalf of staff is allowed
    return user.permissions?.canApplyOnBehalfOfStaff === true;
  }
  
  return true;
}
```

### Leave Approval Rules
```typescript
function validateLeaveApprovalRules(user: User, leaveData: any): boolean {
  // Only ADMIN can approve leaves
  if (user.role !== 'ADMIN') {
    return false;
  }
  
  // ADMIN cannot approve their own leaves
  if (leaveData.applicantId === user.uid) {
    return false;
  }
  
  // Must be from same school
  return user.schoolId === leaveData.schoolId;
}
```

## Permission Inheritance

### Role Hierarchy
```typescript
const ROLE_HIERARCHY = {
  'SUPER_ADMIN': 3,
  'ADMIN': 2,
  'STAFF': 1
};

function hasHigherRole(userRole: string, requiredRole: string): boolean {
  return ROLE_HIERARCHY[userRole] >= ROLE_HIERARCHY[requiredRole];
}
```

### Permission Sets
```typescript
const PERMISSION_SETS = {
  STAFF: [
    'canViewOwnData',
    'canUpdateOwnProfile',
    'canApplyLeave',
    'canViewOwnLeaves',
    'canRequestPermission',
    'canViewOwnPermissions'
  ],
  
  ADMIN: [
    ...PERMISSION_SETS.STAFF, // Inherits all STAFF permissions
    'canManageStaff',
    'canApproveLeaves',
    'canViewAllLeaves',
    'canManageSchoolSettings',
    'canViewReports'
  ],
  
  SUPER_ADMIN: [
    'canCreateSchools',
    'canViewAllSchools',
    'canManageSubscriptions',
    'canViewSystemLogs',
    'canAssignAdmins',
    'canOverrideAnyPermission'
  ]
};
```

## Audit & Compliance

### Permission Audit Log
```typescript
interface PermissionAuditLog {
  timestamp: Date;
  userId: string;
  userRole: string;
  action: string;
  resource: string;
  resourceId: string;
  schoolId?: string;
  success: boolean;
  reason?: string;
  ipAddress: string;
  userAgent: string;
}
```

### Compliance Checks
```typescript
function logPermissionCheck(
  user: User,
  action: string,
  resource: string,
  success: boolean,
  reason?: string
): void {
  const auditLog: PermissionAuditLog = {
    timestamp: new Date(),
    userId: user.uid,
    userRole: user.role,
    action,
    resource,
    resourceId: resource.id,
    schoolId: user.schoolId,
    success,
    reason,
    ipAddress: getCurrentIP(),
    userAgent: getCurrentUserAgent()
  };
  
  // Store in audit collection
  db.collection('auditLogs').add(auditLog);
}
```
