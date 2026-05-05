const admin = require('firebase-admin');
const db = admin.firestore();
const { logError, logSuccess } = require('../utils/logger');

/**
 * Register RFID Card
 * POST /register-rfid
 * Body: { schoolId, uid, userId }
 */
const registerRfidCard = async (req, res) => {
  try {
    const { schoolId, uid, userId } = req.body;
    const { deviceId, deviceName } = req.deviceInfo;

    console.log('🏷️  [REGISTER_RFID] Registering RFID card');
    console.log(`   School: ${schoolId}`);
    console.log(`   UID: ${uid}`);
    console.log(`   User: ${userId}`);
    console.log(`   Device: ${deviceName} (${deviceId})`);

    // Validate required fields
    if (!schoolId || !uid || !userId) {
      return res.status(400).json({
        success: false,
        error: 'BAD_REQUEST',
        message: 'schoolId, uid, and userId are required'
      });
    }

    // Check if RFID card already exists
    const existingCard = await db
      .collection('schools')
      .doc(schoolId)
      .collection('rfid_cards')
      .doc(uid)
      .get();

    if (existingCard.exists) {
      return res.status(409).json({
        success: false,
        error: 'ALREADY_EXISTS',
        message: 'RFID card already registered'
      });
    }

    // Verify user exists in the school
    const userDoc = await db
      .collection('schools')
      .doc(schoolId)
      .collection('users')
      .doc(userId)
      .get();

    if (!userDoc.exists) {
      return res.status(404).json({
        success: false,
        error: 'USER_NOT_FOUND',
        message: 'User not found in this school'
      });
    }

    // Register RFID card
    const rfidCard = {
      uid,
      userId,
      schoolId,
      registeredBy: deviceId,
      registeredAt: admin.firestore.FieldValue.serverTimestamp(),
      isActive: true,
      metadata: {
        deviceName,
        registrationDevice: deviceId
      }
    };

    await db
      .collection('schools')
      .doc(schoolId)
      .collection('rfid_cards')
      .doc(uid)
      .set(rfidCard);

    logSuccess('REGISTER_RFID', { uid, userId, schoolId });

    return res.status(201).json({
      success: true,
      message: 'RFID card registered successfully',
      data: {
        uid,
        userId,
        schoolId,
        registeredAt: new Date().toISOString()
      }
    });

  } catch (error) {
    logError('REGISTER_RFID', error, { body: req.body });
    return res.status(500).json({
      success: false,
      error: 'INTERNAL_ERROR',
      message: 'Failed to register RFID card'
    });
  }
};

module.exports = { registerRfidCard };
