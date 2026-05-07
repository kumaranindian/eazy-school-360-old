/**
 * Script to list all RFID cards in a school
 */

const admin = require('firebase-admin');
const serviceAccount = require('../service-account-key.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function listAllCards() {
  try {
    const schoolId = 'RMqzF9Gtx8j8ts5umDlt';
    
    console.log(`Listing all RFID cards for school ${schoolId}\n`);
    
    // Get all cards
    const cardsSnapshot = await db
      .collection('schools')
      .doc(schoolId)
      .collection('rfid_cards')
      .get();
    
    console.log(`Total cards found: ${cardsSnapshot.size}\n`);
    
    cardsSnapshot.docs.forEach((doc, index) => {
      const data = doc.data();
      console.log(`Card ${index + 1}:`);
      console.log(`  Document ID: ${doc.id}`);
      console.log(`  UUID: ${data.uuid || 'N/A'}`);
      console.log(`  Staff ID: ${data.staffId || 'N/A'}`);
      console.log(`  Staff Name: ${data.staffName || 'N/A'}`);
      console.log(`  Card Type: ${data.cardType || 'undefined'}`);
      console.log(`  Is Active: ${data.isActive}`);
      console.log(`  Is Assigned: ${data.isAssigned}`);
      console.log(`  Assigned At: ${data.assignedAt?.toDate() || 'N/A'}`);
      console.log('');
    });
    
    process.exit(0);
  } catch (error) {
    console.error('❌ Error:', error);
    process.exit(1);
  }
}

listAllCards();
