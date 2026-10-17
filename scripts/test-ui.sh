#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$ROOT/../work/tests"
xcrun swiftc "$ROOT/Tests/UI/UIAutomation.swift" -o "$ROOT/../work/tests/UIAutomation"
python3 "$ROOT/scripts/ui-qa.py" "$@"
