/**
 * Cloud Functions for WhatsApp Fee Reminders
 *
 * Scheduled functions that run daily to:
 * 1. Send fee due reminders to parents
 * 2. Send daily collection summary to admins
 *
 * Production-ready with error handling, logging, and rate limiting
 */
const functions = require('firebase-functions');
const admin = require('firebase-admin');
const axios = require('axios');
// Initialize Firestore
const db = admin.firestore();
/**
 * Test WhatsApp configuration by sending a test message
 * HTTP callable function to test configuration from the Flutter app
 * This avoids CORS issues in web browsers
 */
exports.testWhatsAppConfiguration = functions.https.onCall(async (data, context) => {
    var _a, _b;
    // Check if user is authenticated
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }
    const { schoolId, testPhone } = data;
    if (!schoolId || !testPhone) {
        throw new functions.https.HttpsError('invalid-argument', 'schoolId and testPhone are required');
    }
    try {
        console.log('[WhatsApp Test] Starting test for school:', schoolId);
        // Get WhatsApp config
        const whatsappConfig = await db
            .collection('schools')
            .doc(schoolId)
            .collection('settings')
            .doc('whatsapp')
            .get();
        if (!whatsappConfig.exists || !whatsappConfig.data().enabled) {
            throw new functions.https.HttpsError('failed-precondition', 'WhatsApp not configured or disabled');
        }
        const { accessToken, phoneNumberId } = whatsappConfig.data();
        if (!accessToken || !phoneNumberId) {
            throw new functions.https.HttpsError('failed-precondition', 'Missing access token or phone number ID');
        }
        // Format phone number
        let formattedPhone = testPhone.replace(/[^0-9+]/g, '');
        if (formattedPhone.startsWith('+')) {
            formattedPhone = formattedPhone.substring(1);
        }
        if (formattedPhone.length === 10 && !formattedPhone.startsWith('0')) {
            formattedPhone = '91' + formattedPhone;
        }
        console.log('[WhatsApp Test] Phone Number ID:', phoneNumberId);
        console.log('[WhatsApp Test] Test Phone:', formattedPhone);
        // Send test message using hello_world template
        const response = await axios.post(`https://graph.facebook.com/v18.0/${phoneNumberId}/messages`, {
            messaging_product: 'whatsapp',
            to: formattedPhone,
            type: 'template',
            template: {
                name: 'hello_world',
                language: { code: 'en_US' },
            },
        }, {
            headers: {
                Authorization: `Bearer ${accessToken}`,
                'Content-Type': 'application/json',
            },
            timeout: 30000,
        });
        console.log('[WhatsApp Test] Response status:', response.status);
        console.log('[WhatsApp Test] Response data:', response.data);
        return {
            success: true,
            message: 'Test message sent successfully',
            statusCode: response.status,
            data: response.data,
        };
    }
    catch (error) {
        console.error('[WhatsApp Test] Error:', error.message);
        console.error('[WhatsApp Test] Response:', (_a = error.response) === null || _a === void 0 ? void 0 : _a.data);
        throw new functions.https.HttpsError('internal', `Test failed: ${error.message}`, (_b = error.response) === null || _b === void 0 ? void 0 : _b.data);
    }
});
/**
 * Callable Cloud Function: Send Fee Due Notification via WhatsApp
 * Called from Flutter app to send fee due reminders on demand
 * Uses same pattern as sendPaymentNotification (which works)
 */
