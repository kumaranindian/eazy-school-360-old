/**
 * Student Phone Number Update Utilities
 * 
 * Updates all student phone numbers to a specified number
 * for testing/demo purposes.
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Initialize Firebase Admin if not already initialized
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

/**
 * HTTP Cloud Function: Update all student phone numbers to a specified number
 * Use with caution - this is for testing/demo purposes only
 */
exports.updateAllStudentPhoneNumbers = functions.https.onCall(async (data, context) => {
  // Authentication temporarily disabled for testing purposes
  // if (!context.auth) {
  //   throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  // }
  
  // Admin role check temporarily disabled for testing purposes
  // const userDoc = await db.collection('users').doc(context.auth.uid).get();
  // if (!userDoc.exists || userDoc.data().role !== 'admin') {
  //   throw new functions.https.HttpsError('permission-denied', 'Only admins can run this function');
  // }
  
  const schoolId = data.schoolId;
  const newPhoneNumber = data.phoneNumber || '+918508196981';
  
  if (!schoolId) {
    throw new functions.https.HttpsError('invalid-argument', 'schoolId is required');
  }
  
  // Validate phone number format
  if (!newPhoneNumber.startsWith('+') || newPhoneNumber.length < 10) {
    throw new functions.https.HttpsError(
      'invalid-argument', 
      'Phone number must be in E.164 format (e.g., +918508196981)'
    );
  }
  
  const batch = db.batch();
  let updateCount = 0;
  let errorCount = 0;
  const errors = [];
  
  try {
    console.log(`[UpdatePhones] Starting update for school: ${schoolId}`);
    console.log(`[UpdatePhones] New phone number: ${newPhoneNumber}`);
    
    // Get all students for the school
    const studentsSnapshot = await db
      .collection('schools')
      .doc(schoolId)
      .collection('students')
      .get();
    
    console.log(`[UpdatePhones] Found ${studentsSnapshot.docs.length} students`);
    
    // Also update student_fee_details collection
    const feeDetailsSnapshot = await db
      .collection('schools')
      .doc(schoolId)
      .collection('student_fee_details')
      .get();
    
    console.log(`[UpdatePhones] Found ${feeDetailsSnapshot.docs.length} fee detail records`);
    
    // Process in batches (Firestore batch limit is 500 operations)
    const batchSize = 450; // Leave some room for other operations
    let currentBatch = db.batch();
    let currentBatchSize = 0;
    let batchCount = 1;
    
    // Update students collection
    for (const doc of studentsSnapshot.docs) {
      const studentData = doc.data();
      const currentPhone = studentData['phoneNumber'];
      const currentParentPhone = studentData['parentPhone'];
      
      // Only update if different
      if (currentPhone !== newPhoneNumber || currentParentPhone !== newPhoneNumber) {
        currentBatch.update(doc.ref, {
          'phoneNumber': newPhoneNumber,
          'parentPhone': newPhoneNumber,
          'updatedAt': admin.firestore.FieldValue.serverTimestamp(),
        });
        
        currentBatchSize++;
        updateCount++;
        
        // Commit batch when it reaches the limit
        if (currentBatchSize >= batchSize) {
          console.log(`[UpdatePhones] Committing batch ${batchCount} (${currentBatchSize} operations)`);
          await currentBatch.commit();
          batchCount++;
          currentBatch = db.batch();
          currentBatchSize = 0;
        }
      }
    }
    
    // Update student_fee_details collection
    for (const doc of feeDetailsSnapshot.docs) {
      const feeData = doc.data();
      const currentPhone = feeData['phoneNumber'];
      
      // Only update if different
      if (currentPhone !== newPhoneNumber) {
        currentBatch.update(doc.ref, {
          'phoneNumber': newPhoneNumber,
          'updatedAt': admin.firestore.FieldValue.serverTimestamp(),
        });
        
        currentBatchSize++;
        updateCount++;
        
        // Commit batch when it reaches the limit
        if (currentBatchSize >= batchSize) {
          console.log(`[UpdatePhones] Committing batch ${batchCount} (${currentBatchSize} operations)`);
          await currentBatch.commit();
          batchCount++;
          currentBatch = db.batch();
          currentBatchSize = 0;
        }
      }
    }
    
    // Commit any remaining operations
    if (currentBatchSize > 0) {
      console.log(`[UpdatePhones] Committing final batch ${batchCount} (${currentBatchSize} operations)`);
      await currentBatch.commit();
    }
    
    console.log(`[UpdatePhones] Completed. Updated ${updateCount} documents.`);
    
    return {
      success: true,
      message: `Successfully updated ${updateCount} student records`,
      details: {
        studentsUpdated: updateCount,
        errors: errorCount,
        newPhoneNumber: newPhoneNumber,
      },
    };
    
  } catch (error) {
    console.error('[UpdatePhones] Error:', error);
    throw new functions.https.HttpsError('internal', `Update failed: ${error.message}`);
  }
});

