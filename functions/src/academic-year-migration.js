const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Initialize Firebase Admin if not already initialized
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

/**
 * Migrates academic year codes from 2-digit format (e.g., "2026-27") to 4-digit format (e.g., "2026-2027")
 * across all Firestore collections.
 * 
 * Usage: Call this function once to migrate all existing data.
 * After migration, the app will consistently use 4-digit format.
 */
exports.migrateAcademicYearFormat = functions.https.onCall(async (data, context) => {
  // Verify the caller is an admin (optional - remove if you want to allow anyone to run)
  // if (!context.auth) {
  //   throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  // }

  const results = {
    students: { updated: 0, skipped: 0, errors: [] },
    feeStructures: { updated: 0, skipped: 0, errors: [] },
    academicYears: { updated: 0, skipped: 0, errors: [] },
    fiscalYears: { updated: 0, skipped: 0, errors: [] }
  };

  try {
    // Get all schools
    const schoolsSnapshot = await db.collection('schools').get();
    console.log(`Found ${schoolsSnapshot.size} schools to migrate`);

    for (const schoolDoc of schoolsSnapshot.docs) {
      const schoolId = schoolDoc.id;
      console.log(`\n=== Processing school: ${schoolId} ===`);

      // Migrate students
      await migrateStudents(schoolId, results.students);

      // Migrate fee structures v2
      await migrateFeeStructures(schoolId, results.feeStructures);

      // Migrate academic years
      await migrateAcademicYears(schoolId, results.academicYears);

      // Migrate fiscal years
      await migrateFiscalYears(schoolId, results.fiscalYears);
    }

    console.log('\n=== Migration Summary ===');
    console.log(JSON.stringify(results, null, 2));

    return {
      success: true,
      message: 'Migration completed successfully',
      results
    };

  } catch (error) {
    console.error('Migration failed:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

/**
 * Migrates student academic year codes
 */
async function migrateStudents(schoolId, result) {
  try {
    const studentsSnapshot = await db.collection('schools')
      .doc(schoolId)
      .collection('students')
      .get();

    console.log(`  Found ${studentsSnapshot.size} students`);

    for (const studentDoc of studentsSnapshot.docs) {
      const data = studentDoc.data();
      const oldYearCode = data.academicYearCode;

      if (oldYearCode && oldYearCode.match(/^\d{4}-\d{2}$/)) {
        const newYearCode = convertTo4DigitFormat(oldYearCode);
        await studentDoc.ref.update({ academicYearCode: newYearCode });
        result.updated++;
        console.log(`  ✓ Student ${studentDoc.id}: ${oldYearCode} -> ${newYearCode}`);
      } else {
        result.skipped++;
      }
    }
  } catch (error) {
    result.errors.push(error.message);
    console.error('  Error migrating students:', error);
  }
}

/**
 * Migrates fee structure academic years
 */
async function migrateFeeStructures(schoolId, result) {
  try {
    const feeStructuresSnapshot = await db.collection('schools')
      .doc(schoolId)
      .collection('fee_structures_v2')
      .get();

    console.log(`  Found ${feeStructuresSnapshot.size} fee structures`);

    for (const structureDoc of feeStructuresSnapshot.docs) {
      const data = structureDoc.data();
      const oldYearCode = data.academicYear;

      if (oldYearCode && oldYearCode.match(/^\d{4}-\d{2}$/)) {
        const newYearCode = convertTo4DigitFormat(oldYearCode);
        await structureDoc.ref.update({ academicYear: newYearCode });
        result.updated++;
        console.log(`  ✓ Fee structure ${structureDoc.id}: ${oldYearCode} -> ${newYearCode}`);
      } else {
        result.skipped++;
      }
    }
  } catch (error) {
    result.errors.push(error.message);
    console.error('  Error migrating fee structures:', error);
  }
}

/**
 * Migrates academic year documents
 */
async function migrateAcademicYears(schoolId, result) {
  try {
    const academicYearsSnapshot = await db.collection('schools')
      .doc(schoolId)
      .collection('academicYears')
      .get();

    console.log(`  Found ${academicYearsSnapshot.size} academic years`);

    for (const ayDoc of academicYearsSnapshot.docs) {
      const data = ayDoc.data();
      const oldYearCode = data.yearCode;

      if (oldYearCode && oldYearCode.match(/^\d{4}-\d{2}$/)) {
        const newYearCode = convertTo4DigitFormat(oldYearCode);
        await ayDoc.ref.update({ yearCode: newYearCode });
        result.updated++;
        console.log(`  ✓ Academic year ${ayDoc.id}: ${oldYearCode} -> ${newYearCode}`);
      } else {
        result.skipped++;
      }
    }
  } catch (error) {
    result.errors.push(error.message);
    console.error('  Error migrating academic years:', error);
  }
}

/**
 * Migrates fiscal year documents
 */
async function migrateFiscalYears(schoolId, result) {
  try {
    const fiscalYearsSnapshot = await db.collection('schools')
      .doc(schoolId)
      .collection('fiscalYears')
      .get();

    console.log(`  Found ${fiscalYearsSnapshot.size} fiscal years`);

    for (const fyDoc of fiscalYearsSnapshot.docs) {
      const data = fyDoc.data();
      const oldYearCode = data.yearCode;

      if (oldYearCode && oldYearCode.match(/^\d{4}-\d{2}$/)) {
        const newYearCode = convertTo4DigitFormat(oldYearCode);
        await fyDoc.ref.update({ yearCode: newYearCode });
        result.updated++;
        console.log(`  ✓ Fiscal year ${fyDoc.id}: ${oldYearCode} -> ${newYearCode}`);
      } else {
        result.skipped++;
      }
    }
  } catch (error) {
    result.errors.push(error.message);
    console.error('  Error migrating fiscal years:', error);
  }
}

/**
 * Converts 2-digit year format to 4-digit format
 * Example: "2026-27" -> "2026-2027"
 */
function convertTo4DigitFormat(oldYearCode) {
  const parts = oldYearCode.split('-');
  if (parts.length !== 2) return oldYearCode;
  
  const startYear = parseInt(parts[0], 10);
  const endYear = startYear + 1;
  
  return `${startYear}-${endYear}`;
}
