const functions = require('firebase-functions/v1').region('asia-south1');
const admin = require('firebase-admin');
// Initialize if not already done
if (!admin.apps.length) {
    admin.initializeApp();
}
const db = admin.firestore();
/**
 * 🎯 SECURE LEAVE APPLICATION CREATION HANDLER
 *
 * Trigger: onCreate of schools/{schoolId}/leaves/{leaveId}
 *
 * This function ensures:
 * 1. Staff can only CREATE leave applications (client-side)
 * 2. ALL balance updates happen server-side (secure)
 * 3. Atomic transactions prevent race conditions
 * 4. Complete audit trail via balanceMutations
 *
 * Flow:
 * - Staff creates leave application document
 * - Function validates available balance
 * - Function reserves balance (pending += days, available -= days)
 * - Function creates audit mutation record
 */
exports.handleLeaveApplicationCreate = functions.firestore
    .document('schools/{schoolId}/leaves/{leaveId}')
    .onCreate(async (snapshot, context) => {
    const { schoolId, leaveId } = context.params;
    const leaveData = snapshot.data();
    console.log('🚀 [LEAVE_CREATE] Function triggered for leave:', leaveId);
    console.log('📊 [LEAVE_CREATE] School:', schoolId);
    // ============================================================
    // STEP 1: EXTRACT AND VALIDATE DATA
    // ============================================================
    const { staffId, userId, leaveTypeId, totalDays, academicYear, status } = leaveData;
    // Validate required fields
    if (!staffId || !userId || !leaveTypeId || !totalDays || !academicYear) {
        console.error('❌ [LEAVE_CREATE] Missing required fields:', {
            staffId, userId, leaveTypeId, totalDays, academicYear
        });
        throw new functions.https.HttpsError('invalid-argument', 'Missing required fields in leave application');
    }
    // Only process if status is PENDING (initial creation)
    if (status !== 'PENDING' && status !== 'pending') {
        console.log('⏭️  [LEAVE_CREATE] Skipping - status is not PENDING:', status);
        return null;
    }
    console.log('✅ [LEAVE_CREATE] Validation passed');
    console.log('👤 [LEAVE_CREATE] Staff:', staffId);
    console.log('📅 [LEAVE_CREATE] Days requested:', totalDays);
    console.log('📚 [LEAVE_CREATE] Academic year:', academicYear);
    // ============================================================
    // STEP 2: CONSTRUCT BALANCE DOCUMENT ID
    // ============================================================
    const balanceId = `${staffId}_${leaveTypeId}_${academicYear}`;
    const balanceRef = db
        .collection('schools')
        .doc(schoolId)
        .collection('leaveBalances')
        .doc(balanceId);
    console.log('🔍 [LEAVE_CREATE] Balance ID:', balanceId);
    // ============================================================
    // STEP 3: ATOMIC TRANSACTION - RESERVE BALANCE
    // ============================================================
    try {
        await db.runTransaction(async (transaction) => {
            console.log('🔄 [LEAVE_CREATE] Starting transaction...');
            // Read current balance
            const balanceDoc = await transaction.get(balanceRef);
            if (!balanceDoc.exists) {
                console.error('❌ [LEAVE_CREATE] Balance document not found:', balanceId);
                throw new functions.https.HttpsError('not-found', 'Leave balance not found for this staff member and leave type');
            }
            const balance = balanceDoc.data();
            const currentAvailable = balance.available || 0;
            const currentPending = balance.pending || 0;
            const currentUsed = balance.used || 0;
            console.log('📊 [LEAVE_CREATE] Current balance:', {
                available: currentAvailable,
                pending: currentPending,
                used: currentUsed
            });
            // ============================================================
            // STEP 4: VALIDATE SUFFICIENT BALANCE
            // ============================================================
            if (currentAvailable < totalDays) {
                console.error('❌ [LEAVE_CREATE] Insufficient balance:', {
                    requested: totalDays,
                    available: currentAvailable
                });
                throw new functions.https.HttpsError('failed-precondition', `Insufficient leave balance. Available: ${currentAvailable}, Requested: ${totalDays}`);
            }
            // Verify staff belongs to same school (security check)
            if (balance.schoolId !== schoolId) {
                console.error('❌ [LEAVE_CREATE] School mismatch:', {
                    balanceSchool: balance.schoolId,
                    requestSchool: schoolId
                });
                throw new functions.https.HttpsError('permission-denied', 'Staff does not belong to this school');
            }
            console.log('✅ [LEAVE_CREATE] Validation passed - sufficient balance');
            // ============================================================
            // STEP 5: CALCULATE NEW BALANCES
            // ============================================================
            const newPending = currentPending + totalDays;
            const newAvailable = currentAvailable - totalDays;
            console.log('🔢 [LEAVE_CREATE] New balance:', {
                pending: newPending,
                available: newAvailable
            });
            // ============================================================
            // STEP 6: UPDATE LEAVE BALANCE (RESERVE DAYS)
            // ============================================================
            transaction.update(balanceRef, {
                pending: newPending,
                available: newAvailable,
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                updatedBy: 'system_leave_create_function'
            });
            console.log('✅ [LEAVE_CREATE] Balance updated in transaction');
            // ============================================================
            // STEP 7: CREATE AUDIT MUTATION RECORD
            // ============================================================
            const mutationRef = db
                .collection('schools')
                .doc(schoolId)
                .collection('balanceMutations')
                .doc(); // Auto-generate ID
            const mutationData = {
                schoolId,
                staffId,
                userId,
                leaveTypeId,
                academicYear,
                mutationType: 'PENDING_ADDED',
                previousValue: currentPending,
                newValue: newPending,
                delta: totalDays,
                referenceId: leaveId,
                reason: 'Leave application submitted - days reserved',
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
                createdBy: 'system_leave_create_function',
                metadata: {
                    leaveApplicationId: leaveId,
                    functionName: 'handleLeaveApplicationCreate',
                    previousAvailable: currentAvailable,
                    newAvailable: newAvailable
                }
            };
            transaction.set(mutationRef, mutationData);
            console.log('✅ [LEAVE_CREATE] Mutation record created in transaction');
            console.log('🔑 [LEAVE_CREATE] Mutation ID:', mutationRef.id);
        });
        console.log('✅ [LEAVE_CREATE] Transaction completed successfully');
        console.log('🎉 [LEAVE_CREATE] Leave application processed:', leaveId);
        return {
            success: true,
            leaveId,
            message: 'Leave balance reserved successfully'
        };
    }
    catch (error) {
        console.error('❌ [LEAVE_CREATE] Transaction failed:', error);
        // Re-throw HttpsError for proper client error handling
        if (error instanceof functions.https.HttpsError) {
            throw error;
        }
        // Wrap other errors
        throw new functions.https.HttpsError('internal', `Failed to process leave application: ${error.message}`);
    }
});
/**
 * Trigger when a leave application status changes
 * Handles balance updates for approval, rejection, and cancellation
 */
