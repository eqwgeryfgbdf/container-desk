# Container Desk 0.2.0 — Public Release

[English](README.md) · [中文（繁體）](README.zh-Hant.md) · [中文（简体）](README.zh-Hans.md)

Native SwiftUI manager for **local Apple Container**, built with the macOS 26 SDK. Requires Apple Silicon, macOS 26 or later, and tested engine **1.5.0**. This is an independent application, not an Apple product.

[Download 0.2.0](https://github.com/eqwgeryfgbdf/container-desk/releases/tag/v0.2.0) · [Detailed quick start](docs/QUICK_START.md) · [Release notes](RELEASE_NOTES.md)

**Public release 0.2.0.** Tested only on the developer's own M4 Mac mini (16 GiB, macOS 26.7.1, Apple Container 1.5.0). The owner explicitly deferred second-Mac testing. This release is ad hoc signed, without Developer ID or Apple notarization. Read the [verification scope and known limits](docs/RELEASE_0.2.0_VALIDATION.md) before use.

## Try it in five minutes

1. Download the DMG and optional `Container-Desk-0.2.0-Quick-Start.zip` from the release. Verify them using `SHA256SUMS.txt`.
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

### Create a container

![Downloaded image picker, CPU menu and memory slider with direct numeric entry](docs/images/create-en.png)

[Watch the actual app walkthrough](https://github.com/eqwgeryfgbdf/container-desk/releases/download/v0.2.0/Container-Desk-Overview-zh-Hant.mp4) (Traditional Chinese captions). These screenshots and the video show **0.2.0 on the developer's own Mac**, using real disposable containers. Host names are visibly masked; runtime values are not fabricated. macOS's recording indicator may be visible. Media does not certify installation or upgrades. [Media provenance](docs/MEDIA.md).


## What is included in 0.2.0

- **Duplicate safely:** create a separate container from inspected configuration. Ports are cleared; environment and mounts require opt-in, mounts default read-only, and writable sharing requires a stopped source. The original container stays intact.
- **Disk usage:** inspect actual image/container/volume usage and review selectively eligible image/network/volume cleanup; no global prune.
- **Image defaults and catalogs:** inspect startup command, user, working directory and exposed ports before creation; browse HTTPS Registry V2 repository/tag pages and deploy a selected tag. Catalog authentication is a separate ephemeral Basic-auth session, not universal bearer-token support.
- **Containers:** create, start, stop, restart, inspect and delete; reviewed batch selection/actions; CPU menu, synchronized memory slider/number field, and downloaded-image selector. New containers start stopped.
- **Details:** double-click to expand, live CPU/memory/process/network summaries, session charts, searchable/exportable logs, clickable TCP web links and Copy URL. Missing measurements remain unavailable; network totals are cumulative traffic.
- **Images and deployment:** Docker Hub search, registry references, platform inspection, download-and-configure, ARM64 or AMD64/Rosetta selection, Dockerfile builds, tag/delete, OCI import/export. Architecture selection is not binary conversion.
- **Files and snapshots:** container file browsing, non-overwriting transfers, and Save Container as Image. Mounted data is excluded from snapshots; environment variables require opt-in. [Scope and limits](docs/CONTAINER_SNAPSHOTS.md).
- **Registry, networks and volumes:** login/logout and image push, searchable inventories, creation, protected deletion and batch review. [Usage](docs/COMPOSE_AND_FILES.md).
- **Projects and Docker migration:** review/import supported Compose configurations, convert a Docker project into a separate configuration, optionally resolve Compose overrides with the installed official Compose CLI, then start/stop/remove managed services. Unsupported fields block import; local Docker images and volume data need separate migration. [Conversion guide](docs/DOCKER_CONVERSION.md).
- **Native interface:** saved sidebar ordering, 80–150% content zoom (⌘+, ⌘−, ⌘0), Reduce Motion-aware transitions, actual host hardware, English/Traditional Chinese/Simplified Chinese, and no demo mode.
- **Engine:** official-source installation and manual/opt-in automatic updates with workload checks. Installation requires a tested release and system authorization. Updates run only while the app is open.

## Verification and remaining work

Automated tests cover container lifecycle, persistent data, files, images, projects, conversion, registry failure/loopback push paths and resource protection. New regressions cover clone preconditions, image metadata, registry catalog validation and three repaired medium-severity security findings. See the [current validation record](docs/RELEASE_0.2.0_VALIDATION.md) for exact results, skipped checks and final stability measurements; a skipped check is not a pass.

Clean engine installation, genuine engine upgrades, external private HTTPS registry success and complete manual VoiceOver acceptance remain unverified. Only the developer's own device was used. AI is deferred. Full Docker migration still requires separate data/local-image transfer, with no restart supervisor or automatic cutover/rollback. There is no remote-host management, embedded terminal or updater while the app is closed. [Feature status](docs/FEATURE_ROADMAP.md) · [Report a test result](docs/TEST_REPORT.md).

## Source, packaging and license

The DMG, `source.zip` and manifest are built from the same release commit. The source ZIP contains **Apache-2.0** licensing, resources, scripts and tests. `SHA256SUMS.txt` covers the uploaded files; `BUILD.json` in the optional Quick Start ZIP records its source commit. The Quick Start ZIP does not duplicate the DMG. Historical 0.1.2 assets remain available for traceability.

For contributors with Command Line Tools/Xcode 26 and Python 3:

```sh
bash scripts/test.sh
bash scripts/build.sh
# Commit all source changes before pairing release artifacts:
bash scripts/package.sh ../outputs
python3 scripts/make-quick-start.py --output ../outputs
```

Packaging refuses a dirty checkout. Keep the GitHub release tag on the manifest's source commit. The optional Developer ID/notarization pipeline is prepared; this public build has only an ad hoc signature. [Apache-2.0 license](LICENSE) · [Release gates](docs/PUBLIC_RELEASE_GATE.md).

## Official dependency

[Apple Container](https://github.com/apple/container) is a separate dependency with its own license. Its official installer is downloaded when needed and is not bundled in this app.
