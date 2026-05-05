import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

const db = admin.firestore();

interface LeaveTypeConfig {
  id: string;
  code: string;
  yearlyQuota: number;
  monthlyQuota: number;
  isActive: boolean;
}

interface LeaveBalance {
  leaveTypes: Record<string, {
    allocated: number;
    used: number;
    remaining: number;
  }>;
}

/**
 * Validate leave application on creation
 * Auto-reject if validation fails
 */
export const validateLeaveApplication = functions
  .region('asia-south1')
  .firestore
  .document('schools/{schoolId}/leaveApplications/{applicationId}')
  .onCreate(async (snapshot, context) => {
    const schoolId = context.params.schoolId;
    const applicationId = context.params.applicationId;
    const applicationData = snapshot.data();

    try {
      // Only validate pending applications
      if (applicationData.status !== 'PENDING') {
        return null;
      }

      const staffId = applicationData.staffId;
      const leaveTypeId = applicationData.leaveTypeId;
      const leaveDates: admin.firestore.Timestamp[] = applicationData.leaveDates || [];
      const totalDays = applicationData.totalDays || leaveDates.length;
      const academicYear = applicationData.academicYear;

      // Get leave type config
      const leaveTypeDoc = await db
        .collection('schools')
        .doc(schoolId)
        .collection('leaveTypes')
        .doc(leaveTypeId)
        .get();

      if (!leaveTypeDoc.exists) {
        await rejectApplication(snapshot.ref, 'Invalid leave type');
        return null;
      }

      const leaveTypeConfig = leaveTypeDoc.data() as LeaveTypeConfig;

      // Check yearly quota
      const yearlyQuotaExceeded = await checkYearlyQuota(
        schoolId,
        staffId,
        academicYear,
        leaveTypeConfig.code,
        totalDays
      );

      if (yearlyQuotaExceeded) {
        await rejectApplication(
          snapshot.ref,
          `Yearly quota exceeded for ${leaveTypeConfig.code}. You don't have enough leave balance.`
        );
        return null;
      }

      // Check monthly quota
      const monthlyQuotaExceeded = await checkMonthlyQuota(
        schoolId,
        staffId,
        leaveDates,
        leaveTypeConfig.code,
        leaveTypeConfig.monthlyQuota
      );

      if (monthlyQuotaExceeded) {
        await rejectApplication(
          snapshot.ref,
          `Monthly quota exceeded for ${leaveTypeConfig.code}. Maximum ${leaveTypeConfig.monthlyQuota} days per month allowed.`
        );
        return null;
      }

      // Check for overlapping leaves
      const hasOverlap = await checkOverlappingLeaves(
        schoolId,
        staffId,
        leaveDates,
        applicationId
      );

      if (hasOverlap) {
        await rejectApplication(
          snapshot.ref,
          'Leave dates overlap with existing approved or pending leave applications'
        );
        return null;
      }

      console.log(`Leave application ${applicationId} passed validation`);
      return null;
    } catch (error) {
      console.error('Error validating leave application:', error);
      await rejectApplication(snapshot.ref, 'Validation error occurred');
      throw error;
    }
  });

/**
 * Update leave balance when leave is approved
 */
