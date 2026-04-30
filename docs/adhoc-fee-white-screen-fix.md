# Ad-Hoc Fee Assignment White Screen Fix

## Issue
After successfully creating an ad-hoc fee assignment, the screen turned white instead of navigating back to the previous screen.

```
[AdHocFeeAssignment] Assignment completed successfully
[Screen becomes white]
```

## Root Cause
The ad-hoc fee assignment screen is rendered **inline** within the admin dashboard (not pushed as a separate route). When the code called `Navigator.of(context).pop()` after successful assignment creation, it was trying to pop from a navigation stack that didn't exist in the expected way, causing:

1. The entire dashboard to be popped instead of just the ad-hoc screen
2. Navigation state to become inconsistent
3. A white screen to appear

### Before (Problematic)
```dart
if (mounted) {
  Navigator.of(context).pop();  // Pop first
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(  // Then show snackbar
    backgroundColor: _accentGreen,
    content: Text('Successfully assigned fee to ${result.studentsAssigned} students'),
  ));
}
```

## Solution
Added an **optional callback** (`onSuccess`) to the `AdHocFeeAssignmentScreen` that allows the parent dashboard to handle navigation by changing its internal state, rather than using `Navigator.pop()`.

Additionally implemented:
- **Race condition prevention**: Check `_isLoading` flag at the start of `_submit()` to prevent double submissions
- **Form clearing**: Clear all form fields after successful submission using `_clearForm()` method
- **Visual feedback**: Submit button is disabled while loading

### After (Fixed)

**1. Ad-Hoc Fee Assignment Screen** - Added callback parameter and form management:
```dart
class AdHocFeeAssignmentScreen extends ConsumerStatefulWidget {
  const AdHocFeeAssignmentScreen({
    super.key,
    required this.schoolId,
    required this.academicYear,
    this.onSuccess,  // Optional callback
  });

  final VoidCallback? onSuccess;
  // ...
}

// Race condition prevention:
Future<void> _submit() async {
  if (_isLoading) return;  // Prevent double submission
  // ...
}

// On success:
if (mounted) {
  _clearForm();  // Clear all form fields
  
  if (widget.onSuccess != null) {
    widget.onSuccess!();  // Call callback (inline rendering)
  } else {
    Navigator.of(context).pop(true);  // Pop navigation (route-based)
  }
}

// Form clearing:
void _clearForm() {
  _nameCtrl.clear();
  _descCtrl.clear();
  _amountCtrl.clear();
  _notesCtrl.clear();
  setState(() {
    _selectedCategory = '';
    _scope = 'school';
    _dueDate = DateTime.now().add(const Duration(days: 30));
    _selectedClasses.clear();
    _selectedSections.clear();
    _preview = null;
  });
  _formKey.currentState?.reset();
}
```

**2. Admin Dashboard** - Provide callback to change state:
```dart
return AdHocFeeAssignmentScreen(
  schoolId: session?.schoolId ?? '',
  academicYear: academicYear,
  onSuccess: () {
    setState(() => _selectedMenuId = 'dashboard');  // Navigate back
  },
);
```

## Changes Made

### 1. File: `lib/presentation/finance/screens/ad_hoc_fee_assignment_screen.dart`

**Lines 24-33:** Added optional `onSuccess` callback parameter
**Lines 126-148:** Use callback for inline rendering, fallback to Navigator.pop for route-based

**Key improvements:**
1. ✅ Support both inline rendering and route-based navigation
2. ✅ Show success snackbar before navigation
3. ✅ Use callback pattern for state-based navigation
4. ✅ Graceful fallback to Navigator.pop when no callback provided
5. ✅ Set explicit snackbar duration (3 seconds)
6. ✅ **Race condition prevention** - Check `_isLoading` at start of `_submit()`
7. ✅ **Form clearing** - Clear all form fields after successful submission
8. ✅ **Button disabled** - Submit button disabled while `_isLoading` is true

### 2. File: `lib/presentation/dashboard/screens/admin_dashboard_screen.dart`

**Lines 467-470:** Provide `onSuccess` callback that changes `_selectedMenuId` to 'dashboard'

**Key improvements:**
1. ✅ Proper state-based navigation for inline screens
2. ✅ Clean separation of concerns (screen doesn't know about dashboard state)

## Testing
1. Navigate to Finance > Ad-Hoc Fee Assignment
2. Fill in the form with valid data
3. Submit the assignment
4. Verify:
   - ✅ Success message appears
   - ✅ Screen navigates back to dashboard smoothly
   - ✅ No white screen appears
   - ✅ Snackbar is visible for 3 seconds
5. Navigate back to Ad-Hoc Fee Assignment
6. Verify:
   - ✅ Form is completely cleared (all fields empty)
   - ✅ Default values restored (scope: school-wide, due date: +30 days)
7. Test race condition:
   - ✅ Try double-clicking submit button - only one submission should occur
   - ✅ Submit button should be disabled while loading

## Impact
- ✅ Fixed white screen navigation issue
- ✅ Improved user feedback with visible success message
- ✅ Better navigation flow with proper async handling
- ✅ More robust mounted checks to prevent memory leaks
- ✅ **Race condition prevention** - No duplicate submissions possible
- ✅ **Form clearing** - Clean slate for next assignment
- ✅ **Better UX** - Users can immediately create another assignment without manual clearing

## Related Files
- `lib/presentation/finance/screens/ad_hoc_fee_assignment_screen.dart` - UI layer with navigation logic

## Date
Fixed on: April 29, 2026
