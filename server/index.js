const express = require('express');
const cors = require('cors');
const dotenv = require('dotenv');
const admin = require('firebase-admin');
const cron = require('node-cron');
const fs = require('fs');
const path = require('path');

dotenv.config();

// Initialize Firebase Admin SDK
const serviceAccountPath = process.env.FIREBASE_SERVICE_ACCOUNT_PATH || path.join(__dirname, 'service-account.json');

if (fs.existsSync(serviceAccountPath)) {
  admin.initializeApp({
    credential: admin.credential.cert(require(serviceAccountPath))
  });
  console.log('[Firebase Admin] Initialized with service account key.');
} else {
  // Fallback for emulator / default environment credentials
  admin.initializeApp();
  console.log('[Firebase Admin] Initialized with default application credentials.');
}

const db = admin.firestore();
const app = express();
app.use(cors({ origin: true }));
app.use(express.json());

// -----------------------------------------------------------------------------
// Authentication Middleware
// -----------------------------------------------------------------------------
async function authenticateToken(req, res, next) {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Unauthorized: Missing or malformed token' });
  }

  const idToken = authHeader.split('Bearer ')[1];
  try {
    const decodedToken = await admin.auth().verifyIdToken(idToken);
    req.uid = decodedToken.uid;
    next();
  } catch (error) {
    console.error('[Auth Middleware Error]:', error.message);
    return res.status(401).json({ error: 'Unauthorized: Invalid Firebase ID Token' });
  }
}

// -----------------------------------------------------------------------------
// Role-specific completion messages map (modular & clean)
// -----------------------------------------------------------------------------
const ROLE_MESSAGES = {
  gardener: [
    "You watered another seed today 🌱",
    "Roots growing deeper. Keep nurturing your spirit!",
    "A faithful harvest begins with daily care."
  ],
  electrician: [
    "Circuit charged. God's power is flowing through you ⚡",
    "Light connected. Shining brightly today!",
    "High voltage spiritual energy restored."
  ],
  cleaner: [
    "Heart refreshed and clean ✨",
    "Sweeping away distraction, fixing focus on Him.",
    "A pure heart creates space for peaceful growth."
  ],
  plumber: [
    "Living water flowing freely 💧",
    "Channels cleared! Streams of grace unlocked.",
    "Connected to the source of eternal water."
  ],
  painter: [
    "Adding vibrant color to your spiritual journey 🎨",
    "Masterpiece in progress. Grace on full display!",
    "Brighter perspective painted for today."
  ]
};

function getRandomRoleMessage(role) {
  const messages = ROLE_MESSAGES[role] || ROLE_MESSAGES.gardener;
  return messages[Math.floor(Math.random() * messages.length)];
}

// Helper to get YYYY-MM-DD string
function getTodayString() {
  const now = new Date();
  return now.toISOString().split('T')[0];
}

// -----------------------------------------------------------------------------
// Endpoints
// -----------------------------------------------------------------------------

// 1. Health check & verification test endpoint
app.get('/health', authenticateToken, (req, res) => {
  res.json({ ok: true, message: 'Pi server operational', verifiedUid: req.uid });
});

