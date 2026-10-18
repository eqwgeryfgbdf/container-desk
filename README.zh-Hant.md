# Container Desk 0.1.3 — 開發者預覽版

[English](README.md) · [中文（繁體）](README.zh-Hant.md) · [中文（简体）](README.zh-Hans.md)

以 macOS 26 SDK 製作的原生 SwiftUI **本機 Apple Container** 管理工具。需要 Apple Silicon、macOS 26 以上，以及已測試的引擎 **1.5.0**。這是獨立開發的應用程式，並非 Apple 產品。

[下載 0.1.3 預覽版](https://github.com/eqwgeryfgbdf/container-desk/releases/tag/v0.1.3-preview) · [完整快速上手教學](docs/QUICK_START.zh-Hant.md) · [三語版本說明](RELEASE_NOTES.md)

**儲存庫維持私人。** 測試者需有儲存庫存取權並登入 GitHub。通過[公開驗收標準](docs/PUBLIC_RELEASE_GATE.md)前不會公開；本版仍是預覽版。

## 五分鐘開始嘗試

1. 在 Release 下載 DMG，以及選用的 `Container-Desk-0.1.3-Quick-Start.zip`，使用 `SHA256SUMS.txt` 核對檔案。
2. 把 **Container Desk.app** 拖到「應用程式」。本版僅有 ad hoc 簽章，沒有 Developer ID 或 Apple 公證；遇到 macOS 阻擋時，請依[安裝教學](docs/QUICK_START.zh-Hant.md)處理。
3. 到「容器引擎」連接或安裝支援的官方 Apple Container。App 與引擎分開下載，管理員授權由 macOS 處理。
4. 解壓入門包，在該資料夾開啟終端機：

```sh
bash quick-test.sh --check
bash quick-test.sh --run
```

第一個命令唯讀。第二個以專用 BusyBox 容器在 `127.0.0.1:18080` 提供網頁，驗證 HTTP、exec／日誌存取、停止重啟與檔案保留，再清理自己建立的資源。不需要 Xcode、Python 或 sudo。使用 `--run --keep` 可保留容器，在 App 裡操作後依輸出指令清理。教學另有全介面的 Python 網頁服務與簡單專案匯入範例；快速測試不代表全部介面或安裝流程已驗收。

## 常用介面與操作影片

### 總覽

![真實 Mac 規格與即時容器統計](docs/images/overview-en.png)

### 容器管理

![容器搜尋、狀態與資源配置](docs/images/containers-en.jpg)

[觀看／下載 58.5 秒實機介紹影片](https://github.com/eqwgeryfgbdf/container-desk/releases/download/v0.1.3-preview/Container-Desk-Overview-zh-Hant.mp4)（繁體字幕）。截圖和影片來自先前的 0.1.2 QA 建置與 macOS 26.7.1，使用真實、可清理的測試資源，主機名稱已遮蔽；不代表 0.1.3 的乾淨安裝或升級驗收。[媒體來源說明](docs/MEDIA.md)。

## 0.1.3 包含的功能

- **容器管理：** 建立、啟動、停止、重啟、檢視與刪除；批量選取和操作確認；CPU 下拉選單、記憶體滑桿／數值輸入、已下載映像選擇。新容器先建立為停止狀態。
- **完整資訊：** 雙擊展開、即時 CPU／記憶體／程序／網路摘要、工作階段圖表、日誌搜尋與匯出、可點擊的 TCP 網址與複製網址。缺少的數據不模擬；網路數字為累計流量。
- **映像與部署：** Docker Hub 搜尋、倉庫映像參照、架構檢查、下載並設定、ARM64 或 AMD64／Rosetta 選擇、Dockerfile 建置、標籤／刪除、OCI 匯入匯出。切換架構不等於轉換二進位檔。
- **檔案與快照：** 瀏覽容器檔案、不覆寫的傳輸、將容器儲存為映像檔。快照不包含掛載資料，環境變數需主動選擇納入。[範圍說明](docs/CONTAINER_SNAPSHOTS.md)。
- **倉庫、網路與儲存卷：** 登入／登出、推送映像，搜尋、建立、參照保護與批量刪除確認。[使用說明](docs/COMPOSE_AND_FILES.md)。
- **專案與 Docker 遷移：** 檢查並匯入支援的 Compose 設定、轉換 Docker 專案為另外的設定檔、選用已安裝的官方 Compose CLI 解析覆寫，再啟動／停止／移除服務。不支援的欄位會阻擋匯入；Docker 本機映像與儲存卷資料需另行遷移。[轉換教學](docs/DOCKER_CONVERSION.md)。
- **原生介面：** 儲存側欄排序、80–150% 內容縮放（⌘+、⌘−、⌘0）、遵循減少動態效果、真實主機規格、英文／繁中／簡中，沒有演示模式。
- **引擎：** 官方來源安裝、手動與選擇加入的自動更新，包含工作負載檢查。安裝限已測試版本並需要系統授權；App 開啟時才執行更新。

## 測試成果與尚待完成

先前完整自動化基準為 **17 組通過、0 失敗**，包含 **56 個原生介面步驟**；另有 5 組依賴外部環境的測試略過。核心、管理、工作流程、安裝模擬與平台測試皆可由腳本重跑；已實測 ARM64 與 AMD64／Rosetta。建立容器視窗的排版卡住問題已修正。本版加入免編譯快速測試與同步顯示打包版本。[自動化教學](docs/AUTOMATED_QA.md) · [本版驗證紀錄](docs/RELEASE_0.1.3_VALIDATION.md)。

第二台 Mac 的乾淨安裝／升級、完整無障礙驗收、60 分鐘長跑與真實私人倉庫驗收仍待完成。短時間壓力基本檢查不等於長跑驗收。AI 模型整合延後；尚無遠端主機管理、內嵌互動終端機、App 關閉後更新或獨立客體核心更新器。檔案解壓只接受限制大小的普通 tar，拒絕壓縮、稀疏及超限封存。安全檢查在涵蓋範圍內未確認高／嚴重漏洞，但不代表保證沒有漏洞。[功能狀態](docs/FEATURE_ROADMAP.md) · [測試回報範本](docs/TEST_REPORT.md)。

## 原始碼、打包與授權

DMG、`preview-source.zip` 與 manifest 對應同一個版本提交。原始碼包含 **Apache-2.0** 授權、資源、腳本與測試。`SHA256SUMS.txt` 涵蓋上傳附件，入門包內的 `BUILD.json` 記錄來源提交。入門包不重複附上 DMG；0.1.2 歷史附件保留以便追溯。

開發者需 Command Line Tools／Xcode 26 與 Python 3：

```sh
bash scripts/test.sh
bash scripts/build.sh
# 先提交所有原始碼變更，再產生同版產物：
bash scripts/package.sh ../outputs
python3 scripts/make-quick-start.py --output ../outputs
```

打包要求乾淨的 Git 工作目錄，Release 標籤必須對應 manifest 的提交。選用的 Developer ID／公證流程已準備，但尚未產出簽署的穩定版。[Apache-2.0 授權](LICENSE) · [公開門檻](docs/PUBLIC_RELEASE_GATE.md)。

## 官方依賴

[Apple Container](https://github.com/apple/container) 為獨立依賴並有自己的授權。官方安裝包按需要下載，未內嵌在 App 中。