exports.sendFeeDueNotification = functions.https.onCall(async (data, context) => {
    var _a, _b, _c, _d;
    console.log('========================================');
    console.log('[WhatsApp Due Notification] *** FUNCTION STARTED ***');
    console.log('[WhatsApp Due Notification] Function called');
    console.log('[WhatsApp Due Notification] Data received:', JSON.stringify(data));
    console.log('[WhatsApp Due Notification] Context auth:', context.auth ? 'authenticated' : 'not authenticated');
    console.log('========================================');
    try {
        if (!context.auth) {
            console.log('[WhatsApp Due Notification] ERROR: User not authenticated');
            throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
        }
        const { schoolId, phoneNumber, studentName, pendingAmount, dueDate, schoolName, className } = data;
        console.log('[WhatsApp Due Notification] Extracted params:', { schoolId, phoneNumber, studentName, pendingAmount, dueDate, className });
        if (!schoolId || !phoneNumber) {
            console.log('[WhatsApp Due Notification] ERROR: Missing required params');
            throw new functions.https.HttpsError('invalid-argument', 'schoolId and phoneNumber are required');
        }
        console.log(`[WhatsApp Due Notification] Sending to ${phoneNumber} for ${studentName}, pending: ${pendingAmount}`);
        // Get WhatsApp config
        console.log('[WhatsApp Due Notification] Fetching WhatsApp config...');
        const whatsappConfig = await db
            .collection('schools')
            .doc(schoolId)
            .collection('settings')
            .doc('whatsapp')
            .get();
        console.log('[WhatsApp Due Notification] Config exists:', whatsappConfig.exists);
        if (!whatsappConfig.exists) {
            console.log(`[WhatsApp Due Notification] WhatsApp config not found for school ${schoolId}`);
            return { success: false, error: 'WhatsApp not configured for this school' };
        }
        const configData = whatsappConfig.data();
        console.log('[WhatsApp Due Notification] Config data:', JSON.stringify(configData));
        if (!configData.enabled) {
            console.log(`[WhatsApp Due Notification] WhatsApp disabled for school ${schoolId}`);
            return { success: false, error: 'WhatsApp is disabled for this school' };
        }
        const { accessToken, phoneNumberId, feeDueTemplate } = configData;
        console.log('[WhatsApp Due Notification] Has accessToken:', !!accessToken);
        console.log('[WhatsApp Due Notification] Has phoneNumberId:', !!phoneNumberId);
        if (!accessToken || !phoneNumberId) {
            console.log('[WhatsApp Due Notification] Missing credentials');
            return { success: false, error: 'Missing access token or phone number ID' };
        }
        // Format phone number
        let formattedPhone = phoneNumber.replace(/[^0-9+]/g, '');
        if (formattedPhone.startsWith('+')) {
            formattedPhone = formattedPhone.substring(1);
        }
        if (formattedPhone.length === 10 && !formattedPhone.startsWith('0')) {
            formattedPhone = '91' + formattedPhone;
        }
        console.log(`[WhatsApp Due Notification] Phone: ${formattedPhone}, Template: ${feeDueTemplate || 'fee_due_reminder'}`);
        // Format due date
        console.log('[WhatsApp Due Notification] Formatting due date...');
        const dueDateObj = new Date(dueDate);
        const dueDateStr = `${dueDateObj.getDate()}/${dueDateObj.getMonth() + 1}/${dueDateObj.getFullYear()}`;
        console.log('[WhatsApp Due Notification] Due date formatted:', dueDateStr);
        // Build template parameters for fee due reminder
        const parameters = [
            { type: 'text', text: studentName || '' },
            { type: 'text', text: className || 'Class' },
            { type: 'text', text: `₹${parseFloat(pendingAmount || 0).toFixed(2)}` },
            { type: 'text', text: dueDateStr || 'N/A' },
        ];
        console.log('[WhatsApp Due Notification] Template parameters:', JSON.stringify(parameters));
        console.log('[WhatsApp Due Notification] Calling WhatsApp API...');
        const response = await axios.post(`https://graph.facebook.com/v19.0/${phoneNumberId}/messages`, {
            messaging_product: 'whatsapp',
            to: formattedPhone,
            type: 'template',
            template: {
                name: feeDueTemplate || 'fee_due_reminder',
                language: { code: 'en' },
                components: [
                    {
                        type: 'body',
                        parameters: parameters
                    }
                ]
            }
        }, {
            headers: {
                Authorization: `Bearer ${accessToken}`,
                'Content-Type': 'application/json',
            },
            timeout: 30000,
        });
        console.log(`[WhatsApp Due Notification] API Response: ${response.status}`, response.data);
        console.log('[WhatsApp Due Notification] WhatsApp message sent successfully');
        // Log notification to whatsappNotifications collection
        console.log('[WhatsApp Due Notification] Logging to whatsappNotifications...');
        await db
            .collection('schools')
            .doc(schoolId)
            .collection('whatsappNotifications')
            .add({
            type: 'fee_due_reminder',
            recipient: formattedPhone,
            studentName: studentName,
            metadata: { pendingAmount, dueDate, className },
            status: 'sent',
            sentAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        // Log notification to communicationLogs collection
        await db
            .collection('schools')
            .doc(schoolId)
            .collection('communicationLogs')
            .add({
            channel: 'whatsapp',
            status: 'sent',
            recipientType: 'parent',
            recipientId: formattedPhone,
            phoneNumber: formattedPhone,
            recipientName: studentName,
            subject: 'Fee Due Reminder',
            message: `Fee due reminder sent to ${studentName} for ${className}. Pending amount: ₹${parseFloat(pendingAmount || 0).toFixed(2)}. Due date: ${dueDateStr}`,
            sentAt: admin.firestore.FieldValue.serverTimestamp(),
            sentByUserId: context.auth.uid,
            sentByUserName: 'Admin',
            metadata: {
                pendingAmount,
                dueDate,
                className,
                schoolName
            }
        });
        console.log('[WhatsApp Due Notification] All logging complete');
        console.log('[WhatsApp Due Notification] Returning success response');
        return { success: true, message: 'Fee due notification sent successfully' };
    }
    catch (error) {
        console.error('[WhatsApp Due Notification] ===== ERROR CAUGHT =====');
        console.error('[WhatsApp Due Notification] Error type:', error.constructor.name);
        console.error('[WhatsApp Due Notification] Error message:', error.message);
        console.error('[WhatsApp Due Notification] Error stack:', error.stack);
        if (error.response) {
            console.error('[WhatsApp Due Notification] API Response status:', error.response.status);
            console.error('[WhatsApp Due Notification] API Response data:', error.response.data);
        }
        // Try to log failed notification (but don't fail if this fails)
        try {
            const { schoolId, phoneNumber, studentName, pendingAmount } = data;
            if (schoolId) {
                await db
                    .collection('schools')
                    .doc(schoolId)
                    .collection('whatsappNotifications')
                    .add({
                    type: 'fee_due_reminder',
                    recipient: phoneNumber,
                    studentName: studentName,
                    metadata: { error: error.message, responseData: JSON.stringify((_a = error.response) === null || _a === void 0 ? void 0 : _a.data) },
                    status: 'failed',
                    sentAt: admin.firestore.FieldValue.serverTimestamp(),
                });
                await db
                    .collection('schools')
                    .doc(schoolId)
                    .collection('communicationLogs')
                    .add({
                    channel: 'whatsapp',
                    status: 'failed',
                    recipientType: 'parent',
                    recipientId: phoneNumber,
                    phoneNumber: phoneNumber,
                    recipientName: studentName,
                    subject: 'Fee Due Reminder',
                    message: `Failed to send fee due reminder to ${studentName}. Pending amount: ₹${parseFloat(pendingAmount || 0).toFixed(2)}`,
                    sentAt: admin.firestore.FieldValue.serverTimestamp(),
                    sentByUserId: ((_b = context.auth) === null || _b === void 0 ? void 0 : _b.uid) || 'unknown',
                    sentByUserName: 'Admin',
                    errorMessage: error.message,
                    metadata: {
                        pendingAmount,
                        dueDate: data.dueDate,
                        className: data.className,
                        errorDetails: (_c = error.response) === null || _c === void 0 ? void 0 : _c.data
                    }
                });
            }
        }
        catch (logError) {
            console.error('[WhatsApp Due Notification] Failed to log error:', logError.message);
        }
        return {
            success: false,
            error: error.message || 'Unknown error occurred',
            details: (_d = error.response) === null || _d === void 0 ? void 0 : _d.data
        };
    }
});
/**
 * Simple test function to verify function is being called
 */
exports.simpleTest = functions.https.onCall(async (data, context) => {
    console.log('========================================');
    console.log('[Simple Test] *** FUNCTION STARTED ***');
    console.log('[Simple Test] Function called');
    console.log('[Simple Test] Data received:', JSON.stringify(data));
    console.log('[Simple Test] Context auth:', context.auth ? 'authenticated' : 'not authenticated');
    console.log('========================================');
    return {
        success: true,
        message: 'Simple test function executed successfully',
        receivedData: data
    };
});
/**
 * Callable Cloud Function: Send Payment Notification via WhatsApp
 * Called from Flutter app to avoid CORS issues when running on web
 */
exports.sendPaymentNotification = functions.https.onCall(async (data, context) => {
    var _a, _b, _c, _d;
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }
    const { schoolId, phoneNumber, studentName, paidAmount, receiptNumber, paymentDate, balanceAmount, schoolName, feeDescription, feeType, isAdmin } = data;
    if (!schoolId || !phoneNumber) {
        throw new functions.https.HttpsError('invalid-argument', 'schoolId and phoneNumber are required');
    }
    try {
        console.log(`[WhatsApp Payment] Sending notification to ${phoneNumber} for ${studentName}`);
        // Get WhatsApp config
        const whatsappConfig = await db
            .collection('schools')
            .doc(schoolId)
            .collection('settings')
            .doc('whatsapp')
            .get();
        if (!whatsappConfig.exists || !whatsappConfig.data().enabled) {
            return { success: false, error: 'WhatsApp not configured or disabled' };
        }
        const { accessToken, phoneNumberId, paymentConfirmationTemplate } = whatsappConfig.data();
        // Use same template for both parent and admin notifications
        const templateName = paymentConfirmationTemplate || 'payment_confirmation';
        if (!accessToken || !phoneNumberId) {
            return { success: false, error: 'Missing access token or phone number ID' };
        }
        // Format phone number
        let formattedPhone = phoneNumber.replace(/[^0-9+]/g, '');
        if (formattedPhone.startsWith('+')) {
            formattedPhone = formattedPhone.substring(1);
        }
        if (formattedPhone.length === 10 && !formattedPhone.startsWith('0')) {
            formattedPhone = '91' + formattedPhone;
        }
        console.log(`[WhatsApp Payment] Phone: ${formattedPhone}, Template: ${templateName}, PhoneNumberId: ${phoneNumberId}, IsAdmin: ${isAdmin}`);
        // Build template parameters based on notification type
        let parameters;
        if (isAdmin === true) {
            // Admin notification parameters: school, student, amount, receipt, date, feeDesc, feeType, balance
            parameters = [
                { type: 'text', text: schoolName || 'School' },
                { type: 'text', text: studentName || '' },
                { type: 'text', text: `₹${parseFloat(paidAmount || 0).toFixed(2)}` },
                { type: 'text', text: receiptNumber || '' },
                { type: 'text', text: paymentDate || '' },
                { type: 'text', text: feeDescription || 'Fee Payment' },
                { type: 'text', text: feeType || 'Term Fee' },
                { type: 'text', text: `₹${parseFloat(balanceAmount || 0).toFixed(2)}` },
            ];
        }
        else {
            // Student/Parent notification parameters: student, amount, receipt, date, balance
            parameters = [
                { type: 'text', text: studentName || '' },
                { type: 'text', text: `₹${parseFloat(paidAmount || 0).toFixed(2)}` },
                { type: 'text', text: receiptNumber || '' },
                { type: 'text', text: paymentDate || '' },
                { type: 'text', text: `₹${parseFloat(balanceAmount || 0).toFixed(2)}` },
            ];
        }
        const response = await axios.post(`https://graph.facebook.com/v19.0/${phoneNumberId}/messages`, {
            messaging_product: 'whatsapp',
            to: formattedPhone,
            type: 'template',
            template: {
                name: templateName,
                language: { code: 'en' },
                components: [
                    {
                        type: 'body',
                        parameters: parameters
                    }
                ]
            }
        }, {
            headers: {
                Authorization: `Bearer ${accessToken}`,
                'Content-Type': 'application/json',
            },
            timeout: 30000,
        });
        console.log(`[WhatsApp Payment] Response: ${response.status}`, response.data);
        // Log notification to whatsappNotifications collection
        await db
            .collection('schools')
            .doc(schoolId)
            .collection('whatsappNotifications')
            .add({
            type: 'payment_confirmation',
            recipient: formattedPhone,
            studentName: studentName,
            metadata: { paidAmount, receiptNumber, balanceAmount },
            status: 'sent',
            sentAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        // Log notification to communicationLogs collection
        await db
            .collection('schools')
            .doc(schoolId)
            .collection('communicationLogs')
            .add({
            channel: 'whatsapp',
            status: 'sent',
            recipientType: isAdmin === true ? 'admin' : 'parent',
            recipientId: formattedPhone,
            phoneNumber: formattedPhone,
            recipientName: isAdmin === true ? 'Admin' : studentName,
            subject: isAdmin === true ? 'Payment Received - Admin Notification' : 'Payment Confirmation',
            message: isAdmin === true
                ? `Payment of ₹${parseFloat(paidAmount || 0).toFixed(2)} received from ${studentName}. Receipt: ${receiptNumber}. Balance: ₹${parseFloat(balanceAmount || 0).toFixed(2)}`
                : `Payment of ₹${parseFloat(paidAmount || 0).toFixed(2)} received for ${studentName}. Receipt: ${receiptNumber}. Balance: ₹${parseFloat(balanceAmount || 0).toFixed(2)}`,
            sentAt: admin.firestore.FieldValue.serverTimestamp(),
            sentByUserId: 'system',
            sentByUserName: 'Payment System',
            metadata: {
                receiptNumber,
                paidAmount,
                balanceAmount,
                paymentDate,
                feeDescription,
                feeType,
                isAdmin
            }
        });
        return { success: true, message: 'Notification sent successfully' };
    }
    catch (error) {
        console.error('[WhatsApp Payment] Error:', error.message);
        console.error('[WhatsApp Payment] Response:', (_a = error.response) === null || _a === void 0 ? void 0 : _a.data);
        // Log failed notification to whatsappNotifications collection
        await db
            .collection('schools')
            .doc(schoolId)
            .collection('whatsappNotifications')
            .add({
            type: 'payment_confirmation',
            recipient: phoneNumber,
            studentName: studentName,
            metadata: { error: error.message, responseData: JSON.stringify((_b = error.response) === null || _b === void 0 ? void 0 : _b.data) },
            status: 'failed',
            sentAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        // Log failed notification to communicationLogs collection
        await db
            .collection('schools')
            .doc(schoolId)
            .collection('communicationLogs')
            .add({
            channel: 'whatsapp',
            status: 'failed',
            purpose: isAdmin === true ? 'adminNotification' : 'paymentConfirmation',
            recipientType: isAdmin === true ? 'admin' : 'parent',
            recipientId: phoneNumber,
            recipientName: isAdmin === true ? 'Admin' : studentName,
            subject: isAdmin === true ? 'Payment Received - Admin Notification' : 'Payment Confirmation',
            message: isAdmin === true
                ? `Payment of ₹${parseFloat(paidAmount || 0).toFixed(2)} received from ${studentName}. Receipt: ${receiptNumber}. Balance: ₹${parseFloat(balanceAmount || 0).toFixed(2)}`
                : `Payment of ₹${parseFloat(paidAmount || 0).toFixed(2)} received for ${studentName}. Receipt: ${receiptNumber}. Balance: ₹${parseFloat(balanceAmount || 0).toFixed(2)}`,
            sentAt: admin.firestore.FieldValue.serverTimestamp(),
            sentByUserId: 'system',
            sentByUserName: 'Payment System',
            errorMessage: error.message,
            metadata: {
                receiptNumber,
                paidAmount,
                balanceAmount,
                paymentDate,
                feeDescription,
                feeType,
                isAdmin,
                errorDetails: (_c = error.response) === null || _c === void 0 ? void 0 : _c.data
            }
        });
        return { success: false, error: error.message, details: (_d = error.response) === null || _d === void 0 ? void 0 : _d.data };
    }
});
/**
 * Cloud Function: Send Fee Due Reminders
 * Scheduled to run daily at 9:00 AM IST
 * Sends WhatsApp reminders for:
 * - Fees due today
 * - Fees due in 3 days (advance reminder)
 * - Overdue fees (sent every 7 days)
 * DISABLED - Now handled by combined-daily-jobs.js to reduce costs
 */
/*
exports.sendFeeDueReminders = functions
  .region('asia-south1')
  .pubsub.schedule('0 9 * * *')
  .timeZone('Asia/Kolkata')
  .onRun(async (context) => {
    console.log('[WhatsApp Reminders] Starting fee due reminder job');
    
    try {
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
          console.log(`[WhatsApp] Skipping school ${schoolId} - not enabled`);
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
        
        console.log(`[WhatsApp] Processing ${ledgers.size} ledgers for school ${schoolId}`);
        
        for (const ledgerDoc of ledgers.docs) {
          const ledger = ledgerDoc.data();
          
          // Process each term in the ledger
          for (const term of ledger.termStatus || []) {
            if (term.balanceAmount <= 0) continue;
            
            const dueDate = term.dueDate?.toDate();
            if (!dueDate) continue;
            
            dueDate.setHours(0, 0, 0, 0);
            
            let shouldSendReminder = false;
            let reminderType = '';
            
            // Check if due today
            if (dueDate.getTime() === today.getTime()) {
              shouldSendReminder = true;
              reminderType = 'due_today';
            }
            // Check if due in 3 days (advance reminder)
            else if (dueDate.getTime() === threeDaysLater.getTime()) {
              shouldSendReminder = true;
              reminderType = 'due_soon';
            }
            // Check if overdue
            else if (dueDate < today) {
              // Send overdue reminders every 7 days
              const daysSinceOverdue = Math.floor((today - dueDate) / (1000 * 60 * 60 * 24));
              if (daysSinceOverdue % 7 === 0) {
                shouldSendReminder = true;
                reminderType = 'overdue';
              }
            }
            
            if (shouldSendReminder) {
              // Get parent phone number from student_fee_details
              const studentDetails = await db
                .collection('schools')
                .doc(schoolId)
                .collection('student_fee_details')
                .where('stuId', '==', parseInt(ledger.studentId))
                .where('academicYear', '==', ledger.academicYear)
                .limit(1)
                .get();
              
              if (studentDetails.empty) {
                console.log(`[WhatsApp] No student details found for ${ledger.studentId}`);
                continue;
              }
              
              const phoneNumber = studentDetails.docs[0].data().phoneNumber;
              if (!phoneNumber || phoneNumber === 'NA' || phoneNumber === '') {
                console.log(`[WhatsApp] No valid phone number for ${ledger.studentName}`);
                continue;
              }
              
              // Send WhatsApp reminder
              const sent = await sendWhatsAppReminder({
                config,
                phoneNumber,
                studentName: ledger.studentName,
                termName: term.termName,
                dueAmount: term.balanceAmount,
                dueDate,
                reminderType,
              });
              
              if (sent) {
                totalReminders++;
                
                // Log the reminder
                await db
                  .collection('schools')
                  .doc(schoolId)
                  .collection('whatsappNotifications')
                  .add({
                    type: 'fee_due_reminder',
                    reminderType,
                    recipient: phoneNumber,
                    studentId: ledger.studentId,
                    studentName: ledger.studentName,
                    termName: term.termName,
                    dueAmount: term.balanceAmount,
                    dueDate: admin.firestore.Timestamp.fromDate(dueDate),
                    status: 'sent',
                    sentAt: admin.firestore.FieldValue.serverTimestamp(),
                  });
              }
              
              // Rate limiting: wait 100ms between messages
              await new Promise(resolve => setTimeout(resolve, 100));
            }
          }
        }
      }
      
      console.log(`[WhatsApp Reminders] Completed. Sent ${totalReminders} reminders`);
      return null;
    } catch (error) {
      console.error('[WhatsApp Reminders] Error:', error);
      throw error;
    }
  });
*/
/**
 * Scheduled function to send daily collection summary to admins
 * Runs daily at 6:00 PM IST
 * DISABLED - Now handled by combined-daily-jobs.js to reduce costs
 */
/*
exports.sendDailyCollectionSummary = functions
  .region('asia-south1')
  .pubsub.schedule('0 18 * * *')
  .timeZone('Asia/Kolkata')
  .onRun(async (context) => {
    console.log('[WhatsApp Summary] Starting daily collection summary job');
    
    try {
      const schools = await db.collection('schools').get();
      
      for (const schoolDoc of schools.docs) {
        const schoolId = schoolDoc.id;
        
        // Check if WhatsApp is enabled
        const whatsappConfig = await db
          .collection('schools')
          .doc(schoolId)
          .collection('settings')
          .doc('whatsapp')
          .get();
        
        if (!whatsappConfig.exists || !whatsappConfig.data().enabled) {
          continue;
        }
        
        const config = whatsappConfig.data();
        const adminNumbers = config.adminPhoneNumbers || [];
        
        if (adminNumbers.length === 0) {
          console.log(`[WhatsApp] No admin numbers configured for school ${schoolId}`);
          continue;
        }
        
        // Get today's payments
        const today = new Date();
        today.setHours(0, 0, 0, 0);
        const tomorrow = new Date(today);
        tomorrow.setDate(tomorrow.getDate() + 1);
        
        const payments = await db
          .collection('schools')
          .doc(schoolId)
          .collection('termFeePayments')
          .where('paidAt', '>=', admin.firestore.Timestamp.fromDate(today))
          .where('paidAt', '<', admin.firestore.Timestamp.fromDate(tomorrow))
          .where('isDeleted', '==', false)
          .get();
        
        const totalCollected = payments.docs.reduce((sum, doc) => sum + (doc.data().amount || 0), 0);
        const transactionCount = payments.size;
        
        // Send summary to all admin numbers
        for (const adminPhone of adminNumbers) {
          await sendWhatsAppAdminSummary({
            config,
            phoneNumber: adminPhone,
            totalCollected,
            transactionCount,
            date: today,
          });
          
          // Rate limiting
          await new Promise(resolve => setTimeout(resolve, 100));
        }
        
        console.log(`[WhatsApp Summary] Sent summary for school ${schoolId}: ₹${totalCollected}, ${transactionCount} transactions`);
      }
      
      return null;
    } catch (error) {
      console.error('[WhatsApp Summary] Error:', error);
      throw error;
    }
  });
*/
/**
 * Helper function to send WhatsApp reminder via Meta API
 */
async function sendWhatsAppReminder({ config, phoneNumber, studentName, termName, dueAmount, dueDate, reminderType }) {
    var _a;
    try {
        const formattedPhone = formatPhoneNumber(phoneNumber);
        const dueDateStr = `${dueDate.getDate()}/${dueDate.getMonth() + 1}/${dueDate.getFullYear()}`;
        const response = await axios.post(`https://graph.facebook.com/v18.0/${config.phoneNumberId}/messages`, {
            messaging_product: 'whatsapp',
            to: formattedPhone,
            type: 'template',
            template: {
                name: config.feeDueTemplate || 'fee_due_reminder',
                language: { code: 'en' },
                components: [
                    {
                        type: 'body',
                        parameters: [
                            { type: 'text', text: studentName },
                            { type: 'text', text: termName },
                            { type: 'text', text: `₹${dueAmount.toFixed(2)}` },
                            { type: 'text', text: dueDateStr },
                        ]
                    }
                ]
            }
        }, {
            headers: {
                'Authorization': `Bearer ${config.accessToken}`,
                'Content-Type': 'application/json',
            }
        });
        return response.status === 200;
    }
    catch (error) {
        console.error('[WhatsApp] Error sending reminder:', ((_a = error.response) === null || _a === void 0 ? void 0 : _a.data) || error.message);
        return false;
    }
}
/**
 * Helper function to send admin summary via Meta API
 */
async function sendWhatsAppAdminSummary({ config, phoneNumber, totalCollected, transactionCount, date }) {
    var _a;
    try {
        const formattedPhone = formatPhoneNumber(phoneNumber);
        const dateStr = `${date.getDate()}/${date.getMonth() + 1}/${date.getFullYear()}`;
        const response = await axios.post(`https://graph.facebook.com/v18.0/${config.phoneNumberId}/messages`, {
            messaging_product: 'whatsapp',
            to: formattedPhone,
            type: 'template',
            template: {
                name: config.adminSummaryTemplate || 'admin_daily_summary',
                language: { code: 'en' },
                components: [
                    {
                        type: 'body',
                        parameters: [
                            { type: 'text', text: dateStr },
                            { type: 'text', text: `₹${totalCollected.toFixed(2)}` },
                            { type: 'text', text: transactionCount.toString() },
                        ]
                    }
                ]
            }
        }, {
            headers: {
                'Authorization': `Bearer ${config.accessToken}`,
                'Content-Type': 'application/json',
            }
        });
        return response.status === 200;
    }
    catch (error) {
        console.error('[WhatsApp] Error sending admin summary:', ((_a = error.response) === null || _a === void 0 ? void 0 : _a.data) || error.message);
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
//# sourceMappingURL=whatsapp-fee-reminders.js.map