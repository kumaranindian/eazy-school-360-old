# Multi-Tenant Firestore Schema Design

## Collection Structure

```
/schools/{schoolId}
/users/{uid}
/schools/{schoolId}/staff/{staffId}
/schools/{schoolId}/leaveTypes/{leaveTypeId}
/schools/{schoolId}/leaves/{leaveId}
/schools/{schoolId}/permissions/{permissionId}
```

## 1. Schools Collection: `/schools/{schoolId}`

```json
{
  "schoolId": "school_001",
  "schoolName": "Green Valley High School",
  "academicYearStart": "2024-06-01T00:00:00Z",
  "status": "ACTIVE",
  "createdAt": "2024-01-15T10:30:00Z",
  "updatedAt": "2024-01-15T10:30:00Z",
  "createdBy": "super_admin_uid",
  "adminUserId": "admin_uid_001",
  "settings": {
    "timezone": "Asia/Kolkata",
    "currency": "INR",
    "workingDays": ["MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY"],
    "maxLeaveCarryForward": 5
  },
  "subscription": {
    "plan": "PREMIUM",
    "maxStaff": 100,
    "expiresAt": "2025-01-15T00:00:00Z",
    "isActive": true
  }
}
```

## 2. Users Collection: `/users/{uid}`

```json
{
  "uid": "user_001",
  "email": "admin@greenvalley.edu",
  "displayName": "John Smith",
  "role": "ADMIN",
  "schoolId": "school_001",
  "staffType": "TEACHING",
  "status": "ACTIVE",
  "createdAt": "2024-01-15T10:30:00Z",
  "updatedAt": "2024-01-15T10:30:00Z",
  "lastLoginAt": "2024-01-20T09:15:00Z",
  "profile": {
    "phoneNumber": "+91-9876543210",
    "department": "Mathematics",
    "designation": "Senior Teacher",
    "employeeId": "EMP001",
    "joiningDate": "2020-06-01T00:00:00Z"
  },
  "permissions": {
    "canManageStaff": true,
    "canApproveLeaves": true,
    "canViewReports": true,
    "canManageSettings": true
  }
}
```

### Sample SUPER_ADMIN User:
```json
{
  "uid": "super_admin_001",
  "email": "superadmin@eazyschool360.com",
  "displayName": "System Administrator",
  "role": "SUPER_ADMIN",
  "schoolId": null,
  "staffType": null,
  "status": "ACTIVE",
  "createdAt": "2024-01-01T00:00:00Z",
  "updatedAt": "2024-01-01T00:00:00Z",
  "permissions": {
    "canCreateSchools": true,
    "canViewAllSchools": true,
    "canManageSubscriptions": true,
    "canAssignAdmins": true
  }
}
```

### Sample STAFF User:
```json
{
  "uid": "staff_001",
  "email": "teacher@greenvalley.edu",
  "displayName": "Mary Johnson",
  "role": "STAFF",
  "schoolId": "school_001",
  "staffType": "TEACHING",
  "status": "ACTIVE",
  "createdAt": "2024-01-16T10:30:00Z",
  "updatedAt": "2024-01-16T10:30:00Z",
  "profile": {
    "phoneNumber": "+91-9876543211",
    "department": "English",
    "designation": "Teacher",
    "employeeId": "EMP002",
    "joiningDate": "2021-06-01T00:00:00Z"
  },
  "permissions": {
    "canApplyLeave": true,
    "canRequestPermission": true,
    "canViewOwnData": true
  }
}
```

## 3. School Staff Subcollection: `/schools/{schoolId}/staff/{staffId}`

```json
{
  "staffId": "staff_001",
  "userId": "user_001",
  "employeeId": "EMP001",
  "status": "ACTIVE",
  "joiningDate": "2020-06-01T00:00:00Z",
  "department": "Mathematics",
  "designation": "Senior Teacher",
  "staffType": "TEACHING",
  "reportingManager": "admin_uid_001",
  "leaveEntitlements": {
    "casualLeave": 12,
    "sickLeave": 12,
    "earnedLeave": 15
  },
  "createdAt": "2024-01-16T10:30:00Z",
  "updatedAt": "2024-01-16T10:30:00Z"
}
```

## Key Design Principles

1. **Tenant Isolation**: Each school is completely isolated through `schoolId`
2. **Immutable School Assignment**: `schoolId` in users collection cannot be changed
3. **Role-Based Access**: Clear hierarchy with SUPER_ADMIN > ADMIN > STAFF
4. **Audit Trail**: All documents have `createdAt`, `updatedAt`, `createdBy` fields
5. **Scalability**: Subcollections for school-specific data to avoid document size limits
6. **Security**: Status fields for soft deletion and access control
