const admin = require('firebase-admin');
const crypto = require('crypto');
const db = admin.firestore();

const hashDeviceKey = (key) => crypto.createHash('sha256').update(key).digest('hex');

/**
 * Constant-time comparison of two hex-encoded hashes, to avoid leaking
 * information about a valid key through response-time differences.
 */
const hashesMatch = (a, b) => {
  const bufA = Buffer.from(a, 'hex');
  const bufB = Buffer.from(b, 'hex');
  return bufA.length === bufB.length && crypto.timingSafeEqual(bufA, bufB);
};

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

    // Check for schoolId (deviceId is optional for some endpoints like register-rfid)
    if (!schoolId) {
      return res.status(400).json({
        success: false,
        error: 'BAD_REQUEST',
        message: 'schoolId is required'
      });
    }

    // If deviceId is provided in body, use it. Otherwise, fetch device by device key
    let targetDeviceId = deviceId;
    let deviceDoc;

    if (targetDeviceId) {
      // Fetch specific device by ID
      deviceDoc = await db
        .collection('schools')
        .doc(schoolId)
        .collection('devices')
        .doc(targetDeviceId)
        .get();
    } else {
      // Find device by device key (for endpoints where deviceId is optional).
      // New devices are keyed by deviceKeyHash only; fall back to the legacy
      // plaintext deviceKey field for devices registered before this fix.
      const incomingHash = hashDeviceKey(deviceKey);
      let devicesSnapshot = await db
        .collection('schools')
        .doc(schoolId)
        .collection('devices')
        .where('deviceKeyHash', '==', incomingHash)
        .limit(1)
        .get();

      if (devicesSnapshot.empty) {
        devicesSnapshot = await db
          .collection('schools')
          .doc(schoolId)
          .collection('devices')
          .where('deviceKey', '==', deviceKey)
          .limit(1)
          .get();
      }

      if (devicesSnapshot.empty) {
        return res.status(403).json({
          success: false,
          error: 'FORBIDDEN',
          message: 'Invalid device key'
        });
      }

      deviceDoc = devicesSnapshot.docs[0];
      targetDeviceId = deviceDoc.id;
    }

    if (!deviceDoc.exists) {
      return res.status(404).json({
        success: false,
        error: 'DEVICE_NOT_FOUND',
        message: 'Device not registered for this school'
      });
    }

    const deviceData = deviceDoc.data();

    // Validate device key: compare hashes in constant time. Supports both the
    // new deviceKeyHash-only storage and legacy plaintext deviceKey records.
    const incomingHash = hashDeviceKey(deviceKey);
    const storedHash = deviceData.deviceKeyHash || (deviceData.deviceKey ? hashDeviceKey(deviceData.deviceKey) : null);

    if (!storedHash || !hashesMatch(incomingHash, storedHash)) {
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
      deviceId: targetDeviceId,
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
