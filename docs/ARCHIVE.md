# Kingdom TODO archive

Closed items moved out of `docs/TODO.md`, with their original wording and any decision notes. New entries are appended at the end.

## 2026-10-21 implementation pass

### Summary

All code-side P0 items, the user-feedback follow-ups, most of P1 and part of P2 were implemented in this pass. Nothing was committed or deployed at the time.

- **Backend (`functions/`):** `index.js` is split into `lib/routes/*`. Membership mutations (join, approve, reject, promote, leave) each run as a single re-validating transaction, and invite codes are reserved. There are stable error codes, input-length limits, per-user rate limits (`rateLimits` collection, TTL), and CORS restricted to the Hosting origins. Fund changes write a ledger entry (`buildings/{id}/fundLedger`) and record each achievement unlock once (`buildings/{id}/achievements`). Server-written `notifications` have deduplicated ids. Building stats read schedule-based targets from `memberActivity` aggregates. New routes: `/equipItem`, `/createBulletinPost`, `/ensureDailyChallenge`. Logs are structured, with request IDs.
- **Rules:** `role` is gone. Purchased avatar slots can only be changed by the server. Clients can no longer create bulletin posts directly. Members can only change their own reaction, from an emoji allow-list. Text lengths are limited. Notifications, the ledger and achievements are read-only to clients, and the bookkeeping collections are closed to them.
- **App (`lib/`):** role removed everywhere. The goal checkbox has pending, failed and confirmed states, and the goals/completions streams are combined without nesting. A notification bell and inbox deep-link into the app. There is a guild achievement history screen with recent contributions. The deposit button shows your balance and has a zero-balance state, and the layout no longer overflows at 320 px. Goals can be edited, archived/restored, deleted or shared to the bulletin. The bulletin is paginated and lets authors edit or delete their posts. Equipping now goes through the server.
- **Tests and CI:** `npm run test:integration` exercises every API route through the Auth, Firestore and Functions emulators, including concurrency races (25 tests). Rules tests grew from 4 to 12 and Flutter tests from 1 to 27. Period keys and catalogs are checked for Dart/JS parity, and `.github/workflows/ci.yml` runs all suites on Node 22.
- **Scripts:** `functions/scripts/remove-legacy-role.js` and `backfill-achievements.js` are idempotent and dry-run by default. Only run against the emulator so far.

### P0 — Make membership mutations race-safe

- Rewrite `approveJoinRequest` as a single Firestore transaction. It must re-read the building, target user, and pending request before writing.
- In that transaction, reject approval when the target user already belongs to another building or the pending request no longer exists.
- Rewrite `leaveBuilding` as a transaction. It previously updated the user and building separately, so concurrent leaves/approvals could overwrite membership, admin, or leader data.
- Re-read and validate roles/membership inside every privileged transaction, rather than only before it.
- Add integration tests for two concurrent approvals, two concurrent leaves, and a join/leave race. — `functions/test/api.integration.test.js`.

### P0 — Test every privileged API route through the emulator

- Add authenticated Functions emulator tests for `completeGoal`, `completeDailyChallenge`, `depositFish`, `createBuilding`, `joinBuilding`, approval/rejection, promotion, leaving, purchase, and statistics. — `npm run test:integration`.
- Test malformed payloads, missing/expired tokens, forged item IDs, insufficient balances, cross-building requests, and unauthorized administration.
- Test duplicate completion requests concurrently and assert exactly one reward, streak update, and group-fund update occurs.

### P0 — Add abuse limits and a stable API contract

- Validate and limit all user-controlled strings: names, goal text, building names/descriptions, invite codes, bulletin text, and reaction data. — server `LIMITS` + rules + `maxLength` on inputs.
- Apply rate limits or Firebase-based quotas to goal completion, building creation, join requests, posts, and reactions. — Firestore fixed-window counters (`functions/lib/rate-limit.js`). Post creation moved to `/createBulletinPost` so it can be limited; reactions are limited by rules to one per member per post rather than by count.
- Replace English-only API errors with stable machine-readable error codes plus user-facing messages in the Flutter client. — `{code, error}` responses mapped in `lib/services/api_client.dart`.
- Restrict production CORS to the Hosting domain(s), rather than accepting every origin. — Hosting origins by default, `ALLOWED_ORIGINS` override.

