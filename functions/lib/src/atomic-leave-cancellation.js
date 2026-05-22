const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Initialize Firebase Admin if not already initialized
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

/**
 * ATOMIC LEAVE CANCELLATION APPROVAL
 * Fixes: Race conditions, idempotency, atomic balance restoration
 * 
 * Triggered by: Document updates in /schools/{schoolId}/leaveCancellations/{cancellationId}
 * When status changes from PENDING to APPROVED/REJECTED
 */
exports.processLeaveCancellationApproval = functions.firestore
  .document('/schools/{schoolId}/leaveCancellations/{cancellationId}')
  .onUpdate(async (change, context) => {
    const { schoolId, cancellationId } = context.params;
    const beforeData = change.before.data();
    const afterData = change.after.data();
    
    // IDEMPOTENCY CHECK #1: Status must have changed
    if (beforeData.status === afterData.status) {
      console.log(`No status change for cancellation ${cancellationId}, skipping processing`);
      return;
    }
    
    // IDEMPOTENCY CHECK #2: Already processed
    if (afterData.processedAt) {
      console.log(`Cancellation ${cancellationId} already processed at ${afterData.processedAt}, skipping`);
      return;
    }
    
    // Only process PENDING -> APPROVED transitions
    if (beforeData.status !== 'PENDING' || afterData.status !== 'APPROVED') {
      console.log(`Cancellation ${cancellationId} status changed from ${beforeData.status} to ${afterData.status}, but not PENDING->APPROVED - skipping balance update`);
      return;
    }
    
    console.log(`Processing approved leave cancellation: ${cancellationId} for leave: ${afterData.leaveApplicationId}`);
    
    try {
      await processApprovedLeaveCancellationAtomic(schoolId, cancellationId, afterData);
      console.log(`Leave cancellation ${cancellationId} processed successfully`);
      
    } catch (error) {
      console.error(`Error processing leave cancellation ${cancellationId}:`, error);
      
      // ATOMIC ROLLBACK: Revert approval status on error
      await change.after.ref.update({
        status: 'PENDING',
        approvedBy: null,
        approvedAt: null,
        processedAt: null,
        errorMessage: `Processing failed: ${error.message}`,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      
      // Create system alert
      await createSystemAlert(schoolId, {
        type: 'LEAVE_CANCELLATION_PROCESSING_ERROR',
        cancellationId,
        leaveApplicationId: afterData.leaveApplicationId,
        error: error.message,
      });
      
      throw new functions.https.HttpsError('internal', `Failed to process leave cancellation: ${error.message}`);
    }
  });

/**
 * ATOMIC LEAVE CANCELLATION PROCESSING
 * All operations in single transaction to prevent race conditions
 */
async function processApprovedLeaveCancellationAtomic(schoolId, cancellationId, cancellationData) {
  const { leaveApplicationId, applicantId, leaveTypeId, academicYear, totalDaysToRestore, approvedBy } = cancellationData;
  
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
    .doc(leaveApplicationId);
  
  const cancellationRef = db
    .collection('schools')
    .doc(schoolId)
    .collection('leaveCancellations')
    .doc(cancellationId);
  
  // ATOMIC TRANSACTION: All operations must succeed or all fail
  await db.runTransaction(async (transaction) => {
    // STEP 1: Re-read cancellation document to check for concurrent modifications
    const currentCancellationDoc = await transaction.get(cancellationRef);
    if (!currentCancellationDoc.exists) {
      throw new Error('Leave cancellation request not found');
    }
    
    const currentCancellationData = currentCancellationDoc.data();
    
    // RACE CONDITION PROTECTION: Verify cancellation is still in expected state
    if (currentCancellationData.status !== 'APPROVED') {
      throw new Error(`Cancellation status changed during processing. Expected: APPROVED, Found: ${currentCancellationData.status}`);
    }
    
    // IDEMPOTENCY CHECK #3: Inside transaction
    if (currentCancellationData.processedAt) {
      console.log(`Cancellation ${cancellationId} already processed, skipping`);
      return;
    }
    
    // STEP 2: Verify leave application exists and is in correct state
    const leaveDoc = await transaction.get(leaveRef);
    if (!leaveDoc.exists) {
      throw new Error('Leave application not found');
    }
    
    const leaveData = leaveDoc.data();
    
    // Verify leave is approved (only approved leaves can be cancelled)
    if (leaveData.status !== 'APPROVED') {
      throw new Error(`Cannot cancel leave with status: ${leaveData.status}. Only APPROVED leaves can be cancelled.`);
    }
    
    // Verify leave hasn't already been cancelled
    if (leaveData.status === 'CANCELLED') {
      throw new Error('Leave has already been cancelled');
    }
    
    // STEP 3: Get current balance with optimistic locking
    const balanceDoc = await transaction.get(balanceRef);
    if (!balanceDoc.exists) {
      throw new Error(`Leave balance not found for ${balanceId}`);
    }
    
    const currentBalance = balanceDoc.data();
    
    // STEP 4: Calculate new balance values (restore days from used to available)
    const newUsed = Math.max(0, currentBalance.used - totalDaysToRestore);
    const newAvailable = currentBalance.available + totalDaysToRestore;
    
    // VALIDATION: Ensure we don't restore more days than were used
    if (currentBalance.used < totalDaysToRestore) {
      throw new Error(`Cannot restore ${totalDaysToRestore} days. Only ${currentBalance.used} days were used.`);
    }
    
    // VALIDATION: Ensure balance equation integrity
    const totalAllowed = currentBalance.totalAllowed;
    const newPending = currentBalance.pending;
    if (newUsed + newPending + newAvailable !== totalAllowed) {
      throw new Error(`Balance equation violation. Total: ${totalAllowed}, Calculated: ${newUsed + newPending + newAvailable}`);
    }
    
    // STEP 5: Update leave balance atomically
    transaction.update(balanceRef, {
      used: newUsed,
      available: newAvailable,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      lastModifiedBy: approvedBy,
    });
    
    // STEP 6: Update leave application status to cancelled atomically
    transaction.update(leaveRef, {
      status: 'CANCELLED',
      cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
      cancellationReason: cancellationData.cancellationReason,
      cancelledBy: approvedBy,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    
    // STEP 7: Mark cancellation as processed atomically
    transaction.update(cancellationRef, {
      processedAt: admin.firestore.FieldValue.serverTimestamp(),
      balanceUpdated: true,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    
    // STEP 8: Create immutable balance mutation record
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
      mutationType: 'CANCELLATION_RESTORE',
      previousUsed: currentBalance.used,
      newUsed: newUsed,
      previousAvailable: currentBalance.available,
      newAvailable: newAvailable,
      delta: totalDaysToRestore,
      referenceId: leaveApplicationId,
      reason: `Leave cancelled: ${totalDaysToRestore} days restored to balance`,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      createdBy: approvedBy,
      metadata: {
        cancellationId,
        cancellationReason: cancellationData.cancellationReason,
        originalLeaveStartDate: leaveData.startDate,
        originalLeaveEndDate: leaveData.endDate,
        functionName: 'processApprovedLeaveCancellationAtomic',
        transactionId: `txn_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
      }
    };
    
    transaction.set(mutationRef, mutationData);
    
    console.log(`Balance restored for ${applicantId}: ${totalDaysToRestore} days returned. New available: ${newAvailable}`);
  });
}

/**
 * BACKEND-ONLY LEAVE CANCELLATION REQUEST CREATION
 * Validates cancellation eligibility and calculates days to restore
 */
exports.createLeaveCancellationRequest = functions.https.onCall(async (data, context) => {
  // Authentication check
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }
  
  const { schoolId, leaveApplicationId, cancellationReason } = data;
  const applicantId = context.auth.uid;
  
  try {
    // STEP 1: Validate leave application exists and is cancellable
    const leaveDoc = await db
      .collection('schools')
      .doc(schoolId)
      .collection('leaves')
      .doc(leaveApplicationId)
      .get();
    
    if (!leaveDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Leave application not found');
    }
    
    const leaveData = leaveDoc.data();
    
    // Verify ownership
    if (leaveData.applicantId !== applicantId) {
      throw new functions.https.HttpsError('permission-denied', 'You can only cancel your own leave applications');
    }
    
    // Verify leave is approved
    if (leaveData.status !== 'APPROVED') {
      throw new functions.https.HttpsError('failed-precondition', 'Only approved leaves can be cancelled through this process');
    }
    
    // Verify leave is in the future
    const leaveStartDate = leaveData.startDate.toDate();
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    
    if (leaveStartDate < today) {
      throw new functions.https.HttpsError('failed-precondition', 'Cannot cancel leave that has already started or passed');
    }
    
    // STEP 2: Check for existing pending cancellation
    const existingCancellationQuery = await db
      .collection('schools')
      .doc(schoolId)
      .collection('leaveCancellations')
      .where('leaveApplicationId', '==', leaveApplicationId)
      .where('status', '==', 'PENDING')
      .get();
    
    if (!existingCancellationQuery.empty) {
      throw new functions.https.HttpsError('already-exists', 'A cancellation request is already pending for this leave');
    }
    
    // STEP 3: BACKEND-ONLY CALCULATION: Calculate days to restore
    const totalDaysToRestore = await calculateDaysToRestore(schoolId, leaveData);
    
    // STEP 4: Create cancellation request
    const cancellationRef = db
      .collection('schools')
      .doc(schoolId)
      .collection('leaveCancellations')
      .doc();
    
    const cancellationData = {
      schoolId,
      leaveApplicationId,
      applicantId,
      leaveTypeId: leaveData.leaveTypeId,
      academicYear: leaveData.academicYear,
      totalDaysToRestore,
      cancellationReason,
      status: 'PENDING',
      requestedAt: admin.firestore.FieldValue.serverTimestamp(),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      metadata: {
        originalLeaveStartDate: leaveData.startDate,
        originalLeaveEndDate: leaveData.endDate,
        originalTotalDays: leaveData.totalDays,
        calculatedBy: 'backend',
        functionName: 'createLeaveCancellationRequest',
      }
    };
    
    await cancellationRef.set(cancellationData);
    
    console.log(`Leave cancellation request created: ${cancellationRef.id} for leave: ${leaveApplicationId}, ${totalDaysToRestore} days to restore`);
    
    return {
      cancellationId: cancellationRef.id,
      totalDaysToRestore,
      status: 'PENDING',
    };
    
  } catch (error) {
    console.error('Error creating leave cancellation request:', error);
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError('internal', error.message);
  }
});

/**
 * BACKEND-ONLY: Calculate days to restore for leave cancellation
 * Recalculates working days to ensure accuracy
 */
async function calculateDaysToRestore(schoolId, leaveData) {
  const startDate = leaveData.startDate.toDate();
  const endDate = leaveData.endDate.toDate();
  const academicYear = leaveData.academicYear;
  
  // Get school holidays for academic year
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
  
  // Get weekend configuration
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
  
  // Calculate working days (same logic as leave application creation)
  let workingDays = 0;
  const currentDate = new Date(startDate);
  
  while (currentDate <= endDate) {
    const dateStr = currentDate.toISOString().split('T')[0];
    const dayOfWeek = currentDate.getDay();
    
    if (!weekendDays.includes(dayOfWeek) && !holidays.has(dateStr)) {
      workingDays++;
    }
    
    currentDate.setDate(currentDate.getDate() + 1);
  }
  
  return workingDays;
}

/**
 * DIRECT LEAVE CANCELLATION (for pending leaves)
 * Allows staff to cancel their own pending leaves immediately
 */
exports.cancelPendingLeave = functions.https.onCall(async (data, context) => {
  // Authentication check
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }
  
  const { schoolId, leaveApplicationId } = data;
  const applicantId = context.auth.uid;
  
  try {
    const leaveRef = db
      .collection('schools')
      .doc(schoolId)
      .collection('leaves')
      .doc(leaveApplicationId);
    
    // ATOMIC TRANSACTION: Cancel pending leave and restore balance
    await db.runTransaction(async (transaction) => {
      const leaveDoc = await transaction.get(leaveRef);
      if (!leaveDoc.exists) {
        throw new Error('Leave application not found');
      }
      
      const leaveData = leaveDoc.data();
      
      // Verify ownership
      if (leaveData.applicantId !== applicantId) {
        throw new Error('You can only cancel your own leave applications');
      }
      
      // Verify leave is pending
      if (leaveData.status !== 'PENDING') {
        throw new Error('Only pending leaves can be cancelled directly');
      }
      
      // STEP 1: Update leave status to cancelled
      transaction.update(leaveRef, {
        status: 'CANCELLED',
        cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
        cancelledBy: applicantId,
        cancellationReason: 'Cancelled by applicant',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      
      // STEP 2: Restore balance (move from pending back to available)
      const balanceId = `${applicantId}_${leaveData.leaveTypeId}_${leaveData.academicYear}`;
      const balanceRef = db
        .collection('schools')
        .doc(schoolId)
        .collection('leaveBalances')
        .doc(balanceId);
      
      const balanceDoc = await transaction.get(balanceRef);
      if (balanceDoc.exists) {
        const currentBalance = balanceDoc.data();
        const totalDays = leaveData.totalDays;
        
        const newPending = Math.max(0, currentBalance.pending - totalDays);
        const newAvailable = currentBalance.available + totalDays;
        
        transaction.update(balanceRef, {
          pending: newPending,
          available: newAvailable,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          lastModifiedBy: applicantId,
        });
        
        // STEP 3: Create balance mutation record
        const mutationRef = db
          .collection('schools')
          .doc(schoolId)
          .collection('balanceMutations')
          .doc();
        
        const mutationData = {
          schoolId,
          userId: applicantId,
          leaveTypeId: leaveData.leaveTypeId,
          academicYear: leaveData.academicYear,
          mutationType: 'PENDING_CANCELLATION',
          previousPending: currentBalance.pending,
          newPending: newPending,
          previousAvailable: currentBalance.available,
          newAvailable: newAvailable,
          delta: totalDays,
          referenceId: leaveApplicationId,
          reason: `Pending leave cancelled: ${totalDays} days restored to available balance`,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          createdBy: applicantId,
          metadata: {
            functionName: 'cancelPendingLeave',
            transactionId: `txn_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
          }
        };
        
        transaction.set(mutationRef, mutationData);
      }
    });
    
    console.log(`Pending leave ${leaveApplicationId} cancelled successfully by ${applicantId}`);
    
    return {
      success: true,
      message: 'Leave cancelled successfully',
    };
    
  } catch (error) {
    console.error('Error cancelling pending leave:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

/**
 * Create system alert for admin attention
 */
async function createSystemAlert(schoolId, alertData) {
  try {
    await db.collection('systemAlerts').add({
      schoolId,
      type: alertData.type,
      severity: 'HIGH',
      message: `Leave cancellation processing issue: ${alertData.error || 'Unknown error'}`,
      data: alertData,
      resolved: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      createdBy: 'system_leave_cancellation_workflow',
    });
  } catch (error) {
    console.error('Failed to create system alert:', error);
  }
}
