const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Initialize Firebase Admin if not already initialized
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

/**
 * ATOMIC LEAVE APPROVAL CLOUD FUNCTION
 * Fixes: Race conditions, idempotency, atomic operations
 * 
 * Triggered by: Document updates in /schools/{schoolId}/leaves/{leaveId}
 * When status changes from PENDING to APPROVED/REJECTED
 */
exports.processLeaveStatusChange = functions.firestore
  .document('/schools/{schoolId}/leaves/{leaveId}')
  .onUpdate(async (change, context) => {
    const { schoolId, leaveId } = context.params;
    const beforeData = change.before.data();
    const afterData = change.after.data();
    
    // IDEMPOTENCY CHECK #1: Status must have changed
    if (beforeData.status === afterData.status) {
      console.log(`No status change for leave ${leaveId}, skipping processing`);
      return;
    }
    
    // IDEMPOTENCY CHECK #2: Already processed
    if (afterData.processedAt) {
      console.log(`Leave ${leaveId} already processed at ${afterData.processedAt}, skipping`);
      return;
    }
    
    // Only process PENDING -> APPROVED/REJECTED transitions
    if (beforeData.status !== 'PENDING') {
      console.log(`Leave ${leaveId} status changed from ${beforeData.status} to ${afterData.status}, but not from PENDING - skipping balance update`);
      return;
    }
    
    if (!['APPROVED', 'REJECTED'].includes(afterData.status)) {
      console.log(`Leave ${leaveId} status changed to ${afterData.status}, no balance update needed`);
      return;
    }
    
    console.log(`Processing leave ${leaveId}: ${beforeData.status} -> ${afterData.status}`);
    
    try {
      if (afterData.status === 'APPROVED') {
        await processLeaveApproval(schoolId, leaveId, afterData);
      } else if (afterData.status === 'REJECTED') {
        await processLeaveRejection(schoolId, leaveId, afterData);
      }
      
      console.log(`Leave ${leaveId} processed successfully`);
      
    } catch (error) {
      console.error(`Error processing leave ${leaveId}:`, error);
      
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
        type: 'LEAVE_PROCESSING_ERROR',
        leaveId,
        applicantId: afterData.applicantId,
        error: error.message,
        attemptedStatus: afterData.status,
      });
      
      throw new functions.https.HttpsError('internal', `Failed to process leave: ${error.message}`);
    }
  });

/**
 * ATOMIC LEAVE APPROVAL PROCESSING
 * All operations in single transaction to prevent race conditions
 */
