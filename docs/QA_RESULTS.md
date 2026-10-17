# Current-source QA — 2026-10-17

This is a source/development-build record, not certification of the existing GitHub download. The repository remains private and the public release decision remains **NOT READY**.

## Environment and reproducibility

Apple Silicon Mac mini (M4, 16 GiB), macOS 26.7.1, Apple Container 1.5.0. Run the commands in [AUTOMATED_QA.md](AUTOMATED_QA.md). Tests use official Python/BusyBox/Distribution image fixtures, UUID resource names and explicit inventory comparisons. No user data is globally pruned; AI models are not installed.

The baseline revision before this work was local `5856d86bd97bc3d0c3ff93c6af0e3db5780c7399`, with tree `e59e83ecda0f6eadd2cb59ce60649fb042d7cfe7` (the same tree as GitHub main `4e441f2663f50bd0c2deef7a492869516e023e80`). The tests below exercise the changes delivered alongside this document. Raw logs and JSON/JUnit results are kept locally under `work/qa/final/` beside the checkout.

## Automated results

The full serial run `python3 scripts/qa.py --live --ui --report-dir ../work/qa/final` completed with **17 PASS, 0 FAIL and 5 explicit SKIP entries**. All executed suites passed, including exact before/after resource inventory comparison. The five skipped categories are clean-Mac install, real engine upgrade, private-registry success, manual accessibility acceptance and deferred AI models. The 60-minute stability gate is separately pending; it was not part of this run.

| Suite | Result | Seconds |
|---|---|---:|
| unit | PASS | 19.68 |
| creation-layout | PASS | 3.78 |
| motion | PASS | 6.71 |
| store-create | PASS | 2.82 |
| management | PASS | 24.06 |
| workflows | PASS | 39.7 |
| platform-files | PASS | 123.03 |
| conversion | PASS | 120.55 |
| resolved-compose | PASS | 121.93 |
| registry | PASS | 21.71 |
| snapshot | PASS | 47.21 |
| search | PASS | 8.92 |
| resource-batch | PASS | 2.77 |
| architecture | PASS | 11.45 |
| image-build-archive | PASS | 31.26 |
| native-ui | PASS | 69.05 |
| state-preservation | PASS | 0 |
| clean-mac-install | SKIP | 0 |
| real-core-upgrade | SKIP | 0 |
| private-registry-success | SKIP | 0 |
| accessibility-manual | SKIP | 0 |
| ai-models | SKIP | 0 |

Unit checks include 51 core/process checks, 35 management checks, 34 workflow checks, 13 simulated installer scenarios, 14 platform suites and completeness of 553 translation keys in all three languages. These counts are assertions/suites, not a percentage of application coverage. Installer simulations do not establish real installation or upgrade success.

## Security review and changes

A completed standard static/offline repository review of the baseline revision covered 102 of 103 tracked files; the binary icon was excluded from full code review. No critical or high-severity vulnerability was confirmed. Two medium-severity availability findings were accepted:

| Finding | Change in this candidate | Regression evidence |
|---|---|---|
| CWE-400: guest-controlled command stdout/stderr could exhaust host temporary storage or memory | General commands now use drained pipes with a 4 MiB budget per stream, termination on overflow/timeout and cancellation handling. | Small 5 MiB stdout/stderr fixtures and child cancellation/reaping checks pass. |
| CWE-409: guest file archives could expand beyond the received-data limit | Before host extraction, validate uncompressed tar headers, checksums, entries and allocation budget; reject compression, sparse metadata and size overrides. Limit: 4 GiB and 10,000 entries. | Ordinary/PAX long paths accepted; hostile-format/entry/metadata fixtures rejected. Real binary and directory transfer round trips pass. |

The sealed baseline scan is `1c78370b-aa05-4812-939b-83697e152f60`. It intentionally retains the original findings; the remediation and regression results are documented here rather than rewriting that historical report. This was not a live penetration test, and the fixes have not been represented as a second independent scan. Unsupported archive extensions are rejected safely and may require exporting a simpler ordinary tar archive.

Testing also exposed an operation-completion race: image pull could finish before refreshed image inventory was available to the next step. Completion now waits for inventory reconciliation. Older management assertions were updated to inspect the current wrapped error reason; real deletion protections continue to pass.

## Native UI and recording

The native test uses observable Accessibility elements plus actual keyboard/mouse events. It validates batch selection/filtering, search, double-click details, zoom commands, logs, file browsing, download-to-configuration, and navigation. The fixture containers are real and removed afterward.

An initial UI automation failure was caused by AX text assignment not delivering SwiftUI edit events; keyboard input fixed the harness. Native window resizing is verified against actual window bounds. These were not classified as app hangs. The earlier UI-001 discrete-slider layout fix remains separate and covered by native layout tests.

The successful recording repeats all **56 UI steps** and exports a **58.5-second, 1280×800 MP4** with Traditional Chinese captions, host-name masks and a development-preview footer. Only trailing idle footage is trimmed. Four full-resolution review frames and a five-second contact sheet were inspected; 58 one-second samples decoded successfully and OCR flagged no host name or `/Users/` path. OCR is supplementary and is not a privacy guarantee. Full manual playback remains required before public publication.

The first recording attempt was discarded by macOS when interrupted; the recorder now waits for its bounded 90-second capture to finish normally and verifies that a movie was saved. The successful rerun and annotation checks are recorded separately from the unified QA run. Standalone UI testing was then repeated from an empty container/image inventory: the helper downloaded its official Python fixture, all 56 steps passed, and exact empty inventory was restored afterward. A two-minute soak-helper smoke finished as `INCOMPLETE`, as designed; it does not pass the 60-minute gate.

Local deliverable: `outputs/qa-20261017/Container-Desk-Overview-zh-Hant.mp4` beside the checkout. SHA-256: `2fcb8e30e15a1e7ad815c70f64a9328cf682af416c234bd7316e82af87f40106`. Raw footage stays in the private local work directory; neither video nor existing GitHub Release assets was automatically published.

The disposable bootstrap builder and Python image were then removed, restoring the original empty container/image/volume inventory and the sole default network. The installed application bundle was compared byte-for-byte with the tested build and its ad hoc signature verified; the previous bundle was backed up. The tested executable SHA-256 is `f85f6eb14bc31726332f9248c9dac83e672c04d682f08dafa2edad4bdf53c0e8`.

## Remaining release gates

- Second clean Mac: actual downloaded DMG, first launch, official core installation, administrator cancel/retry and supported upgrade recovery.
- Successful authentication to a dedicated trusted HTTPS private registry (loopback push and negative authentication tests are automated).
- Full three-language/light/dark/window-size/VoiceOver/contrast acceptance, sidebar drag ordering and browser URL-opening checks.
- Full 60-minute stability/performance acceptance with navigation/refresh timing. The new soak script covers the idle process/CPU/RSS portion only.
- Candidate DMG/source pairing and release-asset verification after this commit is packaged and published.

AI deployment is deferred by request. The next model trial should use one small local model and measure memory/latency before broadening support.
