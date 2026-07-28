const admin = require('firebase-admin');
const path = require('path');

// Initialize Admin SDK using default credentials or emulator
if (!admin.apps.length) {
  admin.initializeApp({
    projectId: process.env.GCP_PROJECT || process.env.FIREBASE_PROJECT_ID || 'kingdom-app'
  });
}

const db = admin.firestore();

async function resetNeighbourhoodsToFreshState() {
  console.log('[Migration] Resetting neighbourhoods and users to fresh state...');

  try {
    // 1. Reset all users' buildingId to null
    const usersSnap = await db.collection('users').get();
    const userBatch = db.batch();
    let userCount = 0;

    usersSnap.docs.forEach(doc => {
      userBatch.update(doc.ref, { buildingId: null });
      userCount++;
    });

    if (userCount > 0) {
      await userBatch.commit();
      console.log(`[Migration] Cleared buildingId for ${userCount} user(s).`);
    }

    // 2. Delete default_building if exists
    const defaultBuildingRef = db.collection('buildings').doc('default_building');
    const defaultDoc = await defaultBuildingRef.get();
    if (defaultDoc.exists) {
      await defaultBuildingRef.delete();
      console.log('[Migration] Deleted default_building document.');
    }

    // 3. Delete bulletin posts attached to default_building
    const postsSnap = await db.collection('bulletinPosts').where('buildingId', '==', 'default_building').get();
    if (!postsSnap.empty) {
      const postsBatch = db.batch();
      postsSnap.docs.forEach(p => postsBatch.delete(p.ref));
      await postsBatch.commit();
      console.log(`[Migration] Deleted ${postsSnap.size} bulletin post(s) from default_building.`);
    }

    console.log('✅ Fresh start reset complete! All users can now create or join new neighbourhoods.');
  } catch (err) {
    console.error('[Migration Error]:', err);
  }
}

resetNeighbourhoodsToFreshState().then(() => process.exit(0));
