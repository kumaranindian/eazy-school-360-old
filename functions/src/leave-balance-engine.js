const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Initialize Firebase Admin if not already initialized
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

/**
 * Cloud Function: Generate leave balances when a new staff member is created
 * Triggered by: Document creation in /schools/{schoolId}/staff/{staffId}
 */
exports.generateLeaveBalancesOnStaffCreation = functions.firestore
  .document('/schools/{schoolId}/staff/{staffId}')
  .onCreate(async (snap, context) => {
    const { schoolId, staffId } = context.params;
    const staffData = snap.data();
    
    console.log(`Generating leave balances for staff: ${staffId} in school: ${schoolId}`);
    
    try {
      // Get current academic year
      const currentAcademicYear = getCurrentAcademicYear();
      
      // Get all active leave types for the school
      const leaveTypesSnapshot = await db
        .collection('schools')
        .doc(schoolId)
        .collection('leaveTypes')
        .where('isActive', '==', true)
        .get();
      
      if (leaveTypesSnapshot.empty) {
        console.log(`No active leave types found for school: ${schoolId}`);
        return;
      }
      
      const batch = db.batch();
      const balances = [];
      
      // Create balance for each leave type
      for (const leaveTypeDoc of leaveTypesSnapshot.docs) {
        const leaveType = leaveTypeDoc.data();
        const leaveTypeId = leaveTypeDoc.id;
        
        const balanceId = `${staffId}_${leaveTypeId}_${currentAcademicYear}`;
        const balanceRef = db
          .collection('schools')
          .doc(schoolId)
          .collection('leaveBalances')
          .doc(balanceId);
        
        const balanceData = {
          schoolId,
          staffId,
          userId: staffData.userId,
          leaveTypeId,
          leaveTypeCode: leaveType.code,
          academicYear: currentAcademicYear,
          totalAllowed: leaveType.annualQuota,
          used: 0,
          pending: 0,
          carriedForward: 0,
          available: leaveType.annualQuota,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          createdBy: 'system_staff_creation',
          metadata: {
            generationSource: 'STAFF_CREATION',
            staffJoiningDate: staffData.joiningDate,
            leaveTypeConfig: {
              annualQuota: leaveType.annualQuota,
              carryForwardAllowed: leaveType.carryForwardAllowed,
              maxCarryForwardDays: leaveType.maxCarryForwardDays
            }
          }
        };
        
        batch.set(balanceRef, balanceData);
        balances.push({ leaveTypeCode: leaveType.code, balance: balanceData });
        
        // Create mutation record
        const mutationRef = db
          .collection('schools')
          .doc(schoolId)
          .collection('balanceMutations')
          .doc();
        
        const mutationData = {
          schoolId,
          staffId,
          userId: staffData.userId,
          leaveTypeId,
          academicYear: currentAcademicYear,
          mutationType: 'CREATED',
          previousValue: 0,
          newValue: leaveType.annualQuota,
          delta: leaveType.annualQuota,
          referenceId: staffId,
          reason: `Initial balance creation for new staff member`,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          createdBy: 'system_staff_creation',
          metadata: {
            staffJoiningDate: staffData.joiningDate,
            leaveTypeCode: leaveType.code,
            functionName: 'generateLeaveBalancesOnStaffCreation'
          }
        };
        
        batch.set(mutationRef, mutationData);
      }
      
      await batch.commit();
      
      console.log(`Successfully created ${balances.length} leave balances for staff: ${staffId}`);
      console.log('Balances created:', balances.map(b => `${b.leaveTypeCode}: ${b.balance.available} days`));
      
    } catch (error) {
      console.error('Error generating leave balances:', error);
      throw new functions.https.HttpsError('internal', 'Failed to generate leave balances');
    }
  });

/**
 * Cloud Function: Academic Year Reset (Cron Job)
 * Scheduled to run on June 1st at 00:00 UTC every year
 * Resets all leave balances and applies carry forward logic
 * DISABLED TO REDUCE COSTS - Can be re-enabled if needed
 */
