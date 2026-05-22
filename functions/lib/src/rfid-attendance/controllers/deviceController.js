const admin = require('firebase-admin');
const db = admin.firestore();
const crypto = require('crypto');
const { logError, logSuccess } = require('../utils/logger');

/**
 * Generate a secure random device key
 */
const generateDeviceKey = () => {
  return crypto.randomBytes(32).toString('hex');
};

/**
 * Register Device
 * POST /register-device
 * Body: { schoolId, deviceId, deviceName }
 */
const registerDevice = async (req, res) => {
  try {
    const { schoolId, deviceId, deviceName } = req.body;
    const { deviceId: authDeviceId } = req.deviceInfo || {};

    console.log('🔌 [REGISTER_DEVICE] Registering device');
    console.log(`   School: ${schoolId}`);
    console.log(`   Device ID: ${deviceId}`);
    console.log(`   Device Name: ${deviceName}`);

    // Validate required fields
    if (!schoolId || !deviceId || !deviceName) {
      return res.status(400).json({
        success: false,
        error: 'BAD_REQUEST',
        message: 'schoolId, deviceId, and deviceName are required'
      });
    }

    // Check if device already exists
    const existingDevice = await db
      .collection('schools')
      .doc(schoolId)
      .collection('devices')
      .doc(deviceId)
      .get();

    if (existingDevice.exists) {
      const deviceData = existingDevice.data();
      
      // If device exists but is inactive, reactivate it
      if (deviceData.isActive === false) {
        await db
          .collection('schools')
          .doc(schoolId)
          .collection('devices')
          .doc(deviceId)
          .update({
            isActive: true,
            deviceName,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            reactivatedAt: admin.firestore.FieldValue.serverTimestamp()
          });

        logSuccess('REGISTER_DEVICE', { deviceId, schoolId, action: 'reactivated' });

        return res.status(200).json({
          success: true,
          message: 'Device reactivated successfully',
          data: {
            deviceId,
            deviceName,
            schoolId,
            isActive: true,
            deviceKey: '*** (existing key preserved) ***'
          }
        });
      }

      return res.status(409).json({
        success: false,
        error: 'ALREADY_EXISTS',
        message: 'Device already registered and active'
      });
    }

    // Generate secure device key
    const deviceKey = generateDeviceKey();

    // Register device
    const device = {
      deviceId,
      deviceName,
      schoolId,
      deviceKey,
      isActive: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      metadata: {
        registeredBy: authDeviceId || 'admin',
        registrationType: 'API'
      }
    };

    await db
      .collection('schools')
      .doc(schoolId)
      .collection('devices')
      .doc(deviceId)
      .set(device);

    logSuccess('REGISTER_DEVICE', { deviceId, schoolId, deviceName });

    return res.status(201).json({
      success: true,
      message: 'Device registered successfully',
      data: {
        deviceId,
        deviceName,
        schoolId,
        isActive: true,
        deviceKey, // Return key only on first registration
        createdAt: new Date().toISOString()
      },
      warning: 'Store the deviceKey securely. It will not be shown again.'
    });

  } catch (error) {
    logError('REGISTER_DEVICE', error, { body: req.body });
    return res.status(500).json({
      success: false,
      error: 'INTERNAL_ERROR',
      message: 'Failed to register device'
    });
  }
};

module.exports = { registerDevice, generateDeviceKey };
