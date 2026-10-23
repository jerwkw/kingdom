const test = require('node:test');
const fs = require('node:fs');
const path = require('node:path');
const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds
} = require('@firebase/rules-unit-testing');
const { serverTimestamp } = require('firebase/firestore');

let env;

test.before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-kingdom',
    firestore: {
      rules: fs.readFileSync(path.join(__dirname, '../../firestore.rules'), 'utf8')
    }
  });
});

test.after(async () => env.cleanup());

// Seed fresh data for each isolated test.
test.beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await db.doc('users/alice').set({ name: 'Alice', avatarConfig: { hairStyle: 'short_classic' }, buildingId: 'home', fishBalance: 10 });
    await db.doc('users/bob').set({ name: 'Bob', avatarConfig: {}, buildingId: 'home', fishBalance: 10 });
    await db.doc('users/eve').set({ name: 'Eve', avatarConfig: {}, buildingId: 'elsewhere', fishBalance: 10 });
    await db.doc('users/legacy').set({ name: 'Legacy', role: 'gardener', avatarConfig: {}, buildingId: null, fishBalance: 10 });
    await db.doc('buildings/home').set({ memberIds: ['alice', 'bob'], groupFund: 0 });
    await db.doc('buildings/home/fundLedger/entry').set({ uid: 'alice', amount: 1 });
    await db.doc('buildings/home/achievements/founded').set({ achievementId: 'founded' });
    await db.doc('goals/alice-goal').set({ userId: 'alice', currentStreak: 0, text: 'private', task: 'SMART Goal', frequency: 'daily', type: 'smart' });
    await db.doc('completions/alice-completion').set({ userId: 'alice' });
    await db.doc('bulletinPosts/post').set({ userId: 'alice', buildingId: 'home', text: 'hello', reactions: { bob: '🙏' } });
    await db.doc('inventory/alice/items/hat').set({ category: 'headpiece' });
    await db.doc('notifications/n1').set({ recipientUid: 'alice', text: 'hi', readAt: null });
  });
});

test('users cannot change their fish balance or building membership', async () => {
  const db = env.authenticatedContext('alice').firestore();
  await assertFails(db.doc('users/alice').update({ fishBalance: 9999 }));
  await assertFails(db.doc('users/alice').update({ buildingId: 'elsewhere' }));
  await assertSucceeds(db.doc('users/alice').update({ name: 'Alice Updated' }));
});

test('profiles no longer accept a role and names are length limited', async () => {
  const newbie = env.authenticatedContext('newbie').firestore();
  const profile = { name: 'New', avatarConfig: {}, buildingId: null, fishBalance: 10 };
  await assertFails(newbie.doc('users/newbie').set({ ...profile, role: 'gardener' }));
  await assertFails(newbie.doc('users/newbie').set({ ...profile, name: 'x'.repeat(41) }));
  await assertSucceeds(newbie.doc('users/newbie').set(profile));

  const alice = env.authenticatedContext('alice').firestore();
  await assertFails(alice.doc('users/alice').update({ role: 'painter' }));

  // Legacy profiles that still carry a role can update other fields.
  const legacy = env.authenticatedContext('legacy').firestore();
  await assertSucceeds(legacy.doc('users/legacy').update({ name: 'Legacy Renamed' }));
});

test('clients cannot equip purchased items by editing avatarConfig', async () => {
  const alice = env.authenticatedContext('alice').firestore();
  await assertFails(alice.doc('users/alice').update({ avatarConfig: { hairStyle: 'short_classic', headpiece: 'head_crown' } }));
  await assertSucceeds(alice.doc('users/alice').update({ avatarConfig: { hairStyle: 'long_wavy' } }));

  const newbie = env.authenticatedContext('newbie').firestore();
  await assertFails(newbie.doc('users/newbie').set({
    name: 'New', avatarConfig: { companion: 'companion_lamb' }, buildingId: null, fishBalance: 10
  }));
});

test('goals stay private and clients cannot forge completions or streaks', async () => {
  const alice = env.authenticatedContext('alice').firestore();
  const bob = env.authenticatedContext('bob').firestore();
  await assertFails(bob.doc('goals/alice-goal').get());
  await assertFails(alice.doc('completions/fake').set({ userId: 'alice' }));
  await assertFails(alice.doc('goals/alice-goal').update({ currentStreak: 99 }));
});

test('users can look up their own missing completions but not anyone else\'s', async () => {
  const alice = env.authenticatedContext('alice').firestore();
  const bob = env.authenticatedContext('bob').firestore();
  await assertSucceeds(alice.doc('completions/alice_challenge_2026-10-23').get());
  await assertSucceeds(alice.doc('completions/alice-completion').get());
  await assertFails(bob.doc('completions/alice_challenge_2026-10-23').get());
  await assertFails(bob.doc('completions/alice-completion').get());
});

