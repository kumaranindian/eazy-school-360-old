const functions = require('firebase-functions');
const admin = require('firebase-admin');
// Initialize Firebase Admin if not already initialized
if (!admin.apps.length) {
    admin.initializeApp();
}
const db = admin.firestore();
/**
 * Cloud Function: Handle leave cancellation requests
 * Triggered by: Document creation in /schools/{schoolId}/leaveCancellations/{cancellationId}
 */
exports.processLeaveCancellationRequest = functions.firestore
    .document('/schools/{schoolId}/leaveCancellations/{cancellationId}')
    .onCreate(async (snap, context) => {
    const { schoolId, cancellationId } = context.params;
    const cancellationData = snap.data();
    console.log(`Processing leave cancellation request: ${cancellationId} for leave: ${cancellationData.leaveApplicationId}`);
    try {
        // Validate the leave application exists and is in correct state
        await validateLeaveCancellationRequest(schoolId, cancellationData);
        console.log(`Leave cancellation request ${cancellationId} validation completed successfully`);
    }
    catch (error) {
        console.error('Leave cancellation validation failed:', error);
        // Mark cancellation as rejected due to validation failure
        await snap.ref.update({
            status: 'REJECTED',
            rejectionReason: `Validation failed: ${error.message}`,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            approvedBy: 'system_validation',
            approvedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        // Create system alert
        await createSystemAlert(schoolId, {
            type: 'LEAVE_CANCELLATION_VALIDATION_FAILED',
            cancellationId,
            leaveApplicationId: cancellationData.leaveApplicationId,
            staffId: cancellationData.staffId,
            error: error.message,
        });
    }
});
/**
 * Cloud Function: Handle leave cancellation approval/rejection
 * Triggered by: Document updates in /schools/{schoolId}/leaveCancellations/{cancellationId}
 */
exports.processLeaveCancellationApproval = functions.firestore
    .document('/schools/{schoolId}/leaveCancellations/{cancellationId}')
    .onUpdate(async (change, context) => {
    const { schoolId, cancellationId } = context.params;
    const beforeData = change.before.data();
    const afterData = change.after.data();
    // Check if status changed to approved
    if (beforeData.status !== 'APPROVED' && afterData.status === 'APPROVED') {
        console.log(`Processing approved leave cancellation: ${cancellationId} for leave: ${afterData.leaveApplicationId}`);
        try {
            await processApprovedLeaveCancellation(schoolId, afterData);
            console.log(`Leave cancellation ${cancellationId} processed successfully`);
        }
        catch (error) {
            console.error('Error processing approved leave cancellation:', error);
            // Revert the approval status
            await change.after.ref.update({
                status: 'PENDING',
                rejectionReason: `Processing failed: ${error.message}`,
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
            // Create system alert
            await createSystemAlert(schoolId, {
                type: 'LEAVE_CANCELLATION_PROCESSING_ERROR',
                cancellationId,
                leaveApplicationId: afterData.leaveApplicationId,
                error: error.message,
            });
            throw new functions.https.HttpsError('internal', 'Failed to process leave cancellation');
        }
    }
});
/**
 * Validate leave cancellation request
 */
async function validateLeaveCancellationRequest(schoolId, cancellationData) {
    // Check if leave application exists
    const leaveDoc = await db
        .collection('schools')
        .doc(schoolId)
        .collection('leaves')
        .doc(cancellationData.leaveApplicationId)
        .get();
    if (!leaveDoc.exists) {
        throw new Error('Leave application not found');
    }
    const leaveData = leaveDoc.data();
    // Check if leave is in a cancellable state
    if (leaveData.status !== 'APPROVED') {
        throw new Error('Only approved leaves can be cancelled through this process');
    }
    // Check if leave is in the future (can't cancel past leaves)
    const leaveStartDate = leaveData.startDate.toDate();
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    if (leaveStartDate < today) {
        throw new Error('Cannot cancel leave that has already started or passed');
    }
    // Check if applicant matches
    if (leaveData.applicantId !== cancellationData.applicantId) {
        throw new Error('Only the leave applicant can request cancellation');
    }
    // Check if there's already a pending cancellation request
    const existingCancellationQuery = await db
        .collection('schools')
        .doc(schoolId)
        .collection('leaveCancellations')
        .where('leaveApplicationId', '==', cancellationData.leaveApplicationId)
        .where('status', '==', 'PENDING')
        .get();
    if (!existingCancellationQuery.empty) {
        throw new Error('A cancellation request is already pending for this leave');
    }
}
/**
 * Process approved leave cancellation
 */
async function processApprovedLeaveCancellation(schoolId, cancellationData) {
    const { leaveApplicationId, staffId, leaveTypeId, academicYear, totalDaysToRestore } = cancellationData;
    // Get leave balance
    const balanceId = `${staffId}_${leaveTypeId}_${academicYear}`;
    const balanceRef = db
        .collection('schools')
        .doc(schoolId)
        .collection('leaveBalances')
        .doc(balanceId);
    await db.runTransaction(async (transaction) => {
        // Get current balance
        const balanceDoc = await transaction.get(balanceRef);
        if (!balanceDoc.exists) {
            throw new Error(`Leave balance not found: ${balanceId}`);
        }
        const currentBalance = balanceDoc.data();
        // Calculate new balance values
        const newUsed = Math.max(0, currentBalance.used - totalDaysToRestore);
        const newAvailable = currentBalance.available + totalDaysToRestore;
        // Update balance
        transaction.update(balanceRef, {
            used: newUsed,
            available: newAvailable,
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
        });
        // Update leave application status to cancelled
        const leaveRef = db
            .collection('schools')
            .doc(schoolId)
            .collection('leaves')
            .doc(leaveApplicationId);
        transaction.update(leaveRef, {
            status: 'CANCELLED',
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
            cancellationReason: cancellationData.cancellationReason,
        });
        // Create balance mutation record
        const mutationRef = db
            .collection('schools')
            .doc(schoolId)
            .collection('balanceMutations')
            .doc();
        const mutationData = {
            schoolId,
            staffId,
            userId: cancellationData.applicantId,
            leaveTypeId,
            academicYear,
            mutationType: 'CANCELLATION_RESTORE',
            previousValue: currentBalance.used,
            newValue: newUsed,
            delta: totalDaysToRestore,
            referenceId: leaveApplicationId,
            reason: `Leave cancelled: ${totalDaysToRestore} days restored to balance`,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            createdBy: cancellationData.approvedBy || 'system',
            metadata: {
                cancellationId: cancellationData.id || 'unknown',
                cancellationReason: cancellationData.cancellationReason,
                functionName: 'processApprovedLeaveCancellation'
            }
        };
        transaction.set(mutationRef, mutationData);
    });
    console.log(`Balance restored for ${staffId}: ${totalDaysToRestore} days returned. Leave ${leaveApplicationId} cancelled.`);
}
/**
 * Cloud Function: Handle permission request status changes
 * Triggered by: Document updates in /schools/{schoolId}/permissions/{permissionId}
 */
exports.processPermissionStatusChange = functions.firestore
    .document('/schools/{schoolId}/permissions/{permissionId}')
    .onUpdate(async (change, context) => {
    const { schoolId, permissionId } = context.params;
    const beforeData = change.before.data();
    const afterData = change.after.data();
    // Check if status changed
    if (beforeData.status === afterData.status) {
        return; // No status change, nothing to do
    }
    console.log(`Permission status changed from ${beforeData.status} to ${afterData.status} for permission: ${permissionId}`);
    try {
        await updateMonthlyPermissionUsage(schoolId, afterData, beforeData.status, afterData.status);
    }
    catch (error) {
        console.error('Error updating monthly permission usage:', error);
        // Create system alert for admin attention
        await createSystemAlert(schoolId, {
            type: 'PERMISSION_USAGE_UPDATE_ERROR',
            permissionId,
            staffId: afterData.staffId,
            error: error.message,
            beforeStatus: beforeData.status,
            afterStatus: afterData.status,
        });
        throw new functions.https.HttpsError('internal', 'Failed to update permission usage');
    }
});
/**
 * Cloud Function: Validate permission request on creation
 * Triggered by: Document creation in /schools/{schoolId}/permissions/{permissionId}
 */
exports.validatePermissionRequest = functions.firestore
    .document('/schools/{schoolId}/permissions/{permissionId}')
    .onCreate(async (snap, context) => {
    const { schoolId, permissionId } = context.params;
    const permissionData = snap.data();
    console.log(`Validating new permission request: ${permissionId} for staff: ${permissionData.staffId}`);
    try {
        // Validate permission request data
        await validatePermissionRequestData(schoolId, permissionData);
        // Check monthly limits
        await validateMonthlyPermissionLimits(schoolId, permissionData);
        // Initialize monthly usage tracking
        await initializeMonthlyUsageTracking(schoolId, permissionData);
        console.log(`Permission request ${permissionId} validation completed successfully`);
    }
    catch (error) {
        console.error('Permission request validation failed:', error);
        // Mark permission as rejected due to validation failure
        await snap.ref.update({
            status: 'REJECTED',
            rejectionReason: `Validation failed: ${error.message}`,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            approvedBy: 'system_validation',
            approvedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        // Create system alert
        await createSystemAlert(schoolId, {
            type: 'PERMISSION_VALIDATION_FAILED',
            permissionId,
            staffId: permissionData.staffId,
            error: error.message,
        });
    }
});
/**
 * Update monthly permission usage tracking
 */
async function updateMonthlyPermissionUsage(schoolId, permissionData, previousStatus, newStatus) {
    const { staffId, applicantId, durationMinutes, requestDate } = permissionData;
    const month = getMonthFromDate(requestDate.toDate());
    const usageId = `${staffId}_${month}`;
    const usageRef = db
        .collection('schools')
        .doc(schoolId)
        .collection('monthlyPermissionUsage')
        .doc(usageId);
    await db.runTransaction(async (transaction) => {
        const usageDoc = await transaction.get(usageRef);
        let usageData;
        if (usageDoc.exists) {
            usageData = usageDoc.data();
        }
        else {
            // Create new usage record
            usageData = {
                schoolId,
                staffId,
                userId: applicantId,
                month,
                totalRequests: 0,
                approvedRequests: 0,
                totalMinutesUsed: 0,
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                metadata: {}
            };
        }
        // Update counters based on status change
        if (previousStatus === 'PENDING' && newStatus === 'APPROVED') {
            usageData.approvedRequests += 1;
            usageData.totalMinutesUsed += durationMinutes;
        }
        else if (previousStatus === 'APPROVED' && (newStatus === 'REJECTED' || newStatus === 'CANCELLED')) {
            usageData.approvedRequests = Math.max(0, usageData.approvedRequests - 1);
            usageData.totalMinutesUsed = Math.max(0, usageData.totalMinutesUsed - durationMinutes);
        }
        usageData.updatedAt = admin.firestore.FieldValue.serverTimestamp();
        if (usageDoc.exists) {
            transaction.update(usageRef, usageData);
        }
        else {
            transaction.set(usageRef, usageData);
        }
    });
    console.log(`Monthly permission usage updated for ${staffId} in ${month}: ${newStatus}`);
}
/**
 * Validate permission request data
 */
async function validatePermissionRequestData(schoolId, permissionData) {
    // Check required fields
    const requiredFields = [
        'schoolId', 'applicantId', 'staffId', 'requestDate', 'startTime',
        'endTime', 'durationMinutes', 'reason'
    ];
    for (const field of requiredFields) {
        if (!permissionData[field]) {
            throw new Error(`Missing required field: ${field}`);
        }
    }
    // Validate dates and times
    const requestDate = permissionData.requestDate.toDate();
    const startTime = permissionData.startTime.toDate();
    const endTime = permissionData.endTime.toDate();
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    if (requestDate < today) {
        throw new Error('Permission date cannot be in the past');
    }
    if (endTime <= startTime) {
        throw new Error('End time must be after start time');
    }
    // Validate duration
    const calculatedDuration = Math.floor((endTime - startTime) / (1000 * 60));
    if (Math.abs(calculatedDuration - permissionData.durationMinutes) > 1) {
        throw new Error('Duration mismatch between calculated and provided values');
    }
    // Get permission configuration
    const configDoc = await db
        .collection('schools')
        .doc(schoolId)
        .collection('permissionConfig')
        .doc('default')
        .get();
    if (!configDoc.exists) {
        throw new Error('Permission configuration not found for school');
    }
    const config = configDoc.data();
    // Validate against configuration limits
    if (permissionData.durationMinutes > config.maxDurationMinutes) {
        throw new Error(`Permission duration exceeds maximum allowed (${config.maxDurationMinutes} minutes)`);
    }
}
/**
 * Validate monthly permission limits
 */
async function validateMonthlyPermissionLimits(schoolId, permissionData) {
    const { staffId, requestDate } = permissionData;
    const month = getMonthFromDate(requestDate.toDate());
    // Get permission configuration
    const configDoc = await db
        .collection('schools')
        .doc(schoolId)
        .collection('permissionConfig')
        .doc('default')
        .get();
    if (!configDoc.exists) {
        throw new Error('Permission configuration not found');
    }
    const config = configDoc.data();
    // Get current month's usage
    const usageId = `${staffId}_${month}`;
    const usageDoc = await db
        .collection('schools')
        .doc(schoolId)
        .collection('monthlyPermissionUsage')
        .doc(usageId)
        .get();
    let currentRequests = 0;
    if (usageDoc.exists) {
        currentRequests = usageDoc.data().totalRequests || 0;
    }
    // Check monthly limit
    if (currentRequests >= config.monthlyLimit) {
        throw new Error(`Monthly permission limit exceeded (${config.monthlyLimit} permissions per month)`);
    }
}
/**
 * Initialize monthly usage tracking
 */
async function initializeMonthlyUsageTracking(schoolId, permissionData) {
    const { staffId, applicantId, requestDate } = permissionData;
    const month = getMonthFromDate(requestDate.toDate());
    const usageId = `${staffId}_${month}`;
    const usageRef = db
        .collection('schools')
        .doc(schoolId)
        .collection('monthlyPermissionUsage')
        .doc(usageId);
    await db.runTransaction(async (transaction) => {
        const usageDoc = await transaction.get(usageRef);
        if (usageDoc.exists) {
            // Increment total requests
            transaction.update(usageRef, {
                totalRequests: admin.firestore.FieldValue.increment(1),
                updatedAt: admin.firestore.FieldValue.serverTimestamp()
            });
        }
        else {
            // Create new usage record
            const usageData = {
                schoolId,
                staffId,
                userId: applicantId,
                month,
                totalRequests: 1,
                approvedRequests: 0,
                totalMinutesUsed: 0,
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                metadata: {}
            };
            transaction.set(usageRef, usageData);
        }
    });
}
/**
 * Create system alert for admin attention
 */
async function createSystemAlert(schoolId, alertData) {
    try {
        await db.collection('systemAlerts').add({
            schoolId,
            type: alertData.type,
            severity: 'HIGH',
            message: `Leave/Permission processing issue: ${alertData.error || 'Unknown error'}`,
            data: alertData,
            resolved: false,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            createdBy: 'system_leave_permission_workflow',
        });
    }
    catch (error) {
        console.error('Failed to create system alert:', error);
    }
}
/**
 * Get month string from date (YYYY-MM format)
 */
function getMonthFromDate(date) {
    return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}`;
}
//# sourceMappingURL=leave-cancellation-workflow.js.map