/*
exports.academicYearReset = functions.pubsub
  .schedule('0 0 1 6 *') // June 1st at 00:00 UTC
  .timeZone('UTC')
  .onRun(async (context) => {
    console.log('Starting Academic Year Reset process...');
    
    try {
      const currentAcademicYear = getCurrentAcademicYear();
      const previousAcademicYear = getPreviousAcademicYear(currentAcademicYear);
      
      console.log(`Resetting from ${previousAcademicYear} to ${currentAcademicYear}`);
      
      // Get all schools
      const schoolsSnapshot = await db.collection('schools').get();
      
      if (schoolsSnapshot.empty) {
        console.log('No schools found for academic year reset');
        return;
      }
      
      const resetPromises = [];
      
      // Process each school
      for (const schoolDoc of schoolsSnapshot.docs) {
        const schoolId = schoolDoc.id;
        resetPromises.push(processSchoolAcademicYearReset(schoolId, currentAcademicYear, previousAcademicYear));
      }
      
      const results = await Promise.allSettled(resetPromises);
      
      // Log results
      let successCount = 0;
      let errorCount = 0;
      
      results.forEach((result, index) => {
        const schoolId = schoolsSnapshot.docs[index].id;
        if (result.status === 'fulfilled') {
          successCount++;
          console.log(`Successfully reset school: ${schoolId}`);
        } else {
          errorCount++;
          console.error(`Failed to reset school: ${schoolId}`, result.reason);
        }
      });
      
      console.log(`Academic Year Reset completed. Success: ${successCount}, Errors: ${errorCount}`);
      
    } catch (error) {
      console.error('Academic Year Reset failed:', error);
      throw error;
    }
  });

/**
 * Process academic year reset for a single school
 */
