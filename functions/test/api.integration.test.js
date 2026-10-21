// Exercises every privileged API route through the Functions emulator with
// real Auth emulator ID tokens. Run via `npm run test:integration`.
const test = require('node:test');
const assert = require('node:assert/strict');
const admin = require('firebase-admin');

const PROJECT_ID = 'demo-kingdom';
const AUTH_HOST = process.env.FIREBASE_AUTH_EMULATOR_HOST || '127.0.0.1:9099';
const FUNCTIONS_HOST = process.env.FUNCTIONS_EMULATOR_HOST || '127.0.0.1:5001';
const API = `http://${FUNCTIONS_HOST}/${PROJECT_ID}/us-central1/api`;

if (!admin.apps.length) admin.initializeApp({ projectId: PROJECT_ID });
const db = admin.firestore();

let counter = 0;
const unique = (prefix) => `${prefix}${Date.now().toString(36)}${(counter++).toString(36)}`.toUpperCase();

async function signUp() {
  const res = await fetch(`http://${AUTH_HOST}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake-api-key`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ returnSecureToken: true })
  });
  const data = await res.json();
  return { uid: data.localId, token: data.idToken };
}

async function createUser(name = 'Member', fishBalance = 10) {
  const user = await signUp();
  await db.doc(`users/${user.uid}`).set({ name, avatarConfig: {}, buildingId: null, fishBalance });
  return user;
}

async function call(user, path, body, { method = 'POST', token } = {}) {
  const headers = { 'Content-Type': 'application/json' };
  const bearer = token !== undefined ? token : user && user.token;
  if (bearer) headers.Authorization = `Bearer ${bearer}`;
  const res = await fetch(`${API}/${path}`, { method, headers, body: method === 'GET' ? undefined : JSON.stringify(body || {}) });
  let data = {};
  try { data = await res.json(); } catch (_) { /* non-JSON error page */ }
  return { ...data, status: res.status };
}

const userDoc = async (uid) => (await db.doc(`users/${uid}`).get()).data();
const buildingDoc = async (id) => (await db.doc(`buildings/${id}`).get()).data();

async function createGuild(leader, name = 'Guild') {
  const res = await call(leader, 'createBuilding', { name, inviteCode: unique('G'), description: '' });
  assert.equal(res.status, 200, JSON.stringify(res));
  const building = await buildingDoc(res.buildingId);
  return { id: res.buildingId, inviteCode: building.inviteCode };
}

async function addMember(guild, leader, member) {
  assert.equal((await call(member, 'joinBuilding', { inviteCode: guild.inviteCode })).status, 200);
  assert.equal((await call(leader, 'approveJoinRequest', { buildingId: guild.id, targetUid: member.uid })).status, 200);
}

async function createGoal(uid, fields = {}) {
  const ref = await db.collection('goals').add({
    userId: uid, type: 'templated', task: 'Pray', text: '', frequency: 'daily',
    currentStreak: 0, sharedToBulletin: false, archived: false, ...fields
  });
  return ref.id;
}

async function waitFor(predicate, timeoutMs = 15000) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    if (await predicate()) return;
    await new Promise((r) => setTimeout(r, 200));
  }
  throw new Error('Timed out waiting for condition');
}

const statuses = (results) => results.map((r) => r.status).sort();

// --- Authentication & payloads ---------------------------------------------

test('requests without a valid token are rejected with a stable code', async () => {
  const missing = await call(null, 'completeGoal', { goalId: 'x' }, { token: '' });
  assert.equal(missing.status, 401);
  assert.equal(missing.code, 'UNAUTHENTICATED');

  const garbage = await call(null, 'completeGoal', { goalId: 'x' }, { token: 'not-a-jwt' });
  assert.equal(garbage.status, 401);

  const header = Buffer.from(JSON.stringify({ alg: 'none', typ: 'JWT' })).toString('base64url');
  const past = Math.floor(Date.now() / 1000) - 7200;
  const payload = Buffer.from(JSON.stringify({
    iss: `https://securetoken.google.com/${PROJECT_ID}`, aud: PROJECT_ID, sub: 'expired-user', user_id: 'expired-user',
    iat: past - 3600, exp: past, auth_time: past - 3600, firebase: { sign_in_provider: 'anonymous' }
  })).toString('base64url');
  const expired = await call(null, 'completeGoal', { goalId: 'x' }, { token: `${header}.${payload}.` });
  assert.equal(expired.status, 401);
});