### User feedback — Remove the unused member-role system

- Remove `role` from onboarding, `UserModel`, Firestore profile documents, Firestore rules, bulletin-post payloads, building statistics, and avatar-renderer inputs.
- Replace role-derived visual treatment with a single neutral member presentation in `AvatarRenderer` and the neighbourhood member list.
- Write a one-off, idempotent Admin SDK migration that removes the legacy `role` field from existing `users` and bulletin posts. — `functions/scripts/remove-legacy-role.js` (dry run by default); not yet run against production.
- Update tests and Firestore rule fixtures so profile creation/update no longer expect or permit a role field.

### User feedback — Make fish balance and guild deposits unmistakable

- Test the deposit flow at narrow mobile, standard mobile, and desktop widths; keep the action visible without clipping and show the current balance before confirmation. — widget test at 320/390/1024 px; fixed header and dialog overflow it found.
- After a successful deposit, verify that the Avatar counter, store counter, guild fund, achievement progress, and member balance refresh without reopening the app. — all are live Firestore streams; stats are re-fetched.
- Add an empty/zero-balance state explaining how fish are earned and disable the deposit action with an accessible explanation.
- Add emulator tests for successful deposit, insufficient funds, stale balance, non-member deposit, and duplicate/concurrent deposit attempts.

### User feedback — Add guild-activity notifications

- Define initial event types: join request submitted, request approved/rejected, member joined/left, fish deposited, achievement unlocked, and leadership/admin changes.
- Add a server-written notification model with recipient UID, guild ID, event type, safe display text, timestamp, read timestamp, and a navigation target. Clients cannot create notifications for other users.
- Write notifications from the relevant Cloud Function transactions/events and define deduplication behavior for retries. — deterministic ids per event and recipient.
- Add a notification-bell icon with unread badge to the authenticated app shell; implement a notification inbox, read/unread state, empty state, and deep links to the relevant guild view.

### User feedback — Turn achievements into a real historical record

- Keep the existing achievements modal as the current-progress view, but don't present it as "past history" (it derived unlocked status from the live fund total and stored no unlock date/event).
- Define achievement IDs, thresholds, one-time unlock behavior, award text, and whether achievements unlock any visual/gameplay change. — _Decision_: display-only milestones (`functions/lib/achievements.json`).
- On the server, atomically record a guild-achievement event when a threshold is crossed, including achievement ID, unlock time, triggering fund balance, and optional triggering event.
- Add a guild-achievement history screen reachable from the guild header and the **Achievements** action, showing unlocked achievements chronologically, then locked milestones with progress. — `GuildAchievementsScreen`, also lists fund contributions.
- Backfill existing guilds deterministically from their current fund total, marking backfilled dates as unknown. — `functions/scripts/backfill-achievements.js`; not yet run against production.

### User feedback — Fix goal-completion checkbox feedback

- Add a per-goal pending state immediately after tap: disable duplicate taps, replace the checkbox with a progress indicator, and show an actionable error if the reward request fails.
- After a successful API response, explicitly wait for the matching completion state before showing success.
- Use one documented timezone/business-day policy in both Dart and Functions for daily, weekly, and monthly period keys, with boundary tests around midnight and ISO-week/year transitions. — _Decision_: UTC; also fixed the client keying today's reflection by local date. Shared fixtures in `functions/test/fixtures/period-keys.json`.
- Refactor `userGoalsProvider` so the goals and completions streams are combined without nested subscriptions, with tests for checked, pending, failed, and completed states.

### P1 — Correct neighbourhood progress and scaling

- Replace the fixed `7` completion denominator in `buildingStats` with a target based on each member's active goal schedule. — 7-day target = 7 per daily goal + 1 per weekly + 7/30 per monthly (`weeklyCompletionTarget`).
- Avoid the N+1 statistics pattern (reading every member and all their completions per request). — `memberActivity` aggregates; stats are two batched reads.
- Add an explicit group-fund contribution ledger so the UI can show history.
- Define whether achievements are display-only milestones or unlock real building changes. — _Decision_: display-only.

