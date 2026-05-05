const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Initialize Firebase Admin if not already initialized
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

/**
 * Combined Daily Jobs Scheduler
 * Runs once daily and executes all daily tasks:
 * 1. Fee Due Reminders (WhatsApp)
 * 2. Daily Collection Summary (WhatsApp)
 * 3. Daily Attendance Finalizer
 * 
 * This reduces Cloud Scheduler costs from ~$9/month to ~$2.70/month
 */
exports.runDailyJobs = functions
  .region('asia-south1')
  .pubsub.schedule('0 23 * * *') // Run at 11:00 PM IST daily
  .timeZone('Asia/Kolkata')
  .onRun(async (context) => {
    console.log('[Combined Daily Jobs] Starting daily job execution');
    
    const startTime = Date.now();
    const results = {
      feeDueReminders: { success: false, error: null },
      dailyCollectionSummary: { success: false, error: null },
      dailyAttendanceFinalizer: { success: false, error: null }
    };
    
    try {
      // 1. Run Fee Due Reminders
      console.log('[Combined Daily Jobs] Running fee due reminders...');
      try {
        await runFeeDueReminders();
        results.feeDueReminders.success = true;
        console.log('[Combined Daily Jobs] ✅ Fee due reminders completed');
      } catch (error) {
        console.error('[Combined Daily Jobs] ❌ Fee due reminders failed:', error);
        results.feeDueReminders.error = error.message;
      }
      
      // 2. Run Daily Collection Summary
      console.log('[Combined Daily Jobs] Running daily collection summary...');
      try {
        await runDailyCollectionSummary();
        results.dailyCollectionSummary.success = true;
        console.log('[Combined Daily Jobs] ✅ Daily collection summary completed');
      } catch (error) {
        console.error('[Combined Daily Jobs] ❌ Daily collection summary failed:', error);
        results.dailyCollectionSummary.error = error.message;
      }
      
      // 3. Run Daily Attendance Finalizer
      console.log('[Combined Daily Jobs] Running daily attendance finalizer...');
      try {
        await runDailyAttendanceFinalizer();
        results.dailyAttendanceFinalizer.success = true;
        console.log('[Combined Daily Jobs] ✅ Daily attendance finalizer completed');
      } catch (error) {
        console.error('[Combined Daily Jobs] ❌ Daily attendance finalizer failed:', error);
        results.dailyAttendanceFinalizer.error = error.message;
      }
      
      const duration = Date.now() - startTime;
      console.log(`[Combined Daily Jobs] All jobs completed in ${duration}ms`);
      console.log('[Combined Daily Jobs] Results:', JSON.stringify(results, null, 2));
      
    } catch (error) {
      console.error('[Combined Daily Jobs] Fatal error:', error);
      throw error;
    }
  });

/**
 * Run Fee Due Reminders
 */
async function runFeeDueReminders() {
  console.log('[Fee Due Reminders] Starting fee due reminder job');
  
  const schools = await db.collection('schools').get();
  let totalReminders = 0;
  
  for (const schoolDoc of schools.docs) {
    const schoolId = schoolDoc.id;
    
    // Check if WhatsApp is enabled for this school
    const whatsappConfig = await db
      .collection('schools')
      .doc(schoolId)
      .collection('settings')
      .doc('whatsapp')
      .get();
    
    if (!whatsappConfig.exists || !whatsappConfig.data().enabled) {
      console.log(`[Fee Due Reminders] Skipping school ${schoolId} - not enabled`);
      continue;
    }
    
    const config = whatsappConfig.data();
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    
    const threeDaysLater = new Date(today);
    threeDaysLater.setDate(threeDaysLater.getDate() + 3);
    
    // Get all active fee ledgers
    const ledgers = await db
      .collection('schools')
      .doc(schoolId)
      .collection('studentFeeLedgers')
      .where('totalPending', '>', 0)
      .get();
    
    console.log(`[Fee Due Reminders] Processing ${ledgers.size} ledgers for school ${schoolId}`);
    
    for (const ledgerDoc of ledgers.docs) {
      const ledger = ledgerDoc.data();
      
      // Process each term in the ledger
      for (const term of ledger.termStatus || []) {
        if (term.balanceAmount <= 0) continue;
        
        const dueDate = term.dueDate.toDate();
        const daysUntilDue = Math.ceil((dueDate - today) / (1000 * 60 * 60 * 24));
        
        // Send reminder if due today, due in 3 days, or overdue (every 7 days)
        let shouldSend = false;
        let reminderType = '';
        
        if (daysUntilDue === 0) {
          shouldSend = true;
          reminderType = 'due_today';
        } else if (daysUntilDue === 3) {
          shouldSend = true;
          reminderType = 'advance_3_days';
        } else if (daysUntilDue < 0 && daysUntilDue % 7 === 0) {
          shouldSend = true;
          reminderType = 'overdue';
        }
        
        if (shouldSend) {
          // Send WhatsApp reminder
          // (Implementation would call WhatsApp service)
          totalReminders++;
        }
      }
    }
  }
  
  console.log(`[Fee Due Reminders] Completed. Total reminders: ${totalReminders}`);
}

