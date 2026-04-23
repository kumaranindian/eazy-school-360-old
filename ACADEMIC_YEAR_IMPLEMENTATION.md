# Academic Year & Fiscal Year Implementation Guide

## Overview
This document outlines the comprehensive implementation of academic year and fiscal year management in Eazy School 360.

## Features Implemented

### 1. Academic Year & Fiscal Year Entities ✅
- **Academic Year**: May 1 to April 30 (e.g., "2024-25")
- **Fiscal Year**: April 1 to March 31 (e.g., "2024-25")
- Both support:
  - Automatic year code generation
  - Current year detection
  - Date range validation
  - Next/previous year navigation

**Files Created:**
- `lib/domain/entities/academic_year.dart`
- `lib/data/repositories/academic_year_repository.dart`

**Providers Available:**
- `schoolAcademicYearsProvider` - All academic years for a school
- `currentAcademicYearProvider` - Current academic year
- `schoolFiscalYearsProvider` - All fiscal years for a school
- `currentFiscalYearProvider` - Current fiscal year

### 2. Searchable Dropdown Widget ✅
A reusable widget that replaces all standard dropdowns with search functionality.

**File Created:**
- `lib/presentation/shared/widgets/searchable_dropdown.dart`

**Usage Example:**
```dart
SearchableDropdown<String>(
  value: selectedClass,
  items: ['I', 'II', 'III', 'IV', 'V'],
  itemLabel: (item) => 'Class $item',
  onChanged: (value) => setState(() => selectedClass = value),
  hint: 'Select Class',
)
```

## Features To Be Implemented

### 3. Fee Structure Versioning (IN PROGRESS)
- Link fee structures to academic years
- Each academic year has its own fee structure
- Support fee structure templates for easy year-to-year copying

**Required Changes:**
- Add `academicYearCode` field to fee structure entities
- Create fee structure templates
- Build UI for managing year-specific fee structures

### 4. Student Entity Updates (PENDING)
- Add `academicYearCode` field to Student entity
- Add `arrears` field to track carried-forward pending fees
- Update student creation/edit forms

**Required Changes:**
```dart
class Student {
  // ... existing fields
  final String academicYearCode; // e.g., "2024-25"
  final double arrears; // Carried forward from previous year
  // ...
}
```

### 5. Arrears Calculation & Carry-Forward (PENDING)
Automatically calculate and carry forward pending fees at year-end.

**Logic:**
1. At academic year end, calculate pending fees per student
2. Create arrears record: `totalFees - totalPaid`
3. When promoting to next year, add arrears to new year's fee structure
4. Track arrears separately in payment records

**Required Components:**
- `ArrearsService` - Calculate and carry forward arrears
- `ArrearsEntity` - Track arrears history
- Firestore collection: `schools/{schoolId}/arrears`

### 6. Student Promotion Service (PENDING)
Class-wise promotion with automatic fee structure adjustment.

**Features:**
- Bulk promote students from one class to next
- Automatically assign new academic year
- Apply new fee structure for promoted class
- Carry forward arrears
- Generate promotion report

**Required Components:**
- `StudentPromotionService`
- Promotion UI screen for admin
- Promotion history tracking

### 7. Year Selector in Screens (PENDING)
Add academic/fiscal year dropdown to:
- Bill Management Screen
- Fee Collection Screen
- Financial Reports Screen
- Expense Entry Screen
- Student Fee Management Screen

**Implementation:**
```dart
// Add to each screen
SearchableDropdown<String>(
  value: selectedYear,
  items: academicYears.map((y) => y.yearCode).toList(),
  itemLabel: (code) => 'Academic Year $code',
  onChanged: (code) => setState(() => selectedYear = code),
)
```

### 8. Sheet Upload Year Selection (PENDING)
When uploading student/fee data via Excel:
- Check if `academicYearCode` column exists
- If missing, show dialog to select academic year
- Apply selected year to all uploaded records

### 9. Historical Data Access (PENDING)
- Filter all financial data by selected year
- Maintain separate collections per year OR use year field in queries
- Ensure reports show correct year-specific data

### 10. Replace All Dropdowns (PENDING)
Replace standard `DropdownButton` with `SearchableDropdown` in:
- Student Directory (class, section, login status filters)
- Staff Management (department, staff type filters)
- Fee Management (class, fee type filters)
- Bill Management (bill type, status filters)
- Leave Management (leave type, status filters)
- All form fields with dropdowns

