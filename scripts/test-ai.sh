#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/../work/ai-tests"
mkdir -p "$BUILD"
export AI_FIXTURE="$ROOT/Tests/AI/mcp-fixture.py"
export AI_PYTHON="$(command -v python3)"
export AI_CONTAINER="$(command -v container || true)"
export AI_REPORT="$BUILD/report.json"
xcrun swiftc -swift-version 5 -parse-as-library -target arm64-apple-macos26.0 \
 "$ROOT/Sources/Models.swift" "$ROOT/Sources/HostInfo.swift" "$ROOT/Sources/ProcessRunner.swift" \
 "$ROOT/Sources/AIModels.swift" "$ROOT/Sources/AITransport.swift" "$ROOT/Sources/AIModelLibrary.swift" \
 "$ROOT/Tests/AI/AITests.swift" -o "$BUILD/AITests"
"$BUILD/AITests" "$@" | tee "$BUILD/results.log"
