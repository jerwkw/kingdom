const { db } = require('./firebase');

// NOT SCHEDULED. Retained pending a data-retention decision for inactive
// neighbourhoods (see docs/TODO.md on the documentation branch). Do not export from index.js without notice,
// retention and recovery rules.
async function cleanupInactiveBuildings() {
  try {
    const buildingsSnap = await db.collection('buildings').get();
    const sevenDaysAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);
    const startDateStr = sevenDaysAgo.toISOString().split('T')[0];

    for (const doc of buildingsSnap.docs) {
      const bData = doc.data();
      const bId = doc.id;
      const memberIds = bData.memberIds || [];

      if (memberIds.length === 0) {
        await doc.ref.delete();
        const posts = await db.collection('bulletinPosts').where('buildingId', '==', bId).get();
        const batch = db.batch();
        posts.docs.forEach(p => batch.delete(p.ref));
        await batch.commit();
        continue;
      }

      let lastActive = bData.lastActivityAt ? bData.lastActivityAt.toDate() : null;
      if (!lastActive || lastActive < sevenDaysAgo) {
        let hasActivity = false;
        for (const mUid of memberIds.slice(0, 10)) {
          const completionsSnap = await db.collection('completions')
            .where('userId', '==', mUid)
            .get();
          if (completionsSnap.docs.some(c => (c.data().date || '') >= startDateStr)) {
            hasActivity = true;
            break;
          }
        }

        if (!hasActivity) {
          console.log(`[Cleanup Cron] Deleting inactive neighbourhood '${bData.name}' (${bId})`);
          await doc.ref.delete();

          const userBatch = db.batch();
          memberIds.forEach(mUid => {
            userBatch.update(db.collection('users').doc(mUid), { buildingId: null });
          });

          const posts = await db.collection('bulletinPosts').where('buildingId', '==', bId).get();
          posts.docs.forEach(p => userBatch.delete(p.ref));
          await userBatch.commit();
        }
      }
    }
  } catch (err) {
    console.error('[Cleanup Inactive Buildings Error]:', err);
  }
}

module.exports = { cleanupInactiveBuildings };