/**
 * HTTP Cloud Function: Preview what would be changed without making changes
 */
exports.previewPhoneNumberUpdate = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }
  
  const schoolId = data.schoolId;
  const newPhoneNumber = data.phoneNumber || '+918508196981';
  
  if (!schoolId) {
    throw new functions.https.HttpsError('invalid-argument', 'schoolId is required');
  }
  
  try {
    // Get all students for the school
    const studentsSnapshot = await db
      .collection('schools')
      .doc(schoolId)
      .collection('students')
      .get();
    
    const feeDetailsSnapshot = await db
      .collection('schools')
      .doc(schoolId)
      .collection('student_fee_details')
      .get();
    
    let wouldUpdateCount = 0;
    const preview = [];
    
    // Preview students that would be updated
    for (const doc of studentsSnapshot.docs.take(10)) { // Show first 10 only
      const studentData = doc.data();
      const currentPhone = studentData['phoneNumber'];
      const studentName = studentData['studentName'] || studentData['name'] || 'Unknown';
      
      if (currentPhone !== newPhoneNumber) {
        wouldUpdateCount++;
        preview.push({
          collection: 'students',
          id: doc.id,
          studentName: studentName,
          currentPhone: currentPhone,
          newPhone: newPhoneNumber,
        });
      }
    }
    
    const totalStudents = studentsSnapshot.docs.length;
    const totalFeeDetails = feeDetailsSnapshot.docs.length;
    
    // Estimate total updates (students + fee details)
    const estimatedUpdates = totalStudents + totalFeeDetails;
    
    return {
      success: true,
      preview: {
        sampleUpdates: preview,
        totalStudents: totalStudents,
        totalFeeDetails: totalFeeDetails,
        estimatedUpdates: estimatedUpdates,
        newPhoneNumber: newPhoneNumber,
        message: `Would update approximately ${estimatedUpdates} records to ${newPhoneNumber}`,
      },
    };
    
  } catch (error) {
    console.error('[PreviewPhones] Error:', error);
    throw new functions.https.HttpsError('internal', `Preview failed: ${error.message}`);
  }
});

/**
 * HTTP Cloud Function: Map RFID card to staff/student
 * Admin can assign an RFID card to a staff member or student
 */
exports.mapRfidToStaff = functions.https.onCall(async (data, context) => {
  // Require authentication
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }
  
  // Require admin role
  const userDoc = await db.collection('users').doc(context.auth.uid).get();
  if (!userDoc.exists || userDoc.data().role !== 'admin') {
    throw new functions.https.HttpsError('permission-denied', 'Only admins can run this function');
  }
  
  const { schoolId, rfidTag, staffId, studentId } = data;
  
  if (!schoolId || !rfidTag) {
    throw new functions.https.HttpsError('invalid-argument', 'schoolId and rfidTag are required');
  }
  
  if (!staffId && !studentId) {
    throw new functions.https.HttpsError('invalid-argument', 'Either staffId or studentId is required');
  }
  
  try {
    // Check if RFID card exists
    const rfidCardDoc = await db
      .collection('schools')
      .doc(schoolId)
      .collection('rfid_cards')
      .doc(rfidTag)
      .get();
    
    if (!rfidCardDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'RFID card not found. Please register the card first.');
    }
    
    // Verify staff/student exists
    const targetId = staffId || studentId;
    const targetCollection = staffId ? 'staff' : 'students';
    
    const targetDoc = await db
      .collection('schools')
      .doc(schoolId)
      .collection(targetCollection)
      .doc(targetId)
      .get();
    
    if (!targetDoc.exists) {
      throw new functions.https.HttpsError('not-found', `${staffId ? 'Staff' : 'Student'} not found in this school`);
    }
    
    // Update RFID card with mapping
    await db
      .collection('schools')
      .doc(schoolId)
      .collection('rfid_cards')
      .doc(rfidTag)
      .update({
        staffId: staffId || null,
        studentId: studentId || null,
        isAssigned: true,
        assignedAt: admin.firestore.FieldValue.serverTimestamp(),
        assignedBy: context.auth.uid
      });
    
    console.log(`[MapRfid] Mapped RFID ${rfidTag} to ${staffId ? 'staff' : 'student'} ${targetId}`);
    
    return {
      success: true,
      message: `RFID card mapped successfully to ${staffId ? 'staff' : 'student'}`,
      data: {
        rfidTag,
        schoolId,
        staffId: staffId || null,
        studentId: studentId || null,
        isAssigned: true,
        assignedAt: new Date().toISOString()
      }
    };
    
  } catch (error) {
    console.error('[MapRfid] Error:', error);
    throw new functions.https.HttpsError('internal', `Failed to map RFID card: ${error.message}`);
  }
});

