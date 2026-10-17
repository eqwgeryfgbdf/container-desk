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
