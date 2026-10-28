# Container Desk 1.0.0

[English](README.md) · [中文（繁體）](README.zh-Hant.md) · [中文（简体）](README.zh-Hans.md)

Native SwiftUI management for **Apple Container** on Apple Silicon and macOS 26+. Independent open-source software, not an Apple product. The app is named **Container Desk**; the website title **Apple Container Desk** describes the engine it manages.

[Download 1.0.0 DMG](https://github.com/eqwgeryfgbdf/container-desk/releases/download/v1.0.0/Container-Desk-1.0.0-arm64.dmg) · [Website](https://container.emo-lab.com/en/) · [Release notes](docs/RELEASE_NOTES_1.0.0.md) · [Quick start](docs/QUICK_START.md)

1.0 consolidates the existing container-management, projects, AI/MCP and image-update workflows into one release. It includes the latest **VM + Package** icon in the installer, Dock and app sidebar, three-language documentation and the website source.

**Distribution:** ad hoc signed, without Developer ID or Apple notarization. Requires Apple Silicon and macOS 26+; testing is limited to the developer’s M4 Mac mini, macOS 26.7.1 and Apple Container 1.5.0. Second-Mac testing remains deferred. A 1.0 version number does not certify every engine version, Docker project or AI model. [Current verification and remaining limits](docs/RELEASE_1.0.0_VALIDATION.md).

## Start in a few minutes

1. Open the DMG, quit an existing Container Desk, and drag the new app into Applications. Approve replacement when requested. If macOS blocks opening, follow [per-app installation guidance](docs/QUICK_START.md); do not disable system protections globally.
2. Connect to the official Apple Container engine in **Container Engine**. The engine is a separate installation, downloaded from Apple’s official release source.
3. In **Images → Download & Deploy**, search Docker Hub or enter an image reference. Select an appropriate ARM64 image, download it and configure CPU, memory and published ports.
4. Create the stopped container, then start it. Double-click for details, inspect logs and click a published TCP web port to open its service.
5. For local AI, follow the [Hugging Face / llama.cpp / MCP guide](docs/AI_QUICK_START.md). Begin with SmolLM2 135M Q4_K_M (~105 MB). Text inference and tool calling are separate capabilities; the small test model did not pass tool calling.

## Included features

| Area | Available in 1.0 |
| --- | --- |
| Containers | Create, start, stop, restart, delete; reviewed batch actions; clone with explicit environment/mount choices; real host resources and container statistics. |
| Interface | macOS SwiftUI, English / Traditional Chinese / Simplified Chinese, sidebar reordering, expanded details, 80–150% zoom and Reduce Motion-aware transitions. |
| Images | Docker Hub search, platform inspection, download-and-configure, Dockerfile builds, tags, OCI import/export, updates and reviewed container replacement/rollback. |
| Storage and files | Networks, volumes, selective cleanup, file browsing/transfers and container-to-image snapshots. No global prune; mounted data is not included in snapshots. |
| Registry and projects | Registry login/push, HTTPS catalog/tag browsing, supported Compose import and Docker project conversion with unsupported-field diagnostics. |
| Local AI and MCP | Public Hugging Face single-file GGUF search/download with revision and SHA-256 verification; llama.cpp CPU deployment; capability tests; reviewed MCP tool calls. |
| Engine | Official-source installation and workload-aware manual / opt-in automatic updates while the app is open. |

## Quick test

Download and inspect the script before running it:

```sh
curl -fL https://raw.githubusercontent.com/eqwgeryfgbdf/container-desk/v1.0.0/scripts/quick-test.sh -o quick-test.sh
bash quick-test.sh --check
bash quick-test.sh --run
```

`--check` is read-only. `--run` creates a temporary loopback HTTP container, verifies it and removes its own resources. No AI model is installed. [Test details](docs/AUTOMATED_QA.md).

## Screenshots and tutorial

![Overview with actual host information](docs/images/overview-en.png)
![Container management](docs/images/containers-en.jpg)
![Container creation controls](docs/images/create-en.png)

These captures show historical 0.2.0 UI with host names masked, not a fresh 1.0 acceptance run. [Media provenance](docs/MEDIA.md). The [90-second AI tutorial](docs/video/README.md) uses real interface stills, narration and labeled explanations; it is not a continuous deployment recording.

## Upgrade and limits

- Quit the old app before replacement. Existing Apple Container workloads, images and volumes stay in the engine’s storage.
- 1.0 uses the stable app identifier `local.containerdesk.app`. The 0.3 preview used `local.containerdesk.ai-development`; its interface preferences and saved AI selection are not automatically migrated. Reselect an existing local GGUF file or model cache when needed; do not delete engine data to upgrade.
- Compose support is a validated subset. Docker local images and persistent data need separate migration; architecture selection does not convert binaries. No remote-host management, embedded terminal or background updater when the app is closed.
- Local AI runs on CPU inside a Linux VM, without Metal. Restricted/split GGUF models are not handled by public search. Model quality and MCP support vary; connections and proposed tool calls require review.
- Image replacement changes container names/IPs and causes downtime. Originals are retained; rollback does not reverse writes to mounted data or database migrations. [Update guide](docs/IMAGE_UPDATES.md).
- Clean engine installation, real engine upgrades, external private HTTPS registry success and full manual VoiceOver acceptance remain unverified. Detailed results distinguish current checks from historical evidence.

## Source and packaging

```sh
bash scripts/test.sh
bash scripts/build.sh
# Commit the intended source before packaging:
bash scripts/package.sh ../outputs
```

Release attachments contain **only the DMG**. Source is available in GitHub’s automatic tag archives under [Apache-2.0](LICENSE). The installer and tag use the same source commit; SHA-256 is in the release body. The optional Developer ID/notarization pipeline is separate from the ad hoc public build.

- [Website source and deployment](website/README.md)
- [Files, registry and projects](docs/COMPOSE_AND_FILES.md)
- [Docker conversion](docs/DOCKER_CONVERSION.md)
- [Feature scope](docs/FEATURE_ROADMAP.md)
- [Official Apple Container dependency](https://github.com/apple/container), installed separately.
