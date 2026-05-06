const admin = require('firebase-admin');
const serviceAccount = require('../service-account-key.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

const SCHOOL_ID = 'BQs5pYYblCCD0H72v9JS'; // Your school ID
const PARENT_PHONE = '+918508196981'; // Specific phone number
const ACADEMIC_YEAR = '2024-25';

const sampleStudents = [
  {
    studentId: 1001,
    name: 'Rahul Kumar',
    className: 'X',
    section: 'A',
    parentName: 'Rajesh Kumar',
    parentPhone: PARENT_PHONE,
    parentEmail: 'rajesh.kumar@example.com'
  },
  {
    studentId: 1002,
    name: 'Priya Sharma',
    className: 'X',
    section: 'A',
    parentName: 'Amit Sharma',
    parentPhone: PARENT_PHONE,
    parentEmail: 'amit.sharma@example.com'
  },
  {
    studentId: 1003,
    name: 'Arjun Singh',
    className: 'X',
    section: 'B',
    parentName: 'Vikram Singh',
    parentPhone: PARENT_PHONE,
    parentEmail: 'vikram.singh@example.com'
  },
  {
    studentId: 1004,
    name: 'Sneha Patel',
    className: 'IX',
    section: 'A',
    parentName: 'Suresh Patel',
    parentPhone: PARENT_PHONE,
    parentEmail: 'suresh.patel@example.com'
  },
  {
    studentId: 1005,
    name: 'Rohan Verma',
    className: 'IX',
    section: 'A',
    parentName: 'Manoj Verma',
    parentPhone: PARENT_PHONE,
    parentEmail: 'manoj.verma@example.com'
  }
];

async function addSampleStudents() {
  console.log('Adding sample students...\n');

  for (const student of sampleStudents) {
    try {
      // Create student document
      const studentRef = db.collection('schools').doc(SCHOOL_ID).collection('students').doc();
      
      const studentData = {
        ...student,
        status: 'ACTIVE',
        dateOfBirth: admin.firestore.Timestamp.fromDate(new Date('2010-01-01')),
        gender: 'Male',
        address: '123 Sample Street, City',
        phoneNumber: PARENT_PHONE,
        admissionDate: admin.firestore.Timestamp.fromDate(new Date('2020-04-01')),
        academicYearCode: ACADEMIC_YEAR,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      };

      await studentRef.set(studentData);
      console.log(`✓ Added student: ${student.name} (ID: ${student.studentId})`);

      // Create fee ledger with pending amount
      const ledgerRef = db.collection('schools').doc(SCHOOL_ID).collection('studentFeeLedgers').doc();
      
      const totalAmount = 50000; // Total fee
      const paidAmount = Math.floor(Math.random() * 30000); // Random paid amount (0-30000)
      const pendingAmount = totalAmount - paidAmount;

      const ledgerData = {
        schoolId: SCHOOL_ID,
        studentId: studentRef.id,
        studentName: student.name,
        className: student.className,
        section: student.section,
        academicYear: ACADEMIC_YEAR,
        feeStructureId: 'sample-structure',
        feeStructureName: 'Standard Fee Structure',
        totalAssigned: totalAmount,
        totalPaid: paidAmount,
        totalPending: pendingAmount,
        totalOverdue: pendingAmount > 0 ? pendingAmount * 0.1 : 0, // 10% overdue
        totalLateFee: 0,
        termStatus: [
          {
            termId: 'term1',
            termName: 'Term 1',
            sequence: 1,
            amount: 12500,
            dueDate: admin.firestore.Timestamp.fromDate(new Date('2024-07-31')),
            category: 'TUITION',
            paidAmount: Math.min(12500, paidAmount),
            balanceAmount: Math.max(0, 12500 - paidAmount),
            isArrear: false
          },
          {
            termId: 'term2',
            termName: 'Term 2',
            sequence: 2,
            amount: 12500,
            dueDate: admin.firestore.Timestamp.fromDate(new Date('2024-10-31')),
            category: 'TUITION',
            paidAmount: Math.min(12500, Math.max(0, paidAmount - 12500)),
            balanceAmount: Math.max(0, 25000 - paidAmount),
            isArrear: false
          },
          {
            termId: 'term3',
            termName: 'Term 3',
            sequence: 3,
            amount: 12500,
            dueDate: admin.firestore.Timestamp.fromDate(new Date('2025-01-31')),
            category: 'TUITION',
            paidAmount: Math.min(12500, Math.max(0, paidAmount - 25000)),
            balanceAmount: Math.max(0, 37500 - paidAmount),
            isArrear: false
          },
          {
            termId: 'term4',
            termName: 'Term 4',
            sequence: 4,
            amount: 12500,
            dueDate: admin.firestore.Timestamp.fromDate(new Date('2025-03-31')),
            category: 'TUITION',
            paidAmount: Math.min(12500, Math.max(0, paidAmount - 37500)),
            balanceAmount: Math.max(0, 50000 - paidAmount),
            isArrear: false
          }
        ],
        remindersEnabled: true,
        lastReminderSentAt: null,
        parentPhone: PARENT_PHONE,
        parentName: student.parentName,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      };

      await ledgerRef.set(ledgerData);
      console.log(`  ✓ Created ledger: Total ₹${totalAmount}, Paid ₹${paidAmount}, Pending ₹${pendingAmount}`);
      console.log('');

    } catch (error) {
      console.error(`✗ Error adding student ${student.name}:`, error);
    }
  }

  console.log('\n✅ Sample students added successfully!');
  console.log(`\nAll students have parent phone: ${PARENT_PHONE}`);
  console.log('You can now test payment due notifications.\n');
  
  process.exit(0);
}

addSampleStudents().catch(error => {
  console.error('Error:', error);
  process.exit(1);
});
