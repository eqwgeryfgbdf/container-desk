#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/../work/tests"
mkdir -p "$BUILD"
xcrun swiftc -swift-version 5 -parse-as-library -target arm64-apple-macos26.0 \
 "$ROOT/Sources/Store.swift" "$ROOT/Sources/ImageUpdates.swift" "$ROOT/Sources/HostInfo.swift" "$ROOT/Sources/Models.swift" \
 "$ROOT/Sources/ProcessRunner.swift" "$ROOT/Sources/ResourceOperations.swift" \
 "$ROOT/Sources/StreamingProcess.swift" "$ROOT/Sources/ManagementStore.swift" \
 "$ROOT/Tests/WorkflowIntegration.swift" -o "$BUILD/WorkflowIntegration"
"$BUILD/WorkflowIntegration" "$@"
