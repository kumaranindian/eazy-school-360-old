/**
 * Script to set up leave types and permission configuration
 * Run this once to initialize the system
 */

const admin = require('firebase-admin');
const serviceAccount = require('../service-account-key.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function setupConfiguration() {
  try {
    const schoolId = 'RMqzF9Gtx8j8ts5umDlt'; // Replace with your school ID
    
    console.log('Setting up leave and permission configuration...\n');
    
    // 1. Create Leave Types
    console.log('Creating leave types...');
    
    const leaveTypes = [
      {
        code: 'CASUAL_LEAVE',
        name: 'Casual Leave',
        description: 'For personal reasons',
        allowHalfDay: true,
        requiresApproval: true,
        isActive: true,
        createdAt: admin.firestore.FieldValue.serverTimestamp()
      },
      {
        code: 'SICK_LEAVE',
        name: 'Sick Leave',
        description: 'For medical reasons',
        allowHalfDay: true,
        requiresApproval: true,
        isActive: true,
        createdAt: admin.firestore.FieldValue.serverTimestamp()
      },
      {
        code: 'EARNED_LEAVE',
        name: 'Earned Leave',
        description: 'Earned leave/privilege leave',
        allowHalfDay: false,
        requiresApproval: true,
        isActive: true,
        createdAt: admin.firestore.FieldValue.serverTimestamp()
      },
      {
        code: 'MATERNITY_LEAVE',
        name: 'Maternity Leave',
        description: 'For maternity purposes',
        allowHalfDay: false,
        requiresApproval: true,
        isActive: true,
        createdAt: admin.firestore.FieldValue.serverTimestamp()
      },
      {
        code: 'PATERNITY_LEAVE',
        name: 'Paternity Leave',
        description: 'For paternity purposes',
        allowHalfDay: false,
        requiresApproval: true,
        isActive: true,
        createdAt: admin.firestore.FieldValue.serverTimestamp()
      }
    ];
    
    for (const leaveType of leaveTypes) {
      await db
        .collection('schools')
        .doc(schoolId)
        .collection('leaveTypes')
        .doc(leaveType.code)
        .set(leaveType);
      
      console.log(`  ✅ Created: ${leaveType.name}`);
    }
    
    // 2. Create Permission Configuration
    console.log('\nCreating permission configuration...');
    
    await db
      .collection('schools')
      .doc(schoolId)
      .collection('settings')
      .doc('permission')
      .set({
        enabled: true,
        minHours: 0.5,
        maxHoursPerDay: 4,
        requiresApproval: true,
        allowedDays: ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'],
        description: 'Staff can request permission for partial day absence',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
    
    console.log('  ✅ Permission configuration created');
    
    // 3. Sample: Initialize leave balances for a staff member
    console.log('\nSample: Creating leave balances for staff...');
    console.log('(You should do this for all staff members)');
    
    const sampleStaffId = 'nkxvUTFv5IsBPAPNchwK'; // Replace with actual staff ID
    
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
        .doc(sampleStaffId)
        .collection('leave_balances')
        .doc(balance.type)
        .set({
          available: balance.available,
          used: 0,
          total: balance.total,
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        });
      
      console.log(`  ✅ ${balance.type}: ${balance.available} days`);
    }
    
    // 4. Initialize permission balance
    console.log('\nCreating permission balance for staff...');
    
    await db
      .collection('schools')
      .doc(schoolId)
      .collection('staff')
      .doc(sampleStaffId)
      .collection('permission_balances')
      .doc('current_year')
      .set({
        availableHours: 24,
        usedHours: 0,
        totalHours: 24,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
    
    console.log('  ✅ Permission balance: 24 hours');
    
    console.log('\n✅ Configuration setup completed successfully!');
    console.log('\nNext steps:');
    console.log('1. Update the schoolId and staffId in this script');
    console.log('2. Run this script for all staff members');
    console.log('3. Adjust leave balances as needed');
    console.log('4. Test leave and permission applications from the app');
    
    process.exit(0);
  } catch (error) {
    console.error('❌ Error:', error);
    process.exit(1);
  }
}

setupConfiguration();
