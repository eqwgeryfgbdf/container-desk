#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/../work/tests"
mkdir -p "$BUILD"
xcrun swiftc -swift-version 5 -parse-as-library -target arm64-apple-macos26.0 "$ROOT/Sources/HostInfo.swift" "$ROOT/Sources/Models.swift" "$ROOT/Sources/ProcessRunner.swift" "$ROOT/Sources/UpdatePolicy.swift" "$ROOT/Tests/CoreTests.swift" -o "$BUILD/CoreTests"
"$BUILD/CoreTests"
python3 "$ROOT/scripts/check_localizations.py"
xcrun swiftc -swift-version 5 -parse-as-library -target arm64-apple-macos26.0 "$ROOT/Sources/Models.swift" "$ROOT/Sources/InstallWorkflow.swift" "$ROOT/Tests/InstallWorkflowTests.swift" -o "$BUILD/InstallWorkflowTests"
"$BUILD/InstallWorkflowTests"
xcrun swiftc -swift-version 5 -parse-as-library -target arm64-apple-macos26.0 "$ROOT/Sources/Models.swift" "$ROOT/Sources/ResourceOperations.swift" "$ROOT/Sources/StreamingProcess.swift" "$ROOT/Tests/ManagementTests.swift" -o "$BUILD/ManagementTests"
"$BUILD/ManagementTests"
xcrun swiftc -swift-version 5 -parse-as-library -target arm64-apple-macos26.0 "$ROOT/Sources/Models.swift" "$ROOT/Tests/WorkflowTests.swift" -o "$BUILD/WorkflowTests"
"$BUILD/WorkflowTests"

bash "$ROOT/scripts/test-platform.sh"

xcrun swiftc -swift-version 5 -parse-as-library -target arm64-apple-macos26.0 "$ROOT/Sources/Models.swift" "$ROOT/Tests/ConvenienceTests.swift" -o "$BUILD/ConvenienceTests"
"$BUILD/ConvenienceTests"

# Deterministic local AI/MCP tests; downloads only with test-ai.sh --live.
bash "$ROOT/scripts/test-ai.sh"

# Public model discovery parsing and verified cache behavior; no network by default.
bash "$ROOT/scripts/test-huggingface.sh"

# Image refresh, replacement, verification and rollback failure paths.
bash "$ROOT/scripts/test-image-updates.sh"