async function processLeaveApproval(schoolId, leaveId, leaveData) {
  const { applicantId, leaveTypeId, academicYear, totalDays, approvedBy } = leaveData;
  
  // Calculate balance document ID
  const balanceId = `${applicantId}_${leaveTypeId}_${academicYear}`;
  const balanceRef = db
    .collection('schools')
    .doc(schoolId)
    .collection('leaveBalances')
    .doc(balanceId);
  
  const leaveRef = db
    .collection('schools')
    .doc(schoolId)
    .collection('leaves')
    .doc(leaveId);
  
  // ATOMIC TRANSACTION: All operations must succeed or all fail
  await db.runTransaction(async (transaction) => {
    // STEP 1: Re-read leave document to check for concurrent modifications
    const currentLeaveDoc = await transaction.get(leaveRef);
    if (!currentLeaveDoc.exists) {
      throw new Error('Leave application not found');
    }
    
    const currentLeaveData = currentLeaveDoc.data();
    
    // RACE CONDITION PROTECTION: Verify leave is still in expected state
    if (currentLeaveData.status !== 'APPROVED') {
      throw new Error(`Leave status changed during processing. Expected: APPROVED, Found: ${currentLeaveData.status}`);
    }
    
    // IDEMPOTENCY CHECK #3: Inside transaction
    if (currentLeaveData.processedAt) {
      console.log(`Leave ${leaveId} already processed, skipping`);
      return;
    }
    
    // STEP 2: Get current balance with optimistic locking
    const balanceDoc = await transaction.get(balanceRef);
    if (!balanceDoc.exists) {
      throw new Error(`Leave balance not found for ${balanceId}`);
    }
    
    const currentBalance = balanceDoc.data();
    
    // NEGATIVE BALANCE PROTECTION: Check available balance
    if (currentBalance.available < totalDays) {
      throw new Error(`Insufficient leave balance. Available: ${currentBalance.available}, Required: ${totalDays}`);
    }
    
    // STEP 3: Calculate new balance values
    const newUsed = currentBalance.used + totalDays;
    const newPending = Math.max(0, currentBalance.pending - totalDays);
    const newAvailable = currentBalance.available - totalDays;
    
    // VALIDATION: Ensure balance equation integrity
    const totalAllowed = currentBalance.totalAllowed;
    if (newUsed + newPending + newAvailable !== totalAllowed) {
      throw new Error(`Balance equation violation. Total: ${totalAllowed}, Calculated: ${newUsed + newPending + newAvailable}`);
    }
    
    // STEP 4: Update leave balance atomically
    transaction.update(balanceRef, {
      used: newUsed,
      pending: newPending,
      available: newAvailable,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      lastModifiedBy: approvedBy,
    });
    
    // STEP 5: Mark leave as processed atomically
    transaction.update(leaveRef, {
      processedAt: admin.firestore.FieldValue.serverTimestamp(),
      balanceUpdated: true,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    
    // STEP 6: Create immutable balance mutation record
    const mutationRef = db
      .collection('schools')
      .doc(schoolId)
      .collection('balanceMutations')
      .doc();
    
    const mutationData = {
      schoolId,
      userId: applicantId,
      leaveTypeId,
      academicYear,
      mutationType: 'LEAVE_APPROVAL',
      previousUsed: currentBalance.used,
      newUsed: newUsed,
      previousAvailable: currentBalance.available,
      newAvailable: newAvailable,
      delta: totalDays,
      referenceId: leaveId,
      reason: `Leave approved: ${totalDays} days deducted from balance`,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      createdBy: approvedBy,
      metadata: {
        leaveStartDate: leaveData.startDate,
        leaveEndDate: leaveData.endDate,
        functionName: 'processLeaveApproval',
        transactionId: `txn_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
      }
    };
    
    transaction.set(mutationRef, mutationData);
    
    console.log(`Balance updated for ${applicantId}: ${totalDays} days deducted. New available: ${newAvailable}`);
  });
}

/**
 * ATOMIC LEAVE REJECTION PROCESSING
 * Updates pending balance without affecting used/available
 */
async function processLeaveRejection(schoolId, leaveId, leaveData) {
  const { applicantId, leaveTypeId, academicYear, totalDays, rejectedBy } = leaveData;
  
  const balanceId = `${applicantId}_${leaveTypeId}_${academicYear}`;
  const balanceRef = db
    .collection('schools')
    .doc(schoolId)
    .collection('leaveBalances')
    .doc(balanceId);
  
  const leaveRef = db
    .collection('schools')
    .doc(schoolId)
    .collection('leaves')
    .doc(leaveId);
  
  // ATOMIC TRANSACTION: Restore pending balance
  await db.runTransaction(async (transaction) => {
    // STEP 1: Re-read leave document
    const currentLeaveDoc = await transaction.get(leaveRef);
    if (!currentLeaveDoc.exists) {
      throw new Error('Leave application not found');
    }
    
    const currentLeaveData = currentLeaveDoc.data();
    
    // RACE CONDITION PROTECTION
    if (currentLeaveData.status !== 'REJECTED') {
      throw new Error(`Leave status changed during processing. Expected: REJECTED, Found: ${currentLeaveData.status}`);
    }
    
    // IDEMPOTENCY CHECK
    if (currentLeaveData.processedAt) {
      console.log(`Leave ${leaveId} already processed, skipping`);
      return;
    }
    
    // STEP 2: Get current balance
    const balanceDoc = await transaction.get(balanceRef);
    if (!balanceDoc.exists) {
      throw new Error(`Leave balance not found for ${balanceId}`);
    }
    
    const currentBalance = balanceDoc.data();
    
    // STEP 3: Calculate new balance (restore pending to available)
    const newPending = Math.max(0, currentBalance.pending - totalDays);
    const newAvailable = currentBalance.available + totalDays;
    
    // STEP 4: Update balance atomically
    transaction.update(balanceRef, {
      pending: newPending,
      available: newAvailable,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      lastModifiedBy: rejectedBy,
    });
    
    // STEP 5: Mark leave as processed
    transaction.update(leaveRef, {
      processedAt: admin.firestore.FieldValue.serverTimestamp(),
      balanceUpdated: true,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    
    // STEP 6: Create balance mutation record
    const mutationRef = db
      .collection('schools')
      .doc(schoolId)
      .collection('balanceMutations')
      .doc();
    
    const mutationData = {
      schoolId,
      userId: applicantId,
      leaveTypeId,
      academicYear,
      mutationType: 'LEAVE_REJECTION',
      previousPending: currentBalance.pending,
      newPending: newPending,
      previousAvailable: currentBalance.available,
      newAvailable: newAvailable,
      delta: totalDays,
      referenceId: leaveId,
      reason: `Leave rejected: ${totalDays} days restored to available balance`,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      createdBy: rejectedBy,
      metadata: {
        rejectionReason: leaveData.rejectionReason,
        functionName: 'processLeaveRejection',
        transactionId: `txn_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
      }
    };
    
    transaction.set(mutationRef, mutationData);
    
    console.log(`Balance updated for ${applicantId}: ${totalDays} days restored to available. New available: ${newAvailable}`);
  });
}

/**
 * BACKEND-ONLY LEAVE APPLICATION CREATION
 * Calculates working days excluding holidays and weekends
 */
exports.createLeaveApplication = functions.https.onCall(async (data, context) => {
  // Authentication check
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }
  
  const { schoolId, leaveTypeId, startDate, endDate, reason, attachments } = data;
  const applicantId = context.auth.uid;
  
  try {
    // SECURITY VALIDATION: Reject if client sends calculated values
    if (data.totalDays !== undefined || data.calculatedDays !== undefined) {
      // Log security violation
      await createSecurityAlert(schoolId, {
        type: 'CLIENT_CALCULATION_ATTEMPT',
        actorUid: applicantId,
        reason: 'Client attempted to send calculated leave days',
        clientData: { totalDays: data.totalDays, calculatedDays: data.calculatedDays },
        timestamp: admin.firestore.FieldValue.serverTimestamp()
      });
      
      throw new functions.https.HttpsError('invalid-argument', 'Client calculations not allowed. Server will calculate working days.');
    }
    
    // STEP 1: Get current academic year
    const academicYear = await getCurrentAcademicYear(schoolId);
    
    // STEP 2: BACKEND-ONLY CALCULATION: Get working days
    const workingDaysResult = await calculateWorkingDays(schoolId, startDate, endDate, academicYear);
    const totalDays = workingDaysResult.totalDays;
    const excludedDates = workingDaysResult.excludedDates;
    
    if (totalDays <= 0) {
      throw new functions.https.HttpsError('invalid-argument', 'Leave application must span at least one working day');
    }
    
    // STEP 3: Check for overlapping leaves
    await validateNoOverlappingLeaves(schoolId, applicantId, startDate, endDate);
    
    // STEP 4: Reserve balance (move from available to pending)
    await reserveLeaveBalance(schoolId, applicantId, leaveTypeId, academicYear, totalDays);
    
    // STEP 5: Create leave application
    const leaveRef = db
      .collection('schools')
      .doc(schoolId)
      .collection('leaves')
      .doc();
    
    const leaveData = {
      schoolId,
      applicantId,
      leaveTypeId,
      academicYear,
      startDate: admin.firestore.Timestamp.fromDate(new Date(startDate)),
      endDate: admin.firestore.Timestamp.fromDate(new Date(endDate)),
      totalDays, // BACKEND CALCULATED ONLY
      reason,
      attachments: attachments || [],
      status: 'PENDING',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      metadata: {
        excludedDates, // BACKEND DETERMINED ONLY
        calculatedBy: 'backend',
        functionName: 'createLeaveApplication',
        securityValidated: true
      }
    };
    
    await leaveRef.set(leaveData);
    
    console.log(`SECURE: Leave application created: ${leaveRef.id} for ${applicantId}, ${totalDays} days (backend calculated)`);
    
    return {
      leaveId: leaveRef.id,
      totalDays, // Backend calculated value
      excludedDates, // Backend determined holidays/weekends
      status: 'PENDING',
      message: 'Leave application created with backend calculations'
    };
    
  } catch (error) {
    console.error('Error creating leave application:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

/**
 * BACKEND-ONLY: Calculate working days excluding holidays and weekends
 * SECURITY: This calculation MUST ONLY happen in Cloud Functions
 * Client cannot manipulate holiday data or weekend configurations
 */
async function calculateWorkingDays(schoolId, startDateStr, endDateStr, academicYear) {
  const startDate = new Date(startDateStr);
  const endDate = new Date(endDateStr);
  
  // SECURITY: Fetch authoritative holiday data from Firestore
  const holidaysQuery = await db
    .collection('schools')
    .doc(schoolId)
    .collection('holidays')
    .where('academicYear', '==', academicYear)
    .where('isActive', '==', true)
    .get();
  
  const holidays = new Set();
  holidaysQuery.docs.forEach(doc => {
    const holiday = doc.data();
    const holidayDate = holiday.date.toDate();
    holidays.add(holidayDate.toISOString().split('T')[0]);
  });
  
  // SECURITY: Fetch authoritative weekend configuration from Firestore
  const weekendConfigDoc = await db
    .collection('schools')
    .doc(schoolId)
    .collection('weekendConfig')
    .doc('default')
    .get();
  
  let weekendDays = [0, 6]; // Default: Sunday, Saturday
  if (weekendConfigDoc.exists) {
    weekendDays = weekendConfigDoc.data().weekendDays || [0, 6];
  }
  
  // BACKEND-ONLY CALCULATION: Working days computation
  let totalDays = 0;
  const excludedDates = [];
  const currentDate = new Date(startDate);
  
  while (currentDate <= endDate) {
    const dateStr = currentDate.toISOString().split('T')[0];
    const dayOfWeek = currentDate.getDay();
    
    if (weekendDays.includes(dayOfWeek)) {
      excludedDates.push({ date: dateStr, reason: 'Weekend' });
    } else if (holidays.has(dateStr)) {
      excludedDates.push({ date: dateStr, reason: 'Holiday' });
    } else {
      totalDays++;
    }
    
    currentDate.setDate(currentDate.getDate() + 1);
  }
  
  // Log calculation for security audit
  console.log(`Backend calculated working days for ${schoolId}: ${totalDays} days from ${startDateStr} to ${endDateStr}`);
  
  return { totalDays, excludedDates };
}

/**
 * Reserve leave balance (move from available to pending)
 */
async function reserveLeaveBalance(schoolId, applicantId, leaveTypeId, academicYear, totalDays) {
  const balanceId = `${applicantId}_${leaveTypeId}_${academicYear}`;
  const balanceRef = db
    .collection('schools')
    .doc(schoolId)
    .collection('leaveBalances')
    .doc(balanceId);
  
  await db.runTransaction(async (transaction) => {
    const balanceDoc = await transaction.get(balanceRef);
    if (!balanceDoc.exists) {
      throw new Error(`Leave balance not found for ${balanceId}`);
    }
    
    const currentBalance = balanceDoc.data();
    
    // Check available balance
    if (currentBalance.available < totalDays) {
      throw new Error(`Insufficient leave balance. Available: ${currentBalance.available}, Required: ${totalDays}`);
    }
    
    // Move from available to pending
    const newAvailable = currentBalance.available - totalDays;
    const newPending = currentBalance.pending + totalDays;
    
    transaction.update(balanceRef, {
      available: newAvailable,
      pending: newPending,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    
    console.log(`Balance reserved for ${applicantId}: ${totalDays} days moved to pending`);
  });
}

/**
 * Validate no overlapping leaves
 */
async function validateNoOverlappingLeaves(schoolId, applicantId, startDate, endDate) {
  const overlappingQuery = await db
    .collection('schools')
    .doc(schoolId)
    .collection('leaves')
    .where('applicantId', '==', applicantId)
    .where('status', 'in', ['PENDING', 'APPROVED'])
    .get();
  
  const start = new Date(startDate);
  const end = new Date(endDate);
  
  for (const doc of overlappingQuery.docs) {
    const leave = doc.data();
    const leaveStart = leave.startDate.toDate();
    const leaveEnd = leave.endDate.toDate();
    
    // Check for overlap
    if (start <= leaveEnd && end >= leaveStart) {
      throw new Error(`Overlapping leave found: ${doc.id} (${leaveStart.toISOString().split('T')[0]} to ${leaveEnd.toISOString().split('T')[0]})`);
    }
  }
}

/**
 * Get current academic year
 */
async function getCurrentAcademicYear(schoolId) {
  const academicYearDoc = await db
    .collection('schools')
    .doc(schoolId)
    .collection('academicYears')
    .where('isCurrent', '==', true)
    .limit(1)
    .get();
  
  if (academicYearDoc.empty) {
    // Default academic year calculation (June to May)
    const now = new Date();
    const currentYear = now.getFullYear();
    const academicStartMonth = 5; // June (0-indexed)
    
    if (now.getMonth() >= academicStartMonth) {
      return `${currentYear}-${currentYear + 1}`;
    } else {
      return `${currentYear - 1}-${currentYear}`;
    }
  }
  
  return academicYearDoc.docs[0].data().year;
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
  } catch (error) {
    console.error('Failed to create system alert:', error);
  }
}

/**
 * Create security alert for client calculation attempts
 */
async function createSecurityAlert(schoolId, alertData) {
  try {
    // Log to immutable audit logs
    await db
      .collection('schools')
      .doc(schoolId)
      .collection('auditLogs')
      .add({
        schoolId,
        actorUid: alertData.actorUid,
        actionType: 'SECURITY_VIOLATION',
        targetType: 'LEAVE_APPLICATION',
        beforeData: null,
        afterData: alertData.clientData,
        reason: alertData.reason,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        metadata: {
          violationType: alertData.type,
          severity: 'CRITICAL',
          functionName: 'createLeaveApplication'
        }
      });

    // Also create system alert
    await createSystemAlert(schoolId, {
      type: 'SECURITY_VIOLATION',
      error: alertData.reason,
      actorUid: alertData.actorUid,
      severity: 'CRITICAL'
    });

    console.error(`SECURITY VIOLATION: ${alertData.reason} by user ${alertData.actorUid} in school ${schoolId}`);
  } catch (error) {
    console.error('Failed to create security alert:', error);
  }
}