// 2. Complete Goal (Privileged transaction for fish rewards & group fund)
app.post('/completeGoal', authenticateToken, async (req, res) => {
  const uid = req.uid;
  const { goalId } = req.body;

  if (!goalId) {
    return res.status(400).json({ error: 'Missing goalId in request body' });
  }

  try {
    const todayStr = getTodayString();

    // Verify goal exists and belongs to user
    const goalRef = db.collection('goals').doc(goalId);
    const goalDoc = await goalRef.get();

    if (!goalDoc.exists) {
      return res.status(404).json({ error: 'Goal not found' });
    }

    const goalData = goalDoc.data();
    if (goalData.userId !== uid) {
      return res.status(403).json({ error: 'Forbidden: Goal does not belong to user' });
    }

    // Check if already completed today
    const completionId = `${uid}_${goalId}_${todayStr}`;
    const completionRef = db.collection('completions').doc(completionId);
    const completionDoc = await completionRef.get();

    if (completionDoc.exists) {
      return res.status(400).json({ error: 'Goal already completed for today' });
    }

    // Fetch user profile for role & building info
    const userRef = db.collection('users').doc(uid);
    const userDoc = await userRef.get();
    const userData = userDoc.exists ? userDoc.data() : {};
    const userRole = userData.role || 'gardener';
    const buildingId = userData.buildingId || null;

    const fishAward = 10;
    const groupContribution = buildingId ? 1 : 0;
    const newStreak = (goalData.currentStreak || 0) + 1;

    // Run atomic transaction
    await db.runTransaction(async (transaction) => {
      // Create completion record
      transaction.set(completionRef, {
        userId: uid,
        refId: goalId,
        refType: 'goal',
        date: todayStr,
        fishAwarded: fishAward,
        groupFundContribution: groupContribution,
        timestamp: admin.firestore.FieldValue.serverTimestamp()
      });

      // Update user fish balance
      transaction.update(userRef, {
        fishBalance: admin.firestore.FieldValue.increment(fishAward)
      });

      // Update goal streak
      transaction.update(goalRef, {
        currentStreak: newStreak
      });

      // Update building group fund if user is in a building
      if (buildingId) {
        const buildingRef = db.collection('buildings').doc(buildingId);
        transaction.update(buildingRef, {
          groupFund: admin.firestore.FieldValue.increment(groupContribution)
        });
      }
    });

    const roleMessage = getRandomRoleMessage(userRole);
    return res.json({
      success: true,
      fishAwarded: fishAward,
      groupFundContribution: groupContribution,
      newStreak: newStreak,
      message: roleMessage
    });

  } catch (err) {
    console.error('[POST /completeGoal Error]:', err);
    return res.status(500).json({ error: 'Failed to process goal completion' });
  }
});

// 3. Complete Daily Challenge
app.post('/completeDailyChallenge', authenticateToken, async (req, res) => {
  const uid = req.uid;
  const todayStr = getTodayString();

  try {
    const completionId = `${uid}_challenge_${todayStr}`;
    const completionRef = db.collection('completions').doc(completionId);
    const completionDoc = await completionRef.get();

    if (completionDoc.exists) {
      return res.status(400).json({ error: 'Daily challenge already completed today' });
    }

    const userRef = db.collection('users').doc(uid);
    const userDoc = await userRef.get();
    const userData = userDoc.exists ? userDoc.data() : {};
    const userRole = userData.role || 'gardener';
    const buildingId = userData.buildingId || null;

    const fishAward = 10;
    const groupContribution = buildingId ? 1 : 0;

    await db.runTransaction(async (transaction) => {
      transaction.set(completionRef, {
        userId: uid,
        refId: todayStr,
        refType: 'dailyChallenge',
        date: todayStr,
        fishAwarded: fishAward,
        groupFundContribution: groupContribution,
        timestamp: admin.firestore.FieldValue.serverTimestamp()
      });

      transaction.update(userRef, {
        fishBalance: admin.firestore.FieldValue.increment(fishAward)
      });

      if (buildingId) {
        const buildingRef = db.collection('buildings').doc(buildingId);
        transaction.update(buildingRef, {
          groupFund: admin.firestore.FieldValue.increment(groupContribution)
        });
      }
    });

    const roleMessage = getRandomRoleMessage(userRole);
    return res.json({
      success: true,
      fishAwarded: fishAward,
      groupFundContribution: groupContribution,
      message: roleMessage
    });

  } catch (err) {
    console.error('[POST /completeDailyChallenge Error]:', err);
    return res.status(500).json({ error: 'Failed to complete daily challenge' });
  }
});

