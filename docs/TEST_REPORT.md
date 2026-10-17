# Candidate test report / 測試結果表

Decision: **NOT READY**

Copy this template for each release candidate. Use PASS / FAIL / PENDING / BLOCKED. Never fill PASS without a matching observation and evidence file/link. Do not upload credentials, serial numbers, private workloads or unredacted logs.

## Candidate identity

| Field | Value |
| --- | --- |
| Source commit | Pending |
| App version/build | Pending |
| GitHub release URL | Pending |
| DMG SHA-256 | Pending |
| Mac model/chip/RAM | Pending |
| macOS version/build | Pending |
| Engine before → after | Pending |
| Clean install / upgrade / migration baseline | Pending |
| Tester and test date | Pending |
| Restore procedure verified | Pending |

## Results

| Gate | Status | Actual result / evidence | Defect / follow-up |
| --- | --- | --- | --- |
| G01 Build/artifact | PENDING | | |
| G02 Download/launch | PENDING | | |
| G03 Clean install | PENDING | | |
| G04 Host information | PENDING | | |
| G05 Creation controls | PENDING | | |
| G06 Lifecycle/data | PENDING | | |
| G07 Updates | PENDING | | |
| G08 Migration | PENDING | | |
| G09 Failure/recovery | PENDING | | |
| G10 Languages/visual | PENDING | | |
| G11 Accessibility | PENDING | | |
| G12 Stability | PENDING | | |
| G13 README/media | PENDING | | |
| G14 Public handoff | PENDING | | |

## Defects

| ID | Severity | Steps to reproduce | Expected / actual | Fix commit | Retest evidence |
| --- | --- | --- | --- | --- | --- |
| UI-001 | Major | In 0.1.2 QA, open Create Container; large host memory creates thousands of slider step marks. | Root cause confirmed in SliderMarkLabels layout. Current source removes discrete slider steps and rounds the binding to whole MiB; native 16 GiB/1 TiB layout and actual UI creation passed. Existing release binary remains affected. | Fixed in current source; candidate/second-Mac retest pending | 2026-10-17 management validation below |

## Decision record

- Required gates passed: 0/14 (this blank template is not an executed report).
- Open critical / major / minor defects: not yet assessed.
- Evidence reviewed by / date: pending.
- Decision: NOT READY. Keep private.
- GitHub visibility change result, if later eligible: not performed.


## 2026-10-17 — management baseline, current source only

Environment: Apple M4 Mac mini, 16 GiB, macOS 26.7.1, Apple Container 1.5.0. Development build only; GitHub `v0.1.2-preview` assets were not replaced. The repository must remain private.

- `bash scripts/test.sh`: PASS, 48 core + 35 management + 13 simulated installer checks; 262 localization keys complete in all three languages.
- `bash scripts/test-management-live.sh --run`: PASS, disposable network/volume creation and readback, image tag, stopped container creation, built-in and in-use deletion refusal (including stopped-container references), volume mount, start/exec/restart with data persistence, inspect, stop, delete and cleanup.
- A real-engine mismatch found during testing was fixed: volume mounts use `type.volume.name` and a disk-image source path, rather than always placing the volume name in `source`. Both representations and matching source paths are now protected.
- `bash scripts/test-images-live.sh --run`: PASS, tiny `FROM scratch`/COPY build, OCI export/delete/import round trip, arm64 BusyBox pull and image cleanup. The existing idle builder was temporarily started by the test and restored to stopped. The original eight container IDs/states were unchanged after both live suites.
- `bash scripts/test-creation-ui.sh`: PASS, isolated native NSHostingView layouts for 16 GiB and 1 TiB capacities in approximately 0.38 and 0.37 seconds. No engine calls or host-preference changes in this test.
- UI-001 root cause: sampled main-thread stacks consistently stayed in `SliderMarkLabels.LabelLayout.LabelLayoutResolver`. Removing `step: 1` avoids thousands of macOS 26 slider marks; the binding still rounds to integer MiB. The creation sheet now uses explicit scroll content and visible footer actions.
- Native UI: invalid pull name rejected with localized text; Escape dismisses the editor; tagging produced the actual new image and the progress sheet reported success; selecting a local image and creating through the UI produced a stopped container whose CLI readback matched that image, 2 CPUs and 512 MiB. Test resources were removed; original eight container states remained unchanged.
- Native AX tree enumeration on the memory-slider sheet can still terminate the computer-use helper. The application itself remained idle/responsive and native keyboard create/cancel succeeded. This is not a VoiceOver acceptance pass; full accessibility testing remains pending.
- Resource work and engine installation are mutually exclusive. Metrics refresh can continue during resource jobs. Cancellation stops the CLI client and explicitly requires state reconciliation; it does not promise rollback of work already accepted by the engine.
- Remaining validation: interactive Terminal session, full three-language/size/contrast matrix, real authorization/cancel/retry for clean engine install/upgrade, second-Mac package launch, long-duration stability. Baseline B and AI remain tracked in [FEATURE_ROADMAP.md](FEATURE_ROADMAP.md).

