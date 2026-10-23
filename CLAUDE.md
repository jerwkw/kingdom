# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Kingdom is a web-first Flutter accountability app for a church cell group: private spiritual goals, daily reflections, a cosmetic currency ("fish"), avatars, shared neighbourhoods ("buildings") and a bulletin board. Backend is Firebase (Auth with Google sign-in, Firestore, Cloud Functions, Hosting). `server/` is an archived Raspberry Pi backend — not part of the supported workflow; don't modify it unless asked. `TODO.md` tracks known gaps and pilot-readiness work.

## Instructions

At the start of a session, refer to docs/TODO.md for a summary of past session changes and pending action items. During the session, once an item is closed, reduce it to a one liner update about the completion and shift the relevant information to docs/ARCHIVE.md. The TODO.md should remain as lightweight as possible

- Only read ARCHIVE.md when necessary, otherwise the shifted information can just be appended to the back.

## Commands

```bash
flutter pub get && (cd functions && npm install)   # setup (Node from .nvmrc, Java needed for emulators)
git config core.hooksPath tool/git-hooks           # once per clone: pre-push runs tool/check.sh

tool/check.sh [flutter|functions] [--no-emulators] # exactly what CI runs; switches Node via nvm

flutter run -d chrome                               # against deployed Firebase project
npx --prefix functions firebase emulators:start     # local Auth/Firestore/Functions/Hosting
flutter run -d chrome --dart-define=USE_FIREBASE_EMULATORS=true

flutter analyze                                     # functions/ and server/ are excluded
flutter test                                        # single test: flutter test test/widget_test.dart --plain-name "goal card"
flutter build web                                   # output to build/web (served by Hosting)

cd functions
npm test                                            # node:test domain tests (test/domain.test.js)
npm run test:rules                                  # Firestore rules tests under emulator, project demo-kingdom
npm run test:integration                            # every API route via Auth+Firestore+Functions emulators (incl. concurrency races)
node --test --test-name-pattern "<name>" test/domain.test.js   # single backend test
node scripts/<name>.js [--apply]                    # one-off Admin SDK migrations; dry run unless --apply
```

Deploy (see `FIREBASE_DEPLOYMENT_GUIDE.md` for order and post-deploy checks): rules/indexes → functions → hosting, via `npx --prefix functions firebase deploy --only <target>`. Firebase CLI is a devDependency of `functions/`, hence `--prefix functions`. `.firebaserc` aliases: `staging` (default, `church-app-staging-f8a55`) and `prod` (`church-app-f8a55`); build web with `--dart-define=FIREBASE_ENV=staging` for staging. `tool/deploy.sh <alias>` deploys a built `build/web` in release order. CI: PRs run `ci.yml`; pushes to `main` deploy staging; `vX.Y.Z` tags deploy prod after `tool/release-check.sh` guards and approval ("Releasing" in the guide; `CHANGELOG.md` and `pubspec.yaml` version must match the tag).

## Architecture

**Trust boundary is the core design rule.** Clients may write directly to Firestore only for editable profile fields (`name` and the drawn avatar parts — never the purchased `headpiece`/`shirt`/`pants`/`companion` slots), private goal content (including `archived`), editing/deleting their own bulletin posts, their own reaction key, and marking their own notifications read (`firestore.rules`). Everything economic, membership-related or rate-limited — fish balances, streaks, `completions`, `inventory`, equipping, group funds and `fundLedger`, guild `achievements`, `buildings` membership/admins, bulletin post creation, `notifications` — is written only by Cloud Functions via the Admin SDK. When adding a feature that touches these, add a Functions route and keep the rule `allow write: if false`; extend `functions/test/firestore.rules.test.js` to prove clients can't forge it and `functions/test/api.integration.test.js` to cover the route.

