#!/bin/bash
# Packages Unprompted for a GitHub release: a universal (Apple Silicon and
# Intel), ad-hoc signed app in a zip, built from committed code only.
#
#   tools/make-release.sh             package HEAD
#   tools/make-release.sh <commit>    package another commit or tag
#
# Writes build/release/Unprompted-<version>.zip, with the version taken
# from Resources/Info.plist, and prints its SHA-256.
set -euo pipefail
unset CDPATH
cd "$(dirname "$0")/.."

REF="${1:-HEAD}"
if [ "$REF" = HEAD ] && [ -n "$(git status --porcelain --untracked-files=no)" ]; then
    echo "Note: uncommitted changes are left out of the release." >&2
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# Building from an export keeps out anything that isn't committed,
# such as characters kept only on this Mac.
git archive "$REF" | tar -x -C "$WORK"
"$WORK/build.sh" release --no-install --universal

APP="$WORK/build/Unprompted.app"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$APP/Contents/Info.plist")"
ZIP="build/release/Unprompted-$VERSION.zip"
mkdir -p build/release
rm -f "$ZIP"
# ditto keeps the bundle's signature and metadata intact.
ditto -c -k --keepParent "$APP" "$ZIP"

echo
echo "Built $ZIP from $(git rev-parse --short "$REF") ($(lipo -archs "$APP/Contents/MacOS/Unprompted"))"
shasum -a 256 "$ZIP"
