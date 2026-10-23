#!/usr/bin/env bash
# Prints the path of the worktree that has the `documentation` branch checked
# out (docs/TODO.md and docs/ARCHIVE.md: shared project status), creating it
# as <main checkout>-docs if no worktree has it yet. Code worktrees never switch
# to that branch; they commit to it with git -C "$(tool/docs.sh)".
set -euo pipefail

branch=documentation
path="$(git worktree list --porcelain | awk -v ref="branch refs/heads/$branch" '
  /^worktree / { wt = substr($0, 10) }
  $0 == ref { print wt; exit }
')"

if [[ -z "$path" ]]; then
  main="$(git worktree list --porcelain | awk '/^worktree / { print substr($0, 10); exit }')"
  path="$main-docs"
  git worktree add --quiet "$path" "$branch" >&2
fi

echo "$path"
