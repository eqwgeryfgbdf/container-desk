# Container Desk 1.0.0 — validation and limits

Validation performed on 2026-10-28–29 (Asia/Taipei), on the developer's own Apple M4 Mac mini (16 GiB), macOS 26.7.1, Apple Container 1.5.0. The owner requested public 1.0 distribution, retained the own-device test scope and deferred a second Mac. This is a consolidated release, not certification of all hardware, Docker projects, models or external registries.

## Results from this release candidate

| Area | Result | Evidence / scope |
| --- | --- | --- |
| Logic and regressions | PASS | `scripts/test.sh`: core, installer state machine, management, project/file/archive safety, registry validation, local AI/MCP, image updates and 721 keys in each of three locales. |
| Native resource layout and transitions | PASS | `test-creation-ui.sh`, `test-motion.sh`; host bounds and reduced-motion behavior. |
| Container management | PASS | Real create/start/restart/stop/delete, ports, mounts, persistence and batch workflows; only disposable fixtures. |
| Clone | PASS on rerun | Real independent clone, retained command/env/resources/mounts and source preservation. Initial run failed the unrelated-state comparison; see below. |
| Files and projects | PASS on rerun | File round trip, no-overwrite, rename/mkdir/delete, dependency/health/DNS, project stop/restart/removal and retained volume. Initial run failed the unrelated-state comparison. |
| Project conversion | PASS | Native Docker conversion and official-resolver import, including changed-configuration refusal. |
| Registry and snapshot | PASS within local scope | Credential transport/rejection, loopback registry push, container snapshot and exclusion checks. No external private-registry success claim. |
| Search, architecture and resources | PASS | Live Docker Hub search/download, architecture deployment and resource batch protection suites. |
| Image update / recovery | PASS | Real BusyBox 1.36.1 → 1.37.0, HTTP 2xx, port/env/mount preservation, manual rollback, HTTP 404 automatic rollback and registry digest refresh. Original container states and fixture-image cleanup verified. |
| Hugging Face / llama.cpp | PASS, tool capability unsupported | 23 checks: live search, pinned metadata, ~105 MB GGUF download/verification, 2-CPU / 1-GiB container startup and actual text inference. The model's tool-call probe reported unsupported, as expected. Temporary model/container and newly downloaded server image removed. |
| AI native UI | PASS | 91 scripted actions across 12 language/theme/size cases. |
| Hugging Face native UI | PASS | 151 scripted actions across English, Traditional Chinese and Simplified Chinese, light/dark and window sizes. |
| General native UI and creation | PASS on final dedicated reruns | 170 matrix actions across 12 language/theme/size cases; 71 navigation/selection/filter/detail/log/file/download actions, including exact expanded-container title; 35 native CPU/memory/creation checks with real CLI readback. The separate creation and full navigation reruns passed exact container/image baseline comparisons. |
| Website | PASS locally | 12 language/viewport cases; 10 motion/interaction checks; Worker checks and 11 locale scenarios. Includes keyboard behavior, reduced motion, image loading, no-JS, 404, explicit language consent and the versioned 1.0 download URL. |
| User quick test | PASS | `quick-test.sh --check` and `--run`: actual loopback HTTP, exec/logs, stop/start persistence and owned-fixture cleanup. |
| Build | PASS | ARM64 release candidate 1.0.0 (build 8), `local.containerdesk.app`; ad hoc signature verification. |

The test counts above describe assertions/scenarios, not code coverage or a security certification. Raw captures and logs remain private because they may include host names, paths and workload identities. Public documentation contains the summarized result only.

### Baseline failures and reruns

The first `qa.py --live` report recorded **15 PASS, 3 FAIL, 7 SKIP**. During that run, an unrelated game-server deployment stopped one existing container and added two containers. The clone and file suites reached their final whole-engine state comparisons and failed there; the overall state-preservation comparison also failed. No test assertion was weakened and the initial report was retained. Clone and file/project suites were then rerun sequentially and passed, including original-state preservation. Image/network/volume inventories matched in the original report; the differences were the unrelated container changes. Subsequent update and AI suites verified their own cleanup and pre-existing state preservation.

The default orchestrator does not run the separately authorized model download or foreground UI suites. Their separate results above supersede those specific SKIP entries; other skipped checks remain unverified.

### Native table regression

