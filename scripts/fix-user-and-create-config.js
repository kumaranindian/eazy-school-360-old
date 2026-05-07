/**
 * Fix user issues and create config for correct school
 */

const admin = require('firebase-admin');
const serviceAccount = require('../service-account-key.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function fixEverything() {
  try {
    const userId = 'Qhj0NhI637WEIo0ZpYp9NQHFA522';
    const schoolId = 'ihrNNOJVJ0KiJqe7YmYD';
    const email = 'ckarthikeyan60@yahoo.in';
    
    console.log('🔧 Fixing user and creating configuration...\n');
    
    // 1. Activate user
    console.log('1. Activating user...');
    await db.collection('users').doc(userId).update({
      isActive: true,
      status: 'ACTIVE'
    });
    console.log('   ✅ User activated');
    
    // 2. Create staff document
    console.log('\n2. Creating staff document...');
    await db
      .collection('schools')
      .doc(schoolId)
      .collection('staff')
      .doc(userId)
      .set({
        userId: userId,
        name: 'karthikeyan Staff',
        email: email,
        employeeId: 'EMP001',
        role: 'STAFF',
        isActive: true,
        schoolId: schoolId,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
    console.log('   ✅ Staff document created');
    
    // 3. Create permission config
    console.log('\n3. Creating permission configuration...');
    await db
      .collection('schools')
      .doc(schoolId)
      .collection('permissionConfig')
      .doc('default')
      .set({
        schoolId: schoolId,
        monthlyLimit: 4,
        maxDurationMinutes: 240,
        requiresApproval: true,
        isActive: true,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        createdBy: userId,
        customRules: {
          minDurationMinutes: 30,
          allowedDays: ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday']
        }
      });
    console.log('   ✅ Permission config created');
    
    // 4. Create permission types
    console.log('\n4. Creating permission types...');
    const permissionTypes = [
      { name: 'Medical Appointment', defaultLimit: 2, isActive: true },
      { name: 'Personal Work', defaultLimit: 2, isActive: true },
      { name: 'Family Emergency', defaultLimit: 1, isActive: true },
      { name: 'Official Work', defaultLimit: 3, isActive: true }
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
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        });
      console.log(`   ✅ Created: ${type.name}`);
    }
    
    // 5. Create leave types
    console.log('\n5. Creating leave types...');
    const leaveTypes = [
      { code: 'CASUAL_LEAVE', name: 'Casual Leave', allowHalfDay: true },
      { code: 'SICK_LEAVE', name: 'Sick Leave', allowHalfDay: true },
      { code: 'EARNED_LEAVE', name: 'Earned Leave', allowHalfDay: false }
    ];
    
    for (const type of leaveTypes) {
      await db
        .collection('schools')
        .doc(schoolId)
        .collection('leaveTypes')
        .doc(type.code)
        .set({
          code: type.code,
          name: type.name,
          allowHalfDay: type.allowHalfDay,
          requiresApproval: true,
          isActive: true,
          createdAt: admin.firestore.FieldValue.serverTimestamp()
        });
      console.log(`   ✅ Created: ${type.name}`);
    }
    
    // 6. Create leave balances
    console.log('\n6. Creating leave balances...');
    const leaveBalances = [
      { type: 'CASUAL_LEAVE', available: 12, total: 12 },
      { type: 'SICK_LEAVE', available: 10, total: 10 },
      { type: 'EARNED_LEAVE', available: 15, total: 15 }
    ];
    
    for (const balance of leaveBalances) {
      await db
        .collection('schools')
        .doc(schoolId)
        .collection('staff')
        .doc(userId)
        .collection('leave_balances')
        .doc(balance.type)
        .set({
          available: balance.available,
          used: 0,
          total: balance.total,
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        });
      console.log(`   ✅ ${balance.type}: ${balance.available} days`);
    }
    
    // 7. Create permission balance
    console.log('\n7. Creating permission balance...');
    await db
      .collection('schools')
      .doc(schoolId)
      .collection('staff')
      .doc(userId)
      .collection('permission_balances')
      .doc('current_year')
      .set({
        availableHours: 24,
        usedHours: 0,
        totalHours: 24,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
    console.log('   ✅ Permission balance: 24 hours');
    
    console.log('\n✅ All fixes applied successfully!');
    console.log('\nUser Details:');
    console.log('  Email:', email);
    console.log('  UID:', userId);
    console.log('  School ID:', schoolId);
    console.log('  Status: ACTIVE');
    console.log('\n🎉 The app should now work! Please refresh and try again.');
    
    process.exit(0);
  } catch (error) {
    console.error('❌ Error:', error);
    process.exit(1);
  }
}

fixEverything();
