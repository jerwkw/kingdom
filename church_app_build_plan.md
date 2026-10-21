# Kingdom — Current Build Plan

## Product scope

Kingdom is a web-first Flutter app for one church cell group per member. Android remains a later target using the same Flutter codebase. Multi-church administration, user-uploaded media, and full moderation tooling remain outside the first release.

## Architecture decision

The project originally planned to run privileged APIs on a self-hosted Raspberry Pi. That approach was replaced for operational simplicity. The supported stack is Firebase Hosting, Authentication, Cloud Firestore, and Cloud Functions.

`functions/index.js` is the authoritative backend. The old `server/` implementation is archived, disabled by default, and must not be deployed. Firebase Hosting forwards `/api/**` to the `api` function, so web uses a same-origin endpoint.

This choice requires a Firebase billing-enabled plan for Functions deployment. Configure budget alerts and usage monitoring before inviting testers.

## Implemented foundation

- Google sign-in, onboarding, initial SMART goal, and avatar creation.
- Responsive Avatar, Neighbourhood, Tasks, and Store navigation.
- Private templated and SMART goals with daily, weekly, and monthly reward periods.
- Atomic completion rewards, streak changes, and group-fund contributions.
- Daily curated reflection prompt and completion reward.
- Neighbourhood creation, invite approval, administration, statistics, achievements, and contributions.
- Bulletin posts and same-neighbourhood reactions.
- Server-authoritative cosmetic purchases, inventory, fitting room, and avatar rendering.
- Firebase Hosting/emulator configuration, rules tests, and backend domain tests.

## Security invariants

1. Clients cannot change balances, membership, completions, inventory, group funds, or streaks directly.
2. Goal text is readable only by its owner.
3. Store identity and price are validated by Cloud Functions.
4. Reward idempotency is checked inside the same transaction as balance and streak updates.
5. Statistics, deposits, administration, and bulletin activity require current membership or the appropriate admin role.
6. A member can belong to only one neighbourhood.
7. Backend outages never fall back to privileged client writes or fabricated progress.

## Remaining release phases

### Phase A — Integration hardening

- Add authenticated Functions emulator integration tests for every endpoint, including concurrent completion attempts.
- Add negative tests for forged prices, cross-building requests, unauthorized admin actions, and malformed payloads.
- Generate the client and server store catalogs from one source.
- Add structured API error codes.

Definition of done: analyzer, Flutter tests, backend tests, rules tests, web build, and endpoint integration tests all pass.

### Phase B — Product completion

- Implement goal editing/deletion.
- Implement “share goal to bulletin” as a copied post without exposing its private source.
- Decide and implement bulletin reporting/moderation.
- Replace placeholder milestone calculations with persisted, tested criteria.
- Decide whether daily reflections remain curated or use an approved AI provider and moderation workflow.

Definition of done: all visible controls work and two-account acceptance testing passes.

### Phase C — Operational readiness

- Add CI for analysis, tests, rules tests, and the web build.
- Configure Firebase budgets, alerts, App Check, logging, and least-privilege access.
- Document backup, recovery, data retention, and rollback.
- Run accessibility, responsive-layout, and browser compatibility checks.
- Conduct a small invited pilot and triage feedback.

Definition of done: deployment is repeatable and the pilot has no unresolved critical defects.

### Phase D — Android

- Register the Android Firebase app and configure native Google sign-in.
- Provide `BACKEND_BASE_URL` as the deployed HTTPS Functions endpoint.
- Test lifecycle behavior, notifications, release signing, and core two-account flows on physical devices.

## Standard verification

```bash
flutter analyze
flutter test
flutter build web
cd functions
npm test
npm run test:rules
```
