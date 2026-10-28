#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [[ -n "$(git -C "$ROOT" status --porcelain)" ]]; then
  echo 'Commit source changes before packaging so the DMG matches its release tag.' >&2
  exit 1
fi
COMMIT="$(git -C "$ROOT" rev-parse HEAD)"
OUT="${1:-$ROOT/../outputs}"
STAGE="$(mktemp -d "${TMPDIR:-/tmp}/containerdesk-dmg.XXXXXX")"
trap 'rm -rf "$STAGE"' EXIT
mkdir -p "$OUT"
CONTAINERDESK_DISTRIBUTION=unsigned-release bash "$ROOT/scripts/build.sh"
ditto "$ROOT/../work/build/Container Desk.app" "$STAGE/Container Desk.app"
ln -s /Applications "$STAGE/Applications"
if [[ -f "$ROOT/LICENSE" ]]; then cp "$ROOT/LICENSE" "$STAGE/LICENSE.txt"; fi
VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$ROOT/../work/build/Container Desk.app/Contents/Info.plist")"
python3 "$ROOT/scripts/installer-readme.py" "$STAGE" "$VERSION"
DMG="$OUT/Container-Desk-$VERSION-arm64.dmg"
hdiutil create -volname 'Container Desk' -srcfolder "$STAGE" -ov -format UDZO "$DMG"
hdiutil verify "$DMG"
python3 "$ROOT/scripts/source-artifacts.py" "$DMG" "$COMMIT"
