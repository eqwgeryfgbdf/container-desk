#!/bin/bash
# Local working-tree preview; never uploads or replaces a stable GitHub release.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/../work/ai-build"
OUT="$ROOT/../outputs/development"
META="$ROOT/../work/ai-build/source-state.json"
mkdir -p "$BUILD" "$OUT"
python3 - "$ROOT" "$META" <<'PY'
import hashlib,json,pathlib,subprocess,sys
root=pathlib.Path(sys.argv[1])
paths=subprocess.check_output(['git','-C',str(root),'ls-files','-co','--exclude-standard','-z']).decode().split('\0')
files={p:hashlib.sha256((root/p).read_bytes()).hexdigest() for p in sorted(set(paths)) if p and (root/p).is_file()}
pathlib.Path(sys.argv[2]).write_text(json.dumps({'base_commit':subprocess.check_output(['git','-C',str(root),'rev-parse','HEAD']).decode().strip(),'working_tree_preview':True,'files':files},indent=2)+'\n')
PY
CONTAINERDESK_DISTRIBUTION=development CONTAINERDESK_BUNDLE_ID=local.containerdesk.ai-development bash "$ROOT/scripts/build.sh" "$BUILD"
python3 - "$ROOT" "$META" <<'PY'
import hashlib,json,pathlib,subprocess,sys
root=pathlib.Path(sys.argv[1]);expected=json.loads(pathlib.Path(sys.argv[2]).read_text())['files']
paths=subprocess.check_output(['git','-C',str(root),'ls-files','-co','--exclude-standard','-z']).decode().split('\0')
actual={p:hashlib.sha256((root/p).read_bytes()).hexdigest() for p in sorted(set(paths)) if p and (root/p).is_file()}
if actual!=expected: raise SystemExit('Source changed during build; rebuild the preview.')
PY
APP="$BUILD/Container Desk.app"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$APP/Contents/Info.plist")"
STAGE="$(mktemp -d "${TMPDIR:-/tmp}/containerdesk-preview.XXXXXX")"
trap 'rm -rf "$STAGE"' EXIT
ditto "$APP" "$STAGE/Container Desk.app"
ln -s /Applications "$STAGE/Applications"
cp "$ROOT/docs/AI_QUICK_START.md" "$STAGE/Read Me - Development Preview.md"
cp "$ROOT"/docs/AI_QUICK_START*.md "$ROOT/docs/AI_VALIDATION.md" "$STAGE/"
cp "$ROOT/docs/IMAGE_UPDATES.md" "$STAGE/"
cp "$ROOT/LICENSE" "$STAGE/LICENSE.txt"
DMG="$OUT/Container-Desk-$VERSION-arm64-preview.dmg"
hdiutil create -volname 'Container Desk Preview' -srcfolder "$STAGE" -ov -format UDZO "$DMG"
hdiutil verify "$DMG"
shasum -a 256 "$DMG" > "$BUILD/DMG-SHA256.txt"
echo "Local development preview only: $DMG"
