# Container Desk 0.1.3 — Developer Preview

[English](#english) · [中文（繁體）](#繁體中文) · [中文（简体）](#简体中文)

## English

A native SwiftUI manager for **local Apple Container** on Apple Silicon, macOS 26+. This independent preview is tested with Apple Container **1.5.0**.

**Start here:** [English quick start](https://github.com/eqwgeryfgbdf/container-desk/blob/v0.1.3-preview/docs/QUICK_START.md). Install the DMG, connect the engine, then try the optional no-compiler Quick Start bundle:

```sh
bash quick-test.sh --check
bash quick-test.sh --run
```

The first command is read-only. The second tests a temporary loopback HTTP container, exec/log access and stop/start persistence, then cleans up its own container and newly downloaded image. Use `--run --keep` to explore it in the app; follow the printed cleanup commands afterwards. No Xcode, Python or sudo is required. This is an engine smoke test, not complete UI/install acceptance.

### What's new since the previous downloadable preview

- Full image/network/volume management, reviewed batch actions and richer full-window container details with clickable TCP web links, logs and live resource charts.
- Unified Docker Hub search, architecture inspection, download and deployment; ARM64 and AMD64/Rosetta paths; Dockerfile builds and OCI archives.
- Container file browsing/transfers, snapshots, Registry login/logout and image push, Projects import/lifecycle and reviewed Docker conversion. Unsupported Compose fields are rejected; Docker volume data needs separate migration.
- Saved sidebar order, content zoom, Reduce Motion-aware transitions, three interface languages, and the creation-sheet layout hang fix.
- Bounded process output and safer bounded tar extraction; automatic app-version display. Matching Apache-2.0 source, manifest, checksums and a three-language quick-start guide are now included.

### Downloads

| File | Purpose |
|---|---|
| `Container-Desk-0.1.3-arm64-preview.dmg` | Install the app. |
| `Container-Desk-0.1.3-Quick-Start.zip` | Optional guides, launchers, smoke script and example project; no duplicated DMG. |
| `Container-Desk-0.1.3-preview-source.zip` | Exact matching Apache-2.0 source, resources, scripts and tests. |
| `Container-Desk-0.1.3-preview-manifest.json` | Source commit/tree and primary artifact hashes. |
| `SHA256SUMS.txt` | SHA-256 checksums of all uploaded attachments except itself. |
| `Container-Desk-Overview-zh-Hant.mp4` | 58.5-second real-app walkthrough with Traditional Chinese captions, recorded on the preceding QA build. |

Verify downloaded files with `shasum -a 256 -c SHA256SUMS.txt` if all assets are in the same folder; for DMG only, compare `shasum -a 256 Container-Desk-0.1.3-arm64-preview.dmg` against its entry.

### Test status and limits

Prior full baseline: **17 groups passed, 0 failed, 5 environment-dependent groups skipped**, including **56 native UI steps**. The new quick-test script and release build have separate [validation notes](https://github.com/eqwgeryfgbdf/container-desk/blob/v0.1.3-preview/docs/RELEASE_0.1.3_VALIDATION.md). Media is real QA footage, not clean-install or upgrade proof. Second-Mac install/upgrade, full accessibility, 60-minute soak and real private-registry acceptance remain pending. AI integration is deferred.

**Ad hoc signed; no Developer ID or Apple notarization.** macOS may block opening; follow the quick-start guide's per-app instructions. The repository remains **private**: testers need repository access and GitHub sign-in. This is a **pre-release**, not a stable/public launch. Historical 0.1.2 assets are preserved.

## 繁體中文

原生 SwiftUI **本機 Apple Container** 管理工具，適用於 Apple Silicon、macOS 26 以上。此獨立預覽版已測試的引擎版本為 **1.5.0**。

**從這裡開始：** [繁體中文快速上手](https://github.com/eqwgeryfgbdf/container-desk/blob/v0.1.3-preview/docs/QUICK_START.zh-Hant.md)。安裝 DMG、連接引擎後，解壓選用的 Quick Start 入門包：

```sh
bash quick-test.sh --check
bash quick-test.sh --run
```

第一個命令唯讀；第二個建立只開放本機的網頁容器，驗證 HTTP、exec／日誌與停止重啟後的檔案保留，再清理自己建立的容器及新下載映像。加上 `--run --keep` 可在 App 裡繼續操作，完成後依輸出清理。不需要 Xcode、Python 或 sudo；這是引擎基本流程測試，不代表全部介面／安裝驗收。

**相較上次可下載版本：** 補齊映像、網路、儲存卷與批量管理；全視窗容器資訊、即時圖表及可點擊網址；整合搜尋、架構檢查、下載部署；加入檔案管理、容器快照、倉庫推送、專案與 Docker 轉換；新增側欄排序、縮放和減少動態效果支援，修正建立容器視窗卡住。程序輸出與 tar 解壓增加容量限制，並附同版 Apache-2.0 原始碼及三語教學。不支援的 Compose 欄位會阻擋匯入，Docker 儲存卷資料需另行遷移。

**下載：** DMG 用於安裝；Quick Start ZIP 是選用教學／測試包，不重複包含 DMG；source ZIP 是同版開源檔；manifest 記錄來源與雜湊；`SHA256SUMS.txt` 可核對附件。MP4 是 58.5 秒真實操作影片、繁體字幕，來自先前 QA 建置。

**驗證與限制：** 先前完整基準為 **17 組通過、0 失敗、5 組依賴外部環境的測試略過**，含 **56 個原生介面步驟**。本版快速腳本與建置另有[驗證紀錄](https://github.com/eqwgeryfgbdf/container-desk/blob/v0.1.3-preview/docs/RELEASE_0.1.3_VALIDATION.md)。第二台 Mac 安裝／升級、完整無障礙、60 分鐘長跑與真實私人倉庫驗收仍待完成；AI 整合延後。影片不代表安裝／升級通過。

**僅 ad hoc 簽章，沒有 Developer ID／Apple 公證；macOS 可能阻擋開啟，請依教學處理單一 App。儲存庫維持私人，測試者需有權限並登入 GitHub。** 本次是預覽版，並非公開穩定版；0.1.2 歷史附件保留。

## 简体中文

原生 SwiftUI **本机 Apple Container** 管理工具，适用于 Apple Silicon、macOS 26 以上。此独立预览版已测试的引擎版本为 **1.5.0**。

**从这里开始：** [简体中文快速上手](https://github.com/eqwgeryfgbdf/container-desk/blob/v0.1.3-preview/docs/QUICK_START.zh-Hans.md)。安装 DMG、连接引擎后，解压可选的 Quick Start 入门包：

```sh
bash quick-test.sh --check
bash quick-test.sh --run
```

第一个命令只读；第二个创建仅本机可访问的网页容器，验证 HTTP、exec／日志及停止重启后的文件保留，再清理自己创建的容器与新下载镜像。添加 `--run --keep` 可继续在 App 中体验，完成后按输出清理。不需要 Xcode、Python 或 sudo；这是引擎基本流程测试，不代表全部界面／安装验收。

**相比上次可下载版本：** 补齐镜像、网络、存储卷及批量管理；全窗口容器详情、实时图表和可点击网址；整合搜索、架构检查、下载部署；新增文件管理、容器快照、仓库推送、项目与 Docker 转换；加入侧栏排序、缩放及减少动态效果支持，修复创建容器窗口卡死。进程输出和 tar 解压增加容量限制，并附同版 Apache-2.0 源码与三语教程。不支持的 Compose 字段会阻止导入，Docker 存储卷数据需要单独迁移。

**下载：** DMG 用于安装；Quick Start ZIP 是可选教程／测试包，不重复包含 DMG；source ZIP 是同版开源文件；manifest 记录来源及哈希；`SHA256SUMS.txt` 可校验附件。MP4 是 58.5 秒实机操作视频、繁体字幕，来自此前 QA 构建。

**验证与限制：** 此前完整基线为 **17 组通过、0 失败、5 组依赖外部环境的测试跳过**，含 **56 个原生界面步骤**。本版快速脚本及构建另有[验证记录](https://github.com/eqwgeryfgbdf/container-desk/blob/v0.1.3-preview/docs/RELEASE_0.1.3_VALIDATION.md)。第二台 Mac 安装／升级、完整无障碍、60 分钟长时间运行和真实私有仓库验收仍待完成；AI 集成延后。视频不代表安装／升级通过。

**仅 ad hoc 签名，没有 Developer ID／Apple 公证；macOS 可能阻止打开，请按教程处理单个 App。仓库保持私有，测试者需要权限并登录 GitHub。** 本次为预览版，并非公开稳定版；0.1.2 历史附件保留。

## Official dependency / 官方依賴 / 官方依赖

[Apple Container](https://github.com/apple/container)
