#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-$ROOT/../outputs}"
STAGE="$(mktemp -d "${TMPDIR:-/tmp}/containerdesk-dmg.XXXXXX")"
trap 'rm -rf "$STAGE"' EXIT
mkdir -p "$OUT"
bash "$ROOT/scripts/build.sh"
ditto "$ROOT/../work/build/Container Desk.app" "$STAGE/Container Desk.app"
ln -s /Applications "$STAGE/Applications"
cp "$ROOT/README.md" "$STAGE/Read Me.md"
hdiutil create -volname 'Container Desk Preview' -srcfolder "$STAGE" -ov -format UDZO "$OUT/Container-Desk-0.1.2-arm64-preview.dmg"
hdiutil verify "$OUT/Container-Desk-0.1.2-arm64-preview.dmg"
