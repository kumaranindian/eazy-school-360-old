const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

// Initialize Firebase Admin SDK
const serviceAccount = require('./service-account-key.json'); // You'll need to add this file

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: 'https://eazy-school-360-default-rtdb.firebaseio.com' // Replace with your database URL
});

const auth = admin.auth();
const firestore = admin.firestore();

async function setCustomClaimsForUser(uid) {
  try {
    console.log(`🔍 Setting custom claims for user: ${uid}`);
    
    // Get user document from Firestore
    const userDoc = await firestore.collection('users').doc(uid).get();
    
    if (!userDoc.exists) {
      throw new Error(`User document not found for UID: ${uid}`);
    }
    
    const userData = userDoc.data();
    console.log('📄 User data:', userData);
    
    // Extract the claims we need
    const customClaims = {
      role: userData.role || 'STAFF',
      schoolId: userData.schoolId || null,
      isActive: userData.isActive || false,
      status: userData.status || 'ACTIVE'
    };
    
    console.log('🔧 Setting custom claims:', customClaims);
    
    // Set custom claims
    await auth.setCustomUserClaims(uid, customClaims);
    
    console.log('✅ Custom claims set successfully');
    
    // Verify the claims were set
    const userRecord = await auth.getUser(uid);
    console.log('🔍 Verified custom claims:', userRecord.customClaims);
    
    return customClaims;
  } catch (error) {
    console.error('❌ Error setting custom claims:', error);
    throw error;
  }
}

async function setCustomClaimsForAllUsers() {
  try {
    console.log('🔍 Getting all users from Firestore...');
    
    const usersSnapshot = await firestore.collection('users').get();
    console.log(`📊 Found ${usersSnapshot.docs.length} users`);
    
    for (const userDoc of usersSnapshot.docs) {
      const uid = userDoc.id;
      const userData = userDoc.data();
      
      console.log(`\n🔧 Processing user: ${uid} (${userData.email})`);
      
      try {
        await setCustomClaimsForUser(uid);
        console.log(`✅ Custom claims set for ${userData.email}`);
      } catch (error) {
        console.error(`❌ Failed to set claims for ${userData.email}:`, error.message);
      }
    }
    
    console.log('\n✅ Finished processing all users');
  } catch (error) {
    console.error('❌ Error processing users:', error);
  }
}

// Main execution
async function main() {
  const args = process.argv.slice(2);
  
  if (args.length === 0) {
    console.log('Usage:');
    console.log('  node set-custom-claims.js <uid>           # Set claims for specific user');
    console.log('  node set-custom-claims.js --all          # Set claims for all users');
    console.log('  node set-custom-claims.js --current      # Set claims for current logged-in user');
    return;
  }
  
  if (args[0] === '--all') {
    await setCustomClaimsForAllUsers();
  } else if (args[0] === '--current') {
    // Set claims for the current user (from logs)
    const currentUid = 'DTNRix56ENeDACP89VdCGD9IaVt1';
    await setCustomClaimsForUser(currentUid);
  } else {
    // Set claims for specific user
    const uid = args[0];
    await setCustomClaimsForUser(uid);
  }
}

// Export for use in other modules
module.exports = { setCustomClaimsForUser, setCustomClaimsForAllUsers };

// Run if called directly
if (require.main === module) {
  main().then(() => {
    console.log('🏁 Script completed');
    process.exit(0);
  }).catch((error) => {
    console.error('💥 Script failed:', error);
    process.exit(1);
  });
}
