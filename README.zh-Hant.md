# Container Desk 0.2.0 — 公開版

[English](README.md) · [中文（繁體）](README.zh-Hant.md) · [中文（简体）](README.zh-Hans.md)

以 macOS 26 SDK 製作的原生 SwiftUI **本機 Apple Container** 管理工具。需要 Apple Silicon、macOS 26 以上，以及已測試的引擎 **1.5.0**。這是獨立開發的應用程式，並非 Apple 產品。

[下載 0.2.0 公開版](https://github.com/eqwgeryfgbdf/container-desk/releases/tag/v0.2.0) · [完整快速上手教學](docs/QUICK_START.zh-Hant.md) · [三語版本說明](RELEASE_NOTES.md)

**公開版 0.2.0。** 僅在開發者自己的 M4 Mac mini（16 GiB、macOS 26.7.1、Apple Container 1.5.0）測試。依擁有者決定暫不進行第二台 Mac 測試。本版只有 ad hoc 簽章，沒有 Developer ID／Apple 公證；請先閱讀[驗證範圍及已知限制](docs/RELEASE_0.2.0_VALIDATION.md)。

## 五分鐘開始嘗試

1. 在 Release 下載 DMG，以及選用的 `Container-Desk-0.2.0-Quick-Start.zip`，使用 `SHA256SUMS.txt` 核對檔案。
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

### 建立容器

![CPU / Memory / Image](docs/images/create-en.png)

[觀看實機操作影片](https://github.com/eqwgeryfgbdf/container-desk/releases/download/v0.2.0/Container-Desk-Overview-zh-Hant.mp4)（繁體字幕）。截圖與影片皆為 **0.2.0 在開發者自己的 Mac** 上操作真實測試容器，主機名稱已遮蔽，沒有模擬數據；可能顯示 macOS 錄影指示。媒體不代表乾淨安裝／升級驗收。[來源說明](docs/MEDIA.md)。

## 0.2.0 包含的功能

- **安全複製容器：** 從實際設定建立獨立副本，清除連接埠；環境變數與掛載需選擇加入，掛載預設唯讀，可寫共用需來源已停止。保留原容器。
- **磁碟用量與清理：** 讀取真實使用量，逐項確認可刪除的映像／網路／儲存卷，不做全域 prune。
- **映像預設資訊與倉庫瀏覽：** 建立前查看啟動命令、使用者、工作目錄與宣告連接埠；瀏覽 HTTPS Registry V2 專案／標籤後部署。目錄瀏覽採獨立暫存 Basic 認證，不保證支援所有 Bearer 認證服務。
- **容器管理：** 建立、啟動、停止、重啟、檢視與刪除；批量選取和操作確認；CPU 下拉選單、記憶體滑桿／數值輸入、已下載映像選擇。新容器先建立為停止狀態。
- **完整資訊：** 雙擊展開、即時 CPU／記憶體／程序／網路摘要、工作階段圖表、日誌搜尋與匯出、可點擊的 TCP 網址與複製網址。缺少的數據不模擬；網路數字為累計流量。
- **映像與部署：** Docker Hub 搜尋、倉庫映像參照、架構檢查、下載並設定、ARM64 或 AMD64／Rosetta 選擇、Dockerfile 建置、標籤／刪除、OCI 匯入匯出。切換架構不等於轉換二進位檔。
- **檔案與快照：** 瀏覽容器檔案、不覆寫的傳輸、將容器儲存為映像檔。快照不包含掛載資料，環境變數需主動選擇納入。[範圍說明](docs/CONTAINER_SNAPSHOTS.md)。
- **倉庫、網路與儲存卷：** 登入／登出、推送映像，搜尋、建立、參照保護與批量刪除確認。[使用說明](docs/COMPOSE_AND_FILES.md)。
- **專案與 Docker 遷移：** 檢查並匯入支援的 Compose 設定、轉換 Docker 專案為另外的設定檔、選用已安裝的官方 Compose CLI 解析覆寫，再啟動／停止／移除服務。不支援的欄位會阻擋匯入；Docker 本機映像與儲存卷資料需另行遷移。[轉換教學](docs/DOCKER_CONVERSION.md)。
- **原生介面：** 儲存側欄排序、80–150% 內容縮放（⌘+、⌘−、⌘0）、遵循減少動態效果、真實主機規格、英文／繁中／簡中，沒有演示模式。
- **引擎：** 官方來源安裝、手動與選擇加入的自動更新，包含工作負載檢查。安裝限已測試版本並需要系統授權；App 開啟時才執行更新。

## 測試範圍

自動化涵蓋容器生命週期、資料保留、檔案、映像、專案與轉換、倉庫失敗／本機推送流程及資源保護。新增複製容器、映像資訊、倉庫目錄與三項中度安全修補回歸測試。完整結果、略過項目及長跑數據請看[本版驗證紀錄](docs/RELEASE_0.2.0_VALIDATION.md)；略過不代表通過。

僅在自己的設備上測試。全新引擎安裝、真實舊版升級、外部私人 HTTPS 倉庫成功流程及完整 VoiceOver 人工驗收仍未驗證。AI 延後；Docker 資料與本機映像仍需另行搬移，尚無自動重啟監督、切換／回滾、遠端主機、內嵌終端機或 App 關閉後更新。[功能狀態](docs/FEATURE_ROADMAP.md) · [回報範本](docs/TEST_REPORT.md)。

## 原始碼、打包與授權

DMG、`source.zip` 與 manifest 對應同一個版本提交。原始碼包含 **Apache-2.0** 授權、資源、腳本與測試。`SHA256SUMS.txt` 涵蓋上傳附件，入門包內的 `BUILD.json` 記錄來源提交。入門包不重複附上 DMG；0.1.2 歷史附件保留以便追溯。

開發者需 Command Line Tools／Xcode 26 與 Python 3：

```sh
bash scripts/test.sh
bash scripts/build.sh
# 先提交所有原始碼變更，再產生同版產物：
bash scripts/package.sh ../outputs
python3 scripts/make-quick-start.py --output ../outputs
```

打包要求乾淨的 Git 工作目錄，Release 標籤必須對應 manifest 的提交。選用的 Developer ID／公證流程已準備，本次公開版僅有 ad hoc 簽章。[Apache-2.0 授權](LICENSE) · [公開門檻](docs/PUBLIC_RELEASE_GATE.md)。

## 官方依賴

[Apple Container](https://github.com/apple/container) 為獨立依賴並有自己的授權。官方安裝包按需要下載，未內嵌在 App 中。
