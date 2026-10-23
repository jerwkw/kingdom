#!/usr/bin/env bash
# Prints one version's section of CHANGELOG.md, for the GitHub Release body.
#
#   tool/release-notes.sh 1.2.3
set -euo pipefail

version="${1:?usage: tool/release-notes.sh X.Y.Z}"
cd "$(git rev-parse --show-toplevel)"

awk -v v="$version" '
  /^## \[/ { if (found) exit; found = index($0, "## [" v "]") == 1; next }
  found
' CHANGELOG.md