test('malformed payloads are rejected before any write', async () => {
  const user = await createUser();
  for (const goalId of [undefined, '', 42, { nested: true }, 'a/b', 'x'.repeat(200)]) {
    const res = await call(user, 'completeGoal', { goalId });
    assert.equal(res.status, 400, `goalId=${JSON.stringify(goalId)}`);
    assert.ok(['INVALID_INPUT', 'TEXT_TOO_LONG'].includes(res.code), res.code);
  }
  for (const amount of [0, -5, 1.5, '10', 1e9]) {
    const res = await call(user, 'depositFish', { buildingId: 'b', amount });
    assert.equal(res.status, 400, `amount=${amount}`);
    assert.equal(res.code, 'INVALID_AMOUNT');
  }
  assert.equal((await userDoc(user.uid)).fishBalance, 10);
});

// --- Goal & reflection rewards ----------------------------------------------

test('completeGoal awards once and updates streak, fund, ledger and activity', async () => {
  const user = await createUser('Goal Owner');
  const guild = await createGuild(user);
  const goalId = await createGoal(user.uid);

  const res = await call(user, 'completeGoal', { goalId });
  assert.equal(res.status, 200, JSON.stringify(res));
  assert.equal(res.fishAwarded, 10);
  assert.equal(res.newStreak, 1);
  assert.equal(res.groupFundContribution, 1);
  assert.ok(res.completionId.startsWith(`${user.uid}_${goalId}_`));

  assert.equal((await userDoc(user.uid)).fishBalance, 20);
  assert.equal((await buildingDoc(guild.id)).groupFund, 1);
  assert.equal((await db.doc(`goals/${goalId}`).get()).data().currentStreak, 1);
  assert.ok((await db.doc(`completions/${res.completionId}`).get()).exists);
  const ledger = await db.collection(`buildings/${guild.id}/fundLedger`).get();
  assert.deepEqual(ledger.docs.map((d) => [d.data().source, d.data().amount]), [['goal', 1]]);
  const activity = (await db.doc(`memberActivity/${user.uid}`).get()).data();
  assert.equal(Object.values(activity.days).reduce((a, b) => a + b, 0), 1);
});

test('concurrent duplicate goal completions reward exactly once', async () => {
  const user = await createUser();
  const guild = await createGuild(user);
  const goalId = await createGoal(user.uid);

  const results = await Promise.all(Array.from({ length: 5 }, () => call(user, 'completeGoal', { goalId })));
  assert.deepEqual(statuses(results), [200, 409, 409, 409, 409]);
  assert.ok(results.filter((r) => r.status === 409).every((r) => r.code === 'ALREADY_COMPLETED'));
  assert.equal((await userDoc(user.uid)).fishBalance, 20);
  assert.equal((await buildingDoc(guild.id)).groupFund, 1);
  assert.equal((await db.doc(`goals/${goalId}`).get()).data().currentStreak, 1);
  assert.equal((await db.collection(`buildings/${guild.id}/fundLedger`).get()).size, 1);
});

test('completeGoal rejects goals that are missing, foreign or archived', async () => {
  const owner = await createUser();
  const other = await createUser();
  const goalId = await createGoal(owner.uid);
  const archivedId = await createGoal(owner.uid, { archived: true });

  assert.equal((await call(other, 'completeGoal', { goalId })).code, 'FORBIDDEN');
  assert.equal((await call(owner, 'completeGoal', { goalId: 'doesNotExist' })).status, 404);
  const archived = await call(owner, 'completeGoal', { goalId: archivedId });
  assert.equal(archived.status, 409);
  assert.equal(archived.code, 'GOAL_ARCHIVED');
  assert.equal((await userDoc(other.uid)).fishBalance, 10);
});

test('daily reflection completes once even under concurrent requests', async () => {
  const user = await createUser();
  const results = await Promise.all(Array.from({ length: 3 }, () => call(user, 'completeDailyChallenge')));
  assert.deepEqual(statuses(results), [200, 409, 409]);
  assert.equal((await userDoc(user.uid)).fishBalance, 20);
  assert.equal((await call(user, 'ensureDailyChallenge')).status, 200);
});

// --- Deposits & achievements -------------------------------------------------

