---
title: "Staging project, tag-based releases, docs branch for worktrees"
author: Jerwkw
date: 2026-10-23
branch: ci/release-workflows
touches:
  - .firebaserc
  - lib/config/firebase_options.dart
  - functions/index.js
  - .github/workflows/
  - tool/
  - CLAUDE.md
  - FIREBASE_DEPLOYMENT_GUIDE.md
---

## Decided
- Staging is a separate Firebase project, `church-app-staging-f8a55` (Firestore asia-southeast1 like prod). `.firebaserc` default alias is staging so an unqualified deploy can't hit prod.
- Web build picks FirebaseOptions via `--dart-define=FIREBASE_ENV=staging`; dart2js drops the unused config, which is what lets `tool/deploy.sh` refuse a build made for the other project.
- One `main` + `vX.Y.Z` tags, not env branches. Prod deploy requires the exact commit to have deployed to staging successfully, plus approval on the `production` GitHub environment.
- `tool/check.sh` is the single definition of CI checks; ci.yml calls it.
- Project status (docs/TODO.md, docs/ARCHIVE.md) lives on the orphan `documentation` branch in its own worktree (`tool/docs.sh`); code docs stay with the code. TODO items close only on merge to main.

## Tried and ruled out
- Moving FIREBASE_DEPLOYMENT_GUIDE.md to the docs branch: it must be versioned with the code it describes (tags, hotfixes).
- Telling agents to `git checkout documentation`: git refuses a branch checked out in another worktree.
- Tagging hotfix branches off main: breaks "prod only runs what staging ran".

## Watch out
- Default shell Node is 20; integration tests need 22 (`node: bad option: --test-concurrency=1`). check.sh switches via nvm.
- Emulator suites use fixed ports; parallel worktrees must go through check.sh's lock.
- The OAuth consent screen's "Testing/Production" status is unrelated to staging/prod; staging stays in Testing with listed test users.
- `CONFIGURATION_NOT_FOUND` from identitytoolkit means Firebase Auth "Get started" was never clicked.
- Prod still runs a pre-git build from 2026-07-28; GitHub remote, WIF deployers and the prod artifact cleanup policy are not set up yet.
- git 2.39 has no `worktree add --orphan`; the docs branch was built with commit-tree.
