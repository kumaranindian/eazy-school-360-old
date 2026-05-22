const functions = require('firebase-functions');
const admin = require('firebase-admin');
// Initialize Firebase Admin if not already initialized
if (!admin.apps.length) {
    admin.initializeApp();
}
const db = admin.firestore();
/**
 * Cloud Function: Handle leave application status changes and update balances
 * Triggered by: Document updates in /schools/{schoolId}/leaves/{leaveId}
 */
exports.processLeaveStatusChange = functions.firestore
    .document('/schools/{schoolId}/leaves/{leaveId}')
    .onUpdate(async (change, context) => {
    const { schoolId, leaveId } = context.params;
    const beforeData = change.before.data();
    const afterData = change.after.data();
    // Check if status changed
    if (beforeData.status === afterData.status) {
        return; // No status change, nothing to do
    }
    console.log(`Leave status changed from ${beforeData.status} to ${afterData.status} for leave: ${leaveId}`);
    try {
        await processLeaveStatusChange(schoolId, leaveId, beforeData, afterData);
    }
    catch (error) {
        console.error('Error processing leave status change:', error);
        // Create system alert for admin attention
        await createSystemAlert(schoolId, {
            type: 'LEAVE_PROCESSING_ERROR',
            leaveId,
            error: error.message,
            beforeStatus: beforeData.status,
            afterStatus: afterData.status,
        });
        throw new functions.https.HttpsError('internal', 'Failed to process leave status change');
    }
});
/**
 * Cloud Function: Validate leave application before creation
 * Triggered by: Document creation in /schools/{schoolId}/leaves/{leaveId}
 */
