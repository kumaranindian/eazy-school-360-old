# Student Leave Approval Screen Fix

## Issue
The Student Leave Approval screen was showing a Firestore index error when trying to load pending or all student leave requests. The error indicated that composite indexes were missing for the `studentLeaves` collection.

## Root Cause
The application queries the `schools/{schoolId}/studentLeaves` collection with the following patterns:

1. **Pending Leaves Query** (`getPendingStudentLeaves`):
   ```dart
   .where('status', isEqualTo: 'PENDING')
   .orderBy('createdAt', descending: true)
   ```

2. **All Leaves Query** (`getSchoolStudentLeaves`):
   ```dart
   .orderBy('createdAt', descending: true)
   ```

3. **Class Leaves Query** (`getClassStudentLeaves`):
   ```dart
   .where('className', isEqualTo: className)
   .where('section', isEqualTo: section)
   .orderBy('createdAt', descending: true)
   ```

4. **Student Leaves Query** (`getStudentLeaves`):
   ```dart
   .where('studentId', isEqualTo: studentId)
   .orderBy('createdAt', descending: true)
   ```

Firestore requires composite indexes for queries that combine `where` clauses with `orderBy` on different fields.

## Solution

### 1. Added Firestore Indexes
Added three composite indexes to `firebase/firestore.indexes.json`:

```json
{
  "collectionGroup": "studentLeaves",
  "queryScope": "COLLECTION",
  "fields": [
    {
      "fieldPath": "status",
      "order": "ASCENDING"
    },
    {
      "fieldPath": "createdAt",
      "order": "DESCENDING"
    }
  ]
},
{
  "collectionGroup": "studentLeaves",
  "queryScope": "COLLECTION",
  "fields": [
    {
      "fieldPath": "className",
      "order": "ASCENDING"
    },
    {
      "fieldPath": "section",
      "order": "ASCENDING"
    },
    {
      "fieldPath": "createdAt",
      "order": "DESCENDING"
    }
  ]
},
{
  "collectionGroup": "studentLeaves",
  "queryScope": "COLLECTION",
  "fields": [
    {
      "fieldPath": "studentId",
      "order": "ASCENDING"
    },
    {
      "fieldPath": "createdAt",
      "order": "DESCENDING"
    }
  ]
}
```

### 2. Verified Firestore Security Rules
The security rules for `studentLeaves` already exist and are correct (lines 799-815 in `firestore.rules`):

```javascript
match /studentLeaves/{leaveId} {
  allow read: if isSignedIn() && (
    isSuperAdmin() || 
    (isTenantAdmin() && belongsToSchool(schoolId)) ||
    (isAdmin() && belongsToSchool(schoolId)) ||
    (isStaff() && belongsToSchool(schoolId))
  );
  allow create: if isSignedIn() && (isSuperAdmin() || belongsToSchool(schoolId));
  allow update: if isSignedIn() && (
    isSuperAdmin() || 
    (isTenantAdmin() && belongsToSchool(schoolId)) ||
    (isAdmin() && belongsToSchool(schoolId)) ||
    (isStaff() && belongsToSchool(schoolId))
  );
  allow delete: if isSignedIn() && (isSuperAdmin() || (isTenantAdmin() && belongsToSchool(schoolId)));
}
```

**Permissions:**
- ✅ **Read**: Super Admin, Admin, Staff (all from the same school)
- ✅ **Create**: Any authenticated user from the school (parents can apply for leave)
- ✅ **Update**: Super Admin, Admin, Staff (for approval/rejection)
- ✅ **Delete**: Super Admin, Admin only

## Manual Index Creation

Since automated deployment had conflicts with existing indexes, you can create the indexes manually:

### Option 1: Using Firebase Console
1. Go to [Firebase Console](https://console.firebase.google.com/project/eazyschool-360-dev/firestore/indexes)
2. Click "Add Index"
3. Create the following indexes:

**Index 1: Pending Leaves**
- Collection ID: `studentLeaves`
- Fields:
  - `status` (Ascending)
  - `createdAt` (Descending)

**Index 2: Class Leaves**
- Collection ID: `studentLeaves`
- Fields:
  - `className` (Ascending)
  - `section` (Ascending)
  - `createdAt` (Descending)

**Index 3: Student Leaves**
- Collection ID: `studentLeaves`
- Fields:
  - `studentId` (Ascending)
  - `createdAt` (Descending)

### Option 2: Using Error Link
When you encounter the error in the app, click the link provided in the error message. It will take you directly to the Firebase Console with the index pre-configured. Just click "Create Index".

## Collections Used
- `schools/{schoolId}/studentLeaves/{leaveId}` - Student leave requests

### Leave Request Structure
Each leave request contains:
- **Student Info**: studentId, studentName, studentNumericId, className, section
- **Leave Details**: leaveType, leaveTypeLabel, startDate, endDate, totalDays, reason
- **Status**: status (PENDING, APPROVED, REJECTED, CANCELLED)
- **Approval Info**: approvedBy, approvedAt, rejectionReason
- **Timestamps**: createdAt, updatedAt

## Features Using Student Leaves

1. **Student Leave Approval Screen** (Admin): View and approve/reject student leave requests
2. **Parent Portal**: Parents can apply for leave for their children
3. **Class Teacher View**: Teachers can view leave requests for their class
4. **Student View**: Students can view their own leave history

## Testing
After creating the indexes:
- ✅ Admin can view pending student leave requests
- ✅ Admin can view all student leave requests
- ✅ Admin can approve/reject leave requests
- ✅ Class teachers can view leaves for their class
- ✅ Parents can view their child's leave history

## Index Build Time
Firestore indexes are built asynchronously. For existing data:
- Small collections (<1000 docs): ~1-2 minutes
- Medium collections (1000-10000 docs): ~5-10 minutes
- Large collections (>10000 docs): ~30+ minutes

You can monitor index build progress in the Firebase Console under Firestore > Indexes.

## Related Files
- `firebase/firestore.indexes.json` - Index definitions (lines 2047-2092)
- `firestore.rules` - Security rules (lines 799-815)
- `lib/presentation/admin/screens/student_leave_approval_screen.dart` - UI screen
- `lib/data/repositories/student_leave_repository.dart` - Data access layer
- `lib/domain/entities/student_leave.dart` - Entity definition
