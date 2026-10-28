> 1.0.0: tests run only on the developer’s own Mac. Second-Mac testing is deferred by the owner. See [current validation](RELEASE_1.0.0_VALIDATION.md). The desktop must be unlocked for native UI tests; they do not bypass the lock screen.

# Automated QA

Run on Apple Silicon with macOS 26 and Swift command-line tools. Tests use real Apple Container operations when `--live` is supplied. The suite never performs a global prune, replaces the engine, or uses saved credentials to publish to a remote registry.

```sh
python3 scripts/qa.py                       # offline logic, locale and native layout tests
python3 scripts/qa.py --live --ui           # engine fixtures plus foreground UI regression
bash scripts/test-ui.sh --record --out ../work/promo
xcrun swiftc -parse-as-library scripts/annotate-video.swift -o ../work/annotate-video
../work/annotate-video ../work/promo/raw.mov ../work/promo/window.json ../work/promo/ui.log ../work/promo/Container-Desk-Overview.mp4
```

Build the application first with `bash scripts/build.sh`. UI tests use that build, temporarily launch in English/light appearance, and require an unlocked desktop plus Accessibility permission for the runner. Recording also requires Screen Recording permission. The test cannot grant these permissions silently. Do not interact with the desktop during the foreground script. The matrix changes language and appearance through Settings and returns to English/light; it does not restore a different prior preference.

The live suite downloads official Python/BusyBox/Distribution images as needed. Standalone UI tests/recording also provision the official Python image if absent and remove only that newly added reference afterward. Each test names its own fixtures, checks readback, and cleans up. The runner saves resource inventory before and after; unexplained differences are failures and are not broadly deleted. An active existing builder is left alone, with the build test marked skipped. Logs, JSON, JUnit XML and Markdown reports go to `../work/qa/<timestamp>/`. Exit code 1 means a failure. **SKIP is not PASS.** Some suites contain multiple assertions; suite totals are not code-coverage percentages.

| Function | Automated evidence |
|---|---|
| Host CPU/memory/disk, parser and engine policies | CoreTests; actual macOS system APIs |
| Create, start, restart, stop, delete, volume persistence | StoreSmoke and ManagementIntegration |
| CPU dropdown/memory inputs, large-host layout | CreationLayoutSmoke; UI configuration flow |
| Multi-port HTTP/UDP, bind mounts, logs, batch continuation/refusal | WorkflowIntegration |
| Images: pull/build/tag/save/load/delete | ImageManagementIntegration; exact inventory readback |
| Search, pagination, architecture, ARM64/AMD64 | HubSearch tests; Rosetta execution only when installed |
| Files: binary/directory transfer, no-overwrite, rename/mkdir/delete | PlatformLiveTests; security archive regressions |
| Registry login rejection, credential pipe and local push | RegistryLiveTests/RegistryPushTests; no remote account required |
| Container snapshot, exclusions, local push | ContainerSnapshotTests |
| Project lifecycle, health, aliases, multi-network, changed-config refusal | Native, converted and official-resolver live suites |
| Resource selection and deletion protections | ResourceBatchTests; UI checkbox/filter regression |
| Full details, logs/files, zoom, navigation, download → configuration | Scripted native AX/keyboard actions with observable assertions |
| Animation/reduced motion and 3-language key completeness | InterfaceMotionSmoke; localization checker |
| Installer recovery sequences | Simulated InstallWorkflowTests; not a real installation |
| Hostile output and archive budgets | Small stdout/stderr/cancellation and tar-format/entry/size regression fixtures |

## Acceptance that remains separate

- Clean installation / real upgrade acceptance remains unverified. The owner deferred a second Mac; do not mark this check passed.
- Trusted HTTPS private-registry login success with a dedicated account.
- Manual VoiceOver reading quality, high contrast, sidebar drag ordering and service URL opening in the user's browser. Three-language creation layout is covered separately by the matrix.
- A 60-minute idle performance run. Use the app PID from `../work/tests/UIAutomation metadata`:

```sh
python3 scripts/soak.py --pid APP_PID --minutes 60 --out ../work/qa/soak.json
```

The soak checks process survival, median idle CPU below 5% of one core and RSS growth no more than 100 MiB. A shorter run is explicitly `INCOMPLETE`; it does not pass the release gate. Navigation latency and data refresh latency remain separate checks.

## Local AI, Hugging Face and image updates

These run separately from the default orchestrator so downloads and service replacement are explicit. Run live suites sequentially on an otherwise quiet engine; concurrent unrelated workload changes correctly fail baseline checks.

```sh
bash scripts/test-image-updates.sh --live
bash scripts/test-huggingface.sh --live --download --inference --allow-image-pull
python3 scripts/test-ai-ui.py
python3 scripts/test-huggingface-ui.py
```

The Hugging Face trial requires the 135M Q4_K_M file to be under 128 MiB (~105 MB at the tested revision). It verifies the download, starts a temporary 2-CPU / 1-GiB llama.cpp container on loopback port 19893, performs text inference and measures tool capability. Keep that port free. The pinned server image is a separate download if absent. Newly created test containers, the temporary model and newly pulled server image are cleaned up; existing models are not used. Unsupported tool calling is reported rather than treated as successful capability.

The AI UI scripts default to the release app identifier. If testing a development build, set `CONTAINERDESK_UI_BUNDLE_ID=local.containerdesk.ai-development` for each script. These scripts require an unlocked desktop and test three languages, light/dark appearance and window sizes; they do not download a model.

## Recording policy

`raw.mov` is private test evidence and can show the host name. Only the annotated MP4 is intended for promotion: its host-name regions are masked, chapter captions use Traditional Chinese, and the footer identifies actual app footage and version. Review the four exported frames and the entire clip before publication. The recorder finishes its fixed 150-second window normally (interrupting macOS screencapture can discard the movie). The annotator checks that the scenario completed before the recording ended and trims only trailing idle footage; action timing is not accelerated. The recorder does not change repository visibility or upload footage automatically.

## Three-language native matrix and recording

```sh
bash scripts/build.sh
bash scripts/test-ui.sh --matrix --record --out ../work/ui-candidate
```

The matrix covers English, Traditional Chinese and Simplified Chinese, light/dark, at 1320×860 and the actual minimum window size 1100×692 (640-point content plus native chrome). It visits Overview, Containers, Engine and Settings and checks creation-field/cancel accessibility. Theme and language return to English/light. A failure remains a failure; screenshots are private until reviewed and redacted. This is not a full VoiceOver certification.

`--reuse` uses an already-running candidate at the exact requested app path, allowing a continuous stability run without relaunch. Start that candidate in English/light, and keep it unlocked. Recording captures a bounded 150 seconds; the annotator trims trailing idle footage only and refuses failed UI scenarios. The native runner ignores macOS screen-sharing overlay windows when identifying the main app window.

With the native test driver compiled and the candidate in English/light, run `python3 scripts/ui-creation-check.py --out ../work/ui-creation` for real CPU-menu and memory-boundary validation, stopped creation, CLI readback and owned-fixture cleanup. It downloads BusyBox only if absent. `Tests/UI/navigation.json` exercises 30 page changes and logs navigation latency.
