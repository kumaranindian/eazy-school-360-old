# Troubleshooting School Branding in PDFs

## Issue: Bills Show "School" Instead of School Name

### Quick Fix Steps:

1. **Hot Restart the App**
   - The PDF branding cache might be holding old data
   - Press `Shift + Cmd + F` (or click "Hot Restart" button)
   - This clears all in-memory caches

2. **Check Debug Logs**
   - Open Bill Management screen
   - Click "Print" on any bill
   - Check the browser console for logs starting with `[PDF_BRANDING]`
   - You should see:
     ```
     📄 [PDF_BRANDING] School doc exists for ID: RMqzF9Gtx8j8ts5umDlt
     📄 [PDF_BRANDING] Raw data: [name, phone, email, address, ...]
     📄 [PDF_BRANDING] name field: nmhss
     📄 [PDF_BRANDING] schoolName field: null
     📄 [PDF_BRANDING] address: palayapettai
     📄 [PDF_BRANDING] phone: 8508196981
     📄 [PDF_BRANDING] email: hi@avail404.com
     ✅ [PDF_BRANDING] Parsed schoolName: nmhss
     ✅ [PDF_BRANDING] Parsed address: palayapettai
     ✅ [PDF_BRANDING] Parsed phone: 8508196981
     ✅ [PDF_BRANDING] Parsed email: hi@avail404.com
     ✅ [PDF_BRANDING] Parsed website: www.nivedhitaschool.in
     ```

3. **Verify Firestore Data**
   Based on your screenshot, your school document has:
   - ✅ `name: "nmhss"` 
   - ✅ `phone: "8508196981"`
   - ✅ `email: "hi@avail404.com"`
   - ✅ `website: "www.nivedhitaschool.in"`
   - ✅ `address: "palayapettai"`

   This is correct! The system will use the `name` field if `schoolName` doesn't exist.

### How the System Works:

The `School.fromFirestore` method handles both field names:
```dart
final schoolName = (data['schoolName'] as String?) ?? (data['name'] as String?) ?? '';
```

This means:
1. First tries to read `schoolName` field
2. If not found, falls back to `name` field
3. If neither exists, uses empty string

### Common Issues:

#### Issue 1: Cache Not Cleared
**Symptom:** Old school name still appears after updating settings

**Solution:**
```dart
// The bill management screen already does this:
PdfBranding.clearCache();
final branding = await PdfBranding.forSchool(_schoolId!);
```

But you need to **hot restart** the app to clear the in-memory cache.

#### Issue 2: Wrong School ID
**Symptom:** Logs show "School doc does NOT exist"

**Solution:**
- Check the console logs for the school ID being used
- Verify it matches your Firestore document ID
- In your case: `RMqzF9Gtx8j8ts5umDlt`

#### Issue 3: Empty Fields
**Symptom:** Some fields are empty in the PDF

**Solution:**
- Check Firestore console
- Ensure all fields have values (not empty strings)
- Update via Settings page and save

### Testing Steps:

1. **Clear Cache and Restart**
   ```bash
   # In terminal
   flutter run -d chrome lib/main_dev.dart
   ```

2. **Generate a Bill**
   - Go to Bill Management
   - Click "Print" on any bill
   - Check browser console for `[PDF_BRANDING]` logs

3. **Verify PDF Content**
   - The PDF should show:
     - School name: "nmhss"
     - Address: "palayapettai"
     - Phone: "8508196981"
     - Email: "hi@avail404.com"
     - Website: "www.nivedhitaschool.in"

### Debug Logs Explanation:

| Log Message | Meaning |
|-------------|---------|
| `📄 School doc exists` | Successfully found school document in Firestore |
| `📄 Raw data: [...]` | List of all fields in the document |
| `📄 name field: nmhss` | Value of the `name` field |
| `✅ Parsed schoolName: nmhss` | Successfully parsed school name (using `name` field) |
| `❌ School doc does NOT exist` | School document not found - check school ID |
| `❌ Error loading school` | Firestore error - check permissions |

### If Still Not Working:

1. **Check Browser Console**
   - Look for any error messages
   - Check if Firestore queries are succeeding

2. **Verify School ID**
   ```dart
   // In bill_management_screen.dart
   print('School ID: $_schoolId');
   ```

3. **Check Firestore Rules**
   - Ensure the user has read access to `schools/{schoolId}`
   - Current rules should allow authenticated users to read their school

4. **Manual Cache Clear**
   ```dart
   // You can add this button temporarily in the UI
   ElevatedButton(
     onPressed: () {
       PdfBranding.clearCache();
       ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text('Cache cleared!')),
       );
     },
     child: Text('Clear PDF Cache'),
   )
   ```

### Expected Behavior:

After hot restart and generating a bill:
1. Console shows debug logs with school details
2. PDF displays actual school name instead of "School"
3. All contact information appears correctly
4. School copy and parent copy both show branding

### Files Involved:

1. `lib/presentation/shared/pdf/pdf_branding.dart` - Fetches and caches school data
2. `lib/domain/entities/school.dart` - Parses Firestore document
3. `lib/presentation/finance/screens/bill_management_screen.dart` - Generates bills
4. Firestore: `schools/{schoolId}` - Stores school details

### Next Steps:

1. Hot restart the app
2. Generate a bill
3. Check console logs
4. If logs show correct data but PDF still shows "School", there might be a different issue
5. Share the console logs for further debugging
