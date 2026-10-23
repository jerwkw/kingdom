---
title: "Free private GitHub repo: manual prod deploy, hook env in worktrees"
author: Jerwkw
date: 2026-10-23
branch: ci/manual-prod-deploy
touches:
  - .github/workflows/
  - tool/git-hooks/pre-push
  - FIREBASE_DEPLOYMENT_GUIDE.md
  - firestore.rules
---

## Decided
- Repo is github.com/jerwkw/kingdom, private on GitHub Free: no environments, no branch protection, no environment approvals. Prod deploys only when `deploy-prod.yml` is dispatched by hand on a vX.Y.Z tag ("Use workflow from" = the tag); starting the run is the approval. Tag pushes deploy nothing.
- Deploy credentials are repository variables `STAGING_`/`PROD_GCP_WIF_PROVIDER` and `..._GCP_DEPLOY_SERVICE_ACCOUNT`; the real guard is each WIF provider's attribute condition (prod: `event_name == workflow_dispatch` and `workflow_ref` starts with `deploy-prod.yml@refs/tags/v`).
- Firebase web API keys in `lib/config/firebase_options.dart` are public client config; GitHub secret-scanning alerts on them are expected. Restrict the keys in Google Cloud instead of removing them.
- Completion ids start with the owner's uid, so the completions read rule allows a missing doc whose id matches `uid_.*` (listening to today's challenge completion before it exists).

## Tried and ruled out
- A GitHub `production` environment with required reviewers: needs a paid plan on a private repo.

## Watch out
- Git exports GIT_DIR to hooks; in a worktree it is absolute, and Flutter's own git calls then read this repo ("Flutter SDK version 0.0.0-unknown", pub get fails). The pre-push hook unsets `git rev-parse --local-env-vars` first.
- A fresh worktree needs `npm ci` in `functions/` before `tool/check.sh`; otherwise `firebase emulators:exec` resolves a global standalone CLI whose bundled Node fails `node --test` ("Cannot find module .../--test").
- In release web builds an exception thrown in `build` renders as a grey box; reproduce with `flutter run -d chrome --dart-define=FIREBASE_ENV=staging` to see it. Riverpod `.value` rethrows provider errors; use `.valueOrNull` in build.
- No `gh` CLI on this machine; open PRs from the URL `git push` prints.
