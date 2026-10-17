# Container Desk 0.1.2 — Developer Preview

**English** · [中文（繁體）](README.zh-Hant.md) · [中文（简体）](README.zh-Hans.md)

Native SwiftUI manager for **local Apple Container**, built with the macOS 26 SDK. Requires an Apple Silicon Mac running macOS 26 or later. This is an independent application, not an Apple product.

[Download developer preview](https://github.com/eqwgeryfgbdf/container-desk/releases/tag/v0.1.2-preview) · [Public release criteria](docs/PUBLIC_RELEASE_GATE.md) · [Test report template](docs/TEST_REPORT.md)

**Release readiness: NOT READY for public visibility.** The repository stays private until all 14 required acceptance gates pass with evidence and no critical/major defects remain. Automated and smoke-test results below cover only part of that contract.

## Screenshots

### Overview

![Overview with actual Mac specifications and live container totals](docs/images/overview-en.png)

### Container management

![Container management with search, status and CPU and memory allocation](docs/images/containers-en.jpg)

Actual macOS 26.7.1 captures from the 0.1.2 QA app. The overview's computer name is visibly redacted; the management page is filtered to a real disposable test container, removed after capture. Hardware and container values are not simulated. Screenshots do not certify the downloadable DMG or complete acceptance. [Capture provenance](docs/MEDIA.md).

## GitHub distribution

The repository contains source, localized resources, build scripts and tests. Downloadable DMGs belong in GitHub Releases, not Git history. Version 0.1.2 should be marked **pre-release** because clean-install/upgrade and final interactive UI acceptance are still pending. Publishing on GitHub does not imply Apple endorsement or notarization.

For a GitHub preview release, run `bash scripts/test.sh` and `bash scripts/package.sh`, then attach the resulting DMG, matching source ZIP, manifest and SHA-256 checksums to the corresponding source tag. No Apple Developer account or signing secret is required for this preview workflow. See `RELEASE_NOTES.md` for the release description.

Every package now includes a matching source ZIP, a source-commit manifest and SHA-256 checksums. Packaging requires a clean Git checkout and refuses source changes made during the build. Upload the complete set together; keep the release tag on the manifest's source commit. The source ZIP includes Apache-2.0 licensing, sources, resources, build scripts and tests; it excludes Git internals and ignored build output.

| Distribution | App | Matching source |
| --- | --- | --- |
| Developer preview | `Container-Desk-VERSION-arm64-preview.dmg` | `Container-Desk-VERSION-preview-source.zip` |
| Signed/notarized release pipeline | `Container-Desk-VERSION-arm64.dmg` | `Container-Desk-VERSION-source.zip` |

The signed pipeline is prepared but has not produced a release: Developer ID credentials are unavailable, and the acceptance gates are incomplete. A filename or successful package build alone does not make a version stable. Existing 0.1.2 release assets remain unchanged; this paired-artifact workflow applies to newly built packages.

## License

Container Desk is licensed under [Apache-2.0](LICENSE). Apple Container is a separate dependency with its own license; its official installer is downloaded when needed and is not bundled here.

## Install

Open `Container-Desk-0.1.2-arm64-preview.dmg` and drag **Container Desk.app** to **Applications**. This development build is ad hoc signed, without a Developer ID certificate or Apple notarization. This preview can be shared through GitHub Releases without joining Apple Developer Program. GitHub hosting does not change macOS Gatekeeper checks: macOS may prevent this preview from opening after download. Developer ID signing and notarization are an optional future distribution improvement.

The app connects to an existing engine when available. Otherwise open **Container Engine**, check the official release, and choose **Install Apple Container**. macOS performs administrator authorization; the app does not collect an administrator password. The first installation also lets Apple's CLI download its recommended Linux guest kernel from the Kata Containers project. The official engine package is not bundled in this DMG.

## Changes in 0.1.2

- Added explicit migration of the recognized per-user installation to the **same** official release under `/usr/local`, retaining original files and the default user data directory. This requires an idle engine, no existing `/usr/local` installation, Apple-signed source executable, and a matching tested version. Arbitrary custom layouts remain unsupported. Terminal PATH is not changed.
- Installation sequencing now has a separately tested workflow: verify download before stopping, recheck workloads before mutation, recover service on failure, never report failed validation as success. This is service recovery, not binary/data rollback.
- Handle stopped-engine status, reject downgrades, distinguish canceled administrator authorization, and avoid terminating an authorized installer while it is writing files.
- Added `scripts/release.sh`: Developer ID signing, hardened runtime, timestamp, notarization, stapling and mounted-app Gatekeeper assessment. `--check` verifies local prerequisites without uploading. The optional signed/notarized distribution remains unavailable without signing credentials; GitHub preview releases are not blocked.
- Retained 0.1.1 controls: CPU dropdown, synchronized memory slider/integer field and downloaded-image dropdown. No demo mode.

## Acceptance evidence

29 core checks, 13 isolated installer sequencing/recovery scenarios and 179 three-language entries passed. Real Store.create produced a stopped container with the selected local image, 2 CPUs and 768 MiB, then removed the temporary container. Full create/start/logs/stats/stop/delete smoke passed. Real official-release preflight recognized this host's migration and refused it while a workload runs. All 8 existing workload states were preserved.

The official signed package was expanded into the workspace without installation; its CLI hash matches the currently installed custom-layout CLI, the CLI's Apple designated signature verifies, and the extracted CLI reports 1.5.0. This is payload verification, not proof of a clean installation or real migration.

## Included

Current source adds a container file browser with non-overwriting transfers, Registry login/logout and image push, and reviewed Compose project import/start/stop/removal. Compose supports a documented subset with dependency readiness, named-volume retention and managed service-name mappings. Unsupported fields are rejected. [Usage and compatibility](docs/COMPOSE_AND_FILES.md). These features are not included in the existing download.

Current source adds image pull/build/tag/delete and OCI archive import/export, network/volume creation and protected deletion, container restart, inspect JSON and an external Terminal action. Creation now offers network/volume selection and advanced command settings. Long operations show live output and can continue in the background or be cancelled. The memory-slider layout hang has been fixed. See the [feature status and remaining baseline](docs/FEATURE_ROADMAP.md). These changes are **not included in the existing `v0.1.2-preview` assets**.

Current source also adds reviewed multi-selection lifecycle actions, multiple TCP/UDP port and bind/volume mappings, and searchable log snapshots with application/boot selection, copy and export. Batch failures are reported per container; changed or ineligible states are refused. These additions are not in the existing download.

Navigation and Info/Logs tabs use brief fades; opening details and changing zoom use smooth, interruptible transitions. Custom motion follows macOS Reduce Motion, and periodic metrics/log updates do not trigger animations. These source changes are not in the existing `v0.1.2-preview` download.

The current source supports content zoom from 80% to 150%: **⌘+** (also **⌘=**) zooms in, **⌘−** zooms out, and **⌘0** resets to 100%. Use the View menu or the percentage menu at the bottom right. The app remembers the selected scale; narrow windows allow horizontal scrolling. The native sidebar, toolbar and dialogs keep their standard size. This addition is not in the existing `v0.1.2-preview` download.

The expanded detail view in current source includes live CPU/memory/process/network summaries, per-container CPU and memory charts (latest 120 actual samples in this app session), grouped connection/configuration/mount details, and a full-width log viewer. Missing samples remain unavailable; network values are cumulative traffic, not bandwidth. This dashboard is not in the existing `v0.1.2-preview` download.

In current source, double-click a container row (or choose Expand Container Details from its context menu) to show its information and logs across the window content area. Back to Containers or Esc restores the list, selection and previous sidebar visibility. This addition is not in the existing `v0.1.2-preview` download.

Current source adds clickable TCP port mappings in the container inspector, opening the published host address in the default browser, plus a Copy URL context action. HTTP is the default; container port 443 uses HTTPS. Wildcard bind addresses open through loopback; UDP mappings stay as text. The service must actually serve HTTP/HTTPS. This addition is not in the existing `v0.1.2-preview` download.

- Native sidebar, container table, inspector, searchable status filters, grouped forms, toolbar and system appearance.
- Actual local container status, create/start/stop/delete, logs, CPU delta samples and memory usage. Published ports default to loopback. New containers start stopped.
- Actual Mac specifications: model, chip, CPU cores, physical memory, macOS/build, architecture and home volume capacity/free space. Unknown values remain unavailable. No hardware serial number or UUID is retained.
- Images, networks and volumes: searchable management with configuration inspection and reference checks before deletion (current source).
- English base, Simplified Chinese and Traditional Chinese, with immediate app-content language switching. System-owned menus follow macOS settings.
- All displayed container and host data is live; demo mode and sample data have been removed.
- Official stable release checks. Signed package URL, size, SHA-256 digest, Apple Containerization installer identity and macOS package assessment are checked before installation.
- Manual updates and opt-in automatic updates while the app is open; automatic checking defaults on, installation defaults off. Installs require a tested release and no running containers; system authorization still applies.

## Preview limits

Only Container **1.5.0** is currently marked compatible. Newer releases are displayed but installation is deferred until tested; automatic mode does not imply unconditional future-version support. Custom files are not overwritten. The recognized `~/.local/bin/container` wrapper can explicitly migrate to the same official version when idle; the original installation is preserved. Other custom layouts still use their original installation method. There is no privileged background helper, closed-app scheduler, remote host management, embedded terminal, full resource editor, skip-version preference or separate guest-kernel updater yet.

Current-source validation: 48 core checks, 35 management checks, 34 workflow checks, 13 simulated installer scenarios and 425 three-language keys passed. Real resource creation/deletion protection, container restart with volume persistence, image build/pull/archive round trip, and native image-tag/creation flows passed; the original 8 container states were preserved. UI-001 was traced to macOS 26 discrete-slider marks and fixed; native layout checks cover 16 GiB and 1 TiB host ranges. Full form/accessibility/multi-size and second-Mac acceptance remain pending. Clean engine installation and genuine upgrade are still **not** verified end to end. Existing release assets retain their earlier limitations; see the [test report](docs/TEST_REPORT.md).

## Build and test

Builds now use Swift Package Manager with pinned Yams 6.2.2; the first build downloads this dependency. Its required license notices are bundled in the app and [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

Install Apple's Xcode 26 or Command Line Tools 26 with a macOS 26 SDK, plus Python 3. There are no third-party Swift package dependencies.

```sh
bash scripts/test.sh
bash scripts/build.sh
bash scripts/package.sh
```

The app bundle is written to `../work/build/Container Desk.app`; DMG to `../outputs`. `Package.swift` supports source browsing in Xcode, but use the build script for the complete `.app` with Info.plist and localized resources. `Resources/Localizable.xcstrings` is generated from `scripts/make_catalog.py`; the bundler converts its translations into `.strings` resources. Regenerate it after changing localization entries.

To rerun the opt-in integration smoke test, compile `Sources/Models.swift`, `Sources/ProcessRunner.swift`, and `Tests/IntegrationSmoke.swift` together, then pass the CLI path and an **existing local image with `/bin/sh`**. This creates and removes only a UUID-named test container.

For an optional Developer ID signed and notarized release, set `SIGNING_IDENTITY` to an installed Developer ID Application identity and `NOTARY_PROFILE` to an existing notarytool Keychain profile, then run `bash scripts/release.sh`. Do not put passwords, private keys or API secrets in source files. The script only reports success after notarization acceptance, stapling, DMG verification and Gatekeeper assessment. Complete the pending clean-install, update, accessibility and visual acceptance checks before distributing.

## Reference

- [Apple Container](https://github.com/apple/container)
