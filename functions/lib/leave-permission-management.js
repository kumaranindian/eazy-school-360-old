const functions = require('firebase-functions');
const admin = require('firebase-admin');
const db = admin.firestore();
/**
 * Apply for Leave
 * Staff can apply for leave based on available balance
 */
exports.applyLeave = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }
    const { schoolId, leaveType, startDate, endDate, reason, halfDay } = data;
    if (!schoolId || !leaveType || !startDate || !endDate || !reason) {
        throw new functions.https.HttpsError('invalid-argument', 'Missing required fields');
    }
    try {
        const staffId = context.auth.uid;
        // Get staff details
        const staffDoc = await db.collection('schools').doc(schoolId).collection('staff').doc(staffId).get();
        if (!staffDoc.exists) {
            throw new functions.https.HttpsError('not-found', 'Staff not found');
        }
        const staffData = staffDoc.data();
        // Validate leave type against configuration
        const leaveTypeDoc = await db
            .collection('schools')
            .doc(schoolId)
            .collection('leaveTypes')
            .where('code', '==', leaveType)
            .where('isActive', '==', true)
            .limit(1)
            .get();
        if (leaveTypeDoc.empty) {
            throw new functions.https.HttpsError('invalid-argument', `Invalid or inactive leave type: ${leaveType}`);
        }
        const leaveTypeConfig = leaveTypeDoc.docs[0].data();
        // Calculate number of days
        const start = new Date(startDate);
        const end = new Date(endDate);
        const days = halfDay ? 0.5 : Math.ceil((end - start) / (1000 * 60 * 60 * 24)) + 1;
        // Validate half-day if applicable
        if (halfDay && !leaveTypeConfig.allowHalfDay) {
            throw new functions.https.HttpsError('invalid-argument', `Half-day leave is not allowed for ${leaveTypeConfig.name}`);
        }
        // Get leave balance
        const balanceDoc = await db
            .collection('schools')
            .doc(schoolId)
            .collection('staff')
            .doc(staffId)
            .collection('leave_balances')
            .doc(leaveType)
            .get();
        if (!balanceDoc.exists) {
            throw new functions.https.HttpsError('failed-precondition', 'Leave balance not found for this leave type');
        }
        const balance = balanceDoc.data();
        if (balance.available < days) {
            throw new functions.https.HttpsError('failed-precondition', `Insufficient leave balance. Available: ${balance.available}, Requested: ${days}`);
        }
        // Check for overlapping leaves
        const overlappingLeaves = await db
            .collection('schools')
            .doc(schoolId)
            .collection('leaves')
            .where('staffId', '==', staffId)
            .where('status', 'in', ['PENDING', 'APPROVED'])
            .get();
        for (const doc of overlappingLeaves.docs) {
            const leave = doc.data();
            const leaveStart = new Date(leave.startDate);
            const leaveEnd = new Date(leave.endDate);
            if ((start >= leaveStart && start <= leaveEnd) || (end >= leaveStart && end <= leaveEnd)) {
                throw new functions.https.HttpsError('already-exists', 'You already have a leave application for overlapping dates');
            }
        }
        // Create leave application
        const leaveRef = await db.collection('schools').doc(schoolId).collection('leaves').add({
            staffId,
            staffName: staffData.name,
            employeeId: staffData.employeeId || '',
            leaveType,
            leaveTypeName: leaveTypeConfig.name,
            leaveTypeId: leaveTypeDoc.docs[0].id,
            startDate,
            endDate,
            days,
            halfDay: halfDay || false,
            reason,
            status: 'PENDING',
            appliedAt: admin.firestore.FieldValue.serverTimestamp(),
            appliedBy: staffId,
            schoolId
        });
        console.log(`[Leave] Application created: ${leaveRef.id} for staff ${staffId}`);
        return {
            success: true,
            leaveId: leaveRef.id,
            message: 'Leave application submitted successfully'
        };
    }
    catch (error) {
        console.error('[Leave] Error:', error);
        if (error instanceof functions.https.HttpsError) {
            throw error;
        }
        throw new functions.https.HttpsError('internal', `Failed to apply leave: ${error.message}`);
    }
});
/**
 * Approve Leave
 * Admin can approve leave and deduct from balance
 */
