const admin = require('firebase-admin');
const db = admin.firestore();

/**
 * Validate that the caller is an authenticated admin (or super admin) of the
 * school named in the request body, via a Firebase Auth ID token.
 *
 * Used for device provisioning (register-device): registering a device hands
 * back a permanent deviceKey, so this step must be done by a person the app
 * has already authenticated (e.g. an admin/installer setting up the reader),
 * not by the unauthenticated hardware itself.
 */
const validateAdminAuth = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization || '';
    const idToken = authHeader.startsWith('Bearer ') ? authHeader.slice(7) : null;

    if (!idToken) {
      return res.status(401).json({
        success: false,
        error: 'UNAUTHORIZED',
        message: 'Missing Authorization: Bearer <idToken> header'
      });
    }

    const { schoolId } = req.body;
    if (!schoolId) {
      return res.status(400).json({
        success: false,
        error: 'BAD_REQUEST',
        message: 'schoolId is required'
      });
    }

    let decoded;
    try {
      decoded = await admin.auth().verifyIdToken(idToken);
    } catch (error) {
      return res.status(401).json({
        success: false,
        error: 'UNAUTHORIZED',
        message: 'Invalid or expired ID token'
      });
    }

    const userDoc = await db.collection('users').doc(decoded.uid).get();
    const userData = userDoc.exists ? userDoc.data() : null;
    const role = userData ? userData.role : null;
    const isSuperAdmin = ['SUPER_ADMIN', 'super_admin'].includes(role);
    const isSchoolAdmin = ['ADMIN', 'admin', 'TENANT_ADMIN', 'tenant_admin'].includes(role)
      && userData.schoolId === schoolId;

    if (!isSuperAdmin && !isSchoolAdmin) {
      return res.status(403).json({
        success: false,
        error: 'FORBIDDEN',
        message: 'Only an admin of this school (or a super admin) can provision devices'
      });
    }

    req.adminInfo = { uid: decoded.uid, schoolId };
    next();
  } catch (error) {
    console.error('❌ [ADMIN_AUTH] Error:', error);
    return res.status(500).json({
      success: false,
      error: 'INTERNAL_ERROR',
      message: 'Failed to validate admin authentication'
    });
  }
};

module.exports = { validateAdminAuth };
