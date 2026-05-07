/**
 * Fix permission configuration location
 * The frontend expects config at: schools/{schoolId}/permissionConfig/default
 * We created it at: schools/{schoolId}/settings/permission
 * 
 * This script creates the config in the correct location with correct fields
 */

const admin = require('firebase-admin');
const serviceAccount = require('../service-account-key.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function fixPermissionConfig() {
  try {
    const schoolId = 'RMqzF9Gtx8j8ts5umDlt';
    const adminUserId = 'nkxvUTFv5IsBPAPNchwK'; // Replace with actual admin user ID
    
    console.log('Creating permission configuration in correct location...\n');
    
    const now = admin.firestore.FieldValue.serverTimestamp();
    
    // Create config in the location frontend expects
    await db
      .collection('schools')
      .doc(schoolId)
      .collection('permissionConfig')
      .doc('default')
      .set({
        schoolId: schoolId,
        monthlyLimit: 4,                    // Max 4 permissions per month
        maxDurationMinutes: 240,            // Max 4 hours (240 minutes)
        requiresApproval: true,
        isActive: true,
        createdAt: now,
        updatedAt: now,
        createdBy: adminUserId,
        customRules: {
          minDurationMinutes: 30,           // Min 30 minutes (0.5 hours)
          allowedDays: ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday']
        }
      });
    
    console.log('✅ Permission configuration created at:');
    console.log(`   schools/${schoolId}/permissionConfig/default`);
    console.log('\nConfiguration:');
    console.log('  - Monthly Limit: 4 permissions');
    console.log('  - Max Duration: 240 minutes (4 hours)');
    console.log('  - Min Duration: 30 minutes (0.5 hours)');
    console.log('  - Requires Approval: Yes');
    console.log('  - Status: Active');
    
    console.log('\n✅ Configuration fixed successfully!');
    console.log('The "Request Permission" screen should now work.');
    
    process.exit(0);
  } catch (error) {
    console.error('❌ Error:', error);
    process.exit(1);
  }
}

fixPermissionConfig();
