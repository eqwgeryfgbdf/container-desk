# Container Desk releases

## 1.0.0

Consolidated native app, current VM + package icon, container and image workflows, local AI / MCP, three-language documentation and website source. Release downloads contain only the DMG.

[English · 繁體中文 · 简体中文 release notes](docs/RELEASE_NOTES_1.0.0.md) · [Validation and limits](docs/RELEASE_1.0.0_VALIDATION.md)

---

# Container Desk 0.3.0 Preview — Hugging Face, Local AI & Image Updates

[English](#english) · [繁體中文](#繁體中文) · [简体中文](#简体中文)

## English

Search and download public Hugging Face GGUF language models directly in **Local AI**, then run the selected model with llama.cpp in Apple Container. This is a **preview**, not a notarized or broadly hardware-certified stable release. Requires Apple Silicon and macOS 26+; tested with Apple Container 1.5.0 on one M4 Mac mini (16 GiB, macOS 26.7.1).

### Quick start

1. Download the single `Container-Desk-0.3.0-arm64-preview.dmg` asset and install the app. It is **ad hoc signed, without Developer ID or Apple notarization**. If macOS blocks it, use Apple's per-app Privacy & Security opening flow after verifying the download; do not disable Gatekeeper globally.
2. Connect/start the official Apple Container engine. Open **Local AI → Search Hugging Face**, enter a name/publisher or use the small-model shortcut.
3. Choose `bartowski/SmolLM2-135M-Instruct-GGUF`, filter filenames with `Q4_K_M`, then select `SmolLM2-135M-Instruct-Q4_K_M.gguf` (105,454,432 bytes at the tested revision).
4. Review file size, license/model card and estimated memory; click **Select & Download**. The app pins the commit and verifies exact size, GGUF header and SHA-256. No container starts merely by downloading.
5. Try 2 CPUs, 1 GiB and 1,024 context; create/start llama.cpp and test the model. The server image is a separate download (~296 MB compressed for the tested ARM64 image). Inference uses CPU inside the Linux VM, without Metal.
6. For MCP, import an existing server configuration, review its command/URL, connect and choose tools. Run the model compatibility test first, then approve individual proposed tool-call batches. The 135M test model completed text inference but did **not** pass tool calling; the warning is expected.

[Full English tutorial](https://github.com/eqwgeryfgbdf/container-desk/blob/v0.3.0-preview/docs/AI_QUICK_START.md) · [Validation](https://github.com/eqwgeryfgbdf/container-desk/blob/v0.3.0-preview/docs/AI_VALIDATION.md)

### Also included

- Check/download a new image version from **Images**, review affected containers, replace a selected container with preserved supported settings, optionally check HTTP health and roll back failed updates. The original container is retained. Replacement names/IPs change, there is downtime, and rollback does not undo writes to mounted data. [Update guide](https://github.com/eqwgeryfgbdf/container-desk/blob/v0.3.0-preview/docs/IMAGE_UPDATES.md).
- Search results show licenses and model-card links; GGUF files can be filtered by quantization. Same-named models with different content use separate caches. Restricted models require manual Hugging Face access and local-file selection. Split GGUFs, projectors/adapters and files without complete checksums are omitted. GGUF does not guarantee support by the pinned engine or MCP capability.
- Fixed MCP process shutdown hanging; expanded regression, real small-model testing and three-language native UI automation. Tests ran on the owner's device only; second-Mac testing remains deferred.

The Release has **one uploaded asset: the DMG**. Three-language guides, tests and Apache-2.0 source remain in the repository. GitHub's automatic source ZIP/tar archives may also appear; no test ZIP, checksum file or video is uploaded for this version. Previous releases remain unchanged. SHA-256 is included below on the GitHub Release page.

## 繁體中文

在「**本機 AI**」直接搜尋、挑選並下載 Hugging Face 公開 GGUF 語言模型，再透過 Apple Container 執行 llama.cpp。本版為**預覽版**，並非已公證或經多設備驗證的正式版。需要 Apple Silicon、macOS 26 以上；僅在擁有者的 M4 Mac mini（16 GiB、macOS 26.7.1、Apple Container 1.5.0）測試。

### 快速開始

1. 下載唯一安裝附件 `Container-Desk-0.3.0-arm64-preview.dmg`。只有 **ad hoc 簽章，沒有 Developer ID／Apple 公證**；若被 macOS 阻擋，確認下載來源後使用「隱私權與安全性」的單一 App 開啟流程，不要全域關閉 Gatekeeper。
2. 連接／啟動 Apple 官方容器引擎，進入「**本機 AI → 搜尋 Hugging Face**」，輸入名稱或發布者，也可點選輕量模型快捷鍵。
3. 選擇 `bartowski/SmolLM2-135M-Instruct-GGUF`，輸入 `Q4_K_M` 篩選，選 `SmolLM2-135M-Instruct-Q4_K_M.gguf`（受測版本 105,454,432 bytes，約 105 MB）。
4. 查看容量、授權／模型說明與估計記憶體後按「**選擇並下載**」。會固定 commit 並驗證大小、GGUF 標頭及 SHA-256，下載不會自動啟動容器。
5. 輕量測試使用 2 CPU、1 GiB、1,024 上下文，建立並啟動 llama.cpp，再測試模型。伺服器映像另行下載，受測 ARM64 映像壓縮後約 296 MB；Linux VM 內使用 CPU，不支援 Metal。
6. 使用 MCP 時匯入已安裝伺服器的設定，檢查命令／網址，連接並挑選工具。先測試模型相容性，之後逐批確認提議的工具呼叫。此次 135M 模型可完成文字推論，**未通過工具呼叫測試**，出現提示是預期結果。

[完整繁體教學](https://github.com/eqwgeryfgbdf/container-desk/blob/v0.3.0-preview/docs/AI_QUICK_START.zh-Hant.md) · [測試紀錄](https://github.com/eqwgeryfgbdf/container-desk/blob/v0.3.0-preview/docs/AI_VALIDATION.md)

同時加入映像更新、經確認的容器替換、HTTP 健康檢查及失敗回復。原容器會保留，但替換容器的名稱／IP 會改變且有停機時間；回復不會還原掛載資料。修復 MCP 結束程序卡住，補齊三語介面與腳本測試。[映像更新說明](https://github.com/eqwgeryfgbdf/container-desk/blob/v0.3.0-preview/docs/IMAGE_UPDATES.md)。

GGUF 格式不保證引擎或 MCP 相容。受限制模型需自行取得 Hugging Face 權限後選擇本機檔案；目前不提供分割 GGUF、投影器、轉接器及缺少完整校驗資訊的下載。僅在自己的設備測試，第二台 Mac 仍延後。

本版**手動上傳附件只有 DMG**；三語教學、測試與 Apache-2.0 原始碼留在儲存庫。GitHub 自動產生的 source ZIP／tar 仍可能顯示；不另附測試包、校驗檔或影片。舊版本附件不變，DMG 的 SHA-256 直接列在本 Release 下方。

## 简体中文

在“**本地 AI**”直接搜索、选择并下载 Hugging Face 公开 GGUF 语言模型，再通过 Apple Container 运行 llama.cpp。本版为**预览版**，不是已公证或经过多设备验证的正式版。需要 Apple Silicon、macOS 26 以上；仅在拥有者的 M4 Mac mini（16 GiB、macOS 26.7.1、Apple Container 1.5.0）测试。

### 快速开始

1. 下载唯一安装附件 `Container-Desk-0.3.0-arm64-preview.dmg`。只有 **ad hoc 签名，没有 Developer ID／Apple 公证**；若被 macOS 阻止，确认下载来源后使用“隐私与安全性”的单个 App 打开流程，不要全局关闭 Gatekeeper。
2. 连接／启动 Apple 官方容器引擎，进入“**本地 AI → 搜索 Hugging Face**”，输入名称或发布者，也可点击轻量模型快捷键。
3. 选择 `bartowski/SmolLM2-135M-Instruct-GGUF`，输入 `Q4_K_M` 筛选，选择 `SmolLM2-135M-Instruct-Q4_K_M.gguf`（测试版本 105,454,432 bytes，约 105 MB）。
4. 查看容量、授权／模型说明与估计内存后点击“**选择并下载**”。会固定 commit 并验证大小、GGUF 标头及 SHA-256，下载不会自动启动容器。
5. 轻量测试使用 2 CPU、1 GiB、1,024 上下文，创建并启动 llama.cpp，再测试模型。服务器镜像单独下载，测试的 ARM64 镜像压缩后约 296 MB；Linux VM 内使用 CPU，不支持 Metal。
6. 使用 MCP 时导入已安装服务器的设置，检查命令／网址，连接并选择工具。先测试模型兼容性，之后逐批确认提议的工具调用。此次 135M 模型可完成文字推理，**未通过工具调用测试**，出现提示是预期结果。

[完整简体教程](https://github.com/eqwgeryfgbdf/container-desk/blob/v0.3.0-preview/docs/AI_QUICK_START.zh-Hans.md) · [测试记录](https://github.com/eqwgeryfgbdf/container-desk/blob/v0.3.0-preview/docs/AI_VALIDATION.md)

同时加入镜像更新、经确认的容器替换、HTTP 健康检查及失败恢复。原容器会保留，但替换容器的名称／IP 会改变且有停机时间；恢复不会还原挂载数据。修复 MCP 结束进程卡住，补齐三语界面与脚本测试。[镜像更新说明](https://github.com/eqwgeryfgbdf/container-desk/blob/v0.3.0-preview/docs/IMAGE_UPDATES.md)。

GGUF 格式不保证引擎或 MCP 兼容。受限制模型需自行取得 Hugging Face 权限后选择本地文件；目前不提供分割 GGUF、投影器、适配器及缺少完整校验信息的下载。仅在自己的设备测试，第二台 Mac 仍延后。

本版**手动上传附件只有 DMG**；三语教程、测试与 Apache-2.0 源码保留在仓库。GitHub 自动生成的 source ZIP／tar 仍可能显示；不另附测试包、校验文件或视频。旧版本附件不变，DMG 的 SHA-256 直接列在本 Release 下方。

---

[0.2.0 release notes](docs/RELEASE_NOTES_0.2.0.md)
