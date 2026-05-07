/**
 * Create permission types for the school
 * Frontend expects: schools/{schoolId}/permissionTypes/{typeId}
 */

const admin = require('firebase-admin');
const serviceAccount = require('../service-account-key.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function createPermissionTypes() {
  try {
    const schoolId = 'RMqzF9Gtx8j8ts5umDlt';
    
    console.log('Creating permission types...\n');
    
    const now = admin.firestore.FieldValue.serverTimestamp();
    
    const permissionTypes = [
      {
        name: 'Medical Appointment',
        defaultLimit: 2,
        isActive: true
      },
      {
        name: 'Personal Work',
        defaultLimit: 2,
        isActive: true
      },
      {
        name: 'Family Emergency',
        defaultLimit: 1,
        isActive: true
      },
      {
        name: 'Official Work',
        defaultLimit: 3,
        isActive: true
      }
    ];
    
    for (const type of permissionTypes) {
      await db
        .collection('schools')
        .doc(schoolId)
        .collection('permissionTypes')
        .add({
          schoolId: schoolId,
          name: type.name,
          defaultLimit: type.defaultLimit,
          isActive: type.isActive,
          createdAt: now,
          updatedAt: now
        });
      
      console.log(`  ✅ Created: ${type.name} (Limit: ${type.defaultLimit}/month)`);
    }
    
    console.log('\n✅ Permission types created successfully!');
    console.log('Staff can now select from these types when requesting permission.');
    
    process.exit(0);
  } catch (error) {
    console.error('❌ Error:', error);
    process.exit(1);
  }
}

createPermissionTypes();