## 2026-10-17 — multi-selection, multiple mappings and log tools

Source-only increment; existing `v0.1.2-preview` release files are unchanged.

- `bash scripts/test.sh`: 48 core checks, 35 management checks, **34 new workflow checks**, 13 simulated installer scenarios and **288 keys in all three languages** passed. Workflow checks cover numeric port collisions, TCP/UDP sharing, literal paths, normalized duplicate mount destinations, incomplete rows, stale/missing/ineligible batch targets, state readback and case-insensitive log filtering.
- `bash scripts/build.sh`: macOS 26 arm64 optimized build and ad hoc signature verification passed. The installed `/Applications/Container Desk.app` executable was verified identical to this build by SHA-256 after installation. Previous app preserved in the local work backup directory.
- `bash scripts/test-creation-ui.sh`: bounded native creation layout passed for 16 GiB and 1 TiB host ranges (0.418 s / 0.358 s in this run). This isolated layout test does not certify every dynamic form row.
- `bash scripts/test-workflows-live.sh --run`: created two uniquely named disposable containers using an existing arm64 Python image and a disposable 1 GiB volume. Verified three published-port mappings (two TCP HTTP endpoints actually responded; UDP was verified as configuration, not packet delivery), three mounts including a named volume, a writable bind and an enforced read-only bind, and application log filtering.
- The live batch test inserted a missing target between two valid start targets and confirmed the latter still started. An externally stopped target was rejected by a previously reviewed restart request while the remaining target restarted. Running deletion was refused. Batch stop/delete were read back; all test resources were removed and all **8 pre-existing container states remained unchanged**.
- Native UI: Command-A selected 8 containers; the batch stop review listed exactly those 8 and marked the 7 stopped targets as skipped. Escape dismissed it without executing a command. Single-selection inspector returned normally.
- Native logs UI: an unmatched query displayed the empty-result state and disabled copy/export; a lowercase query matched an uppercase log line. The native save panel successfully exported the filtered snapshot to the local work directory; CLI readback matched the displayed text byte for byte. No log export or private host screenshot was added to Git.
- Interactive acceptance still pending: dynamic extra-row entry/removal across all window sizes and VoiceOver; batch execution/cancellation initiated from the UI (executor tested against the engine); boot-log source and larger line limits; interactive Terminal; clean install, real upgrade and the user's second Mac. No claim of full feature parity or public-release readiness.

## 2026-10-17 — files, Registry and Compose adapter

Current source only, on Apple Container 1.5.0 / macOS 26.7.1 / M4 Mac mini. The existing `v0.1.2-preview` release assets remain unchanged and the repository remains private.