exports.approveLeave = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }
    const { schoolId, leaveId, remarks } = data;
    if (!schoolId || !leaveId) {
        throw new functions.https.HttpsError('invalid-argument', 'Missing required fields');
    }
    try {
        // Verify admin access
        const userDoc = await db.collection('users').doc(context.auth.uid).get();
        if (!userDoc.exists) {
            throw new functions.https.HttpsError('not-found', 'User not found');
        }
        const userData = userDoc.data();
        const isAdmin = ['ADMIN', 'admin', 'TENANT_ADMIN', 'tenant_admin', 'SUPER_ADMIN', 'super_admin'].includes(userData.role);
        if (!isAdmin) {
            throw new functions.https.HttpsError('permission-denied', 'Only admins can approve leaves');
        }
        // Get leave application
        const leaveRef = db.collection('schools').doc(schoolId).collection('leaves').doc(leaveId);
        const leaveDoc = await leaveRef.get();
        if (!leaveDoc.exists) {
            throw new functions.https.HttpsError('not-found', 'Leave application not found');
        }
        const leave = leaveDoc.data();
        if (leave.status !== 'PENDING') {
            throw new functions.https.HttpsError('failed-precondition', `Leave is already ${leave.status}`);
        }
        // Use transaction to ensure atomicity
        await db.runTransaction(async (transaction) => {
            // Get current balance
            const balanceRef = db
                .collection('schools')
                .doc(schoolId)
                .collection('staff')
                .doc(leave.staffId)
                .collection('leave_balances')
                .doc(leave.leaveType);
            const balanceDoc = await transaction.get(balanceRef);
            if (!balanceDoc.exists) {
                throw new functions.https.HttpsError('not-found', 'Leave balance not found');
            }
            const balance = balanceDoc.data();
            if (balance.available < leave.days) {
                throw new functions.https.HttpsError('failed-precondition', `Insufficient balance. Available: ${balance.available}, Required: ${leave.days}`);
            }
            // Update leave status
            transaction.update(leaveRef, {
                status: 'APPROVED',
                approvedAt: admin.firestore.FieldValue.serverTimestamp(),
                approvedBy: context.auth.uid,
                approverName: userData.name || userData.email,
                remarks: remarks || ''
            });
            // Deduct from balance
            transaction.update(balanceRef, {
                available: admin.firestore.FieldValue.increment(-leave.days),
                used: admin.firestore.FieldValue.increment(leave.days),
                updatedAt: admin.firestore.FieldValue.serverTimestamp()
            });
        });
        console.log(`[Leave] Approved: ${leaveId} by ${context.auth.uid}`);
        return {
            success: true,
            message: 'Leave approved successfully'
        };
    }
    catch (error) {
        console.error('[Leave] Approval error:', error);
        if (error instanceof functions.https.HttpsError) {
            throw error;
        }
        throw new functions.https.HttpsError('internal', `Failed to approve leave: ${error.message}`);
    }
});
/**
 * Reject Leave
 * Admin can reject leave application
 */
exports.rejectLeave = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }
    const { schoolId, leaveId, remarks } = data;
    if (!schoolId || !leaveId || !remarks) {
        throw new functions.https.HttpsError('invalid-argument', 'Missing required fields');
    }
    try {
        // Verify admin access
        const userDoc = await db.collection('users').doc(context.auth.uid).get();
        if (!userDoc.exists) {
            throw new functions.https.HttpsError('not-found', 'User not found');
        }
        const userData = userDoc.data();
        const isAdmin = ['ADMIN', 'admin', 'TENANT_ADMIN', 'tenant_admin', 'SUPER_ADMIN', 'super_admin'].includes(userData.role);
        if (!isAdmin) {
            throw new functions.https.HttpsError('permission-denied', 'Only admins can reject leaves');
        }
        // Get leave application
        const leaveRef = db.collection('schools').doc(schoolId).collection('leaves').doc(leaveId);
        const leaveDoc = await leaveRef.get();
        if (!leaveDoc.exists) {
            throw new functions.https.HttpsError('not-found', 'Leave application not found');
        }
        const leave = leaveDoc.data();
        if (leave.status !== 'PENDING') {
            throw new functions.https.HttpsError('failed-precondition', `Leave is already ${leave.status}`);
        }
        // Update leave status
        await leaveRef.update({
            status: 'REJECTED',
            rejectedAt: admin.firestore.FieldValue.serverTimestamp(),
            rejectedBy: context.auth.uid,
            rejectorName: userData.name || userData.email,
            remarks
        });
        console.log(`[Leave] Rejected: ${leaveId} by ${context.auth.uid}`);
        return {
            success: true,
            message: 'Leave rejected successfully'
        };
    }
    catch (error) {
        console.error('[Leave] Rejection error:', error);
        if (error instanceof functions.https.HttpsError) {
            throw error;
        }
        throw new functions.https.HttpsError('internal', `Failed to reject leave: ${error.message}`);
    }
});
/**
 * Cancel Leave
 * Staff can cancel their own pending leave
 */
