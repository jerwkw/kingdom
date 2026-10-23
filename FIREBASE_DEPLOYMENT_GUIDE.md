# Firebase Deployment Guide

Firebase is Kingdom's supported production platform. The Raspberry Pi backend is archived.

## Prerequisites

- Flutter SDK compatible with `pubspec.yaml`.
- Node.js 22 and Java for the Firestore emulator.
- Firebase project with Authentication, Firestore, Functions, and Hosting enabled.
- Google sign-in enabled with localhost and the Hosting domain authorized.
- Billing enabled for Functions, with budget alerts and appropriate project access controls.

## Install and select the project

```bash
flutter pub get
cd functions
npm install
cd ..
npx --prefix functions firebase login
npx --prefix functions firebase use staging    # or: prod
```

## Environments

| Alias | Project ID | URL | Web build |
| --- | --- | --- | --- |
| `staging` (default) | `church-app-staging-f8a55` | https://church-app-staging-f8a55.web.app | `flutter build web --dart-define=FIREBASE_ENV=staging` |
| `prod` | `church-app-f8a55` | https://church-app-f8a55.web.app | `flutter build web` |

`.firebaserc` defaults to staging, so an unqualified deploy never reaches production. Deploy every release to staging, run the post-deployment checks there, then repeat with `--project prod`. The web build picks its Firebase config from `FIREBASE_ENV` (`lib/config/firebase_options.dart`), so always rebuild `build/web` with the matching flag before deploying Hosting — a staging deploy of a production build talks to the production database.

Confirm the active project (`firebase use`) before every deployment.

### One-time staging console setup

1. Upgrade `church-app-staging-f8a55` to the Blaze plan (Functions and the scheduler need it) and add a small budget alert.
2. Enable the Cloud Firestore API, then create the database in `asia-southeast1` to match production: `npx --prefix functions firebase --project staging firestore:databases:create "(default)" --location asia-southeast1`.
3. Authentication → Get started → enable the Google provider. The `*.web.app` / `*.firebaseapp.com` domains and `localhost` are authorized by default.
4. Grant access only to the people who run deploys and acceptance checks.

## Verify before deployment

```bash
flutter analyze
flutter test
flutter build web
cd functions
npm test
npm run test:rules
npm run test:integration
cd ..
```

Do not deploy if a command fails. Rule and integration tests require the emulators (Java) and may download emulator artifacts on first use. The same checks run in `.github/workflows/ci.yml`; mark both CI jobs as required status checks in the GitHub branch protection settings for `main`.

## Configuration

- **CORS**: the API allows the deploying project's `*.web.app` / `*.firebaseapp.com` origins by default, derived from `GCLOUD_PROJECT` (see `functions/index.js`). For a different project or custom domain, set a comma-separated `ALLOWED_ORIGINS` in `functions/.env.<project-id>` (not committed if it contains anything private).
- **Rate-limit TTL**: `firestore.indexes.json` declares a TTL policy on `rateLimits.expiresAt`; deploying indexes enables it. Confirm it in the console under Firestore → TTL.

## Deployment order

```bash
npx --prefix functions firebase deploy --only firestore:rules,firestore:indexes
npx --prefix functions firebase deploy --only functions
npx --prefix functions firebase deploy --only hosting
```

Hosting serves `build/web` and rewrites `/api/**` to the authenticated `api` function.

### Release that removes roles and adds notifications/achievements

Older clients write `role`, create bulletin posts directly and equip items by editing `avatarConfig`; the new rules refuse all three. The new client works against the old rules, so for this release deploy in this order instead:

1. `firestore:indexes`, then wait until the new `notifications` and `bulletinPosts` indexes finish building.
2. `functions` (adds `equipItem`, `createBulletinPost`, `ensureDailyChallenge` and the `goalScheduleSync` trigger).
3. `hosting`.
4. `firestore:rules`.
5. One-off data scripts, dry run first (they need Application Default Credentials for the project):

   ```bash
   cd functions
   GOOGLE_CLOUD_PROJECT=<project-id> node scripts/remove-legacy-role.js          # dry run
   GOOGLE_CLOUD_PROJECT=<project-id> node scripts/remove-legacy-role.js --apply
   GOOGLE_CLOUD_PROJECT=<project-id> node scripts/backfill-achievements.js       # dry run
   GOOGLE_CLOUD_PROJECT=<project-id> node scripts/backfill-achievements.js --apply
   ```

   Both are idempotent. Backfilled achievements have no unlock date and are shown as "date unknown".

## Post-deployment checks

Using two non-production test accounts:

1. Sign in and complete onboarding.
2. Create daily, weekly, and monthly goals; confirm each rewards only once per period.
3. Create a neighbourhood, request access from account two, and approve it.
4. Confirm an outsider cannot retrieve statistics or react to its bulletin.
5. Purchase a known cosmetic and verify the amount matches the server catalog.
6. Complete a daily reflection and verify one completion, one balance increment, and one fund contribution.
7. Deposit fish from account one; confirm account two gets one notification, the bell badge updates live, and opening it marks it read and opens the guild.
8. Cross an achievement threshold; confirm it appears once in the guild history with its date.
9. Tick a goal; confirm the checkbox shows progress, then stays checked after reload.
10. Inspect Functions logs (structured, with `requestId`) for authorization or transaction errors.

## Local emulators

```bash
npx --prefix functions firebase emulators:start
flutter run -d chrome --dart-define=USE_FIREBASE_EMULATORS=true
```

Without the build flag, localhost uses deployed Firebase services.

## Rollback

For a security or economy regression, roll back Hosting and Functions using Firebase release history and redeploy the last known-good rules immediately. Never loosen rules as an availability workaround.
