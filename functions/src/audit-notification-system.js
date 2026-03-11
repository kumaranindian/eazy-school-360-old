const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Initialize Firebase Admin if not already initialized
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

/**
 * Audit logging helper - IMMUTABLE logs written only from Cloud Functions
 */
class AuditLogger {
  static async log(auditData) {
    try {
      const auditEntry = {
        schoolId: auditData.schoolId,
        actorUid: auditData.actorUid,
        actorRole: auditData.actorRole,
        actorName: auditData.actorName || null,
        actionType: auditData.actionType,
        targetId: auditData.targetId,
        targetType: auditData.targetType || null,
        targetName: auditData.targetName || null,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        description: auditData.description || null,
        beforeData: auditData.beforeData || null,
        afterData: auditData.afterData || null,
        metadata: auditData.metadata || null,
        ipAddress: auditData.ipAddress || null,
        userAgent: auditData.userAgent || null,
      };

      // Write to school-scoped audit logs
      await db
        .collection('schools')
        .doc(auditData.schoolId)
        .collection('auditLogs')
        .add(auditEntry);

      console.log(`Audit log created: ${auditData.actionType} by ${auditData.actorRole}`);
    } catch (error) {
      console.error('Failed to create audit log:', error);
      // Don't throw - audit logging should not break main operations
    }
  }
}

/**
 * Notification system - Tenant-aware FCM and in-app notifications
 */
class NotificationSystem {
  static async sendNotification(notificationData) {
    try {
      // Create in-app notification
      await this.createInAppNotification(notificationData);
      
      // Send FCM push notification
      await this.sendPushNotification(notificationData);
      
      console.log(`Notification sent to ${notificationData.recipientRole}: ${notificationData.title}`);
    } catch (error) {
      console.error('Failed to send notification:', error);
    }
  }

  static async createInAppNotification(notificationData) {
    const notification = {
      schoolId: notificationData.schoolId,
      recipientUid: notificationData.recipientUid,
      recipientRole: notificationData.recipientRole,
      title: notificationData.title,
      message: notificationData.message,
      actionType: notificationData.actionType || null,
      actionTargetId: notificationData.actionTargetId || null,
      isRead: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      readAt: null,
      metadata: notificationData.metadata || null,
    };

    await db
      .collection('schools')
      .doc(notificationData.schoolId)
      .collection('notifications')
      .add(notification);
  }

  static async sendPushNotification(notificationData) {
    try {
      // Get user's FCM token
      const userDoc = await db.collection('users').doc(notificationData.recipientUid).get();
      if (!userDoc.exists) return;

      const userData = userDoc.data();
      const fcmToken = userData.fcmToken;

      if (!fcmToken) {
        console.log(`No FCM token for user: ${notificationData.recipientUid}`);
        return;
      }

      // Send to individual token
      const message = {
        token: fcmToken,
        notification: {
          title: notificationData.title,
          body: notificationData.message,
        },
        data: {
          schoolId: notificationData.schoolId,
          actionType: notificationData.actionType || '',
          actionTargetId: notificationData.actionTargetId || '',
        },
        android: {
          notification: {
            channelId: 'leave_management',
            priority: 'high',
          },
        },
        apns: {
          payload: {
            aps: {
              badge: 1,
              sound: 'default',
            },
          },
        },
      };

      await admin.messaging().send(message);

      // Also send to school-scoped topic
      const topicName = `school_${notificationData.schoolId}_${notificationData.recipientRole.toLowerCase()}s`;
      const topicMessage = {
        topic: topicName,
        notification: {
          title: notificationData.title,
          body: notificationData.message,
        },
        data: {
          schoolId: notificationData.schoolId,
          actionType: notificationData.actionType || '',
          actionTargetId: notificationData.actionTargetId || '',
        },
      };

      await admin.messaging().send(topicMessage);
    } catch (error) {
      console.error('FCM send failed:', error);
    }
  }
}

/**
 * Dashboard statistics updater
 */
class DashboardStatsUpdater {
  static async updateSchoolStats(schoolId) {
    try {
      const stats = await this.calculateSchoolStats(schoolId);
      
      await db
        .collection('schools')
        .doc(schoolId)
        .collection('dashboardStats')
        .doc('current')
        .set({
          ...stats,
          lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });

      console.log(`Dashboard stats updated for school: ${schoolId}`);
    } catch (error) {
      console.error('Failed to update dashboard stats:', error);
    }
  }

