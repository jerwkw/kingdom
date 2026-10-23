#!/usr/bin/env bash
# Runs the CI checks. .github/workflows/ci.yml calls this too, so a green local
# run means a green CI run (dependencies are assumed installed locally).
#
#   tool/check.sh                          # everything
#   tool/check.sh flutter                  # analyze, test, build web
#   tool/check.sh functions                # domain, rules and integration tests
#   tool/check.sh [suite] --no-emulators   # skip the rules/integration suites
#
# Switches to the Node version in .nvmrc via nvm when needed. The emulator
# suites bind fixed ports, so concurrent runs (other worktrees or agents) wait
# for each other on a machine-wide lock instead of colliding.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

fail() { echo "check: $*" >&2; exit 1; }

suite=all
emulators=1
for arg in "$@"; do
  case "$arg" in
    all|flutter|functions) suite="$arg" ;;
    --no-emulators) emulators=0 ;;
    *) fail "usage: tool/check.sh [all|flutter|functions] [--no-emulators]" ;;
  esac
done

use_node() {
  local want
  want="$(cat .nvmrc)"
  if [[ "$(node -v 2>/dev/null)" != "v$want".* && -s "${NVM_DIR:-$HOME/.nvm}/nvm.sh" ]]; then
    set +eu
    # shellcheck disable=SC1091
    . "${NVM_DIR:-$HOME/.nvm}/nvm.sh"
    nvm use --silent >/dev/null
    set -eu
  fi
  [[ "$(node -v 2>/dev/null)" == "v$want".* ]] ||
    fail "need Node $want (found $(node -v 2>/dev/null || echo none)); install it, e.g. nvm install $want"
}

lock="${TMPDIR:-/tmp}/kingdom-emulators.lock"
acquire_emulator_lock() {
  local announced=0 holder
  until mkdir "$lock" 2>/dev/null; do
    holder="$(cat "$lock/pid" 2>/dev/null || true)"
    if [[ -n "$holder" ]] && ! kill -0 "$holder" 2>/dev/null; then
      rm -rf "$lock"  # holder died without cleaning up
      continue
    fi
    if [[ "$announced" == 0 ]]; then
      echo "check: waiting for another run's emulators (pid ${holder:-?}) to finish..."
      announced=1
    fi
    sleep 5
  done
  echo $$ > "$lock/pid"
  trap 'rm -rf "$lock"' EXIT
}

run_flutter() {
  flutter pub get
  flutter analyze
  flutter test
  flutter build web
}

run_functions() {
  use_node
  (cd functions && npm test)
  if [[ "$emulators" == 1 ]]; then
    acquire_emulator_lock
    (cd functions && npm run test:rules && npm run test:integration)
  else
    echo "check: skipped rules and integration suites (--no-emulators); CI still runs them"
  fi
}

case "$suite" in
  flutter) run_flutter ;;
  functions) run_functions ;;
  all) run_flutter; run_functions ;;
esac
echo "check: $suite passed"