exports.cancelLeave = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }
    const { schoolId, leaveId } = data;
    if (!schoolId || !leaveId) {
        throw new functions.https.HttpsError('invalid-argument', 'Missing required fields');
    }
    try {
        const staffId = context.auth.uid;
        // Get leave application
        const leaveRef = db.collection('schools').doc(schoolId).collection('leaves').doc(leaveId);
        const leaveDoc = await leaveRef.get();
        if (!leaveDoc.exists) {
            throw new functions.https.HttpsError('not-found', 'Leave application not found');
        }
        const leave = leaveDoc.data();
        // Verify ownership
        if (leave.staffId !== staffId) {
            throw new functions.https.HttpsError('permission-denied', 'You can only cancel your own leaves');
        }
        if (leave.status !== 'PENDING') {
            throw new functions.https.HttpsError('failed-precondition', `Cannot cancel ${leave.status} leave`);
        }
        // Update leave status
        await leaveRef.update({
            status: 'CANCELLED',
            cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
            cancelledBy: staffId
        });
        console.log(`[Leave] Cancelled: ${leaveId} by ${staffId}`);
        return {
            success: true,
            message: 'Leave cancelled successfully'
        };
    }
    catch (error) {
        console.error('[Leave] Cancellation error:', error);
        if (error instanceof functions.https.HttpsError) {
            throw error;
        }
        throw new functions.https.HttpsError('internal', `Failed to cancel leave: ${error.message}`);
    }
});
/**
 * Apply for Permission
 * Staff can apply for permission based on available balance
 */
