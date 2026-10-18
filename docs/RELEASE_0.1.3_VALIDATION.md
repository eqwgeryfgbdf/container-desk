# 0.1.3 preview — validation record

Date: 2026-10-18 (Asia/Taipei). Host: Apple Silicon M4, macOS 26.7.1, Apple Container 1.5.0. This is a developer preview, not a public/stable acceptance certificate.

## Scope

The release incorporates the existing management and security-hardening work, bumps the application version to 0.1.3 (build 4), reads the Settings version from the bundle, and adds multilingual guides and a no-compiler smoke bundle. The uploaded manifest identifies the exact source commit/tree used for the DMG and source ZIP; `BUILD.json` identifies the Quick Start bundle source. The release tag must match those commits.

## Checks repeated for this release

- `bash scripts/test.sh`: PASS — 51 core checks, 553 localization keys in three languages, 13 simulated installer cases, 35 management checks, 34 workflow checks and 14 platform suites. Installer cases simulate external operations; no engine installation/upgrade was performed.
- Debug and release compilation; ad hoc signing/strict signature verification. The package uses arm64 and macOS deployment target 26.0.
- `quick-test.sh --check`: PASS — read-only preflight with reachable supported engine.
- `quick-test.sh --run`: PASS — pulled absent BusyBox 1.37, created a unique loopback HTTP service, checked its exact response and file readback, accessed logs, stopped/restarted it, verified persistence, and removed the owned container/image.
- `--run --keep --port 18083`: PASS — retained a working fixture and printed precise cleanup instructions.
- Occupied port 18083: PASS — refused before creating another fixture.
- A second run on port 18084 with the existing image and kept container: PASS — removed only the new fixture and preserved the original image/container. The retained fixture and its originally downloaded image were then explicitly removed.
- `docs/examples/quick-web.yaml`: parsed by the application's `ComposePlanner`; one supported service, correct image, no named volumes and loopback port 18082. The exact parsed command was also run in a disposable real container; its HTTP response matched the guide. This verifies the example and command, not a second full GUI import acceptance run.

Release artifacts additionally undergo DMG integrity verification, archive/manifest consistency checks and SHA-256 generation. These packaging checks do not prove first launch on another Mac.

## Earlier full regression baseline

The preceding 0.1.2 QA build, with the then-pending fixes in its working tree, produced **17 PASS / 0 FAIL / 5 SKIP** groups, including **56 native UI steps** and real ARM64 plus AMD64/Rosetta deployment. It was not a clean 0.1.3-tagged run. The relevant fixes were subsequently committed; the repeatable suites above were rerun for this release. Do not represent the older baseline as a new full end-to-end run against the downloaded 0.1.3 DMG.

The 58.5-second video and README screenshots are from that preceding QA build. The video shows real application interaction and disposable fixtures, with identifying host details redacted. It is not installation, upgrade or registry-push evidence. See [media provenance](MEDIA.md).

## Still pending

- Second-Mac download, Gatekeeper/first launch, clean engine installation and real upgrade acceptance.
- Complete VoiceOver/contrast/layout acceptance and 60-minute soak; the earlier two-minute smoke is not sufficient.
- Successful end-to-end private HTTPS registry use with a dedicated test account.
- Manual final review of the promotional video before public marketing.
- AI model integration is intentionally deferred.

The repository remains private and the release is marked pre-release. The app has ad hoc signing, no Developer ID certificate and no Apple notarization. See [public release gates](PUBLIC_RELEASE_GATE.md), [automated QA](AUTOMATED_QA.md), and [test report template](TEST_REPORT.md).
