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
    const response = await axios.post(
      `https://graph.facebook.com/v18.0/${phoneNumberId}/messages`,
      {
        messaging_product: 'whatsapp',
        to: formattedPhone,
        type: 'template',
        template: {
          name: 'hello_world',
          language: { code: 'en_US' },
        },
      },
      {
        headers: {
          Authorization: `Bearer ${accessToken}`,
          'Content-Type': 'application/json',
        },
        timeout: 30000,
      }
    );

    console.log('[WhatsApp Test] Response status:', response.status);
    console.log('[WhatsApp Test] Response data:', response.data);

    return {
      success: true,
      message: 'Test message sent successfully',
      statusCode: response.status,
      data: response.data,
    };
  } catch (error) {
    console.error('[WhatsApp Test] Error:', error.message);
    console.error('[WhatsApp Test] Response:', error.response?.data);

    throw new functions.https.HttpsError(
      'internal',
      `Test failed: ${error.message}`,
      error.response?.data
    );
  }
});

/**
 * Callable Cloud Function: Send Payment Notification via WhatsApp
 * Called from Flutter app to avoid CORS issues when running on web
 */
exports.sendPaymentNotification = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { schoolId, phoneNumber, studentName, paidAmount, receiptNumber, paymentDate, balanceAmount } = data;

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

    console.log(`[WhatsApp Payment] Phone: ${formattedPhone}, Template: ${templateName}, PhoneNumberId: ${phoneNumberId}`);

    const response = await axios.post(
      `https://graph.facebook.com/v19.0/${phoneNumberId}/messages`,
      {
        messaging_product: 'whatsapp',
        to: formattedPhone,
        type: 'template',
        template: {
          name: templateName,
          language: { code: 'en' },
          components: [
            {
              type: 'body',
              parameters: [
                { type: 'text', text: studentName || '' },
                { type: 'text', text: `₹${parseFloat(paidAmount || 0).toFixed(2)}` },
                { type: 'text', text: receiptNumber || '' },
                { type: 'text', text: paymentDate || '' },
                { type: 'text', text: `₹${parseFloat(balanceAmount || 0).toFixed(2)}` },
              ]
            }
          ]
        }
      },
      {
        headers: {
          Authorization: `Bearer ${accessToken}`,
          'Content-Type': 'application/json',
        },
        timeout: 30000,
      }
    );

    console.log(`[WhatsApp Payment] Response: ${response.status}`, response.data);

    // Log notification
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

    return { success: true, message: 'Notification sent successfully' };
  } catch (error) {
    console.error('[WhatsApp Payment] Error:', error.message);
    console.error('[WhatsApp Payment] Response:', error.response?.data);

    // Log failed notification
    await db
      .collection('schools')
      .doc(schoolId)
      .collection('whatsappNotifications')
      .add({
        type: 'payment_confirmation',
        recipient: phoneNumber,
        studentName: studentName,
        metadata: { error: error.message, responseData: JSON.stringify(error.response?.data) },
        status: 'failed',
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
      });

    return { success: false, error: error.message, details: error.response?.data };
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
  try {
    const formattedPhone = formatPhoneNumber(phoneNumber);
    const dueDateStr = `${dueDate.getDate()}/${dueDate.getMonth() + 1}/${dueDate.getFullYear()}`;
    
    const response = await axios.post(
      `https://graph.facebook.com/v18.0/${config.phoneNumberId}/messages`,
      {
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
      },
      {
        headers: {
          'Authorization': `Bearer ${config.accessToken}`,
          'Content-Type': 'application/json',
        }
      }
    );
    
    return response.status === 200;
  } catch (error) {
    console.error('[WhatsApp] Error sending reminder:', error.response?.data || error.message);
    return false;
  }
}

/**
 * Helper function to send admin summary via Meta API
 */
async function sendWhatsAppAdminSummary({ config, phoneNumber, totalCollected, transactionCount, date }) {
  try {
    const formattedPhone = formatPhoneNumber(phoneNumber);
    const dateStr = `${date.getDate()}/${date.getMonth() + 1}/${date.getFullYear()}`;
    
    const response = await axios.post(
      `https://graph.facebook.com/v18.0/${config.phoneNumberId}/messages`,
      {
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
      },
      {
        headers: {
          'Authorization': `Bearer ${config.accessToken}`,
          'Content-Type': 'application/json',
        }
      }
    );
    
    return response.status === 200;
  } catch (error) {
    console.error('[WhatsApp] Error sending admin summary:', error.response?.data || error.message);
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