exports.applyPermission = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }
    const { schoolId, date, startTime, endTime, reason } = data;
    if (!schoolId || !date || !startTime || !endTime || !reason) {
        throw new functions.https.HttpsError('invalid-argument', 'Missing required fields');
    }
    try {
        const staffId = context.auth.uid;
        // Get staff details
        const staffDoc = await db.collection('schools').doc(schoolId).collection('staff').doc(staffId).get();
        if (!staffDoc.exists) {
            throw new functions.https.HttpsError('not-found', 'Staff not found');
        }
        const staffData = staffDoc.data();
        // Get permission configuration
        const permissionConfigDoc = await db
            .collection('schools')
            .doc(schoolId)
            .collection('settings')
            .doc('permission')
            .get();
        let permissionConfig;
        if (!permissionConfigDoc.exists) {
            // Use default configuration
            permissionConfig = {
                enabled: true,
                minHours: 0.5,
                maxHoursPerDay: 4,
                requiresApproval: true
            };
            console.log('[Permission] Using default configuration');
        }
        else {
            permissionConfig = permissionConfigDoc.data();
        }
        // Validate if permissions are enabled
        if (!permissionConfig.enabled) {
            throw new functions.https.HttpsError('failed-precondition', 'Permission requests are currently disabled');
        }
        // Calculate duration in hours
        const start = new Date(`${date}T${startTime}`);
        const end = new Date(`${date}T${endTime}`);
        const hours = (end - start) / (1000 * 60 * 60);
        if (hours <= 0) {
            throw new functions.https.HttpsError('invalid-argument', 'End time must be after start time');
        }
        // Validate against min/max hours if configured
        if (permissionConfig.minHours && hours < permissionConfig.minHours) {
            throw new functions.https.HttpsError('invalid-argument', `Minimum permission duration is ${permissionConfig.minHours} hours`);
        }
        if (permissionConfig.maxHoursPerDay && hours > permissionConfig.maxHoursPerDay) {
            throw new functions.https.HttpsError('invalid-argument', `Maximum permission duration is ${permissionConfig.maxHoursPerDay} hours per day`);
        }
        // Get permission balance
        const balanceDoc = await db
            .collection('schools')
            .doc(schoolId)
            .collection('staff')
            .doc(staffId)
            .collection('permission_balances')
            .doc('current_year')
            .get();
        if (!balanceDoc.exists) {
            throw new functions.https.HttpsError('failed-precondition', 'Permission balance not found');
        }
        const balance = balanceDoc.data();
        if (balance.availableHours < hours) {
            throw new functions.https.HttpsError('failed-precondition', `Insufficient permission balance. Available: ${balance.availableHours} hours, Requested: ${hours} hours`);
        }
        // Check for existing permission on same date
        const existingPermission = await db
            .collection('schools')
            .doc(schoolId)
            .collection('permissions')
            .where('staffId', '==', staffId)
            .where('date', '==', date)
            .where('status', 'in', ['PENDING', 'APPROVED'])
            .limit(1)
            .get();
        if (!existingPermission.empty) {
            throw new functions.https.HttpsError('already-exists', 'You already have a permission request for this date');
        }
        // Create permission application
        const permissionRef = await db.collection('schools').doc(schoolId).collection('permissions').add({
            staffId,
            staffName: staffData.name,
            employeeId: staffData.employeeId || '',
            date,
            startTime,
            endTime,
            hours,
            reason,
            status: 'PENDING',
            appliedAt: admin.firestore.FieldValue.serverTimestamp(),
            appliedBy: staffId,
            schoolId
        });
        console.log(`[Permission] Application created: ${permissionRef.id} for staff ${staffId}`);
        return {
            success: true,
            permissionId: permissionRef.id,
            message: 'Permission request submitted successfully'
        };
    }
    catch (error) {
        console.error('[Permission] Error:', error);
        if (error instanceof functions.https.HttpsError) {
            throw error;
        }
        throw new functions.https.HttpsError('internal', `Failed to apply permission: ${error.message}`);
    }
});
/**
 * Approve Permission
 * Admin can approve permission and deduct from balance
 */
exports.approvePermission = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }
    const { schoolId, permissionId, remarks } = data;
    if (!schoolId || !permissionId) {
        throw new functions.https.HttpsError('invalid-argument', 'Missing required fields');
    }
    try {
        // Verify admin access
        const userDoc = await db.collection('users').doc(context.auth.uid).get();
        if (!userDoc.exists) {
            throw new functions.https.HttpsError('not-found', 'User not found');
        }
        const userData = userDoc.data();
        const isAdmin = ['ADMIN', 'admin', 'TENANT_ADMIN', 'tenant_admin', 'SUPER_ADMIN', 'super_admin'].includes(userData.role);
        if (!isAdmin) {
            throw new functions.https.HttpsError('permission-denied', 'Only admins can approve permissions');
        }
        // Get permission application
        const permissionRef = db.collection('schools').doc(schoolId).collection('permissions').doc(permissionId);
        const permissionDoc = await permissionRef.get();
        if (!permissionDoc.exists) {
            throw new functions.https.HttpsError('not-found', 'Permission request not found');
        }
        const permission = permissionDoc.data();
        if (permission.status !== 'PENDING') {
            throw new functions.https.HttpsError('failed-precondition', `Permission is already ${permission.status}`);
        }
        // Use transaction to ensure atomicity
        await db.runTransaction(async (transaction) => {
            // Get current balance
            const balanceRef = db
                .collection('schools')
                .doc(schoolId)
                .collection('staff')
                .doc(permission.staffId)
                .collection('permission_balances')
                .doc('current_year');
            const balanceDoc = await transaction.get(balanceRef);
            if (!balanceDoc.exists) {
                throw new functions.https.HttpsError('not-found', 'Permission balance not found');
            }
            const balance = balanceDoc.data();
            if (balance.availableHours < permission.hours) {
                throw new functions.https.HttpsError('failed-precondition', `Insufficient balance. Available: ${balance.availableHours} hours, Required: ${permission.hours} hours`);
            }
            // Update permission status
            transaction.update(permissionRef, {
                status: 'APPROVED',
                approvedAt: admin.firestore.FieldValue.serverTimestamp(),
                approvedBy: context.auth.uid,
                approverName: userData.name || userData.email,
                remarks: remarks || ''
            });
            // Deduct from balance
            transaction.update(balanceRef, {
                availableHours: admin.firestore.FieldValue.increment(-permission.hours),
                usedHours: admin.firestore.FieldValue.increment(permission.hours),
                updatedAt: admin.firestore.FieldValue.serverTimestamp()
            });
        });
        console.log(`[Permission] Approved: ${permissionId} by ${context.auth.uid}`);
        return {
            success: true,
            message: 'Permission approved successfully'
        };
    }
    catch (error) {
        console.error('[Permission] Approval error:', error);
        if (error instanceof functions.https.HttpsError) {
            throw error;
        }
        throw new functions.https.HttpsError('internal', `Failed to approve permission: ${error.message}`);
    }
});
/**
 * Reject Permission
 * Admin can reject permission request
 */
