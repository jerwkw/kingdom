---
title: "Kingdom TODO pass: transactions, API errors, emulator tests"
author: Jerwkw
date: 2026-10-21
branch: main
cost: { minutes: 33, tokens: 432075 }
touches:
  - FIREBASE_DEPLOYMENT_GUIDE.md
  - README.md
  - analysis_options.yaml
  - church_app_build_plan.md
  - firestore.indexes.json
  - firestore.rules
  - functions/index.js
  - functions/package-lock.json
  - functions/package.json
  - lib/config/avatar_anchor_system.dart
---

## Decided
- Business-day policy is UTC for every period key (Dart lib/utils/period_keys.dart and functions/lib/domain.js), verified against functions/test/fixtures/period-keys.json from both sides.
- Store catalog and achievement thresholds are authoritative JSON in functions/lib/; Flutter display catalogs are kept in sync by test/catalog_parity_test.dart rather than code generation.
- Bulletin post creation moved to POST /createBulletinPost (rate limited, server author name); rules deny client creates. Reactions are limited by rules to the caller's own key with an emoji allow-list.
- Purchased avatar slots (headpiece/shirt/pants/companion) are only writable via /equipItem; rules keep them unchanged on client profile writes.
- Achievements are display-only milestones; unlocks recorded in buildings/{id}/achievements by applyFundChange in the same transaction as the fund change.

## Tried and ruled out
- `admin.firestore.FieldValue` is undefined under the Functions emulator with firebase-admin 13; import FieldValue/Timestamp/getFirestore from 'firebase-admin/firestore' (functions/lib/firebase.js).
- Response bodies must not carry a top-level `status` field: the integration test helper spreads JSON over the HTTP status (joinBuilding returns status: 'pending').

## Watch out
- Deploy order for this release is indexes → functions → hosting → rules, because old clients (role on create, direct post creation, direct equip) break under the new rules. See FIREBASE_DEPLOYMENT_GUIDE.md.
- The goalScheduleSync trigger fills memberActivity.goalCounts asynchronously; integration tests that read stats must wait for it.
- The neighbourhood header overflowed at 320px; test/neighbourhood_deposit_test.dart guards narrow widths, keep it passing when editing that header.
