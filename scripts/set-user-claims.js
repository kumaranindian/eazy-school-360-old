#!/usr/bin/env node

/**
 * Standalone script to set Firebase Auth custom claims
 * Run this locally without needing Cloud Functions
 * Requires: Firebase Admin SDK service account key
 */

const admin = require('firebase-admin');
const readline = require('readline');

// Initialize Firebase Admin with service account
// Download your service account key from:
// Firebase Console > Project Settings > Service Accounts > Generate New Private Key
const serviceAccount = require('../service-account-key.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();
const auth = admin.auth();

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

async function setClaimsForUser(uid) {
  try {
    // Get user document from Firestore
    const userDoc = await db.collection('users').doc(uid).get();
    
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
    
    await auth.setCustomUserClaims(uid, customClaims);
    
    console.log(`✅ Claims set for user ${uid}:`);
    console.log(`   Email: ${userData.email}`);
    console.log(`   Role: ${role}`);
    console.log(`   Claims:`, customClaims);
    
    return true;
  } catch (error) {
    console.error(`❌ Error setting claims for user ${uid}:`, error.message);
    return false;
  }
}

async function setClaimsForAllUsers() {
  try {
    console.log('🔧 Setting claims for all users...\n');
    
    const usersSnapshot = await db.collection('users').get();
    
    if (usersSnapshot.empty) {
      console.log('⚠️  No users found in Firestore');
      return;
    }
    
    let successCount = 0;
    let failCount = 0;
    
    for (const doc of usersSnapshot.docs) {
      const uid = doc.id;
      const success = await setClaimsForUser(uid);
      
      if (success) {
        successCount++;
      } else {
        failCount++;
      }
      console.log(''); // blank line between users
    }
    
    console.log('📊 Summary:');
    console.log(`   ✅ Success: ${successCount}`);
    console.log(`   ❌ Failed: ${failCount}`);
    console.log(`   📝 Total: ${usersSnapshot.size}`);
    
  } catch (error) {
    console.error('❌ Error:', error.message);
  }
}

async function setClaimsByEmail(email) {
  try {
    const userRecord = await auth.getUserByEmail(email);
    await setClaimsForUser(userRecord.uid);
  } catch (error) {
    console.error(`❌ Error finding user by email ${email}:`, error.message);
  }
}

async function interactiveMode() {
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout
  });

  console.log('\n🔐 Firebase Custom Claims Manager\n');
  console.log('Options:');
  console.log('  1. Set claims for specific user (by UID)');
  console.log('  2. Set claims for specific user (by email)');
  console.log('  3. Set claims for ALL users');
  console.log('  4. Exit\n');

  rl.question('Choose option (1-4): ', async (answer) => {
    switch (answer.trim()) {
      case '1':
        rl.question('Enter user UID: ', async (uid) => {
          await setClaimsForUser(uid.trim());
          rl.close();
          process.exit(0);
        });
        break;
      
      case '2':
        rl.question('Enter user email: ', async (email) => {
          await setClaimsByEmail(email.trim());
          rl.close();
          process.exit(0);
        });
        break;
      
      case '3':
        rl.question('Are you sure? This will update ALL users (y/n): ', async (confirm) => {
          if (confirm.toLowerCase() === 'y') {
            await setClaimsForAllUsers();
          } else {
            console.log('Cancelled.');
          }
          rl.close();
          process.exit(0);
        });
        break;
      
      case '4':
        console.log('Goodbye!');
        rl.close();
        process.exit(0);
        break;
      
      default:
        console.log('Invalid option');
        rl.close();
        process.exit(1);
    }
  });
}

async function main() {
  const args = process.argv.slice(2);
  
  if (args.length === 0) {
    // Interactive mode
    await interactiveMode();
  } else if (args[0] === '--all') {
    await setClaimsForAllUsers();
    process.exit(0);
  } else if (args[0] === '--email') {
    if (!args[1]) {
      console.error('❌ Please provide an email: --email user@example.com');
      process.exit(1);
    }
    await setClaimsByEmail(args[1]);
    process.exit(0);
  } else {
    // Assume it's a UID
    await setClaimsForUser(args[0]);
    process.exit(0);
  }
}

main().catch((error) => {
  console.error('❌ Fatal error:', error);
  process.exit(1);
});
