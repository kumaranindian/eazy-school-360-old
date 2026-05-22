const functions = require('firebase-functions/v1');
const admin = require('firebase-admin');

// Initialize if not already done
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

/**
 * Trigger when a permission request status changes
 * Updates monthly usage tracking
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
    const durationMinutes = afterData.durationMinutes || 0;
    const requestDate = afterData.requestDate?.toDate() || new Date();

    console.log(`📋 [PERMISSION_TRIGGER] Status change: ${oldStatus} -> ${newStatus} for permission ${permissionId}`);

    try {
      // Get month key for usage tracking
      const monthKey = `${requestDate.getFullYear()}-${String(requestDate.getMonth() + 1).padStart(2, '0')}`;
      const usageId = `${staffId}_${monthKey}`;
      const usageRef = db
        .collection('schools')
        .doc(schoolId)
        .collection('monthlyPermissionUsage')
        .doc(usageId);

      await db.runTransaction(async (transaction) => {
        const usageDoc = await transaction.get(usageRef);
        
        let currentUsage = {
          staffId,
          month: monthKey,
          totalRequests: 0,
          approvedRequests: 0,
          rejectedRequests: 0,
          cancelledRequests: 0,
          totalMinutesUsed: 0,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        };

        if (usageDoc.exists) {
          currentUsage = usageDoc.data();
        }

        // Handle different status transitions
        if (oldStatus === 'PENDING' && newStatus === 'APPROVED') {
          currentUsage.approvedRequests = (currentUsage.approvedRequests || 0) + 1;
          currentUsage.totalMinutesUsed = (currentUsage.totalMinutesUsed || 0) + durationMinutes;
          console.log(`✅ [PERMISSION_TRIGGER] Approved: +${durationMinutes} minutes`);
        } 
        else if (oldStatus === 'PENDING' && newStatus === 'REJECTED') {
          currentUsage.rejectedRequests = (currentUsage.rejectedRequests || 0) + 1;
          console.log(`❌ [PERMISSION_TRIGGER] Rejected`);
        }
        else if (oldStatus === 'PENDING' && newStatus === 'CANCELLED') {
          currentUsage.cancelledRequests = (currentUsage.cancelledRequests || 0) + 1;
          console.log(`🚫 [PERMISSION_TRIGGER] Cancelled (pending)`);
        }
        else if (oldStatus === 'APPROVED' && newStatus === 'CANCELLED') {
          currentUsage.approvedRequests = Math.max(0, (currentUsage.approvedRequests || 0) - 1);
          currentUsage.totalMinutesUsed = Math.max(0, (currentUsage.totalMinutesUsed || 0) - durationMinutes);
          currentUsage.cancelledRequests = (currentUsage.cancelledRequests || 0) + 1;
          console.log(`🚫 [PERMISSION_TRIGGER] Cancelled (approved): -${durationMinutes} minutes`);
        }

        currentUsage.updatedAt = admin.firestore.FieldValue.serverTimestamp();

        if (usageDoc.exists) {
          transaction.update(usageRef, currentUsage);
        } else {
          transaction.set(usageRef, currentUsage);
        }
      });

      console.log(`✅ [PERMISSION_TRIGGER] Usage updated for ${usageId}`);
      return null;
    } catch (error) {
      console.error(`❌ [PERMISSION_TRIGGER] Error updating usage:`, error);
      throw error;
    }
  });

/**
 * Trigger when a new permission request is created
 * Tracks request count
 */
