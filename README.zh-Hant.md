# Container Desk 1.0.0

[English](README.md) · [中文（繁體）](README.zh-Hant.md) · [中文（简体）](README.zh-Hans.md)

專為 Apple Silicon、macOS 26 以上打造的 **Apple Container 原生 SwiftUI 管理工具**。獨立開源專案，並非 Apple 官方 App。應用程式名稱為 **Container Desk**；官網標題 **Apple Container Desk** 說明其管理的引擎。

[下載 1.0.0 DMG](https://github.com/eqwgeryfgbdf/container-desk/releases/download/v1.0.0/Container-Desk-1.0.0-arm64.dmg) · [官網](https://container.emo-lab.com/) · [版本說明](docs/RELEASE_NOTES_1.0.0.md) · [快速上手](docs/QUICK_START.zh-Hant.md)

1.0 整合現有容器管理、專案、AI／MCP 與映像更新功能。安裝檔、Dock 與 App 側欄統一使用最新 **VM＋套件 Logo**，並納入三語教學與官網原始碼。

**發行方式：**只有 ad hoc 簽章，沒有 Developer ID 或 Apple 公證。需要 Apple Silicon、macOS 26 以上；測試僅在開發者的 M4 Mac mini、macOS 26.7.1、Apple Container 1.5.0 進行。第二台 Mac 測試仍延後。1.0 版本號不代表所有引擎、Docker 專案或模型都相容。[本版驗證與限制](docs/RELEASE_1.0.0_VALIDATION.md)。

## 快速開始

1. 開啟 DMG，先結束舊版 Container Desk，再拖入「應用程式」並確認取代。若被 macOS 阻擋，依[單一 App 安裝教學](docs/QUICK_START.zh-Hant.md)處理，不要全域停用安全保護。
2. 在「容器引擎」連接 Apple 官方 Container。引擎需另外安裝，來源為 Apple 官方發布頁。
3. 到「映像檔 → 下載與部署」，搜尋 Docker Hub 或輸入映像參照；選擇合適的 ARM64 映像，下載後設定 CPU、記憶體與連接埠。
4. 建立後容器保持停止，按「啟動」才執行。雙擊可展開資訊、查看日誌，並點擊已發布的 TCP 網頁連接埠開啟服務。
5. 本機 AI 請看 [Hugging Face／llama.cpp／MCP 教學](docs/AI_QUICK_START.zh-Hant.md)。可先用 SmolLM2 135M Q4_K_M（約 105 MB）。文字推論與工具調用是不同能力；該小模型未通過工具調用測試。

## 完整功能範圍

| 類別 | 1.0 提供內容 |
| --- | --- |
| 容器 | 建立、啟動、停止、重啟、刪除、經確認的批次操作、選擇性複製設定、真實主機規格與資源資訊。 |
| 介面 | 原生 SwiftUI、英文／繁體／簡體、側欄排序、展開資訊、80–150% 縮放、尊重減少動態效果的過渡。 |
| 映像檔 | Docker Hub 搜尋、架構檢查、下載與部署、Dockerfile 建置、標籤、OCI 匯入匯出、更新與經確認的容器替換／回復。 |
| 儲存與檔案 | 網路、儲存卷、選擇性清理、檔案瀏覽與傳輸、容器儲存為映像；不全域清理，快照不包含掛載資料。 |
| 倉庫與專案 | Registry 登入／推送、HTTPS 倉庫目錄與標籤、支援範圍內的 Compose 匯入、Docker 專案轉換及不支援欄位提示。 |
| 本機 AI／MCP | 搜尋公開單檔 GGUF、固定版本與 SHA-256 下載驗證、llama.cpp CPU 部署、能力測試、經確認的 MCP 工具執行。 |
| 引擎 | 官方來源安裝；有工作負載檢查的手動／自願啟用自動更新，僅 App 開啟時執行。 |

## 快速測試

先下載並檢查腳本內容，再執行：

```sh
curl -fL https://raw.githubusercontent.com/eqwgeryfgbdf/container-desk/v1.0.0/scripts/quick-test.sh -o quick-test.sh
bash quick-test.sh --check
bash quick-test.sh --run
```

`--check` 唯讀；`--run` 建立、驗證並移除自己的暫存 localhost HTTP 容器，不安裝 AI 模型。[自動化說明](docs/AUTOMATED_QA.md)。

## 截圖與教學影片

![實際主機資訊總覽](docs/images/overview-en.png)
![容器管理](docs/images/containers-en.jpg)
![建立容器設定](docs/images/create-en.png)

以上為 0.2.0 歷史介面截圖，主機名稱已遮蔽，並非本版新測試證明。[素材來源](docs/MEDIA.md)。[90 秒 AI 教學](docs/video/README.md)使用實際介面截圖、旁白與操作解說，並非連續部署實錄。

## 升級與限制

- 取代前先結束舊 App。Apple Container 的容器、映像與儲存卷仍在引擎原本的資料位置。
- 1.0 使用正式 App 識別 `local.containerdesk.app`；0.3 預覽版使用 `local.containerdesk.ai-development`。預覽版的介面偏好、AI 選取記錄不會自動搬移，必要時重新選取既有 GGUF 或模型快取；不需刪除引擎資料。
- Compose 僅支援已驗證的設定子集。Docker 本機映像及持久資料需另外搬移；選擇架構不會轉換二進位程式。尚無遠端主機管理、內嵌終端機或 App 關閉後的背景更新。
- 本機 AI 在 Linux VM 使用 CPU，沒有 Metal。公開搜尋不處理受限制或分割 GGUF；模型品質與 MCP 相容性不同，連線與模型提出的工具調用都需確認。
- 映像替換會改變容器名稱／IP 並造成停機；保留原容器供回復，但無法還原掛載資料寫入或資料庫遷移。[更新教學](docs/IMAGE_UPDATES.md)。
- 乾淨引擎安裝、真正引擎升級、外部私人 HTTPS 倉庫成功流程與完整人工 VoiceOver 驗收仍未驗證；驗證文件區分本次與歷史結果。

## 原始碼、打包與授權

```sh
bash scripts/test.sh
bash scripts/build.sh
# 提交預計發布的原始碼後再打包：
bash scripts/package.sh ../outputs
```

Release 附件**只有 DMG**；[Apache-2.0](LICENSE) 原始碼可從 GitHub 自動產生的版本封存下載。安裝檔與版本標籤對應同一提交，SHA-256 列在 Release 內。Developer ID／公證流程另備，不等於本次已公證。

[官網原始碼](website/README.md) · [檔案、倉庫與專案](docs/COMPOSE_AND_FILES.md) · [Docker 轉換](docs/DOCKER_CONVERSION.md) · [功能範圍](docs/FEATURE_ROADMAP.md) · [Apple Container 官方來源](https://github.com/apple/container)