exports.onLeaveStatusChange = functions.firestore
    .document('schools/{schoolId}/leaves/{leaveId}')
    .onUpdate(async (change, context) => {
    const { schoolId, leaveId } = context.params;
    const beforeData = change.before.data();
    const afterData = change.after.data();
    // Skip if status hasn't changed
    if (beforeData.status === afterData.status) {
        return null;
    }
    const oldStatus = beforeData.status;
    const newStatus = afterData.status;
    const staffId = afterData.staffId;
    const leaveTypeId = afterData.leaveTypeId;
    const totalDays = afterData.totalDays || 0;
    const academicYear = afterData.academicYear;
    console.log(`📋 [LEAVE_TRIGGER] Status change: ${oldStatus} -> ${newStatus} for leave ${leaveId}`);
    try {
        const balanceId = `${staffId}_${leaveTypeId}_${academicYear}`;
        const balanceRef = db
            .collection('schools')
            .doc(schoolId)
            .collection('leaveBalances')
            .doc(balanceId);
        await db.runTransaction(async (transaction) => {
            const balanceDoc = await transaction.get(balanceRef);
            if (!balanceDoc.exists) {
                console.error(`❌ [LEAVE_TRIGGER] Balance not found: ${balanceId}`);
                return;
            }
            const balance = balanceDoc.data();
            let updates = { updatedAt: admin.firestore.FieldValue.serverTimestamp() };
            // Handle different status transitions
            if (oldStatus === 'PENDING' && newStatus === 'APPROVED') {
                // Move from pending to used
                updates.pending = Math.max(0, (balance.pending || 0) - totalDays);
                updates.used = (balance.used || 0) + totalDays;
                updates.available = Math.max(0, (balance.available || 0));
                console.log(`✅ [LEAVE_TRIGGER] Approved: pending -${totalDays}, used +${totalDays}`);
            }
            else if (oldStatus === 'PENDING' && newStatus === 'REJECTED') {
                // Release pending back to available
                updates.pending = Math.max(0, (balance.pending || 0) - totalDays);
                updates.available = (balance.available || 0) + totalDays;
                console.log(`❌ [LEAVE_TRIGGER] Rejected: pending -${totalDays}, available +${totalDays}`);
            }
            else if (oldStatus === 'PENDING' && newStatus === 'CANCELLED') {
                // Release pending back to available
                updates.pending = Math.max(0, (balance.pending || 0) - totalDays);
                updates.available = (balance.available || 0) + totalDays;
                console.log(`🚫 [LEAVE_TRIGGER] Cancelled (pending): pending -${totalDays}, available +${totalDays}`);
            }
            else if (oldStatus === 'APPROVED' && newStatus === 'CANCELLED') {
                // Restore used days back to available
                updates.used = Math.max(0, (balance.used || 0) - totalDays);
                updates.available = (balance.available || 0) + totalDays;
                console.log(`🚫 [LEAVE_TRIGGER] Cancelled (approved): used -${totalDays}, available +${totalDays}`);
            }
            transaction.update(balanceRef, updates);
            // Create mutation record for audit trail
            const mutationRef = db
                .collection('schools')
                .doc(schoolId)
                .collection('balanceMutations')
                .doc();
            transaction.set(mutationRef, {
                schoolId,
                staffId,
                leaveTypeId,
                academicYear,
                mutationType: `STATUS_${oldStatus}_TO_${newStatus}`,
                delta: totalDays,
                referenceId: leaveId,
                reason: `Leave status changed from ${oldStatus} to ${newStatus}`,
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
                createdBy: afterData.approvedBy || 'system',
                metadata: {
                    leaveId,
                    oldStatus,
                    newStatus,
                    balanceUpdates: updates,
                },
            });
        });
        console.log(`✅ [LEAVE_TRIGGER] Balance updated successfully for ${balanceId}`);
        return null;
    }
    catch (error) {
        console.error(`❌ [LEAVE_TRIGGER] Error updating balance:`, error);
        throw error;
    }
});
/**
 * Trigger when a new leave application is created
 * Reserves balance (marks as pending)
 */