exports.validateLeaveApplication = functions.firestore
    .document('/schools/{schoolId}/leaves/{leaveId}')
    .onCreate(async (snap, context) => {
    const { schoolId, leaveId } = context.params;
    const leaveData = snap.data();
    console.log(`Validating new leave application: ${leaveId} for staff: ${leaveData.staffId}`);
    try {
        // Validate leave application data
        await validateLeaveApplicationData(schoolId, leaveId, leaveData);
        // Check for overlapping leaves (additional server-side validation)
        await validateNoOverlappingLeaves(schoolId, leaveData);
        // Validate sufficient balance
        await validateSufficientBalance(schoolId, leaveData);
        console.log(`Leave application ${leaveId} validation completed successfully`);
    }
    catch (error) {
        console.error('Leave application validation failed:', error);
        // Mark application as invalid and notify
        await snap.ref.update({
            status: 'REJECTED',
            rejectionReason: `Validation failed: ${error.message}`,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            approvedBy: 'system_validation',
            approvedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        // Create system alert
        await createSystemAlert(schoolId, {
            type: 'LEAVE_VALIDATION_FAILED',
            leaveId,
            staffId: leaveData.staffId,
            error: error.message,
        });
    }
});
/**
 * Process leave status change and update balances accordingly
 */
async function processLeaveStatusChange(schoolId, leaveId, beforeData, afterData) {
    const { staffId, applicantId, leaveTypeId, academicYear, totalDays } = afterData;
    const previousStatus = beforeData.status;
    const newStatus = afterData.status;
    // Get current balance
    const balanceId = `${staffId}_${leaveTypeId}_${academicYear}`;
    const balanceRef = db
        .collection('schools')
        .doc(schoolId)
        .collection('leaveBalances')
        .doc(balanceId);
    await db.runTransaction(async (transaction) => {
        const balanceDoc = await transaction.get(balanceRef);
        if (!balanceDoc.exists) {
            throw new Error(`Balance not found: ${balanceId}`);
        }
        const currentBalance = balanceDoc.data();
        let newUsed = currentBalance.used;
        let newPending = currentBalance.pending;
        let mutationType = '';
        let reason = '';
        // Handle status transitions
        if (previousStatus === 'PENDING' && newStatus === 'APPROVED') {
            // Move from pending to used
            newPending = Math.max(0, newPending - totalDays);
            newUsed = newUsed + totalDays;
            mutationType = 'USED';
            reason = `Leave approved: ${totalDays} days deducted from balance`;
        }
        else if (previousStatus === 'PENDING' && (newStatus === 'REJECTED' || newStatus === 'CANCELLED')) {
            // Remove from pending
            newPending = Math.max(0, newPending - totalDays);
            mutationType = 'PENDING_REMOVED';
            reason = `Leave ${newStatus.toLowerCase()}: ${totalDays} days released from pending`;
        }
        else if (previousStatus === 'APPROVED' && newStatus === 'CANCELLED') {
            // Return used days (rare case, but possible for future leaves)
            newUsed = Math.max(0, newUsed - totalDays);
            mutationType = 'ADJUSTMENT';
            reason = `Leave cancelled: ${totalDays} days returned to balance`;
        }
        else {
            // No balance change needed for other transitions
            console.log(`No balance update needed for transition ${previousStatus} -> ${newStatus}`);
            return;
        }
        // Calculate new available balance
        const newAvailable = currentBalance.totalAllowed + currentBalance.carriedForward - newUsed - newPending;
        // Validate balance doesn't go negative (should not happen with proper validation)
        if (newAvailable < 0) {
            throw new Error(`Balance would become negative: ${newAvailable}. Current: ${currentBalance.available}, Requested: ${totalDays}`);
        }
        // Update balance
        const updatedBalance = {
            used: newUsed,
            pending: newPending,
            available: newAvailable,
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
        };
        transaction.update(balanceRef, updatedBalance);
        // Create mutation record
        const mutationRef = db
            .collection('schools')
            .doc(schoolId)
            .collection('balanceMutations')
            .doc();
        const mutationData = {
            schoolId,
            staffId,
            userId: applicantId,
            leaveTypeId,
            academicYear,
            mutationType,
            previousValue: mutationType === 'USED' ? currentBalance.used : currentBalance.pending,
            newValue: mutationType === 'USED' ? newUsed : newPending,
            delta: mutationType === 'USED' ? totalDays : -totalDays,
            referenceId: leaveId,
            reason,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            createdBy: afterData.approvedBy || 'system',
            metadata: {
                leaveRequestDates: afterData.leaveDates || [],
                previousStatus,
                newStatus,
                totalDays,
                functionName: 'processLeaveStatusChange'
            }
        };
        transaction.set(mutationRef, mutationData);
    });
    console.log(`Balance updated for ${staffId}: ${mutationType} ${totalDays} days. Status: ${previousStatus} -> ${newStatus}`);
}
/**
 * Validate leave application data
 */
async function validateLeaveApplicationData(schoolId, leaveId, leaveData) {
    // Check required fields
    const requiredFields = [
        'schoolId', 'applicantId', 'staffId', 'leaveTypeId', 'leaveTypeCode',
        'academicYear', 'startDate', 'endDate', 'leaveDates', 'totalDays', 'reason'
    ];
    for (const field of requiredFields) {
        if (!leaveData[field]) {
            throw new Error(`Missing required field: ${field}`);
        }
    }
    // Validate dates
    const startDate = leaveData.startDate.toDate();
    const endDate = leaveData.endDate.toDate();
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    if (startDate < today) {
        throw new Error('Leave start date cannot be in the past');
    }
    if (endDate < startDate) {
        throw new Error('Leave end date must be after start date');
    }
    // Validate total days
    if (leaveData.totalDays <= 0) {
        throw new Error('Total leave days must be greater than 0');
    }
    if (leaveData.leaveDates.length !== leaveData.totalDays) {
        throw new Error('Leave dates count does not match total days');
    }
    // Validate leave type exists and is active
    const leaveTypeDoc = await db
        .collection('schools')
        .doc(schoolId)
        .collection('leaveTypes')
        .doc(leaveData.leaveTypeId)
        .get();
    if (!leaveTypeDoc.exists) {
        throw new Error('Leave type not found');
    }
    const leaveType = leaveTypeDoc.data();
    if (!leaveType.isActive) {
        throw new Error('Leave type is not active');
    }
    // Validate against leave type constraints
    if (leaveData.totalDays > leaveType.maxDaysPerRequest) {
        throw new Error(`Leave request exceeds maximum ${leaveType.maxDaysPerRequest} days per request`);
    }
    // Validate academic year
    const currentAcademicYear = getCurrentAcademicYear();
    if (leaveData.academicYear !== currentAcademicYear) {
        throw new Error('Leave request must be for current academic year');
    }
}
/**
 * Validate no overlapping leaves
 */
async function validateNoOverlappingLeaves(schoolId, leaveData) {
    const existingLeavesQuery = await db
        .collection('schools')
        .doc(schoolId)
        .collection('leaves')
        .where('applicantId', '==', leaveData.applicantId)
        .where('status', 'in', ['PENDING', 'APPROVED'])
        .get();
    const requestedDates = leaveData.leaveDates.map(timestamp => {
        const date = timestamp.toDate();
        return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`;
    });
    for (const doc of existingLeavesQuery.docs) {
        const existingLeave = doc.data();
        const existingDates = existingLeave.leaveDates.map(timestamp => {
            const date = timestamp.toDate();
            return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`;
        });
        // Check for overlapping dates
        const overlap = requestedDates.some(date => existingDates.includes(date));
        if (overlap) {
            throw new Error(`Leave request overlaps with existing application: ${doc.id}`);
        }
    }
}
/**
 * Validate sufficient balance
 */
async function validateSufficientBalance(schoolId, leaveData) {
    const balanceId = `${leaveData.staffId}_${leaveData.leaveTypeId}_${leaveData.academicYear}`;
    const balanceDoc = await db
        .collection('schools')
        .doc(schoolId)
        .collection('leaveBalances')
        .doc(balanceId)
        .get();
    if (!balanceDoc.exists) {
        throw new Error('Leave balance not found for this leave type');
    }
    const balance = balanceDoc.data();
    if (balance.available < leaveData.totalDays) {
        throw new Error(`Insufficient leave balance. Available: ${balance.available}, Requested: ${leaveData.totalDays}`);
    }
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
            message: `Leave processing issue: ${alertData.error || 'Unknown error'}`,
            data: alertData,
            resolved: false,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            createdBy: 'system_leave_workflow',
        });
    }
    catch (error) {
        console.error('Failed to create system alert:', error);
    }
}
/**
 * Get current academic year (June 1 to May 31)
 */