test('goal owners can edit, archive and delete within limits', async () => {
  const alice = env.authenticatedContext('alice').firestore();
  await assertSucceeds(alice.doc('goals/alice-goal').update({ text: 'edited', frequency: 'weekly' }));
  await assertSucceeds(alice.doc('goals/alice-goal').update({ archived: true }));
  await assertFails(alice.doc('goals/alice-goal').update({ text: 'x'.repeat(281) }));
  await assertFails(alice.doc('goals/alice-goal').update({ frequency: 'hourly' }));
  await assertFails(alice.doc('goals/new').set({
    userId: 'alice', type: 'smart', task: 'SMART Goal', text: 'x'.repeat(281), frequency: 'daily', currentStreak: 0, sharedToBulletin: false
  }));
  await assertSucceeds(alice.doc('goals/new').set({
    userId: 'alice', type: 'smart', task: 'SMART Goal', text: 'ok', frequency: 'monthly', currentStreak: 0, sharedToBulletin: false, archived: false
  }));
  await assertSucceeds(alice.doc('goals/alice-goal').delete());
});

test('inventory is owner-readable but client writes are denied', async () => {
  const alice = env.authenticatedContext('alice').firestore();
  const bob = env.authenticatedContext('bob').firestore();
  await assertSucceeds(alice.doc('inventory/alice/items/hat').get());
  await assertFails(bob.doc('inventory/alice/items/hat').get());
  await assertFails(alice.doc('inventory/alice/items/new').set({ equipped: false }));
});

test('outsiders cannot read or react to another building bulletin', async () => {
  const bob = env.authenticatedContext('bob').firestore();
  const eve = env.authenticatedContext('eve').firestore();
  await assertSucceeds(bob.doc('bulletinPosts/post').update({ reactions: { bob: '❤️' } }));
  await assertFails(eve.doc('bulletinPosts/post').get());
  await assertFails(eve.doc('bulletinPosts/post').update({ reactions: { bob: '🙏', eve: '🙏' } }));
});

test('members can only change their own reaction, with allowed emoji', async () => {
  const alice = env.authenticatedContext('alice').firestore();
  const bob = env.authenticatedContext('bob').firestore();
  await assertSucceeds(alice.doc('bulletinPosts/post').update({ reactions: { bob: '🙏', alice: '🙌' } }));
  await assertFails(alice.doc('bulletinPosts/post').update({ reactions: { alice: '🙌' } }));
  await assertFails(bob.doc('bulletinPosts/post').update({ reactions: { bob: '💩' } }));
  await assertSucceeds(bob.doc('bulletinPosts/post').update({ reactions: { alice: '🙌' } }));
});

test('bulletin posts are created by the API; authors edit text within limits', async () => {
  const alice = env.authenticatedContext('alice').firestore();
  const bob = env.authenticatedContext('bob').firestore();
  await assertFails(alice.collection('bulletinPosts').add({ userId: 'alice', buildingId: 'home', text: 'new', reactions: {} }));
  await assertSucceeds(alice.doc('bulletinPosts/post').update({ text: 'edited', editedAt: serverTimestamp() }));
  await assertFails(alice.doc('bulletinPosts/post').update({ text: 'x'.repeat(1001), editedAt: serverTimestamp() }));
  await assertFails(alice.doc('bulletinPosts/post').update({ buildingId: 'elsewhere' }));
  await assertFails(bob.doc('bulletinPosts/post').update({ text: 'hijack', editedAt: serverTimestamp() }));
  await assertFails(bob.doc('bulletinPosts/post').delete());
  await assertSucceeds(alice.doc('bulletinPosts/post').delete());
});

test('notifications are recipient-readable and only markable as read', async () => {
  const alice = env.authenticatedContext('alice').firestore();
  const bob = env.authenticatedContext('bob').firestore();
  await assertSucceeds(alice.doc('notifications/n1').get());
  await assertFails(bob.doc('notifications/n1').get());
  await assertFails(alice.doc('notifications/n1').update({ text: 'forged' }));
  await assertFails(bob.doc('notifications/n1').update({ readAt: serverTimestamp() }));
  await assertSucceeds(alice.doc('notifications/n1').update({ readAt: serverTimestamp() }));
  await assertFails(alice.collection('notifications').add({ recipientUid: 'bob', text: 'spam' }));
  await assertSucceeds(alice.collection('notifications').where('recipientUid', '==', 'alice').get());
  await assertFails(alice.collection('notifications').get());
});

test('guild ledger and achievements are member-readable and server-written', async () => {
  const alice = env.authenticatedContext('alice').firestore();
  const eve = env.authenticatedContext('eve').firestore();
  await assertSucceeds(alice.doc('buildings/home/fundLedger/entry').get());
  await assertSucceeds(alice.doc('buildings/home/achievements/founded').get());
  await assertFails(eve.doc('buildings/home/achievements/founded').get());
  await assertFails(alice.doc('buildings/home/achievements/citadel').set({ achievementId: 'citadel' }));
  await assertFails(alice.doc('buildings/home/fundLedger/forged').set({ amount: 500 }));
});

test('server bookkeeping collections are closed to clients', async () => {
  const alice = env.authenticatedContext('alice').firestore();
  await assertFails(alice.doc('memberActivity/alice').get());
  await assertFails(alice.doc('rateLimits/alice_completeGoal_0').set({ count: 0 }));
  await assertFails(alice.doc('inviteCodes/HOME').get());
});
