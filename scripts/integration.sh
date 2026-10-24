#!/bin/bash
# Opt-in: creates and deletes only UUID-named temporary test containers.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/../work/tests"
mkdir -p "$BUILD"
xcrun swiftc -swift-version 5 -parse-as-library -target arm64-apple-macos26.0 "$ROOT/Sources/Models.swift" "$ROOT/Sources/ProcessRunner.swift" "$ROOT/Sources/HostInfo.swift" "$ROOT/Sources/Store.swift" "$ROOT/Sources/ImageUpdates.swift" "$ROOT/Sources/ResourceOperations.swift" "$ROOT/Sources/StreamingProcess.swift" "$ROOT/Sources/ManagementStore.swift" "$ROOT/Tests/StoreSmoke.swift" -o "$BUILD/StoreSmoke"
"$BUILD/StoreSmoke"
if [[ $# -eq 2 ]]; then
  xcrun swiftc -swift-version 5 -parse-as-library -target arm64-apple-macos26.0 "$ROOT/Sources/Models.swift" "$ROOT/Sources/ProcessRunner.swift" "$ROOT/Tests/IntegrationSmoke.swift" -o "$BUILD/IntegrationSmoke"
  "$BUILD/IntegrationSmoke" "$1" "$2"
fi