/**
 * HTTP Cloud Function: List all RFID cards for a school
 * Admin can view all registered RFID cards and their assignments
 */
exports.listRfidCards = functions.https.onCall(async (data, context) => {
  // Require authentication
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }
  
  // Require admin role
  const userDoc = await db.collection('users').doc(context.auth.uid).get();
  if (!userDoc.exists || userDoc.data().role !== 'admin') {
    throw new functions.https.HttpsError('permission-denied', 'Only admins can run this function');
  }
  
  const { schoolId } = data;
  
  if (!schoolId) {
    throw new functions.https.HttpsError('invalid-argument', 'schoolId is required');
  }
  
  try {
    // Get all RFID cards for the school
    const rfidCardsSnapshot = await db
      .collection('schools')
      .doc(schoolId)
      .collection('rfid_cards')
      .get();
    
    const cards = [];
    
    for (const doc of rfidCardsSnapshot.docs) {
      const cardData = doc.data();
      const card = {
        rfidTag: doc.id,
        schoolId: cardData.schoolId,
        isAssigned: cardData.isAssigned || false,
        staffId: cardData.staffId || null,
        studentId: cardData.studentId || null,
        registeredAt: cardData.registeredAt?.toDate?.() || cardData.registeredAt,
        assignedAt: cardData.assignedAt?.toDate?.() || cardData.assignedAt,
        isActive: cardData.isActive !== false
      };
      
      // Fetch staff/student details if assigned
      if (cardData.staffId) {
        const staffDoc = await db
          .collection('schools')
          .doc(schoolId)
          .collection('staff')
          .doc(cardData.staffId)
          .get();
        
        if (staffDoc.exists) {
          card.staffName = staffDoc.data().name || staffDoc.data().displayName || 'Unknown';
        }
      }
      
      if (cardData.studentId) {
        const studentDoc = await db
          .collection('schools')
          .doc(schoolId)
          .collection('students')
          .doc(cardData.studentId)
          .get();
        
        if (studentDoc.exists) {
          card.studentName = studentDoc.data().studentName || studentDoc.data().name || 'Unknown';
        }
      }
      
      cards.push(card);
    }
    
    return {
      success: true,
      data: {
        schoolId,
        totalCards: cards.length,
        assignedCards: cards.filter(c => c.isAssigned).length,
        unassignedCards: cards.filter(c => !c.isAssigned).length,
        cards
      }
    };
    
  } catch (error) {
    console.error('[ListRfidCards] Error:', error);
    throw new functions.https.HttpsError('internal', `Failed to list RFID cards: ${error.message}`);
  }
});

/**
 * HTTP Cloud Function: Unmap RFID card from staff/student
 * Admin can remove the mapping from an RFID card
 */
exports.unmapRfidCard = functions.https.onCall(async (data, context) => {
  // Require authentication
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }
  
  // Require admin role
  const userDoc = await db.collection('users').doc(context.auth.uid).get();
  if (!userDoc.exists || userDoc.data().role !== 'admin') {
    throw new functions.https.HttpsError('permission-denied', 'Only admins can run this function');
  }
  
  const { schoolId, rfidTag } = data;
  
  if (!schoolId || !rfidTag) {
    throw new functions.https.HttpsError('invalid-argument', 'schoolId and rfidTag are required');
  }
  
  try {
    // Check if RFID card exists
    const rfidCardDoc = await db
      .collection('schools')
      .doc(schoolId)
      .collection('rfid_cards')
      .doc(rfidTag)
      .get();
    
    if (!rfidCardDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'RFID card not found');
    }
    
    // Remove mapping
    await db
      .collection('schools')
      .doc(schoolId)
      .collection('rfid_cards')
      .doc(rfidTag)
      .update({
        staffId: null,
        studentId: null,
        isAssigned: false,
        unassignedAt: admin.firestore.FieldValue.serverTimestamp(),
        unassignedBy: context.auth.uid
      });
    
    console.log(`[UnmapRfid] Unmapped RFID ${rfidTag}`);
    
    return {
      success: true,
      message: 'RFID card unmapped successfully',
      data: {
        rfidTag,
        schoolId,
        isAssigned: false,
        unassignedAt: new Date().toISOString()
      }
    };
    
  } catch (error) {
    console.error('[UnmapRfid] Error:', error);
    throw new functions.https.HttpsError('internal', `Failed to unmap RFID card: ${error.message}`);
  }
});