  static async calculateSchoolStats(schoolId) {
    const today = new Date();
    const todayStart = new Date(today.getFullYear(), today.getMonth(), today.getDate());
    const todayEnd = new Date(todayStart.getTime() + 24 * 60 * 60 * 1000);

    // Get pending leave approvals
    const pendingLeavesQuery = await db
      .collection('schools')
      .doc(schoolId)
      .collection('leaves')
      .where('status', '==', 'PENDING')
      .get();

    // Get pending permission approvals
    const pendingPermissionsQuery = await db
      .collection('schools')
      .doc(schoolId)
      .collection('permissions')
      .where('status', '==', 'PENDING')
      .get();

    // Get staff on leave today
    const staffOnLeaveQuery = await db
      .collection('schools')
      .doc(schoolId)
      .collection('leaves')
      .where('status', '==', 'APPROVED')
      .where('startDate', '<=', admin.firestore.Timestamp.fromDate(todayEnd))
      .where('endDate', '>=', admin.firestore.Timestamp.fromDate(todayStart))
      .get();

    // Get total active staff
    const totalStaffQuery = await db
      .collection('schools')
      .doc(schoolId)
      .collection('staff')
      .where('status', '==', 'ACTIVE')
      .get();

    // Calculate monthly stats
    const currentMonth = `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, '0')}`;
    const monthStart = new Date(today.getFullYear(), today.getMonth(), 1);
    const monthEnd = new Date(today.getFullYear(), today.getMonth() + 1, 0);

    const monthlyLeavesQuery = await db
      .collection('schools')
      .doc(schoolId)
      .collection('leaves')
      .where('createdAt', '>=', admin.firestore.Timestamp.fromDate(monthStart))
      .where('createdAt', '<=', admin.firestore.Timestamp.fromDate(monthEnd))
      .get();

    const monthlyPermissionsQuery = await db
      .collection('schools')
      .doc(schoolId)
      .collection('permissions')
      .where('createdAt', '>=', admin.firestore.Timestamp.fromDate(monthStart))
      .where('createdAt', '<=', admin.firestore.Timestamp.fromDate(monthEnd))
      .get();

    // Process monthly leave stats
    const monthlyLeaveStats = {};
    monthlyLeavesQuery.docs.forEach(doc => {
      const status = doc.data().status;
      monthlyLeaveStats[status] = (monthlyLeaveStats[status] || 0) + 1;
    });

    // Process monthly permission stats
    const monthlyPermissionStats = {};
    monthlyPermissionsQuery.docs.forEach(doc => {
      const status = doc.data().status;
      monthlyPermissionStats[status] = (monthlyPermissionStats[status] || 0) + 1;
    });

    return {
      schoolId,
      pendingLeaveApprovals: pendingLeavesQuery.size,
      pendingPermissionApprovals: pendingPermissionsQuery.size,
      staffOnLeaveToday: staffOnLeaveQuery.size,
      totalStaff: totalStaffQuery.size,
      monthlyLeaveStats,
      monthlyPermissionStats,
    };
  }
}

/**
 * Enhanced leave approval workflow with audit logging and notifications
 */
exports.enhancedLeaveApproval = functions.firestore
  .document('/schools/{schoolId}/leaves/{leaveId}')
  .onUpdate(async (change, context) => {
    const { schoolId, leaveId } = context.params;
    const beforeData = change.before.data();
    const afterData = change.after.data();

    // Check if status changed
    if (beforeData.status === afterData.status) {
      return;
    }

    const previousStatus = beforeData.status;
    const newStatus = afterData.status;

    try {
      // Create audit log
      await AuditLogger.log({
        schoolId,
        actorUid: afterData.approvedBy || 'system',
        actorRole: 'ADMIN', // Assuming only admins can approve
        actionType: newStatus === 'APPROVED' ? 'LEAVE_APPROVED' : 'LEAVE_REJECTED',
        targetId: leaveId,
        targetType: 'LEAVE_APPLICATION',
        targetName: `${afterData.leaveTypeCode} Leave`,
        description: `Leave ${newStatus.toLowerCase()} - ${afterData.totalDays} days`,
        beforeData: { status: previousStatus },
        afterData: { status: newStatus, rejectionReason: afterData.rejectionReason },
        metadata: {
          leaveTypeCode: afterData.leaveTypeCode,
          totalDays: afterData.totalDays,
          startDate: afterData.startDate,
          endDate: afterData.endDate,
        },
      });

      // Send notification to applicant
      let notificationTitle, notificationMessage;
      if (newStatus === 'APPROVED') {
        notificationTitle = 'Leave Approved';
        notificationMessage = `Your ${afterData.leaveTypeCode} leave for ${afterData.totalDays} days has been approved.`;
      } else if (newStatus === 'REJECTED') {
        notificationTitle = 'Leave Rejected';
        notificationMessage = `Your ${afterData.leaveTypeCode} leave request has been rejected.`;
      }

      if (notificationTitle) {
        await NotificationSystem.sendNotification({
          schoolId,
          recipientUid: afterData.applicantId,
          recipientRole: 'STAFF',
          title: notificationTitle,
          message: notificationMessage,
          actionType: 'LEAVE_STATUS_CHANGED',
          actionTargetId: leaveId,
          metadata: {
            leaveTypeCode: afterData.leaveTypeCode,
            totalDays: afterData.totalDays,
            status: newStatus,
          },
        });
      }

      // Update dashboard stats
      await DashboardStatsUpdater.updateSchoolStats(schoolId);

    } catch (error) {
      console.error('Enhanced leave approval processing failed:', error);
    }
  });

