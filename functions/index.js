const functions = require('firebase-functions/v1').region('asia-south1');
const admin = require('firebase-admin');

admin.initializeApp();

// Import modular functions
const leaveManagement = require('./src/leave-management');
const authManagement = require('./src/auth-management');
const rfidAttendance = require('./src/rfid-attendance/index');

// Export leave management functions
exports.handleLeaveApplicationCreate = leaveManagement.handleLeaveApplicationCreate;
exports.onLeaveStatusChange = leaveManagement.onLeaveStatusChange;

// Export permission management functions
exports.handlePermissionRequestCreate = leaveManagement.handlePermissionRequestCreate;
exports.onPermissionStatusChange = leaveManagement.onPermissionStatusChange;

// Export auth management functions
exports.handleUserCreate = authManagement.handleUserCreate;
exports.handlePasswordReset = authManagement.handlePasswordReset;
exports.activateUser = authManagement.activateUser;

// Export RFID attendance functions
exports.rfidApi = rfidAttendance.api;
exports.onAttendanceCreate = rfidAttendance.onAttendanceCreate;

// Export WhatsApp notification functions
const whatsappReminders = require('./src/whatsapp-fee-reminders');
exports.testWhatsAppConfiguration = whatsappReminders.testWhatsAppConfiguration;
exports.sendPaymentNotification = whatsappReminders.sendPaymentNotification;

// Export data cleanup functions
try {
  const dataCleanup = require('./src/data-cleanup');
  exports.standardizeAcademicYears = dataCleanup.standardizeAcademicYears;
  exports.previewAcademicYearCleanup = dataCleanup.previewAcademicYearCleanup;
  exports.validateAcademicYear = dataCleanup.validateAcademicYear;
  exports.validateLedgerAcademicYear = dataCleanup.validateLedgerAcademicYear;
  console.log('[Functions] Data cleanup functions loaded successfully');
} catch (error) {
  console.error('[Functions] Error loading data cleanup functions:', error.message);
}

// Export student phone update functions
try {
  const phoneUpdate = require('./src/student-phone-update');
  exports.updateAllStudentPhoneNumbers = phoneUpdate.updateAllStudentPhoneNumbers;
  exports.previewPhoneNumberUpdate = phoneUpdate.previewPhoneNumberUpdate;
  exports.revertStudentPhoneNumbers = phoneUpdate.revertStudentPhoneNumbers;
  exports.mapRfidToStaff = phoneUpdate.mapRfidToStaff;
  exports.listRfidCards = phoneUpdate.listRfidCards;
  exports.unmapRfidCard = phoneUpdate.unmapRfidCard;
  console.log('[Functions] Student phone update functions loaded successfully');
} catch (error) {
  console.error('[Functions] Error loading student phone update functions:', error.message);
}

// Export weekly due notification scheduler
try {
  const weeklyDueNotification = require('./src/weekly-due-notification');
  exports.sendWeeklyDueNotifications = weeklyDueNotification.sendWeeklyDueNotifications;
  console.log('[Functions] Weekly due notification scheduler loaded successfully');
} catch (error) {
  console.error('[Functions] Error loading weekly due notification scheduler:', error.message);
}

// Export combined daily jobs scheduler (includes attendance finalizer)
try {
  const combinedDailyJobs = require('./src/combined-daily-jobs');
  exports.runDailyJobs = combinedDailyJobs.runDailyJobs;
  console.log('[Functions] Combined daily jobs scheduler loaded successfully');
} catch (error) {
  console.error('[Functions] Error loading combined daily jobs scheduler:', error.message);
}

// Export leave and permission management functions
try {
  const leavePermissionMgmt = require('./src/leave-permission-management');
  exports.applyLeave = leavePermissionMgmt.applyLeave;
  exports.approveLeave = leavePermissionMgmt.approveLeave;
  exports.rejectLeave = leavePermissionMgmt.rejectLeave;
  exports.cancelLeave = leavePermissionMgmt.cancelLeave;
  exports.applyPermission = leavePermissionMgmt.applyPermission;
  exports.approvePermission = leavePermissionMgmt.approvePermission;
  exports.rejectPermission = leavePermissionMgmt.rejectPermission;
  exports.adjustLeaveBalance = leavePermissionMgmt.adjustLeaveBalance;
  exports.adjustPermissionBalance = leavePermissionMgmt.adjustPermissionBalance;
  exports.getLeaveTypes = leavePermissionMgmt.getLeaveTypes;
  exports.getPermissionConfig = leavePermissionMgmt.getPermissionConfig;
  console.log('[Functions] Leave and permission management functions loaded successfully');
} catch (error) {
  console.error('[Functions] Error loading leave and permission management functions:', error.message);
}

