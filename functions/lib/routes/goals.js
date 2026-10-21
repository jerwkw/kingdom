const { db, FieldValue } = require('../firebase');
const { getPeriodKey } = require('../domain');
const { applyFundChange, newEventId } = require('../guild');
const { conflict, forbidden, log, notFound, requireId, route } = require('../http');
const { rateLimit } = require('../rate-limit');

const FISH_PER_COMPLETION = 10;
const ACTIVITY_RETENTION_DAYS = 14;

const ENCOURAGING_MESSAGES = [
  "You built another faithful habit today! 🏰",
  "Roots growing deeper. Keep nurturing your spirit!",
  "A faithful harvest begins with daily care. ✨",
  "Streams of grace unlocked for today! 💧",
  "Masterpiece in progress. Grace on full display! 🎨",
  "God's strength is made perfect in faithful small steps. ⚡"
];

const CURATED_REFLECTIONS = [
  "What is one verse or word from today's Scripture that brought comfort or conviction to your heart?",
  "How did you experience God's goodness or encouragement in your interactions today?",
  "Is there someone in your life or cell group who needs extra prayer today? Take a moment to write a brief prayer for them.",
  "Reflect on a recent challenge you faced. How did your faith help guide your response?",
  "What is one practical action or encouraging note you can share with a friend or church member this week?"
];

function randomMessage() {
  return ENCOURAGING_MESSAGES[Math.floor(Math.random() * ENCOURAGING_MESSAGES.length)];
}

async function ensureDailyChallenge(dateKey = getPeriodKey('daily')) {
  const challengeRef = db.collection('dailyChallenges').doc(dateKey);
  await db.runTransaction(async (transaction) => {
    const doc = await transaction.get(challengeRef);
    if (doc.exists) return;
    transaction.set(challengeRef, {
      promptText: CURATED_REFLECTIONS[Math.floor(Math.random() * CURATED_REFLECTIONS.length)],
      source: 'curated',
      createdAt: FieldValue.serverTimestamp()
    });
  });
}

// Reads the documents every reward transaction needs. Returns the building
// snapshot only when the user belongs to one.
async function readRewardContext(transaction, uid) {
  const userRef = db.collection('users').doc(uid);
  const activityRef = db.collection('memberActivity').doc(uid);
  const [userDoc, activityDoc] = await Promise.all([transaction.get(userRef), transaction.get(activityRef)]);
  if (!userDoc.exists) throw notFound('USER_NOT_FOUND', 'User profile not found.');

  const buildingId = userDoc.data().buildingId || null;
  let buildingRef = null;
  let buildingDoc = null;
  if (buildingId) {
    buildingRef = db.collection('buildings').doc(buildingId);
    buildingDoc = await transaction.get(buildingRef);
    if (!buildingDoc.exists || !(buildingDoc.data().memberIds || []).includes(uid)) {
      throw conflict('INVALID_BUILDING_MEMBERSHIP', 'Your neighbourhood membership is out of date. Please reload.');
    }
  }
  return { userRef, activityRef, activityDoc, buildingRef, buildingDoc };
}

// Writes fish, guild-fund and activity updates shared by goal and reflection
// completions. Must run after all transaction reads.
function applyReward(transaction, ctx, { uid, source, dateKey, countsTowardConsistency }) {
  transaction.update(ctx.userRef, { fishBalance: FieldValue.increment(FISH_PER_COMPLETION) });

  let fund = null;
  if (ctx.buildingDoc) {
    fund = applyFundChange(transaction, {
      buildingRef: ctx.buildingRef,
      buildingData: ctx.buildingDoc.data(),
      amount: 1,
      source,
      uid,
      entryId: newEventId()
    });
  }

  if (countsTowardConsistency) {
    const days = { ...((ctx.activityDoc.exists && ctx.activityDoc.data().days) || {}) };
    const cutoff = new Date(Date.now() - ACTIVITY_RETENTION_DAYS * 86400000).toISOString().slice(0, 10);
    for (const key of Object.keys(days)) if (key < cutoff) delete days[key];
    days[dateKey] = (days[dateKey] || 0) + 1;
    transaction.set(ctx.activityRef, { days, updatedAt: FieldValue.serverTimestamp() }, { merge: true });
  }

  return { groupFundContribution: fund ? 1 : 0, unlockedAchievements: fund ? fund.unlocked : [] };
}

