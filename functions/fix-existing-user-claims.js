#!/usr/bin/env node

/**
 * One-time script to fix custom claims for existing users
 * Run this after deploying the updated Cloud Functions
 */

const admin = require('firebase-admin');

// Initialize Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp();
}

// Helper function to convert role string to claim flags
function roleToClaimFlags(role) {
  const isSuperAdmin = role === 'SUPER_ADMIN';
  const isAdmin = role === 'ADMIN' || role === 'tenant_admin';
  const isStaff = role === 'STAFF';
  
  return {
    superAdmin: isSuperAdmin,
    admin: isAdmin,
    staff: isStaff
  };
}

async function fixUserClaims(uid) {
  try {
    // Get user document from Firestore
    const userDoc = await admin.firestore().collection('users').doc(uid).get();
    
    if (!userDoc.exists) {
      console.error(`❌ User document not found: ${uid}`);
      return false;
    }
    
    const userData = userDoc.data();
    const role = userData.role || 'STAFF';
    const roleFlags = roleToClaimFlags(role);
    
    // Set custom claims
    const customClaims = {
      ...roleFlags,
      schoolId: userData.schoolId || null,
      isActive: userData.isActive !== false
    };
    
    await admin.auth().setCustomUserClaims(uid, customClaims);
    
    console.log(`✅ Fixed claims for user ${uid}:`);
    console.log(`   Role: ${role}`);
    console.log(`   Claims:`, customClaims);
    
    return true;
  } catch (error) {
    console.error(`❌ Error fixing claims for user ${uid}:`, error);
    return false;
  }
}

async function fixAllUsers() {
  try {
    console.log('🔧 Starting bulk fix for all users...\n');
    
    const usersSnapshot = await admin.firestore().collection('users').get();
    
    if (usersSnapshot.empty) {
      console.log('⚠️  No users found in Firestore');
      return;
    }
    
    let successCount = 0;
    let failCount = 0;
    
    for (const doc of usersSnapshot.docs) {
      const uid = doc.id;
      const success = await fixUserClaims(uid);
      
      if (success) {
        successCount++;
      } else {
        failCount++;
      }
    }
    
    console.log('\n📊 Summary:');
    console.log(`   ✅ Success: ${successCount}`);
    console.log(`   ❌ Failed: ${failCount}`);
    console.log(`   📝 Total: ${usersSnapshot.size}`);
    
  } catch (error) {
    console.error('❌ Error in bulk fix:', error);
  }
}

async function main() {
  const args = process.argv.slice(2);
  
  if (args.length === 0) {
    console.log('Usage:');
    console.log('  node fix-existing-user-claims.js <uid>           # Fix specific user');
    console.log('  node fix-existing-user-claims.js --all           # Fix all users');
    console.log('\nExample:');
    console.log('  node fix-existing-user-claims.js DTNRix56ENeDACP89VdCGD9IaVt1');
    process.exit(1);
  }
  
  if (args[0] === '--all') {
    await fixAllUsers();
  } else {
    const uid = args[0];
    console.log(`🔧 Fixing claims for user: ${uid}\n`);
    await fixUserClaims(uid);
  }
  
  console.log('\n✅ Done! Users must sign out and sign in again for changes to take effect.');
  process.exit(0);
}

main().catch((error) => {
  console.error('❌ Fatal error:', error);
  process.exit(1);
});
