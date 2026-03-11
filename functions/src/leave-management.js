const functions = require('firebase-functions/v1');
const admin = require('firebase-admin');

// Initialize if not already done
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

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
    } catch (error) {
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
    } catch (error) {
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
      } catch (error) {
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
  } catch (error) {
    console.error('❌ [ANALYTICS] Error:', error);
    throw new functions.https.HttpsError('internal', 'Failed to get analytics');
  }
});

module.exports = exports;