/**
 * Enhanced permission approval workflow
 */
exports.enhancedPermissionApproval = functions.firestore
  .document('/schools/{schoolId}/permissions/{permissionId}')
  .onUpdate(async (change, context) => {
    const { schoolId, permissionId } = context.params;
    const beforeData = change.before.data();
    const afterData = change.after.data();

    // Check if status changed
    if (beforeData.status === afterData.status) {
      return;
    }

    const previousStatus = beforeData.status;
    const newStatus = afterData.status;

    try {
      // Create audit log
      await AuditLogger.log({
        schoolId,
        actorUid: afterData.approvedBy || 'system',
        actorRole: 'ADMIN',
        actionType: newStatus === 'APPROVED' ? 'PERMISSION_APPROVED' : 'PERMISSION_REJECTED',
        targetId: permissionId,
        targetType: 'PERMISSION_REQUEST',
        targetName: `Permission Request`,
        description: `Permission ${newStatus.toLowerCase()} - ${afterData.durationMinutes} minutes`,
        beforeData: { status: previousStatus },
        afterData: { status: newStatus, rejectionReason: afterData.rejectionReason },
        metadata: {
          durationMinutes: afterData.durationMinutes,
          requestDate: afterData.requestDate,
          startTime: afterData.startTime,
          endTime: afterData.endTime,
        },
      });

      // Send notification to applicant
      let notificationTitle, notificationMessage;
      if (newStatus === 'APPROVED') {
        notificationTitle = 'Permission Approved';
        notificationMessage = `Your permission request for ${Math.floor(afterData.durationMinutes / 60)}h ${afterData.durationMinutes % 60}m has been approved.`;
      } else if (newStatus === 'REJECTED') {
        notificationTitle = 'Permission Rejected';
        notificationMessage = `Your permission request has been rejected.`;
      }

      if (notificationTitle) {
        await NotificationSystem.sendNotification({
          schoolId,
          recipientUid: afterData.applicantId,
          recipientRole: 'STAFF',
          title: notificationTitle,
          message: notificationMessage,
          actionType: 'PERMISSION_STATUS_CHANGED',
          actionTargetId: permissionId,
          metadata: {
            durationMinutes: afterData.durationMinutes,
            status: newStatus,
          },
        });
      }

      // Update dashboard stats
      await DashboardStatsUpdater.updateSchoolStats(schoolId);

    } catch (error) {
      console.error('Enhanced permission approval processing failed:', error);
    }
  });

/**
 * Leave cancellation approval workflow
 */
exports.enhancedLeaveCancellationApproval = functions.firestore
  .document('/schools/{schoolId}/leaveCancellations/{cancellationId}')
  .onUpdate(async (change, context) => {
    const { schoolId, cancellationId } = context.params;
    const beforeData = change.before.data();
    const afterData = change.after.data();

    // Check if status changed to approved
    if (beforeData.status !== 'APPROVED' && afterData.status === 'APPROVED') {
      try {
        // Create audit log
        await AuditLogger.log({
          schoolId,
          actorUid: afterData.approvedBy,
          actorRole: 'ADMIN',
          actionType: 'LEAVE_CANCELLATION_APPROVED',
          targetId: cancellationId,
          targetType: 'LEAVE_CANCELLATION',
          targetName: `${afterData.leaveTypeCode} Leave Cancellation`,
          description: `Leave cancellation approved - ${afterData.totalDaysToRestore} days restored`,
          beforeData: { status: beforeData.status },
          afterData: { status: afterData.status },
          metadata: {
            leaveApplicationId: afterData.leaveApplicationId,
            leaveTypeCode: afterData.leaveTypeCode,
            totalDaysToRestore: afterData.totalDaysToRestore,
            cancellationReason: afterData.cancellationReason,
          },
        });

        // Send notification to applicant
        await NotificationSystem.sendNotification({
          schoolId,
          recipientUid: afterData.applicantId,
          recipientRole: 'STAFF',
          title: 'Leave Cancellation Approved',
          message: `Your leave cancellation has been approved. ${afterData.totalDaysToRestore} days have been restored to your balance.`,
          actionType: 'LEAVE_CANCELLATION_APPROVED',
          actionTargetId: cancellationId,
          metadata: {
            leaveTypeCode: afterData.leaveTypeCode,
            totalDaysToRestore: afterData.totalDaysToRestore,
          },
        });

      } catch (error) {
        console.error('Enhanced leave cancellation approval processing failed:', error);
      }
    }
  });

