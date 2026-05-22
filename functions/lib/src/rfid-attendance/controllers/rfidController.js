const admin = require('firebase-admin');
const db = admin.firestore();
const { logError, logSuccess } = require('../utils/logger');

/**
 * Register RFID Card
 * POST /register-rfid
 * Body: { schoolId, rfidTag }
 * This just registers the RFID card to the device. 
 * Mapping to staff/student is done separately in Flutter UI.
 */
const registerRfidCard = async (req, res) => {
  try {
    const { schoolId, rfidTag } = req.body;
    const { deviceId, deviceName } = req.deviceInfo;

    console.log('🏷️  [REGISTER_RFID] Registering RFID card');
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

    // Check if RFID card already exists
    const existingCard = await db
      .collection('schools')
      .doc(schoolId)
      .collection('rfid_cards')
      .doc(rfidTag)
      .get();

    if (existingCard.exists) {
      return res.status(409).json({
        success: false,
        error: 'ALREADY_EXISTS',
        message: 'RFID card already registered'
      });
    }

    // Register RFID card (unassigned - no staff/student mapping yet)
    const rfidCard = {
      uuid: rfidTag,  // UUID field for compatibility with Flutter app
      rfidTag,
      schoolId,
      staffId: null,  // null for unassigned cards
      staffName: null,  // null for unassigned
      cardType: 'primary',  // Default card type
      registeredBy: deviceId,
      registeredAt: admin.firestore.FieldValue.serverTimestamp(),
      assignedAt: admin.firestore.FieldValue.serverTimestamp(),  // Required field
      isActive: true,
      isAssigned: false,
      metadata: {
        deviceName,
        registrationDevice: deviceId
      }
    };

    await db
      .collection('schools')
      .doc(schoolId)
      .collection('rfid_cards')
      .doc(rfidTag)
      .set(rfidCard);

    logSuccess('REGISTER_RFID', { rfidTag, schoolId });

    return res.status(201).json({
      success: true,
      message: 'RFID card registered successfully (unassigned)',
      data: {
        rfidTag,
        schoolId,
        registeredAt: new Date().toISOString(),
        isAssigned: false
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

/**
 * Unmap RFID Card from Staff
 * POST /unmap-rfid
 * Body: { schoolId, rfidTag }
 * This unmaps the RFID card from staff, setting staffId and staffName to null
 */
const unmapRfidCard = async (req, res) => {
  try {
    const { schoolId, rfidTag } = req.body;
    const { deviceId, deviceName } = req.deviceInfo;

    console.log('🔓 [UNMAP_RFID] Unmapping RFID card from staff');
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

    // Check if RFID card exists
    const cardRef = db
      .collection('schools')
      .doc(schoolId)
      .collection('rfid_cards')
      .doc(rfidTag);

    const cardDoc = await cardRef.get();

    if (!cardDoc.exists) {
      return res.status(404).json({
        success: false,
        error: 'NOT_FOUND',
        message: 'RFID card not found'
      });
    }

    const cardData = cardDoc.data();

    // Check if card is already unassigned
    if (!cardData.staffId) {
      return res.status(400).json({
        success: false,
        error: 'ALREADY_UNASSIGNED',
        message: 'RFID card is already unassigned'
      });
    }

    // Unmap the card - set staffId and staffName to null
    await cardRef.update({
      staffId: null,
      staffName: null,
      isAssigned: false,
      unmappedAt: admin.firestore.FieldValue.serverTimestamp(),
      unmappedBy: deviceId,
      metadata: {
        ...cardData.metadata,
        lastUnmappedDevice: deviceName,
        lastUnmappedDeviceId: deviceId
      }
    });

    logSuccess('UNMAP_RFID', { rfidTag, schoolId, previousStaffId: cardData.staffId });

    return res.status(200).json({
      success: true,
      message: 'RFID card unmapped successfully',
      data: {
        rfidTag,
        schoolId,
        previousStaffId: cardData.staffId,
        previousStaffName: cardData.staffName,
        unmappedAt: new Date().toISOString()
      }
    });

  } catch (error) {
    logError('UNMAP_RFID', error, { body: req.body });
    return res.status(500).json({
      success: false,
      error: 'INTERNAL_ERROR',
      message: 'Failed to unmap RFID card'
    });
  }
};

module.exports = { registerRfidCard, unmapRfidCard };
