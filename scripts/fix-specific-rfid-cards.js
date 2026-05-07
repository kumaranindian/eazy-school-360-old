/**
 * Script to fix specific RFID cards for a staff member
 */

const admin = require('firebase-admin');
const serviceAccount = require('../service-account-key.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function fixSpecificCards() {
  try {
    const schoolId = 'RMqzF9Gtx8j8ts5umDlt';
    const staffId = 'nkxvUTFv5IsBPAPNchwK';
    
    console.log(`Fixing RFID cards for staff ${staffId} in school ${schoolId}`);
    
    // Get all cards for this staff member
    const cardsSnapshot = await db
      .collection('schools')
      .doc(schoolId)
      .collection('rfid_cards')
      .where('staffId', '==', staffId)
      .where('isActive', '==', true)
      .get();
    
    console.log(`Found ${cardsSnapshot.size} active card(s)`);
    
    const cards = [];
    cardsSnapshot.docs.forEach(doc => {
      const data = doc.data();
      cards.push({ id: doc.id, data });
      console.log(`  Card: ${data.uuid}, Type: ${data.cardType || 'undefined'}, Assigned: ${data.assignedAt?.toDate()}`);
    });
    
    // Sort by assignedAt (oldest first)
    cards.sort((a, b) => {
      const aTime = a.data.assignedAt?.toMillis() || 0;
      const bTime = b.data.assignedAt?.toMillis() || 0;
      return aTime - bTime;
    });
    
    console.log('\nUpdating card types...');
    
    // First card should be primary, second should be backup
    for (let i = 0; i < cards.length; i++) {
      const card = cards[i];
      const expectedType = i === 0 ? 'primary' : 'backup';
      const currentType = card.data.cardType;
      
      console.log(`\nCard ${i + 1}: ${card.data.uuid}`);
      console.log(`  Current type: ${currentType || 'undefined'}`);
      console.log(`  Expected type: ${expectedType}`);
      
      if (currentType !== expectedType) {
        console.log(`  ✏️  Updating to ${expectedType}...`);
        
        await db
          .collection('schools')
          .doc(schoolId)
          .collection('rfid_cards')
          .doc(card.id)
          .update({
            cardType: expectedType,
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
          });
        
        console.log(`  ✅ Updated successfully`);
      } else {
        console.log(`  ✓ Already correct`);
      }
    }
    
    console.log('\n✅ All cards fixed successfully!');
    process.exit(0);
  } catch (error) {
    console.error('❌ Error:', error);
    process.exit(1);
  }
}

fixSpecificCards();
