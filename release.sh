#!/bin/sh
# Create a release on Codeberg (fj) and GitHub (gh) from the latest CHANGELOG.md block.
# Usage: ./release.sh <tag>   e.g. ./release.sh v0.0.1
set -eu

TAG="${1:?usage: ./release.sh <tag>}"
GH_REPO="Iamlooker/zigi"

cd "$(dirname "$0")"

# Notify if CHANGELOG.md was not touched by the latest commit
if [ "$(git rev-parse HEAD)" != "$(git rev-list -1 HEAD -- CHANGELOG.md)" ]; then
    echo "note: CHANGELOG.md last updated in an older commit:" >&2
    git log -1 --format='      %h %s' -- CHANGELOG.md >&2
fi

if command -v parse-changelog >/dev/null 2>&1; then
    BODY="$(parse-changelog CHANGELOG.md "${TAG#v}")"
else
    echo "note: parse-changelog not found, using first CHANGELOG.md block" >&2
    BODY="$(awk '/^## /{ if (found) exit; found = 1; next } found' CHANGELOG.md)"
    if [ -z "$(printf '%s' "$BODY" | tr -d '[:space:]')" ]; then
        echo "error: could not extract a release block from CHANGELOG.md" >&2
        exit 1
    fi
fi

# gh creates its tag from the GitHub default branch head; abort if the mirror lags
GH_HEAD="$(gh api "repos/$GH_REPO/commits/HEAD" --jq .sha)"
if [ "$GH_HEAD" != "$(git rev-parse HEAD)" ]; then
    echo "error: GitHub mirror head ($GH_HEAD) != local HEAD; wait for mirror sync" >&2
    exit 1
fi

zig build -Doptimize=ReleaseSmall
ASSET="zig-out/zigi-$TAG-linux-x86_64"
cp zig-out/bin/zigi "$ASSET"

fj release create "$TAG" --create-tag --attach "$ASSET" --body "$BODY"
gh release create "$TAG" "$ASSET" --repo "$GH_REPO" --title "$TAG" --notes "$BODY"

git fetch --tags origin
echo "released $TAG on Codeberg and GitHub"