// RFID card management functions removed - using existing mapRfidToStaff and unmapRfidCard instead

// Export new TypeScript RFID Attendance & Leave functions
const {
  processRfidSwipe,
  dailyAttendanceFinalizer,
  validateLeaveApplication,
  updateLeaveBalanceOnApproval,
  validatePermissionRequest,
  updatePermissionUsageOnApproval,
} = require('./lib/index');

exports.processRfidSwipe = processRfidSwipe;
exports.dailyAttendanceFinalizer = dailyAttendanceFinalizer;
exports.validateLeaveApplication = validateLeaveApplication;
exports.updateLeaveBalanceOnApproval = updateLeaveBalanceOnApproval;
exports.validatePermissionRequest = validatePermissionRequest;
exports.updatePermissionUsageOnApproval = updatePermissionUsageOnApproval;

// Helper function to convert role string to claim flags
function roleToClaimFlags(role) {
  const isSuperAdmin = role === 'SUPER_ADMIN';
  const isAdmin = role === 'ADMIN' || role === 'tenant_admin';
  const isStaff = role === 'STAFF';
  
  return {
    superAdmin: isSuperAdmin,
    admin: isAdmin,
    staff: isStaff
  };
}

// Cloud Function to set custom claims based on user document
exports.setCustomClaims = functions.https.onCall(async (data, context) => {
  // Only allow authenticated users to call this function
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const uid = context.auth.uid;
  
  try {
    // Get user document from Firestore
    const userDoc = await admin.firestore().collection('users').doc(uid).get();
    
    if (!userDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'User document not found');
    }
    
    const userData = userDoc.data();
    const role = userData.role || 'STAFF';
    const roleFlags = roleToClaimFlags(role);
    
    // Set custom claims based on user document
    // These match the Firestore security rules expectations:
    // - superAdmin, admin, staff (boolean flags)
    // - schoolId (string)
    // - isActive (boolean)
    const customClaims = {
      ...roleFlags,
      schoolId: userData.schoolId || null,
      isActive: userData.isActive !== false // default to true if not explicitly false
    };
    
    await admin.auth().setCustomUserClaims(uid, customClaims);
    
    console.log(`✅ Custom claims set for user ${uid}:`, customClaims);
    
    return {
      success: true,
      claims: customClaims,
      message: 'Custom claims set successfully. Please sign out and sign in again to apply changes.'
    };
  } catch (error) {
    console.error('Error setting custom claims:', error);
    throw new functions.https.HttpsError('internal', 'Failed to set custom claims');
  }
});

