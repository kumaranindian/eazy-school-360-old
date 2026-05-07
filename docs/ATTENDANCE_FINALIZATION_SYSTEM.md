# Attendance Finalization System

## Overview
The attendance finalization system automatically processes daily RFID attendance records and finalizes attendance status for all staff members at the end of each day.

## Schedule
- **Time**: 11:59 PM IST (23:59 Asia/Kolkata)
- **Frequency**: Daily
- **Function**: `runDailyJobs` (combined scheduler)

## How It Works

### 1. RFID Attendance Collection
Throughout the day, staff members scan their RFID cards at entry/exit points:
- RFID scans are stored in: `schools/{schoolId}/rfid_attendance`
- Each scan includes: `rfidTag`, `staffId`, `scannedAt`, `deviceId`

**Example RFID Scan:**
```json
{
  "schoolId": "RMqzF9Gtx8j8ts5umDlt",
  "rfidTag": "TAG1002",
  "staffId": "nkxvUTFv5IsBPAPNchwK",
  "scannedAt": "2025-05-07T15:00:00Z",
  "deviceId": "nmhss-device-1"
}
```

### 2. Daily Finalization Process

At 11:59 PM, the scheduler:

#### Step 1: Check Working Day
- Retrieves school's attendance configuration
- Verifies if the day is a working day
- Skips finalization for non-working days

#### Step 2: Collect RFID Scans
- Queries all RFID scans for the current day (00:00 to 23:59)
- Groups scans by staff member
- Identifies first scan (check-in) and last scan (check-out)

#### Step 3: Process Each Staff Member
For each active staff member, the system:

1. **Checks for Approved Leave**
   - If leave exists → Mark as `LEAVE`
   - Store leave type and leave ID

2. **Checks for Approved Permission**
   - If permission exists → Mark as `PERMISSION`
   - Store permission ID

3. **Processes RFID Attendance**
   - **If RFID scans exist:**
     - Status: `PRESENT` or `PERMISSION`
     - Records check-in and check-out times
     - Stores total number of scans
   
   - **If no RFID scans:**
     - Status: `LOP` (Loss of Pay - auto-marked) or `PERMISSION`
     - Flag: `autoMarked: true` to indicate automatic marking
     - No check-in/check-out times

### 3. Attendance Record Structure

Final attendance is stored in: `schools/{schoolId}/staff/{staffId}/attendance/{date}`

```javascript
{
  date: "2025-05-07",
  staffId: "nkxvUTFv5IsBPAPNchwK",
  staffName: "karthikeyan Staff",
  status: "PRESENT" | "ABSENT" | "LEAVE" | "PERMISSION",
  
  // For PRESENT status
  checkIn: Timestamp,
  checkOut: Timestamp,
  totalScans: 4,
  
  // For LEAVE status
  leaveType: "CASUAL_LEAVE",
  leaveId: "abc123",
  
  // For PERMISSION status
  permissionId: "xyz789",
  
  // Finalization metadata
  finalized: true,
  finalizedAt: Timestamp
}
```

## Attendance Status Types

| Status | Description | Conditions | Notes |
|--------|-------------|------------|-------|
| `PRESENT` | Staff attended | RFID scans exist, no permission | Records check-in/check-out times |
| `LEAVE` | Staff on approved leave | Approved leave application exists | Stores actual leave type (CASUAL_LEAVE, SICK_LEAVE, etc.) |
| `LOP` | Loss of Pay | No RFID scans, no approved leave, no permission | Auto-marked with `autoMarked: true` flag |
| `PERMISSION` | Staff had permission | Approved permission exists | May or may not have RFID scans |

### Status Details
- **LEAVE**: Uses the actual leave type from the approved leave application (e.g., `CASUAL_LEAVE`, `SICK_LEAVE`, `MATERNITY_LEAVE`)
- **LOP (Loss of Pay)**: Automatically marked when staff has no RFID scans and no approved leave/permission. Indicates unauthorized absence that may result in salary deduction.

## Configuration

### Attendance Settings
Location: `schools/{schoolId}/settings/attendance`

```javascript
{
  workingDays: ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"],
  schoolStartTime: "08:00",
  schoolEndTime: "15:00"
}
```

### Default Configuration
If no settings exist:
- Working Days: Monday to Friday
- School Hours: 8:00 AM to 3:00 PM

## Idempotency
The system is idempotent - if attendance is already finalized for a date, it will skip processing to avoid duplicate entries.

## Query Requirements

### Required Firestore Indexes

1. **RFID Attendance Query:**
   ```
   Collection: schools/{schoolId}/rfid_attendance
   Fields: scannedAt (Ascending)
   ```

2. **Leave Query:**
   ```
   Collection: schools/{schoolId}/leaves
   Fields: staffId, status, startDate, endDate
   ```

3. **Permission Query:**
   ```
   Collection: schools/{schoolId}/permissions
   Fields: staffId, status, date
   ```

## Testing

### Manual Trigger
You can manually trigger the scheduler for testing:

```bash
# Using Firebase CLI
firebase functions:shell
> runDailyJobs()
```

### Test with Specific Date
Modify the function temporarily to process a specific date:
```javascript
const testDate = new Date('2025-05-07');
await finalizeSchoolAttendance(schoolId, testDate);
```

## Monitoring

### Cloud Function Logs
View logs in Firebase Console:
```
Functions > runDailyJobs > Logs
```

### Log Messages
- `[Daily Attendance Finalizer] Starting daily attendance finalization`
- `[Attendance Finalizer] Found X RFID scans for YYYY-MM-DD`
- `[Attendance Finalizer] Processing X active staff members`
- `[Attendance Finalizer] Staff {id} marked {status}`

## Cost Optimization

This scheduler is part of the **Combined Daily Jobs** function that runs:
1. Fee Due Reminders
2. Daily Collection Summary
3. **Attendance Finalization**

By combining these jobs, we reduce Cloud Scheduler costs from ~$9/month to ~$2.70/month.

## Future Enhancements

1. **Late Arrival Detection**
   - Compare check-in time with school start time
   - Mark as "LATE" if after threshold

2. **Early Departure Detection**
   - Compare check-out time with school end time
   - Mark as "EARLY_DEPARTURE"

3. **Half-Day Calculation**
   - Calculate working hours from check-in/check-out
   - Mark as "HALF_DAY" if below threshold

4. **Student Attendance**
   - Extend system to process student RFID scans
   - Similar logic for student attendance finalization

## Troubleshooting

### Issue: Attendance not finalized
**Check:**
1. Is the date a working day?
2. Are there RFID scans in the database?
3. Check Cloud Function logs for errors
4. Verify Firestore indexes are deployed

### Issue: Wrong status assigned
**Check:**
1. Leave application status and dates
2. Permission request status and date
3. RFID scan timestamps
4. Staff status (must be ACTIVE)

### Issue: Duplicate attendance records
**Check:**
1. The `finalized` flag should prevent duplicates
2. Verify the function isn't being triggered multiple times
3. Check Cloud Scheduler configuration

## Related Documentation
- [RFID Attendance System](./RFID_ATTENDANCE_SYSTEM_IMPLEMENTATION.md)
- [Leave Management](./PERMISSION_LEAVE_FIXES.md)
- [Firebase Indexes](./FIRESTORE_INDEXES_REFERENCE.md)