test('depositFish moves fish, records ledger and notifies other members', async () => {
  const leader = await createUser('Leader', 15);
  const member = await createUser('Member', 10);
  const guild = await createGuild(leader);
  await addMember(guild, leader, member);

  const res = await call(leader, 'depositFish', { buildingId: guild.id, amount: 12 });
  assert.equal(res.status, 200, JSON.stringify(res));
  assert.equal(res.newBalance, 3);
  assert.equal(res.groupFund, 12);
  assert.deepEqual(res.unlockedAchievements, ['first_fish']);

  const ledger = await db.collection(`buildings/${guild.id}/fundLedger`).where('source', '==', 'deposit').get();
  assert.equal(ledger.size, 1);
  assert.equal(ledger.docs[0].data().balanceAfter, 12);
  const notes = await db.collection('notifications').where('recipientUid', '==', member.uid).where('type', '==', 'fish_deposited').get();
  assert.equal(notes.size, 1);
  const leaderNotes = await db.collection('notifications').where('recipientUid', '==', leader.uid).where('type', '==', 'fish_deposited').get();
  assert.equal(leaderNotes.size, 0);
});

test('depositFish rejects insufficient, stale, non-member and concurrent overdrafts', async () => {
  const leader = await createUser('Leader', 10);
  const outsider = await createUser('Outsider', 50);
  const guild = await createGuild(leader);

  const insufficient = await call(leader, 'depositFish', { buildingId: guild.id, amount: 11 });
  assert.equal(insufficient.code, 'INSUFFICIENT_FUNDS');
  assert.equal((await call(outsider, 'depositFish', { buildingId: guild.id, amount: 5 })).code, 'NOT_A_MEMBER');
  assert.equal((await call(leader, 'depositFish', { buildingId: 'missing', amount: 1 })).status, 404);

  // Two deposits of 6 race against a balance of 10: exactly one may succeed.
  const results = await Promise.all([6, 6].map((amount) => call(leader, 'depositFish', { buildingId: guild.id, amount })));
  assert.deepEqual(statuses(results), [200, 400]);
  assert.equal((await userDoc(leader.uid)).fishBalance, 4);
  assert.equal((await buildingDoc(guild.id)).groupFund, 6);

  // A stale client that still believes it has 10 fish is refused.
  assert.equal((await call(leader, 'depositFish', { buildingId: guild.id, amount: 10 })).code, 'INSUFFICIENT_FUNDS');
});

test('achievements unlock once even when deposits race across a threshold', async () => {
  const a = await createUser('A', 30);
  const b = await createUser('B', 30);
  const guild = await createGuild(a);
  await addMember(guild, a, b);

  const results = await Promise.all([call(a, 'depositFish', { buildingId: guild.id, amount: 6 }), call(b, 'depositFish', { buildingId: guild.id, amount: 6 })]);
  assert.deepEqual(statuses(results), [200, 200]);
  assert.equal(results.flatMap((r) => r.unlockedAchievements).filter((id) => id === 'first_fish').length, 1);

  const achievements = await db.collection(`buildings/${guild.id}/achievements`).get();
  assert.deepEqual(achievements.docs.map((d) => d.id).sort(), ['first_fish', 'founded']);
  const notes = await db.collection('notifications').where('buildingId', '==', guild.id).where('type', '==', 'achievement_unlocked').get();
  assert.equal(notes.size, 2); // one per member

  await call(a, 'depositFish', { buildingId: guild.id, amount: 1 });
  assert.equal((await db.collection(`buildings/${guild.id}/achievements`).get()).size, 2);
});

// --- Building creation & joining --------------------------------------------

test('createBuilding validates input and reserves invite codes', async () => {
  const user = await createUser();
  assert.equal((await call(user, 'createBuilding', { name: '', inviteCode: 'ABCD' })).code, 'INVALID_INPUT');
  assert.equal((await call(user, 'createBuilding', { name: 'x'.repeat(61), inviteCode: 'ABCD' })).code, 'TEXT_TOO_LONG');
  assert.equal((await call(user, 'createBuilding', { name: 'Ok', inviteCode: 'no spaces!' })).code, 'INVALID_INVITE_CODE');

  const guild = await createGuild(user);
  const again = await call(user, 'createBuilding', { name: 'Second', inviteCode: unique('S') });
  assert.equal(again.code, 'ALREADY_IN_BUILDING');
  assert.ok((await db.doc(`buildings/${guild.id}/achievements/founded`).get()).exists);
});