exports.rejectPermission = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }
    const { schoolId, permissionId, remarks } = data;
    if (!schoolId || !permissionId || !remarks) {
        throw new functions.https.HttpsError('invalid-argument', 'Missing required fields');
    }
    try {
        // Verify admin access
        const userDoc = await db.collection('users').doc(context.auth.uid).get();
        if (!userDoc.exists) {
            throw new functions.https.HttpsError('not-found', 'User not found');
        }
        const userData = userDoc.data();
        const isAdmin = ['ADMIN', 'admin', 'TENANT_ADMIN', 'tenant_admin', 'SUPER_ADMIN', 'super_admin'].includes(userData.role);
        if (!isAdmin) {
            throw new functions.https.HttpsError('permission-denied', 'Only admins can reject permissions');
        }
        // Get permission application
        const permissionRef = db.collection('schools').doc(schoolId).collection('permissions').doc(permissionId);
        const permissionDoc = await permissionRef.get();
        if (!permissionDoc.exists) {
            throw new functions.https.HttpsError('not-found', 'Permission request not found');
        }
        const permission = permissionDoc.data();
        if (permission.status !== 'PENDING') {
            throw new functions.https.HttpsError('failed-precondition', `Permission is already ${permission.status}`);
        }
        // Update permission status
        await permissionRef.update({
            status: 'REJECTED',
            rejectedAt: admin.firestore.FieldValue.serverTimestamp(),
            rejectedBy: context.auth.uid,
            rejectorName: userData.name || userData.email,
            remarks
        });
        console.log(`[Permission] Rejected: ${permissionId} by ${context.auth.uid}`);
        return {
            success: true,
            message: 'Permission rejected successfully'
        };
    }
    catch (error) {
        console.error('[Permission] Rejection error:', error);
        if (error instanceof functions.https.HttpsError) {
            throw error;
        }
        throw new functions.https.HttpsError('internal', `Failed to reject permission: ${error.message}`);
    }
});
/**
 * Adjust Leave Balance
 * Admin can manually adjust leave balance
 */
exports.adjustLeaveBalance = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }
    const { schoolId, staffId, leaveType, adjustment, reason } = data;
    if (!schoolId || !staffId || !leaveType || adjustment === undefined || !reason) {
        throw new functions.https.HttpsError('invalid-argument', 'Missing required fields');
    }
    try {
        // Verify admin access
        const userDoc = await db.collection('users').doc(context.auth.uid).get();
        if (!userDoc.exists) {
            throw new functions.https.HttpsError('not-found', 'User not found');
        }
        const userData = userDoc.data();
        const isAdmin = ['ADMIN', 'admin', 'TENANT_ADMIN', 'tenant_admin', 'SUPER_ADMIN', 'super_admin'].includes(userData.role);
        if (!isAdmin) {
            throw new functions.https.HttpsError('permission-denied', 'Only admins can adjust balances');
        }
        const balanceRef = db
            .collection('schools')
            .doc(schoolId)
            .collection('staff')
            .doc(staffId)
            .collection('leave_balances')
            .doc(leaveType);
        await balanceRef.update({
            available: admin.firestore.FieldValue.increment(adjustment),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            lastAdjustment: {
                amount: adjustment,
                reason,
                adjustedBy: context.auth.uid,
                adjustedAt: admin.firestore.FieldValue.serverTimestamp()
            }
        });
        console.log(`[Leave Balance] Adjusted: ${staffId} ${leaveType} by ${adjustment}`);
        return {
            success: true,
            message: 'Leave balance adjusted successfully'
        };
    }
    catch (error) {
        console.error('[Leave Balance] Adjustment error:', error);
        if (error instanceof functions.https.HttpsError) {
            throw error;
        }
        throw new functions.https.HttpsError('internal', `Failed to adjust balance: ${error.message}`);
    }
});
/**
 * Get Available Leave Types
 * Returns active leave types for a school
 */
