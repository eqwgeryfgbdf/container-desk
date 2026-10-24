# Container Desk 0.3.0 — Preview

[English](README.md) · [中文（繁體）](README.zh-Hant.md) · [中文（简体）](README.zh-Hans.md)

Native SwiftUI manager for **local Apple Container** on Apple Silicon and macOS 26+. Independent application, not an Apple product. Tested engine: **1.5.0**.

[Download 0.3.0 preview DMG](https://github.com/eqwgeryfgbdf/container-desk/releases/download/v0.3.0-preview/Container-Desk-0.3.0-arm64-preview.dmg) · [Release notes](https://github.com/eqwgeryfgbdf/container-desk/releases/tag/v0.3.0-preview) · [Hugging Face & local AI tutorial](docs/AI_QUICK_START.md) · [Previous stable 0.2.0](https://github.com/eqwgeryfgbdf/container-desk/releases/tag/v0.2.0)

**New in this preview:** search Hugging Face, filter single-file GGUF quantizations, compare sizes/licenses/memory estimates and download with pinned revisions and SHA-256 verification. Run llama.cpp locally in Apple Container, test model/MCP compatibility, and review tool calls before execution. Image updates now support reviewed container replacement, health checks and rollback. [AI validation](docs/AI_VALIDATION.md) · [Image update guide](docs/IMAGE_UPDATES.md).

Tested only on the developer's M4 Mac mini (16 GiB, macOS 26.7.1). Second-Mac testing remains deferred. This preview is **ad hoc signed, without Developer ID or Apple notarization**. Release attachments contain only the DMG; guides, tests and Apache-2.0 source remain in this repository. GitHub also generates source archives automatically.

## Try Hugging Face in five minutes

1. Download the DMG, drag **Container Desk.app** to **Applications**, then open it. If macOS blocks this unsigned preview, follow the per-app [installation guidance](docs/QUICK_START.md#2-install-and-connect); do not disable Gatekeeper globally.
2. Start or install the official Apple Container engine from **Container Engine**. Models and the llama.cpp server image are separate downloads.
3. Open **Local AI → Search Hugging Face**. Select the `SmolLM2-135M-Instruct` shortcut, then `bartowski/SmolLM2-135M-Instruct-GGUF`.
4. Filter files with `Q4_K_M`, select `SmolLM2-135M-Instruct-Q4_K_M.gguf` (~105 MB), review its license and click **Select & Download**.
5. For a tiny text test use 2 CPUs, 1 GiB and 1,024 context, then **Create and start llama.cpp**. Use **Test model and tool calling** before trying MCP. This model completed text inference but failed the tool-call probe; that warning is expected. [Full tutorial and troubleshooting](docs/AI_QUICK_START.md).

GGUF format alone does not guarantee engine or tool-call support. Inference uses CPU inside the Linux VM, without Metal. For a container-only smoke test, download and inspect the versioned script, then run:

```sh
curl -fL https://raw.githubusercontent.com/eqwgeryfgbdf/container-desk/v0.3.0-preview/scripts/quick-test.sh -o quick-test.sh
bash quick-test.sh --check
bash quick-test.sh --run
```

`--check` is read-only; `--run` creates, verifies and removes its own loopback HTTP test container. It does not install an AI model. No extra Release ZIP is needed.

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

Clean engine installation, genuine engine upgrades, external private HTTPS registry success and complete manual VoiceOver acceptance remain unverified. Only the developer's own device was used. AI is available in the development preview described above. Full Docker migration still requires separate data/local-image transfer, with no restart supervisor or automatic cutover/rollback. There is no remote-host management, embedded terminal or updater while the app is closed. [Feature status](docs/FEATURE_ROADMAP.md) · [Report a test result](docs/TEST_REPORT.md).

## Source, packaging and license

Future GitHub Releases attach only the `.dmg` installer. Source is available through GitHub’s automatic release-tag archives under **Apache-2.0**. Tutorials, test scripts and videos belong in the repository or documentation. Build manifests and checksums remain local under `../work/release-metadata`; they are not release attachments. Historical attachments remain unchanged.

For contributors with Command Line Tools/Xcode 26 and Python 3:

```sh
bash scripts/test.sh
bash scripts/build.sh
# Commit all source changes before pairing release artifacts:
bash scripts/package.sh ../outputs
```

Packaging refuses a dirty checkout. Keep the GitHub release tag on the build source commit. The optional Developer ID/notarization pipeline is prepared; this public build has only an ad hoc signature. [Apache-2.0 license](LICENSE) · [Release gates](docs/PUBLIC_RELEASE_GATE.md).

## Official dependency

[Apple Container](https://github.com/apple/container) is a separate dependency with its own license. Its official installer is downloaded when needed and is not bundled in this app.

### Update images and containers

Select an image → **Update → Check & Download Latest Image**, then **Apply Image to Container…** to review and replace an outdated container. Verification includes digest, runtime state and an optional HTTP health URL. Originals are retained for recovery; container name/IP change and mounted data is not rolled back. See [the update guide](docs/IMAGE_UPDATES.md) for limits and scripted tests. This feature is in the development build.
