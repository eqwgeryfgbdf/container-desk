#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/../work/huggingface-tests"
mkdir -p "$BUILD"
xcrun swiftc -swift-version 5 -parse-as-library -target arm64-apple-macos26.0 \
 "$ROOT/Sources/Models.swift" "$ROOT/Sources/HostInfo.swift" "$ROOT/Sources/ProcessRunner.swift" \
 "$ROOT/Sources/AIModels.swift" "$ROOT/Sources/AITransport.swift" "$ROOT/Sources/AIModelLibrary.swift" \
 "$ROOT/Sources/HuggingFaceModels.swift" "$ROOT/Tests/AI/HuggingFaceTests.swift" -o "$BUILD/HuggingFaceTests"
"$BUILD/HuggingFaceTests" "$@" | tee "$BUILD/results.log"
