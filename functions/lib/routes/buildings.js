const { db, FieldValue } = require('../firebase');
const { LIMITS, completionPercent, getPeriodKey, weeklyCompletionTarget } = require('../domain');
const { NOTIFICATION_TYPES, applyFundChange, newEventId, queueNotifications } = require('../guild');
const {
  badRequest, conflict, forbidden, log, notFound, optionalString, requireId, requireString, route
} = require('../http');
const { rateLimit } = require('../rate-limit');
const { recomputeGoalCounts } = require('./goals');

const INVITE_CODE_PATTERN = new RegExp(`^[A-Z0-9]{${LIMITS.inviteCodeMin},${LIMITS.inviteCodeMax}}$`);

function normalizeInviteCode(value) {
  if (typeof value !== 'string') throw badRequest('INVALID_INPUT', 'Invite code is required.');
  const code = value.trim().toUpperCase();
  if (!INVITE_CODE_PATTERN.test(code)) {
    throw badRequest('INVALID_INVITE_CODE', `Invite codes are ${LIMITS.inviteCodeMin}-${LIMITS.inviteCodeMax} letters or digits.`);
  }
  return code;
}

const buildingRefFor = (id) => db.collection('buildings').doc(id);
const userRefFor = (uid) => db.collection('users').doc(uid);
const inviteCodeRefFor = (code) => db.collection('inviteCodes').doc(code);

async function getBuildingOrThrow(transaction, buildingId) {
  const doc = await transaction.get(buildingRefFor(buildingId));
  if (!doc.exists) throw notFound('BUILDING_NOT_FOUND', 'Neighbourhood not found.');
  return doc;
}

const isAdmin = (building, uid) => (building.adminUids || []).includes(uid) || building.leaderUid === uid;

// Invite codes are reserved in `inviteCodes/{code}` so two creators cannot
// claim the same code concurrently. Buildings created before reservations
// existed are found by query instead.
async function findBuildingIdByInviteCode(code) {
  const reservation = await inviteCodeRefFor(code).get();
  if (reservation.exists) return reservation.data().buildingId;
  const legacy = await db.collection('buildings').where('inviteCode', '==', code).limit(1).get();
  return legacy.empty ? null : legacy.docs[0].id;
}

async function deleteBulletinPosts(buildingId) {
  const posts = await db.collection('bulletinPosts').where('buildingId', '==', buildingId).get();
  for (let i = 0; i < posts.docs.length; i += 400) {
    const batch = db.batch();
    posts.docs.slice(i, i + 400).forEach((p) => batch.delete(p.ref));
    await batch.commit();
  }
}

