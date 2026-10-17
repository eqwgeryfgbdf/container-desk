# Public release acceptance / 公開驗收門檻

Status: **NOT READY — keep the repository private.**

This is the acceptance contract for the first public Container Desk preview. Passing it makes the release eligible for public visibility; it does not claim Apple endorsement, notarization, or support for untested Container versions. A later stable release needs its own completed record. No score averaging: every required gate must pass, with zero open critical or major defects. Pending, blocked, and simulated results do not count as a real-machine pass.

目前維持私人。以下必要項目必須全部通過；不能以「大部分成功」取代驗收。完成後才符合公開條件，不能因上傳成功便視為測試通過。

## Candidate and environments

- Record the exact source commit, app version/build, DMG SHA-256, macOS build, Mac chip/RAM, engine version before/after, date and tester in [TEST_REPORT.md](TEST_REPORT.md).
- Test the actual DMG downloaded from GitHub on the owner's second Apple Silicon Mac, with macOS 26 or later. A locally compiled app is not a substitute for testing that DMG's download/launch behavior.
- Use a clean, disposable or restorable environment for first installation; use a separate restorable baseline for upgrade/migration. Do not downgrade or delete working data to make a test pass.
- The minimum macOS version advertised in the README must be tested. If only a newer version is tested, narrow the supported version statement or leave this gate pending.
- Use only disposable `cd-qa-<unique-id>` containers, a dedicated temporary mount directory and a free loopback port. Record existing container IDs/statuses before and after; do not mutate unrelated workloads.
- Application changes invalidate affected results. Rebuild the candidate, repeat affected gates plus the basic lifecycle smoke test, and update the artifact hash. Documentation-only edits do not invalidate runtime results.

## Required gates

| ID | Test procedure | Pass condition and evidence | Current evidence |
| --- | --- | --- | --- |
| G01 Build and artifact | From the candidate commit run `bash scripts/test.sh` and `bash scripts/package.sh`; verify DMG with `hdiutil verify`; compare release asset SHA-256. | All automated checks exit 0; DMG opens read-only; app has the stated arm64 architecture/version/minimum OS; all published hashes match. Attach console output. | Earlier 29 core + 13 simulated workflow checks and localization validation passed; 0.1.2 release asset hashes match. Candidate report still required. |
| G02 Download and launch | On the second Mac download the GitHub DMG, drag the app to Applications, launch, quit and relaunch three times. | App launches through a documented macOS-supported flow with protections intact; no crash or missing resources. Record any Gatekeeper interaction. A blocked launch is a failed usability gate, not a pass. | Pending second Mac. |
| G03 Clean engine install | With no prior engine/data, check official release, cancel administrator authorization once, then retry and approve on the test Mac. | Cancel never reports success. Retry validates the official package, installs, configures the recommended guest kernel, starts the engine and reads the installed version. Record real CLI version/status and app result. | Package signature/digest checked; actual install pending. |
| G04 Host information | Compare Overview with macOS System Information / `system_profiler SPHardwareDataType`, `sysctl`, `sw_vers` and the same home filesystem volume. | Model/chip/physical+logical cores/RAM/OS/architecture match; disk units and volume match, allowing changing free space. Missing values show unavailable. No sample/demonstration mode. | Real host detection tested in code; second-Mac comparison pending. |
| G05 Creation controls | Open CPU menu; test memory field at 199, 200, 768, host maximum, maximum+1, blank and nonnumeric text. Drag slider then type 768. Test no images and refreshed downloaded images. | CPU options are 1…logical cores. Slider and field agree. Invalid values cannot create. Images match local CLI inventory; removed selection cannot submit. Valid creation stays stopped; CLI inspect reads back chosen image, CPU and memory. | Store/CLI readback passed; full UI matrix pending. |
| G06 Lifecycle and data | Three complete create/start/logs/stats/stop/delete cycles; on one cycle publish a free `127.0.0.1` port, use a harmless env value and a dedicated mounted file. Cancel stop/delete once each. | Correct logs/CPU/memory/status; port reachable only as configured; env and mount verified in guest; cancellation preserves the test container. No leftover test containers and no change to unrelated IDs/statuses/data. | One real lifecycle and one allocation smoke passed; full UI/data matrix pending. |
| G07 Engine updates | In a restorable environment test a genuine supported old→new upgrade manually, then repeat from restored baseline with automatic installation enabled and app open. Also check with a running test workload, auto-install off, and an unsupported newer release. | Successful upgrade reports the new version and preserves data. Active workloads block installation without being stopped. Auto-install off performs no install; unsupported releases defer. Same-version reinstall does not count as upgrade. | Real busy-workload refusal passed; real upgrade and automatic run pending. |
| G08 Migration | On the isolated Mac reproduce the recognized signed per-user layout, default data directory, same supported version and no `/usr/local` install; migrate while idle. Also test an unsupported custom layout. | Official path runs the expected version; original files/data remain; sample container data survives. Unsupported layout is refused without overwriting it. | Recognition/preflight passed; migration pending. |
| G09 Failure and recovery | Exercise offline release check, interrupted package download, canceled authorization, invalid package fixture in isolated tests, and installer/start failure via injected workflow tests. Disconnect/reconnect the engine without touching production workloads. | Clear localized error, no false success, UI remains responsive, retry works. Verification fails before service stop. Recovery failures remain visible. Report separately which cases are simulated and which were exercised on-device. | 13 simulated workflow scenarios passed; interactive/offline cases pending. |
| G10 Languages and visual design | Inspect Overview, table/inspector, creation form, engine and Settings in English, Simplified and Traditional Chinese; repeat light/dark at 1320×860 and minimum 1100×640. Check supported display scaling. | No untranslated app keys, clipped controls, unreadable contrast, nested-radius defects or inaccessible scroll content; no custom rounded masks cutting native controls. System-owned labels may follow macOS language. Save representative screenshots with build identity. | 179×3 catalog entries validated; English QA Overview, management and Settings captured; UI-001 fixed in current source; full matrix and second-Mac retest pending. |
| G11 Accessibility | Navigate creation and confirmations with keyboard only, including Tab/Shift-Tab and cancel; inspect CPU/image menus, slider and numeric field with VoiceOver; inspect increased contrast/reduced transparency. | Every operation has a readable name/value/focus; focus reaches actions and returns after dismissal; no keyboard trap. No claim of accessibility pass based on screenshots alone. | Pending. |
| G12 Responsiveness and stability | With the same disposable workload, keep the app open 60 minutes, refresh/navigate at least 30 times and perform the lifecycle cycles. Record app CPU/RSS every minute. | Zero crash/hang/unhandled error; navigation/form response within 1 s; status catches up within 15 s on a healthy local engine. After 5-minute warmup, median idle app CPU <5% of one core and final 5-minute median RSS ≤ initial 5-minute median +100 MiB; investigate sustained growth. | Pending; thresholds are acceptance targets, not measured claims. |
| G13 Documentation and media | Follow README from a fresh checkout; review release limitations and real app screenshots; run relative-link/image checks and inspect rendered GitHub README. | Build/install steps reproducible; support matrix matches evidence; ≥2 useful actual app screenshots, including the creation controls. No fake success, mock data, private paths/hostnames/logs/tokens in public assets. Record screenshot provenance. Video optional. | English QA Overview and management in README; Settings retained as secondary media. Current-source creation view verified locally; candidate creation screenshot and second-Mac acceptance pending. |
| G14 Public handoff | Review the candidate's final report, unresolved defects, history/artifacts and license intent; verify repo is still private before eligibility is recorded. | All required rows PASS with evidence; zero critical/major defects; minor defects listed with workarounds; privacy/reuse terms explicit. Set decision to ELIGIBLE only then. | Not ready. |