// 4. Create Neighbourhood / Building (Rate Limited: Max 5/week per user)
app.post('/createBuilding', authenticateToken, async (req, res) => {
  const uid = req.uid;
  const { name, description, inviteCode } = req.body;

  if (!name || !inviteCode) {
    return res.status(400).json({ error: 'Name and invite code are required.' });
  }

  const normalizedCode = inviteCode.trim().toUpperCase();

  try {
    // Rate Limiting Check: Max 5 buildings created per user in last 7 days
    const sevenDaysAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);
    const userBuildingsSnap = await db.collection('buildings')
      .where('creatorUid', '==', uid)
      .get();

    const recentCreationsCount = userBuildingsSnap.docs.filter(doc => {
      const createdAt = doc.data().createdAt;
      if (!createdAt) return false;
      const date = createdAt.toDate ? createdAt.toDate() : new Date(createdAt);
      return date >= sevenDaysAgo;
    }).length;

    if (recentCreationsCount >= 5) {
      return res.status(429).json({ error: 'Creation limit reached: You can create at most 5 neighbourhoods per week.' });
    }

    // Check Invite Code Uniqueness
    const existingCodeQuery = await db.collection('buildings')
      .where('inviteCode', '==', normalizedCode)
      .limit(1)
      .get();

    if (!existingCodeQuery.empty) {
      return res.status(400).json({ error: 'Invite code is already in use by another neighbourhood.' });
    }

    // Create New Building Document
    const newBuildingRef = db.collection('buildings').doc();
    const buildingId = newBuildingRef.id;

    await db.runTransaction(async (transaction) => {
      const userRef = db.collection('users').doc(uid);
      const userDoc = await transaction.get(userRef);
      if (!userDoc.exists) throw new Error('User profile not found.');

      transaction.set(newBuildingRef, {
        name: name.trim(),
        description: (description || '').trim(),
        inviteCode: normalizedCode,
        creatorUid: uid,
        leaderUid: uid,
        adminUids: [uid],
        memberIds: [uid],
        pendingJoinRequests: [],
        groupFund: 0,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        lastActivityAt: admin.firestore.FieldValue.serverTimestamp()
      });

      transaction.update(userRef, {
        buildingId: buildingId
      });
    });

    return res.json({
      success: true,
      buildingId: buildingId,
      buildingName: name.trim()
    });

  } catch (err) {
    console.error('[POST /createBuilding Error]:', err);
    return res.status(500).json({ error: 'Failed to create neighbourhood. Please try again.' });
  }
});

// 5. Request to Join Building via Invite Code
app.post('/joinBuilding', authenticateToken, async (req, res) => {
  const uid = req.uid;
  const { inviteCode } = req.body;

  if (!inviteCode) {
    return res.status(400).json({ error: 'Missing inviteCode' });
  }

  try {
    const normalizedCode = inviteCode.trim().toUpperCase();
    const buildingQuery = await db.collection('buildings')
      .where('inviteCode', '==', normalizedCode)
      .limit(1)
      .get();

    if (buildingQuery.empty) {
      return res.status(404).json({ error: 'Invalid invite code. No matching neighbourhood found.' });
    }

    const buildingDoc = buildingQuery.docs[0];
    const buildingId = buildingDoc.id;
    const buildingData = buildingDoc.data();

    const memberIds = buildingData.memberIds || [];
    if (memberIds.includes(uid)) {
      return res.status(400).json({ error: 'You are already a member of this neighbourhood.' });
    }

    const pendingRequests = buildingData.pendingJoinRequests || [];
    if (pendingRequests.some(r => r.uid === uid)) {
      return res.status(400).json({ error: 'Join request is already pending approval by neighbourhood admins.' });
    }

    // Fetch requester user info
    const userDoc = await db.collection('users').doc(uid).get();
    const userData = userDoc.data() || {};

    const joinRequest = {
      uid: uid,
      name: userData.name || 'Member',
      avatarConfig: userData.avatarConfig || {},
      requestedAt: new Date().toISOString()
    };

    await db.collection('buildings').doc(buildingId).update({
      pendingJoinRequests: admin.firestore.FieldValue.arrayUnion(joinRequest)
    });

    return res.json({
      success: true,
      status: 'pending',
      buildingId: buildingId,
      buildingName: buildingData.name || 'Cell Group'
    });

  } catch (err) {
    console.error('[POST /joinBuilding Error]:', err);
    return res.status(500).json({ error: 'Failed to submit join request' });
  }
});

