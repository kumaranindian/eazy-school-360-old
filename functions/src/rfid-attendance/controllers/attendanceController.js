const admin = require('firebase-admin');
const db = admin.firestore();
const { logError, logSuccess, logWarning } = require('../utils/logger');

// Configurable duplicate scan window (in milliseconds)
const DUPLICATE_SCAN_WINDOW = 5 * 60 * 1000; // 5 minutes

/**
 * Mark Attendance
 * POST /mark-attendance
 * Body: { schoolId, uid, deviceId, timestamp }
 */
const markAttendance = async (req, res) => {
  try {
    const { schoolId, uid, deviceId, timestamp } = req.body;
    const { deviceId: authDeviceId, deviceName } = req.deviceInfo;

    console.log('📍 [MARK_ATTENDANCE] Marking attendance');
    console.log(`   School: ${schoolId}`);
    console.log(`   UID: ${uid}`);
    console.log(`   Device: ${deviceName} (${deviceId})`);

    // Validate required fields
    if (!schoolId || !uid || !deviceId) {
      return res.status(400).json({
        success: false,
        error: 'BAD_REQUEST',
        message: 'schoolId, uid, and deviceId are required'
      });
    }

    // Validate deviceId matches authenticated device
    if (deviceId !== authDeviceId) {
      return res.status(403).json({
        success: false,
        error: 'FORBIDDEN',
        message: 'Device ID mismatch'
      });
    }

    // Fetch RFID card mapping
    const rfidDoc = await db
      .collection('schools')
      .doc(schoolId)
      .collection('rfid_cards')
      .doc(uid)
      .get();

    if (!rfidDoc.exists) {
      return res.status(404).json({
        success: false,
        error: 'RFID_NOT_FOUND',
        message: 'RFID card not registered'
      });
    }

    const rfidData = rfidDoc.data();

    // Check if RFID card is active
    if (rfidData.isActive === false) {
      return res.status(403).json({
        success: false,
        error: 'RFID_INACTIVE',
        message: 'RFID card is inactive'
      });
    }

    const userId = rfidData.userId;

    // Check for duplicate scan within window
    const duplicateWindowStart = admin.firestore.Timestamp.fromDate(
      new Date(Date.now() - DUPLICATE_SCAN_WINDOW)
    );

    const duplicateCheck = await db
      .collection('schools')
      .doc(schoolId)
      .collection('attendance')
      .where('userId', '==', userId)
      .where('scannedAt', '>=', duplicateWindowStart)
      .orderBy('scannedAt', 'desc')
      .limit(1)
      .get();

    if (!duplicateCheck.empty) {
      const lastAttendance = duplicateCheck.docs[0].data();
      const lastScanTime = lastAttendance.scannedAt.toDate();
      const timeSinceLastScan = Date.now() - lastScanTime.getTime();
      const minutesSince = Math.floor(timeSinceLastScan / 1000 / 60);

      logWarning('MARK_ATTENDANCE', `Duplicate scan detected for user ${userId}. Last scan was ${minutesSince} minutes ago`);

      return res.status(409).json({
        success: false,
        error: 'DUPLICATE_SCAN',
        message: `Duplicate scan detected. Last scan was ${minutesSince} minutes ago`,
        data: {
          lastScanTime: lastScanTime.toISOString(),
          timeSinceLastScan: timeSinceLastScan
        }
      });
    }

    // Use provided timestamp or server time
    const scanTime = timestamp 
      ? admin.firestore.Timestamp.fromDate(new Date(timestamp))
      : admin.firestore.FieldValue.serverTimestamp();

    // Create attendance record
    const attendanceRecord = {
      schoolId,
      userId,
      uid,
      deviceId,
      deviceName,
      scannedAt: scanTime,
      status: 'PRESENT',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      metadata: {
        scanMethod: 'RFID',
        deviceInfo: {
          deviceId,
          deviceName
        }
      }
    };

    const attendanceRef = await db
      .collection('schools')
      .doc(schoolId)
      .collection('attendance')
      .add(attendanceRecord);

    // Fetch user details for response
    const userDoc = await db
      .collection('schools')
      .doc(schoolId)
      .collection('users')
      .doc(userId)
      .get();

    let userDetails = null;
    if (userDoc.exists) {
      const userData = userDoc.data();
      userDetails = {
        userId,
        name: userData.name || userData.displayName || 'Unknown',
        email: userData.email || null,
        role: userData.role || 'STAFF'
      };
    }

    logSuccess('MARK_ATTENDANCE', {
      attendanceId: attendanceRef.id,
      userId,
      schoolId,
      scannedAt: scanTime
    });

    return res.status(201).json({
      success: true,
      message: 'Attendance marked successfully',
      data: {
        attendanceId: attendanceRef.id,
        schoolId,
        userId,
        uid,
        scannedAt: scanTime,
        userDetails,
        deviceId,
        deviceName
      }
    });

  } catch (error) {
    logError('MARK_ATTENDANCE', error, { body: req.body });
    return res.status(500).json({
      success: false,
      error: 'INTERNAL_ERROR',
      message: 'Failed to mark attendance'
    });
  }
};

module.exports = { markAttendance };
