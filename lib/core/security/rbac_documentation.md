# Complete Role-Based Access Control (RBAC) Implementation

## Overview
This document outlines the comprehensive RBAC implementation for the multi-tenant Flutter + Firebase School Staff Leave & Permission Management system.

## 1. Role Definitions (Immutable)

### SUPER_ADMIN
- **Scope**: System-wide access
- **Capabilities**: 
  - Create/manage schools
  - Assign/revoke admins
  - View platform-level metrics
  - System configuration
  - Cross-tenant access

### ADMIN
- **Scope**: Single school (tenant-scoped)
- **Capabilities**:
  - Manage staff within their school
  - Approve/reject leave requests
  - Configure leave types and holidays
  - View school reports
  - Manage permissions

### STAFF
- **Scope**: Own data only (user-scoped)
- **Capabilities**:
  - Apply for leave/permissions
  - View own balance and history
  - Update own profile
  - Cancel own pending requests

## 2. Centralized Role Policy

### File: `lib/core/security/role_policy.dart`
- Single source of truth for all permissions
- Defines UI modules, backend actions, and routes per role
- Immutable permission sets
- Tenant and user scoping validation

### Key Features:
- **UI Module Permissions**: Controls what screens/features are visible
- **Backend Action Permissions**: Controls what operations can be performed
- **Route Access Control**: Controls navigation permissions
- **Tenant Scoping**: Ensures school-level data isolation
- **User Scoping**: Ensures user-level data isolation for staff

## 3. Flutter UI Enforcement

### Route Guards (`lib/core/security/route_guard.dart`)
```dart
RouteGuard(
  route: '/admin-dashboard',
  requiredModule: UIModule.adminDashboard,
  child: AdminDashboardScreen(),
)
```

### Feature Guards
```dart
FeatureGuard(
  requiredAction: BackendAction.approveLeave,
  child: ApproveButton(),
)
```

### Role-Based Components
- `RoleBasedButton`: Shows/hides buttons based on permissions
- `RoleBasedMenuItem`: Conditional menu items
- `RoleBasedFAB`: Conditional floating action buttons

## 4. Backend Authorization

### File: `functions/src/security/backend-authorization.js`
- Validates every Cloud Function request
- Enforces role-based action permissions
- Implements tenant-safe queries
- Logs security violations

### Key Features:
- **Request Validation**: Authenticates and authorizes every request
- **Tenant Scoping**: Ensures queries are scoped to user's school
- **User Scoping**: Restricts staff to their own data
- **Audit Logging**: Tracks all authorization attempts
- **Security Violations**: Immutable logging of unauthorized attempts

### Usage Example:
```javascript
const userContext = await BackendAuthorization.validateRequest(
  context, 
  'approveLeave',
  { targetSchoolId: data.schoolId }
);
```

## 5. Firestore Security Rules

### File: `firestore.rules`
- Updated to use new role names (SUPER_ADMIN, ADMIN, STAFF)
- Maintains backward compatibility
- Enforces tenant isolation at database level
- Prevents cross-school data access

### Key Rules:
- Super Admin: Full access to all data
- Admin: Access only to their school's data
- Staff: Access only to their own data within their school

## 6. Data Access Scoping

### Tenant-Safe Queries
```javascript
// Admin queries - scoped to school
query.where('schoolId', '==', userSchoolId)

// Staff queries - scoped to user and school
query.where('schoolId', '==', userSchoolId)
     .where('applicantId', '==', userId)
```

### Multi-Level Scoping
1. **System Level**: Super Admin access
2. **Tenant Level**: School-scoped for Admin
3. **User Level**: Individual user-scoped for Staff

## 7. UI Rendering Stability

### Error Handling
- Graceful fallback for unauthorized access
- Proper loading states during permission checks
- Role-specific empty states
- Clear error messages

### Access Denied Screens
- Consistent UI for unauthorized access
- Clear messaging about required permissions
- Navigation back to authorized areas

## 8. Security Guarantees

### Frontend Security
- ✅ No role logic duplication
- ✅ Centralized permission checks
- ✅ Route-level protection
- ✅ Feature-level visibility control
- ✅ Clean fallback UI

### Backend Security
- ✅ Every action validated at server
- ✅ Tenant isolation enforced
- ✅ User data scoping enforced
- ✅ Security violations logged
- ✅ Immutable audit trail

### Database Security
- ✅ Firestore rules enforce RBAC
- ✅ Cross-tenant access prevented
- ✅ Role-based read/write permissions
- ✅ Data integrity maintained

## 9. Implementation Status

### ✅ Completed
1. **Role Policy Definition**: Complete centralized permission system
2. **UI Role Guards**: Route and feature-level protection
3. **Backend Authorization**: Comprehensive Cloud Function security
4. **Firestore Rules**: Updated for new role system
5. **Dashboard Integration**: RBAC applied to admin dashboard

### 🔄 In Progress
1. **Navigation Filtering**: Role-based menu item filtering
2. **Staff Dashboard**: RBAC integration
3. **Super Admin Dashboard**: RBAC integration

### 📋 Pending
1. **End-to-End Testing**: Comprehensive role testing
2. **Performance Optimization**: Permission check caching
3. **Documentation**: User guides per role

## 10. Usage Examples

### Checking UI Access
```dart
final roleGuard = ref.watch(roleGuardServiceProvider);
if (roleGuard.hasUIAccess(UIModule.staffManagement)) {
  // Show staff management UI
}
```

### Validating Backend Actions
```dart
final validation = roleGuard.validateAction(
  BackendAction.approveLeave,
  targetSchoolId: schoolId,
);
if (validation.isValid) {
  // Perform action
}
```

### Protected Routes
```dart
RouteGuard(
  route: '/staff-management',
  requiredModule: UIModule.staffManagement,
  requiredAction: BackendAction.viewSchoolStaff,
  child: StaffManagementScreen(),
)
```

## 11. Security Best Practices

### Never Trust Client
- All permissions validated at backend
- UI checks are for UX only
- Server-side validation is authoritative

### Principle of Least Privilege
- Users get minimum required permissions
- Explicit permission grants only
- No implicit permission inheritance

### Defense in Depth
- Multiple layers of security
- UI, API, and database level checks
- Comprehensive audit logging

### Tenant Isolation
- Strict school-level data separation
- No cross-tenant queries allowed
- Super Admin exception with full audit

## 12. Monitoring and Auditing

### Security Audit Logs
- All authorization attempts logged
- Failed attempts flagged as violations
- Immutable audit trail maintained
- Real-time security monitoring

### Performance Monitoring
- Permission check performance tracked
- Database query optimization
- Caching strategies for frequent checks

This RBAC implementation ensures complete security for the multi-tenant school management system with proper role separation, tenant isolation, and comprehensive audit trails.