function register(app, authenticateToken) {
  app.post(['/completeGoal', '/api/completeGoal'], authenticateToken, rateLimit('completeGoal'), route(async (req) => {
    const uid = req.uid;
    const goalId = requireId(req.body && req.body.goalId, 'goalId');
    const goalRef = db.collection('goals').doc(goalId);
    const todayStr = getPeriodKey('daily');
    let result;

    await db.runTransaction(async (transaction) => {
      const goalDoc = await transaction.get(goalRef);
      if (!goalDoc.exists) throw notFound('GOAL_NOT_FOUND', 'Goal not found.');
      const goal = goalDoc.data();
      if (goal.userId !== uid) throw forbidden('FORBIDDEN', 'This goal does not belong to you.');
      if (goal.archived === true) throw conflict('GOAL_ARCHIVED', 'Restore this goal before completing it.');

      const frequency = goal.frequency || 'daily';
      const periodKey = getPeriodKey(frequency);
      const completionId = `${uid}_${goalId}_${periodKey}`;
      const completionRef = db.collection('completions').doc(completionId);
      const completionDoc = await transaction.get(completionRef);
      if (completionDoc.exists) throw conflict('ALREADY_COMPLETED', 'Goal already completed for this period.');
      const ctx = await readRewardContext(transaction, uid);

      const reward = applyReward(transaction, ctx, { uid, source: 'goal', dateKey: todayStr, countsTowardConsistency: true });
      const newStreak = (goal.currentStreak || 0) + 1;
      transaction.set(completionRef, {
        userId: uid,
        refId: goalId,
        refType: 'goal',
        date: todayStr,
        periodKey,
        frequency,
        fishAwarded: FISH_PER_COMPLETION,
        groupFundContribution: reward.groupFundContribution,
        timestamp: FieldValue.serverTimestamp()
      });
      transaction.update(goalRef, { currentStreak: newStreak });
      result = { ...reward, completionId, periodKey, newStreak };
    });

    log('INFO', req, 'Goal completed', { goalId, periodKey: result.periodKey });
    return { fishAwarded: FISH_PER_COMPLETION, message: randomMessage(), ...result };
  }));

  app.post(['/completeDailyChallenge', '/api/completeDailyChallenge'], authenticateToken, rateLimit('completeDailyChallenge'), route(async (req) => {
    const uid = req.uid;
    const todayStr = getPeriodKey('daily');
    await ensureDailyChallenge(todayStr);

    const completionId = `${uid}_challenge_${todayStr}`;
    const completionRef = db.collection('completions').doc(completionId);
    let reward;

    await db.runTransaction(async (transaction) => {
      const completionDoc = await transaction.get(completionRef);
      if (completionDoc.exists) throw conflict('ALREADY_COMPLETED', 'Daily reflection already completed today.');
      const ctx = await readRewardContext(transaction, uid);

      reward = applyReward(transaction, ctx, { uid, source: 'dailyChallenge', dateKey: todayStr, countsTowardConsistency: false });
      transaction.set(completionRef, {
        userId: uid,
        refId: todayStr,
        refType: 'dailyChallenge',
        date: todayStr,
        periodKey: todayStr,
        frequency: 'daily',
        fishAwarded: FISH_PER_COMPLETION,
        groupFundContribution: reward.groupFundContribution,
        timestamp: FieldValue.serverTimestamp()
      });
    });

    return { fishAwarded: FISH_PER_COMPLETION, message: randomMessage(), completionId, ...reward };
  }));

  // Lets the client recover when the scheduled job has not yet created
  // today's reflection.
  app.post(['/ensureDailyChallenge', '/api/ensureDailyChallenge'], authenticateToken, route(async () => {
    const dateKey = getPeriodKey('daily');
    await ensureDailyChallenge(dateKey);
    return { dateKey };
  }));
}

// Keeps memberActivity/{uid}.goalCounts in sync with the user's active goal
// schedule, so building statistics need no per-member goal queries.
async function recomputeGoalCounts(uid) {
  const goals = await db.collection('goals').where('userId', '==', uid).get();
  const goalCounts = { daily: 0, weekly: 0, monthly: 0 };
  for (const doc of goals.docs) {
    const goal = doc.data();
    if (goal.archived === true) continue;
    const frequency = ['weekly', 'monthly'].includes(goal.frequency) ? goal.frequency : 'daily';
    goalCounts[frequency] += 1;
  }
  await db.collection('memberActivity').doc(uid).set({ goalCounts, updatedAt: FieldValue.serverTimestamp() }, { merge: true });
  return goalCounts;
}

module.exports = { ensureDailyChallenge, recomputeGoalCounts, register };