exports.getLeaveTypes = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }
    const { schoolId } = data;
    if (!schoolId) {
        throw new functions.https.HttpsError('invalid-argument', 'schoolId is required');
    }
    try {
        const leaveTypesSnapshot = await db
            .collection('schools')
            .doc(schoolId)
            .collection('leaveTypes')
            .where('isActive', '==', true)
            .orderBy('name', 'asc')
            .get();
        const leaveTypes = [];
        leaveTypesSnapshot.docs.forEach(doc => {
            leaveTypes.push(Object.assign({ id: doc.id }, doc.data()));
        });
        return {
            success: true,
            leaveTypes
        };
    }
    catch (error) {
        console.error('[Leave Types] Error:', error);
        throw new functions.https.HttpsError('internal', `Failed to get leave types: ${error.message}`);
    }
});
/**
 * Get Permission Configuration
 * Returns permission settings for a school
 */
exports.getPermissionConfig = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }
    const { schoolId } = data;
    if (!schoolId) {
        throw new functions.https.HttpsError('invalid-argument', 'schoolId is required');
    }
    try {
        const configDoc = await db
            .collection('schools')
            .doc(schoolId)
            .collection('settings')
            .doc('permission')
            .get();
        if (!configDoc.exists) {
            // Return default configuration
            return {
                success: true,
                config: {
                    enabled: true,
                    minHours: 0.5,
                    maxHoursPerDay: 4,
                    requiresApproval: true,
                    allowedDays: ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'],
                    description: 'Permission requests for partial day absence',
                    isDefault: true,
                    message: 'Using default permission configuration'
                }
            };
        }
        return {
            success: true,
            config: Object.assign(Object.assign({}, configDoc.data()), { isDefault: false })
        };
    }
    catch (error) {
        console.error('[Permission Config] Error:', error);
        throw new functions.https.HttpsError('internal', `Failed to get permission config: ${error.message}`);
    }
});
/**
 * Adjust Permission Balance
 * Admin can manually adjust permission balance
 */
exports.adjustPermissionBalance = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }
    const { schoolId, staffId, adjustment, reason } = data;
    if (!schoolId || !staffId || adjustment === undefined || !reason) {
        throw new functions.https.HttpsError('invalid-argument', 'Missing required fields');
    }
    try {
        // Verify admin access
        const userDoc = await db.collection('users').doc(context.auth.uid).get();
        if (!userDoc.exists) {
            throw new functions.https.HttpsError('not-found', 'User not found');
        }
        const userData = userDoc.data();
        const isAdmin = ['ADMIN', 'admin', 'TENANT_ADMIN', 'tenant_admin', 'SUPER_ADMIN', 'super_admin'].includes(userData.role);
        if (!isAdmin) {
            throw new functions.https.HttpsError('permission-denied', 'Only admins can adjust balances');
        }
        const balanceRef = db
            .collection('schools')
            .doc(schoolId)
            .collection('staff')
            .doc(staffId)
            .collection('permission_balances')
            .doc('current_year');
        await balanceRef.update({
            availableHours: admin.firestore.FieldValue.increment(adjustment),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            lastAdjustment: {
                amount: adjustment,
                reason,
                adjustedBy: context.auth.uid,
                adjustedAt: admin.firestore.FieldValue.serverTimestamp()
            }
        });
        console.log(`[Permission Balance] Adjusted: ${staffId} by ${adjustment} hours`);
        return {
            success: true,
            message: 'Permission balance adjusted successfully'
        };
    }
    catch (error) {
        console.error('[Permission Balance] Adjustment error:', error);
        if (error instanceof functions.https.HttpsError) {
            throw error;
        }
        throw new functions.https.HttpsError('internal', `Failed to adjust balance: ${error.message}`);
    }
});
//# sourceMappingURL=leave-permission-management.js.map