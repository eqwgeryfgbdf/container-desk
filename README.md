# Container Desk 0.1.3 — Developer Preview

[English](README.md) · [中文（繁體）](README.zh-Hant.md) · [中文（简体）](README.zh-Hans.md)

Native SwiftUI manager for **local Apple Container**, built with the macOS 26 SDK. Requires Apple Silicon, macOS 26 or later, and tested engine **1.5.0**. This is an independent application, not an Apple product.

[Download 0.1.3 preview](https://github.com/eqwgeryfgbdf/container-desk/releases/tag/v0.1.3-preview) · [Detailed quick start](docs/QUICK_START.md) · [Release notes](RELEASE_NOTES.md)

**The repository remains private.** Testers need repository access and GitHub sign-in. Public visibility waits for the [acceptance gates](docs/PUBLIC_RELEASE_GATE.md); this preview is not a verified stable release.

## Try it in five minutes

1. Download the DMG and optional `Container-Desk-0.1.3-Quick-Start.zip` from the release. Verify them using `SHA256SUMS.txt`.
2. Drag **Container Desk.app** to **Applications**. This build is ad hoc signed, without Developer ID or Apple notarization; see the [installation guide](docs/QUICK_START.md#2-install-and-connect) if macOS blocks opening it.
3. Open **Container Engine** to connect to or install the supported official Apple Container engine. The app and engine are separate downloads; administrator authorization belongs to macOS.
4. Unzip the Quick Start bundle, open Terminal in its folder, and run:

```sh
bash quick-test.sh --check
bash quick-test.sh --run
```

The check is read-only. The test uses one temporary BusyBox HTTP container on `127.0.0.1:18080`, verifies HTTP, exec/log access and stop/start persistence, then removes its own resources. No Xcode, Python or sudo is needed. Use `--run --keep` to explore that container in the app and follow the printed cleanup commands. The guide also walks through a GUI-only Python web server and a small imported project. This smoke test does not certify every UI or installation path.

## Screenshots and video

### Overview

![Actual Mac specifications and live container totals](docs/images/overview-en.png)

### Container management

![Container management, search, status and resource allocation](docs/images/containers-en.jpg)

[Watch or download the 58.5-second walkthrough](https://github.com/eqwgeryfgbdf/container-desk/releases/download/v0.1.3-preview/Container-Desk-Overview-zh-Hant.mp4) (Traditional Chinese captions). Screenshots and video come from the preceding 0.1.2 QA build on macOS 26.7.1; they show real disposable fixtures, with host identity redacted. They are not evidence of a clean 0.1.3 installation or upgrade. [Media provenance](docs/MEDIA.md).

## What is included in 0.1.3

- **Containers:** create, start, stop, restart, inspect and delete; reviewed batch selection/actions; CPU menu, synchronized memory slider/number field, and downloaded-image selector. New containers start stopped.
- **Details:** double-click to expand, live CPU/memory/process/network summaries, session charts, searchable/exportable logs, clickable TCP web links and Copy URL. Missing measurements remain unavailable; network totals are cumulative traffic.
- **Images and deployment:** Docker Hub search, registry references, platform inspection, download-and-configure, ARM64 or AMD64/Rosetta selection, Dockerfile builds, tag/delete, OCI import/export. Architecture selection is not binary conversion.
- **Files and snapshots:** container file browsing, non-overwriting transfers, and Save Container as Image. Mounted data is excluded from snapshots; environment variables require opt-in. [Scope and limits](docs/CONTAINER_SNAPSHOTS.md).
- **Registry, networks and volumes:** login/logout and image push, searchable inventories, creation, protected deletion and batch review. [Usage](docs/COMPOSE_AND_FILES.md).
- **Projects and Docker migration:** review/import supported Compose configurations, convert a Docker project into a separate configuration, optionally resolve Compose overrides with the installed official Compose CLI, then start/stop/remove managed services. Unsupported fields block import; local Docker images and volume data need separate migration. [Conversion guide](docs/DOCKER_CONVERSION.md).
- **Native interface:** saved sidebar ordering, 80–150% content zoom (⌘+, ⌘−, ⌘0), Reduce Motion-aware transitions, actual host hardware, English/Traditional Chinese/Simplified Chinese, and no demo mode.
- **Engine:** official-source installation and manual/opt-in automatic updates with workload checks. Installation requires a tested release and system authorization. Updates run only while the app is open.

## Verification and remaining work

The preceding automated baseline passed **17 groups, 0 failures**, including **56 native UI steps**; 5 environment-dependent groups were skipped. Core, management, workflow, installer simulation and platform suites are repeatable from scripts. Real ARM64 and AMD64/Rosetta paths were exercised. The creation-sheet layout hang was fixed. This release adds a no-compiler smoke test and synchronized packaged-app version reporting. [Automation guide](docs/AUTOMATED_QA.md) · [Release validation](docs/RELEASE_0.1.3_VALIDATION.md).

Clean installation/upgrade on the second Mac, complete accessibility acceptance, a 60-minute soak and real private-registry acceptance remain pending. The short soak smoke is not the long-run acceptance test. AI model integration is deferred. There is no remote-host management, embedded interactive terminal, closed-app updater or independent guest-kernel updater. File extraction accepts bounded ordinary tar archives; compressed/sparse or oversized archives are refused. The security review found no validated high/critical findings within its scope; this is not a guarantee of absence. [Feature status](docs/FEATURE_ROADMAP.md) · [Report a test result](docs/TEST_REPORT.md).

## Source, packaging and license

The DMG, `preview-source.zip` and manifest are built from the same release commit. The source ZIP contains **Apache-2.0** licensing, resources, scripts and tests. `SHA256SUMS.txt` covers the uploaded files; `BUILD.json` in the optional Quick Start ZIP records its source commit. The Quick Start ZIP does not duplicate the DMG. Historical 0.1.2 assets remain available for traceability.

For contributors with Command Line Tools/Xcode 26 and Python 3:

```sh
bash scripts/test.sh
bash scripts/build.sh
# Commit all source changes before pairing release artifacts:
bash scripts/package.sh ../outputs
python3 scripts/make-quick-start.py --output ../outputs
```

Packaging refuses a dirty checkout. Keep the GitHub release tag on the manifest's source commit. The optional Developer ID/notarization pipeline is prepared but has not produced a signed stable release. [Apache-2.0 license](LICENSE) · [Release gates](docs/PUBLIC_RELEASE_GATE.md).

## Official dependency

[Apple Container](https://github.com/apple/container) is a separate dependency with its own license. Its official installer is downloaded when needed and is not bundled in this app.
