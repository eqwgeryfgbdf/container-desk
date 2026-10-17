#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
swift build --package-path "$ROOT" --configuration debug --product ContainerDesk
BIN="$(swift build --package-path "$ROOT" --configuration debug --show-bin-path)"
mkdir -p "$ROOT/../work/tests"
xcrun swiftc -swift-version 5 -parse-as-library -target arm64-apple-macos26.0 \
 -I "$BIN/Modules" -I "$ROOT/.build/checkouts/Yams/Sources/CYaml/include" \
 "$ROOT/Sources/Models.swift" "$ROOT/Sources/HostInfo.swift" "$ROOT/Sources/ProcessRunner.swift" \
 "$ROOT/Sources/ResourceOperations.swift" "$ROOT/Sources/StreamingProcess.swift" "$ROOT/Sources/Store.swift" \
 "$ROOT/Sources/ManagementStore.swift" "$ROOT/Sources/FileOperations.swift" "$ROOT/Sources/RegistryOperations.swift" \
 "$ROOT/Sources/DeploymentSource.swift" "$ROOT/Sources/DockerComposeResolver.swift" "$ROOT/Sources/DockerProjectConverter.swift" "$ROOT/Sources/ComposePlan.swift" "$ROOT/Sources/ComposeOperations.swift" \
 "$ROOT"/Tests/Platform/*.swift "$BIN"/Yams.build/*.o "$BIN"/CYaml.build/src/*.o \
 -o "$ROOT/../work/tests/PlatformTests"
"$ROOT/../work/tests/PlatformTests" "$@"