- Automated checks: 48 core, 35 management, 34 workflow, 13 simulated installer scenarios, 425 keys in English/Simplified Chinese/Traditional Chinese, and 9 platform suites. Platform coverage includes unsupported Compose fields and YAML alias/duplicate/cycle rejection, literal environment/arguments, network-scoped service-name maps, stable host-file inode updates, refusal to follow a host-file symlink, corrupt project-library preservation, credential stdin/output handling, tar traversal/symlink extraction refusal and transfer subprocess cancellation.
- Engine compatibility findings: Apple Container's custom-network DNS did not resolve a bare Compose service name in the initial integration test. The adapter now uses private per-project host files mounted read-only, refreshed with current same-network owned peers after project starts. A live bind-mount probe verified in-place updates remain visible. No host DNS, global engine settings or existing workload was changed.
- Another live probe showed `container copy` returning success for a named-volume path while the file was absent from the container's mounted volume. Transfers now use binary tar streams through `exec` in the container's actual mount namespace. No TTY or text decoding touches the archive. Native BSD tar extraction keeps its default path/symlink protections and uses safe writes. Archives are bounded to 4 GiB; interrupted remote uploads can leave a reported staging directory.
- Registry push: an empty generated OCI image was imported and pushed to an isolated loopback Distribution registry. Both the remote index and child manifest were read back over HTTP. The new tags, test image and registry container were deleted; the registry image was removed only when downloaded by the test. Original container states were unchanged.
- Registry credential failure: an HTTPS attempt against a disposable HTTP fixture fails without changing saved CLI accounts. This validates a secure transport-failure path, **not** successful private-registry authentication. No real user password or token was used. Successful trusted-registry login/logout and authenticated pull/push remain pending an account supplied through a secure flow.
- Full feature/UI, VoiceOver, clean install/upgrade and second-Mac acceptance remain open. There is no claim of complete Docker Compose compatibility, continuous restart supervision or public-release readiness. See [the support matrix](COMPOSE_AND_FILES.md).
- End-to-end Compose/files run passed: two disposable services started in dependency/health order and a web request to `http://db:8000` succeeded from the other service. Binary file and nested-directory/empty-directory uploads and downloads through a named volume matched their originals. Existing destination refusal, rename, mkdir and empty-directory/file deletion passed. Project stop/restart/removal/recreate retained volume data; a changed CPU/memory configuration was refused. Test containers, volume, network and host-map directory were removed, and all **8 original container states were preserved**.
- Release-mode arm64 build and strict ad hoc signature verification passed. `/Applications/Container Desk.app` was updated after saving the previous app; the installed executable matched the build by SHA-256 (`dfd8887cde370d0eb86cb9b5d7c7b2a74d808033f73b572e8fad3540be802509`). Bundled third-party notices matched the source file. This is a development build, not a new notarized/public release.
- Native Traditional Chinese UI: Registry empty-account state and SecureField rendered; submitting empty values produced localized validation and Escape dismissed the sheet. Compose imported the included YAML through the native file picker, showed service/resource/port/mount/startup details and a review confirmation; cancel left it uncreated, and the test-only library record was removed. The file browser read the running container's real root listing, distinguishing directories and symlinks; no workload file was modified by this UI check. Full interactive transfer/VoiceOver/multi-size acceptance remains pending despite executor integration coverage.

## 2026-10-17 — reviewed Docker project conversion

- Added Compose/Dockerfile/folder analysis, compatibility messages, generated YAML preview, explicit manual-restart opt-in and a separate Save & Import step. Conversion shares the existing strict YAML/planner validation; it does not execute Docker or change original files.
- Automated checks passed: 48 core, 35 management, 34 workflow, 13 simulated installer scenarios, 459 three-language catalog keys and 10 platform suites. Migration fixtures cover unique mode-0600 output, original/env/bind preservation, source-change refusal, default-driver removal, restart consent, invalid port metadata/protocols, unsupported options, ambiguous files, override handling and Dockerfile wrapper architecture checks.
- `bash scripts/test-platform.sh --convert-run` passed against Apple Container 1.5.0. A disposable two-service Docker-style configuration was converted, then actually started in dependency/health order. Service-name HTTP access, binary and nested-directory transfer, no-overwrite refusal, project stop/restart/removal/recreate, retained volume data and changed-configuration refusal passed. Only test-owned resources were cleaned up. All **8 original container states remained unchanged**.
- Native Traditional Chinese UI passed: selected the isolated Compose fixture through NSOpenPanel, observed automatic-restart blocking and disabled Save, enabled manual management, reviewed readable scrollable notices, checked review consent, then saved/imported. The Compose page showed the separate file, loopback port and **Not Created** service; no pull/build/start occurred. Original source and output permissions were read back through CLI. The test-only library record was removed afterward.
- Release-configuration compilation and ad hoc signature verification passed. Installed `/Applications/Container Desk.app` matches the built executable (SHA-256 `4b740f3c36d3b54bd7a367df6bd6aa26e1d5f030ef73afca59a7211d098cd80e`). The previous app was backed up locally. This is a development build, not a notarized stable release. Existing GitHub DMG assets remain unchanged.
- Limits: arbitrary third-party Docker projects, data migration/cutover, successful Dockerfile builds through this wrapper, other-language interactive/VoiceOver/multi-size checks and second-Mac acceptance are not certified by this fixture. See [conversion scope](DOCKER_CONVERSION.md).

