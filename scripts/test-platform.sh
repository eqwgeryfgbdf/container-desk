#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
swift build --package-path "$ROOT" --configuration debug --product ContainerDesk
BIN="$(swift build --package-path "$ROOT" --configuration debug --show-bin-path)"
mkdir -p "$ROOT/../work/tests"
# Swift 6.3+ uses Swift Build's product layout; older tools use native SPM objects.
if [[ -f "$BIN/Yams.o" ]]; then
 MODULES="$BIN"
 OBJECTS=("$BIN/Yams.o" "$BIN/CYaml.o")
else
 MODULES="$BIN/Modules"
 OBJECTS=("$BIN"/Yams.build/*.o "$BIN"/CYaml.build/src/*.o)
fi
xcrun swiftc -swift-version 5 -parse-as-library -target arm64-apple-macos26.0 \
 -I "$MODULES" -I "$ROOT/.build/checkouts/Yams/Sources/CYaml/include" \
 "$ROOT/Sources/Models.swift" "$ROOT/Sources/HostInfo.swift" "$ROOT/Sources/ProcessRunner.swift" \
 "$ROOT/Sources/ResourceOperations.swift" "$ROOT/Sources/StreamingProcess.swift" "$ROOT/Sources/Store.swift" \
 "$ROOT/Sources/ManagementStore.swift" "$ROOT/Sources/FileOperations.swift" "$ROOT/Sources/RegistryOperations.swift" "$ROOT/Sources/RegistryCatalog.swift" \
 "$ROOT/Sources/ContainerSnapshot.swift" "$ROOT/Sources/DeploymentSource.swift" "$ROOT/Sources/HubSearch.swift" "$ROOT/Sources/DockerComposeResolver.swift" "$ROOT/Sources/DockerProjectConverter.swift" "$ROOT/Sources/ComposePlan.swift" "$ROOT/Sources/ComposeOperations.swift" \
 "$ROOT/Sources/AIModels.swift" "$ROOT/Sources/AITransport.swift" "$ROOT/Sources/AIModelLibrary.swift" "$ROOT/Sources/AIWorkspace.swift" \
 "$ROOT/Sources/ImageUpdates.swift" "$ROOT/Sources/ImageUpdateStore.swift" \
 "$ROOT"/Tests/Platform/*.swift "${OBJECTS[@]}" \
 -o "$ROOT/../work/tests/PlatformTests"
"$ROOT/../work/tests/PlatformTests" "$@"
