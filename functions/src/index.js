const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Initialize Firebase Admin
admin.initializeApp();

// Import ATOMIC workflow modules (CRITICAL FIXES)
const atomicLeaveApproval = require('./atomic-leave-approval');
const atomicLeaveCancellation = require('./atomic-leave-cancellation');
const atomicPermissionApproval = require('./atomic-permission-approval');

// ATOMIC LEAVE APPROVAL FUNCTIONS (RACE-CONDITION SAFE)
exports.processLeaveStatusChange = atomicLeaveApproval.processLeaveStatusChange;
exports.createLeaveApplication = atomicLeaveApproval.createLeaveApplication;

// ATOMIC LEAVE CANCELLATION FUNCTIONS (IDEMPOTENT)
exports.processLeaveCancellationApproval = atomicLeaveCancellation.processLeaveCancellationApproval;
exports.createLeaveCancellationRequest = atomicLeaveCancellation.createLeaveCancellationRequest;
exports.cancelPendingLeave = atomicLeaveCancellation.cancelPendingLeave;

// ATOMIC PERMISSION APPROVAL FUNCTIONS (USAGE TRACKING SAFE)
exports.processPermissionStatusChange = atomicPermissionApproval.processPermissionStatusChange;
exports.createPermissionRequest = atomicPermissionApproval.createPermissionRequest;
exports.cancelPendingPermission = atomicPermissionApproval.cancelPendingPermission;

// Health check function
exports.healthCheck = functions.https.onRequest((req, res) => {
  res.status(200).send({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    message: 'Eazy School 360 Atomic Cloud Functions are running',
    features: {
      atomicBalanceOperations: true,
      idempotencyProtection: true,
      raceConditionSafe: true,
      backendOnlyLogic: true
    }
  });
});

// Import weekly due notification scheduler
const weeklyDueNotification = require('./weekly-due-notification');
exports.sendWeeklyDueNotifications = weeklyDueNotification.sendWeeklyDueNotifications;
