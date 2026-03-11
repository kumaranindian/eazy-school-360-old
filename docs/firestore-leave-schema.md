# Firestore Schema for Leave Configuration and Balance Engine

## Collection Structure

### 1. Leave Type Configurations (Per School)
```
/schools/{schoolId}/leaveTypes/{leaveTypeId}
```

#### Document Structure
```json
{
  "schoolId": "school_abc123",
  "name": "Casual Leave",
  "code": "CASUAL",
  "description": "General purpose casual leave for personal work",
  "annualQuota": 12,
  "carryForwardAllowed": true,
  "maxCarryForwardDays": 5,
  "maxDaysPerRequest": 3,
  "isPaid": true,
  "isActive": true,
  "createdAt": "2024-06-01T00:00:00Z",
  "updatedAt": "2024-06-01T00:00:00Z",
  "createdBy": "admin_user_id",
  "customRules": {
    "requiresApproval": true,
    "advanceNoticeRequired": 1,
    "blackoutDates": ["2024-12-25", "2024-01-01"]
  }
}
```

#### Standard Leave Type Configurations

**Casual Leave**
```json
{
  "name": "Casual Leave",
  "code": "CASUAL",
  "description": "General purpose leave for personal work",
  "annualQuota": 12,
  "carryForwardAllowed": true,
  "maxCarryForwardDays": 5,
  "maxDaysPerRequest": 3,
  "isPaid": true
}
```

**Sick Leave**
```json
{
  "name": "Sick Leave", 
  "code": "SICK",
  "description": "Medical leave for illness or health issues",
  "annualQuota": 10,
  "carryForwardAllowed": false,
  "maxCarryForwardDays": 0,
  "maxDaysPerRequest": 7,
  "isPaid": true
}
```

**Earned Leave**
```json
{
  "name": "Earned Leave",
  "code": "EARNED", 
  "description": "Vacation leave earned through service",
  "annualQuota": 21,
  "carryForwardAllowed": true,
  "maxCarryForwardDays": 15,
  "maxDaysPerRequest": 15,
  "isPaid": true
}
```

### 2. Leave Balances (Per Staff, Per Academic Year)
```
/schools/{schoolId}/leaveBalances/{balanceId}
```

#### Document Structure
```json
{
  "schoolId": "school_abc123",
  "staffId": "staff_profile_id",
  "userId": "firebase_user_id",
  "leaveTypeId": "leave_type_id",
  "leaveTypeCode": "CASUAL",
  "academicYear": "2024-25",
  "totalAllowed": 12,
  "used": 3,
  "pending": 2,
  "carriedForward": 2,
  "available": 9,
  "createdAt": "2024-06-01T00:00:00Z",
  "updatedAt": "2024-10-15T10:30:00Z",
  "createdBy": "system_function",
  "metadata": {
    "lastCarryForwardDate": "2024-06-01T00:00:00Z",
    "lastResetDate": "2024-06-01T00:00:00Z",
    "generationSource": "ACADEMIC_YEAR_RESET"
  }
}
```

#### Balance Calculation Logic
```javascript
available = totalAllowed + carriedForward - used - pending

// Constraints:
// - available >= 0 (never negative)
// - used >= 0
// - pending >= 0
// - carriedForward >= 0 and <= maxCarryForwardDays from config
```

### 3. Balance Mutations (Audit Trail)
```
/schools/{schoolId}/balanceMutations/{mutationId}
```

#### Document Structure
```json
{
  "schoolId": "school_abc123",
  "staffId": "staff_profile_id", 
  "userId": "firebase_user_id",
  "leaveTypeId": "leave_type_id",
  "academicYear": "2024-25",
  "mutationType": "USED",
  "previousValue": 5,
  "newValue": 3,
  "delta": -2,
  "referenceId": "leave_request_id",
  "reason": "Leave approved and deducted from balance",
  "createdAt": "2024-10-15T10:30:00Z",
  "createdBy": "admin_user_id",
  "metadata": {
    "leaveRequestDates": ["2024-10-16", "2024-10-17"],
    "approvedBy": "admin_user_id",
    "functionName": "processLeaveApproval"
  }
}
```

#### Mutation Types
- **CREATED**: Initial balance creation
- **USED**: Days deducted when leave is approved
- **PENDING_ADDED**: Days reserved when leave request is submitted
- **PENDING_REMOVED**: Days released when leave request is cancelled/rejected
- **CARRY_FORWARD**: Days carried from previous academic year
- **RESET**: Academic year reset operation
- **ADJUSTMENT**: Manual adjustment by admin

