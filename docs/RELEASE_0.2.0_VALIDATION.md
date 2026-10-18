# Container Desk 0.2.0 — validation and release scope

Release channel: regular public release, as explicitly requested by the owner on 2026-10-18. Version 0.2.0, build 5. This is an independent application. **Ad hoc signed, without Developer ID or Apple notarization.** A regular GitHub Release does not imply notarization or complete platform certification.

**Tests ran only on the developer’s own Mac. Second-Mac testing was explicitly deferred.**

**僅在開發者自己的設備上測試，第二台 Mac 測試暫不執行。** 本次正式公開並不代表所有設備、乾淨安裝或真實升級皆通過驗證。

**仅在开发者自己的设备上测试，第二台 Mac 测试暂不执行。** 本次正式公开并不代表所有设备、全新安装或真实升级均已验证。

## Environment and identity

- M4 Mac mini, 16 GiB, 10 physical/logical cores; macOS 26.7.1, arm64.
- Apple Container CLI 1.5.0. Docker Compose resolution used the already-installed Docker tooling; existing Docker workloads were retained.
- SDK/runtime minimum is macOS 26.0; direct host evidence is macOS 26.7.1 only. Other macOS 26 releases are not individually certified.
- Candidate runtime source accompanies this document. The release tag, DMG/source manifest and Quick Start `BUILD.json` identify the exact published commit/tree. Documentation changes after runtime tests do not alter the tested executable source.

## Automated evidence

`python3 scripts/qa.py --live --report-dir ../work/qa/0.2.0-final` completed with **23 PASS, 0 FAIL, 6 explicit SKIP** entries. These are suite/setup/cleanup entries, not a claim of 100% code coverage. Native UI was omitted from this serial backend run and is recorded separately. The other skips are clean installation, genuine engine upgrade, external private HTTPS registry success, manual accessibility and deferred AI.

Passing coverage includes:

- 51 core/policy/process assertions, 35 management checks, 34 workflow checks, 13 simulated installer scenarios, 16 platform suites, convenience planning tests and **583 translation keys in all three languages**.
- Real stopped creation/readback; lifecycle/batch operations; CPU/memory, multiple ports/mounts, log access, file persistence, refusal of in-use deletion and unchanged unrelated inventories.
- Clone source identity, command/environment and mount policy; actual clone start/readback and source preservation.
- File transfer/rename/mkdir/delete, project health/dependency startup, service-name mapping, stop/restart/removal with retained data; converted and officially resolved Compose projects.
- Registry authentication failure and loopback push paths; snapshots, search, actual architecture selection, build and OCI archive round trip.
- Exact before/after container/image/network/volume inventory preservation. Test-owned fixtures were cleaned up; no blanket prune.

An earlier candidate run had 23 PASS / 1 FAIL: native UI could not inspect the locked desktop. That result was retained, not relabelled as success. The runner now reports a clear locked-screen prerequisite; later unlocked UI testing is separate evidence.

## Native UI and quick-start evidence

- The unlocked native language/appearance matrix passed **170 steps**: three languages × two themes × two sizes. Creation controls and cancellation remained reachable; all 12 creation-sheet captures were reviewed for obvious clipping. Actual minimum window height is 692 points (640-point content plus native chrome).
- A separate 30-navigation run passed; maximum observed title/navigation response was **0.63 seconds** on this host. This measures app navigation acknowledgement, not every possible operation or network request.
- The recorded workflow passed **68 steps**, including selection/filtering, expanded details, zoom, logs/files, clone review, disk-usage review and download-to-configuration. Creation and destructive cleanup are not performed by the promotional video.
- Native creation additionally verified every host CPU option (1–10), memory values 199/200/768/16384/16385/blank/nonnumeric, disabled invalid submission, then created a stopped 10-CPU/768-MiB fixture and read back exact settings through the CLI. The fixture and newly downloaded image were cleaned up.
- `bash scripts/quick-test.sh --check` and `--run` passed: loopback HTTP, exec/log access, stop/start file persistence and cleanup of only the generated fixture and image.
- Earlier automation attempts exposed locked-screen, localized sidebar-name and macOS recording-overlay-window assumptions in the test runner. Those runner defects were fixed; subsequent completed runs above are the reported evidence.

## Final stability and artifact evidence

The completed 60-minute observation and final artifact checks are recorded in the release attachment [Container-Desk-0.2.0-Validation.json](https://github.com/eqwgeryfgbdf/container-desk/releases/download/v0.2.0/Container-Desk-0.2.0-Validation.json), alongside the matching source commit/tree and checksums. This keeps the source immutable while testing and packaging finish. A missing report is not a pass.

The same app process is observed every five seconds for 60 minutes. The session includes native UI matrix, creation and recording activity, followed by idle observation; it is not a constant-load or purely idle benchmark. After the five-minute warmup, the target is median CPU below 5% of one core and final-five-minute median RSS no more than 100 MiB above the initial five-minute steady window. Navigation timing is measured separately. Raw local logs are not uploaded because they can contain host-specific information; the public report contains summary results and evidence hashes.

The final promotional clip is 67.3 seconds at 1280×800, recorded from the same 0.2.0 runtime. Captions and privacy masks were added to real footage; the recording workflow passed 68 steps. Frame sampling and a host-name OCR check supplement visual media review.

## Security remediation

A fresh repository scan confirmed three medium-severity findings and no high/critical finding in its covered scope. All three were repaired before this release:

1. Compose guest arguments resembling host flags could be misinterpreted and cause out-of-bounds crashes. Consumers now use typed configuration metadata instead of rescanning argv.
2. Environment expansion could allocate unbounded memory. UTF-8 limits are checked before appending: 512 KiB per value and 2 MiB cumulative processed project values, with bounded env-file reads. Oversized projects fail with a property-specific diagnostic.
3. Single-label registry names selected from catalogs could become Docker Hub namespaces during deployment. Catalog references now retain the selected HTTPS authority using an explicit `:443` when needed.

Regression tests exercise the original triggers and alternative forms, ordinary command/Compose behavior, Unicode expansion, aggregate budgets and registry host/path/tag variants. A fresh independent patch reviewer found no concrete surviving bypass or regression in the three scoped fixes. This is a bounded source review and test result, not a guarantee that no vulnerabilities exist.

## Remaining limits

- No clean-machine install, downloaded-DMG Gatekeeper acceptance, genuine old-to-new engine upgrade or installation-layout migration was performed. Existing host data was not removed/downgraded to manufacture a test environment. Installer simulations are labelled separately.
- No external authenticated private HTTPS registry account was supplied. Local registry paths and catalog validation are tested; provider-specific successful authentication is not certified. Catalog Basic credentials are transient; CLI credentials are separate. Use the same explicit authority, including `:443`, for login and pull.
- Manual VoiceOver reading quality, all assistive-technology combinations and subjective contrast acceptance are not complete. AX/keyboard automation does not replace them.
- Docker conversion supports a documented subset. Automatic volume/local-image migration, continuous restart supervision and verified cutover/rollback are not implemented. Do not claim every Docker project migrates unchanged.
- AI model integration is deferred; no model is installed by this release's tests. No remote-host manager, embedded terminal, closed-app updater or separate guest-kernel updater.

The earlier [release acceptance target](PUBLIC_RELEASE_GATE.md) remains historical reference. The owner explicitly authorized public distribution with the disclosed scope; unperformed gates remain unverified. Release publication is checked separately against GitHub visibility, prerelease/draft flags, tag identity and asset digests.
