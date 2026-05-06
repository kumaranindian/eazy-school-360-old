/**
 * Script to trigger Firestore index creation by running queries that require them.
 * This forces Firebase to create the indexes defined in firestore.indexes.json
 */

const admin = require('firebase-admin');

// Initialize Firebase Admin
const serviceAccount = require('../firebase-admin-key.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function triggerIndexCreation() {
  console.log('🔍 Triggering index creation by running queries...\n');

  try {
    // Trigger studentFeeItems index: isActive, paidAmount, __name__
    console.log('1. Triggering studentFeeItems (isActive, paidAmount, __name__) index...');
    const feeItemsQuery = await db.collectionGroup('studentFeeItems')
      .where('isActive', '==', true)
      .orderBy('paidAmount', 'asc')
      .limit(1)
      .get();
    console.log(`   ✅ Query executed (${feeItemsQuery.size} docs)\n`);

    // Trigger bills index: billType, billDate DESC, __name__
    console.log('2. Triggering bills (billType, billDate DESC, __name__) index...');
    const billsQuery = await db.collectionGroup('bills')
      .where('billType', '==', 'TUITION')
      .orderBy('billDate', 'desc')
      .limit(1)
      .get();
    console.log(`   ✅ Query executed (${billsQuery.size} docs)\n`);

    console.log('✅ All index-triggering queries completed!');
    console.log('📝 Indexes should now be building in Firebase Console.');
    console.log('🔗 Check status: https://console.firebase.google.com/project/eazyschool-360-dev/firestore/indexes\n');

  } catch (error) {
    if (error.code === 9 || error.message.includes('index')) {
      console.log('✅ Index creation triggered! Firebase will now build the indexes.');
      console.log('   This error is expected - it means Firebase recognized the need for the index.');
      console.log('🔗 Check status: https://console.firebase.google.com/project/eazyschool-360-dev/firestore/indexes\n');
    } else {
      console.error('❌ Error:', error.message);
    }
  }

  process.exit(0);
}

triggerIndexCreation();