// 6. Approve Join Request (Admin Only)
app.post('/approveJoinRequest', authenticateToken, async (req, res) => {
  const uid = req.uid;
  const { buildingId, targetUid } = req.body;

  if (!buildingId || !targetUid) {
    return res.status(400).json({ error: 'Missing buildingId or targetUid' });
  }

  try {
    const buildingRef = db.collection('buildings').doc(buildingId);
    const bDoc = await buildingRef.get();

    if (!bDoc.exists) return res.status(404).json({ error: 'Neighbourhood not found' });
    const bData = bDoc.data();

    const adminUids = bData.adminUids || [];
    if (!adminUids.includes(uid)) {
      return res.status(403).json({ error: 'Only neighbourhood admins can approve join requests.' });
    }

    const pendingRequests = bData.pendingJoinRequests || [];
    const updatedPending = pendingRequests.filter(r => r.uid !== targetUid);

    await db.runTransaction(async (transaction) => {
      const uRef = db.collection('users').doc(targetUid);
      transaction.update(buildingRef, {
        memberIds: admin.firestore.FieldValue.arrayUnion(targetUid),
        pendingJoinRequests: updatedPending,
        lastActivityAt: admin.firestore.FieldValue.serverTimestamp()
      });
      transaction.update(uRef, {
        buildingId: buildingId
      });
    });

    return res.json({ success: true });

  } catch (err) {
    console.error('[POST /approveJoinRequest Error]:', err);
    return res.status(500).json({ error: 'Failed to approve join request' });
  }
});

// 7. Reject Join Request (Admin Only)
app.post('/rejectJoinRequest', authenticateToken, async (req, res) => {
  const uid = req.uid;
  const { buildingId, targetUid } = req.body;

  if (!buildingId || !targetUid) {
    return res.status(400).json({ error: 'Missing buildingId or targetUid' });
  }

  try {
    const buildingRef = db.collection('buildings').doc(buildingId);
    const bDoc = await buildingRef.get();

    if (!bDoc.exists) return res.status(404).json({ error: 'Neighbourhood not found' });
    const bData = bDoc.data();

    const adminUids = bData.adminUids || [];
    if (!adminUids.includes(uid)) {
      return res.status(403).json({ error: 'Only neighbourhood admins can reject join requests.' });
    }

    const pendingRequests = bData.pendingJoinRequests || [];
    const updatedPending = pendingRequests.filter(r => r.uid !== targetUid);

    await buildingRef.update({
      pendingJoinRequests: updatedPending
    });

    return res.json({ success: true });

  } catch (err) {
    console.error('[POST /rejectJoinRequest Error]:', err);
    return res.status(500).json({ error: 'Failed to reject join request' });
  }
});

// 8. Promote Member to Admin (Leader Only)
app.post('/promoteBuildingAdmin', authenticateToken, async (req, res) => {
  const uid = req.uid;
  const { buildingId, targetUid } = req.body;

  if (!buildingId || !targetUid) {
    return res.status(400).json({ error: 'Missing buildingId or targetUid' });
  }

  try {
    const buildingRef = db.collection('buildings').doc(buildingId);
    const bDoc = await buildingRef.get();

    if (!bDoc.exists) return res.status(404).json({ error: 'Neighbourhood not found' });
    const bData = bDoc.data();

    if (bData.leaderUid !== uid) {
      return res.status(403).json({ error: 'Only the neighbourhood leader can promote admins.' });
    }

    await buildingRef.update({
      adminUids: admin.firestore.FieldValue.arrayUnion(targetUid)
    });

    return res.json({ success: true });

  } catch (err) {
    console.error('[POST /promoteBuildingAdmin Error]:', err);
    return res.status(500).json({ error: 'Failed to promote admin' });
  }
});

