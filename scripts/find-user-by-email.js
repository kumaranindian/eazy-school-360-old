/**
 * Find user by email to get their actual UID
 */

const admin = require('firebase-admin');
const serviceAccount = require('../service-account-key.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function findUser() {
  try {
    const email = 'ckarthikeyan60@yahoo.in';
    
    console.log('🔍 Searching for user:', email);
    console.log('');
    
    // Method 1: Check Firebase Auth
    try {
      const userRecord = await admin.auth().getUserByEmail(email);
      console.log('✅ Found in Firebase Auth:');
      console.log('   UID:', userRecord.uid);
      console.log('   Email:', userRecord.email);
      console.log('   Display Name:', userRecord.displayName || 'N/A');
      console.log('   Created:', new Date(userRecord.metadata.creationTime).toLocaleString());
      
      // Method 2: Check users collection
      console.log('\n🔍 Checking users collection...');
      const userDoc = await db.collection('users').doc(userRecord.uid).get();
      
      if (userDoc.exists) {
        console.log('✅ Found in users collection:');
        const data = userDoc.data();
        console.log('   Role:', data.role);
        console.log('   SchoolId:', data.schoolId);
        console.log('   Name:', data.name || 'N/A');
        console.log('   IsActive:', data.isActive);
        
        // Method 3: Check staff collection
        if (data.schoolId) {
          console.log('\n🔍 Checking staff collection...');
          const staffDoc = await db
            .collection('schools')
            .doc(data.schoolId)
            .collection('staff')
            .doc(userRecord.uid)
            .get();
          
          if (staffDoc.exists) {
            console.log('✅ Found in staff collection:');
            const staffData = staffDoc.data();
            console.log('   Name:', staffData.name);
            console.log('   Employee ID:', staffData.employeeId || 'N/A');
          } else {
            console.log('❌ NOT found in staff collection');
            console.log('   Expected location: schools/' + data.schoolId + '/staff/' + userRecord.uid);
          }
        }
      } else {
        console.log('❌ NOT found in users collection');
      }
      
    } catch (authError) {
      console.log('❌ Not found in Firebase Auth:', authError.message);
    }
    
    // Method 4: Search by email in users collection
    console.log('\n🔍 Searching users collection by email...');
    const usersSnapshot = await db.collection('users').where('email', '==', email).get();
    
    if (!usersSnapshot.empty) {
      console.log('✅ Found ' + usersSnapshot.size + ' user(s) with this email:');
      usersSnapshot.docs.forEach(doc => {
        const data = doc.data();
        console.log('\n   User ID:', doc.id);
        console.log('   Email:', data.email);
        console.log('   Role:', data.role);
        console.log('   SchoolId:', data.schoolId);
      });
    } else {
      console.log('❌ No users found with this email');
    }
    
    process.exit(0);
  } catch (error) {
    console.error('❌ Error:', error);
    process.exit(1);
  }
}

findUser();
