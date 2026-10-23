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
tool/check.sh
```

This runs `flutter analyze`, `flutter test`, `flutter build web`, then the Functions domain, rules and integration tests, switching to the Node version in `.nvmrc` via nvm if needed. Do not deploy if it fails. Rule and integration tests require the emulators (Java) and may download emulator artifacts on first use. `.github/workflows/ci.yml` calls the same script on every pull request and before every deploy, and the pre-push hook (`git config core.hooksPath tool/git-hooks`) runs it before branch pushes.

## Configuration

- **CORS**: the API allows the deploying project's `*.web.app` / `*.firebaseapp.com` origins by default, derived from `GCLOUD_PROJECT` (see `functions/index.js`). For a different project or custom domain, set a comma-separated `ALLOWED_ORIGINS` in `functions/.env.<project-id>` (not committed if it contains anything private).
- **Rate-limit TTL**: `firestore.indexes.json` declares a TTL policy on `rateLimits.expiresAt`; deploying indexes enables it. Confirm it in the console under Firestore → TTL.

## Deployment order

Normally CI deploys (see "Releasing"). To deploy by hand, build for the target and run `tool/deploy.sh`, which deploys indexes → functions → hosting → rules and refuses a `build/web` built for the other project:

```bash
flutter build web --dart-define=FIREBASE_ENV=staging && tool/deploy.sh staging
flutter build web && tool/deploy.sh prod
```

Rules go last because the new client works against the old rules, while old clients may break under new ones. Hosting serves `build/web` and rewrites `/api/**` to the authenticated `api` function.

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

## Releasing

Work lands on `main` only through pull requests that pass CI (`flutter` and `functions` jobs). Every push to `main` deploys to staging (`.github/workflows/deploy-staging.yml`). Production deploys only from a `vMAJOR.MINOR.PATCH` tag (`deploy-prod.yml`).

1. Run the post-deployment checks on staging against the `main` commit you want to release.
2. In a PR: bump `version:` in `pubspec.yaml` (`X.Y.Z+N`, N increases every release) and rename `## [Unreleased]` in `CHANGELOG.md` to `## [X.Y.Z] - YYYY-MM-DD`. MAJOR = breaks older clients or needs a migration/special deploy order, MINOR = features, PATCH = fixes. Merge it and wait for the staging deploy of the merge commit to succeed.
3. `git switch main && git pull && tool/release-check.sh vX.Y.Z`, then `git tag -a vX.Y.Z -m "vX.Y.Z" && git push origin vX.Y.Z`.
4. `deploy-prod.yml` checks the tag (format, `pubspec.yaml`, changelog entry, commit on `main`, successful staging deploy of that exact commit), reruns CI, then waits for approval on the `production` environment. Approve it in the Actions run.
5. After the deploy, run any one-off scripts named in the changelog's deploy notes, then the post-deployment checks on production. The workflow publishes a GitHub Release from the changelog section.

A release whose changelog says it needs a different deploy order is deployed to prod by hand first, in that order. Then push the tag as usual: the workflow redeploys the same commit (a no-op in effect) and creates the Release.

**Hotfix:** branch from `main`, fix, PR, merge, then release as a PATCH. If `main` holds unreleased work that must not ship, hold the release until it is ready rather than tagging a commit off `main`; the guards reject that.

### One-time GitHub and Google Cloud setup

- **GitHub environments:** `staging` (no protection) and `production` (required reviewers: the release approvers, with "Prevent self-review" once there is more than one; deployment branches/tags limited to `v*`). On each, set variables `GCP_WIF_PROVIDER` and `GCP_DEPLOY_SERVICE_ACCOUNT`.
- **Branch protection on `main`:** require a pull request and the `flutter` and `functions` status checks. Private repositories need a paid GitHub plan for branch protection and environment reviewers.
- **Deploy identity per Firebase project:** a `github-deployer` service account with Firebase Hosting Admin, Cloud Functions Admin, Firebase Rules Admin, Cloud Datastore Index Admin, Cloud Scheduler Admin and Service Account User on the Functions runtime account, reached through a Workload Identity Federation provider that trusts only this repository (and, for prod, only the `production` environment). No key files.
- **Functions image cleanup:** run `npx --prefix functions firebase --project prod functions:artifacts:setpolicy` once; without a policy the non-interactive functions deploy fails after deploying. Staging already has one.

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
