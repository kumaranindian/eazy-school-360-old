# Ad-Hoc Fee Display in Fee Management Screen

## Issue
When ad-hoc fee assignments were created, the fee items were not displayed in the Student Fee Management screen. The screen only showed fees from the Student Fee Ledger (which is built from FeeStructureV2 documents), but ad-hoc fees stored in the `studentFeeItems` collection were not integrated.

## Root Cause
The `LedgerFeeManagementCard` widget only displayed fees from `StudentFeeLedger` documents, which are built from FeeStructureV2 structures. Ad-hoc fee assignments create fee items in the `studentFeeItems` collection separately, and these were never loaded or displayed in the fee management screen.

### Data Flow
- **Regular fees**: FeeStructureV2 → StudentFeeLedger → LedgerFeeManagementCard
- **Ad-hoc fees**: AdHocFeeAssignment → studentFeeItems (NOT displayed)

## Solution
Added support for loading and displaying ad-hoc fee items alongside regular ledger fees in the `LedgerFeeManagementCard` widget.

### Changes Made

#### File: `lib/presentation/finance/widgets/ledger_fee_management_card.dart`

**1. Added imports** (lines 7, 11)
```dart
import '../../../data/repositories/student_fee_item_repository.dart';
import '../../../domain/entities/student_fee_item.dart';
```

**2. Added state variable** (line 86)
```dart
// Ad-hoc fee items (event-based fees not in the ledger)
List<StudentFeeItem> _adhocFeeItems = const [];
```

**3. Updated _refresh() method** (lines 131-142, 178)
```dart
// Load ad-hoc fee items for the student
List<StudentFeeItem> adhocItems = const [];
try {
  final feeItemRepo = ref.read(studentFeeItemRepositoryProvider);
  adhocItems = await feeItemRepo.getByStudent(
    widget.schoolId,
    widget.studentId,
    widget.academicYear,
  );
} catch (e) {
  print('[LedgerFeeManagementCard] Failed to load ad-hoc fee items: $e');
}

// In setState:
_adhocFeeItems = adhocItems;
```

**4. Added display section in build method** (lines 257-260)
```dart
if (_adhocFeeItems.isNotEmpty) ...[
  const SizedBox(height: 16),
  _adhocFeesSection(isDesktop, isMobile),
],
```

**5. Implemented _adhocFeesSection() method** (lines 439-506)
- Displays ad-hoc fees in a separate section with amber accent
- Shows summary cards (Total, Paid, Balance)
- Lists individual ad-hoc fee items with details
- Shows PAID badge for fully paid items

**6. Implemented helper methods**
- `_adhocSummaryCard()` (lines 508-532) - Summary card widget
- `_adhocFeeItemRow()` (lines 534-600) - Individual fee item row widget

### Display Layout
The ad-hoc fees section appears after the arrears section (if any) and before the action row. It includes:

1. **Header** with icon, title, and item count badge
2. **Summary cards** showing Total, Paid, and Balance amounts
3. **Individual fee items** with:
   - Item name
   - Category name
   - Due date
   - Amount, Paid, and Balance
   - PAID badge for fully paid items

### Visual Design
- **Accent color**: Amber (to distinguish from regular fees)
- **Border**: Amber-tinted border for the section
- **Paid items**: Green border and PAID badge
- **Unpaid items**: Default border

## Testing
1. Create an ad-hoc fee assignment (e.g., SPORTS fee for 3 students)
2. Navigate to Finance > Fee Management
3. Select one of the assigned students
4. Verify:
   - ✅ Ad-Hoc Fees section appears below regular fees
   - ✅ Summary cards show correct totals
   - ✅ Individual fee items display with correct details
   - ✅ PAID badge appears for fully paid items
   - ✅ Category names are resolved from feeCategories collection

## Firestore Index Deployment
The query for ad-hoc fee items requires a composite index on the `studentFeeItems` collection. The index was added to `firestore.indexes.json`:

```json
{
  "collectionGroup": "studentFeeItems",
  "queryScope": "COLLECTION",
  "fields": [
    { "fieldPath": "academicYear", "order": "ASCENDING" },
    { "fieldPath": "isActive", "order": "ASCENDING" },
    { "fieldPath": "studentId", "order": "ASCENDING" },
    { "fieldPath": "dueDate", "order": "ASCENDING" }
  ]
}
```

Deployed using:
```bash
firebase deploy --only firestore:indexes
```

Deployment completed successfully.

## Impact
- ✅ Ad-hoc fees now visible in fee management screen
- ✅ Users can see all fees (regular + ad-hoc) in one place
- ✅ Consistent UI with regular fee display
- ✅ Separate section clearly distinguishes ad-hoc fees
- ✅ No breaking changes to existing functionality
- ✅ **Ad-hoc fees can now be paid via Make Payment dialog**
- ✅ **Auto-allocate works for both regular and ad-hoc fees**
- ✅ **Payments recorded correctly for ad-hoc fee items**

## Payment Support for Ad-Hoc Fees

### Changes to MultiAllocationPaymentDialog

**File: `lib/presentation/finance/widgets/multi_allocation_payment_dialog.dart`**

1. **Added adHocFeeItems parameter** - Accepts list of ad-hoc fee items
2. **Added state variables** - `_openAdHocItems` and `_adhocAmountCtrls`
3. **Updated initialization** - Loads ad-hoc items with outstanding balance
4. **Updated _allocatedTotal()** - Includes ad-hoc fee allocations
5. **Updated _autoAllocate()** - Allocates to ledger entries first, then ad-hoc items
6. **Updated _submit()** - Records payments for both ledger entries and ad-hoc items
7. **Updated outstanding calculation** - Includes ad-hoc fee balances
8. **Added UI section** - Displays ad-hoc fees with amber accent
9. **Implemented _adhocAllocationRow()** - Row widget for ad-hoc fee items

### Payment Flow
- Ad-hoc fees appear in a separate section in the Make Payment dialog
- Amber accent color distinguishes them from regular fees
- Auto-allocate distributes payment across all outstanding fees (ledger + ad-hoc)
- Payments are recorded via `StudentFeeItemRepository.recordPayment()`
- Payment dialog refreshes the ledger after successful payment

### Related Files
- `lib/presentation/finance/widgets/multi_allocation_payment_dialog.dart` - Payment dialog updated

## Related Files
- `lib/presentation/finance/widgets/ledger_fee_management_card.dart` - Main widget updated
- `lib/data/repositories/student_fee_item_repository.dart` - Repository used to load ad-hoc fees
- `lib/domain/entities/student_fee_item.dart` - Entity representing ad-hoc fee items

## Future Enhancements
- Add payment functionality for ad-hoc fees (currently read-only)
- Add ability to delete ad-hoc fee items from fee management screen
- Add filtering by source (regular vs ad-hoc)
- Add export functionality for ad-hoc fees

## Date
Fixed on: April 29, 2026