function register(app, authenticateToken) {
  app.post(['/createBuilding', '/api/createBuilding'], authenticateToken, rateLimit('createBuilding'), route(async (req) => {
    const uid = req.uid;
    const name = requireString(req.body && req.body.name, 'Name', { max: LIMITS.buildingName });
    const description = optionalString(req.body && req.body.description, 'Description', { max: LIMITS.buildingDescription });
    const inviteCode = normalizeInviteCode(req.body && req.body.inviteCode);

    const legacyCodeQuery = await db.collection('buildings').where('inviteCode', '==', inviteCode).limit(1).get();
    if (!legacyCodeQuery.empty) throw conflict('INVITE_CODE_TAKEN', 'Invite code is already in use by another neighbourhood.');

    const buildingRef = db.collection('buildings').doc();
    await db.runTransaction(async (transaction) => {
      const userRef = userRefFor(uid);
      const [userDoc, codeDoc] = await Promise.all([transaction.get(userRef), transaction.get(inviteCodeRefFor(inviteCode))]);
      if (!userDoc.exists) throw notFound('USER_NOT_FOUND', 'User profile not found.');
      if (userDoc.data().buildingId) throw conflict('ALREADY_IN_BUILDING', 'Leave your current neighbourhood before creating another.');
      if (codeDoc.exists) throw conflict('INVITE_CODE_TAKEN', 'Invite code is already in use by another neighbourhood.');

      transaction.set(buildingRef, {
        name,
        description,
        inviteCode,
        creatorUid: uid,
        leaderUid: uid,
        adminUids: [uid],
        memberIds: [uid],
        pendingJoinRequests: [],
        groupFund: 0,
        createdAt: FieldValue.serverTimestamp(),
        lastActivityAt: FieldValue.serverTimestamp()
      });
      transaction.set(inviteCodeRefFor(inviteCode), { buildingId: buildingRef.id, createdAt: FieldValue.serverTimestamp() });
      transaction.set(buildingRef.collection('achievements').doc('founded'), {
        achievementId: 'founded',
        threshold: 0,
        unlockedAt: FieldValue.serverTimestamp(),
        fundBalance: 0,
        triggerSource: 'created',
        triggerUid: uid,
        backfilled: false
      });
      transaction.update(userRef, { buildingId: buildingRef.id });
    });

    log('INFO', req, 'Building created', { buildingId: buildingRef.id });
    return { buildingId: buildingRef.id, buildingName: name };
  }));

  app.post(['/joinBuilding', '/api/joinBuilding'], authenticateToken, rateLimit('joinBuilding'), route(async (req) => {
    const uid = req.uid;
    const inviteCode = normalizeInviteCode(req.body && req.body.inviteCode);
    const buildingId = await findBuildingIdByInviteCode(inviteCode);
    if (!buildingId) throw notFound('INVALID_INVITE_CODE', 'Invalid invite code. No matching neighbourhood found.');

    let buildingName;
    await db.runTransaction(async (transaction) => {
      const [buildingDoc, userDoc] = await Promise.all([
        getBuildingOrThrow(transaction, buildingId),
        transaction.get(userRefFor(uid))
      ]);
      if (!userDoc.exists) throw notFound('USER_NOT_FOUND', 'User profile not found.');
      const building = buildingDoc.data();
      const user = userDoc.data();
      buildingName = building.name || 'Cell Group';

      if ((building.memberIds || []).includes(uid)) throw conflict('ALREADY_MEMBER', 'You are already a member of this neighbourhood.');
      if (user.buildingId) throw conflict('ALREADY_IN_BUILDING', 'Leave your current neighbourhood before joining another.');
      if ((building.pendingJoinRequests || []).some((r) => r.uid === uid)) {
        throw conflict('REQUEST_PENDING', 'Your join request is already waiting for approval.');
      }

      const requestedAt = new Date().toISOString();
      transaction.update(buildingRefFor(buildingId), {
        pendingJoinRequests: FieldValue.arrayUnion({
          uid,
          name: user.name || 'Member',
          avatarConfig: user.avatarConfig || {},
          requestedAt
        })
      });
      queueNotifications(transaction, {
        eventId: `join_${buildingId}_${uid}_${Date.parse(requestedAt)}`,
        recipients: [...(building.adminUids || []), building.leaderUid].filter(Boolean),
        buildingId,
        type: NOTIFICATION_TYPES.joinRequest,
        text: `${user.name || 'Someone'} asked to join ${buildingName}.`,
        target: 'requests'
      });
    });

    return { status: 'pending', buildingId, buildingName };
  }));

  app.post(['/approveJoinRequest', '/api/approveJoinRequest'], authenticateToken, rateLimit('membershipAdmin'), route(async (req) => {
    const uid = req.uid;
    const buildingId = requireId(req.body && req.body.buildingId, 'buildingId');
    const targetUid = requireId(req.body && req.body.targetUid, 'targetUid');

    await db.runTransaction(async (transaction) => {
      const [buildingDoc, targetDoc] = await Promise.all([
        getBuildingOrThrow(transaction, buildingId),
        transaction.get(userRefFor(targetUid))
      ]);
      const building = buildingDoc.data();
      if (!isAdmin(building, uid)) throw forbidden('NOT_ADMIN', 'Only neighbourhood admins can approve join requests.');

      const pending = building.pendingJoinRequests || [];
      const request = pending.find((r) => r.uid === targetUid);
      if (!request) throw conflict('NO_PENDING_REQUEST', 'No pending request exists for this user.');
      if (!targetDoc.exists) throw notFound('USER_NOT_FOUND', 'That member no longer has a profile.');
      if ((building.memberIds || []).includes(targetUid)) throw conflict('ALREADY_MEMBER', 'That person is already a member.');
      const targetBuildingId = targetDoc.data().buildingId;
      if (targetBuildingId) {
        throw conflict('TARGET_IN_OTHER_BUILDING', 'That person has already joined another neighbourhood. Reject this request instead.');
      }

      const existingMembers = building.memberIds || [];
      transaction.update(buildingDoc.ref, {
        memberIds: FieldValue.arrayUnion(targetUid),
        pendingJoinRequests: pending.filter((r) => r.uid !== targetUid),
        lastActivityAt: FieldValue.serverTimestamp()
      });
      transaction.update(userRefFor(targetUid), { buildingId });

      const eventId = `approved_${buildingId}_${targetUid}_${Date.parse(request.requestedAt) || 0}`;
      queueNotifications(transaction, {
        eventId,
        recipients: [targetUid],
        buildingId,
        type: NOTIFICATION_TYPES.requestApproved,
        text: `Welcome! Your request to join ${building.name || 'the neighbourhood'} was approved.`
      });
      queueNotifications(transaction, {
        eventId: `joined_${eventId}`,
        recipients: existingMembers,
        buildingId,
        type: NOTIFICATION_TYPES.memberJoined,
        text: `${request.name || 'A new member'} joined ${building.name || 'your neighbourhood'}.`
      });
    });

    return {};
  }));

  app.post(['/rejectJoinRequest', '/api/rejectJoinRequest'], authenticateToken, rateLimit('membershipAdmin'), route(async (req) => {
    const uid = req.uid;
    const buildingId = requireId(req.body && req.body.buildingId, 'buildingId');
    const targetUid = requireId(req.body && req.body.targetUid, 'targetUid');

    await db.runTransaction(async (transaction) => {
      const buildingDoc = await getBuildingOrThrow(transaction, buildingId);
      const building = buildingDoc.data();
      if (!isAdmin(building, uid)) throw forbidden('NOT_ADMIN', 'Only neighbourhood admins can reject join requests.');
      const pending = building.pendingJoinRequests || [];
      const request = pending.find((r) => r.uid === targetUid);
      if (!request) throw conflict('NO_PENDING_REQUEST', 'No pending request exists for this user.');

      transaction.update(buildingDoc.ref, { pendingJoinRequests: pending.filter((r) => r.uid !== targetUid) });
      queueNotifications(transaction, {
        eventId: `rejected_${buildingId}_${targetUid}_${Date.parse(request.requestedAt) || 0}`,
        recipients: [targetUid],
        buildingId,
        type: NOTIFICATION_TYPES.requestRejected,
        text: `Your request to join ${building.name || 'the neighbourhood'} was not approved.`,
        target: 'none'
      });
    });

    return {};
  }));

  app.post(['/promoteBuildingAdmin', '/api/promoteBuildingAdmin'], authenticateToken, rateLimit('membershipAdmin'), route(async (req) => {
    const uid = req.uid;
    const buildingId = requireId(req.body && req.body.buildingId, 'buildingId');
    const targetUid = requireId(req.body && req.body.targetUid, 'targetUid');

    await db.runTransaction(async (transaction) => {
      const buildingDoc = await getBuildingOrThrow(transaction, buildingId);
      const building = buildingDoc.data();
      if (building.leaderUid !== uid) throw forbidden('NOT_LEADER', 'Only the neighbourhood leader can promote admins.');
      if (!(building.memberIds || []).includes(targetUid)) throw badRequest('NOT_A_MEMBER', 'That person is not a member.');
      if ((building.adminUids || []).includes(targetUid)) return;

      transaction.update(buildingDoc.ref, { adminUids: FieldValue.arrayUnion(targetUid) });
      queueNotifications(transaction, {
        eventId: `promoted_${buildingId}_${targetUid}_${newEventId()}`,
        recipients: building.memberIds || [],
        buildingId,
        type: NOTIFICATION_TYPES.leadershipChanged,
        text: 'A member was promoted to neighbourhood admin.'
      });
    });

    return {};
  }));

  app.post(['/leaveBuilding', '/api/leaveBuilding'], authenticateToken, rateLimit('membershipAdmin'), route(async (req) => {
    const uid = req.uid;
    const buildingId = requireId(req.body && req.body.buildingId, 'buildingId');
    let outcome = {};

    await db.runTransaction(async (transaction) => {
      const userRef = userRefFor(uid);
      const [buildingDoc, userDoc] = await Promise.all([
        transaction.get(buildingRefFor(buildingId)),
        transaction.get(userRef)
      ]);
      const userBuildingId = userDoc.exists ? userDoc.data().buildingId : null;

      if (!buildingDoc.exists) {
        // Self-heal a profile that points at a deleted building.
        if (userBuildingId === buildingId) transaction.update(userRef, { buildingId: null });
        outcome = { deleted: true };
        return;
      }

      const building = buildingDoc.data();
      const members = building.memberIds || [];
      if (!members.includes(uid)) throw forbidden('NOT_A_MEMBER', 'You are not a member of this neighbourhood.');

      const remainingMembers = members.filter((m) => m !== uid);
      if (userDoc.exists && userBuildingId === buildingId) transaction.update(userRef, { buildingId: null });

      if (remainingMembers.length === 0) {
        transaction.delete(buildingDoc.ref);
        if (building.inviteCode) transaction.delete(inviteCodeRefFor(building.inviteCode));
        outcome = { deleted: true };
        return;
      }

      let adminUids = (building.adminUids || []).filter((a) => a !== uid && remainingMembers.includes(a));
      let leaderUid = building.leaderUid;
      if (leaderUid === uid || !remainingMembers.includes(leaderUid)) {
        leaderUid = adminUids[0] || remainingMembers[0];
      }
      if (!adminUids.includes(leaderUid)) adminUids = [leaderUid, ...adminUids];

      transaction.update(buildingDoc.ref, {
        memberIds: remainingMembers,
        adminUids,
        leaderUid,
        pendingJoinRequests: (building.pendingJoinRequests || []).filter((r) => r.uid !== uid),
        lastActivityAt: FieldValue.serverTimestamp()
      });

      const eventId = `left_${buildingId}_${uid}_${newEventId()}`;
      const leaverName = (userDoc.exists && userDoc.data().name) || 'A member';
      queueNotifications(transaction, {
        eventId,
        recipients: remainingMembers,
        buildingId,
        type: NOTIFICATION_TYPES.memberLeft,
        text: `${leaverName} left ${building.name || 'your neighbourhood'}.`
      });
      if (leaderUid !== building.leaderUid) {
        queueNotifications(transaction, {
          eventId: `leader_${eventId}`,
          recipients: [leaderUid],
          buildingId,
          type: NOTIFICATION_TYPES.leadershipChanged,
          text: `You are now the leader of ${building.name || 'your neighbourhood'}.`
        });
      }
      outcome = { newLeaderUid: leaderUid };
    });

    if (outcome.deleted) await deleteBulletinPosts(buildingId);
    return outcome;
  }));

  app.post(['/depositFish', '/api/depositFish'], authenticateToken, rateLimit('depositFish'), route(async (req) => {
    const uid = req.uid;
    const buildingId = requireId(req.body && req.body.buildingId, 'buildingId');
    const amount = req.body && req.body.amount;
    if (!Number.isSafeInteger(amount) || amount <= 0 || amount > LIMITS.maxDeposit) {
      throw badRequest('INVALID_AMOUNT', `Deposit a whole number of fish between 1 and ${LIMITS.maxDeposit}.`);
    }

    const userRef = userRefFor(uid);
    const entryId = newEventId();
    let result;
    await db.runTransaction(async (transaction) => {
      const [userDoc, buildingDoc] = await Promise.all([
        transaction.get(userRef),
        getBuildingOrThrow(transaction, buildingId)
      ]);
      if (!userDoc.exists) throw notFound('USER_NOT_FOUND', 'User profile not found.');
      const building = buildingDoc.data();
      if (userDoc.data().buildingId !== buildingId || !(building.memberIds || []).includes(uid)) {
        throw forbidden('NOT_A_MEMBER', 'You are not a member of this neighbourhood.');
      }
      const balance = userDoc.data().fishBalance || 0;
      if (balance < amount) throw badRequest('INSUFFICIENT_FUNDS', 'Not enough fish available to deposit.');

      transaction.update(userRef, { fishBalance: FieldValue.increment(-amount) });
      const fund = applyFundChange(transaction, {
        buildingRef: buildingDoc.ref, buildingData: building, amount, source: 'deposit', uid, entryId
      });
      queueNotifications(transaction, {
        eventId: `deposit_${entryId}`,
        recipients: (building.memberIds || []).filter((m) => m !== uid),
        buildingId,
        type: NOTIFICATION_TYPES.fishDeposited,
        text: `${userDoc.data().name || 'A member'} deposited ${amount} fish into the guild fund.`
      });
      result = { newBalance: balance - amount, groupFund: fund.newFund, unlockedAchievements: fund.unlocked };
    });

    return { message: `Successfully deposited ${amount} fish!`, ...result };
  }));

  app.get(['/buildingStats/:buildingId', '/api/buildingStats/:buildingId'], authenticateToken, route(async (req) => {
    const buildingId = requireId(req.params.buildingId, 'buildingId');
    const buildingDoc = await buildingRefFor(buildingId).get();
    if (!buildingDoc.exists) throw notFound('BUILDING_NOT_FOUND', 'Neighbourhood not found.');
    const building = buildingDoc.data();
    const memberIds = building.memberIds || [];
    if (!memberIds.includes(req.uid)) throw forbidden('NOT_A_MEMBER', 'You are not a member of this neighbourhood.');
    if (memberIds.length === 0) return { buildingId, name: building.name || 'Cell Group', groupFund: building.groupFund || 0, members: [] };

    const startKey = getPeriodKey('daily', new Date(Date.now() - 6 * 86400000));
    // Two batched reads regardless of member count: profiles and activity
    // aggregates maintained by reward transactions and the goals trigger.
    const [userDocs, activityDocs] = await Promise.all([
      db.getAll(...memberIds.map(userRefFor)),
      db.getAll(...memberIds.map((m) => db.collection('memberActivity').doc(m)))
    ]);

    const members = await Promise.all(memberIds.map(async (mUid, i) => {
      const profile = userDocs[i].exists ? userDocs[i].data() : {};
      const activity = activityDocs[i].exists ? activityDocs[i].data() : {};
      // One-time fallbacks for members whose aggregates predate this code.
      const goalCounts = activity.goalCounts || await recomputeGoalCounts(mUid);
      let completions;
      if (activity.days) {
        completions = Object.entries(activity.days).filter(([day]) => day >= startKey).reduce((sum, [, n]) => sum + n, 0);
      } else {
        const snap = await db.collection('completions').where('userId', '==', mUid).where('date', '>=', startKey).get();
        completions = snap.docs.filter((c) => c.data().refType === 'goal').length;
      }
      return {
        uid: mUid,
        name: profile.name || 'Group Member',
        avatarConfig: profile.avatarConfig || {},
        completions,
        completionTarget: Math.round(weeklyCompletionTarget(goalCounts) * 10) / 10,
        completionPercent: completionPercent(completions, goalCounts)
      };
    }));

    return { buildingId, name: building.name || 'Cell Group', groupFund: building.groupFund || 0, members };
  }));
}

module.exports = { register };
