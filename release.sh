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

BODY="$(awk '/^## /{ if (found) exit; found = 1; next } found' CHANGELOG.md)"
if [ -z "$(printf '%s' "$BODY" | tr -d '[:space:]')" ]; then
    echo "error: could not extract a release block from CHANGELOG.md" >&2
    exit 1
fi

# gh creates its tag from the GitHub default branch head; abort if the mirror lags
GH_HEAD="$(gh api "repos/$GH_REPO/commits/HEAD" --jq .sha)"
if [ "$GH_HEAD" != "$(git rev-parse HEAD)" ]; then
    echo "error: GitHub mirror head ($GH_HEAD) != local HEAD; wait for mirror sync" >&2
    exit 1
fi

zig build -Doptimize=ReleaseSmall
LINUX_ASSET="zig-out/zigi-$TAG-x86_64-linux.tar.gz"
tar czf "$LINUX_ASSET" -C zig-out/bin zigi -C ../.. resources

zig build -Doptimize=ReleaseSmall -Dtarget=x86_64-windows-gnu
WINDOWS_ASSET="zig-out/zigi-$TAG-x86_64-windows.zip"
zip -j "$WINDOWS_ASSET" zig-out/bin/zigi.exe
zip -r "$WINDOWS_ASSET" resources

fj release create "$TAG" --create-tag \
    --attach "$LINUX_ASSET" --attach "$WINDOWS_ASSET" --body "$BODY"
gh release create "$TAG" "$LINUX_ASSET" "$WINDOWS_ASSET" \
    --repo "$GH_REPO" --title "$TAG" --notes "$BODY"

git fetch --tags origin
echo "released $TAG on Codeberg and GitHub"