function getCurrentAcademicYear() {
    const now = new Date();
    const currentYear = now.getFullYear();
    // Academic year starts June 1
    if (now.getMonth() < 5) { // Before June (0-indexed)
        return `${currentYear - 1}-${currentYear.toString().substring(2)}`;
    }
    else {
        return `${currentYear}-${(currentYear + 1).toString().substring(2)}`;
    }
}
/**
 * Cloud Function: Bulk approve/reject leave applications (Admin batch operations)
 */
exports.bulkProcessLeaveApplications = functions.https.onCall(async (data, context) => {
    // Verify authentication
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }
    const { schoolId, leaveIds, action, rejectionReason, remarks } = data;
    // Validate input
    if (!schoolId || !leaveIds || !Array.isArray(leaveIds) || !action) {
        throw new functions.https.HttpsError('invalid-argument', 'Missing required parameters');
    }
    if (!['APPROVED', 'REJECTED'].includes(action)) {
        throw new functions.https.HttpsError('invalid-argument', 'Invalid action');
    }
    if (action === 'REJECTED' && !rejectionReason) {
        throw new functions.https.HttpsError('invalid-argument', 'Rejection reason required');
    }
    try {
        // Validate admin permissions
        await validateAdminAccess(context.auth.uid, schoolId);
        const results = [];
        const batch = db.batch();
        for (const leaveId of leaveIds) {
            try {
                const leaveRef = db
                    .collection('schools')
                    .doc(schoolId)
                    .collection('leaves')
                    .doc(leaveId);
                const leaveDoc = await leaveRef.get();
                if (!leaveDoc.exists) {
                    results.push({ leaveId, success: false, error: 'Leave application not found' });
                    continue;
                }
                const leaveData = leaveDoc.data();
                if (leaveData.status !== 'PENDING') {
                    results.push({ leaveId, success: false, error: 'Leave application is not pending' });
                    continue;
                }
                // Update leave application
                const updateData = {
                    status: action,
                    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                    approvedBy: context.auth.uid,
                    approvedAt: admin.firestore.FieldValue.serverTimestamp(),
                };
                if (rejectionReason) {
                    updateData.rejectionReason = rejectionReason;
                }
                if (remarks) {
                    updateData.remarks = remarks;
                }
                batch.update(leaveRef, updateData);
                results.push({ leaveId, success: true });
            }
            catch (error) {
                results.push({ leaveId, success: false, error: error.message });
            }
        }
        await batch.commit();
        return {
            success: true,
            results,
            processed: leaveIds.length,
            successful: results.filter(r => r.success).length,
        };
    }
    catch (error) {
        console.error('Bulk leave processing failed:', error);
        throw new functions.https.HttpsError('internal', error.message);
    }
});
/**
 * Validate admin access to school
 */
async function validateAdminAccess(adminUserId, schoolId) {
    const adminDoc = await db.collection('users').doc(adminUserId).get();
    if (!adminDoc.exists) {
        throw new Error('Admin user not found');
    }
    const adminData = adminDoc.data();
    if (adminData.role !== 'ADMIN' && adminData.role !== 'SUPER_ADMIN') {
        throw new Error('Insufficient permissions');
    }
    if (adminData.role === 'ADMIN' && adminData.schoolId !== schoolId) {
        throw new Error('Access denied to this school');
    }
    if (adminData.status !== 'ACTIVE') {
        throw new Error('Admin account is not active');
    }
}
//# sourceMappingURL=leave-approval-workflow.js.map