### P1 — Complete goals and reflections

- Add goal editing, deletion, and archive/restore controls.
- Implement `sharedToBulletin` as an explicit action that creates a safe copy on the bulletin; never expose the private goal document to other members.
- Decide whether SMART goals can be weekly/monthly. — _Decision_: yes.
- Show a clear empty/loading/error state when a daily challenge has not been generated instead of silently substituting generic copy.
- Remove the duplicate `refId` property in the daily-challenge completion payload. — was already gone.

### P1 — Finish bulletin behavior and moderation

- Add post edit/delete UX consistent with the Firestore rules.
- Add pagination/limits and deterministic ordering (`createdAt`) for bulletin posts.
- Add content-length limits and a clear policy for prayer requests and sensitive personal information. — 1000-char limit and a privacy note in the post dialog; wording is a draft for leaders to approve.

### P1 — Finish store and avatar integrity

- Prevent users from equipping premium item IDs by directly editing `avatarConfig`; verify ownership server-side.
- Store equipped state in the inventory or add a trusted equip endpoint, then test ownership and category validation. — `/equipItem`.

### P2 — Testing and delivery

- Add CI for `flutter analyze`, `flutter test`, `flutter build web`, `npm test`, rules tests, and Functions integration tests.
- Run CI on Node 22, matching `functions/package.json`.
- Add unit tests for models, period-key parity between Dart and JavaScript, error presentation, bulletin reaction behavior, and store ownership.

### P2 — Data, observability, and recovery

- Add structured logs with request IDs and safe error context; avoid recording goals, prayer requests, tokens, or other sensitive text.

### P2 — Simplify the codebase

- Split `functions/index.js` into route modules, validation helpers, domain services, and transaction helpers.

## 2026-10-23 staging environment

- Created staging Firebase project `church-app-staging-f8a55` (Firestore `asia-southeast1`, Google sign-in, Blaze, image cleanup policy) and deployed the release there.
- `.firebaserc` aliases `staging` (default) / `prod`; web `FirebaseOptions` selected by `--dart-define=FIREBASE_ENV` in `lib/config/firebase_options.dart`; CORS default origins follow `GCLOUD_PROJECT`.

## 2026-10-23 merged to main (local; GitHub remote added the same day)

- `ci/release-workflows`: tag-based releases (`CHANGELOG.md`, `tool/release-check.sh`, staging/prod deploy workflows, "Releasing" in the deployment guide); local CI parity (`tool/check.sh`, `.nvmrc`, pre-push hook, agent rules in `CLAUDE.md`); docs split (status on the `documentation` branch via `tool/docs.sh`, code docs with the code, PR template).
- `fix/challenge-completion-read`: the Tasks tab rendered grey on staging because `completions/{uid}_challenge_{today}` doesn't exist until the reflection is done and the read rule (`resource.data.userId == uid`) denied it; `.value` on the errored provider then threw during build. Rules now allow reading a missing completion whose id starts with the caller's uid (rules test added); the client uses `.valueOrNull`. Needs a rules + hosting deploy to reach staging.

## 2026-10-23 manual prod deploy (#1)

- Repo `github.com/jerwkw/kingdom` is private on GitHub Free (no environments, no branch protection). `deploy-prod.yml` now runs only via workflow_dispatch on a `vX.Y.Z` tag; starting the run is the approval. Deploy credentials are repository variables `STAGING_`/`PROD_GCP_WIF_PROVIDER` and `..._GCP_DEPLOY_SERVICE_ACCOUNT`; the deployment guide gives WIF attribute conditions restricting prod to those runs.
- Pre-push hook clears git's hook environment (an absolute `GIT_DIR` in worktrees broke Flutter's version lookup).
- Action version bumps (#2) were merged into the PR #1 branch by mistake and re-opened against `main` as #3.