async function processSchoolAcademicYearReset(schoolId, newAcademicYear, previousAcademicYear) {
  console.log(`Processing academic year reset for school: ${schoolId}`);
  
  try {
    // Get all active staff in the school
    const staffSnapshot = await db
      .collection('schools')
      .doc(schoolId)
      .collection('staff')
      .where('status', '==', 'ACTIVE')
      .get();
    
    if (staffSnapshot.empty) {
      console.log(`No active staff found for school: ${schoolId}`);
      return;
    }
    
    // Get all active leave types for the school
    const leaveTypesSnapshot = await db
      .collection('schools')
      .doc(schoolId)
      .collection('leaveTypes')
      .where('isActive', '==', true)
      .get();
    
    if (leaveTypesSnapshot.empty) {
      console.log(`No active leave types found for school: ${schoolId}`);
      return;
    }
    
    const batch = db.batch();
    let balancesCreated = 0;
    let mutationsCreated = 0;
    
    // Process each staff member
    for (const staffDoc of staffSnapshot.docs) {
      const staffData = staffDoc.data();
      const staffId = staffDoc.id;
      
      // Process each leave type
      for (const leaveTypeDoc of leaveTypesSnapshot.docs) {
        const leaveType = leaveTypeDoc.data();
        const leaveTypeId = leaveTypeDoc.id;
        
        // Get previous year balance for carry forward calculation
        const previousBalanceId = `${staffId}_${leaveTypeId}_${previousAcademicYear}`;
        const previousBalanceDoc = await db
          .collection('schools')
          .doc(schoolId)
          .collection('leaveBalances')
          .doc(previousBalanceId)
          .get();
        
        let carriedForward = 0;
        
        // Calculate carry forward if allowed and previous balance exists
        if (leaveType.carryForwardAllowed && previousBalanceDoc.exists) {
          const previousBalance = previousBalanceDoc.data();
          const availableToCarry = previousBalance.available || 0;
          carriedForward = Math.min(availableToCarry, leaveType.maxCarryForwardDays || 0);
        }
        
        // Create new balance for current academic year
        const newBalanceId = `${staffId}_${leaveTypeId}_${newAcademicYear}`;
        const newBalanceRef = db
          .collection('schools')
          .doc(schoolId)
          .collection('leaveBalances')
          .doc(newBalanceId);
        
        const totalAllowed = leaveType.annualQuota + carriedForward;
        
        const newBalanceData = {
          schoolId,
          staffId,
          userId: staffData.userId,
          leaveTypeId,
          leaveTypeCode: leaveType.code,
          academicYear: newAcademicYear,
          totalAllowed: leaveType.annualQuota,
          used: 0,
          pending: 0,
          carriedForward,
          available: totalAllowed,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          createdBy: 'system_academic_year_reset',
          metadata: {
            generationSource: 'ACADEMIC_YEAR_RESET',
            previousAcademicYear,
            carriedForwardFrom: carriedForward > 0 ? previousBalanceId : null,
            resetDate: admin.firestore.FieldValue.serverTimestamp()
          }
        };
        
        batch.set(newBalanceRef, newBalanceData);
        balancesCreated++;
        
        // Create mutation record for reset
        const resetMutationRef = db
          .collection('schools')
          .doc(schoolId)
          .collection('balanceMutations')
          .doc();
        
        const resetMutationData = {
          schoolId,
          staffId,
          userId: staffData.userId,
          leaveTypeId,
          academicYear: newAcademicYear,
          mutationType: 'RESET',
          previousValue: 0,
          newValue: totalAllowed,
          delta: totalAllowed,
          referenceId: newBalanceId,
          reason: `Academic year reset to ${newAcademicYear}`,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          createdBy: 'system_academic_year_reset',
          metadata: {
            previousAcademicYear,
            carriedForward,
            annualQuota: leaveType.annualQuota,
            functionName: 'academicYearReset'
          }
        };
        
        batch.set(resetMutationRef, resetMutationData);
        mutationsCreated++;
        
        // Create carry forward mutation if applicable
        if (carriedForward > 0) {
          const carryForwardMutationRef = db
            .collection('schools')
            .doc(schoolId)
            .collection('balanceMutations')
            .doc();
          
          const carryForwardMutationData = {
            schoolId,
            staffId,
            userId: staffData.userId,
            leaveTypeId,
            academicYear: newAcademicYear,
            mutationType: 'CARRY_FORWARD',
            previousValue: leaveType.annualQuota,
            newValue: totalAllowed,
            delta: carriedForward,
            referenceId: previousBalanceId,
            reason: `Carried forward ${carriedForward} days from ${previousAcademicYear}`,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            createdBy: 'system_academic_year_reset',
            metadata: {
              previousAcademicYear,
              carriedForwardDays: carriedForward,
              maxCarryForwardAllowed: leaveType.maxCarryForwardDays,
              functionName: 'academicYearReset'
            }
          };
          
          batch.set(carryForwardMutationRef, carryForwardMutationData);
          mutationsCreated++;
        }
      }
    }
    
    // Create academic year metadata record
    const academicYearRef = db
      .collection('schools')
      .doc(schoolId)
      .collection('academicYears')
      .doc(newAcademicYear);
    
    const academicYearData = {
      schoolId,
      academicYear: newAcademicYear,
      startDate: getAcademicYearStart(newAcademicYear),
      endDate: getAcademicYearEnd(newAcademicYear),
      isActive: true,
      resetCompleted: true,
      resetDate: admin.firestore.FieldValue.serverTimestamp(),
      totalStaffProcessed: staffSnapshot.size,
      totalBalancesCreated: balancesCreated,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      createdBy: 'system_academic_year_reset',
      metadata: {
        resetJobId: `academic_reset_${Date.now()}`,
        previousAcademicYear,
        processingStartTime: admin.firestore.FieldValue.serverTimestamp()
      }
    };
    
    batch.set(academicYearRef, academicYearData);
    
    // Commit all changes
    await batch.commit();
    
    console.log(`School ${schoolId} reset completed: ${balancesCreated} balances, ${mutationsCreated} mutations`);
    
  } catch (error) {
    console.error(`Error processing school ${schoolId}:`, error);
    throw error;
  }
}

/**
 * Cloud Function: Update leave balance when leave request status changes
 * Triggered by: Document updates in /schools/{schoolId}/leaves/{leaveId}
 */
