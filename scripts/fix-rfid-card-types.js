/**
 * Script to fix RFID card types in the database
 * This will update cards that don't have a cardType field
 */

const admin = require('firebase-admin');
const serviceAccount = require('../service-account-key.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function fixRfidCardTypes() {
  try {
    console.log('Starting RFID card type fix...');
    
    // Get all schools
    const schoolsSnapshot = await db.collection('schools').get();
    
    for (const schoolDoc of schoolsSnapshot.docs) {
      const schoolId = schoolDoc.id;
      console.log(`\nProcessing school: ${schoolId}`);
      
      // Get all RFID cards for this school
      const cardsSnapshot = await db
        .collection('schools')
        .doc(schoolId)
        .collection('rfid_cards')
        .get();
      
      console.log(`Found ${cardsSnapshot.size} RFID cards`);
      
      // Group cards by staffId
      const staffCards = {};
      cardsSnapshot.docs.forEach(doc => {
        const data = doc.data();
        if (data.staffId) {
          if (!staffCards[data.staffId]) {
            staffCards[data.staffId] = [];
          }
          staffCards[data.staffId].push({ id: doc.id, data });
        }
      });
      
      // Fix card types for each staff member
      for (const [staffId, cards] of Object.entries(staffCards)) {
        console.log(`\nStaff ${staffId} has ${cards.length} card(s)`);
        
        // Sort by assignedAt (oldest first)
        cards.sort((a, b) => {
          const aTime = a.data.assignedAt?.toMillis() || 0;
          const bTime = b.data.assignedAt?.toMillis() || 0;
          return aTime - bTime;
        });
        
        // First card should be primary, second should be backup
        for (let i = 0; i < cards.length; i++) {
          const card = cards[i];
          const expectedType = i === 0 ? 'primary' : 'backup';
          const currentType = card.data.cardType;
          
          if (currentType !== expectedType) {
            console.log(`  Updating card ${card.data.uuid} from "${currentType || 'undefined'}" to "${expectedType}"`);
            
            await db
              .collection('schools')
              .doc(schoolId)
              .collection('rfid_cards')
              .doc(card.id)
              .update({
                cardType: expectedType,
                updatedAt: admin.firestore.FieldValue.serverTimestamp()
              });
          } else {
            console.log(`  Card ${card.data.uuid} already has correct type: ${currentType}`);
          }
        }
      }
    }
    
    console.log('\n✅ RFID card type fix completed successfully!');
    process.exit(0);
  } catch (error) {
    console.error('❌ Error fixing RFID card types:', error);
    process.exit(1);
  }
}

fixRfidCardTypes();
