"use strict";
// Firebase Admin is initialized in index.js
// No need to import or initialize here
Object.defineProperty(exports, "__esModule", { value: true });
exports.updatePermissionUsageOnApproval = exports.validatePermissionRequest = exports.updateLeaveBalanceOnApproval = exports.validateLeaveApplication = exports.processRfidSwipe = void 0;
// Export RFID Attendance Functions
var attendanceProcessor_1 = require("./attendance/attendanceProcessor");
Object.defineProperty(exports, "processRfidSwipe", { enumerable: true, get: function () { return attendanceProcessor_1.processRfidSwipe; } });
// Export Leave & Permission Validators
var leaveValidator_1 = require("./leave/leaveValidator");
Object.defineProperty(exports, "validateLeaveApplication", { enumerable: true, get: function () { return leaveValidator_1.validateLeaveApplication; } });
Object.defineProperty(exports, "updateLeaveBalanceOnApproval", { enumerable: true, get: function () { return leaveValidator_1.updateLeaveBalanceOnApproval; } });
Object.defineProperty(exports, "validatePermissionRequest", { enumerable: true, get: function () { return leaveValidator_1.validatePermissionRequest; } });
Object.defineProperty(exports, "updatePermissionUsageOnApproval", { enumerable: true, get: function () { return leaveValidator_1.updatePermissionUsageOnApproval; } });
// Export existing RFID API (if exists)
// Uncomment if you have the existing RFID HTTP endpoints
// export { api as rfidAttendanceApi } from './rfid-attendance';
//# sourceMappingURL=index.js.map