## What blocks public release

- **Critical:** data loss, unintended workload stop/deletion, exposed credentials, or bypass of package trust checks.
- **Major:** cannot launch/install/create/start/stop/delete, wrong resource allocation, incorrect update result, persistent crash/hang, or unusable controls in a supported language/size.
- **Minor:** cosmetic defects with no loss of readability or function. Record them; they cannot excuse a failed required gate.
- Developer ID/notarization is not inherently required for a GitHub public preview, but G02 still requires an honest, reproducible launch path for the shipped DMG. Never disable Gatekeeper/SIP or remove protection globally to manufacture a pass. If no supported path works, repair distribution or keep the candidate private.
- If a real upgrade baseline or other required environment is unavailable, retain **PENDING**. Removing a feature or narrowing supported scope requires an explicit product decision and updated documentation/tests; do not silently waive the gate.

## Test order and exit decision

1. Automated checks/artifact identity → download/launch → clean installation.
2. Hardware/form/lifecycle → upgrade/migration/recovery on isolated baselines.
3. Language/design/accessibility → 60-minute stability → README/media.
4. Complete the report and check every evidence link. **All PASS + zero critical/major defects = ELIGIBLE FOR PUBLIC PREVIEW.** Until then, keep private and keep the release marked pre-release.

The eligibility decision is separate from the actual visibility change. Do not represent the repository as public until GitHub confirms it. This document does not schedule background monitoring or make the repository public automatically.

## Current-source automated QA update — 2026-10-17

See [QA_RESULTS.md](QA_RESULTS.md) for the unified live/UI run, bounded-output/archive security changes and actual recording evidence. These source-level results do not fill the blank candidate acceptance table or certify the older release assets. The repository remains private until every required public-release gate is verified.
