/**
 * Weekly Due Date Notification Scheduler
 *
 * Runs weekly on Thursday at 01:45 AM IST
 * For each class, sends due date notifications to parents/students
 * for fees due within the next 30 days
 *
 * Uses phone number from student info (students collection), not ledger
 */
const functions = require('firebase-functions');
const admin = require('firebase-admin');
// Initialize Firebase Admin if not already initialized
if (!admin.apps.length) {
    admin.initializeApp();
}
const db = admin.firestore();
const axios = require('axios');
/**
 * Scheduled Cloud Function: Weekly Due Date Notification
 * Runs every Thursday at 2:00 AM IST
 */
exports.sendWeeklyDueNotifications = functions
    .region('asia-south1')
    .pubsub.schedule('0 2 * * 4')
    .timeZone('Asia/Kolkata')
    .onRun(async (context) => {
    console.log('[Weekly Due Notification] Starting weekly due date notification job');
    try {
        const schools = await db.collection('schools').get();
        let totalNotifications = 0;
        let totalStudentsProcessed = 0;
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
                console.log(`[Weekly Due Notification] Skipping school ${schoolId} - WhatsApp not enabled`);
                continue;
            }
            const config = whatsappConfig.data();
            // Get all unique classes for this school
            const classesSnapshot = await db
                .collection('schools')
                .doc(schoolId)
                .collection('students')
                .select('className')
                .get();
            const uniqueClasses = new Set();
            classesSnapshot.docs.forEach(doc => {
                const className = doc.data().className;
                if (className) {
                    uniqueClasses.add(className);
                }
            });
            console.log(`[Weekly Due Notification] Processing ${uniqueClasses.size} classes for school ${schoolId}`);
            // Calculate date range (next 30 days)
            const today = new Date();
            today.setHours(0, 0, 0, 0);
            const thirtyDaysLater = new Date(today);
            thirtyDaysLater.setDate(thirtyDaysLater.getDate() + 30);
            thirtyDaysLater.setHours(23, 59, 59, 999);
            // Process each class
            for (const className of uniqueClasses) {
                console.log(`[Weekly Due Notification] Processing class: ${className}`);
                // Get students in this class
                const studentsSnapshot = await db
                    .collection('schools')
                    .doc(schoolId)
                    .collection('students')
                    .where('className', '==', className)
                    .where('status', '==', 'ACTIVE')
                    .get();
                if (studentsSnapshot.empty) {
                    console.log(`[Weekly Due Notification] No active students in class ${className}`);
                    continue;
                }
                // Process each student in the class
                for (const studentDoc of studentsSnapshot.docs) {
                    const student = studentDoc.data();
                    const studentId = student.studentId || studentDoc.id;
                    // Get student's fee ledger
                    const ledgerSnapshot = await db
                        .collection('schools')
                        .doc(schoolId)
                        .collection('studentFeeLedgers')
                        .where('studentId', '==', parseInt(studentId))
                        .limit(1)
                        .get();
                    if (ledgerSnapshot.empty) {
                        console.log(`[Weekly Due Notification] No fee ledger found for student ${studentId}`);
                        continue;
                    }
                    const ledger = ledgerSnapshot.docs[0].data();
                    totalStudentsProcessed++;
                    // Check for due dates within next 30 days
                    const upcomingDues = [];
                    // Check term fees
                    if (ledger.termStatus && Array.isArray(ledger.termStatus)) {
                        for (const term of ledger.termStatus) {
                            if (term.balanceAmount > 0 && term.dueDate) {
                                const dueDate = term.dueDate.toDate();
                                dueDate.setHours(0, 0, 0, 0);
                                if (dueDate >= today && dueDate <= thirtyDaysLater) {
                                    upcomingDues.push({
                                        type: 'term',
                                        name: term.termName,
                                        amount: term.balanceAmount,
                                        dueDate: dueDate
                                    });
                                }
                            }
                        }
                    }
                    // Check ad-hoc fees
                    if (ledger.feeItems && Array.isArray(ledger.feeItems)) {
                        for (const fee of ledger.feeItems) {
                            if (fee.balanceAmount > 0 && fee.dueDate) {
                                const dueDate = fee.dueDate.toDate();
                                dueDate.setHours(0, 0, 0, 0);
                                if (dueDate >= today && dueDate <= thirtyDaysLater) {
                                    upcomingDues.push({
                                        type: 'adhoc',
                                        name: fee.itemName || fee.name,
                                        amount: fee.balanceAmount,
                                        dueDate: dueDate
                                    });
                                }
                            }
                        }
                    }
                    // If student has upcoming dues, send notification
                    if (upcomingDues.length > 0) {
                        // Get phone number from student info (not ledger)
                        const phoneNumber = student.phoneNumber || student.parentPhone;
                        if (!phoneNumber || phoneNumber === 'NA' || phoneNumber === '') {
                            console.log(`[Weekly Due Notification] No valid phone number for student ${student.studentName}`);
                            continue;
                        }
                        // Sort dues by due date
                        upcomingDues.sort((a, b) => a.dueDate - b.dueDate);
                        // Send WhatsApp notification
                        const sent = await sendWeeklyDueReminder({
                            config,
                            phoneNumber,
                            studentName: student.studentName || student.name,
                            className: className,
                            upcomingDues: upcomingDues.slice(0, 3), // Limit to top 3 upcoming dues
                        });
                        if (sent) {
                            totalNotifications++;
                            // Log the notification
                            await db
                                .collection('schools')
                                .doc(schoolId)
                                .collection('communicationLogs')
                                .add({
                                channel: 'whatsapp',
                                status: 'sent',
                                purpose: 'feeReminder',
                                recipientType: 'parent',
                                recipientId: phoneNumber,
                                recipientName: student.studentName || student.name,
                                subject: 'Weekly Fee Due Reminder',
                                message: `Upcoming dues for ${student.studentName || student.name} (${className}): ${upcomingDues.map(d => `${d.name} - ₹${d.amount} due on ${d.dueDate.toLocaleDateString()}`).join(', ')}`,
                                sentAt: admin.firestore.FieldValue.serverTimestamp(),
                                sentByUserId: 'system',
                                sentByUserName: 'Weekly Scheduler',
                                metadata: {
                                    className: className,
                                    studentId: studentId,
                                    duesCount: upcomingDues.length,
                                    dues: upcomingDues.map(d => ({
                                        name: d.name,
                                        amount: d.amount,
                                        dueDate: admin.firestore.Timestamp.fromDate(d.dueDate)
                                    }))
                                }
                            });
                            console.log(`[Weekly Due Notification] Sent notification to ${phoneNumber} for ${student.studentName} (${className})`);
                        }
                        // Rate limiting: wait 100ms between messages
                        await new Promise(resolve => setTimeout(resolve, 100));
                    }
                }
            }
        }
        console.log(`[Weekly Due Notification] Completed. Processed ${totalStudentsProcessed} students, sent ${totalNotifications} notifications`);
        return null;
    }
    catch (error) {
        console.error('[Weekly Due Notification] Error:', error);
        throw error;
    }
});
/**
 * Helper function to send weekly due reminder via WhatsApp
 */