// 9. Leave Neighbourhood (With Leadership Transfer & Instant Deletion when Empty)
app.post('/leaveBuilding', authenticateToken, async (req, res) => {
  const uid = req.uid;
  const { buildingId } = req.body;

  if (!buildingId) {
    return res.status(400).json({ error: 'Missing buildingId' });
  }

  try {
    const buildingRef = db.collection('buildings').doc(buildingId);
    const bDoc = await buildingRef.get();

    if (!bDoc.exists) {
      // Clear user buildingId if doc doesn't exist
      await db.collection('users').doc(uid).update({ buildingId: null });
      return res.json({ success: true });
    }

    const bData = bDoc.data();
    const remainingMembers = (bData.memberIds || []).filter(m => m !== uid);
    const remainingAdmins = (bData.adminUids || []).filter(a => a !== uid);

    // Clear user profile buildingId
    await db.collection('users').doc(uid).update({ buildingId: null });

    // INSTANT DELETION if no members remain
    if (remainingMembers.length === 0) {
      await buildingRef.delete();
      // Clean up bulletin posts
      const posts = await db.collection('bulletinPosts').where('buildingId', '==', buildingId).get();
      const batch = db.batch();
      posts.docs.forEach(p => batch.delete(p.ref));
      await batch.commit();

      console.log(`[Building] Instant deletion of empty building ${buildingId}`);
      return res.json({ success: true, deleted: true });
    }

    // Handle Leadership Transfer if leaving user was Leader
    let newLeaderUid = bData.leaderUid;
    let newAdminUids = remainingAdmins;

    if (bData.leaderUid === uid) {
      if (remainingAdmins.length > 0) {
        newLeaderUid = remainingAdmins[0];
      } else {
        newLeaderUid = remainingMembers[0]; // Oldest remaining member
        newAdminUids = [newLeaderUid];
      }
    }

    await buildingRef.update({
      memberIds: remainingMembers,
      adminUids: newAdminUids,
      leaderUid: newLeaderUid,
      pendingJoinRequests: (bData.pendingJoinRequests || []).filter(r => r.uid !== uid)
    });

    return res.json({ success: true, newLeaderUid: newLeaderUid });

  } catch (err) {
    console.error('[POST /leaveBuilding Error]:', err);
    return res.status(500).json({ error: 'Failed to leave neighbourhood' });
  }
});

// 5. Purchase Cosmetic Item
app.post('/purchaseItem', authenticateToken, async (req, res) => {
  const uid = req.uid;
  const { itemId, cost } = req.body;

  if (!itemId || cost == null) {
    return res.status(400).json({ error: 'Missing itemId or cost' });
  }

  try {
    const userRef = db.collection('users').doc(uid);
    const itemRef = db.collection('inventory').doc(uid).collection('items').doc(itemId);

    let success = false;
    let newBalance = 0;

    await db.runTransaction(async (transaction) => {
      const userDoc = await transaction.get(userRef);
      if (!userDoc.exists) throw new Error('User profile not found');

      const currentBalance = userDoc.data().fishBalance || 0;
      if (currentBalance < cost) {
        throw new Error('INSUFFICIENT_FUNDS');
      }

      const itemDoc = await transaction.get(itemRef);
      if (itemDoc.exists) {
        throw new Error('ALREADY_OWNED');
      }

      newBalance = currentBalance - cost;
      transaction.update(userRef, { fishBalance: newBalance });
      transaction.set(itemRef, {
        equipped: false,
        acquiredAt: admin.firestore.FieldValue.serverTimestamp()
      });
      success = true;
    });

    return res.json({ success: true, newBalance: newBalance });

  } catch (err) {
    if (err.message === 'INSUFFICIENT_FUNDS') {
      return res.status(400).json({ error: 'Not enough fish to purchase this item' });
    }
    if (err.message === 'ALREADY_OWNED') {
      return res.status(400).json({ error: 'You already own this item' });
    }
    console.error('[POST /purchaseItem Error]:', err);
    return res.status(500).json({ error: 'Failed to process purchase' });
  }
});