## Database Schema Changes

### New Collections

#### `schools/{schoolId}/academicYears`
```json
{
  "yearCode": "2024-25",
  "startDate": "2024-05-01T00:00:00Z",
  "endDate": "2025-04-30T23:59:59Z",
  "isCurrent": true,
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

#### `schools/{schoolId}/fiscalYears`
```json
{
  "yearCode": "2024-25",
  "startDate": "2024-04-01T00:00:00Z",
  "endDate": "2025-03-31T23:59:59Z",
  "isCurrent": true,
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

#### `schools/{schoolId}/arrears`
```json
{
  "studentId": "student_doc_id",
  "studentName": "John Doe",
  "className": "V",
  "section": "A",
  "fromAcademicYear": "2023-24",
  "toAcademicYear": "2024-25",
  "arrearsAmount": 5000.00,
  "description": "Pending fees from 2023-24",
  "status": "PENDING|PAID|WAIVED",
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

### Modified Collections

#### `schools/{schoolId}/students`
Add fields:
- `academicYearCode`: Current academic year
- `arrears`: Current arrears amount

#### `schools/{schoolId}/feeStructures`
Add fields:
- `academicYearCode`: Academic year this structure applies to

#### `schools/{schoolId}/bills`
Add fields:
- `fiscalYearCode`: Fiscal year for this bill

#### `schools/{schoolId}/feeCollections`
Add fields:
- `academicYearCode`: Academic year for this collection

## Migration Strategy

### Phase 1: Setup (Current)
1. ✅ Create academic/fiscal year entities
2. ✅ Create repository and providers
3. ✅ Create searchable dropdown widget

### Phase 2: Core Integration
1. Update Student entity with year fields
2. Update fee structure with year linkage
3. Implement arrears calculation service
4. Create promotion service

### Phase 3: UI Updates
1. Add year selectors to all relevant screens
2. Replace all dropdowns with searchable version
3. Update sheet upload with year selection
4. Add year filter to reports

### Phase 4: Data Migration
1. Initialize academic/fiscal years for existing schools
2. Assign current year to all existing students
3. Link existing fee structures to current year
4. Calculate any existing arrears

### Phase 5: Testing
1. Test year transitions
2. Test promotion workflow
3. Test arrears carry-forward
4. Test historical data access
5. Test searchable dropdowns

## API Methods

### Academic Year Repository
```dart
// Get all years
Stream<List<AcademicYear>> getAcademicYears(String schoolId)

// Get current year
Stream<AcademicYear?> getCurrentAcademicYear(String schoolId)

// Get year by code
Future<AcademicYear?> getAcademicYearByCode(String schoolId, String yearCode)

// Create year
Future<String> createAcademicYear(String schoolId, AcademicYear year)

// Set current year
Future<void> setCurrentAcademicYear(String schoolId, String yearId)

// Initialize years (creates 5 years: -2, -1, current, +1, +2)
Future<void> initializeAcademicYears(String schoolId)
```

## Usage Examples

### Initialize Years for a School
```dart
final repo = ref.read(academicYearRepositoryProvider);
await repo.initializeAcademicYears(schoolId);
await repo.initializeFiscalYears(schoolId);
```

### Get Current Academic Year
```dart
final currentYearAsync = ref.watch(currentAcademicYearProvider(schoolId));
currentYearAsync.when(
  data: (year) => Text('Current Year: ${year?.yearCode}'),
  loading: () => CircularProgressIndicator(),
  error: (e, _) => Text('Error: $e'),
);
```

### Filter Students by Year
```dart
final students = await FirebaseFirestore.instance
  .collection('schools').doc(schoolId).collection('students')
  .where('academicYearCode', isEqualTo: '2024-25')
  .get();
```

## Next Steps

1. **Immediate**: Complete fee structure versioning
2. **Next**: Update Student entity and forms
3. **Then**: Implement arrears service
4. **Then**: Build promotion service
5. **Finally**: Update all UI screens with year selectors

## Notes

- Academic year runs May-April to align with Indian school calendar
- Fiscal year runs April-March to align with Indian financial year
- All monetary calculations should use fiscal year
- All academic operations (fees, admissions) should use academic year
- Arrears are calculated at end of academic year (April 30)
- Promotion happens at start of new academic year (May 1)