/**
 * New leave/permission application notifications
 */
exports.newApplicationNotification = functions.firestore
  .document('/schools/{schoolId}/{collection}/{applicationId}')
  .onCreate(async (snap, context) => {
    const { schoolId, collection, applicationId } = context.params;
    
    // Only process leaves and permissions
    if (!['leaves', 'permissions'].includes(collection)) {
      return;
    }

    const applicationData = snap.data();
    
    try {
      // Get all admins for this school
      const adminsQuery = await db
        .collection('users')
        .where('schoolId', '==', schoolId)
        .where('role', '==', 'ADMIN')
        .where('status', '==', 'ACTIVE')
        .get();

      // Send notification to all admins
      const notificationPromises = adminsQuery.docs.map(async (adminDoc) => {
        const adminData = adminDoc.data();
        
        let title, message, actionType;
        if (collection === 'leaves') {
          title = 'New Leave Application';
          message = `New ${applicationData.leaveTypeCode} leave application for ${applicationData.totalDays} days requires approval.`;
          actionType = 'NEW_LEAVE_APPLICATION';
        } else {
          title = 'New Permission Request';
          message = `New permission request for ${Math.floor(applicationData.durationMinutes / 60)}h ${applicationData.durationMinutes % 60}m requires approval.`;
          actionType = 'NEW_PERMISSION_REQUEST';
        }

        await NotificationSystem.sendNotification({
          schoolId,
          recipientUid: adminData.uid,
          recipientRole: 'ADMIN',
          title,
          message,
          actionType,
          actionTargetId: applicationId,
          metadata: {
            applicantId: applicationData.applicantId,
            collection,
          },
        });
      });

      await Promise.all(notificationPromises);

      // Update dashboard stats
      await DashboardStatsUpdater.updateSchoolStats(schoolId);

    } catch (error) {
      console.error('New application notification failed:', error);
    }
  });

/**
 * FCM token management
 */
exports.updateFCMToken = functions.https.onCall(async (data, context) => {
  // Verify authentication
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { fcmToken } = data;
  
  if (!fcmToken) {
    throw new functions.https.HttpsError('invalid-argument', 'FCM token is required');
  }

  try {
    // Update user's FCM token
    await db.collection('users').doc(context.auth.uid).update({
      fcmToken: fcmToken,
      fcmTokenUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Subscribe to school-scoped topics
    const userDoc = await db.collection('users').doc(context.auth.uid).get();
    if (userDoc.exists) {
      const userData = userDoc.data();
      const schoolId = userData.schoolId;
      const role = userData.role;

      if (schoolId && role) {
        const topicName = `school_${schoolId}_${role.toLowerCase()}s`;
        await admin.messaging().subscribeToTopic([fcmToken], topicName);
        console.log(`User subscribed to topic: ${topicName}`);
      }
    }

    return { success: true };
  } catch (error) {
    console.error('FCM token update failed:', error);
    throw new functions.https.HttpsError('internal', 'Failed to update FCM token');
  }
});

/**
 * Mark notification as read
 */
exports.markNotificationRead = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { schoolId, notificationId } = data;

  if (!schoolId || !notificationId) {
    throw new functions.https.HttpsError('invalid-argument', 'School ID and notification ID are required');
  }

  try {
    // Verify user has access to this school
    const userDoc = await db.collection('users').doc(context.auth.uid).get();
    if (!userDoc.exists || userDoc.data().schoolId !== schoolId) {
      throw new functions.https.HttpsError('permission-denied', 'Access denied to this school');
    }

    // Update notification
    await db
      .collection('schools')
      .doc(schoolId)
      .collection('notifications')
      .doc(notificationId)
      .update({
        isRead: true,
        readAt: admin.firestore.FieldValue.serverTimestamp(),
      });

    return { success: true };
  } catch (error) {
    console.error('Mark notification read failed:', error);
    throw new functions.https.HttpsError('internal', 'Failed to mark notification as read');
  }
});

/**
 * Scheduled dashboard stats update (runs every hour)
 */
exports.scheduledDashboardUpdate = functions.pubsub
  .schedule('0 * * * *') // Every hour
  .onRun(async (context) => {
    try {
      // Get all active schools
      const schoolsQuery = await db
        .collection('schools')
        .where('status', '==', 'ACTIVE')
        .get();

      // Update stats for each school
      const updatePromises = schoolsQuery.docs.map(async (schoolDoc) => {
        await DashboardStatsUpdater.updateSchoolStats(schoolDoc.id);
      });

      await Promise.all(updatePromises);
      console.log(`Dashboard stats updated for ${schoolsQuery.size} schools`);
    } catch (error) {
      console.error('Scheduled dashboard update failed:', error);
    }
  });