// 6. Get Aggregated Building Stats (Strict Privacy Protection)
app.get('/buildingStats/:buildingId', authenticateToken, async (req, res) => {
  const { buildingId } = req.params;

  try {
    const buildingDoc = await db.collection('buildings').doc(buildingId).get();
    if (!buildingDoc.exists) {
      return res.status(404).json({ error: 'Building not found' });
    }

    const buildingData = buildingDoc.data();
    const memberIds = buildingData.memberIds || [];

    // Calculate rolling 7-day completion window
    const now = new Date();
    const sevenDaysAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
    const startDateStr = sevenDaysAgo.toISOString().split('T')[0];

    // Fetch members' profile details
    const memberStats = await Promise.all(memberIds.map(async (mUid) => {
      const uDoc = await db.collection('users').doc(mUid).get();
      const uData = uDoc.exists ? uDoc.data() : { name: 'Member', role: 'gardener' };

      // Query completions for this user over the 7 day period
      const completionsSnap = await db.collection('completions')
        .where('userId', '==', mUid)
        .get();

      const totalCompletions = completionsSnap.docs.filter(c => (c.data().date || '') >= startDateStr).length;
      // Define baseline target (e.g. 7 days * target goals = 7 completions benchmark for 100%)
      const targetCompletions = 7; 
      const completionPercent = Math.min(100, Math.round((totalCompletions / targetCompletions) * 100));

      return {
        uid: mUid,
        name: uData.name || 'Group Member',
        role: uData.role || 'gardener',
        avatarConfig: uData.avatarConfig || {},
        completionPercent: completionPercent
      };
    }));

    return res.json({
      buildingId: buildingId,
      name: buildingData.name || 'Cell Group',
      groupFund: buildingData.groupFund || 0,
      members: memberStats
    });

  } catch (err) {
    console.error('[GET /buildingStats Error]:', err);
    return res.status(500).json({ error: 'Failed to fetch building stats' });
  }
});

// -----------------------------------------------------------------------------
// Daily Challenge Generation (Cron & Fallback)
// -----------------------------------------------------------------------------
const CURATED_REFLECTIONS = [
  "What is one verse or word from today's Scripture that brought comfort or conviction to your heart?",
  "How did you experience God's goodness or encouragement in your interactions today?",
  "Is there someone in your life or cell group who needs extra prayer today? Take a moment to write a brief prayer for them.",
  "Reflect on a recent challenge you faced. How did your faith help guide your response?",
  "What is one practical action or encouraging note you can share with a friend or church member this week?"
];

async function ensureDailyChallenge() {
  const todayStr = getTodayString();
  const challengeRef = db.collection('dailyChallenges').doc(todayStr);
  const doc = await challengeRef.get();

  if (!doc.exists) {
    const prompt = CURATED_REFLECTIONS[Math.floor(Math.random() * CURATED_REFLECTIONS.length)];
    await challengeRef.set({
      promptText: prompt,
      source: 'curated_ai',
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });
    console.log(`[Daily Challenge] Backfilled challenge for ${todayStr}`);
  }
}

async function cleanupInactiveBuildings() {
  try {
    const buildingsSnap = await db.collection('buildings').get();
    const sevenDaysAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);
    const startDateStr = sevenDaysAgo.toISOString().split('T')[0];

    for (const doc of buildingsSnap.docs) {
      const bData = doc.data();
      const bId = doc.id;
      const memberIds = bData.memberIds || [];

      // 1. Instant deletion for 0-member buildings
      if (memberIds.length === 0) {
        console.log(`[Cleanup Cron] Deleting empty neighbourhood '${bId}'`);
        await doc.ref.delete();
        const posts = await db.collection('bulletinPosts').where('buildingId', '==', bId).get();
        const batch = db.batch();
        posts.docs.forEach(p => batch.delete(p.ref));
        await batch.commit();
        continue;
      }

      // 2. Inactivity check: Check lastActivityAt or recent completions
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

          // Reset user buildingId
          const userBatch = db.batch();
          memberIds.forEach(mUid => {
            userBatch.update(db.collection('users').doc(mUid), { buildingId: null });
          });

          // Delete bulletin posts
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

// Scheduled Cron Job: Runs every day at 00:01 Midnight
cron.schedule('1 0 * * *', async () => {
  console.log('[Cron] Triggering daily challenge generation & building cleanup...');
  await ensureDailyChallenge();
  await cleanupInactiveBuildings();
});

// Start Server
const PORT = process.env.PORT || 3000;
app.listen(PORT, async () => {
  console.log(`[Pi Server] Kingdom Backend listening on port ${PORT}`);
  // Initial check on boot
  await ensureDailyChallenge();
  await cleanupInactiveBuildings();
});
