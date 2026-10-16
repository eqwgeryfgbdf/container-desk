#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/../work/tests"
mkdir -p "$BUILD"
xcrun swiftc -swift-version 5 -parse-as-library -target arm64-apple-macos26.0 \
  "$ROOT/Sources/ContentZoom.swift" "$ROOT/Sources/InterfaceMotion.swift" \
  "$ROOT/Tests/InterfaceMotionSmoke.swift" -o "$BUILD/InterfaceMotionSmoke"
"$BUILD/InterfaceMotionSmoke"
"$BUILD/InterfaceMotionSmoke" --reduced