export const updateLeaveBalanceOnApproval = functions
  .region('asia-south1')
  .firestore
  .document('schools/{schoolId}/leaveApplications/{applicationId}')
  .onUpdate(async (change, context) => {
    const schoolId = context.params.schoolId;
    const beforeData = change.before.data();
    const afterData = change.after.data();

    // Check if status changed to APPROVED
    if (beforeData.status !== 'APPROVED' && afterData.status === 'APPROVED') {
      try {
        const staffId = afterData.staffId;
        const leaveTypeCode = afterData.leaveTypeCode;
        const totalDays = afterData.totalDays;
        const academicYear = afterData.academicYear;

        // Deduct from leave balance
        const balanceRef = db
          .collection('schools')
          .doc(schoolId)
          .collection('leaveBalances')
          .doc(`${staffId}_${academicYear}`);

        await db.runTransaction(async (transaction) => {
          const balanceDoc = await transaction.get(balanceRef);

          if (!balanceDoc.exists) {
            throw new Error('Leave balance not found');
          }

          const balanceData = balanceDoc.data() as LeaveBalance;
          const leaveTypes = balanceData.leaveTypes || {};
          const leaveType = leaveTypes[leaveTypeCode];

          if (!leaveType) {
            throw new Error(`Leave type ${leaveTypeCode} not found in balance`);
          }

          // Deduct from remaining balance
          const newRemaining = leaveType.remaining - totalDays;
          const newUsed = leaveType.used + totalDays;

          transaction.update(balanceRef, {
            [`leaveTypes.${leaveTypeCode}.remaining`]: newRemaining,
            [`leaveTypes.${leaveTypeCode}.used`]: newUsed,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        });

        console.log(`Deducted ${totalDays} days from ${leaveTypeCode} balance for staff ${staffId}`);
      } catch (error) {
        console.error('Error updating leave balance:', error);
        throw error;
      }
    }

    // Check if status changed to REJECTED or CANCELLED from APPROVED
    if (beforeData.status === 'APPROVED' && 
        (afterData.status === 'REJECTED' || afterData.status === 'CANCELLED')) {
      try {
        const staffId = afterData.staffId;
        const leaveTypeCode = afterData.leaveTypeCode;
        const totalDays = afterData.totalDays;
        const academicYear = afterData.academicYear;

        // Restore leave balance
        const balanceRef = db
          .collection('schools')
          .doc(schoolId)
          .collection('leaveBalances')
          .doc(`${staffId}_${academicYear}`);

        await db.runTransaction(async (transaction) => {
          const balanceDoc = await transaction.get(balanceRef);

          if (!balanceDoc.exists) {
            throw new Error('Leave balance not found');
          }

          const balanceData = balanceDoc.data() as LeaveBalance;
          const leaveTypes = balanceData.leaveTypes || {};
          const leaveType = leaveTypes[leaveTypeCode];

          if (!leaveType) {
            throw new Error(`Leave type ${leaveTypeCode} not found in balance`);
          }

          // Restore to remaining balance
          const newRemaining = leaveType.remaining + totalDays;
          const newUsed = leaveType.used - totalDays;

          transaction.update(balanceRef, {
            [`leaveTypes.${leaveTypeCode}.remaining`]: newRemaining,
            [`leaveTypes.${leaveTypeCode}.used`]: Math.max(0, newUsed),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        });

        console.log(`Restored ${totalDays} days to ${leaveTypeCode} balance for staff ${staffId}`);
      } catch (error) {
        console.error('Error restoring leave balance:', error);
        throw error;
      }
    }

    return null;
  });

/**
 * Validate permission request on creation
 */
export const validatePermissionRequest = functions
  .region('asia-south1')
  .firestore
  .document('schools/{schoolId}/permissionRequests/{requestId}')
  .onCreate(async (snapshot, context) => {
    const schoolId = context.params.schoolId;
    const requestId = context.params.requestId;
    const requestData = snapshot.data();

    try {
      // Only validate pending requests
      if (requestData.status !== 'PENDING') {
        return null;
      }

      const staffId = requestData.staffId;
      const requestDate = requestData.requestDate.toDate();
      const durationMinutes = requestData.durationMinutes;

      // Get permission config
      const configDoc = await db
        .collection('schools')
        .doc(schoolId)
        .collection('permissionConfig')
        .doc('default')
        .get();

      if (!configDoc.exists) {
        console.warn('Permission config not found, using defaults');
        return null;
      }

      const config = configDoc.data()!;
      const monthlyLimit = config.monthlyLimit || 3;
      const maxDurationMinutes = config.maxDurationMinutes || 240; // 4 hours

      // Check duration limit
      if (durationMinutes > maxDurationMinutes) {
        await rejectPermission(
          snapshot.ref,
          `Permission duration exceeds maximum allowed (${maxDurationMinutes / 60} hours)`
        );
        return null;
      }

      // Check monthly limit
      const month = `${requestDate.getFullYear()}-${String(requestDate.getMonth() + 1).padStart(2, '0')}`;
      const monthlyUsageDoc = await db
        .collection('schools')
        .doc(schoolId)
        .collection('monthlyPermissionUsage')
        .doc(`${staffId}_${month}`)
        .get();

      if (monthlyUsageDoc.exists) {
        const usageData = monthlyUsageDoc.data()!;
        const approvedRequests = usageData.approvedRequests || 0;

        if (approvedRequests >= monthlyLimit) {
          await rejectPermission(
            snapshot.ref,
            `Monthly permission limit exceeded. Maximum ${monthlyLimit} permissions per month allowed.`
          );
          return null;
        }
      }

      console.log(`Permission request ${requestId} passed validation`);
      return null;
    } catch (error) {
      console.error('Error validating permission request:', error);
      await rejectPermission(snapshot.ref, 'Validation error occurred');
      throw error;
    }
  });

/**
 * Update monthly permission usage on approval
 */
export const updatePermissionUsageOnApproval = functions
  .region('asia-south1')
  .firestore
  .document('schools/{schoolId}/permissionRequests/{requestId}')
  .onUpdate(async (change, context) => {
    const schoolId = context.params.schoolId;
    const beforeData = change.before.data();
    const afterData = change.after.data();

    // Check if status changed to APPROVED
    if (beforeData.status !== 'APPROVED' && afterData.status === 'APPROVED') {
      try {
        const staffId = afterData.staffId;
        const userId = afterData.applicantId;
        const requestDate = afterData.requestDate.toDate();
        const durationMinutes = afterData.durationMinutes;
        const month = `${requestDate.getFullYear()}-${String(requestDate.getMonth() + 1).padStart(2, '0')}`;

        const usageRef = db
          .collection('schools')
          .doc(schoolId)
          .collection('monthlyPermissionUsage')
          .doc(`${staffId}_${month}`);

        await db.runTransaction(async (transaction) => {
          const usageDoc = await transaction.get(usageRef);

          if (!usageDoc.exists) {
            // Create new usage record
            transaction.set(usageRef, {
              schoolId,
              staffId,
              userId,
              month,
              totalRequests: 1,
              approvedRequests: 1,
              totalMinutesUsed: durationMinutes,
              createdAt: admin.firestore.FieldValue.serverTimestamp(),
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
          } else {
            // Update existing usage record
            const usageData = usageDoc.data()!;
            transaction.update(usageRef, {
              approvedRequests: (usageData.approvedRequests || 0) + 1,
              totalMinutesUsed: (usageData.totalMinutesUsed || 0) + durationMinutes,
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
          }
        });

        console.log(`Updated permission usage for staff ${staffId} in ${month}`);
      } catch (error) {
        console.error('Error updating permission usage:', error);
        throw error;
      }
    }

    return null;
  });

/**
 * Check yearly quota
 */
async function checkYearlyQuota(
  schoolId: string,
  staffId: string,
  academicYear: string,
  leaveTypeCode: string,
  requestedDays: number
): Promise<boolean> {
  const balanceDoc = await db
    .collection('schools')
    .doc(schoolId)
    .collection('leaveBalances')
    .doc(`${staffId}_${academicYear}`)
    .get();

  if (!balanceDoc.exists) {
    return true; // No balance record, quota exceeded
  }

  const balanceData = balanceDoc.data() as LeaveBalance;
  const leaveTypes = balanceData.leaveTypes || {};
  const leaveType = leaveTypes[leaveTypeCode];

  if (!leaveType) {
    return true; // Leave type not found in balance
  }

  return leaveType.remaining < requestedDays;
}

/**
 * Check monthly quota
 */
async function checkMonthlyQuota(
  schoolId: string,
  staffId: string,
  leaveDates: admin.firestore.Timestamp[],
  leaveTypeCode: string,
  monthlyQuota: number
): Promise<boolean> {
  // Group leave dates by month
  const monthlyDays = new Map<string, number>();

  for (const dateTimestamp of leaveDates) {
    const date = dateTimestamp.toDate();
    const monthKey = `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}`;
    monthlyDays.set(monthKey, (monthlyDays.get(monthKey) || 0) + 1);
  }

  // Check each month
  for (const [month, days] of monthlyDays.entries()) {
    // Get existing approved leaves for this month and leave type
    const startDate = new Date(month + '-01');
    const endDate = new Date(startDate.getFullYear(), startDate.getMonth() + 1, 0);

    const existingLeavesSnapshot = await db
      .collection('schools')
      .doc(schoolId)
      .collection('leaveApplications')
      .where('staffId', '==', staffId)
      .where('leaveTypeCode', '==', leaveTypeCode)
      .where('status', '==', 'APPROVED')
      .get();

    let existingDaysInMonth = 0;
    for (const leaveDoc of existingLeavesSnapshot.docs) {
      const leaveData = leaveDoc.data();
      const leaveDates: admin.firestore.Timestamp[] = leaveData.leaveDates || [];
      
      for (const dateTimestamp of leaveDates) {
        const date = dateTimestamp.toDate();
        if (date >= startDate && date <= endDate) {
          existingDaysInMonth++;
        }
      }
    }

    const totalDaysInMonth = existingDaysInMonth + days;
    if (totalDaysInMonth > monthlyQuota) {
      return true; // Monthly quota exceeded
    }
  }

  return false;
}

/**
 * Check for overlapping leaves
 */
async function checkOverlappingLeaves(
  schoolId: string,
  staffId: string,
  leaveDates: admin.firestore.Timestamp[],
  currentApplicationId: string
): Promise<boolean> {
  const existingLeavesSnapshot = await db
    .collection('schools')
    .doc(schoolId)
    .collection('leaveApplications')
    .where('staffId', '==', staffId)
    .where('status', 'in', ['PENDING', 'APPROVED'])
    .get();

  const requestedDates = new Set(
    leaveDates.map(ts => ts.toDate().toISOString().split('T')[0])
  );

  for (const leaveDoc of existingLeavesSnapshot.docs) {
    if (leaveDoc.id === currentApplicationId) {
      continue; // Skip current application
    }

    const leaveData = leaveDoc.data();
    const existingDates: admin.firestore.Timestamp[] = leaveData.leaveDates || [];

    for (const dateTimestamp of existingDates) {
      const dateStr = dateTimestamp.toDate().toISOString().split('T')[0];
      if (requestedDates.has(dateStr)) {
        return true; // Overlap found
      }
    }
  }

  return false;
}

/**
 * Reject leave application
 */
async function rejectApplication(
  ref: admin.firestore.DocumentReference,
  reason: string
): Promise<void> {
  await ref.update({
    status: 'REJECTED',
    rejectionReason: reason,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  console.log(`Leave application rejected: ${reason}`);
}

/**
 * Reject permission request
 */
async function rejectPermission(
  ref: admin.firestore.DocumentReference,
  reason: string
): Promise<void> {
  await ref.update({
    status: 'REJECTED',
    rejectionReason: reason,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  console.log(`Permission request rejected: ${reason}`);
}