exports.onLeaveCreate = functions.firestore
    .document('schools/{schoolId}/leaves/{leaveId}')
    .onCreate(async (snap, context) => {
    const { schoolId, leaveId } = context.params;
    const leaveData = snap.data();
    // Only process if status is PENDING
    if (leaveData.status !== 'PENDING') {
        return null;
    }
    const staffId = leaveData.staffId;
    const leaveTypeId = leaveData.leaveTypeId;
    const totalDays = leaveData.totalDays || 0;
    const academicYear = leaveData.academicYear;
    console.log(`📝 [LEAVE_CREATE] New leave application: ${leaveId}, days: ${totalDays}`);
    try {
        const balanceId = `${staffId}_${leaveTypeId}_${academicYear}`;
        const balanceRef = db
            .collection('schools')
            .doc(schoolId)
            .collection('leaveBalances')
            .doc(balanceId);
        await db.runTransaction(async (transaction) => {
            const balanceDoc = await transaction.get(balanceRef);
            if (!balanceDoc.exists) {
                console.error(`❌ [LEAVE_CREATE] Balance not found: ${balanceId}`);
                // Create balance if it doesn't exist
                const leaveTypeDoc = await db
                    .collection('schools')
                    .doc(schoolId)
                    .collection('leaveTypes')
                    .doc(leaveTypeId)
                    .get();
                if (leaveTypeDoc.exists) {
                    const leaveType = leaveTypeDoc.data();
                    transaction.set(balanceRef, {
                        id: balanceId,
                        schoolId,
                        staffId,
                        userId: leaveData.applicantId,
                        leaveTypeId,
                        leaveTypeCode: leaveType.code || '',
                        academicYear,
                        totalAllowed: leaveType.annualQuota || 0,
                        used: 0,
                        pending: totalDays,
                        carriedForward: 0,
                        available: Math.max(0, (leaveType.annualQuota || 0) - totalDays),
                        createdAt: admin.firestore.FieldValue.serverTimestamp(),
                        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                        createdBy: 'system_auto_create',
                    });
                    console.log(`✅ [LEAVE_CREATE] Auto-created balance: ${balanceId}`);
                }
                return;
            }
            const balance = balanceDoc.data();
            // Reserve the days
            transaction.update(balanceRef, {
                pending: (balance.pending || 0) + totalDays,
                available: Math.max(0, (balance.available || 0) - totalDays),
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
            // Create mutation record
            const mutationRef = db
                .collection('schools')
                .doc(schoolId)
                .collection('balanceMutations')
                .doc();
            transaction.set(mutationRef, {
                schoolId,
                staffId,
                leaveTypeId,
                academicYear,
                mutationType: 'PENDING_RESERVED',
                delta: totalDays,
                referenceId: leaveId,
                reason: 'Leave application submitted - days reserved',
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
                createdBy: leaveData.applicantId || 'system',
            });
        });
        console.log(`✅ [LEAVE_CREATE] Balance reserved for ${balanceId}`);
        return null;
    }
    catch (error) {
        console.error(`❌ [LEAVE_CREATE] Error reserving balance:`, error);
        throw error;
    }
});
/**
 * Batch approve multiple leave applications
 * Callable function for admin bulk operations
 */
exports.batchApproveLeaves = functions.https.onCall(async (data, context) => {
    // Verify authentication
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }
    const { schoolId, leaveIds, approvedBy, remarks } = data;
    if (!schoolId || !leaveIds || !Array.isArray(leaveIds) || leaveIds.length === 0) {
        throw new functions.https.HttpsError('invalid-argument', 'schoolId and leaveIds array are required');
    }
    // Verify admin permissions
    const userDoc = await db.collection('users').doc(context.auth.uid).get();
    if (!userDoc.exists) {
        throw new functions.https.HttpsError('permission-denied', 'User not found');
    }
    const userData = userDoc.data();
    if (userData.role !== 'ADMIN' && userData.role !== 'SUPER_ADMIN') {
        throw new functions.https.HttpsError('permission-denied', 'Only admins can approve leaves');
    }
    if (userData.role === 'ADMIN' && userData.schoolId !== schoolId) {
        throw new functions.https.HttpsError('permission-denied', 'Access denied to this school');
    }
    console.log(`📋 [BATCH_APPROVE] Processing ${leaveIds.length} leave applications`);
    const results = {
        success: [],
        failed: [],
    };
    // Process in batches of 10 for better performance
    const batchSize = 10;
    for (let i = 0; i < leaveIds.length; i += batchSize) {
        const batch = leaveIds.slice(i, i + batchSize);
        await Promise.all(batch.map(async (leaveId) => {
            try {
                const leaveRef = db
                    .collection('schools')
                    .doc(schoolId)
                    .collection('leaves')
                    .doc(leaveId);
                const leaveDoc = await leaveRef.get();
                if (!leaveDoc.exists) {
                    results.failed.push({ leaveId, error: 'Leave not found' });
                    return;
                }
                const leaveData = leaveDoc.data();
                if (leaveData.status !== 'PENDING') {
                    results.failed.push({ leaveId, error: `Cannot approve - status is ${leaveData.status}` });
                    return;
                }
                await leaveRef.update({
                    status: 'APPROVED',
                    approvedBy: approvedBy || context.auth.uid,
                    approvedAt: admin.firestore.FieldValue.serverTimestamp(),
                    remarks: remarks || null,
                    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                });
                results.success.push(leaveId);
            }
            catch (error) {
                console.error(`❌ [BATCH_APPROVE] Error approving ${leaveId}:`, error);
                results.failed.push({ leaveId, error: error.message });
            }
        }));
    }
    console.log(`✅ [BATCH_APPROVE] Completed: ${results.success.length} approved, ${results.failed.length} failed`);
    return {
        message: `Processed ${leaveIds.length} applications`,
        approved: results.success.length,
        failed: results.failed.length,
        details: results,
    };
});
/**
 * Get leave analytics for a school
 * Callable function for dashboard
 */
exports.getLeaveAnalytics = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }
    const { schoolId, startDate, endDate } = data;
    if (!schoolId) {
        throw new functions.https.HttpsError('invalid-argument', 'schoolId is required');
    }
    // Verify permissions
    const userDoc = await db.collection('users').doc(context.auth.uid).get();
    if (!userDoc.exists) {
        throw new functions.https.HttpsError('permission-denied', 'User not found');
    }
    const userData = userDoc.data();
    if (userData.role !== 'ADMIN' && userData.role !== 'SUPER_ADMIN') {
        throw new functions.https.HttpsError('permission-denied', 'Only admins can view analytics');
    }
    try {
        let query = db
            .collection('schools')
            .doc(schoolId)
            .collection('leaves');
        if (startDate) {
            query = query.where('createdAt', '>=', admin.firestore.Timestamp.fromDate(new Date(startDate)));
        }
        if (endDate) {
            query = query.where('createdAt', '<=', admin.firestore.Timestamp.fromDate(new Date(endDate)));
        }
        const snapshot = await query.get();
        const analytics = {
            total: 0,
            byStatus: {},
            byType: {},
            byMonth: {},
            totalDays: 0,
            averageDaysPerRequest: 0,
        };
        snapshot.forEach((doc) => {
            const data = doc.data();
            analytics.total++;
            // By status
            const status = data.status || 'UNKNOWN';
            analytics.byStatus[status] = (analytics.byStatus[status] || 0) + 1;
            // By type
            const typeId = data.leaveTypeId || 'UNKNOWN';
            analytics.byType[typeId] = (analytics.byType[typeId] || 0) + 1;
            // By month
            if (data.createdAt) {
                const date = data.createdAt.toDate();
                const monthKey = `${date.getFullYear()}-${String(date.getMonth() + 1).padLeft(2, '0')}`;
                analytics.byMonth[monthKey] = (analytics.byMonth[monthKey] || 0) + 1;
            }
            // Total days
            if (data.status === 'APPROVED') {
                analytics.totalDays += data.totalDays || 0;
            }
        });
        if (analytics.byStatus['APPROVED'] > 0) {
            analytics.averageDaysPerRequest = (analytics.totalDays / analytics.byStatus['APPROVED']).toFixed(2);
        }
        return analytics;
    }
    catch (error) {
        console.error('❌ [ANALYTICS] Error:', error);
        throw new functions.https.HttpsError('internal', 'Failed to get analytics');
    }
});
/**
 * 🎯 SECURE PERMISSION REQUEST CREATION HANDLER
 *
 * Trigger: onCreate of schools/{schoolId}/permissions/{permissionId}
 *
 * This function ensures:
 * 1. Staff can only CREATE permission requests (client-side)
 * 2. ALL balance updates happen server-side (secure)
 * 3. Atomic transactions prevent race conditions
 * 4. Complete audit trail via permissionMutations
 *
 * Flow:
 * - Staff creates permission request document
 * - Function validates available balance
 * - Function updates monthly usage
 * - Function creates audit mutation record
 */