### 4. Academic Year Metadata
```
/schools/{schoolId}/academicYears/{academicYear}
```

#### Document Structure
```json
{
  "schoolId": "school_abc123",
  "academicYear": "2024-25",
  "startDate": "2024-06-01T00:00:00Z",
  "endDate": "2025-05-31T23:59:59Z",
  "isActive": true,
  "resetCompleted": true,
  "resetDate": "2024-06-01T00:00:00Z",
  "totalStaffProcessed": 45,
  "totalBalancesCreated": 180,
  "createdAt": "2024-06-01T00:00:00Z",
  "createdBy": "system_cron_job",
  "metadata": {
    "resetJobId": "cron_job_20240601_000000",
    "processingDuration": "00:02:34",
    "errors": []
  }
}
```

## Firestore Indexes Required

### 1. Leave Type Configurations
```json
{
  "collectionGroup": "leaveTypes",
  "queryScope": "COLLECTION",
  "fields": [
    {"fieldPath": "schoolId", "order": "ASCENDING"},
    {"fieldPath": "isActive", "order": "ASCENDING"},
    {"fieldPath": "code", "order": "ASCENDING"}
  ]
}
```

### 2. Leave Balances - Staff Query
```json
{
  "collectionGroup": "leaveBalances", 
  "queryScope": "COLLECTION",
  "fields": [
    {"fieldPath": "schoolId", "order": "ASCENDING"},
    {"fieldPath": "staffId", "order": "ASCENDING"},
    {"fieldPath": "academicYear", "order": "ASCENDING"}
  ]
}
```

### 3. Leave Balances - User Query
```json
{
  "collectionGroup": "leaveBalances",
  "queryScope": "COLLECTION", 
  "fields": [
    {"fieldPath": "schoolId", "order": "ASCENDING"},
    {"fieldPath": "userId", "order": "ASCENDING"},
    {"fieldPath": "academicYear", "order": "ASCENDING"}
  ]
}
```

### 4. Balance Mutations - Audit Query
```json
{
  "collectionGroup": "balanceMutations",
  "queryScope": "COLLECTION",
  "fields": [
    {"fieldPath": "schoolId", "order": "ASCENDING"},
    {"fieldPath": "staffId", "order": "ASCENDING"},
    {"fieldPath": "createdAt", "order": "DESCENDING"}
  ]
}
```

### 5. Academic Year Reset Query
```json
{
  "collectionGroup": "leaveBalances",
  "queryScope": "COLLECTION",
  "fields": [
    {"fieldPath": "schoolId", "order": "ASCENDING"},
    {"fieldPath": "academicYear", "order": "ASCENDING"},
    {"fieldPath": "leaveTypeCode", "order": "ASCENDING"}
  ]
}
```

## Data Validation Rules

### 1. Leave Type Configuration Validation
- `annualQuota`: Must be > 0 and <= 365
- `maxCarryForwardDays`: Must be >= 0 and <= annualQuota
- `maxDaysPerRequest`: Must be > 0 and <= annualQuota
- `code`: Must be unique within school
- `carryForwardAllowed`: If false, maxCarryForwardDays must be 0

### 2. Leave Balance Validation
- `available`: Must be >= 0 (enforced by Cloud Functions)
- `used`: Must be >= 0
- `pending`: Must be >= 0
- `carriedForward`: Must be >= 0 and <= maxCarryForwardDays from config
- `totalAllowed`: Must match leaveType.annualQuota

### 3. Academic Year Format
- Format: "YYYY-YY" (e.g., "2024-25")
- Start year must be current or future
- End year must be start year + 1

## Multi-Tenant Isolation

### 1. School-Level Isolation
- All leave configurations are scoped to `schoolId`
- All balances are scoped to `schoolId`
- Cross-school access is prevented by security rules

### 2. Staff-Level Isolation
- Staff can only access their own balances
- Admins can access all balances within their school
- Super admins can access all balances across schools

### 3. Academic Year Isolation
- Balances are isolated by academic year
- Historical data is preserved across years
- Carry forward logic operates between consecutive years only

## Performance Considerations

### 1. Batch Operations
- Academic year reset processes schools in batches
- Balance mutations are batched for efficiency
- Large schools (>1000 staff) get special handling

### 2. Caching Strategy
- Leave type configurations cached at school level
- Current academic year cached globally
- Balance calculations cached per staff per academic year

### 3. Query Optimization
- Composite indexes for all common query patterns
- Pagination for large result sets
- Efficient filtering by schoolId first, then other criteria
