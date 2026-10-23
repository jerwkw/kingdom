#!/usr/bin/env bash
# Deploys an already-built build/web plus rules, indexes and Functions to one
# Firebase alias, in the default release order: indexes -> functions -> hosting
# -> rules. Rules go last because the new client works against the old rules but
# old clients may break under the new ones. Releases that need another order are
# deployed by hand (FIREBASE_DEPLOYMENT_GUIDE.md on the documentation branch).
#
#   flutter build web --dart-define=FIREBASE_ENV=staging && tool/deploy.sh staging
#   flutter build web && tool/deploy.sh prod
set -euo pipefail

alias="${1:?usage: tool/deploy.sh staging|prod}"
[[ "$alias" == staging || "$alias" == prod ]] || { echo "deploy: unknown alias '$alias'" >&2; exit 1; }
cd "$(git rev-parse --show-toplevel)"

[[ -f build/web/main.dart.js ]] || { echo "deploy: build/web is missing; run flutter build web first" >&2; exit 1; }
project_id="$(node -p "JSON.parse(require('fs').readFileSync('.firebaserc', 'utf8')).projects['$alias']")"
grep -q "$project_id" build/web/main.dart.js ||
  { echo "deploy: build/web was not built for $alias ($project_id); check FIREBASE_ENV" >&2; exit 1; }

firebase() { npx --prefix functions firebase --project "$alias" --non-interactive "$@"; }

firebase deploy --only firestore:indexes
firebase deploy --only functions
firebase deploy --only hosting
firebase deploy --only firestore:rules
