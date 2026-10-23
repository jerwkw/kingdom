# Kingdom implementation TODO

Last reviewed: 2026-10-23. Closed items and their details live in [ARCHIVE.md](ARCHIVE.md). This file lives on the docs-only `documentation` branch (find it with `tool/docs.sh`). Items done on an unmerged branch are marked _(in progress: branch)_ and close only when merged into `main`.

## Status

- **2026-10-21 pass:** all code-side P0, the user-feedback follow-ups, most of P1 and part of P2 done (route split, transactional membership, error codes, rate limits, fund ledger, achievements, notifications, server-side equip, role removal, CI). Committed; deployed to staging only.
- **Deploy order for this release:** indexes → functions → hosting → rules, then `functions/scripts/remove-legacy-role.js` and `backfill-achievements.js` (both only run against the emulator so far). Older clients break under the new rules. See `FIREBASE_DEPLOYMENT_GUIDE.md` (code branches).

### Decisions to confirm

- UTC business day.
- Achievements are display-only.
- SMART goals may be weekly or monthly.
- The 7-day consistency formula (7 per daily goal + 1 per weekly + 7/30 per monthly).
- Wording of the bulletin privacy note.

### Known gaps

- Reactions are limited per member per post by the rules, not by a request quota.
- The Dart store catalog is kept in sync by a parity test, not generated.
- Users who equipped unowned items before this release keep them; the rules only block new changes.

## P0 — before any invited users

### Deploy and verify the Firebase environment

Done: staging project `church-app-staging-f8a55` created with a web app; `.firebaserc` aliases (`staging` default, `prod`); web config chosen by `--dart-define=FIREBASE_ENV`; CORS derived from the deploying project. Production (`church-app-f8a55`) still runs the pre-pass build from 2026-07-28.

- Staging console setup done and release deployed to staging on 2026-10-23 (indexes → functions → hosting → rules); new routes answer 401 unauthenticated at https://church-app-staging-f8a55.web.app. Google OAuth consent screen is in Testing — add testers under Google Auth Platform → Audience.
- [ ] Run the two-account checks in `FIREBASE_DEPLOYMENT_GUIDE.md` (code branches) against that environment.
- Done 2026-10-23 (merged to `main`, not yet deployed): grey Tasks tab on staging fixed.
- [ ] Confirm Google sign-in works from the final Hosting domain and that all authorized domains are configured.
- [ ] Configure Firebase budget alerts, Cloud Functions logs/alerts, and least-privilege Firebase project access.
- [ ] Enable and enforce Firebase App Check for web before distributing broadly.
- [ ] Restrict both web API keys in Google Cloud (HTTP referrers: the Hosting domains + localhost; APIs: those Firebase web uses), then close GitHub's secret-scanning alerts on them as "used in tests"/false positive.

### CI and API hardening

Done: race-safe membership transactions, emulator integration tests for every route, string limits, rate limits, error codes, CORS.

- [ ] Prod deploys by manually running `deploy-prod.yml` on a tag (free private repo: no environments or branch protection); pre-push hook fixed for worktrees. _(in progress: ci/manual-prod-deploy)_
- [ ] Repo pushed to `github.com/jerwkw/kingdom` (private, free plan) on 2026-10-23. Remaining: do the "One-time GitHub and Google Cloud setup" in the deployment guide (repository variables, Workload Identity Federation deployers with the attribute conditions given there, prod cleanup policy). Until then the deploy step of every `main` push fails at auth (CI part runs).

## User-feedback acceptance checks

Code for all of these is done (role removal, deposit UX, notifications, achievement history, checkbox states); each needs a deployed environment and two real accounts.

- [ ] **Roles:** a new user never chooses a role; existing members still load, render, post, and appear in guild statistics after migration.
- [ ] **Deposits:** verify the deployed build shows the Avatar fish-balance banner and the **Deposit Fish** button in the guild header. A member can find it in one tap, choose an amount, get a clear result, and immediately see the updated balance/fund.
- [ ] **Notifications:** a guild event produces one in-app notification per intended recipient, the bell badge updates live, and opening the item marks it read and navigates correctly.
- [ ] **Achievements:** members can tap the guild and see which achievements it unlocked and when; repeated deposits never create duplicate unlock events.
- [ ] **Goal checkbox:** reproduce against the deployed endpoint (API response, completion doc, stream, UI). After one successful tap the checkbox checks and the text strikes through in the same interaction, stays checked after reload, and is disabled for the period.
- [ ] Decide whether push notifications are needed. If yes: opt-in UX, FCM tokens, preferences, background handling, delivery/privacy tests (the in-app bell must work without push).

## P1 — core feature and correctness work

Done: schedule-based stats targets, `memberActivity` aggregates, fund ledger, goal edit/archive/delete/share, daily-challenge states, bulletin edit/delete/pagination/limits, server-side equip.

- [ ] Decide a data-retention policy for empty/inactive neighbourhoods. `lib/inactive-cleanup.js` stays unscheduled; don't re-enable destructive cleanup without notice, retention, and recovery rules.
- [ ] Decide whether reflections remain curated content or use an approved AI provider, and update naming/copy accordingly.
- [ ] Decide on report, review, and removal (moderation) workflows before testing with a wider group.
- [ ] Generate the Flutter store catalog from `functions/lib/store-catalog.json` (currently enforced by a parity test only).
- [ ] Decide which catalog assets are final; current visuals are mainly emoji/procedural renderings.

## P2 — engineering quality and operations

Done: CI on Node 22 for all suites, unit/parity tests, structured logging, `functions/index.js` route split.

- Done 2026-10-23: tag-based release process.
- Done 2026-10-23: local CI parity via `tool/check.sh`.
- Done 2026-10-23: docs split for worktrees.

- [ ] Add browser smoke tests and an accessibility pass (keyboard flow, semantic labels, contrast, text scaling, reduced motion).
- [ ] Define Firestore backup/export, restore, retention, and incident-response procedures.
- [ ] Document who may deploy, inspect production data, manage Firebase keys, and access logs.
- [ ] Add monitoring for Function failures, unusual reward/purchase rates, and Firestore quota/cost growth.
- [ ] Remove the archived `server/` Raspberry Pi implementation once no historical reference is needed; keep it disabled and undeployed until then.
- [ ] Move Firebase web configuration to generated/platform-specific configuration where practical, and document how Android configuration will be added.
- [ ] Remove the unscheduled inactive-cleanup path if the retention decision is to keep neighbourhoods indefinitely.

## P3 — later product/platform work

- [ ] Register and configure the Android Firebase app, Google sign-in fingerprints, release signing, and `BACKEND_BASE_URL`.
- [ ] Test Android lifecycle behavior, responsive layouts, physical-device sign-in, and notifications.
- [ ] Evaluate multi-church tenancy only after the single-group pilot is stable; it requires a new data model and authorization review.

## Suggested execution order

1. P0 deploy to a non-production project, run the migration scripts, then the acceptance checks above.
2. Pending P1 decisions (retention, moderation, reflections, assets).
3. P2 observability, recovery, and pilot readiness.
4. Small two-account pilot before Android or multi-church expansion.
