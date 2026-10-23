#!/usr/bin/env bash
# Guards a release tag before it is deployed to production. Run locally before
# tagging (checks HEAD) or after (checks the tagged commit); deploy-prod.yml runs
# it too.
#
#   tool/release-check.sh v1.2.3
#
# MAIN_REF overrides the branch the commit must be on (default: origin/main if it
# exists, else main).
set -euo pipefail

tag="${1:?usage: tool/release-check.sh vX.Y.Z}"
cd "$(git rev-parse --show-toplevel)"

fail() { echo "release-check: $*" >&2; exit 1; }

[[ "$tag" =~ ^v([0-9]+\.[0-9]+\.[0-9]+)$ ]] || fail "tag '$tag' is not vMAJOR.MINOR.PATCH"
version="${BASH_REMATCH[1]}"

pubspec_version="$(sed -nE 's/^version:[[:space:]]*([0-9]+\.[0-9]+\.[0-9]+)(\+[0-9]+)?[[:space:]]*$/\1/p' pubspec.yaml)"
[[ "$pubspec_version" == "$version" ]] ||
  fail "pubspec.yaml version is '$pubspec_version', tag is $version"

grep -qE "^## \[$version\]" CHANGELOG.md || fail "CHANGELOG.md has no '## [$version]' section"

if git rev-parse -q --verify "refs/tags/$tag" >/dev/null; then
  commit="$(git rev-parse "$tag^{commit}")"
else
  commit="$(git rev-parse HEAD)"
fi

main_ref="${MAIN_REF:-}"
if [[ -z "$main_ref" ]]; then
  if git rev-parse -q --verify origin/main >/dev/null; then main_ref=origin/main; else main_ref=main; fi
fi
git merge-base --is-ancestor "$commit" "$main_ref" || fail "commit ${commit:0:7} is not on $main_ref"

echo "release-check: $tag OK (commit ${commit:0:7} on $main_ref)"