The expanded-detail test initially opened the wrong container or no detail after changing search/filter results. The table retained stale scrolling/recycled row geometry. The app now rebuilds the table for a changed search/filter and keeps the inspector pane mounted, avoiding a layout change on first selection. The regression now checks the exact expanded-container window title, not merely the presence of a Back button. The original unfiltered double-click scenario passed after the fix; no alternate-container result is accepted.

An early native creation run completed all input/readback assertions but failed its final resource inventory comparison. Its dedicated rerun passed with before/after container and image inventories saved. One complete native navigation run likewise passed all 71 actions but failed the final image inventory comparison; it is not counted as a clean full-suite pass. Baseline capture was added to make future inventory differences diagnosable. A final independent full navigation rerun passed all 71 actions and exact before/after container/image inventory comparison. Raw failure reports are retained privately.

### Lightweight model

- Repository: `bartowski/SmolLM2-135M-Instruct-GGUF`.
- File: `SmolLM2-135M-Instruct-Q4_K_M.gguf`, 105,454,432 bytes.
- Tested revision: `09816acd5d99df7be770d85ea30822623dab342c`.
- Download checks: pinned revision, exact size, GGUF header and SHA-256.
- Result: nonempty local text response; tool calling unsupported. Text generation is not proof of MCP capability. No claim about model quality or GPU acceleration.

## Still unverified / deliberately not run

- **Developer ID and notarization:** unavailable; only ad hoc signing. Apple Development credentials are not a substitute for Developer ID distribution.
- **Second-Mac / clean install:** deferred by the owner. Replacing and launching on this existing development Mac does not prove a clean downloaded-DMG Gatekeeper flow on another Mac.
- **Actual engine installation/upgrade:** not performed against the live shared engine. Installer failure/recovery paths have simulated regression coverage only.
- **Build/archive live suite:** skipped because the host's existing builder was active. It was not stopped for testing. Historical tests do not become a new 1.0 pass.
- **External private HTTPS registry success:** needs a dedicated account and environment; local push and rejection tests do not cover it.
- **Full manual accessibility acceptance:** no complete VoiceOver, high-contrast or subjective motion review. Scripted accessible controls are partial evidence.
- **New 60-minute idle soak:** not rerun for 1.0. Historical 0.2 results do not certify this candidate's long-duration stability.
- No guarantee of arbitrary Compose/Docker compatibility, mounted-database rollback, remote host management, Metal acceleration or every GGUF/MCP combination.

## Reproduction and packaging

See [Automated QA](AUTOMATED_QA.md) and the [quick start](QUICK_START.md). Run live suites sequentially while unrelated workloads are stable. Tests refuse or report unexpected changes rather than broadly deleting data.

The packaging script requires a clean committed tree and writes local source-commit, tree and SHA-256 provenance. The public Release contains only the DMG; its body records the installer checksum and source commit. Before publication, verify the DMG, mount it read-only, check version/bundle identity, architecture, signature, three locales, new icon and portable installer instructions. Re-download the published asset and compare its SHA-256. GitHub's automatic source archives refer to the same version tag.

## 繁體中文摘要

已在自己的 M4 Mac mini 實測容器、檔案、專案、倉庫本機流程、映像更新／失敗回復，以及約 105 MB 小模型的下載與文字推論。小模型不支援可靠的工具調用，會顯示相容性提示。三語 AI／模型搜尋介面及官網自動化通過。第一次測試受到其他容器部署影響的狀態比較失敗已保留，相關功能重跑通過。

本版只有 ad hoc 簽章，沒有 Developer ID／Apple 公證；第二台 Mac、乾淨安裝、實際引擎升級、外部私人倉庫、完整人工無障礙與本版 60 分鐘穩定性測試仍未完成。忙碌中的既有建置器沒有被中斷，建置／封存實機測試因此略過。未執行不等於通過。

## 简体中文摘要

已在自己的 M4 Mac mini 实测容器、文件、项目、仓库本地流程、镜像更新／失败恢复，以及约 105 MB 小模型下载与文字推理。小模型不支持可靠的工具调用，会显示兼容性提示。三语 AI／模型搜索界面及官网自动化通过。第一次测试受其他容器部署影响的状态比较失败已保留，相关功能重跑通过。

本版只有 ad hoc 签名，没有 Developer ID／Apple 公证；第二台 Mac、干净安装、实际引擎升级、外部私人仓库、完整人工无障碍及本版 60 分钟稳定性测试仍未完成。没有中断繁忙的已有构建器，因此跳过了构建／归档实机测试。未执行不等于通过。