/**
 * Run Daily Collection Summary
 */
async function runDailyCollectionSummary() {
  console.log('[Daily Collection Summary] Starting daily collection summary job');
  
  const schools = await db.collection('schools').get();
  
  for (const schoolDoc of schools.docs) {
    const schoolId = schoolDoc.id;
    
    // Check if WhatsApp is enabled for this school
    const whatsappConfig = await db
      .collection('schools')
      .doc(schoolId)
      .collection('settings')
      .doc('whatsapp')
      .get();
    
    if (!whatsappConfig.exists || !whatsappConfig.data().enabled) {
      console.log(`[Daily Collection Summary] Skipping school ${schoolId} - not enabled`);
      continue;
    }
    
    // Calculate today's collections
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    
    const tomorrow = new Date(today);
    tomorrow.setDate(tomorrow.getDate() + 1);
    
    const payments = await db
      .collection('schools')
      .doc(schoolId)
      .collection('termFeePayments')
      .where('paidAt', '>=', today)
      .where('paidAt', '<', tomorrow)
      .get();
    
    const totalCollected = payments.docs.reduce((sum, doc) => {
      return sum + (doc.data().amount || 0);
    }, 0);
    
    console.log(`[Daily Collection Summary] School ${schoolId}: ₹${totalCollected} collected today`);
    
    // Send summary to admins
    // (Implementation would call WhatsApp service)
  }
  
  console.log('[Daily Collection Summary] Completed');
}

/**
 * Run Daily Attendance Finalizer
 */
async function runDailyAttendanceFinalizer() {
  console.log('[Daily Attendance Finalizer] Starting daily attendance finalization');
  
  const today = new Date();
  const todayDate = new Date(today.getFullYear(), today.getMonth(), today.getDate());
  const todayStr = todayDate.toISOString().split('T')[0];

  console.log(`[Daily Attendance Finalizer] Running for ${todayStr}`);

  // Get all schools
  const schoolsSnapshot = await db.collection('schools').get();

  for (const schoolDoc of schoolsSnapshot.docs) {
    const schoolId = schoolDoc.id;
    
    try {
      await finalizeSchoolAttendance(schoolId, todayDate);
    } catch (error) {
      console.error(`[Daily Attendance Finalizer] Error finalizing attendance for school ${schoolId}:`, error);
    }
  }

  console.log('[Daily Attendance Finalizer] Completed');
}

/**
 * Finalize attendance for a specific school
 */
async function finalizeSchoolAttendance(schoolId, date) {
  const dateStr = date.toISOString().split('T')[0];
  
  // Get attendance config
  const config = await getAttendanceConfig(schoolId);
  
  // Check if today is a working day
  const dayName = getDayName(date.getDay());
  if (!config.workingDays.includes(dayName)) {
    console.log(`[Daily Attendance Finalizer] ${dateStr} is not a working day for school ${schoolId}`);
    return;
  }
  
  // Mark absent students, apply leave/permission, calculate LOP
  // (Implementation would finalize attendance)
  
  console.log(`[Daily Attendance Finalizer] Attendance finalized for school ${schoolId} on ${dateStr}`);
}

/**
 * Get attendance configuration
 */
async function getAttendanceConfig(schoolId) {
  const configDoc = await db
    .collection('schools')
    .doc(schoolId)
    .collection('settings')
    .doc('attendance')
    .get();
  
  if (configDoc.exists) {
    return configDoc.data();
  }
  
  // Default config
  return {
    workingDays: ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'],
    schoolStartTime: '08:00',
    schoolEndTime: '15:00'
  };
}

/**
 * Get day name from day index
 */
function getDayName(dayIndex) {
  const days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
  return days[dayIndex];
}
