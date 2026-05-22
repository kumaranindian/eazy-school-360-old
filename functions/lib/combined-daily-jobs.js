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
 * Schedule: 11:59 PM IST to capture all RFID attendance for the day
 * This reduces Cloud Scheduler costs from ~$9/month to ~$2.70/month
 */
exports.runDailyJobs = functions
    .region('asia-south1')
    .pubsub.schedule('59 23 * * *') // Run at 11:59 PM IST daily
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
        }
        catch (error) {
            console.error('[Combined Daily Jobs] ❌ Fee due reminders failed:', error);
            results.feeDueReminders.error = error.message;
        }
        // 2. Run Daily Collection Summary
        console.log('[Combined Daily Jobs] Running daily collection summary...');
        try {
            await runDailyCollectionSummary();
            results.dailyCollectionSummary.success = true;
            console.log('[Combined Daily Jobs] ✅ Daily collection summary completed');
        }
        catch (error) {
            console.error('[Combined Daily Jobs] ❌ Daily collection summary failed:', error);
            results.dailyCollectionSummary.error = error.message;
        }
        // 3. Run Daily Attendance Finalizer
        console.log('[Combined Daily Jobs] Running daily attendance finalizer...');
        try {
            await runDailyAttendanceFinalizer();
            results.dailyAttendanceFinalizer.success = true;
            console.log('[Combined Daily Jobs] ✅ Daily attendance finalizer completed');
        }
        catch (error) {
            console.error('[Combined Daily Jobs] ❌ Daily attendance finalizer failed:', error);
            results.dailyAttendanceFinalizer.error = error.message;
        }
        const duration = Date.now() - startTime;
        console.log(`[Combined Daily Jobs] All jobs completed in ${duration}ms`);
        console.log('[Combined Daily Jobs] Results:', JSON.stringify(results, null, 2));
    }
    catch (error) {
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
                if (term.balanceAmount <= 0)
                    continue;
                const dueDate = term.dueDate.toDate();
                const daysUntilDue = Math.ceil((dueDate - today) / (1000 * 60 * 60 * 24));
                // Send reminder if due today, due in 3 days, or overdue (every 7 days)
                let shouldSend = false;
                let reminderType = '';
                if (daysUntilDue === 0) {
                    shouldSend = true;
                    reminderType = 'due_today';
                }
                else if (daysUntilDue === 3) {
                    shouldSend = true;
                    reminderType = 'advance_3_days';
                }
                else if (daysUntilDue < 0 && daysUntilDue % 7 === 0) {
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
        }
        catch (error) {
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
    console.log(`[Attendance Finalizer] Processing school ${schoolId} for ${dateStr}`);
    // Get attendance config
    const config = await getAttendanceConfig(schoolId);
    // Check if today is a working day
    const dayName = getDayName(date.getDay());
    if (!config.workingDays.includes(dayName)) {
        console.log(`[Attendance Finalizer] ${dateStr} is not a working day (${dayName})`);
        return;
    }
    // Get all RFID attendance records for the day
    const startOfDay = new Date(date);
    startOfDay.setHours(0, 0, 0, 0);
    const endOfDay = new Date(date);
    endOfDay.setHours(23, 59, 59, 999);
    const attendanceSnapshot = await db
        .collection('schools')
        .doc(schoolId)
        .collection('rfid_attendance')
        .where('scannedAt', '>=', admin.firestore.Timestamp.fromDate(startOfDay))
        .where('scannedAt', '<=', admin.firestore.Timestamp.fromDate(endOfDay))
        .get();
    console.log(`[Attendance Finalizer] Found ${attendanceSnapshot.size} RFID scans for ${dateStr}`);
    // Group attendance by staff/student
    const attendanceByUser = {};
    attendanceSnapshot.docs.forEach(doc => {
        const data = doc.data();
        const userId = data.staffId || data.studentId;
        const userType = data.staffId ? 'staff' : 'student';
        if (!attendanceByUser[userId]) {
            attendanceByUser[userId] = {
                userId,
                userType,
                scans: [],
                firstScan: null,
                lastScan: null
            };
        }
        const scanTime = data.scannedAt.toDate();
        attendanceByUser[userId].scans.push({
            time: scanTime,
            rfidTag: data.rfidTag
        });
        if (!attendanceByUser[userId].firstScan || scanTime < attendanceByUser[userId].firstScan) {
            attendanceByUser[userId].firstScan = scanTime;
        }
        if (!attendanceByUser[userId].lastScan || scanTime > attendanceByUser[userId].lastScan) {
            attendanceByUser[userId].lastScan = scanTime;
        }
    });
    // Get all active staff members
    const staffSnapshot = await db
        .collection('schools')
        .doc(schoolId)
        .collection('staff')
        .where('status', '==', 'ACTIVE')
        .get();
    console.log(`[Attendance Finalizer] Processing ${staffSnapshot.size} active staff members`);
    // Process each staff member
    for (const staffDoc of staffSnapshot.docs) {
        const staffId = staffDoc.id;
        const staffData = staffDoc.data();
        try {
            await processStaffAttendance(schoolId, staffId, staffData, date, attendanceByUser[staffId], config);
        }
        catch (error) {
            console.error(`[Attendance Finalizer] Error processing staff ${staffId}:`, error);
        }
    }
    console.log(`[Attendance Finalizer] Completed for school ${schoolId} on ${dateStr}`);
}
/**
 * Process attendance for a single staff member
 */
async function processStaffAttendance(schoolId, staffId, staffData, date, attendanceData, config) {
    const dateStr = date.toISOString().split('T')[0];
    const attendanceRef = db
        .collection('schools')
        .doc(schoolId)
        .collection('staff')
        .doc(staffId)
        .collection('attendance')
        .doc(dateStr);
    // Check if attendance already finalized
    const existingDoc = await attendanceRef.get();
    if (existingDoc.exists && existingDoc.data().finalized) {
        console.log(`[Attendance Finalizer] Attendance already finalized for staff ${staffId} on ${dateStr}`);
        return;
    }
    // Check for approved leaves
    const leaveSnapshot = await db
        .collection('schools')
        .doc(schoolId)
        .collection('leaves')
        .where('staffId', '==', staffId)
        .where('status', '==', 'APPROVED')
        .where('startDate', '<=', dateStr)
        .where('endDate', '>=', dateStr)
        .limit(1)
        .get();
    if (!leaveSnapshot.empty) {
        const leaveData = leaveSnapshot.docs[0].data();
        await attendanceRef.set({
            date: dateStr,
            staffId,
            staffName: staffData.name,
            status: 'LEAVE',
            leaveType: leaveData.leaveType,
            leaveId: leaveSnapshot.docs[0].id,
            finalized: true,
            finalizedAt: admin.firestore.FieldValue.serverTimestamp()
        }, { merge: true });
        console.log(`[Attendance Finalizer] Staff ${staffId} on leave (${leaveData.leaveType})`);
        return;
    }
    // Check for approved permissions
    const permissionSnapshot = await db
        .collection('schools')
        .doc(schoolId)
        .collection('permissions')
        .where('staffId', '==', staffId)
        .where('status', '==', 'APPROVED')
        .where('date', '==', dateStr)
        .limit(1)
        .get();
    // If RFID attendance exists
    if (attendanceData && attendanceData.firstScan) {
        const status = permissionSnapshot.empty ? 'PRESENT' : 'PERMISSION';
        await attendanceRef.set({
            date: dateStr,
            staffId,
            staffName: staffData.name,
            status,
            checkIn: admin.firestore.Timestamp.fromDate(attendanceData.firstScan),
            checkOut: admin.firestore.Timestamp.fromDate(attendanceData.lastScan),
            totalScans: attendanceData.scans.length,
            permissionId: permissionSnapshot.empty ? null : permissionSnapshot.docs[0].id,
            finalized: true,
            finalizedAt: admin.firestore.FieldValue.serverTimestamp()
        }, { merge: true });
        console.log(`[Attendance Finalizer] Staff ${staffId} marked ${status}`);
    }
    else {
        // No RFID scan - mark as LOP (Loss of Pay) if no permission
        const status = permissionSnapshot.empty ? 'LOP' : 'PERMISSION';
        await attendanceRef.set({
            date: dateStr,
            staffId,
            staffName: staffData.name,
            status,
            permissionId: permissionSnapshot.empty ? null : permissionSnapshot.docs[0].id,
            autoMarked: true, // Flag to indicate this was auto-marked
            finalized: true,
            finalizedAt: admin.firestore.FieldValue.serverTimestamp()
        }, { merge: true });
        console.log(`[Attendance Finalizer] Staff ${staffId} marked ${status} (no RFID scan - auto-marked)`);
    }
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
//# sourceMappingURL=combined-daily-jobs.js.map