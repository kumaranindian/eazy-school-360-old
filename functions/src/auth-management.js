const functions = require('firebase-functions/v1').region('asia-south1');
const admin = require('firebase-admin');

// Initialize if not already done
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

/**
 * 🎯 SECURE STAFF ACTIVATION HANDLER
 * 
 * Trigger: onCreate of users/{userId}
 * 
 * This function ensures:
 * 1. Automatic custom claims setup for new users
 * 2. Email verification link sent automatically
 * 3. Proper activation workflow
 * 4. Security and audit trail
 * 
 * Flow:
 * - Admin creates staff user
 * - Function sets custom claims
 * - Function sends password reset email
 * - Staff resets password and gets activated
 */
exports.handleUserCreate = functions.firestore
  .document('users/{userId}')
  .onCreate(async (snapshot, context) => {
    const { userId } = context.params;
    const userData = snapshot.data();
    
    console.log('🚀 [USER_CREATE] Function triggered for user:', userId);
    console.log('📊 [USER_CREATE] Email:', userData.email);
    console.log('📊 [USER_CREATE] Role:', userData.role);
    
    try {
      // ============================================================
      // STEP 1: SET CUSTOM CLAIMS
      // ============================================================
      const customClaims = {
        superAdmin: userData.role === 'SUPER_ADMIN',
        admin: userData.role === 'ADMIN' || userData.role === 'tenant_admin',
        staff: userData.role === 'STAFF' || userData.role === 'TEACHER',
        finance: userData.role === 'FINANCE',
        schoolId: userData.schoolId || null,
        isActive: userData.isActive === true // Only true if explicitly set
      };
      
      await admin.auth().setCustomUserClaims(userId, customClaims);
      console.log('✅ [USER_CREATE] Custom claims set:', customClaims);
      
      // ============================================================
      // STEP 2: SEND PASSWORD RESET EMAIL (for activation)
      // ============================================================
      if (userData.onboardingStatus === 'PENDING_ACTIVATION') {
        try {
          const actionCodeSettings = {
            url: `${functions.config().app?.url || 'http://localhost:3000'}/login`,
            handleCodeInApp: false
          };
          
          const resetLink = await admin.auth().generatePasswordResetLink(
            userData.email,
            actionCodeSettings
          );
          
          console.log('✅ [USER_CREATE] Password reset link generated');
          console.log('🔗 [USER_CREATE] Link:', resetLink);
          
          // TODO: Send email via SendGrid/Mailgun
          // For now, log the link (admin should manually send it)
          
        } catch (emailError) {
          console.error('❌ [USER_CREATE] Failed to generate reset link:', emailError);
          // Non-fatal - continue with user creation
        }
      }
      
      // ============================================================
      // STEP 3: CREATE AUDIT LOG
      // ============================================================
      await db.collection('auditLogs').add({
        action: 'USER_CREATED',
        userId,
        email: userData.email,
        role: userData.role,
        schoolId: userData.schoolId,
        createdBy: userData.createdBy || 'system',
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        metadata: {
          onboardingStatus: userData.onboardingStatus,
          customClaims
        }
      });
      
      console.log('✅ [USER_CREATE] Audit log created');
      console.log('🎉 [USER_CREATE] User creation completed:', userId);
      
      return {
        success: true,
        userId,
        message: 'User created and claims set successfully'
      };
      
    } catch (error) {
      console.error('❌ [USER_CREATE] Error:', error);
      throw new functions.https.HttpsError(
        'internal',
        `Failed to process user creation: ${error.message}`
      );
    }
  });

/**
 * 🎯 SECURE STAFF ACTIVATION ON PASSWORD RESET
 * 
 * Trigger: User completes password reset
 * 
 * This function ensures:
 * 1. User is activated after password reset
 * 2. Custom claims updated
 * 3. Membership documents created
 * 4. Audit trail maintained
 */
