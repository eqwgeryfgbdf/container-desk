#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="${1:-$ROOT/../work/build}"
SDK_VERSION="$(xcrun --show-sdk-version)"
if [[ "${SDK_VERSION%%.*}" -lt 26 ]]; then
  echo "macOS SDK 26 or later is required. Install Xcode 26 or Command Line Tools 26." >&2
  exit 1
fi
APP="$DEST/Container Desk.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
swift build --package-path "$ROOT" --configuration release --arch arm64
BIN_DIR="$(swift build --package-path "$ROOT" --configuration release --arch arm64 --show-bin-path)"
cp "$BIN_DIR/ContainerDesk" "$APP/Contents/MacOS/ContainerDesk"
python3 "$ROOT/scripts/bundle_resources.py" "$APP"
rm -f "$APP/Contents/Resources/AppIcon.icns"
if [[ -f "$ROOT/Resources/AppIcon.icns" ]]; then cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon-VMPackage.icns"; fi
codesign --force --sign - "$APP"
codesign --verify --strict "$APP"
echo "Built app: $APP (ad hoc signed; not notarized)"
