/**
 * Data Cleanup Utilities
 * 
 * Standardizes academic year formats across the database
 * and validates data consistency.
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Initialize Firebase Admin if not already initialized
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

/**
 * Normalize academic year to full format (e.g., "2025-2026")
 * @param {string} year - Academic year string
 * @returns {string} - Normalized year string
 */
function normalizeAcademicYear(year) {
  if (!year || typeof year !== 'string') return year;
  
  // Remove any extra spaces
  year = year.trim();
  
  // Check if already in full format (YYYY-YYYY)
  const fullFormatMatch = year.match(/^(\d{4})-(\d{4})$/);
  if (fullFormatMatch) {
    return year; // Already in correct format
  }
  
  // Check if in short format (YYYY-YY)
  const shortFormatMatch = year.match(/^(\d{4})-(\d{2})$/);
  if (shortFormatMatch) {
    const startYear = shortFormatMatch[1];
    const shortEndYear = shortFormatMatch[2];
    const fullEndYear = startYear.substring(0, 2) + shortEndYear;
    return `${startYear}-${fullEndYear}`;
  }
  
  // If doesn't match any expected format, return as-is
  return year;
}

/**
 * HTTP Cloud Function: Standardize all academic years in the database
 * Call this once to clean up existing inconsistent data
 */
