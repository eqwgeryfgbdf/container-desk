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
