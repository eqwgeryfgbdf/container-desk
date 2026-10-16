#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [[ -n "$(git -C "$ROOT" status --porcelain)" ]]; then
  echo 'Commit source changes before packaging so the DMG and source archive match.' >&2
  exit 1
fi
COMMIT="$(git -C "$ROOT" rev-parse HEAD)"
OUT="${1:-$ROOT/../outputs}"
STAGE="$(mktemp -d "${TMPDIR:-/tmp}/containerdesk-dmg.XXXXXX")"
trap 'rm -rf "$STAGE"' EXIT
mkdir -p "$OUT"
bash "$ROOT/scripts/build.sh"
ditto "$ROOT/../work/build/Container Desk.app" "$STAGE/Container Desk.app"
ln -s /Applications "$STAGE/Applications"
cp "$ROOT/README.md" "$STAGE/Read Me.md"
if [[ -f "$ROOT/LICENSE" ]]; then cp "$ROOT/LICENSE" "$STAGE/LICENSE.txt"; fi
VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$ROOT/../work/build/Container Desk.app/Contents/Info.plist")"
DMG="$OUT/Container-Desk-$VERSION-arm64-preview.dmg"
hdiutil create -volname 'Container Desk Preview' -srcfolder "$STAGE" -ov -format UDZO "$DMG"
hdiutil verify "$DMG"
python3 "$ROOT/scripts/source-artifacts.py" "$DMG" "$COMMIT"