async function sendWeeklyDueReminder({ config, phoneNumber, studentName, className, upcomingDues }) {
    var _a;
    try {
        const formattedPhone = formatPhoneNumber(phoneNumber);
        // Build message with upcoming dues
        const duesList = upcomingDues.map((due, index) => {
            const dueDateStr = `${due.dueDate.getDate()}/${due.dueDate.getMonth() + 1}/${due.dueDate.getFullYear()}`;
            return `${index + 1}. ${due.name}: ₹${due.amount.toFixed(0)} due on ${dueDateStr}`;
        }).join('\n');
        const messageBody = `Dear Parent,\n\nYour child ${studentName} (${className}) has the following upcoming fee dues:\n\n${duesList}\n\nPlease ensure timely payment to avoid late fees.\n\nThank you,\nSchool Administration`;
        // Try to use a template first, fallback to text message
        let response;
        try {
            response = await axios.post(`https://graph.facebook.com/v19.0/${config.phoneNumberId}/messages`, {
                messaging_product: 'whatsapp',
                to: formattedPhone,
                type: 'template',
                template: {
                    name: config.weeklyDueTemplate || 'weekly_due_reminder',
                    language: { code: 'en' },
                    components: [
                        {
                            type: 'body',
                            parameters: [
                                { type: 'text', text: studentName },
                                { type: 'text', text: className },
                                { type: 'text', text: upcomingDues.length.toString() },
                                { type: 'text', text: duesList },
                            ]
                        }
                    ]
                }
            }, {
                headers: {
                    'Authorization': `Bearer ${config.accessToken}`,
                    'Content-Type': 'application/json',
                },
                timeout: 30000,
            });
        }
        catch (templateError) {
            // If template fails, try sending as text message
            console.log('[Weekly Due Notification] Template not available, sending as text message');
            response = await axios.post(`https://graph.facebook.com/v19.0/${config.phoneNumberId}/messages`, {
                messaging_product: 'whatsapp',
                to: formattedPhone,
                type: 'text',
                text: {
                    body: messageBody
                }
            }, {
                headers: {
                    'Authorization': `Bearer ${config.accessToken}`,
                    'Content-Type': 'application/json',
                },
                timeout: 30000,
            });
        }
        console.log(`[Weekly Due Notification] WhatsApp response: ${response.status}`);
        return response.status === 200;
    }
    catch (error) {
        console.error('[Weekly Due Notification] Error sending reminder:', ((_a = error.response) === null || _a === void 0 ? void 0 : _a.data) || error.message);
        return false;
    }
}
/**
 * Format phone number to E.164 format
 */
function formatPhoneNumber(phone) {
    let cleaned = phone.replace(/[^\d+]/g, '');
    if (cleaned.startsWith('+')) {
        return cleaned;
    }
    if (cleaned.startsWith('91') && cleaned.length === 12) {
        return `+${cleaned}`;
    }
    if (cleaned.length === 10) {
        return `+91${cleaned}`;
    }
    return cleaned;
}
//# sourceMappingURL=weekly-due-notification.js.map