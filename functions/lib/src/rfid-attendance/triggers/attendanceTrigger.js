const functions = require('firebase-functions/v1').region('asia-south1');
const admin = require('firebase-admin');
const db = admin.firestore();
const { logSuccess, logError } = require('../utils/logger');

/**
 * Firestore Trigger: On Attendance Create
 * Triggered when a new attendance record is created
 * Logs the event and can trigger notifications
 */
exports.onAttendanceCreate = functions.firestore
  .document('schools/{schoolId}/attendance/{attendanceId}')
  .onCreate(async (snapshot, context) => {
    const { schoolId, attendanceId } = context.params;
    const attendanceData = snapshot.data();

    console.log('📋 [ATTENDANCE_TRIGGER] Attendance record created');
    console.log(`   School: ${schoolId}`);
    console.log(`   Attendance ID: ${attendanceId}`);
    console.log(`   User: ${attendanceData.userId}`);
    console.log(`   Device: ${attendanceData.deviceName} (${attendanceData.deviceId})`);
    console.log(`   Status: ${attendanceData.status}`);
    console.log(`   Scanned At: ${attendanceData.scannedAt}`);

    try {
      // Update user's last seen timestamp
      await db
        .collection('schools')
        .doc(schoolId)
        .collection('users')
        .doc(attendanceData.userId)
        .update({
          lastSeenAt: admin.firestore.FieldValue.serverTimestamp(),
          lastSeenDevice: attendanceData.deviceId
        });

      console.log('✅ [ATTENDANCE_TRIGGER] User last seen updated');

      // Optional: Create daily attendance summary
      const scanDate = attendanceData.scannedAt.toDate();
      const dateKey = `${scanDate.getFullYear()}-${String(scanDate.getMonth() + 1).padStart(2, '0')}-${String(scanDate.getDate()).padStart(2, '0')}`;
      const summaryId = `${attendanceData.userId}_${dateKey}`;

      const summaryRef = db
        .collection('schools')
        .doc(schoolId)
        .collection('dailyAttendanceSummary')
        .doc(summaryId);

      await db.runTransaction(async (transaction) => {
        const summaryDoc = await transaction.get(summaryRef);

        if (summaryDoc.exists) {
          const summary = summaryDoc.data();
          transaction.update(summaryRef, {
            totalScans: (summary.totalScans || 0) + 1,
            lastScanAt: attendanceData.scannedAt,
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
          });
        } else {
          transaction.set(summaryRef, {
            userId: attendanceData.userId,
            date: dateKey,
            schoolId,
            totalScans: 1,
            firstScanAt: attendanceData.scannedAt,
            lastScanAt: attendanceData.scannedAt,
            status: 'PRESENT',
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
          });
        }
      });

      console.log('✅ [ATTENDANCE_TRIGGER] Daily attendance summary updated');

      // Optional: Trigger notification (if notification system exists)
      // This is a placeholder for notification logic
      // await sendAttendanceNotification(schoolId, attendanceData);

      logSuccess('ATTENDANCE_TRIGGER', { attendanceId, schoolId, userId: attendanceData.userId });

      return null;
    } catch (error) {
      logError('ATTENDANCE_TRIGGER', error, { schoolId, attendanceId });
      // Don't throw - we don't want to fail the attendance marking
      return null;
    }
  });
