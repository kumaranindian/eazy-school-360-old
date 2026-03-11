# Eazy School 360 - Technical Documentation

## Table of Contents
1. [Overview](#overview)
2. [Technology Stack](#technology-stack)
3. [Architecture](#architecture)
4. [User Roles & Permissions](#user-roles--permissions)
5. [Features](#features)
6. [Database Schema](#database-schema)
7. [API & Repositories](#api--repositories)
8. [Security](#security)
9. [Deployment](#deployment)

---

## Overview

**Eazy School 360** is a comprehensive multi-tenant school management system designed to streamline staff management, leave tracking, and permission handling for educational institutions. The system supports multiple schools (tenants) with role-based access control.

### Key Highlights
- **Multi-tenant Architecture**: Each school operates independently with isolated data
- **Role-based Access Control**: Super Admin, Admin, and Staff roles with granular permissions
- **Leave Management**: Complete leave lifecycle from application to approval
- **Auto-generated IDs**: Staff and leave IDs are auto-generated with school prefix
- **Real-time Updates**: Powered by Firebase Firestore for instant data synchronization
- **Responsive Design**: Works on desktop, tablet, and mobile devices

---

## Technology Stack

### Frontend
| Technology | Version | Purpose |
|------------|---------|---------|
| Flutter | 3.x | Cross-platform UI framework |
| Dart | >=3.0.0 | Programming language |
| flutter_riverpod | 2.3.7 | State management |
| go_router | 17.0.0 | Navigation & routing |
| flutter_screenutil | 5.9.0 | Responsive UI scaling |

### Backend (Firebase)
| Service | Purpose |
|---------|---------|
| Firebase Authentication | User authentication & session management |
| Cloud Firestore | NoSQL database for all data storage |
| Firebase Storage | File storage (documents, images) |
| Firebase Messaging | Push notifications |

### Additional Libraries
| Library | Purpose |
|---------|---------|
| intl | Date/time formatting & localization |
| syncfusion_flutter_calendar | Calendar widgets |
| syncfusion_flutter_charts | Data visualization |
| pdf / printing | PDF generation & printing |
| csv | CSV import/export |
| table_calendar | Calendar picker |

---

## Architecture

### Project Structure
```
lib/
├── core/                    # Core utilities & services
│   ├── providers/          # Riverpod providers
│   ├── security/           # Route guards & role policies
│   ├── services/           # Business services (ID generator, etc.)
│   └── ui/                 # Shared UI components
├── data/                   # Data layer
│   ├── repositories/       # Data access layer
│   └── services/           # Data services
├── domain/                 # Domain layer
│   └── entities/           # Business entities/models
├── presentation/           # UI layer
│   ├── admin/             # Admin screens
│   ├── auth/              # Authentication screens
│   ├── dashboard/         # Dashboard screens
│   ├── staff/             # Staff screens
│   └── widgets/           # Shared widgets
├── firebase_options.dart   # Firebase configuration
└── main.dart              # Application entry point
```

### Design Pattern
- **Clean Architecture**: Separation of concerns with domain, data, and presentation layers
- **Repository Pattern**: Data access abstraction through repositories
- **Provider Pattern**: State management using Riverpod

---

## User Roles & Permissions

### Role Hierarchy

| Role | Description | Scope |
|------|-------------|-------|
| **SUPER_ADMIN** | Platform administrator | All schools |
| **ADMIN** | School administrator | Single school |
| **STAFF** | Teaching/Non-teaching staff | Own data only |

### Permission Matrix

| Permission | SUPER_ADMIN | ADMIN | STAFF |
|------------|:-----------:|:-----:|:-----:|
| Create Schools | ✅ | ❌ | ❌ |
| View All Schools | ✅ | ❌ | ❌ |
| Manage Subscriptions | ✅ | ❌ | ❌ |
| Assign Admins | ✅ | ❌ | ❌ |
| Manage Staff | ❌ | ✅ | ❌ |
| Approve Leaves | ❌ | ✅ | ❌ |
| View Reports | ❌ | ✅ | ❌ |
| Manage Settings | ❌ | ✅ | ❌ |
| Apply Leave | ❌ | ✅ | ✅ |
| Request Permission | ❌ | ✅ | ✅ |
| View Own Data | ❌ | ✅ | ✅ |

### Staff Types
- **TEACHING**: Teachers, professors, instructors
- **NON_TEACHING**: Administrative staff, support staff

### User Status
- **ACTIVE**: User can access the system
- **DISABLED**: User access is revoked

### Onboarding Status
- **PENDING_ACTIVATION**: Account created, awaiting activation
- **EMAIL_VERIFIED**: Email verified
- **PROFILE_COMPLETED**: Profile setup complete
- **ACTIVE**: Fully onboarded

---

## Features

### 1. Authentication & Authorization
- Email/password authentication
- Role-based route protection
- Session management
- Password reset functionality

### 2. School Management (Super Admin)
- Create and manage schools
- Assign school administrators
- Manage subscriptions and plans
- View all schools dashboard

### 3. Staff Management (Admin)
- Add new staff members with auto-generated Employee IDs
- Edit staff profiles
- Activate/deactivate staff
- View staff directory
- Filter by department, status, staff type

### 4. Leave Management
- **Leave Types Configuration**
  - Casual Leave, Sick Leave, Earned Leave, etc.
  - Configurable annual quota
  - Carry forward settings
  - Paid/unpaid options

- **Leave Application**
  - Apply for leave with date range
  - Automatic working days calculation
  - Holiday and weekend exclusion
  - Leave balance validation

- **Leave Approval Workflow**
  - Pending → Approved/Rejected
  - Rejection reason tracking
  - Approval history

- **Leave Balance Tracking**
  - Real-time balance updates
  - Academic year-based tracking
  - Carry forward calculation

### 5. Permission Management
- Permission type configuration
- Permission request workflow
- Approval/rejection tracking

### 6. Dashboard & Analytics
- Staff count statistics
- Pending leaves count
- Staff on leave today
- Recent activity feed

### 7. ID Generation System
- Auto-generated Employee IDs: `{SchoolCode}{Number}` (e.g., ES360001)
- Auto-generated Leave Codes: `{SchoolCode}_LV_{Number}` (e.g., ES360_LV_001)
- Atomic counter increments using Firestore transactions

---

## Database Schema

### Firestore Collections Structure

```
firestore/
├── users/                          # All users across all schools
│   └── {userId}/
├── schools/                        # School/tenant documents
│   └── {schoolId}/
│       ├── staff/                  # Staff profiles
│       │   └── {staffId}/
│       ├── leaves/                 # Leave applications
│       │   └── {leaveId}/
│       ├── leaveTypes/             # Leave type configurations
│       │   └── {leaveTypeId}/
│       ├── leaveBalances/          # Staff leave balances
│       │   └── {balanceId}/
│       ├── balanceMutations/       # Balance change audit trail
│       │   └── {mutationId}/
│       ├── permissions/            # Permission requests
│       │   └── {permissionId}/
│       ├── permissionTypes/        # Permission type configurations
│       │   └── {permissionTypeId}/
│       ├── holidays/               # School holidays
│       │   └── {holidayId}/
│       └── auditLog/               # Activity audit log
│           └── {logId}/
```

### Entity Schemas

#### Users Collection (`users/{userId}`)
| Field | Type | Description |
|-------|------|-------------|
| uid | string | Firebase Auth UID |
| email | string | User email address |
| displayName | string | Full name |
| role | string | SUPER_ADMIN, ADMIN, STAFF |
| schoolId | string? | Associated school ID |
| staffType | string? | TEACHING, NON_TEACHING |
| status | string | ACTIVE, DISABLED |
| onboardingStatus | string | Onboarding progress |
| createdAt | timestamp | Account creation date |
| updatedAt | timestamp | Last update date |
| lastLoginAt | timestamp? | Last login timestamp |
| createdBy | string? | Creator's user ID |
| profile | map | User profile details |
| permissions | map | Permission flags |

#### Schools Collection (`schools/{schoolId}`)
| Field | Type | Description |
|-------|------|-------------|
| schoolId | string | Document ID |
| schoolName | string | School name |
| shortCode | string | Short code for ID generation (e.g., "ES360") |
| academicYearStart | timestamp | Academic year start date |
| status | string | ACTIVE, DISABLED |
| createdAt | timestamp | Creation date |
| updatedAt | timestamp | Last update date |
| createdBy | string | Creator's user ID |
| adminUserId | string? | Primary admin user ID |
| settings | map | School settings |
| subscription | map | Subscription details |
| staffCounter | number | Auto-increment counter for staff IDs |
| leaveCounter | number | Auto-increment counter for leave IDs |

**Settings Sub-object:**
| Field | Type | Default |
|-------|------|---------|
| timezone | string | "Asia/Kolkata" |
| currency | string | "INR" |
| workingDays | array | ["MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY"] |
| maxLeaveCarryForward | number | 5 |

**Subscription Sub-object:**
| Field | Type | Default |
|-------|------|---------|
| plan | string | "BASIC" |
| maxStaff | number | 50 |
| expiresAt | timestamp | 1 year from creation |
| isActive | boolean | true |

#### Staff Collection (`schools/{schoolId}/staff/{staffId}`)
| Field | Type | Description |
|-------|------|-------------|
| id | string | Document ID |
| userId | string | Reference to users collection |
| schoolId | string | Parent school ID |
| name | string | Full name |
| employeeId | string | Auto-generated (e.g., "ES360001") |
| email | string | Email address |
| department | string | Department name |
| staffType | string | TEACHING, NON_TEACHING |
| status | string | ACTIVE, DISABLED |
| joiningDate | timestamp | Date of joining |
| createdAt | timestamp | Record creation date |
| updatedAt | timestamp | Last update date |
| createdBy | string | Creator's user ID |
| phoneNumber | string? | Contact number |
| address | string? | Address |
| emergencyContact | string? | Emergency contact |
| designation | string? | Job title |

#### Leave Types (`schools/{schoolId}/leaveTypes/{leaveTypeId}`)
| Field | Type | Description |
|-------|------|-------------|
| id | string | Document ID |
| schoolId | string | Parent school ID |
| name | string | Leave type name |
| code | string | Short code (CASUAL, SICK, EARNED, etc.) |
| description | string | Description |
| annualQuota | number | Total days per year |
| carryForwardAllowed | boolean | Allow carry forward |
| maxCarryForwardDays | number | Max carry forward days |
| maxDaysPerRequest | number | Max days per single request |
| isPaid | boolean | Paid leave flag |
| isActive | boolean | Active status |
| createdAt | timestamp | Creation date |
| updatedAt | timestamp | Last update date |
| createdBy | string | Creator's user ID |
| customRules | map? | Additional rules |

#### Leave Applications (`schools/{schoolId}/leaves/{leaveId}`)
| Field | Type | Description |
|-------|------|-------------|
| id | string | Document ID |
| schoolId | string | Parent school ID |
| applicantId | string | User ID of applicant |
| staffId | string | Staff profile ID |
| leaveTypeId | string | Leave type reference |
| leaveTypeCode | string | Leave type code |
| academicYear | string | Academic year (e.g., "2024-25") |
| startDate | timestamp | Leave start date |
| endDate | timestamp | Leave end date |
| leaveDates | array | Actual leave dates (excluding weekends/holidays) |
| totalDays | number | Number of working days |
| reason | string | Leave reason |
| status | string | PENDING, APPROVED, REJECTED, CANCELLED |
| createdAt | timestamp | Application date |
| updatedAt | timestamp | Last update date |
| approvedBy | string? | Approver's user ID |
| approvedAt | timestamp? | Approval date |
| rejectionReason | string? | Rejection reason |
| remarks | string? | Additional remarks |
| metadata | map? | Additional data (leaveCode, etc.) |

#### Leave Balances (`schools/{schoolId}/leaveBalances/{balanceId}`)
| Field | Type | Description |
|-------|------|-------------|
| id | string | Document ID |
| schoolId | string | Parent school ID |
| staffId | string | Staff profile ID |
| userId | string | User ID |
| leaveTypeId | string | Leave type reference |
| leaveTypeCode | string | Leave type code |
| academicYear | string | Academic year |
| totalAllowed | number | Total quota for year |
| used | number | Days used |
| pending | number | Days in pending requests |
| carriedForward | number | Days from previous year |
| available | number | Available balance |
| createdAt | timestamp | Creation date |
| updatedAt | timestamp | Last update date |
| createdBy | string | Creator's user ID |
| metadata | map? | Additional tracking data |

#### Balance Mutations (`schools/{schoolId}/balanceMutations/{mutationId}`)
| Field | Type | Description |
|-------|------|-------------|
| id | string | Document ID |
| schoolId | string | Parent school ID |
| staffId | string | Staff profile ID |
| userId | string | User ID |
| leaveTypeId | string | Leave type reference |
| academicYear | string | Academic year |
| mutationType | string | CREATED, USED, PENDING_ADDED, PENDING_REMOVED, CARRY_FORWARD, RESET, ADJUSTMENT |
| previousValue | number | Value before change |
| newValue | number | Value after change |
| delta | number | Change amount |
| referenceId | string? | Related leave request ID |
| reason | string | Reason for change |
| createdAt | timestamp | Mutation date |
| createdBy | string | User who made change |
| metadata | map? | Additional data |

---

## API & Repositories

### Repository Classes

| Repository | Purpose |
|------------|---------|
| `AuthRepository` | Authentication, login, logout, password reset |
| `StaffManagementRepository` | Staff CRUD operations |
| `LeaveApplicationRepository` | Leave application lifecycle |
| `LeaveConfigurationRepository` | Leave type configuration |
| `LeaveTypeRepository` | Leave type queries |
| `PermissionRequestRepository` | Permission request handling |
| `PermissionTypeRepository` | Permission type configuration |
| `SchoolManagementRepository` | School CRUD operations |
| `AdminDashboardRepository` | Dashboard statistics |
| `TeacherRepository` | Legacy teacher operations |

### Key Services

| Service | Purpose |
|---------|---------|
| `IdGeneratorService` | Auto-generate staff/leave IDs with school prefix |
| `LeaveBalanceService` | Manage leave balance calculations |

---

## Security

### Firestore Security Rules

The application uses comprehensive Firestore security rules:

1. **Authentication Required**: All operations require signed-in users
2. **Role-based Access**: Operations are restricted based on user roles
3. **School Isolation**: Users can only access data from their assigned school
4. **Owner Access**: Staff can only view/modify their own data

### Key Security Functions
```javascript
isSignedIn()      // User is authenticated
hasUserDoc()      // User document exists
isActive()        // User status is ACTIVE
isSuperAdmin()    // User has SUPER_ADMIN role
isAdmin()         // User has ADMIN role
isStaff()         // User has STAFF role
belongsToSchool() // User belongs to the specified school
```

---

## Deployment

### Prerequisites
- Flutter SDK 3.x
- Firebase CLI
- Node.js (for Firebase Functions)

### Build Commands
```bash
# Web build
flutter build web

# Android build
flutter build apk

# iOS build
flutter build ios
```

### Firebase Deployment
```bash
# Deploy Firestore rules
firebase deploy --only firestore:rules

# Deploy Firestore indexes
firebase deploy --only firestore:indexes

# Deploy all
firebase deploy
```

### Environment Configuration
Firebase configuration is stored in `lib/firebase_options.dart` (auto-generated by FlutterFire CLI).

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2026 | Initial release |
| 1.1.0 | 2026 | Teacher/Staff dashboard enhancements |

### v1.1.0 Changes

#### Staff Dashboard Enhancements
- **Real-time Leave Balances**: Staff dashboard now displays actual leave balances from Firebase instead of mock data
- **Live Recent Requests**: Recent requests section shows combined leave and permission requests from Firebase
- **Dark Theme Profile**: My Profile screen updated to match the dark theme of the dashboard

#### Data Flow Updates
- Staff leave balances are fetched using `staffLeaveBalancesProvider` from `LeaveBalanceService`
- Recent requests combine data from `staffLeaveApplicationsProvider` and `staffPermissionRequestsProvider`
- All data is real-time through Firestore streams

#### Firebase Collections Used
| Collection | Purpose |
|------------|---------|
| `leaveBalances` | Staff leave balance per leave type and academic year |
| `leaves` | Leave applications with status tracking |
| `permissions` | Permission requests with status tracking |

#### New Firestore Indexes
- `holidays`: Composite index for `isActive` + `date` queries

---

*Document generated for Eazy School 360 v1.1.0*
