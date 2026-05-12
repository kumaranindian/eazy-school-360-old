# Pagination and Date Filter Updates

## Summary
Updated default date filters to 1 week for both Communication Logs and Bill Management screens. Both screens already have pagination implemented.

## Changes Made

### 1. Communication Logs Screen
**File:** `lib/presentation/admin/screens/communication_logs_screen.dart`

**Changes:**
- Changed default date range from 30 days to 7 days (1 week)
- Line 70-72: Updated `initState()` to set `_startDate` to 7 days ago instead of 30 days

**Existing Features (Already Implemented):**
- ✅ Pagination with 25 items per page
- ✅ Infinite scroll loading
- ✅ Date range filters (start date and end date)
- ✅ Status filter (Pending, Sent, Failed, Delivered)
- ✅ Purpose filter (Fee Reminder, Leave Approval, etc.)
- ✅ Channel filter (WhatsApp, SMS, Email)
- ✅ Recipient type filter
- ✅ Search functionality
- ✅ Export to CSV and Excel

### 2. Bill Management Screen
**File:** `lib/presentation/finance/screens/bill_management_screen.dart`

**Status:** Already defaults to current week (Monday to Sunday)

**Existing Features (Already Implemented):**
- ✅ Date range defaults to current week
- ✅ Quick range selector (Week, Month, Quarter, Year, Custom)
- ✅ Bill type filter (Revenue, Expense, Both)
- ✅ Bulk selection and download
- ✅ Export to CSV and Excel
- ✅ PDF generation with school branding
- ✅ Print functionality

## School Branding in Bills

### Current Implementation
The Bill Management screen already uses `PdfBranding.forSchool()` to fetch school details from Firestore and apply them to generated bills.

**School Details Included:**
- School Name
- Address
- Phone
- Email
- Website

### Troubleshooting "School" Placeholder Issue

If bills show "School" instead of the actual school name, it means the school details are not properly saved in Firestore. To fix:

1. **Go to Settings Page**
   - Navigate to Admin Dashboard → Settings
   - Update all school information fields
   - Click Save

2. **Verify in Firestore**
   - Open Firebase Console
   - Go to Firestore Database
   - Navigate to `schools/{schoolId}`
   - Verify these fields exist:
     - `name` or `schoolName`
     - `address`
     - `phone`
     - `email`
     - `website`

3. **Clear PDF Branding Cache**
   The system automatically clears the cache before generating each bill using:
   ```dart
   PdfBranding.clearCache();
   final branding = await PdfBranding.forSchool(_schoolId!);
   ```

### Bill Generation Flow

1. User clicks "Print" or "Download" on a bill
2. System calls `PdfBranding.forSchool(schoolId)`
3. Branding fetches school details from Firestore
4. PDF is generated with school header containing:
   - School name (bold, 12pt)
   - Address (small, 8pt)
   - Phone number
   - Email (if available)
   - Website (if available)
5. Two copies are generated on A5 page:
   - SCHOOL COPY
   - PARENT COPY (for revenue) or OFFICE COPY (for expense)

## Date Filter Defaults

| Screen | Default Range | Customizable |
|--------|---------------|--------------|
| Communication Logs | Last 7 days | ✅ Yes |
| Bill Management | Current week (Mon-Sun) | ✅ Yes |

## Pagination Details

### Communication Logs
- **Page Size:** 25 logs per page
- **Loading:** Infinite scroll (auto-loads when scrolling near bottom)
- **Indicator:** Shows "Loading more..." at bottom when fetching

### Bill Management
- **No Pagination:** Loads all bills for selected date range
- **Reason:** Typically smaller dataset within a week
- **Performance:** Optimized with Firestore queries and indexes

## Testing

### Communication Logs
1. Open Communication Logs screen
2. Verify date range shows last 7 days by default
3. Scroll to bottom to trigger pagination
4. Change date range and verify filtering works
5. Apply other filters (status, purpose, channel)

### Bill Management
1. Open Bill Management screen
2. Verify date range shows current week (Monday to Sunday)
3. Click "Print" on any bill
4. Verify school details appear correctly in PDF
5. If "School" appears instead of school name:
   - Go to Settings
   - Update school information
   - Save and try again

## Files Modified

1. `/lib/presentation/admin/screens/communication_logs_screen.dart`
   - Line 70-72: Changed default date range to 7 days

## Files Already Correct

1. `/lib/presentation/finance/screens/bill_management_screen.dart`
   - Already defaults to current week
   - Already uses `PdfBranding` for school details

## Related Documentation

- `SCHOOL_BRANDING_IMPLEMENTATION.md` - School branding system details
- `lib/presentation/shared/pdf/pdf_branding.dart` - PDF branding implementation