test('concurrent creations with the same invite code yield one building', async () => {
  const a = await createUser();
  const b = await createUser();
  const code = unique('DUP');
  const results = await Promise.all([a, b].map((u) => call(u, 'createBuilding', { name: 'Dup', inviteCode: code })));
  assert.deepEqual(statuses(results), [200, 409]);
  assert.equal(results.find((r) => r.status === 409).code, 'INVITE_CODE_TAKEN');
  assert.equal((await db.collection('buildings').where('inviteCode', '==', code).get()).size, 1);
});

test('joinBuilding queues one request and notifies admins', async () => {
  const leader = await createUser('Leader');
  const joiner = await createUser('Joiner');
  const guild = await createGuild(leader);

  assert.equal((await call(joiner, 'joinBuilding', { inviteCode: 'NOSUCHCODE' })).code, 'INVALID_INVITE_CODE');
  assert.equal((await call(joiner, 'joinBuilding', { inviteCode: guild.inviteCode.toLowerCase() })).status, 200);
  assert.equal((await call(joiner, 'joinBuilding', { inviteCode: guild.inviteCode })).code, 'REQUEST_PENDING');
  assert.equal((await buildingDoc(guild.id)).pendingJoinRequests.length, 1);

  const notes = await db.collection('notifications').where('recipientUid', '==', leader.uid).where('type', '==', 'join_request').get();
  assert.equal(notes.size, 1);
  assert.equal(notes.docs[0].data().readAt, null);
});

// --- Approval, rejection & promotion ----------------------------------------

test('only admins of that building can approve or reject', async () => {
  const leader = await createUser();
  const joiner = await createUser();
  const otherLeader = await createUser();
  const guild = await createGuild(leader);
  await createGuild(otherLeader);
  await call(joiner, 'joinBuilding', { inviteCode: guild.inviteCode });

  assert.equal((await call(joiner, 'approveJoinRequest', { buildingId: guild.id, targetUid: joiner.uid })).code, 'NOT_ADMIN');
  assert.equal((await call(otherLeader, 'approveJoinRequest', { buildingId: guild.id, targetUid: joiner.uid })).code, 'NOT_ADMIN');
  assert.equal((await call(otherLeader, 'rejectJoinRequest', { buildingId: guild.id, targetUid: joiner.uid })).code, 'NOT_ADMIN');
  assert.equal((await call(leader, 'approveJoinRequest', { buildingId: guild.id })).code, 'INVALID_INPUT');

  const reject = await call(leader, 'rejectJoinRequest', { buildingId: guild.id, targetUid: joiner.uid });
  assert.equal(reject.status, 200);
  assert.equal((await call(leader, 'rejectJoinRequest', { buildingId: guild.id, targetUid: joiner.uid })).code, 'NO_PENDING_REQUEST');
  const notes = await db.collection('notifications').where('recipientUid', '==', joiner.uid).where('type', '==', 'request_rejected').get();
  assert.equal(notes.size, 1);
});

test('two concurrent approvals of the same request apply once', async () => {
  const leader = await createUser('Leader');
  const admin2 = await createUser('Admin');
  const joiner = await createUser('Joiner');
  const guild = await createGuild(leader);
  await addMember(guild, leader, admin2);
  assert.equal((await call(leader, 'promoteBuildingAdmin', { buildingId: guild.id, targetUid: admin2.uid })).status, 200);
  await call(joiner, 'joinBuilding', { inviteCode: guild.inviteCode });

  const results = await Promise.all([leader, admin2].map((u) => call(u, 'approveJoinRequest', { buildingId: guild.id, targetUid: joiner.uid })));
  assert.deepEqual(statuses(results), [200, 409]);

  const building = await buildingDoc(guild.id);
  assert.equal(building.memberIds.filter((m) => m === joiner.uid).length, 1);
  assert.equal(building.pendingJoinRequests.length, 0);
  assert.equal((await userDoc(joiner.uid)).buildingId, guild.id);
  const welcomes = await db.collection('notifications').where('recipientUid', '==', joiner.uid).where('type', '==', 'request_approved').get();
  assert.equal(welcomes.size, 1);
});

