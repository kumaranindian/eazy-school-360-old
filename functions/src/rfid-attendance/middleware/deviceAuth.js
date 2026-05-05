const admin = require('firebase-admin');
const db = admin.firestore();

/**
 * Validate device key from header
 * Checks if the device is registered and the key matches
 */
const validateDeviceKey = async (req, res, next) => {
  try {
    const deviceKey = req.headers['x-device-key'];
    const { schoolId, deviceId } = req.body;

    // Check for device key header
    if (!deviceKey) {
      return res.status(401).json({
        success: false,
        error: 'UNAUTHORIZED',
        message: 'Missing x-device-key header'
      });
    }

    // Check for required fields
    if (!schoolId || !deviceId) {
      return res.status(400).json({
        success: false,
        error: 'BAD_REQUEST',
        message: 'schoolId and deviceId are required'
      });
    }

    // Fetch device from Firestore
    const deviceDoc = await db
      .collection('schools')
      .doc(schoolId)
      .collection('devices')
      .doc(deviceId)
      .get();

    if (!deviceDoc.exists) {
      return res.status(404).json({
        success: false,
        error: 'DEVICE_NOT_FOUND',
        message: 'Device not registered for this school'
      });
    }

    const deviceData = deviceDoc.data();

    // Validate device key
    if (deviceData.deviceKey !== deviceKey) {
      return res.status(403).json({
        success: false,
        error: 'FORBIDDEN',
        message: 'Invalid device key'
      });
    }

    // Check if device is active
    if (deviceData.isActive === false) {
      return res.status(403).json({
        success: false,
        error: 'DEVICE_INACTIVE',
        message: 'Device is inactive'
      });
    }

    // Attach device info to request for use in controllers
    req.deviceInfo = {
      deviceId,
      deviceName: deviceData.deviceName,
      schoolId
    };

    next();
  } catch (error) {
    console.error('❌ [DEVICE_AUTH] Error:', error);
    return res.status(500).json({
      success: false,
      error: 'INTERNAL_ERROR',
      message: 'Failed to validate device'
    });
  }
};

module.exports = { validateDeviceKey };
