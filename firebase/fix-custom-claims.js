const admin = require('firebase-admin');

// Initialize Firebase Admin SDK with project ID
const app = admin.initializeApp({
  projectId: 'eazy-school-360'
});

const auth = admin.auth();
const firestore = admin.firestore();

async function fixCustomClaimsForCurrentUser() {
  const uid = 'DTNRix56ENeDACP89VdCGD9IaVt1'; // Current user from logs
  
  try {
    console.log(`🔍 Fixing custom claims for user: ${uid}`);
    
    // Get user document from Firestore
    const userDoc = await firestore.collection('users').doc(uid).get();
    
    if (!userDoc.exists) {
      throw new Error(`User document not found for UID: ${uid}`);
    }
    
    const userData = userDoc.data();
    console.log('📄 Current user data:', {
      email: userData.email,
      role: userData.role,
      schoolId: userData.schoolId,
      isActive: userData.isActive,
      status: userData.status
    });
    
    // Set the custom claims that Firebase security rules need
    const customClaims = {
      role: userData.role,
      schoolId: userData.schoolId,
      isActive: userData.isActive,
      status: userData.status
    };
    
    console.log('🔧 Setting custom claims:', customClaims);
    
    // Set custom claims in Firebase Auth
    await auth.setCustomUserClaims(uid, customClaims);
    
    console.log('✅ Custom claims set successfully!');
    
    // Verify the claims were set correctly
    const userRecord = await auth.getUser(uid);
    console.log('🔍 Verified custom claims in Firebase Auth:', userRecord.customClaims);
    
    console.log('\n📋 Next steps:');
    console.log('1. User needs to refresh their browser or re-login');
    console.log('2. Firebase Auth token will then include the custom claims');
    console.log('3. Security rules will have access to role, schoolId, isActive, status');
    
    return true;
  } catch (error) {
    console.error('❌ Error setting custom claims:', error);
    
    if (error.code === 'auth/user-not-found') {
      console.log('💡 User not found in Firebase Auth. This might be a different issue.');
    } else if (error.code === 'auth/insufficient-permissions') {
      console.log('💡 Insufficient permissions. Make sure you have Firebase Admin privileges.');
    }
    
    return false;
  }
}

// Execute the fix
fixCustomClaimsForCurrentUser().then((success) => {
  if (success) {
    console.log('\n🎉 Custom claims fix completed successfully!');
    console.log('The user should now be able to access staff and leave management features.');
  } else {
    console.log('\n❌ Custom claims fix failed. Check the error messages above.');
  }
  process.exit(success ? 0 : 1);
}).catch((error) => {
  console.error('💥 Unexpected error:', error);
  process.exit(1);
});
