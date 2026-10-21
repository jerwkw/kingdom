// One-off, idempotent migration: removes the retired `role` field from users
// and `authorRole` from bulletin posts.
//
//   node scripts/remove-legacy-role.js            # dry run (default)
//   node scripts/remove-legacy-role.js --apply    # write changes
//
// Requires Application Default Credentials for the target project
// (GOOGLE_CLOUD_PROJECT / `gcloud auth application-default login`), or
// FIRESTORE_EMULATOR_HOST for a local run.
const { db, FieldValue } = require('../lib/firebase');

const apply = process.argv.includes('--apply');

async function strip(collection, field) {
  const snap = await db.collection(collection).get();
  const targets = snap.docs.filter((doc) => Object.prototype.hasOwnProperty.call(doc.data(), field));
  for (let i = 0; apply && i < targets.length; i += 400) {
    const batch = db.batch();
    targets.slice(i, i + 400).forEach((doc) => batch.update(doc.ref, { [field]: FieldValue.delete() }));
    await batch.commit();
  }
  console.log(`${collection}.${field}: ${targets.length} document(s) ${apply ? 'updated' : 'would be updated'}`);
}

(async () => {
  await strip('users', 'role');
  await strip('bulletinPosts', 'authorRole');
  if (!apply) console.log('Dry run only. Re-run with --apply to write.');
})().catch((err) => {
  console.error(err);
  process.exit(1);
});
