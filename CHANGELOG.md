# Changelog

Versions follow `vMAJOR.MINOR.PATCH`: MAJOR for releases that break older clients or need a data migration or special deploy order, MINOR for features, PATCH for fixes. The version must match `pubspec.yaml`. See "Releasing" in `FIREBASE_DEPLOYMENT_GUIDE.md` (on the `documentation` branch).

## [Unreleased]

First tagged release. Production currently runs an untagged build from 2026-07-28.

**Deploy notes:** older clients break under the new rules, and `functions/scripts/remove-legacy-role.js` and `backfill-achievements.js` must run after the deploy.

### Added
- Notification bell and inbox for guild events, with deep links.
- Guild achievement history and fund contribution ledger.
- Goal editing, archive/restore, deletion and sharing to the bulletin.
- Bulletin pagination and editing/deleting your own posts.
- Staging environment (`church-app-staging-f8a55`) and tag-based production releases.

### Changed
- Goal checkbox shows pending, failed and confirmed states.
- Deposit button shows your balance and explains how to earn fish when it is zero.
- Neighbourhood statistics use each member's goal schedule instead of a fixed target.
- Equipping items and creating bulletin posts now go through the server.
- Business day is UTC everywhere.

### Removed
- The member-role system.

### Security
- Membership changes run in single re-validating transactions.
- Input length limits, per-user rate limits and Hosting-only CORS.
- Purchased avatar slots, bulletin post creation, notifications and achievements are server-written only.
