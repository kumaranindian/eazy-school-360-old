# New Category-Based Fee Management System

## Overview
Complete refactoring of the fee management system from term-based ledgers to category-based fee tracking with support for ad-hoc and event-based fees.

## Completed Components ✅

### 1. Data Model
- **StudentFeeItem** (`lib/domain/entities/student_fee_item.dart`)
  - Individual fee items with category tracking
  - Supports class-wise, student-wise, and school-wide assignment
  - Tracks amount, paid amount, and balance
  - Links to fee structures or ad-hoc assignments

- **AdHocFeeAssignment** (`lib/domain/entities/ad_hoc_fee_assignment.dart`)
  - Bulk fee assignment records
  - Supports school-wide, class-wise, section-wise, or custom student selection
  - Tracks assignment progress and completion

### 2. Repositories
- **StudentFeeItemRepository** (`lib/data/repositories/student_fee_item_repository.dart`)
  - CRUD operations for fee items
  - Category-wise summary generation
  - Batch payment recording
  - Stream providers for real-time updates

- **AdHocFeeAssignmentRepository** (`lib/data/repositories/ad_hoc_fee_assignment_repository.dart`)
  - Assignment management
  - Progress tracking
  - Status updates (draft, active, completed, cancelled)

### 3. Services
- **AdHocFeeAssignmentService** (`lib/data/services/ad_hoc_fee_assignment_service.dart`)
  - Bulk fee assignment logic
  - Student selection by scope (school/class/section/custom)
  - Preview before assignment
  - Cancellation with validation

### 4. Security
- **Firestore Rules** (`firestore.rules`)
  - Added rules for `studentFeeItems` collection
  - Added rules for `adHocFeeAssignments` collection
  - Same permission model as existing fee structures

## Key Features

### 1. Flexible Fee Assignment
```dart
// School-wide assignment
await service.createAndAssign(
  scope: 'school',
  categoryCode: 'ANNUAL_DAY',
  assignmentName: 'Annual Day 2026',
  amount: 300,
  dueDate: DateTime(2026, 12, 15),
);

// Class-wise assignment
await service.createAndAssign(
  scope: 'class',
  classIds: ['I', 'II'],
  categoryCode: 'SPORTS_DAY',
  assignmentName: 'Sports Day Fee',
  amount: 500,
  dueDate: DateTime(2026, 11, 20),
);

// Student-specific assignment
await service.createAndAssign(
  scope: 'custom',
  studentIds: ['student123', 'student456'],
  categoryCode: 'LAB_FEE',
  assignmentName: 'Science Lab Fee',
  amount: 1000,
  dueDate: DateTime(2026, 10, 1),
);
```

### 2. Category-Based Tracking
Each student has multiple fee items, each with a category:
- TUITION (monthly, can vary per student)
- EXAM (yearly, class-wise or student-wise)
- VAN (yearly, class-wise or student-wise)
- SPORTS_DAY (event-based, ad-hoc)
- ANNUAL_DAY (event-based, ad-hoc)
- Custom categories as needed

### 3. Payment Collection
Payments are recorded against specific fee items:
```dart
// Pay specific fee items
await repository.recordPaymentBatch(schoolId, {
  'item1': 3000, // June Tuition
  'item2': 1000, // Exam Fee
  'item3': 500,  // Sports Day
});
```

## Firestore Collections

### `schools/{schoolId}/studentFeeItems`
```json
{
  "studentId": "student123",
  "academicYear": "2026-27",
  "categoryCode": "SPORTS_DAY",
  "itemName": "Sports Day 2026",
  "amount": 500,
  "paidAmount": 0,
  "balanceAmount": 500,
  "dueDate": "2026-11-20",
  "source": "event",
  "adHocAssignmentId": "assignment456",
  "assignmentLevel": "class",
  "isActive": true
}
```

### `schools/{schoolId}/adHocFeeAssignments`
```json
{
  "academicYear": "2026-27",
  "categoryCode": "SPORTS_DAY",
  "assignmentName": "Sports Day 2026",
  "amount": 500,
  "scope": "class",
  "classIds": ["I", "II"],
  "studentCount": 50,
  "assignedCount": 50,
  "totalAmount": 25000,
  "status": "completed"
}
```

## Pending Work 🚧

### UI Components (Next Phase)
1. **AdHocFeeAssignmentScreen**
   - Create new ad-hoc fee assignments
   - Select scope (school/class/section/custom)
   - Preview before assignment
   - View assignment history

2. **Updated Payment Dialog**
   - Show fee items grouped by category
   - Allow payment against any fee item
   - Support partial payments
   - Category-wise totals

3. **Updated Fee Management Screen**
   - Display category-wise balances
   - Show all fee items for a student
   - Filter by category
   - Quick payment actions

### Migration
- Service to migrate existing term-based ledgers to fee items
- Preserve payment history
- Handle arrears

### Testing
- Unit tests for services
- Integration tests for repositories
- UI tests for new screens

## Usage Examples

### Creating an Event Fee
```dart
final service = ref.read(adHocFeeAssignmentServiceProvider);

// Preview first
final preview = await service.previewAssignment(
  schoolId: 'school123',
  academicYear: '2026-27',
  scope: 'class',
  classIds: ['I', 'II', 'III'],
  amount: 500,
);

print('Will assign to ${preview.studentCount} students');
print('Total amount: ₹${preview.totalAmount}');

// If confirmed, create assignment
final result = await service.createAndAssign(
  schoolId: 'school123',
  academicYear: '2026-27',
  categoryCode: 'SPORTS_DAY',
  assignmentName: 'Sports Day 2026',
  description: 'Annual sports day event fee',
  amount: 500,
  dueDate: DateTime(2026, 11, 20),
  scope: 'class',
  classIds: ['I', 'II', 'III'],
  createdBy: 'admin123',
);

print('Assigned to ${result.studentsAssigned} students');
```

### Viewing Student Fees
```dart
final repository = ref.read(studentFeeItemRepositoryProvider);

// Get all fee items for a student
final items = await repository.getByStudent(
  'school123',
  'student456',
  '2026-27',
);

// Get category-wise summary
final summary = await repository.getCategorySummary(
  'school123',
  'student456',
  '2026-27',
);

for (final entry in summary.entries) {
  print('${entry.key}: ₹${entry.value.balanceAmount} pending');
}
```

## Benefits

1. **Flexibility**: Assign fees at any time, not just during structure creation
2. **Granularity**: Track individual fee items instead of term bundles
3. **Simplicity**: Category-based collection is more intuitive
4. **Scalability**: Easy to add new fee types without changing structure
5. **Reporting**: Better insights with category-wise breakdowns

## Next Steps

1. Complete UI components (3-4 screens)
2. Create migration service
3. Update existing fee structure assignment to create fee items
4. Thorough testing
5. Deploy to production
6. Train users on new system

## Migration Strategy

### Phase 1: Parallel Running
- Keep old system active
- New fees use new system
- Existing ledgers remain unchanged

### Phase 2: Gradual Migration
- Migrate one class at a time
- Verify data integrity
- Get user feedback

### Phase 3: Full Cutover
- Migrate all remaining data
- Deprecate old system
- Remove old code

## Support

For questions or issues, contact the development team.
