/**
 * Verify permission configuration and types exist
 */

const admin = require('firebase-admin');
const serviceAccount = require('../service-account-key.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function verifyData() {
  try {
    const schoolId = 'RMqzF9Gtx8j8ts5umDlt';
    
    console.log('🔍 Verifying permission data...\n');
    
    // 1. Check permission config
    console.log('1. Checking Permission Config:');
    console.log('   Location: schools/' + schoolId + '/permissionConfig/default');
    
    const configDoc = await db
      .collection('schools')
      .doc(schoolId)
      .collection('permissionConfig')
      .doc('default')
      .get();
    
    if (configDoc.exists) {
      console.log('   ✅ Config EXISTS');
      const data = configDoc.data();
      console.log('   Data:', JSON.stringify(data, null, 2));
    } else {
      console.log('   ❌ Config DOES NOT EXIST');
    }
    
    // 2. Check permission types
    console.log('\n2. Checking Permission Types:');
    console.log('   Location: schools/' + schoolId + '/permissionTypes/');
    
    const typesSnapshot = await db
      .collection('schools')
      .doc(schoolId)
      .collection('permissionTypes')
      .get();
    
    if (typesSnapshot.empty) {
      console.log('   ❌ No permission types found');
    } else {
      console.log('   ✅ Found ' + typesSnapshot.size + ' permission types:');
      typesSnapshot.docs.forEach(doc => {
        const data = doc.data();
        console.log('      - ' + data.name + ' (ID: ' + doc.id + ', Active: ' + data.isActive + ')');
      });
    }
    
    // 3. Check staff user
    console.log('\n3. Checking Staff User:');
    const staffId = 'nkxvUTFv5IsBPAPNchwK';
    
    const staffDoc = await db
      .collection('schools')
      .doc(schoolId)
      .collection('staff')
      .doc(staffId)
      .get();
    
    if (staffDoc.exists) {
      console.log('   ✅ Staff EXISTS');
      const data = staffDoc.data();
      console.log('   Name:', data.name);
      console.log('   Role:', data.role);
    } else {
      console.log('   ❌ Staff DOES NOT EXIST');
    }
    
    // 4. Check user document
    console.log('\n4. Checking User Document:');
    const userDoc = await db
      .collection('users')
      .doc(staffId)
      .get();
    
    if (userDoc.exists) {
      console.log('   ✅ User EXISTS');
      const data = userDoc.data();
      console.log('   Email:', data.email);
      console.log('   Role:', data.role);
      console.log('   SchoolId:', data.schoolId);
    } else {
      console.log('   ❌ User DOES NOT EXIST');
    }
    
    console.log('\n✅ Verification complete!');
    
    process.exit(0);
  } catch (error) {
    console.error('❌ Error:', error);
    process.exit(1);
  }
}

verifyData();