## 2026-10-17 — official Compose resolution and registry quick deployment

- Installed Docker Compose **5.1.2** now resolves a selected base file and ordered overrides before conversion. Tested YAML anchors/templates, adjacent `.env`, resolved `env_file`, build args/target and default metadata normalization. Source environment is deliberately limited to project env files. Missing-variable warnings are refused; CLI diagnostics are suppressed because they may contain resolved secrets. Save reruns resolution and refuses changed inputs. Mode-0600 snapshots preserve literal `$` and `$$` correctly and do not reinterpret later `.env` changes.
- Added multiple networks (up to 8 declared attachments), network-scoped aliases, `init` and explicit labels, plus build args/target/no-cache/pull. Reserved labels and conflicting/reserved aliases are rejected. The runtime still uses managed host files; continuous service discovery and restart supervision are not implemented.
- Full checks passed: 48 core, 35 management, 34 workflow, 13 simulated installer scenarios, 483 three-language catalog keys and 11 platform suites. The additional official-CLI fixture passed merged overrides, env-file resolution, literal-dollar preservation, changed-input refusal and host-env isolation.
- `bash scripts/test-platform.sh --resolved-run` passed. The merged two-service project attached a service to two networks; an HTTP request using its peer's `database` alias succeeded. File round trips, no-overwrite behavior, stop/restart/remove/recreate, retained data, changed-config rejection and cleanup passed. The fixture's configuration-change step now edits the YAML node rather than assuming Docker preserves a human-readable memory unit. All **8 original Apple container states**, all existing Docker container states and original Apple image references were verified unchanged after cleanup.
- Native Traditional Chinese **Images → Quick Deploy…** accepted a Docker Hub BusyBox repository URL with tag `1.37`, downloaded it, verified Linux arm64 and displayed Ready to Configure. The actual image was read back through CLI; no container was created. The new test image was removed. The native automation connection failed while moving to Configure Container, so the final sheet handoff and new resolver controls remain pending interactive acceptance; the app process continued running. The app was restarted afterward to clear test UI state.
- Production-configuration build and ad hoc signature verification passed. Installed executable SHA-256: `415da6ef92e1f80e7609eb6e1b5cc726b8d2878da3ae05cd0836591a3481c413`. Previous app backed up locally; existing GitHub DMG assets remain unchanged.
- This is **not complete painless migration**: application-consistent volume migration, Docker local-image bridging, restart supervision, cutover/rollback, repository URL/template browsing and second-Mac acceptance remain open. The requirements are explicitly tracked in [migration acceptance](MIGRATION_ACCEPTANCE.md).

## 2026-10-17 — Docker Hub image search

- Added public keyword search and repository/version pagination to Quick Deploy; results show repository descriptions, Docker Official Image badges, pulls and stars. Linux ARM64 metadata guides tag selection; manual image/URL entry remains available.
- `bash scripts/test.sh`: 48 core, 13 simulated installer, 35 management, 34 workflow checks and 12 platform suites passed; all 507 localization keys are complete in English, Simplified Chinese and Traditional Chinese.
- New deterministic tests cover query encoding, input/path rejection, official-image normalization, 64-bit pull counts, missing/incompatible architecture metadata, empty results, HTTP 429/503, malformed/oversized responses and cancellation.
- `bash scripts/test-platform.sh --hub-search --hub-download`: live Docker Hub search and repository/tag pagination passed. Selected a real official BusyBox ARM64 tag through search and downloaded/verified it via `Store.prepareDeployment`. Removed only the test's new image reference. Original image references and all container states matched afterward; no containers were created or started.
- Build note: a first release build detected a concurrent whitespace-only source formatting edit and refused to finish. The final build was restarted after source edits stopped.
- Existing GitHub Release DMG/source assets are unchanged. This increment does not certify clean-machine installation, full Docker migration, or public-release readiness.
- Native Traditional Chinese UI: keyword `busybox` returned results with official badge/pull counts; selecting the official repository loaded version tags and selected `latest · Linux ARM64`. Use Image populated `docker.io/library/busybox:latest`; Download and Verify completed and displayed Ready to Configure. Clicking Configure Container again disconnected the native automation pipe before it returned a view. The app process remained alive with no ContainerDesk crash report found; final configuration-sheet handoff remains unverified. No container was created. The UI test's new BusyBox reference was removed via CLI.

