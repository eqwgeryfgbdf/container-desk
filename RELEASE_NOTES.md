# Container Desk 0.1.2 — Developer Preview

[English](#english) · [中文（繁體）](#繁體中文) · [中文（简体）](#简体中文)

## English

Native SwiftUI manager for local **Apple Container** on Apple Silicon Macs running macOS 26 or later. This is an independent developer preview, not an Apple product or a verified stable release.

### Features

- Actual Mac specifications and live container status, metrics and logs.
- Create, start, stop and delete containers; CPU dropdown, synchronized memory slider/numeric input, and downloaded-image dropdown.
- English, Simplified Chinese and Traditional Chinese interfaces; no demo mode.
- Official engine installation/update workflow with workload protection and explicit same-version migration for recognized per-user installations.
- Read-only image, network and volume inventories.

### Verification and limitations

29 core checks, 13 isolated installer workflow tests, real container allocation and lifecycle smoke tests passed. The isolated installer tests simulate external operations; they do not prove a completed clean system install. Clean installation, upgrade and full interactive UI/accessibility acceptance remain pending. Suspected major issue **UI-001**: the QA creation sheet became unresponsive with the main thread in SwiftUI layout. Only Apple Container **1.5.0** is on the tested compatibility list; other updates are deferred.

**Ad hoc signed; no Developer ID or Apple notarization. macOS may block the downloaded app.** There is no remote-host management, interactive terminal, closed-app updater or independent guest-kernel updater. The repository remains private until all required acceptance gates pass with no unresolved critical/major defects. This Release stays marked **Pre-release**.

### Downloads and testing

- `Container-Desk-0.1.2-arm64-preview.dmg`: application installer image.
- `Container-Desk-0.1.2-Test-Kit.zip`: the same DMG, an older source snapshot, `Check-Mac.command`, testing instructions and checksums. The script inspects the Mac and writes a local report; it does not install software, stop services or upload reports. It is optional for normal installation and may be removed from Releases after acceptance evidence is saved.
- `SHA256SUMS.txt`: checksums for the DMG and Test Kit ZIP.
- GitHub-generated source archives correspond to the `v0.1.2-preview` tag, not current `main`.

On the second test Mac, read `先讀我.md` in the Test Kit before running `Check-Mac.command`; report the result and any failed step without passwords or private keys. The Test Kit instructions are currently in Traditional Chinese.

Current `main` uses **Apache-2.0** and includes updated screenshots and multilingual READMEs. The existing source tag and Test Kit predate the license/documentation additions; their archives have not been replaced. New packaging produces a matching source ZIP, source-commit manifest and checksums alongside the DMG. These new paired packages are not assets of this existing Release.

[English README](https://github.com/eqwgeryfgbdf/container-desk/blob/main/README.md) · [Acceptance criteria](https://github.com/eqwgeryfgbdf/container-desk/blob/main/docs/PUBLIC_RELEASE_GATE.md)

## 繁體中文

原生 SwiftUI **本機 Apple Container** 管理工具，適用於 Apple Silicon、macOS 26 或更新版本。這是獨立開發的預覽版，並非 Apple 產品或已驗收的穩定版。

### 功能

- 實際 Mac 規格與即時容器狀態、資源統計及日誌。
- 建立、啟動、停止及刪除容器；CPU 下拉選單、同步的記憶體滑桿與數字輸入、已下載映像檔下拉選單。
- 英文、簡體中文與繁體中文介面；已移除演示模式。
- 官方引擎安裝與更新流程，包含工作負載保護，以及已識別個人使用者安裝的明確同版遷移。
- 映像檔、網路與磁碟區唯讀清單。

### 驗證與限制

已通過 29 項核心檢查、13 項隔離的安裝流程測試、實際容器配額與生命週期基本流程測試。隔離安裝測試模擬外部操作，不代表已完成乾淨系統安裝。乾淨安裝、升級與完整介面互動／無障礙驗收仍待完成。疑似重大問題 **UI-001**：QA 建立容器視窗無回應，主執行緒停留在 SwiftUI 排版。目前相容性測試清單僅含 Apple Container **1.5.0**，其他版本更新暫緩。

**僅有 ad hoc 簽章，沒有 Developer ID 或 Apple 公證；下載後可能被 macOS 阻擋。** 尚未提供遠端主機管理、互動終端機、關閉應用程式後的更新或獨立客體核心更新器。全部必要驗收通過且沒有未解決的嚴重／重大問題前，儲存庫保持私人；此 Release 維持 **Pre-release（預覽版）**。

### 下載與測試

- `Container-Desk-0.1.2-arm64-preview.dmg`：應用程式安裝映像檔。
- `Container-Desk-0.1.2-Test-Kit.zip`：相同 DMG、較早的原始碼快照、`Check-Mac.command`、測試說明與校驗碼。腳本檢查 Mac 並產生本機報告，不會安裝軟體、停止服務或上傳報告。一般安裝不需要測試包；驗收證據保存後可從 Releases 移除。
- `SHA256SUMS.txt`：DMG 與 Test Kit ZIP 的校驗碼。
- GitHub 自動產生的原始碼壓縮檔對應 `v0.1.2-preview` 標籤，並非目前的 `main`。

在第二台測試 Mac 上，先閱讀測試包的 `先讀我.md`，再執行 `Check-Mac.command`；回報結果與失敗步驟即可，不提供密碼或私鑰。測試包內的說明目前使用繁體中文。

目前 `main` 採用 **Apache-2.0**，並包含更新的截圖與多語言 README。既有原始碼標籤及 Test Kit 早於這些授權與文件更新，壓縮檔尚未替換。新的打包流程會隨 DMG 產生同版原始碼 ZIP、原始碼提交清單與校驗碼；新的配對包尚未附加至本 Release。

[繁體中文 README](https://github.com/eqwgeryfgbdf/container-desk/blob/main/README.zh-Hant.md) · [驗收標準（英文）](https://github.com/eqwgeryfgbdf/container-desk/blob/main/docs/PUBLIC_RELEASE_GATE.md)

## 简体中文

原生 SwiftUI **本机 Apple Container** 管理工具，适用于 Apple Silicon、macOS 26 或更新版本。这是独立开发的预览版，并非 Apple 产品或已验收的稳定版。

### 功能

- 实际 Mac 配置与实时容器状态、资源统计及日志。
- 创建、启动、停止及删除容器；CPU 下拉菜单、同步的内存滑块与数字输入、已下载镜像下拉菜单。
- 英文、简体中文与繁体中文界面；已移除演示模式。
- 官方引擎安装与更新流程，包含工作负载保护，以及已识别个人用户安装的明确同版本迁移。
- 镜像、网络与卷的只读列表。

### 验证与限制

已通过 29 项核心检查、13 项隔离的安装流程测试、实际容器配额与生命周期基本流程测试。隔离安装测试模拟外部操作，不代表已完成全新系统安装。全新安装、升级与完整界面交互／无障碍验收仍待完成。疑似重大问题 **UI-001**：QA 创建容器窗口无响应，主线程停留在 SwiftUI 布局。目前兼容性测试列表仅含 Apple Container **1.5.0**，其他版本更新暂缓。

**仅有 ad hoc 签名，没有 Developer ID 或 Apple 公证；下载后可能被 macOS 阻止。** 尚未提供远程主机管理、交互终端、关闭应用后的更新或独立客体内核更新器。全部必要验收通过且没有未解决的严重／重大问题前，仓库保持私有；此 Release 保持 **Pre-release（预览版）**。

### 下载与测试

- `Container-Desk-0.1.2-arm64-preview.dmg`：应用安装镜像文件。
- `Container-Desk-0.1.2-Test-Kit.zip`：相同 DMG、较早的源代码快照、`Check-Mac.command`、测试说明与校验和。脚本检查 Mac 并生成本机报告，不会安装软件、停止服务或上传报告。一般安装不需要测试包；验收证据保存后可从 Releases 删除。
- `SHA256SUMS.txt`：DMG 与 Test Kit ZIP 的校验和。
- GitHub 自动生成的源代码压缩包对应 `v0.1.2-preview` 标签，并非当前的 `main`。

在第二台测试 Mac 上，先阅读测试包中的 `先讀我.md`，再运行 `Check-Mac.command`；报告结果与失败步骤即可，不提供密码或私钥。测试包内的说明目前使用繁体中文。

当前 `main` 采用 **Apache-2.0**，并包含更新的截图与多语言 README。现有源代码标签及 Test Kit 早于这些许可证与文档更新，压缩包尚未替换。新的打包流程会随 DMG 生成同版本源代码 ZIP、源代码提交清单与校验和；新的配对包尚未附加到本 Release。

[简体中文 README](https://github.com/eqwgeryfgbdf/container-desk/blob/main/README.zh-Hans.md) · [验收标准（英文）](https://github.com/eqwgeryfgbdf/container-desk/blob/main/docs/PUBLIC_RELEASE_GATE.md)

## Reference / 引用

- [Apple Container](https://github.com/apple/container)