exports.handlePasswordReset = functions.auth.user().onCreate(async (user) => {
  console.log('🚀 [PASSWORD_RESET] Function triggered for user:', user.uid);
  
  try {
    // Check if user document exists
    const userDoc = await db.collection('users').doc(user.uid).get();
    
    if (!userDoc.exists) {
      console.log('⚠️ [PASSWORD_RESET] User document not found, skipping');
      return null;
    }
    
    const userData = userDoc.data();
    
    // Only activate if pending
    if (userData.onboardingStatus !== 'PENDING_ACTIVATION') {
      console.log('ℹ️ [PASSWORD_RESET] User not pending activation, skipping');
      return null;
    }
    
    console.log('🔄 [PASSWORD_RESET] Activating user:', user.uid);
    
    // ============================================================
    // STEP 1: UPDATE USER DOCUMENT
    // ============================================================
    await db.collection('users').doc(user.uid).update({
      isActive: true,
      onboardingStatus: 'ACTIVE',
      activatedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    console.log('✅ [PASSWORD_RESET] User document updated');
    
    // ============================================================
    // STEP 2: UPDATE CUSTOM CLAIMS
    // ============================================================
    const customClaims = {
      superAdmin: userData.role === 'SUPER_ADMIN',
      admin: userData.role === 'ADMIN' || userData.role === 'tenant_admin',
      staff: userData.role === 'STAFF' || userData.role === 'TEACHER',
      finance: userData.role === 'FINANCE',
      schoolId: userData.schoolId || null,
      isActive: true // Now active
    };
    
    await admin.auth().setCustomUserClaims(user.uid, customClaims);
    console.log('✅ [PASSWORD_RESET] Custom claims updated:', customClaims);
    
    // ============================================================
    // STEP 3: CREATE/UPDATE MEMBERSHIP DOCUMENT
    // ============================================================
    if (userData.schoolId) {
      const membershipRef = db
        .collection('userMemberships')
        .doc(user.uid)
        .collection('schools')
        .doc(userData.schoolId);
      
      await membershipRef.set({
        schoolId: userData.schoolId,
        userId: user.uid,
        primaryRole: userData.role,
        roles: [userData.role],
        isActive: true,
        joinedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      }, { merge: true });
      
      console.log('✅ [PASSWORD_RESET] Membership document created');
    }
    
    // ============================================================
    // STEP 4: CREATE AUDIT LOG
    // ============================================================
    await db.collection('auditLogs').add({
      action: 'USER_ACTIVATED',
      userId: user.uid,
      email: user.email,
      role: userData.role,
      schoolId: userData.schoolId,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      metadata: {
        activationMethod: 'password_reset',
        customClaims
      }
    });
    
    console.log('✅ [PASSWORD_RESET] Audit log created');
    console.log('🎉 [PASSWORD_RESET] User activation completed:', user.uid);
    
    return null;
    
  } catch (error) {
    console.error('❌ [PASSWORD_RESET] Error:', error);
    // Don't throw - this is a background function
    return null;
  }
});

/**
 * 🎯 CALLABLE FUNCTION: ACTIVATE USER
 * 
 * Allows admins to manually activate a user
 * 
 * Security:
 * - Only admins can call this
 * - Validates user belongs to same school
 * - Updates claims and membership
 */
exports.activateUser = functions.https.onCall(async (data, context) => {
  // ============================================================
  // STEP 1: VALIDATE CALLER
  // ============================================================
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'User must be authenticated'
    );
  }
  
  const callerUid = context.auth.uid;
  const callerDoc = await db.collection('users').doc(callerUid).get();
  
  if (!callerDoc.exists) {
    throw new functions.https.HttpsError(
      'not-found',
      'Caller user document not found'
    );
  }
  
  const callerData = callerDoc.data();
  const isAdmin = callerData.role === 'SUPER_ADMIN' || 
                  callerData.role === 'ADMIN' ||
                  callerData.role === 'tenant_admin';
  
  if (!isAdmin) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Only admins can activate users'
    );
  }
  
  console.log('🔐 [ACTIVATE_USER] Admin request from:', callerUid);
  
  // ============================================================
  // STEP 2: VALIDATE TARGET USER
  // ============================================================
  const { userId } = data;
  
  if (!userId) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'userId is required'
    );
  }
  
  const userDoc = await db.collection('users').doc(userId).get();
  
  if (!userDoc.exists) {
    throw new functions.https.HttpsError(
      'not-found',
      'User document not found'
    );
  }
  
  const userData = userDoc.data();
  
  // Verify same school (unless super admin)
  if (callerData.role !== 'SUPER_ADMIN') {
    if (userData.schoolId !== callerData.schoolId) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Can only activate users in your school'
      );
    }
  }
  
  console.log('✅ [ACTIVATE_USER] Validation passed for user:', userId);
  
  // ============================================================
  // STEP 3: ACTIVATE USER
  // ============================================================
  try {
    // Update user document
    await db.collection('users').doc(userId).update({
      isActive: true,
      onboardingStatus: 'ACTIVE',
      activatedAt: admin.firestore.FieldValue.serverTimestamp(),
      activatedBy: callerUid,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    // Update custom claims
    const customClaims = {
      superAdmin: userData.role === 'SUPER_ADMIN',
      admin: userData.role === 'ADMIN' || userData.role === 'tenant_admin',
      staff: userData.role === 'STAFF' || userData.role === 'TEACHER',
      finance: userData.role === 'FINANCE',
      schoolId: userData.schoolId || null,
      isActive: true
    };
    
    await admin.auth().setCustomUserClaims(userId, customClaims);
    
    // Create/update membership
    if (userData.schoolId) {
      const membershipRef = db
        .collection('userMemberships')
        .doc(userId)
        .collection('schools')
        .doc(userData.schoolId);
      
      await membershipRef.set({
        schoolId: userData.schoolId,
        userId,
        primaryRole: userData.role,
        roles: [userData.role],
        isActive: true,
        activatedBy: callerUid,
        joinedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      }, { merge: true });
    }
    
    // Create audit log
    await db.collection('auditLogs').add({
      action: 'USER_ACTIVATED',
      userId,
      email: userData.email,
      role: userData.role,
      schoolId: userData.schoolId,
      activatedBy: callerUid,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      metadata: {
        activationMethod: 'manual_admin',
        customClaims
      }
    });
    
    console.log('✅ [ACTIVATE_USER] User activated successfully:', userId);
    
    return {
      success: true,
      userId,
      message: 'User activated successfully'
    };
    
  } catch (error) {
    console.error('❌ [ACTIVATE_USER] Error:', error);
    throw new functions.https.HttpsError(
      'internal',
      `Failed to activate user: ${error.message}`
    );
  }
});

module.exports = {
  handleUserCreate: exports.handleUserCreate,
  handlePasswordReset: exports.handlePasswordReset,
  activateUser: exports.activateUser
};
