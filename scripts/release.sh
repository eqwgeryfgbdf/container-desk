#!/bin/bash
# Production signing/notarization. Credentials stay in Keychain; never in this script.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [[ "${1:-}" == "--check" ]]; then
  xcrun --find notarytool
  xcrun --find stapler
  security find-identity -v -p codesigning
  exit 0
fi
: "${SIGNING_IDENTITY:?Set SIGNING_IDENTITY to your Developer ID Application certificate name or hash}"
: "${NOTARY_PROFILE:?Set NOTARY_PROFILE to an existing notarytool Keychain profile name}"
if ! security find-identity -v -p codesigning | grep -F -- "$SIGNING_IDENTITY" | grep -F "Developer ID Application:" >/dev/null; then
  echo 'The requested signing identity is not available in Keychain.' >&2
  exit 1
fi
OUT="$ROOT/../outputs"
BUILD="$ROOT/../work/release"
CONTAINERDESK_DISTRIBUTION=release CONTAINERDESK_BUNDLE_ID=local.containerdesk.app bash "$ROOT/scripts/build.sh" "$BUILD"
APP="$BUILD/Container Desk.app"
codesign --force --sign "$SIGNING_IDENTITY" --options runtime --timestamp "$APP"
codesign --verify --strict --verbose=2 "$APP"
STAGE="$(mktemp -d "${TMPDIR:-/tmp}/containerdesk-release.XXXXXX")"
trap 'rm -rf "$STAGE"' EXIT
ditto "$APP" "$STAGE/Container Desk.app"
ln -s /Applications "$STAGE/Applications"
cp "$ROOT/README.md" "$STAGE/Read Me.md"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$APP/Contents/Info.plist")"
DMG="$OUT/Container-Desk-$VERSION-arm64.dmg"
hdiutil create -volname 'Container Desk' -srcfolder "$STAGE" -ov -format UDZO "$DMG"
codesign --force --sign "$SIGNING_IDENTITY" --timestamp "$DMG"
RESULT="$BUILD/notarization.json"
xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait --output-format json > "$RESULT"
python3 - "$RESULT" <<'PY'
import json,sys
r=json.load(open(sys.argv[1]))
if r.get('status')!='Accepted':
    raise SystemExit('Notarization not accepted. Review work/release/notarization.json and the submission log.')
PY
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"
hdiutil verify "$DMG"
MOUNT="$BUILD/gatekeeper-mount"
mkdir -p "$MOUNT"
hdiutil attach "$DMG" -readonly -nobrowse -mountpoint "$MOUNT"
trap 'hdiutil detach "$MOUNT" >/dev/null 2>&1 || true; rm -rf "$STAGE"' EXIT
spctl --assess --type execute --verbose=2 "$MOUNT/Container Desk.app"
hdiutil detach "$MOUNT"
echo "Signed and notarized DMG: $DMG"
