# Container Desk 1.0.0

[English](#english) · [繁體中文](#繁體中文) · [简体中文](#简体中文)

## English

The first consolidated 1.0 release of Container Desk, an independent native SwiftUI manager for the official Apple Container engine. Requires Apple Silicon and macOS 26+. This version brings the existing container, image, project and local AI workflows into one versioned source tree, installer, documentation set and website.

- Latest translucent **VM + package icon**, shared by the installer, Dock, sidebar and website.
- Reset stale table scrolling/row geometry when search or filters change, and keep the detail pane in place. Native regression tests verify the expanded container identity.
- Container lifecycle and batch operations, expanded details, clickable web ports, real host information, file transfer, networks, volumes and snapshots.
- Docker Hub search with architecture selection, download-to-deployment, supported Docker/Compose project conversion, registry workflows and image updates with health checks and rollback.
- Hugging Face single-file GGUF search/download with revision and SHA-256 verification; llama.cpp CPU deployment, MCP connection and explicit tool-call approval. Models are not bundled.
- English, Traditional Chinese and Simplified Chinese guides, native UI scaling, sidebar ordering and reduced-motion-aware transitions.
- Website source, branding assets and the existing narrated AI tutorial are now included in the repository. The older tutorial/screenshots remain labeled with their recording version.

**Download:** `Container-Desk-1.0.0-arm64.dmg` is the only uploaded Release asset. The Apache-2.0 source is available at this tag and through GitHub's automatic source archives. No separate test ZIP is required.

**Signing and validation:** ad hoc signed; no Developer ID or Apple notarization. Tested only on the developer's M4 Mac mini, macOS 26.7.1, Apple Container 1.5.0. A 1.0 version number does not imply clean-install, multi-device, every-Docker-project or every-model compatibility. See the [actual validation record and open limits](RELEASE_1.0.0_VALIDATION.md).

**Upgrade:** quit the previous app and replace it in Applications. Version 1.0 uses `local.containerdesk.app`; the 0.3 preview used a separate preference domain. Reselect preview UI preferences and existing GGUF files if needed. Replacing the app does not remove Apple Container workloads or storage. Image replacement is a separate, confirmed operation; rollback does not undo mounted-data writes. Local AI has no Metal acceleration, and the small 135M example is not a reliable MCP tool-calling model.

[Quick start](QUICK_START.md) · [Hugging Face / llama.cpp / MCP](AI_QUICK_START.md) · [Image updates](IMAGE_UPDATES.md)

## 繁體中文

Container Desk 首個整合版 1.0，以原生 SwiftUI 管理 Apple 官方 Container 引擎。獨立開源專案，需要 Apple Silicon、macOS 26 以上。將現有容器、映像、專案與本機 AI 功能，整理成版本一致的原始碼、安裝檔、文件與官網。

- 安裝檔、Dock、側欄與官網統一最新透明立體 **VM＋套件 Logo**。
- 修正搜尋／篩選後表格保留舊捲動與列位置的問題，固定資訊欄版面；自動化會核對雙擊展開的容器名稱。
- 容器生命週期與批次管理、展開資訊、點擊連接埠、真實主機資訊、檔案傳輸、網路、儲存卷與快照。
- Docker Hub 搜尋與架構選擇、下載部署、支援範圍內的 Docker／Compose 轉換、Registry 工作流程、映像更新與健康檢查／回復。
- Hugging Face 單檔 GGUF 搜尋與下載，固定版本及 SHA-256 驗證；llama.cpp CPU 部署、MCP 連線與逐批確認工具執行。不內附模型。
- 英文、繁體、簡體教學；介面縮放、側欄排序與尊重減少動態效果的過渡動畫。
- 納入官網原始碼、品牌素材及既有 AI 旁白教學。舊教學／截圖仍標明錄製版本。

**下載：**Release 手動上傳附件只有 `Container-Desk-1.0.0-arm64.dmg`。Apache-2.0 原始碼可從版本標籤及 GitHub 自動封存取得，不另附測試包。

**簽章與驗證：**僅 ad hoc 簽章，尚無 Developer ID／Apple 公證。只在開發者自己的 M4 Mac mini、macOS 26.7.1、Apple Container 1.5.0 測試。1.0 不代表已完成乾淨安裝、多設備或所有 Docker 專案／模型相容驗證。[本次測試與未完成項目](RELEASE_1.0.0_VALIDATION.md)。

**升級：**先結束舊 App，再於「應用程式」取代。1.0 使用 `local.containerdesk.app`，與 0.3 預覽版的偏好設定位置不同；必要時重新選擇介面偏好及既有 GGUF。替換 App 不刪除 Apple Container 的容器及資料。映像替換需另行確認，回復不能還原掛載資料的寫入。AI 使用 CPU，沒有 Metal；135M 示範模型不適合作為可靠的 MCP 工具調用模型。

[快速上手](QUICK_START.zh-Hant.md) · [Hugging Face／llama.cpp／MCP](AI_QUICK_START.zh-Hant.md) · [映像更新](IMAGE_UPDATES.md)

## 简体中文

Container Desk 首个整合版 1.0，使用原生 SwiftUI 管理 Apple 官方 Container 引擎。独立开源项目，需要 Apple Silicon、macOS 26 及以上。将已有的容器、镜像、项目及本地 AI 功能整理为版本一致的源码、安装包、文档和官网。

- 安装包、Dock、侧栏与官网统一最新透明立体 **VM＋软件包 Logo**。
- 修复搜索／筛选后表格保留旧滚动和行位置的问题，固定详情栏布局；自动化会核对双击展开的容器名称。
- 容器生命周期与批量管理、展开详情、点击端口、真实主机信息、文件传输、网络、存储卷及快照。
- Docker Hub 搜索与架构选择、下载部署、支持范围内的 Docker／Compose 转换、Registry 工作流程、镜像更新与健康检查／恢复。
- Hugging Face 单文件 GGUF 搜索下载，固定版本和 SHA-256 验证；llama.cpp CPU 部署、MCP 连接及逐批确认工具执行。不附带模型。
- 英文、繁体、简体教程；界面缩放、侧栏排序和尊重减少动态效果的过渡动画。
- 纳入官网源码、品牌素材和已有 AI 旁白教程。历史教程／截图保留录制版本说明。

**下载：**Release 手动上传附件只有 `Container-Desk-1.0.0-arm64.dmg`。Apache-2.0 源码可从版本标签和 GitHub 自动归档获取，不另附测试包。

**签名与验证：**仅 ad hoc 签名，没有 Developer ID／Apple 公证。只在开发者自己的 M4 Mac mini、macOS 26.7.1、Apple Container 1.5.0 测试。1.0 不表示已完成干净安装、多设备或所有 Docker 项目／模型兼容验证。[本次测试和未完成项目](RELEASE_1.0.0_VALIDATION.md)。

**升级：**退出旧 App，再于“应用程序”替换。1.0 使用 `local.containerdesk.app`，与 0.3 预览版的偏好设置位置不同；必要时重新选择界面偏好和已有 GGUF。替换 App 不删除 Apple Container 的容器及数据。镜像替换需要单独确认，恢复不能撤销挂载数据写入。AI 使用 CPU，没有 Metal；135M 示例模型不适合作为可靠的 MCP 工具调用模型。

[快速上手](QUICK_START.zh-Hans.md) · [Hugging Face／llama.cpp／MCP](AI_QUICK_START.zh-Hans.md) · [镜像更新](IMAGE_UPDATES.md)
