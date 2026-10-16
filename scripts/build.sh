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
xcrun swiftc -swift-version 5 -parse-as-library -target arm64-apple-macos26.0 -O -o "$APP/Contents/MacOS/ContainerDesk" "$ROOT"/Sources/*.swift
python3 "$ROOT/scripts/bundle_resources.py" "$APP"
if [[ -f "$ROOT/Resources/AppIcon.icns" ]]; then cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/"; fi
codesign --force --sign - "$APP"
codesign --verify --strict "$APP"
echo "Development app: $APP (ad hoc signed; not notarized)"