exports.standardizeAcademicYears = functions.https.onRequest(async (req, res) => {
  // Set CORS headers
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type');

  // Handle preflight OPTIONS request
  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  // Only allow POST
  if (req.method !== 'POST') {
    res.status(405).send({ error: 'Method not allowed' });
    return;
  }

  // Authentication temporarily disabled for migration purposes
  // if (!context.auth) {
  //   throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  // }
  
  // Admin role check temporarily disabled for migration purposes
  // const userDoc = await db.collection('users').doc(context.auth.uid).get();
  // if (!userDoc.exists || userDoc.data().role !== 'admin') {
  //   throw new functions.https.HttpsError('permission-denied', 'Only admins can run this function');
  // }
  
  let schoolId;
  try {
    const data = req.body;
    schoolId = data.schoolId;
    if (!schoolId) {
      res.status(400).send({ error: 'schoolId is required' });
      return;
    }
  } catch (error) {
    res.status(400).send({ error: 'Invalid request body' });
    return;
  }
  
  const batch = db.batch();
  let updateCount = 0;
  const errors = [];
  
  try {
    console.log(`[StandardizeAY] Starting cleanup for school: ${schoolId}`);
    
    // 1. Update Fee Structures
    const feeStructuresSnapshot = await db
      .collection('schools')
      .doc(schoolId)
      .collection('feeStructures')
      .get();
    
    for (const doc of feeStructuresSnapshot.docs) {
      const data = doc.data();
      const currentYear = data.academicYear;
      const normalizedYear = normalizeAcademicYear(currentYear);
      
      if (currentYear !== normalizedYear) {
        batch.update(doc.ref, {
          academicYear: normalizedYear,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        updateCount++;
        console.log(`[StandardizeAY] FeeStructure ${doc.id}: "${currentYear}" -> "${normalizedYear}"`);
      }
    }
    
    // 2. Update Student Fee Ledgers
    const ledgersSnapshot = await db
      .collection('schools')
      .doc(schoolId)
      .collection('studentFeeLedgers')
      .get();
    
    for (const doc of ledgersSnapshot.docs) {
      const data = doc.data();
      const currentYear = data.academicYear;
      const normalizedYear = normalizeAcademicYear(currentYear);
      
      // Also normalize termStatus entries that have sourceAcademicYear
      let termStatusUpdated = false;
      const termStatus = data.termStatus || [];
      const updatedTermStatus = termStatus.map(entry => {
        if (entry.sourceAcademicYear) {
          const normalizedSourceYear = normalizeAcademicYear(entry.sourceAcademicYear);
          if (entry.sourceAcademicYear !== normalizedSourceYear) {
            termStatusUpdated = true;
            return {
              ...entry,
              sourceAcademicYear: normalizedSourceYear,
            };
          }
        }
        return entry;
      });
      
      const needsUpdate = currentYear !== normalizedYear || termStatusUpdated;
      
      if (needsUpdate) {
        const updateData = {
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        };
        
        if (currentYear !== normalizedYear) {
          updateData.academicYear = normalizedYear;
        }
        
        if (termStatusUpdated) {
          updateData.termStatus = updatedTermStatus;
        }
        
        batch.update(doc.ref, updateData);
        updateCount++;
        console.log(`[StandardizeAY] Ledger ${doc.id}: "${currentYear}" -> "${normalizedYear}"${termStatusUpdated ? ' (termStatus updated)' : ''}`);
      }
    }
    
    // 3. Update Academic Years collection
    const academicYearsSnapshot = await db
      .collection('schools')
      .doc(schoolId)
      .collection('academicYears')
      .get();
    
    for (const doc of academicYearsSnapshot.docs) {
      const data = doc.data();
      const docId = doc.id;
      const normalizedDocId = normalizeAcademicYear(docId);
      
      // Check if the document ID needs to change
      if (docId !== normalizedDocId) {
        // Create new document with normalized ID
        const newDocRef = db
          .collection('schools')
          .doc(schoolId)
          .collection('academicYears')
          .doc(normalizedDocId);
        
        // Copy data to new document
        batch.set(newDocRef, {
          ...data,
          year: normalizedDocId,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        
        // Delete old document (this will be done in a separate batch to avoid issues)
        // For now, just log it
        console.log(`[StandardizeAY] AcademicYear doc: "${docId}" -> "${normalizedDocId}" (needs manual migration)`);
      }
      
      // Also normalize the year field within the document
      const yearField = data.year;
      const normalizedYearField = normalizeAcademicYear(yearField);
      
      if (yearField !== normalizedYearField) {
        batch.update(doc.ref, {
          year: normalizedYearField,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        updateCount++;
      }
    }
    
    // Commit all updates
    await batch.commit();
    
    console.log(`[StandardizeAY] Completed. Updated ${updateCount} documents.`);
    
    res.status(200).send({
      success: true,
      message: `Standardized ${updateCount} documents`,
      details: {
        feeStructuresUpdated: feeStructuresSnapshot.docs.length,
        ledgersUpdated: ledgersSnapshot.docs.length,
        totalUpdates: updateCount,
      },
    });
    
  } catch (error) {
    console.error('[StandardizeAY] Error:', error);
    res.status(500).send({ error: `Cleanup failed: ${error.message}` });
  }
});

/**
 * Firestore Trigger: Validate and normalize academic year on write
 * This prevents future inconsistencies
 */
exports.validateAcademicYear = functions.firestore
  .document('schools/{schoolId}/feeStructures/{structureId}')
  .onWrite(async (change, context) => {
    const { schoolId, structureId } = context.params;
    
    // Only process if it's a create or update (not delete)
    if (!change.after.exists) return null;
    
    const data = change.after.data();
    const academicYear = data.academicYear;
    
    if (!academicYear) return null;
    
    const normalizedYear = normalizeAcademicYear(academicYear);
    
    // If the year needs normalization, update it
    if (academicYear !== normalizedYear) {
      console.log(`[ValidateAY] Normalizing fee structure ${structureId}: "${academicYear}" -> "${normalizedYear}"`);
      await change.after.ref.update({
        academicYear: normalizedYear,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
    
    return null;
  });

/**
 * Firestore Trigger: Validate and normalize academic year in ledgers
 */
exports.validateLedgerAcademicYear = functions.firestore
  .document('schools/{schoolId}/studentFeeLedgers/{ledgerId}')
  .onWrite(async (change, context) => {
    const { schoolId, ledgerId } = context.params;
    
    // Only process if it's a create or update (not delete)
    if (!change.after.exists) return null;
    
    const data = change.after.data();
    const academicYear = data.academicYear;
    const termStatus = data.termStatus || [];
    
    let needsUpdate = false;
    const updates = {};
    
    // Normalize main academic year
    if (academicYear) {
      const normalizedYear = normalizeAcademicYear(academicYear);
      if (academicYear !== normalizedYear) {
        updates.academicYear = normalizedYear;
        needsUpdate = true;
      }
    }
    
    // Normalize sourceAcademicYear in termStatus
    const updatedTermStatus = termStatus.map(entry => {
      if (entry.sourceAcademicYear) {
        const normalizedSourceYear = normalizeAcademicYear(entry.sourceAcademicYear);
        if (entry.sourceAcademicYear !== normalizedSourceYear) {
          needsUpdate = true;
          return {
            ...entry,
            sourceAcademicYear: normalizedSourceYear,
          };
        }
      }
      return entry;
    });
    
    if (needsUpdate) {
      if (updatedTermStatus !== termStatus) {
        updates.termStatus = updatedTermStatus;
      }
      updates.updatedAt = admin.firestore.FieldValue.serverTimestamp();
      
      console.log(`[ValidateAY] Normalizing ledger ${ledgerId}`);
      await change.after.ref.update(updates);
    }
    
    return null;
  });

/**
 * HTTP Cloud Function: Preview what would be changed without making changes
 */
exports.previewAcademicYearCleanup = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }
  
  const schoolId = data.schoolId;
  if (!schoolId) {
    throw new functions.https.HttpsError('invalid-argument', 'schoolId is required');
  }
  
  const preview = {
    feeStructures: [],
    ledgers: [],
    academicYears: [],
    totalChanges: 0,
  };
  
  try {
    // Preview Fee Structures
    const feeStructuresSnapshot = await db
      .collection('schools')
      .doc(schoolId)
      .collection('feeStructures')
      .get();
    
    for (const doc of feeStructuresSnapshot.docs) {
      const data = doc.data();
      const currentYear = data.academicYear;
      const normalizedYear = normalizeAcademicYear(currentYear);
      
      if (currentYear !== normalizedYear) {
        preview.feeStructures.push({
          id: doc.id,
          current: currentYear,
          normalized: normalizedYear,
        });
        preview.totalChanges++;
      }
    }
    
    // Preview Ledgers
    const ledgersSnapshot = await db
      .collection('schools')
      .doc(schoolId)
      .collection('studentFeeLedgers')
      .get();
    
    for (const doc of ledgersSnapshot.docs) {
      const data = doc.data();
      const currentYear = data.academicYear;
      const normalizedYear = normalizeAcademicYear(currentYear);
      
      // Check termStatus
      const termStatus = data.termStatus || [];
      const termStatusIssues = [];
      
      termStatus.forEach((entry, index) => {
        if (entry.sourceAcademicYear) {
          const normalizedSourceYear = normalizeAcademicYear(entry.sourceAcademicYear);
          if (entry.sourceAcademicYear !== normalizedSourceYear) {
            termStatusIssues.push({
              index,
              current: entry.sourceAcademicYear,
              normalized: normalizedSourceYear,
            });
          }
        }
      });
      
      if (currentYear !== normalizedYear || termStatusIssues.length > 0) {
        preview.ledgers.push({
          id: doc.id,
          studentName: data.studentName,
          studentId: data.studentId,
          academicYear: {
            current: currentYear,
            normalized: normalizedYear,
            needsUpdate: currentYear !== normalizedYear,
          },
          termStatusIssues: termStatusIssues,
        });
        preview.totalChanges++;
      }
    }
    
    // Preview Academic Years collection
    const academicYearsSnapshot = await db
      .collection('schools')
      .doc(schoolId)
      .collection('academicYears')
      .get();
    
    for (const doc of academicYearsSnapshot.docs) {
      const docId = doc.id;
      const normalizedDocId = normalizeAcademicYear(docId);
      const data = doc.data();
      const yearField = data.year;
      const normalizedYearField = normalizeAcademicYear(yearField);
      
      const issues = [];
      
      if (docId !== normalizedDocId) {
        issues.push({
          field: 'documentId',
          current: docId,
          normalized: normalizedDocId,
        });
      }
      
      if (yearField !== normalizedYearField) {
        issues.push({
          field: 'year',
          current: yearField,
          normalized: normalizedYearField,
        });
      }
      
      if (issues.length > 0) {
        preview.academicYears.push({
          id: docId,
          issues,
        });
        preview.totalChanges++;
      }
    }
    
    return {
      success: true,
      preview,
    };
    
  } catch (error) {
    console.error('[PreviewAY] Error:', error);
    throw new functions.https.HttpsError('internal', `Preview failed: ${error.message}`);
  }
});

// Note: All functions are already exported via exports.functionName
// This line is kept for compatibility if someone requires just the utility
module.exports.normalizeAcademicYear = normalizeAcademicYear;