exports.updateLeaveBalanceOnStatusChange = functions.firestore
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
    } catch (error) {
      console.error('Error updating leave balance:', error);
      throw new functions.https.HttpsError('internal', 'Failed to update leave balance');
    }
  });

/**
 * Process leave status change and update balances accordingly
 */
async function processLeaveStatusChange(schoolId, leaveId, beforeData, afterData) {
  const { staffId, userId, leaveTypeId, academicYear, totalDays } = afterData;
  const previousStatus = beforeData.status;
  const newStatus = afterData.status;
  
  // Get current balance
  const balanceId = `${staffId}_${leaveTypeId}_${academicYear}`;
  const balanceRef = db
    .collection('schools')
    .doc(schoolId)
    .collection('leaveBalances')
    .doc(balanceId);
  
  const balanceDoc = await balanceRef.get();
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
    
  } else if (previousStatus === 'PENDING' && (newStatus === 'REJECTED' || newStatus === 'CANCELLED')) {
    // Remove from pending
    newPending = Math.max(0, newPending - totalDays);
    mutationType = 'PENDING_REMOVED';
    reason = `Leave ${newStatus.toLowerCase()}: ${totalDays} days released from pending`;
    
  } else if (previousStatus === 'APPROVED' && newStatus === 'CANCELLED') {
    // Return used days (rare case, but possible)
    newUsed = Math.max(0, newUsed - totalDays);
    mutationType = 'ADJUSTMENT';
    reason = `Leave cancelled: ${totalDays} days returned to balance`;
    
  } else {
    // No balance change needed for other transitions
    return;
  }
  
  // Calculate new available balance
  const newAvailable = currentBalance.totalAllowed + currentBalance.carriedForward - newUsed - newPending;
  
  // Validate balance doesn't go negative
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
  
  // Create mutation record
  const mutationRef = db
    .collection('schools')
    .doc(schoolId)
    .collection('balanceMutations')
    .doc();
  
  const mutationData = {
    schoolId,
    staffId,
    userId,
    leaveTypeId,
    academicYear,
    mutationType,
    previousValue: mutationType === 'USED' ? currentBalance.used : currentBalance.pending,
    newValue: mutationType === 'USED' ? newUsed : newPending,
    delta: mutationType === 'USED' ? totalDays : -totalDays,
    referenceId: leaveId,
    reason,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    createdBy: afterData.updatedBy || 'system',
    metadata: {
      leaveRequestDates: afterData.dates,
      previousStatus,
      newStatus,
      totalDays,
      functionName: 'updateLeaveBalanceOnStatusChange'
    }
  };
  
  // Execute updates in batch
  const batch = db.batch();
  batch.update(balanceRef, updatedBalance);
  batch.set(mutationRef, mutationData);
  
  await batch.commit();
  
  console.log(`Balance updated for ${staffId}: ${mutationType} ${totalDays} days. New available: ${newAvailable}`);
}

/**
 * Utility Functions
 */

function getCurrentAcademicYear() {
  const now = new Date();
  const currentYear = now.getFullYear();
  
  // Academic year starts June 1
  if (now.getMonth() < 5) { // Before June (0-indexed)
    return `${currentYear - 1}-${currentYear.toString().substring(2)}`;
  } else {
    return `${currentYear}-${(currentYear + 1).toString().substring(2)}`;
  }
}

function getPreviousAcademicYear(currentYear) {
  const startYear = parseInt(currentYear.split('-')[0]);
  const prevStartYear = startYear - 1;
  return `${prevStartYear}-${(prevStartYear + 1).toString().substring(2)}`;
}

function getAcademicYearStart(academicYear) {
  const startYear = parseInt(academicYear.split('-')[0]);
  return admin.firestore.Timestamp.fromDate(new Date(startYear, 5, 1)); // June 1
}

function getAcademicYearEnd(academicYear) {
  const startYear = parseInt(academicYear.split('-')[0]);
  return admin.firestore.Timestamp.fromDate(new Date(startYear + 1, 4, 31)); // May 31 next year
}
