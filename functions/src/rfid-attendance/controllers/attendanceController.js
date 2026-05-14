const admin = require('firebase-admin');
const db = admin.firestore();
const { logError, logSuccess, logWarning } = require('../utils/logger');

// Configurable duplicate scan window (in milliseconds)
const DUPLICATE_SCAN_WINDOW = 5 * 60 * 1000; // 5 minutes

/**
 * Mark Attendance
 * POST /mark-attendance
 * Body: { schoolId, rfidTag, timestamp }
 * Device is authenticated via x-device-key header
 */
const markAttendance = async (req, res) => {
  try {
    const { schoolId, rfidTag, timestamp } = req.body;
    const { deviceId, deviceName } = req.deviceInfo;

    console.log('📍 [MARK_ATTENDANCE] Marking attendance');
    console.log(`   School: ${schoolId}`);
    console.log(`   RFID Tag: ${rfidTag}`);
    console.log(`   Device: ${deviceName} (${deviceId})`);

    // Validate required fields
    if (!schoolId || !rfidTag) {
      return res.status(400).json({
        success: false,
        error: 'BAD_REQUEST',
        message: 'schoolId and rfidTag are required'
      });
    }

    // Fetch RFID card mapping
    const rfidDoc = await db
      .collection('schools')
      .doc(schoolId)
      .collection('rfid_cards')
      .doc(rfidTag)
      .get();

    if (!rfidDoc.exists) {
      return res.status(404).json({
        success: false,
        error: 'RFID_NOT_FOUND',
        message: 'RFID card not registered. Please register the card first.'
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

    // Check if RFID card is assigned to a staff/student
    if (!rfidData.isAssigned) {
      return res.status(400).json({
        success: false,
        error: 'RFID_UNASSIGNED',
        message: 'RFID card is not assigned to any staff or student. Please assign it in the admin panel.'
      });
    }

    // Get the staffId or studentId from the mapping
    const staffId = rfidData.staffId;
    const studentId = rfidData.studentId;

    if (!staffId && !studentId) {
      return res.status(400).json({
        success: false,
        error: 'INVALID_MAPPING',
        message: 'RFID card mapping is invalid. Please re-assign the card.'
      });
    }

    // Determine which collection to use
    const targetCollection = staffId ? 'staff' : 'students';
    const targetId = staffId || studentId;

    // Duplicate scan check removed to allow multiple scans

    // Use provided timestamp or server time
    const scanTime = timestamp 
      ? admin.firestore.Timestamp.fromDate(new Date(timestamp))
      : admin.firestore.FieldValue.serverTimestamp();

    // Create attendance record
    const attendanceRecord = {
      schoolId,
      rfidTag,
      staffId: staffId || null,
      studentId: studentId || null,
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
      .collection(targetCollection)
      .doc(targetId)
      .get();

    let userDetails = null;
    if (userDoc.exists) {
      const userData = userDoc.data();
      userDetails = {
        id: targetId,
        type: staffId ? 'staff' : 'student',
        name: staffId 
          ? (userData.name || userData.displayName || 'Unknown')
          : (userData.studentName || userData.name || 'Unknown'),
        email: userData.email || null
      };
    }

    logSuccess('MARK_ATTENDANCE', {
      attendanceId: attendanceRef.id,
      rfidTag,
      schoolId,
      staffId,
      studentId,
      scannedAt: scanTime
    });

    return res.status(201).json({
      success: true,
      message: 'Attendance marked successfully',
      data: {
        attendanceId: attendanceRef.id,
        schoolId,
        rfidTag,
        staffId,
        studentId,
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