exports.handlePermissionRequestCreate = functions.firestore
    .document('schools/{schoolId}/permissions/{permissionId}')
    .onCreate(async (snapshot, context) => {
    const { schoolId, permissionId } = context.params;
    const permissionData = snapshot.data();
    console.log('🚀 [PERMISSION_CREATE] Function triggered for permission:', permissionId);
    console.log('📊 [PERMISSION_CREATE] School:', schoolId);
    // ============================================================
    // STEP 1: EXTRACT AND VALIDATE DATA
    // ============================================================
    const { staffId, applicantId, permissionTypeId, requestDate, status } = permissionData;
    // Validate required fields
    if (!staffId || !applicantId || !permissionTypeId || !requestDate) {
        console.error('❌ [PERMISSION_CREATE] Missing required fields:', {
            staffId, applicantId, permissionTypeId, requestDate
        });
        throw new functions.https.HttpsError('invalid-argument', 'Missing required fields in permission request');
    }
    // Only process if status is PENDING (initial creation)
    if (status !== 'PENDING' && status !== 'pending') {
        console.log('⏭️  [PERMISSION_CREATE] Skipping - status is not PENDING:', status);
        return null;
    }
    console.log('✅ [PERMISSION_CREATE] Validation passed');
    console.log('👤 [PERMISSION_CREATE] Staff:', staffId);
    console.log('� [PERMISSION_CREATE] Request date:', requestDate);
    // ============================================================
    // STEP 2: GET MONTH FROM REQUEST DATE
    // ============================================================
    const requestDateObj = requestDate.toDate ? requestDate.toDate() : new Date(requestDate);
    const month = `${requestDateObj.getFullYear()}-${String(requestDateObj.getMonth() + 1).padStart(2, '0')}`;
    const usageId = `${staffId}_${month}`;
    console.log('📊 [PERMISSION_CREATE] Month:', month);
    console.log('� [PERMISSION_CREATE] Usage ID:', usageId);
    // ============================================================
    // STEP 3: ATOMIC TRANSACTION - UPDATE MONTHLY USAGE
    // ============================================================
    try {
        await db.runTransaction(async (transaction) => {
            console.log('🔄 [PERMISSION_CREATE] Starting transaction...');
            const usageRef = db
                .collection('schools')
                .doc(schoolId)
                .collection('monthlyPermissionUsage')
                .doc(usageId);
            // Read current usage
            const usageDoc = await transaction.get(usageRef);
            let currentUsage;
            if (!usageDoc.exists) {
                console.log('ℹ️ [PERMISSION_CREATE] Creating new usage document');
                currentUsage = {
                    staffId,
                    month,
                    totalRequests: 0,
                    approvedRequests: 0,
                    totalMinutesUsed: 0,
                    permissionTypeCounts: {}
                };
            }
            else {
                currentUsage = usageDoc.data();
            }
            console.log('📊 [PERMISSION_CREATE] Current usage:', {
                totalRequests: currentUsage.totalRequests,
                approvedRequests: currentUsage.approvedRequests
            });
            // ============================================================
            // STEP 4: UPDATE USAGE
            // ============================================================
            const newTotalRequests = (currentUsage.totalRequests || 0) + 1;
            const permissionTypeCounts = currentUsage.permissionTypeCounts || {};
            permissionTypeCounts[permissionTypeId] = (permissionTypeCounts[permissionTypeId] || 0) + 1;
            console.log('🔢 [PERMISSION_CREATE] New usage:', {
                totalRequests: newTotalRequests,
                permissionTypeCounts
            });
            // ============================================================
            // STEP 5: UPDATE MONTHLY USAGE DOCUMENT
            // ============================================================
            transaction.set(usageRef, {
                schoolId,
                staffId,
                month,
                totalRequests: newTotalRequests,
                approvedRequests: currentUsage.approvedRequests || 0,
                totalMinutesUsed: currentUsage.totalMinutesUsed || 0,
                permissionTypeCounts,
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                updatedBy: 'system_permission_create_function'
            }, { merge: true });
            console.log('✅ [PERMISSION_CREATE] Monthly usage updated in transaction');
            // ============================================================
            // STEP 6: CREATE AUDIT MUTATION RECORD
            // ============================================================
            const mutationRef = db
                .collection('schools')
                .doc(schoolId)
                .collection('permissionMutations')
                .doc(); // Auto-generate ID
            const mutationData = {
                schoolId,
                staffId,
                applicantId,
                permissionTypeId,
                month,
                mutationType: 'REQUEST_CREATED',
                previousValue: currentUsage.totalRequests || 0,
                newValue: newTotalRequests,
                delta: 1,
                referenceId: permissionId,
                reason: 'Permission request submitted',
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
                createdBy: 'system_permission_create_function',
                metadata: {
                    permissionRequestId: permissionId,
                    functionName: 'handlePermissionRequestCreate',
                    permissionTypeCounts
                }
            };
            transaction.set(mutationRef, mutationData);
            console.log('✅ [PERMISSION_CREATE] Mutation record created in transaction');
            console.log('🔑 [PERMISSION_CREATE] Mutation ID:', mutationRef.id);
        });
        console.log('✅ [PERMISSION_CREATE] Transaction completed successfully');
        console.log('🎉 [PERMISSION_CREATE] Permission request processed:', permissionId);
        return {
            success: true,
            permissionId,
            message: 'Monthly usage updated successfully'
        };
    }
    catch (error) {
        console.error('❌ [PERMISSION_CREATE] Transaction failed:', error);
        // Re-throw HttpsError for proper client error handling
        if (error instanceof functions.https.HttpsError) {
            throw error;
        }
        // Wrap other errors
        throw new functions.https.HttpsError('internal', `Failed to process permission request: ${error.message}`);
    }
});
/**
 * Trigger when a permission request status changes
 * Handles monthly usage updates for approval, rejection, and cancellation
 */