## 2026-10-17 — unified download/deployment and platform selection

- Replaced separate Download Image and Quick Deploy toolbar buttons with Download & Deploy. The common flow supports search or direct references, Download Only and Download & Configure. Configuration now remains in the same sheet, retaining selected image and architecture.
- Version details show OS/architecture/variant metadata, omit unknown attestation entries, prefer ARM64 and offer AMD64/Rosetta. Runtime availability is read from Virtualization.framework; unavailable Rosetta blocks AMD64 configuration in this flow while preserving download-only access. There is no binary architecture conversion or automatic Rosetta installation.
- Downloads explicitly request the selected Linux platform and verify its actual config. An existing reference with only the other architecture triggers a download instead of a false cached success. Container creation rechecks the local architecture.
- `bash scripts/test-platform.sh --hub-search --architecture-deploy` passed: public search, ARM64 and AMD64 download for the same reference, selected AMD64/Rosetta carried into a real stopped container, start/attach returned `x86_64`, test container/image removed, original container states and image references preserved.
- `bash scripts/test.sh` passed all existing checks and 12 platform suites; 525 localization keys are complete in three languages. Added coverage for platform lists, missing metadata, unsupported OS, architecture propagation and actual config versus advertised platform.
- Compose empty state now fills the available content area and centers its icon/message below the page controls; the page expands with its viewport.
- Native UI verified the single Download & Deploy toolbar entry, full BusyBox platform list, ARM64 default, AMD64 selection and actual installed-Rosetta status. Download & Configure completed its download, but entering CreateView still disconnected the native automation pipe; the app process remained alive. Screenshot retrieval also failed through that pipe, so final configuration-page visual acceptance remains pending despite the backend AMD64 creation/execution pass. The temporary UI image reference was deleted and the app reopened.
- Compose empty state was visually verified centered in the remaining main-content area at normal (1335 × 692) and zoomed (1920 × 1004) window sizes; the window was returned to its original size.

## 2026-10-17 — Projects naming, sidebar order and container snapshots

- Renamed the navigation/page title to Projects in all three languages; Compose remains the configuration format and import command name.
- Sidebar order uses stable IDs in user preferences, supports drag/drop and offers Move Up/Down and Restore Default Order in the context menu. Invalid/duplicate saved IDs are repaired and newly introduced destinations are retained.
- Container actions now provide Save Container as Image. The official filesystem export is packaged into a single-layer OCI image, preserving changed/deleted files and startup executable/arguments, working directory, user and architecture. Mounted storage and runtime configuration are excluded; environment values are opt-in. Pushing is a separate explicit action after local success.
- Unit coverage checks snapshot metadata, omitted/included environment, unsupported states/user encodings and sidebar preference normalization. Full checks passed with 13 platform suites and 546 complete localization keys.
- `bash scripts/test-platform.sh --snapshot` final run passed: running and stopped snapshots; restored clone executed with added/deleted files preserved; bind-mounted test content absent; environment omitted by default and included only when requested; existing local tags rejected; real OCI push to a disposable loopback Distribution registry verified by manifest readback; all test images/containers cleaned and original image references/container states preserved.
- The first push fixture encountered resourceInUse during cleanup because its restored clone still referenced the snapshot digest. The test now removes its own restored clone before testing push cleanup; final run passed. Production protection was retained and original containers were not restarted or modified.

- Native Traditional Chinese UI passed: dragging the Projects label from seventh to first changed the order; quitting and reopening retained it; right-click Restore Default Order restored the original order. Sidebar selection was explicitly verified after removing competing native move handling. Drag from the label/icon; blank trailing row space did not initiate dragging in automation. Projects remained centered in the main area.
- The Save Container as Image sheet was opened read-only for an existing stopped container: environment inclusion and filesystem acknowledgement defaulted off, Save was disabled until acknowledgement, and Cancel left the source unchanged. Live snapshot/push execution used only the disposable fixture above.
- Final release-configuration build and strict ad hoc signature verification passed; the app was installed locally. Existing GitHub Release DMG/source assets are unchanged. The unified deployment configuration-page automation limitation documented above remains open; this is not a public-release certification.