exports.onPermissionCreate = functions.firestore
  .document('schools/{schoolId}/permissions/{permissionId}')
  .onCreate(async (snap, context) => {
    const { schoolId, permissionId } = context.params;
    const permissionData = snap.data();

    const staffId = permissionData.staffId;
    const requestDate = permissionData.requestDate?.toDate() || new Date();

    console.log(`📝 [PERMISSION_CREATE] New permission request: ${permissionId}`);

    try {
      const monthKey = `${requestDate.getFullYear()}-${String(requestDate.getMonth() + 1).padStart(2, '0')}`;
      const usageId = `${staffId}_${monthKey}`;
      const usageRef = db
        .collection('schools')
        .doc(schoolId)
        .collection('monthlyPermissionUsage')
        .doc(usageId);

      await db.runTransaction(async (transaction) => {
        const usageDoc = await transaction.get(usageRef);
        
        if (usageDoc.exists) {
          transaction.update(usageRef, {
            totalRequests: admin.firestore.FieldValue.increment(1),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        } else {
          transaction.set(usageRef, {
            staffId,
            month: monthKey,
            totalRequests: 1,
            approvedRequests: 0,
            rejectedRequests: 0,
            cancelledRequests: 0,
            totalMinutesUsed: 0,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }
      });

      console.log(`✅ [PERMISSION_CREATE] Usage tracked for ${usageId}`);
      return null;
    } catch (error) {
      console.error(`❌ [PERMISSION_CREATE] Error tracking usage:`, error);
      throw error;
    }
  });

/**
 * Batch approve multiple permission requests
 * Callable function for admin bulk operations
 */
exports.batchApprovePermissions = functions.https.onCall(async (data, context) => {
  // Verify authentication
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { schoolId, permissionIds, approvedBy, remarks } = data;

  if (!schoolId || !permissionIds || !Array.isArray(permissionIds) || permissionIds.length === 0) {
    throw new functions.https.HttpsError('invalid-argument', 'schoolId and permissionIds array are required');
  }

  // Verify admin permissions
  const userDoc = await db.collection('users').doc(context.auth.uid).get();
  if (!userDoc.exists) {
    throw new functions.https.HttpsError('permission-denied', 'User not found');
  }

  const userData = userDoc.data();
  if (userData.role !== 'ADMIN' && userData.role !== 'SUPER_ADMIN') {
    throw new functions.https.HttpsError('permission-denied', 'Only admins can approve permissions');
  }

  if (userData.role === 'ADMIN' && userData.schoolId !== schoolId) {
    throw new functions.https.HttpsError('permission-denied', 'Access denied to this school');
  }

  console.log(`📋 [BATCH_APPROVE_PERM] Processing ${permissionIds.length} permission requests`);

  const results = {
    success: [],
    failed: [],
  };

  // Process in batches of 10
  const batchSize = 10;
  for (let i = 0; i < permissionIds.length; i += batchSize) {
    const batch = permissionIds.slice(i, i + batchSize);
    
    await Promise.all(batch.map(async (permissionId) => {
      try {
        const permRef = db
          .collection('schools')
          .doc(schoolId)
          .collection('permissions')
          .doc(permissionId);

        const permDoc = await permRef.get();
        if (!permDoc.exists) {
          results.failed.push({ permissionId, error: 'Permission not found' });
          return;
        }

        const permData = permDoc.data();
        if (permData.status !== 'PENDING') {
          results.failed.push({ permissionId, error: `Cannot approve - status is ${permData.status}` });
          return;
        }

        await permRef.update({
          status: 'APPROVED',
          approvedBy: approvedBy || context.auth.uid,
          approvedAt: admin.firestore.FieldValue.serverTimestamp(),
          remarks: remarks || null,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        results.success.push(permissionId);
      } catch (error) {
        console.error(`❌ [BATCH_APPROVE_PERM] Error approving ${permissionId}:`, error);
        results.failed.push({ permissionId, error: error.message });
      }
    }));
  }

  console.log(`✅ [BATCH_APPROVE_PERM] Completed: ${results.success.length} approved, ${results.failed.length} failed`);

  return {
    message: `Processed ${permissionIds.length} requests`,
    approved: results.success.length,
    failed: results.failed.length,
    details: results,
  };
});

/**
 * Get permission analytics for a school
 */
exports.getPermissionAnalytics = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { schoolId, month } = data;

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
      .collection('monthlyPermissionUsage');

    if (month) {
      query = query.where('month', '==', month);
    }

    const snapshot = await query.get();

    const analytics = {
      totalStaff: 0,
      totalRequests: 0,
      totalApproved: 0,
      totalRejected: 0,
      totalCancelled: 0,
      totalMinutesUsed: 0,
      averageMinutesPerStaff: 0,
      staffUsage: [],
    };

    snapshot.forEach((doc) => {
      const data = doc.data();
      analytics.totalStaff++;
      analytics.totalRequests += data.totalRequests || 0;
      analytics.totalApproved += data.approvedRequests || 0;
      analytics.totalRejected += data.rejectedRequests || 0;
      analytics.totalCancelled += data.cancelledRequests || 0;
      analytics.totalMinutesUsed += data.totalMinutesUsed || 0;

      analytics.staffUsage.push({
        staffId: data.staffId,
        month: data.month,
        totalRequests: data.totalRequests || 0,
        approvedRequests: data.approvedRequests || 0,
        totalMinutesUsed: data.totalMinutesUsed || 0,
      });
    });

    if (analytics.totalStaff > 0) {
      analytics.averageMinutesPerStaff = Math.round(analytics.totalMinutesUsed / analytics.totalStaff);
    }

    // Sort by usage descending
    analytics.staffUsage.sort((a, b) => b.totalMinutesUsed - a.totalMinutesUsed);

    return analytics;
  } catch (error) {
    console.error('❌ [PERM_ANALYTICS] Error:', error);
    throw new functions.https.HttpsError('internal', 'Failed to get analytics');
  }
});

/**
 * Initialize permission configuration for a school
 */
exports.initializePermissionConfig = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { schoolId } = data;

  if (!schoolId) {
    throw new functions.https.HttpsError('invalid-argument', 'schoolId is required');
  }

  // Verify admin permissions
  const userDoc = await db.collection('users').doc(context.auth.uid).get();
  if (!userDoc.exists) {
    throw new functions.https.HttpsError('permission-denied', 'User not found');
  }

  const userData = userDoc.data();
  if (userData.role !== 'ADMIN' && userData.role !== 'SUPER_ADMIN') {
    throw new functions.https.HttpsError('permission-denied', 'Only admins can initialize config');
  }

  try {
    const configRef = db
      .collection('schools')
      .doc(schoolId)
      .collection('permissionConfig')
      .doc('default');

    const existingConfig = await configRef.get();
    if (existingConfig.exists) {
      return { message: 'Configuration already exists', exists: true };
    }

    await configRef.set({
      schoolId,
      monthlyLimit: 10,
      maxDurationMinutes: 120,
      requiresApproval: true,
      isActive: true,
      allowWeekends: false,
      allowHolidays: false,
      minAdvanceNoticeHours: 2,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      createdBy: context.auth.uid,
    });

    console.log(`✅ [INIT_CONFIG] Permission config initialized for school: ${schoolId}`);
    return { message: 'Configuration initialized successfully', exists: false };
  } catch (error) {
    console.error('❌ [INIT_CONFIG] Error:', error);
    throw new functions.https.HttpsError('internal', 'Failed to initialize configuration');
  }
});

module.exports = exports;
