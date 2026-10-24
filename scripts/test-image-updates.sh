#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$ROOT/../work/tests"
xcrun swiftc -swift-version 5 -parse-as-library -target arm64-apple-macos26.0 \
 "$ROOT/Sources/Models.swift" "$ROOT/Sources/ResourceOperations.swift" "$ROOT/Sources/ProcessRunner.swift" "$ROOT/Sources/ImageUpdates.swift" \
 "$ROOT/Tests/ImageUpdates/ImageUpdateTests.swift" -o "$ROOT/../work/tests/ImageUpdateTests"
"$ROOT/../work/tests/ImageUpdateTests" "$@"