// Cloud Function: Set custom claims for a user
exports.setUserClaims = functions.https.onCall(async (data, context) => {
  // Check if request is made by an authenticated user
  if (!context.auth) {
    throw new functions.https.HttpsError('failed-precondition', 'The function must be called while authenticated.');
  }

  const { uid, claims } = data;

  if (!uid || !claims) {
    throw new functions.https.HttpsError('invalid-argument', 'The function must be called with uid and claims.');
  }

  try {
    // Set custom claims for the user
    await admin.auth().setCustomUserClaims(uid, claims);
    
    // Force token refresh by updating a field in the user document
    const userRef = admin.firestore().collection('users').doc(uid);
    await userRef.update({
      claimsUpdatedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    return { message: 'Claims set successfully', uid, claims };
  } catch (error) {
    console.error('Error setting custom claims:', error);
    throw new functions.https.HttpsError('internal', 'Unable to set custom claims.');
  }
});

// Cloud Function: Initialize teacher balances when a new teacher is created
exports.onTeacherCreate = functions.firestore
  .document('teachers/{teacherId}')
  .onCreate(async (snap, context) => {
    const teacherId = context.params.teacherId;
    const teacherData = snap.data();
    const schoolId = teacherData.schoolId;
    
    console.log(`🔄 [CLOUD_FUNCTION] Teacher created: ${teacherId} (${teacherData.name}) in school: ${schoolId}`);
    
    if (!schoolId) {
      console.error(`❌ [CLOUD_FUNCTION] No schoolId found for teacher ${teacherId}`);
      return;
    }
    
    try {
      const db = admin.firestore();
      const batch = db.batch();
      
      // Get all active leave types for this school
      const leaveTypesSnapshot = await db
        .collection('leave_types')
        .where('schoolId', '==', schoolId)
        .where('isActive', '==', true)
        .get();
      
      // Get all active permission types for this school
      const permissionTypesSnapshot = await db
        .collection('permission_types')
        .where('schoolId', '==', schoolId)
        .where('isActive', '==', true)
        .get();
      
      // Prepare leave balances
      const leaveBalances = {};
      leaveTypesSnapshot.forEach(doc => {
        const data = doc.data();
        leaveBalances[doc.id] = data.defaultBalance || 0;
      });
      
      // Prepare permission limits
      const permissionLimits = {};
      permissionTypesSnapshot.forEach(doc => {
        const data = doc.data();
        permissionLimits[doc.id] = data.defaultLimit || 0;
      });
      
      // Update teacher document with balances
      const teacherRef = db.collection('teachers').doc(teacherId);
      batch.update(teacherRef, {
        leaveBalances,
        permissionLimits,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
      
      await batch.commit();
      
      console.log(`✅ [CLOUD_FUNCTION] Initialized ${Object.keys(leaveBalances).length} leave types and ${Object.keys(permissionLimits).length} permission types for teacher ${teacherId} in school ${schoolId}`);
      
    } catch (error) {
      console.error(`❌ [CLOUD_FUNCTION] Error initializing teacher balances for ${teacherId}:`, error);
    }
  });

// Cloud Function: Add new leave type to all active teachers in the same school
exports.onLeaveTypeCreate = functions.firestore
  .document('leave_types/{leaveTypeId}')
  .onCreate(async (snap, context) => {
    const leaveTypeId = context.params.leaveTypeId;
    const leaveTypeData = snap.data();
    const schoolId = leaveTypeData.schoolId;
    
    console.log(`🔄 [CLOUD_FUNCTION] Leave type created: ${leaveTypeId} (${leaveTypeData.name}) for school: ${schoolId}`);
    
    if (!schoolId) {
      console.error(`❌ [CLOUD_FUNCTION] No schoolId found for leave type ${leaveTypeId}`);
      return;
    }
    
    try {
      const db = admin.firestore();
      
      // Get all active teachers in the same school
      const teachersSnapshot = await db
        .collection('teachers')
        .where('schoolId', '==', schoolId)
        .where('isActive', '==', true)
        .get();
      
      if (teachersSnapshot.empty) {
        console.log(`ℹ️ [CLOUD_FUNCTION] No active teachers found in school ${schoolId} to update with leave type ${leaveTypeId}`);
        return;
      }
      
      const batch = db.batch();
      let batchCount = 0;
      
      // Add this leave type to all active teachers in the same school
      teachersSnapshot.forEach(teacherDoc => {
        const teacherRef = db.collection('teachers').doc(teacherDoc.id);
        batch.update(teacherRef, {
          [`leaveBalances.${leaveTypeId}`]: leaveTypeData.defaultBalance || 0,
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        });
        batchCount++;
        
        // Firestore batch limit is 500 operations
        if (batchCount >= 500) {
          console.warn(`⚠️ [CLOUD_FUNCTION] Batch limit reached. Only updating first 500 teachers for leave type ${leaveTypeId} in school ${schoolId}`);
          return false; // Break out of forEach
        }
      });
      
      await batch.commit();
      
      console.log(`✅ [CLOUD_FUNCTION] Added leave type ${leaveTypeId} to ${batchCount} active teachers in school ${schoolId}`);
      
    } catch (error) {
      console.error(`❌ [CLOUD_FUNCTION] Error adding leave type ${leaveTypeId} to teachers in school ${schoolId}:`, error);
    }
  });

// Cloud Function: Add new permission type to all active teachers in the same school
exports.onPermissionTypeCreate = functions.firestore
  .document('permission_types/{permissionTypeId}')
  .onCreate(async (snap, context) => {
    const permissionTypeId = context.params.permissionTypeId;
    const permissionTypeData = snap.data();
    const schoolId = permissionTypeData.schoolId;
    
    console.log(`🔄 [CLOUD_FUNCTION] Permission type created: ${permissionTypeId} (${permissionTypeData.name}) for school: ${schoolId}`);
    
    if (!schoolId) {
      console.error(`❌ [CLOUD_FUNCTION] No schoolId found for permission type ${permissionTypeId}`);
      return;
    }
    
    try {
      const db = admin.firestore();
      
      // Get all active teachers in the same school
      const teachersSnapshot = await db
        .collection('teachers')
        .where('schoolId', '==', schoolId)
        .where('isActive', '==', true)
        .get();
      
      if (teachersSnapshot.empty) {
        console.log(`ℹ️ [CLOUD_FUNCTION] No active teachers found in school ${schoolId} to update with permission type ${permissionTypeId}`);
        return;
      }
      
      // Process teachers in batches (Firestore limit: 500 operations per batch)
      const batchSize = 500;
      const teachers = teachersSnapshot.docs;
      
      for (let i = 0; i < teachers.length; i += batchSize) {
        const batch = db.batch();
        const batchTeachers = teachers.slice(i, i + batchSize);
        
        batchTeachers.forEach(teacherDoc => {
          const teacherRef = db.collection('teachers').doc(teacherDoc.id);
          batch.update(teacherRef, {
            [`permissionLimits.${permissionTypeId}`]: permissionTypeData.defaultLimit || 0,
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
          });
        });
        
        await batch.commit();
        console.log(`✅ [CLOUD_FUNCTION] Updated batch of ${batchTeachers.length} teachers with permission type ${permissionTypeId} in school ${schoolId}`);
      }
      
      console.log(`✅ [CLOUD_FUNCTION] Added permission type ${permissionTypeId} to ${teachers.length} active teachers in school ${schoolId}`);
      
    } catch (error) {
      console.error(`❌ [CLOUD_FUNCTION] Error adding permission type ${permissionTypeId} to teachers in school ${schoolId}:`, error);
    }
  });

// Trigger to automatically set custom claims when user document is created/updated
exports.onUserDocumentWrite = functions.firestore
  .document('users/{userId}')
  .onWrite(async (change, context) => {
    const userId = context.params.userId;
    
    // Skip if document was deleted
    if (!change.after.exists) {
      console.log(`⚠️ User document deleted: ${userId}`);
      return null;
    }
    
    const userData = change.after.data();
    const role = userData.role || 'STAFF';
    
    // Check if role or schoolId changed (to avoid unnecessary updates)
    if (change.before.exists) {
      const beforeData = change.before.data();
      const roleChanged = beforeData.role !== userData.role;
      const schoolChanged = beforeData.schoolId !== userData.schoolId;
      const activeChanged = beforeData.isActive !== userData.isActive;
      
      if (!roleChanged && !schoolChanged && !activeChanged) {
        console.log(`ℹ️ No relevant changes for user ${userId}, skipping claim update`);
        return null;
      }
    }
    
    try {
      const roleFlags = roleToClaimFlags(role);
      
      // Set custom claims based on user document
      // These match the Firestore security rules expectations:
      // - superAdmin, admin, staff (boolean flags)
      // - schoolId (string)
      // - isActive (boolean)
      const customClaims = {
        ...roleFlags,
        schoolId: userData.schoolId || null,
        isActive: userData.isActive !== false // default to true if not explicitly false
      };
      
      await admin.auth().setCustomUserClaims(userId, customClaims);
      
      console.log(`✅ Custom claims set for user ${userId}:`, customClaims);
      return null;
    } catch (error) {
      console.error(`❌ Error setting custom claims for user ${userId}:`, error);
      return null;
    }
  });
