const admin = require("firebase-admin");

const serviceAccount = require('./service-account-key.json');
const projectId = serviceAccount.project_id;

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: projectId
});

async function run() {
  let nextPageToken;
  let totalDeleted = 0;
  let totalSkipped = 0;

  do {
    const result = await admin.auth().listUsers(1000, nextPageToken);

    // Filter out hi@avail404.com
    const uidsToDelete = result.users
      .filter(u => u.email !== 'hi@avail404.com')
      .map(u => u.uid);

    const skipped = result.users.filter(u => u.email === 'hi@avail404.com').length;
    totalSkipped += skipped;

    if (uidsToDelete.length) {
      await admin.auth().deleteUsers(uidsToDelete);
      totalDeleted += uidsToDelete.length;
      console.log(`Deleted ${uidsToDelete.length} users (skipped ${skipped})`);
    }

    nextPageToken = result.pageToken;
  } while (nextPageToken);

  console.log(`\n🔥 DELETION COMPLETE`);
  console.log(`✅ Deleted: ${totalDeleted} users`);
  console.log(`⏭️  Skipped: ${totalSkipped} users (hi@avail404.com)`);
}

run().catch(console.error);
