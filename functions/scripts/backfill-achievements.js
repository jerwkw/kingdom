// One-off, idempotent backfill of guild achievement history from each
// building's current fund total. Existing unlock events are never touched.
// No historical contribution data exists for older guilds, so backfilled
// events have `unlockedAt: null` and `backfilled: true`; the app shows their
// date as unknown.
//
//   node scripts/backfill-achievements.js            # dry run (default)
//   node scripts/backfill-achievements.js --apply    # write changes
const { db, FieldValue } = require('../lib/firebase');
const { ACHIEVEMENTS } = require('../lib/domain');

const apply = process.argv.includes('--apply');

(async () => {
  const buildings = await db.collection('buildings').get();
  let created = 0;
  for (const building of buildings.docs) {
    const fund = building.data().groupFund || 0;
    const existing = await building.ref.collection('achievements').get();
    const have = new Set(existing.docs.map((d) => d.id));
    const missing = ACHIEVEMENTS.filter((a) => a.threshold <= fund && !have.has(a.id));
    if (missing.length === 0) continue;

    const batch = db.batch();
    for (const achievement of missing) {
      batch.create(building.ref.collection('achievements').doc(achievement.id), {
        achievementId: achievement.id,
        threshold: achievement.threshold,
        unlockedAt: null,
        fundBalance: fund,
        triggerSource: 'backfill',
        backfilled: true,
        backfilledAt: FieldValue.serverTimestamp()
      });
    }
    if (apply) await batch.commit();
    created += missing.length;
    console.log(`${building.id}: ${missing.map((a) => a.id).join(', ')}`);
  }
  console.log(`${created} achievement event(s) ${apply ? 'created' : 'would be created'}.`);
  if (!apply) console.log('Dry run only. Re-run with --apply to write.');
})().catch((err) => {
  console.error(err);
  process.exit(1);
});