test('approval is refused once the requester has joined another building', async () => {
  const leaderA = await createUser();
  const leaderB = await createUser();
  const joiner = await createUser();
  const a = await createGuild(leaderA, 'A');
  const b = await createGuild(leaderB, 'B');
  await call(joiner, 'joinBuilding', { inviteCode: a.inviteCode });
  await call(joiner, 'joinBuilding', { inviteCode: b.inviteCode });

  const results = await Promise.all([
    call(leaderA, 'approveJoinRequest', { buildingId: a.id, targetUid: joiner.uid }),
    call(leaderB, 'approveJoinRequest', { buildingId: b.id, targetUid: joiner.uid })
  ]);
  assert.deepEqual(statuses(results), [200, 409]);
  assert.equal(results.find((r) => r.status === 409).code, 'TARGET_IN_OTHER_BUILDING');

  const joined = (await userDoc(joiner.uid)).buildingId;
  const [docA, docB] = await Promise.all([buildingDoc(a.id), buildingDoc(b.id)]);
  assert.equal([docA, docB].filter((d) => d.memberIds.includes(joiner.uid)).length, 1);
  assert.ok((joined === a.id ? docA : docB).memberIds.includes(joiner.uid));
});

test('only the leader can promote, and only members', async () => {
  const leader = await createUser();
  const member = await createUser();
  const outsider = await createUser();
  const guild = await createGuild(leader);
  await addMember(guild, leader, member);

  assert.equal((await call(member, 'promoteBuildingAdmin', { buildingId: guild.id, targetUid: member.uid })).code, 'NOT_LEADER');
  assert.equal((await call(leader, 'promoteBuildingAdmin', { buildingId: guild.id, targetUid: outsider.uid })).code, 'NOT_A_MEMBER');
  assert.equal((await call(leader, 'promoteBuildingAdmin', { buildingId: guild.id, targetUid: member.uid })).status, 200);
  assert.ok((await buildingDoc(guild.id)).adminUids.includes(member.uid));
});

// --- Leaving -----------------------------------------------------------------

test('two concurrent leaves keep membership, admins and leader consistent', async () => {
  const leader = await createUser('Leader');
  const m1 = await createUser('M1');
  const m2 = await createUser('M2');
  const guild = await createGuild(leader);
  await addMember(guild, leader, m1);
  await addMember(guild, leader, m2);
  await call(leader, 'promoteBuildingAdmin', { buildingId: guild.id, targetUid: m1.uid });

  const results = await Promise.all([leader, m1].map((u) => call(u, 'leaveBuilding', { buildingId: guild.id })));
  assert.deepEqual(statuses(results), [200, 200]);

  const building = await buildingDoc(guild.id);
  assert.deepEqual(building.memberIds, [m2.uid]);
  assert.equal(building.leaderUid, m2.uid);
  assert.deepEqual(building.adminUids, [m2.uid]);
  assert.equal((await userDoc(leader.uid)).buildingId, null);
  assert.equal((await userDoc(m1.uid)).buildingId, null);
  assert.equal((await userDoc(m2.uid)).buildingId, guild.id);
});

test('the last member leaving deletes the building and frees its invite code', async () => {
  const leader = await createUser();
  const guild = await createGuild(leader);
  await db.collection('bulletinPosts').add({ userId: leader.uid, buildingId: guild.id, text: 'bye', reactions: {} });

  const res = await call(leader, 'leaveBuilding', { buildingId: guild.id });
  assert.equal(res.deleted, true);
  assert.equal((await db.doc(`buildings/${guild.id}`).get()).exists, false);
  assert.equal((await db.doc(`inviteCodes/${guild.inviteCode}`).get()).exists, false);
  assert.equal((await db.collection('bulletinPosts').where('buildingId', '==', guild.id).get()).size, 0);
  assert.equal((await call(leader, 'leaveBuilding', { buildingId: guild.id })).status, 200);
});

test('a join approval racing a leave leaves profile and building in agreement', async () => {
  const leader = await createUser();
  const stayer = await createUser();
  const joiner = await createUser();
  const guild = await createGuild(leader);
  await addMember(guild, leader, stayer);
  await call(joiner, 'joinBuilding', { inviteCode: guild.inviteCode });

  await Promise.all([
    call(leader, 'approveJoinRequest', { buildingId: guild.id, targetUid: joiner.uid }),
    call(stayer, 'leaveBuilding', { buildingId: guild.id })
  ]);

  const building = await buildingDoc(guild.id);
  for (const uid of [leader.uid, stayer.uid, joiner.uid]) {
    const profile = await userDoc(uid);
    assert.equal(profile.buildingId === guild.id, building.memberIds.includes(uid), `uid ${uid}`);
  }
  assert.ok(!building.memberIds.includes(stayer.uid));
});

test('non-members cannot leave a building they are not in', async () => {
  const leader = await createUser();
  const outsider = await createUser();
  const guild = await createGuild(leader);
  assert.equal((await call(outsider, 'leaveBuilding', { buildingId: guild.id })).code, 'NOT_A_MEMBER');
});

