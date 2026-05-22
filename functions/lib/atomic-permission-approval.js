const functions = require('firebase-functions');
const admin = require('firebase-admin');
// Initialize Firebase Admin if not already initialized
if (!admin.apps.length) {
    admin.initializeApp();
}
const db = admin.firestore();
/**
 * ATOMIC PERMISSION APPROVAL CLOUD FUNCTION
 * Fixes: Race conditions, idempotency, atomic usage tracking
 *
 * Triggered by: Document updates in /schools/{schoolId}/permissions/{permissionId}
 * When status changes from PENDING to APPROVED/REJECTED
 */
exports.processPermissionStatusChange = functions.firestore
    .document('/schools/{schoolId}/permissions/{permissionId}')
    .onUpdate(async (change, context) => {
    const { schoolId, permissionId } = context.params;
    const beforeData = change.before.data();
    const afterData = change.after.data();
    // IDEMPOTENCY CHECK #1: Status must have changed
    if (beforeData.status === afterData.status) {
        console.log(`No status change for permission ${permissionId}, skipping processing`);
        return;
    }
    // IDEMPOTENCY CHECK #2: Already processed
    if (afterData.processedAt) {
        console.log(`Permission ${permissionId} already processed at ${afterData.processedAt}, skipping`);
        return;
    }
    // Only process PENDING -> APPROVED/REJECTED transitions
    if (beforeData.status !== 'PENDING') {
        console.log(`Permission ${permissionId} status changed from ${beforeData.status} to ${afterData.status}, but not from PENDING - skipping usage update`);
        return;
    }
    if (!['APPROVED', 'REJECTED'].includes(afterData.status)) {
        console.log(`Permission ${permissionId} status changed to ${afterData.status}, no usage update needed`);
        return;
    }
    console.log(`Processing permission ${permissionId}: ${beforeData.status} -> ${afterData.status}`);
    try {
        await updateMonthlyPermissionUsageAtomic(schoolId, permissionId, afterData, beforeData.status, afterData.status);
        console.log(`Permission ${permissionId} processed successfully`);
    }
    catch (error) {
        console.error(`Error processing permission ${permissionId}:`, error);
        // ATOMIC ROLLBACK: Revert status change on error
        await change.after.ref.update({
            status: 'PENDING',
            approvedBy: null,
            approvedAt: null,
            rejectedBy: null,
            rejectedAt: null,
            rejectionReason: null,
            processedAt: null,
            errorMessage: `Processing failed: ${error.message}`,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        // Create system alert
        await createSystemAlert(schoolId, {
            type: 'PERMISSION_PROCESSING_ERROR',
            permissionId,
            applicantId: afterData.applicantId,
            error: error.message,
            attemptedStatus: afterData.status,
        });
        throw new functions.https.HttpsError('internal', `Failed to process permission: ${error.message}`);
    }
});
/**
 * ATOMIC MONTHLY PERMISSION USAGE UPDATE
 * All operations in single transaction to prevent race conditions
 */
async function updateMonthlyPermissionUsageAtomic(schoolId, permissionId, permissionData, previousStatus, newStatus) {
    const { applicantId, durationMinutes, requestDate } = permissionData;
    const month = getMonthFromDate(requestDate.toDate());
    const usageId = `${applicantId}_${month}`;
    const usageRef = db
        .collection('schools')
        .doc(schoolId)
        .collection('monthlyPermissionUsage')
        .doc(usageId);
    const permissionRef = db
        .collection('schools')
        .doc(schoolId)
        .collection('permissions')
        .doc(permissionId);
    // ATOMIC TRANSACTION: All operations must succeed or all fail
    await db.runTransaction(async (transaction) => {
        // STEP 1: Re-read permission document to check for concurrent modifications
        const currentPermissionDoc = await transaction.get(permissionRef);
        if (!currentPermissionDoc.exists) {
            throw new Error('Permission request not found');
        }
        const currentPermissionData = currentPermissionDoc.data();
        // RACE CONDITION PROTECTION: Verify permission is still in expected state
        if (currentPermissionData.status !== newStatus) {
            throw new Error(`Permission status changed during processing. Expected: ${newStatus}, Found: ${currentPermissionData.status}`);
        }
        // IDEMPOTENCY CHECK #3: Inside transaction
        if (currentPermissionData.processedAt) {
            console.log(`Permission ${permissionId} already processed, skipping`);
            return;
        }
        // STEP 2: Get or create monthly usage record
        const usageDoc = await transaction.get(usageRef);
        let usageData;
        if (usageDoc.exists) {
            usageData = usageDoc.data();
        }
        else {
            // Create new usage record
            usageData = {
                schoolId,
                userId: applicantId,
                month,
                totalRequests: 0,
                approvedRequests: 0,
                rejectedRequests: 0,
                totalMinutesUsed: 0,
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                metadata: {}
            };
        }
        // STEP 3: Update counters based on status change
        if (previousStatus === 'PENDING' && newStatus === 'APPROVED') {
            usageData.approvedRequests += 1;
            usageData.totalMinutesUsed += durationMinutes;
        }
        else if (previousStatus === 'PENDING' && newStatus === 'REJECTED') {
            usageData.rejectedRequests += 1;
        }
        else if (previousStatus === 'APPROVED' && newStatus === 'REJECTED') {
            // Reversal: approved -> rejected
            usageData.approvedRequests = Math.max(0, usageData.approvedRequests - 1);
            usageData.rejectedRequests += 1;
            usageData.totalMinutesUsed = Math.max(0, usageData.totalMinutesUsed - durationMinutes);
        }
        else if (previousStatus === 'APPROVED' && newStatus === 'CANCELLED') {
            // Cancellation of approved permission
            usageData.approvedRequests = Math.max(0, usageData.approvedRequests - 1);
            usageData.totalMinutesUsed = Math.max(0, usageData.totalMinutesUsed - durationMinutes);
        }
        usageData.updatedAt = admin.firestore.FieldValue.serverTimestamp();
        // STEP 4: Update or create usage record
        if (usageDoc.exists) {
            transaction.update(usageRef, usageData);
        }
        else {
            transaction.set(usageRef, usageData);
        }
        // STEP 5: Mark permission as processed
        transaction.update(permissionRef, {
            processedAt: admin.firestore.FieldValue.serverTimestamp(),
            usageUpdated: true,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        // STEP 6: Create usage mutation record for audit trail
        const mutationRef = db
            .collection('schools')
            .doc(schoolId)
            .collection('permissionUsageMutations')
            .doc();
        const mutationData = {
            schoolId,
            userId: applicantId,
            permissionId,
            month,
            mutationType: `PERMISSION_${newStatus}`,
            previousApproved: usageDoc.exists ? (usageDoc.data().approvedRequests || 0) : 0,
            newApproved: usageData.approvedRequests,
            previousMinutes: usageDoc.exists ? (usageDoc.data().totalMinutesUsed || 0) : 0,
            newMinutes: usageData.totalMinutesUsed,
            deltaMinutes: newStatus === 'APPROVED' ? durationMinutes : (newStatus === 'REJECTED' && previousStatus === 'APPROVED' ? -durationMinutes : 0),
            referenceId: permissionId,
            reason: `Permission ${newStatus.toLowerCase()}: ${durationMinutes} minutes ${newStatus === 'APPROVED' ? 'added to' : 'removed from'} usage`,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            createdBy: currentPermissionData.approvedBy || currentPermissionData.rejectedBy || 'system',
            metadata: {
                requestDate: permissionData.requestDate,
                startTime: permissionData.startTime,
                endTime: permissionData.endTime,
                functionName: 'updateMonthlyPermissionUsageAtomic',
                transactionId: `txn_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
            }
        };
        transaction.set(mutationRef, mutationData);
        console.log(`Monthly permission usage updated for ${applicantId} in ${month}: ${newStatus}, ${usageData.totalMinutesUsed} total minutes`);
    });
}
/**
 * BACKEND-ONLY PERMISSION REQUEST CREATION
 * Validates limits and calculates duration
 */
exports.createPermissionRequest = functions.https.onCall(async (data, context) => {
    // Authentication check
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }
    const { schoolId, requestDate, startTime, endTime, reason } = data;
    const applicantId = context.auth.uid;
    try {
        // STEP 1: BACKEND-ONLY CALCULATION: Calculate duration
        const startDateTime = new Date(`${requestDate}T${startTime}`);
        const endDateTime = new Date(`${requestDate}T${endTime}`);
        if (endDateTime <= startDateTime) {
            throw new functions.https.HttpsError('invalid-argument', 'End time must be after start time');
        }
        const durationMinutes = Math.floor((endDateTime - startDateTime) / (1000 * 60));
        // STEP 2: Validate permission configuration and limits
        await validatePermissionLimits(schoolId, applicantId, requestDate, durationMinutes);
        // STEP 3: Check for overlapping permissions
        await validateNoOverlappingPermissions(schoolId, applicantId, requestDate, startDateTime, endDateTime);
        // STEP 4: Initialize monthly usage tracking
        await initializeMonthlyUsageTracking(schoolId, applicantId, requestDate);
        // STEP 5: Create permission request
        const permissionRef = db
            .collection('schools')
            .doc(schoolId)
            .collection('permissions')
            .doc();
        const permissionData = {
            schoolId,
            applicantId,
            requestDate: admin.firestore.Timestamp.fromDate(new Date(requestDate)),
            startTime: admin.firestore.Timestamp.fromDate(startDateTime),
            endTime: admin.firestore.Timestamp.fromDate(endDateTime),
            durationMinutes,
            reason,
            status: 'PENDING',
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            metadata: {
                calculatedBy: 'backend',
                functionName: 'createPermissionRequest',
            }
        };
        await permissionRef.set(permissionData);
        console.log(`Permission request created: ${permissionRef.id} for ${applicantId}, ${durationMinutes} minutes`);
        return {
            permissionId: permissionRef.id,
            durationMinutes,
            status: 'PENDING',
        };
    }
    catch (error) {
        console.error('Error creating permission request:', error);
        if (error instanceof functions.https.HttpsError) {
            throw error;
        }
        throw new functions.https.HttpsError('internal', error.message);
    }
});
/**
 * Validate permission limits against configuration
 */
async function validatePermissionLimits(schoolId, applicantId, requestDate, durationMinutes) {
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
    // Validate duration against maximum allowed
    if (durationMinutes > config.maxDurationMinutes) {
        throw new Error(`Permission duration exceeds maximum allowed (${config.maxDurationMinutes} minutes)`);
    }
    // Validate monthly limits
    const month = getMonthFromDate(new Date(requestDate));
    const usageId = `${applicantId}_${month}`;
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
    // Validate request date is not in the past
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const reqDate = new Date(requestDate);
    if (reqDate < today) {
        throw new Error('Permission date cannot be in the past');
    }
}
/**
 * Validate no overlapping permissions
 */
async function validateNoOverlappingPermissions(schoolId, applicantId, requestDate, startDateTime, endDateTime) {
    const overlappingQuery = await db
        .collection('schools')
        .doc(schoolId)
        .collection('permissions')
        .where('applicantId', '==', applicantId)
        .where('requestDate', '==', admin.firestore.Timestamp.fromDate(new Date(requestDate)))
        .where('status', 'in', ['PENDING', 'APPROVED'])
        .get();
    for (const doc of overlappingQuery.docs) {
        const permission = doc.data();
        const permissionStart = permission.startTime.toDate();
        const permissionEnd = permission.endTime.toDate();
        // Check for time overlap
        if (startDateTime < permissionEnd && endDateTime > permissionStart) {
            throw new Error(`Overlapping permission found: ${doc.id} (${permissionStart.toTimeString()} to ${permissionEnd.toTimeString()})`);
        }
    }
}
/**
 * Initialize monthly usage tracking
 */
async function initializeMonthlyUsageTracking(schoolId, applicantId, requestDate) {
    const month = getMonthFromDate(new Date(requestDate));
    const usageId = `${applicantId}_${month}`;
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
                userId: applicantId,
                month,
                totalRequests: 1,
                approvedRequests: 0,
                rejectedRequests: 0,
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
 * DIRECT PERMISSION CANCELLATION (for pending permissions)
 * Allows staff to cancel their own pending permissions immediately
 */
exports.cancelPendingPermission = functions.https.onCall(async (data, context) => {
    // Authentication check
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }
    const { schoolId, permissionId } = data;
    const applicantId = context.auth.uid;
    try {
        const permissionRef = db
            .collection('schools')
            .doc(schoolId)
            .collection('permissions')
            .doc(permissionId);
        // ATOMIC TRANSACTION: Cancel pending permission and update usage
        await db.runTransaction(async (transaction) => {
            const permissionDoc = await transaction.get(permissionRef);
            if (!permissionDoc.exists) {
                throw new Error('Permission request not found');
            }
            const permissionData = permissionDoc.data();
            // Verify ownership
            if (permissionData.applicantId !== applicantId) {
                throw new Error('You can only cancel your own permission requests');
            }
            // Verify permission is pending
            if (permissionData.status !== 'PENDING') {
                throw new Error('Only pending permissions can be cancelled directly');
            }
            // STEP 1: Update permission status to cancelled
            transaction.update(permissionRef, {
                status: 'CANCELLED',
                cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
                cancelledBy: applicantId,
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
            // STEP 2: Update monthly usage (decrement total requests)
            const month = getMonthFromDate(permissionData.requestDate.toDate());
            const usageId = `${applicantId}_${month}`;
            const usageRef = db
                .collection('schools')
                .doc(schoolId)
                .collection('monthlyPermissionUsage')
                .doc(usageId);
            const usageDoc = await transaction.get(usageRef);
            if (usageDoc.exists) {
                const currentUsage = usageDoc.data();
                const newTotalRequests = Math.max(0, currentUsage.totalRequests - 1);
                transaction.update(usageRef, {
                    totalRequests: newTotalRequests,
                    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                });
            }
        });
        console.log(`Pending permission ${permissionId} cancelled successfully by ${applicantId}`);
        return {
            success: true,
            message: 'Permission cancelled successfully',
        };
    }
    catch (error) {
        console.error('Error cancelling pending permission:', error);
        throw new functions.https.HttpsError('internal', error.message);
    }
});
/**
 * Get month string from date (YYYY-MM format)
 */
function getMonthFromDate(date) {
    return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}`;
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
            message: `Permission processing issue: ${alertData.error || 'Unknown error'}`,
            data: alertData,
            resolved: false,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            createdBy: 'system_permission_workflow',
        });
    }
    catch (error) {
        console.error('Failed to create system alert:', error);
    }
}
//# sourceMappingURL=atomic-permission-approval.js.map