**Cloud Functions (`functions/`)**: `index.js` builds a single Express app exported as `api` (`functions.https.onRequest`, firebase-functions v1 API), plus the `dailyChallengeCron` schedule and the `goalScheduleSync` Firestore trigger. Routes live in `lib/routes/{goals,buildings,store,bulletin}.js`, each `register(app, authenticateToken)`; every route uses `authenticateToken` and is registered under both `/x` and `/api/x` (Hosting `/api/**` rewrite and direct invocation).
- Wrap handlers in `route()` from `lib/http.js` and throw `ApiError` (`badRequest`/`forbidden`/`notFound`/`conflict`) with a stable `code`; responses are `{success, code, error}`. The Flutter client maps codes to copy in `lib/services/api_client.dart` — add new codes there too. Validate strings with `requireString`/`requireId` against `LIMITS` in `lib/domain.js`.
- Per-user quotas: `rateLimit('<action>')` middleware from `lib/rate-limit.js` (Firestore counters in `rateLimits`).
- Every multi-document change runs in one `db.runTransaction` that re-reads and re-validates membership/roles inside it (all reads before writes). Fund changes go through `applyFundChange` in `lib/guild.js`, which writes the ledger entry and any achievement unlocks; notifications are queued in the same transaction with `queueNotifications` using deterministic ids (`${eventId}_${uid}`) for dedup.
- Building statistics read the server-only `memberActivity/{uid}` aggregates (daily completion counts written by reward transactions; `goalCounts` written by the trigger) instead of per-member queries.
- Logs go through `log()` (structured, with `requestId`); never log goal, bulletin or prayer text, or tokens.
- `lib/inactive-cleanup.js` is intentionally unscheduled pending a retention decision.

**Flutter client (`lib/`)**: Riverpod throughout.
- `providers/` hold Firestore `StreamProvider`s for live reads and `StateNotifier`-style controllers that call the Functions API through `apiClientProvider` (`services/api_client.dart`, which attaches the ID token and throws `ApiException(code, message)`). Base URL comes from `backendBaseUrlProvider` in `auth_provider.dart`: `/api` on web, `--dart-define=BACKEND_BASE_URL` otherwise. Balances, funds and memberships are live streams, so actions don't need to invalidate them; only the request/response `buildingMemberStatsProvider` is refreshed.
- `userGoalsProvider` combines independent goals and completions streams; per-goal pending/failed/confirmed state lives in `goalCompletionStatusProvider`.
- `main.dart` initializes Firebase (web options per environment from `config/firebase_options.dart`), optionally connects emulators, and routes between `OnboardingScreen` and `MainShell` based on auth + profile state. `MainShell` hosts the tabs in `screens/`; the selected tab is `shellTabProvider` (so notifications can deep-link). Each tab's app bar carries `NotificationBell`.
- `config/` holds static catalogs: avatar parts, the avatar anchor/geometry system used by `widgets/avatar_renderer.dart`, the store catalog, achievement display copy and `TextLimits`. The member-role system was removed; don't reintroduce `role`.

**Duplicated definitions that must stay in sync** (each enforced by a test that reads the authoritative file):
- Store item IDs/categories/costs: `functions/lib/store-catalog.json` (authoritative — the server ignores client prices) and `lib/config/store_config.dart` (display). `test/catalog_parity_test.dart`.
- Achievement IDs/thresholds: `functions/lib/achievements.json` and `lib/config/achievements_config.dart`. `test/catalog_parity_test.dart`.
- Goal period keys (business-day policy is UTC everywhere; daily `YYYY-MM-DD`, weekly ISO `YYYY-Www`, monthly `YYYY-MM`): `lib/utils/period_keys.dart` and `getPeriodKey` in `functions/lib/domain.js`, both tested against `functions/test/fixtures/period-keys.json`. Completion docs are matched against goals by `refType`/`refId`/`periodKey`.
- Text limits: `LIMITS` in `domain.js`, `firestore.rules`, and `lib/config/limits.dart`.

## Notes

- **Agents and work branches:** `main` only changes through PRs that pass CI. Before reporting work as done, run `tool/check.sh` (or the relevant suite) and report its result. Never deploy (`tool/deploy.sh`, `firebase deploy`) — CI deploys staging from `main` and prod from tags. Don't bypass the pre-push hook with `--no-verify`. Emulator suites share fixed ports across worktrees; `tool/check.sh` serialises them with a machine-wide lock, so don't run `npm run test:rules`/`test:integration` directly in parallel.
- Hosting sets no-cache headers on html/js/json and SPA-rewrites everything else to `index.html`.
- Never commit service-account credentials, `.env` files, signing keys, or platform Firebase secret files (the web `FirebaseOptions` in `lib/config/firebase_options.dart` are public client config).