// --- Store -------------------------------------------------------------------

test('purchases use server prices and equipping requires ownership', async () => {
  const user = await createUser('Shopper', 25);
  assert.equal((await call(user, 'purchaseItem', { itemId: 'free_crown' })).code, 'UNKNOWN_ITEM');
  assert.equal((await call(user, 'purchaseItem', { itemId: 'head_crown', cost: 0 })).code, 'INSUFFICIENT_FUNDS');
  assert.equal((await call(user, 'equipItem', { itemId: 'head_cap' })).code, 'NOT_OWNED');

  const bought = await call(user, 'purchaseItem', { itemId: 'head_cap' });
  assert.equal(bought.newBalance, 10);
  assert.equal((await call(user, 'purchaseItem', { itemId: 'head_cap' })).code, 'ALREADY_OWNED');

  assert.equal((await call(user, 'equipItem', { itemId: 'head_cap' })).equipped, true);
  assert.equal((await userDoc(user.uid)).avatarConfig.headpiece, 'head_cap');
  assert.equal((await call(user, 'equipItem', { itemId: 'head_cap' })).equipped, false);
  assert.equal((await userDoc(user.uid)).avatarConfig.headpiece, undefined);
});

test('concurrent purchases cannot overdraw the balance', async () => {
  const user = await createUser('Shopper', 40);
  const results = await Promise.all(['shirt_tunic', 'pants_joggers', 'head_halo'].map((itemId) => call(user, 'purchaseItem', { itemId })));
  const spent = 40 - (await userDoc(user.uid)).fishBalance;
  assert.ok(spent <= 40 && spent >= 0);
  assert.equal(results.filter((r) => r.status === 200).length, (await db.collection(`inventory/${user.uid}/items`).get()).size);
});

// --- Statistics & bulletin -----------------------------------------------------

test('buildingStats uses each member goal schedule and is member-only', async () => {
  const leader = await createUser('Leader');
  const outsider = await createUser();
  const guild = await createGuild(leader);
  const daily = await createGoal(leader.uid, { frequency: 'daily' });
  await createGoal(leader.uid, { frequency: 'weekly' });
  await waitFor(async () => {
    const counts = ((await db.doc(`memberActivity/${leader.uid}`).get()).data() || {}).goalCounts || {};
    return counts.daily === 1 && counts.weekly === 1;
  });
  await call(leader, 'completeGoal', { goalId: daily });

  const stats = await call(leader, `buildingStats/${guild.id}`, null, { method: 'GET' });
  assert.equal(stats.status, 200, JSON.stringify(stats));
  const me = stats.members.find((m) => m.uid === leader.uid);
  assert.equal(me.completionTarget, 8);
  assert.equal(me.completions, 1);
  assert.equal(me.completionPercent, 13);
  assert.equal(me.role, undefined);

  assert.equal((await call(outsider, `buildingStats/${guild.id}`, null, { method: 'GET' })).code, 'NOT_A_MEMBER');
});

test('bulletin posts are validated and limited to members', async () => {
  const leader = await createUser('Poster');
  const outsider = await createUser();
  await createGuild(leader);

  assert.equal((await call(outsider, 'createBulletinPost', { type: 'prayer', text: 'hi' })).code, 'NOT_A_MEMBER');
  assert.equal((await call(leader, 'createBulletinPost', { type: 'spam', text: 'hi' })).code, 'INVALID_INPUT');
  assert.equal((await call(leader, 'createBulletinPost', { type: 'prayer', text: 'x'.repeat(1001) })).code, 'TEXT_TOO_LONG');
  const ok = await call(leader, 'createBulletinPost', { type: 'prayer', text: '  Please pray for our week  ' });
  assert.equal(ok.status, 200);
  const post = (await db.doc(`bulletinPosts/${ok.postId}`).get()).data();
  assert.equal(post.text, 'Please pray for our week');
  assert.equal(post.authorName, 'Poster');
  assert.equal(post.authorRole, undefined);
});

test('rate limits return 429 with a stable code', async () => {
  const user = await createUser();
  const results = [];
  for (let i = 0; i < 11; i++) results.push(await call(user, 'joinBuilding', { inviteCode: 'NOSUCHCODE' }));
  assert.deepEqual(results.slice(0, 10).map((r) => r.status), Array(10).fill(404));
  assert.equal(results[10].status, 429);
  assert.equal(results[10].code, 'RATE_LIMITED');
});
