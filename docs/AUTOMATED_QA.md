# Automated QA

Run on Apple Silicon with macOS 26 and Swift command-line tools. Tests use real Apple Container operations when `--live` is supplied. The suite never performs a global prune, replaces the engine, or uses saved credentials to publish to a remote registry.

```sh
python3 scripts/qa.py                       # offline logic, locale and native layout tests
python3 scripts/qa.py --live --ui           # engine fixtures plus foreground UI regression
bash scripts/test-ui.sh --record --out ../work/promo
xcrun swiftc -parse-as-library scripts/annotate-video.swift -o ../work/annotate-video
../work/annotate-video ../work/promo/raw.mov ../work/promo/window.json ../work/promo/ui.log ../work/promo/Container-Desk-Overview.mp4
```

Build the application first with `bash scripts/build.sh`. UI tests use that build, temporarily launch in English/light appearance, and require an unlocked desktop plus Accessibility permission for the runner. Recording also requires Screen Recording permission. The test cannot grant these permissions silently. Do not interact with the desktop during the foreground script. Normal application preferences are not changed by the language launch overrides.

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

- Another clean Mac: download the actual GitHub DMG, first launch, real core install, administrator cancellation/retry and upgrade recovery.
- Trusted HTTPS private-registry login success with a dedicated account.
- VoiceOver reading quality, high contrast, all three languages at supported window sizes, sidebar drag ordering and service URL opening in the user's browser.
- A 60-minute idle performance run. Use the app PID from `../work/tests/UIAutomation metadata`:

```sh
python3 scripts/soak.py --pid APP_PID --minutes 60 --out ../work/qa/soak.json
```

The soak checks process survival, median idle CPU below 5% of one core and RSS growth no more than 100 MiB. A shorter run is explicitly `INCOMPLETE`; it does not pass the release gate. Navigation latency and data refresh latency remain separate checks.

AI deployment is intentionally deferred. A future trial should start with one lightweight local model and measured memory/latency before expanding compatibility.

## Recording policy

`raw.mov` is private test evidence and can show the host name. Only the annotated MP4 is intended for promotion: its host-name regions are masked, chapter captions use Traditional Chinese, and the footer identifies actual app footage and development-preview status. Review the four exported frames and the entire clip before publication. The recorder finishes its fixed 90-second window normally (interrupting macOS screencapture can discard the movie). The annotator checks that the scenario completed before the recording ended and trims only trailing idle footage; action timing is not accelerated. The recorder does not change repository visibility or upload footage automatically.
