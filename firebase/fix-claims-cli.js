const { execSync } = require('child_process');

async function fixCustomClaimsUsingCLI() {
  const uid = 'DTNRix56ENeDACP89VdCGD9IaVt1'; // Current user from logs
  
  try {
    console.log(`🔍 Fixing custom claims for user: ${uid}`);
    console.log('📋 Setting custom claims using Firebase CLI...');
    
    // The custom claims we need to set based on the user document
    const customClaims = {
      role: 'tenant_admin',
      schoolId: '3uloakcJRa8w1R4TRQhi',
      isActive: true,
      status: 'ACTIVE'
    };
    
    console.log('🔧 Custom claims to set:', customClaims);
    
    // Use Firebase CLI to set custom claims
    const claimsJson = JSON.stringify(customClaims);
    const command = `firebase auth:set-custom-user-claims ${uid} '${claimsJson}'`;
    
    console.log('🚀 Executing command:', command);
    
    const result = execSync(command, {
      cwd: process.cwd(),
      encoding: 'utf8',
      timeout: 30000
    });
    
    console.log('✅ Command output:', result);
    console.log('✅ Custom claims set successfully!');
    
    // Verify the claims were set
    console.log('🔍 Verifying custom claims...');
    const verifyCommand = `firebase auth:get-user ${uid}`;
    const verifyResult = execSync(verifyCommand, {
      cwd: process.cwd(),
      encoding: 'utf8',
      timeout: 30000
    });
    
    console.log('📄 User details:', verifyResult);
    
    console.log('\n📋 Next steps:');
    console.log('1. User needs to refresh their browser or re-login');
    console.log('2. Firebase Auth token will then include the custom claims');
    console.log('3. Security rules will have access to role, schoolId, isActive, status');
    console.log('4. Staff and leave management features should work');
    
    return true;
  } catch (error) {
    console.error('❌ Error setting custom claims:', error.message);
    
    if (error.message.includes('not found')) {
      console.log('💡 User not found. The UID might be incorrect.');
    } else if (error.message.includes('permission')) {
      console.log('💡 Permission denied. Make sure you are logged in with Firebase CLI:');
      console.log('   firebase login');
    } else if (error.message.includes('project')) {
      console.log('💡 Project not found. Make sure you are in the correct Firebase project:');
      console.log('   firebase use eazy-school-360');
    }
    
    return false;
  }
}

// Execute the fix
fixCustomClaimsUsingCLI().then((success) => {
  if (success) {
    console.log('\n🎉 Custom claims fix completed successfully!');
    console.log('The user should now be able to access staff and leave management features after refreshing.');
  } else {
    console.log('\n❌ Custom claims fix failed. Check the error messages above.');
  }
  process.exit(success ? 0 : 1);
}).catch((error) => {
  console.error('💥 Unexpected error:', error);
  process.exit(1);
});
