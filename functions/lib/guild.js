const { db, FieldValue } = require('./firebase');
const { achievementsCrossed } = require('./domain');

// Notification event types written by the server. Clients may only mark their
// own notifications as read (see firestore.rules).
const NOTIFICATION_TYPES = Object.freeze({
  joinRequest: 'join_request',
  requestApproved: 'request_approved',
  requestRejected: 'request_rejected',
  memberJoined: 'member_joined',
  memberLeft: 'member_left',
  fishDeposited: 'fish_deposited',
  achievementUnlocked: 'achievement_unlocked',
  leadershipChanged: 'leadership_changed'
});

// Writes one notification per recipient inside an existing transaction.
// Document ids are `${eventId}_${recipientUid}`, so a retried transaction or a
// replayed event overwrites rather than duplicates.
function queueNotifications(transaction, { eventId, recipients, buildingId, type, text, target = 'guild' }) {
  for (const recipientUid of new Set(recipients)) {
    const ref = db.collection('notifications').doc(`${eventId}_${recipientUid}`);
    transaction.set(ref, {
      recipientUid,
      buildingId,
      type,
      text,
      target,
      createdAt: FieldValue.serverTimestamp(),
      readAt: null
    });
  }
}

function newEventId() {
  return db.collection('_').doc().id;
}

// Applies a change to a building's group fund inside a transaction that has
// already read `buildingData` (all reads must precede this call). Records a
// ledger entry, and an achievement event for each threshold crossed.
function applyFundChange(transaction, { buildingRef, buildingData, amount, source, uid, entryId = newEventId() }) {
  const previousFund = buildingData.groupFund || 0;
  const newFund = previousFund + amount;

  transaction.update(buildingRef, {
    groupFund: FieldValue.increment(amount),
    lastActivityAt: FieldValue.serverTimestamp()
  });
  transaction.set(buildingRef.collection('fundLedger').doc(entryId), {
    uid,
    amount,
    source,
    balanceAfter: newFund,
    createdAt: FieldValue.serverTimestamp()
  });

  const unlocked = achievementsCrossed(previousFund, newFund);
  for (const achievement of unlocked) {
    transaction.set(buildingRef.collection('achievements').doc(achievement.id), {
      achievementId: achievement.id,
      threshold: achievement.threshold,
      unlockedAt: FieldValue.serverTimestamp(),
      fundBalance: newFund,
      triggerSource: source,
      triggerUid: uid,
      triggerLedgerEntryId: entryId,
      backfilled: false
    });
    queueNotifications(transaction, {
      eventId: `achievement_${buildingRef.id}_${achievement.id}`,
      recipients: buildingData.memberIds || [],
      buildingId: buildingRef.id,
      type: NOTIFICATION_TYPES.achievementUnlocked,
      text: `${buildingData.name || 'Your guild'} unlocked a new achievement at ${achievement.threshold} fish!`,
      target: 'achievements'
    });
  }

  return { previousFund, newFund, unlocked: unlocked.map((a) => a.id), entryId };
}

module.exports = { NOTIFICATION_TYPES, applyFundChange, newEventId, queueNotifications };