exports.onPermissionStatusChange = functions.firestore
    .document('schools/{schoolId}/permissions/{permissionId}')
    .onUpdate(async (change, context) => {
    const { schoolId, permissionId } = context.params;
    const beforeData = change.before.data();
    const afterData = change.after.data();
    // Skip if status hasn't changed
    if (beforeData.status === afterData.status) {
        return null;
    }
    const oldStatus = beforeData.status;
    const newStatus = afterData.status;
    const staffId = afterData.staffId;
    const applicantId = afterData.applicantId;
    const permissionTypeId = afterData.permissionTypeId;
    const requestDate = afterData.requestDate;
    const durationMinutes = afterData.durationMinutes || 0;
    console.log(`📋 [PERMISSION_TRIGGER] Status change: ${oldStatus} -> ${newStatus} for permission ${permissionId}`);
    try {
        // Get month from request date
        const requestDateObj = requestDate.toDate ? requestDate.toDate() : new Date(requestDate);
        const month = `${requestDateObj.getFullYear()}-${String(requestDateObj.getMonth() + 1).padStart(2, '0')}`;
        const usageId = `${staffId}_${month}`;
        const usageRef = db
            .collection('schools')
            .doc(schoolId)
            .collection('monthlyPermissionUsage')
            .doc(usageId);
        await db.runTransaction(async (transaction) => {
            const usageDoc = await transaction.get(usageRef);
            if (!usageDoc.exists) {
                console.error(`❌ [PERMISSION_TRIGGER] Usage document not found: ${usageId}`);
                return;
            }
            const usage = usageDoc.data();
            let updates = { updatedAt: admin.firestore.FieldValue.serverTimestamp() };
            // Handle different status transitions
            if (oldStatus === 'PENDING' && newStatus === 'APPROVED') {
                // Increment approved requests and total minutes
                updates.approvedRequests = (usage.approvedRequests || 0) + 1;
                updates.totalMinutesUsed = (usage.totalMinutesUsed || 0) + durationMinutes;
                console.log(`✅ [PERMISSION_TRIGGER] Approved: approvedRequests +1, totalMinutesUsed +${durationMinutes}`);
            }
            else if (oldStatus === 'PENDING' && newStatus === 'REJECTED') {
                // No change to approved requests, just log
                console.log(`❌ [PERMISSION_TRIGGER] Rejected: no balance change needed`);
            }
            else if (oldStatus === 'PENDING' && newStatus === 'CANCELLED') {
                // No change to approved requests, just log
                console.log(`🚫 [PERMISSION_TRIGGER] Cancelled (pending): no balance change needed`);
            }
            else if (oldStatus === 'APPROVED' && newStatus === 'CANCELLED') {
                // Decrement approved requests and total minutes
                updates.approvedRequests = Math.max(0, (usage.approvedRequests || 0) - 1);
                updates.totalMinutesUsed = Math.max(0, (usage.totalMinutesUsed || 0) - durationMinutes);
                console.log(`🚫 [PERMISSION_TRIGGER] Cancelled (approved): approvedRequests -1, totalMinutesUsed -${durationMinutes}`);
            }
            transaction.update(usageRef, updates);
            // Create mutation record for audit trail
            const mutationRef = db
                .collection('schools')
                .doc(schoolId)
                .collection('permissionMutations')
                .doc();
            transaction.set(mutationRef, {
                schoolId,
                staffId,
                applicantId,
                permissionTypeId,
                month,
                mutationType: `STATUS_${oldStatus}_TO_${newStatus}`,
                delta: 1,
                referenceId: permissionId,
                reason: `Permission status changed from ${oldStatus} to ${newStatus}`,
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
                createdBy: afterData.approvedBy || 'system',
                metadata: {
                    permissionId,
                    oldStatus,
                    newStatus,
                    durationMinutes,
                    usageUpdates: updates,
                },
            });
        });
        console.log(`✅ [PERMISSION_TRIGGER] Monthly usage updated successfully for ${usageId}`);
        return null;
    }
    catch (error) {
        console.error(`❌ [PERMISSION_TRIGGER] Error updating monthly usage:`, error);
        throw error;
    }
});
module.exports = exports;
//# sourceMappingURL=leave-management.js.map