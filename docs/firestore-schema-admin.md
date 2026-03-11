# Admin Module Firestore Schema

## Collections Structure

### 1. teachers/{teacherId}
```json
{
  "teacherId": "string (UUID)",
  "name": "string",
  "email": "string",
  "phone": "string",
  "role": "Teacher | HOD",
  "isActive": "boolean",
  "createdAt": "timestamp",
  "updatedAt": "timestamp",
  "leaveBalances": {
    "annual_leave": 20,
    "sick_leave": 10,
    "casual_leave": 5
  },
  "permissionLimits": {
    "early_departure": 5,
    "late_arrival": 3,
    "lunch_extension": 10
  }
}
```

### 2. leave_types/{leaveTypeId}
```json
{
  "id": "string (UUID)",
  "name": "string",
  "defaultBalance": "number",
  "isPaid": "boolean",
  "isActive": "boolean",
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

### 3. permission_types/{permissionTypeId}
```json
{
  "id": "string (UUID)",
  "name": "string",
  "defaultLimit": "number",
  "isActive": "boolean",
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

## Key Features

1. **Multi-tenant ready**: Each school will have separate collections
2. **Soft delete**: Using `isActive` flag
3. **Server timestamps**: For audit trail
4. **Embedded balances**: Leave and permission data stored in teacher document
5. **Batch operations**: For bulk updates via Cloud Functions

## Security Model

- **Admin only**: Full CRUD access to all collections
- **Teachers**: Read-only access to their own data
- **Cloud Functions**: Automated balance initialization and propagation
