# Container Desk 0.2.0

[English](#english) · [中文（繁體）](#繁體中文) · [中文（简体）](#简体中文)

## English

A regular public release of the native SwiftUI manager for **local Apple Container**. Requires Apple Silicon and macOS 26+. Tested engine: **1.5.0**. Independent app; not an Apple product.

**Tested only on the developer's own M4 Mac mini, 16 GiB, macOS 26.7.1. Second-Mac testing was explicitly deferred.** Public release status does not imply broad hardware certification or Apple notarization.

New in 0.2.0:

- Duplicate a container into a separate stopped instance, with source identity rechecks, cleared ports, optional environment/mounts and read-only mounts by default. The original stays intact; mounted data is shared, not copied.
- Inspect local image command, user, working directory and exposed-port defaults before creation.
- Browse HTTPS Registry V2 repository/tag pages and deploy a selected tag. Optional catalog Basic credentials are session-only; CLI pull/push login remains separate. Some hosted registries do not expose catalogs or use unsupported bearer authentication.
- Read actual disk usage and selectively review image/network/volume cleanup, with reference checks before each deletion. No global prune.
- Repair three medium-severity security issues: Compose option-like guest arguments could crash preview/hosts processing, environment expansion lacked memory budgets, and a single-label catalog host could be interpreted as a Docker Hub namespace. Added regression tests and independent patch review.
- Expanded English, Traditional Chinese and Simplified Chinese onboarding, repeatable QA and native UI test diagnostics for locked screens.

Existing workflows include lifecycle/batch operations, full-window details/charts, clickable TCP links, searchable logs, files, snapshots, Docker Hub search/download/configuration, ARM64/AMD64 selection, OCI archives, Dockerfile builds, projects and reviewed Docker conversion. Unsupported project settings are rejected. Full Docker data/local-image transfer, restart supervision and cutover/rollback remain future work.

### Try it

[English quick start](https://github.com/eqwgeryfgbdf/container-desk/blob/v0.2.0/docs/QUICK_START.md). Download the DMG and optional Quick Start ZIP, verify checksums, install the app, connect the official Apple Container engine, then run from the unzipped Quick Start directory:

```sh
bash quick-test.sh --check
bash quick-test.sh --run
```

The first command is read-only. The second runs a disposable loopback HTTP container, verifies exec/log access and stop/start persistence, then removes its own resources. Add `--keep` to explore it in the app and follow the printed cleanup instructions. No compiler or sudo needed.

| Asset | Purpose |
|---|---|
| `Container-Desk-0.2.0-arm64.dmg` | Install the app. Ad hoc signed; **no Developer ID or Apple notarization**. |
| `Container-Desk-0.2.0-source.zip` | Matching Apache-2.0 source, resources, scripts and tests. |
| `Container-Desk-0.2.0-manifest.json` | Exact source commit/tree and primary artifact hashes. |
| `Container-Desk-0.2.0-Quick-Start.zip` | Three-language guide, smoke test, launchers and sample project; no duplicate DMG. |
| `Container-Desk-Overview-zh-Hant.mp4` | Actual app walkthrough with Traditional Chinese captions; not installation/upgrade proof. |
| `Container-Desk-0.2.0-Validation.json` | Final own-Mac QA/stability summary and artifact verification. |
| `SHA256SUMS.txt` | Checksums for every other attached asset. |

For all files in one folder: `shasum -a 256 -c SHA256SUMS.txt`. For DMG only, compare its full SHA-256 with the matching line. Follow the guide's per-app macOS opening instructions; do not disable Gatekeeper globally.

[Verification details and remaining limits](https://github.com/eqwgeryfgbdf/container-desk/blob/v0.2.0/docs/RELEASE_0.2.0_VALIDATION.md). Clean engine installation, genuine engine upgrades, external private HTTPS registry success and complete manual VoiceOver acceptance are not verified. AI models are deferred. Historical preview releases remain for traceability.

## 繁體中文

原生 SwiftUI **本機 Apple Container** 管理工具的 0.2.0 正式公開發行。需要 Apple Silicon、macOS 26 以上；已測試引擎為 **1.5.0**。這是獨立 App，並非 Apple 產品。

**僅在開發者自己的 M4 Mac mini（16 GiB、macOS 26.7.1）測試；第二台 Mac 測試依擁有者決定暫不執行。** 正式公開不代表所有設備皆經驗證，也不代表已通過 Apple 公證。

本版新增安全複製容器、映像啟動預設資訊、HTTPS Registry V2 專案／標籤瀏覽與部署、真實磁碟用量及逐項清理確認。複製保留原容器、清除連接埠，環境變數與掛載需主動加入，掛載預設唯讀；儲存卷為共用，不會複製資料。倉庫目錄使用暫存 Basic 認證，拉取／推送另外登入，不保證支援每個服務的 Bearer 流程。

修復三項中度安全問題：Compose 指令參數混淆造成預覽／主機名稱處理崩潰、環境變數展開無記憶體上限、簡短倉庫主機名誤導向 Docker Hub。已加入回歸測試及獨立複核。三語教學與自動化也同步更新。

[繁體快速上手](https://github.com/eqwgeryfgbdf/container-desk/blob/v0.2.0/docs/QUICK_START.zh-Hant.md)：下載 DMG 安裝，連接官方引擎；選用 Quick Start ZIP 解壓後先執行 `bash quick-test.sh --check`（唯讀），再執行 `bash quick-test.sh --run`（建立、驗證並清理專用測試容器）。加上 `--keep` 可留在 App 中操作，完成後依輸出清理。不需要編譯器或 sudo。

DMG 是安裝檔；source ZIP 是同版 **Apache-2.0** 原始碼；manifest 與 `SHA256SUMS.txt` 可核對提交與檔案；入門包不重複包含 DMG。Validation.json 記錄本機最終測試與穩定性結果。MP4 為真實操作錄影、繁體字幕，不代表安裝／升級驗收。

**只有 ad hoc 簽章，沒有 Developer ID／Apple 公證。** macOS 可能阻擋首次開啟，請依教學處理單一 App。全新引擎安裝、真實舊版升級、外部私人 HTTPS 倉庫成功流程及完整 VoiceOver 人工驗收仍未驗證。完整 Docker 資料／本機映像遷移、重啟監督與切換／回滾尚未完成；AI 延後。[本版驗證與限制](https://github.com/eqwgeryfgbdf/container-desk/blob/v0.2.0/docs/RELEASE_0.2.0_VALIDATION.md)。

## 简体中文

原生 SwiftUI **本机 Apple Container** 管理工具的 0.2.0 正式公开发行。需要 Apple Silicon、macOS 26 以上；已测试引擎为 **1.5.0**。这是独立 App，并非 Apple 产品。

**仅在开发者自己的 M4 Mac mini（16 GiB、macOS 26.7.1）测试；第二台 Mac 测试按所有者决定暂不执行。** 正式公开不代表全部设备均经验证，也不代表已通过 Apple 公证。

本版新增安全复制容器、镜像启动默认信息、HTTPS Registry V2 项目／标签浏览与部署、真实磁盘用量及逐项清理确认。复制保留源容器、清除端口，环境变量与挂载需主动加入，挂载默认只读；卷为共享，不会复制数据。仓库目录使用临时 Basic 认证，拉取／推送另外登录，不保证支持每个服务的 Bearer 流程。

修复三项中度安全问题：Compose 命令参数混淆导致预览／主机名处理崩溃、环境变量展开没有内存上限、简短仓库主机名误导向 Docker Hub。已添加回归测试及独立复核。三语教程与自动化也同步更新。

[简体快速上手](https://github.com/eqwgeryfgbdf/container-desk/blob/v0.2.0/docs/QUICK_START.zh-Hans.md)：下载 DMG 安装，连接官方引擎；可选 Quick Start ZIP 解压后先运行 `bash quick-test.sh --check`（只读），再运行 `bash quick-test.sh --run`（创建、验证并清理专用测试容器）。添加 `--keep` 可留在 App 中操作，结束后按输出清理。不需要编译器或 sudo。

DMG 是安装文件；source ZIP 是同版 **Apache-2.0** 源代码；manifest 与 `SHA256SUMS.txt` 可核对提交和文件；入门包不重复包含 DMG。Validation.json 记录本机最终测试及稳定性结果。MP4 是真实操作录屏、繁体字幕，不代表安装／升级验收。

**只有 ad hoc 签名，没有 Developer ID／Apple 公证。** macOS 可能阻止首次打开，请按教程处理单个 App。全新引擎安装、真实旧版升级、外部私有 HTTPS 仓库成功流程及完整 VoiceOver 人工验收仍未验证。完整 Docker 数据／本地镜像迁移、重启监督与切换／回滚尚未完成；AI 延后。[本版验证与限制](https://github.com/eqwgeryfgbdf/container-desk/blob/v0.2.0/docs/RELEASE_0.2.0_VALIDATION.md)。
