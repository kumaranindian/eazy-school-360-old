// Firebase Admin is initialized in index.js
// No need to import or initialize here

// Export RFID Attendance Functions
export {
  processRfidSwipe,
} from './attendance/attendanceProcessor';

// Export Leave & Permission Validators
export {
  validateLeaveApplication,
  updateLeaveBalanceOnApproval,
  validatePermissionRequest,
  updatePermissionUsageOnApproval,
} from './leave/leaveValidator';

// Export existing RFID API (if exists)
// Uncomment if you have the existing RFID HTTP endpoints
// export { api as rfidAttendanceApi } from './rfid-attendance';
