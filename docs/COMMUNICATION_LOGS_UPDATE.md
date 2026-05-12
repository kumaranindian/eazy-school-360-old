# Communication Logs Screen Update

## Overview
Updated the Communication Logs screen to include export functionality for CSV and Excel formats while maintaining the existing card-based UI.

## Changes Made

### 1. Export Functionality Added

#### CSV Export
- Exports all visible communication logs to CSV format
- Columns: Date & Time, Recipient, Phone, Type, Channel, Purpose, Status, Subject, Message
- Web: Triggers browser download
- Mobile/Desktop: Saves to application documents directory

#### Excel Export
- Exports all visible communication logs to Excel (.xlsx) format
- Same columns as CSV
- Formatted with headers
- Web: Triggers browser download
- Mobile/Desktop: Saves to application documents directory

### 2. UI Updates

#### Desktop View
- Added **Export to Excel** button (green table icon) in header
- Added **Export to CSV** button (blue download icon) in header
- Buttons are disabled when no logs are available
- Tooltips show on hover

#### Mobile View
- Added overflow menu (three dots) with options:
  - Export to Excel
  - Export to CSV
  - Refresh
- Replaces individual buttons to save space

### 3. Technical Implementation

#### Dependencies Used
- `csv: ^6.0.0` - CSV file generation
- `excel: ^4.0.6` - Excel file generation
- `path_provider: ^2.1.1` - File system access for mobile/desktop

#### Code Structure
```dart
// Export methods
Future<void> _exportToCSV() async
Future<void> _exportToExcel() async
List<List<dynamic>> _generateCSVData()

// Updated header with export buttons
Widget _buildHeader(bool isMobile)
```

#### Platform Support
- **Web**: Uses `dart:html` for blob downloads
- **Mobile/Desktop**: Uses `dart:io` for file system access
- Conditional imports handle platform differences

### 4. Data Exported

Each row includes:
1. **Date & Time**: Formatted as "dd MMM yyyy, HH:mm"
2. **Recipient**: Name (or "(no name)" if empty)
3. **Phone**: Recipient phone number
4. **Type**: Recipient type (Parent, Student, Staff, etc.)
5. **Channel**: Communication channel (WhatsApp, SMS, Email, etc.)
6. **Purpose**: Purpose of communication (Payment Due, Fee Reminder, etc.)
7. **Status**: Message status (Sent, Delivered, Read, Failed, Pending)
8. **Subject**: Message subject
9. **Message**: Full message content

## Usage

### For Admins
1. Navigate to Communication Logs screen
2. Apply any desired filters (date range, status, channel, etc.)
3. Click the **Excel** or **CSV** export button
4. File will be downloaded (web) or saved to documents folder (mobile/desktop)

### Export File Names
- Format: `communication_logs_{timestamp}.csv` or `communication_logs_{timestamp}.xlsx`
- Example: `communication_logs_1715234567890.xlsx`

## Benefits

1. **Data Analysis**: Export data for offline analysis in Excel/Google Sheets
2. **Reporting**: Generate reports for management
3. **Archival**: Keep historical records of communications
4. **Audit Trail**: Export for compliance and auditing purposes
5. **Filtering**: Apply filters before export to get specific data subsets

## Future Enhancements

Potential improvements:
- Add PDF export option
- Include charts/graphs in Excel export
- Add email functionality to send exports directly
- Schedule automated exports
- Add custom column selection
- Include summary statistics in exports

## Files Modified

1. `/lib/presentation/admin/screens/communication_logs_screen.dart`
   - Added export methods
   - Updated header with export buttons
   - Added conditional imports for platform support

## Testing Checklist

- [ ] CSV export works on web
- [ ] Excel export works on web
- [ ] CSV export works on mobile
- [ ] Excel export works on mobile
- [ ] Export buttons disabled when no data
- [ ] Mobile overflow menu works correctly
- [ ] Exported data matches screen data
- [ ] File names are unique (timestamp-based)
- [ ] All columns exported correctly
- [ ] Special characters handled properly

## Notes

- Export includes only the currently loaded/filtered logs (not all logs in database)
- For large datasets, consider pagination or loading all data before export
- Excel files use the `excel` package which creates valid .xlsx files
- CSV files use UTF-8 encoding for proper character support
