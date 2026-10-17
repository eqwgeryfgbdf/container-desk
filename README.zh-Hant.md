# Container Desk 0.1.2 — 開發預覽版

[English](README.md) · **中文（繁體）** · [中文（简体）](README.zh-Hans.md)

使用 macOS 26 SDK 打造的原生 SwiftUI **本機 Apple Container** 管理工具。需要搭載 Apple Silicon、執行 macOS 26 或更新版本的 Mac。本專案獨立開發，並非 Apple 產品。

[下載開發預覽版](https://github.com/eqwgeryfgbdf/container-desk/releases/tag/v0.1.2-preview) · [公開驗收標準（英文）](docs/PUBLIC_RELEASE_GATE.md) · [測試報告範本（英文）](docs/TEST_REPORT.md)

**公開狀態：尚未達標。** 儲存庫維持私人，直到全部 14 項必要驗收通過且附有證據，並且沒有未解決的嚴重或重大問題。下列自動化與基本流程測試僅涵蓋部分驗收要求。

## 介面截圖

### 總覽

![總覽：實際 Mac 規格與即時容器數量](docs/images/overview-en.png)

### 容器管理

![容器管理：搜尋、狀態及 CPU 與記憶體配額](docs/images/containers-en.jpg)

以上為 macOS 26.7.1 上 0.1.2 QA 應用程式的實際英文介面。總覽僅明確遮蔽電腦名稱；管理頁面篩選出真實的臨時測試容器，截圖後已移除。硬體與容器數值並非模擬資料。截圖不代表下載版 DMG 已通過驗收，也不代表完整驗收完成。[截圖來源說明（英文）](docs/MEDIA.md)。

## GitHub 發行

儲存庫包含原始碼、在地化資源、建置腳本與測試。DMG 下載檔放在 GitHub Releases，不納入 Git 歷史。0.1.2 的乾淨安裝、升級與完整介面互動驗收仍待完成，因此應標示為 **Pre-release（預覽版）**。在 GitHub 發行不代表獲得 Apple 認可或公證。

預覽版打包先執行 `bash scripts/test.sh` 與 `bash scripts/package.sh`，再將產生的 DMG、同版原始碼 ZIP、版本清單與 SHA-256 校驗碼一起附加到對應原始碼標籤的 Release。此流程不需要 Apple Developer 帳號或簽署密鑰。三語發行說明見 [RELEASE_NOTES.md](RELEASE_NOTES.md)。

新的打包流程會產生配對的原始碼 ZIP、記錄原始碼提交的清單與 SHA-256 校驗碼。打包要求 Git 工作目錄沒有未提交修改；建置期間若原始碼改變，就會拒絕產生配對結果。上傳時應提供完整組合，Release 標籤必須指向清單記錄的提交。原始碼 ZIP 包含 Apache-2.0 授權、程式、資源、建置腳本與測試，不含 Git 內部資料及已忽略的建置產物。

| 發行方式 | 應用程式 | 同版原始碼 |
| --- | --- | --- |
| 開發預覽版 | `Container-Desk-VERSION-arm64-preview.dmg` | `Container-Desk-VERSION-preview-source.zip` |
| 簽署與公證發行流程 | `Container-Desk-VERSION-arm64.dmg` | `Container-Desk-VERSION-source.zip` |

簽署流程已準備，但尚未產生正式發行：目前沒有 Developer ID 憑證，必要驗收也尚未完成。檔名或打包成功本身不代表穩定版本。既有 0.1.2 Release 附件維持原樣；配對產物流程適用於新打包的檔案。

## 授權

Container Desk 採用 [Apache-2.0](LICENSE)。Apple Container 是獨立相依項目，適用其自身授權；需要時才下載官方安裝程式，本專案不內附該套件。授權完整條文以英文 LICENSE 為準。

## 安裝

開啟 `Container-Desk-0.1.2-arm64-preview.dmg`，將 **Container Desk.app** 拖曳至 **Applications（應用程式）**。此開發版使用 ad hoc 簽章，沒有 Developer ID 憑證或 Apple 公證。不加入 Apple Developer Program 仍可透過 GitHub Releases 分享預覽版，但 GitHub 不會改變 macOS Gatekeeper 檢查：下載後可能無法開啟。Developer ID 簽署與公證可作為後續發行改善。

應用程式會連線至既有引擎。若尚未安裝，開啟 **Container Engine（容器引擎）**，檢查官方版本，再選擇 **Install Apple Container（安裝 Apple Container）**。管理員授權由 macOS 處理，應用程式不收集管理員密碼。首次安裝也會由 Apple CLI 下載其建議的 Kata Containers Linux 客體核心。此 DMG 不內附官方引擎套件。

## 0.1.2 更新內容

- 新增明確的遷移流程：將已識別的個人使用者安裝轉為 `/usr/local` 下的**相同官方版本**，保留原始檔案與預設使用者資料目錄。需要引擎閒置、`/usr/local` 尚未安裝、來源執行檔具有 Apple 簽章，且版本已通過相容驗證。不支援任意自訂配置，也不修改終端機 PATH。
- 安裝順序已獨立測試：停止引擎前先驗證下載，變更前再次檢查工作負載，失敗時嘗試恢復服務，不將驗證失敗顯示為成功。服務恢復不等於執行檔或資料回復舊版。
- 處理引擎已停止的狀態、拒絕降版、區分管理員取消授權，避免在已授權安裝程式寫入檔案時將其終止。
- 新增 `scripts/release.sh`，包含 Developer ID 簽署、強化執行環境、時間戳記、公證、公證票證附加及掛載後的 Gatekeeper 檢查。`--check` 僅檢查本機條件，不上傳。沒有簽署憑證時無法產生簽署與公證版本，但仍可建立 GitHub 預覽版。
- 保留 0.1.1 控制項：CPU 下拉選單、同步的記憶體滑桿與整數欄位、已下載映像檔下拉選單。已移除演示模式。

## 驗收證據

已通過 29 項核心檢查、13 項隔離的安裝順序與恢復情境，以及 179 組三語文案檢查。實際 `Store.create` 使用選定的本機映像檔、2 顆 CPU 與 768 MiB 記憶體建立停止狀態的容器，隨後移除。建立、啟動、日誌、資源統計、停止及刪除的基本流程已通過。真實官方版本預檢識別出本機遷移需求，並在有工作負載運行時拒絕執行。既有 8 個工作負載狀態均保持不變。

官方簽署套件只在工作目錄展開，沒有執行系統安裝。套件內 CLI 雜湊與目前自訂配置中的 CLI 相同，Apple 指定簽章驗證通過，展開的 CLI 回報版本 1.5.0。這是套件內容驗證，不代表乾淨安裝或實際遷移已通過。

## 功能

目前原始碼新增容器檔案瀏覽、拒絕覆寫的上下載、Registry 登入／登出與映像檔推送，以及可預覽確認的 Compose 專案匯入、啟動、停止及移除。Compose 支援明確列出的子集合，包含相依服務就緒檢查、保留命名儲存卷及受管理的服務名稱對照；不支援的欄位會直接拒絕。[操作與相容範圍](docs/COMPOSE_AND_FILES.md)。既有下載檔尚未包含這些功能。

目前原始碼也加入「**轉換 Docker 專案…**」：選擇 Compose、Dockerfile 或專案資料夾，檢查相容性後另存設定並匯入。不支援的需求會阻擋轉換；將自動重啟改為手動管理須明確勾選。保留原檔與 Docker 工作負載；儲存卷資料及僅存在 Docker 的本機映像檔需要另外遷移。[轉換指南與限制](docs/DOCKER_CONVERSION.md)。既有下載檔維持原樣。

Docker 轉換現在可使用已安裝的官方 Compose CLI 解析覆寫檔、YAML 範本與環境檔案，並支援多網路／別名、建置參數及目標。**映像檔 → 下載與部署…** 可貼上 Docker Hub 連結或 Registry 映像檔名稱，驗證 arm64 映像檔後進入設定。完整保留資料的無痛轉移仍未完成，詳見[轉移驗收條件](docs/MIGRATION_ACCEPTANCE.md)。

**統一下載與部署：** 映像檔頁面改用單一「**下載與部署…**」入口。搜尋儲存庫、查看可用平台，選擇 ARM64（優先）或 AMD64／Rosetta，再選擇只下載或下載並設定。所選架構會帶入容器設定。切換版本不是二進位轉換；原生 ARM64 重建需要原始碼與 Dockerfile。

**批量選取：** 容器、映像檔、網路與儲存卷加入逐列核取方塊、全選目前結果及取消選取；也支援 Command / Shift 點選。選取範圍跟隨目前篩選結果。容器可批次啟動、停止、重新啟動或刪除；資源刪除前列出全部所選項目，逐項檢查使用狀態與保護規則，並回報結果。

**導覽與容器快照：** 側邊欄改名為「專案」，可拖曳排序並儲存順序，右鍵可移動或還原；專案空白提示已置中。容器操作新增「將容器儲存為映像檔…」，可先保存容器內的檔案修改，再選擇推送到自己的倉庫。不包含掛載資料，環境變數需主動勾選。詳見[快照範圍](docs/CONTAINER_SNAPSHOTS.md)。

目前原始碼新增映像檔下載／建置／標籤／刪除與 OCI 封存檔匯入匯出、網路／儲存卷建立與受保護刪除、容器重新啟動、JSON 設定檢查及外部終端機入口。建立容器可選網路／儲存卷並設定進階指令。長時間操作有即時輸出，可在背景繼續或取消；也修正了記憶體拉桿造成的視窗卡住問題。詳見[功能狀態與後續基本功能](docs/FEATURE_ROADMAP.md)。這些變更**尚未包含在既有 `v0.1.2-preview` 下載檔**。

目前原始碼也加入多選容器批次操作（先確認清單）、多組 TCP／UDP 連接埠與資料夾／儲存卷掛載，以及可搜尋、切換應用程式／開機來源、複製和匯出的日誌快照。批次作業會逐項回報結果，拒絕狀態已改變或不適用的操作。既有下載檔尚未包含這些新增功能。

頁面與資訊／日誌分頁採用短暫淡入淡出；展開詳細資訊及縮放使用可中斷的平順過渡。自訂動畫遵循 macOS「減少動態效果」，定期指標／日誌更新不觸發動畫。這些原始碼更新尚未包含於既有 `v0.1.2-preview` 下載檔。

目前原始碼支援主內容區 80%～150% 縮放：**⌘+**（也支援 **⌘=**）放大、**⌘−** 縮小、**⌘0** 還原至 100%。也可使用「顯示方式」選單或右下角比例選單；應用程式會記住比例，較窄的視窗可水平捲動。原生側邊欄、工具列及對話框維持標準尺寸。既有 `v0.1.2-preview` 下載檔尚未包含此功能。

目前原始碼的展開頁已加入即時 CPU、記憶體、程序與網路摘要、個別容器趨勢圖（本次 App 工作階段最近 120 次實際取樣）、連接埠／配置／掛載分區及全寬日誌檢視。缺少的資料不補為零；網路數值為累計流量而非頻寬。既有 `v0.1.2-preview` 下載檔尚未包含此儀表板。

目前原始碼支援雙擊容器列，或從右鍵選單選擇「展開容器詳細資訊」，在整個視窗內容區顯示資訊與日誌。點擊「返回容器清單」或按 Esc 可恢復清單、選取項目與原先的側邊欄顯示狀態。既有 `v0.1.2-preview` 下載檔尚未包含此功能。

目前原始碼新增可點擊的 TCP 連接埠對應，在預設瀏覽器開啟主機端網址，並提供右鍵「複製網址」。預設使用 HTTP；容器端 443 使用 HTTPS。綁定所有介面的位址會轉為本機迴路位址，UDP 維持文字。服務本身須支援 HTTP／HTTPS。既有 `v0.1.2-preview` 下載檔尚未包含此功能。

- 原生側邊欄、容器表格、詳細資訊面板、搜尋與狀態篩選、分組表單、工具列及系統外觀。
- 真實本機容器狀態、建立／啟動／停止／刪除、日誌、CPU 差值取樣與記憶體用量。發布的連接埠預設僅綁定本機迴路位址；新容器建立後維持停止。
- 實際 Mac 規格：機型、晶片、CPU 核心、實體記憶體、macOS 與組建、架構，以及家目錄所在磁碟容量與可用空間。無法取得的值保持不可用，不保留硬體序號或 UUID。
- 映像檔、網路與儲存卷：可搜尋的管理清單、設定檢查與刪除前參照檢查（目前原始碼）。
- 以英文為基底，提供簡體中文及繁體中文；切換後即時更新應用程式內容。系統管理的選單依 macOS 設定。
- 主機及容器資料均取自實際環境，已移除演示模式與範例資料。
- 檢查官方穩定版；安裝前驗證簽署套件 URL、大小、SHA-256、Apple Containerization 安裝程式身分與 macOS 套件評估結果。
- 應用程式開啟時提供手動更新及自行啟用的自動更新。預設開啟自動檢查、關閉自動安裝。安裝要求版本已驗證且沒有運行中的容器，仍需系統授權。

## 預覽版限制

目前僅將 Container **1.5.0** 列為相容版本。較新版本會顯示資訊，但通過測試前不安裝；自動模式不代表無條件支援未來版本。不覆寫自訂檔案。已識別的 `~/.local/bin/container` 包裝腳本可在閒置時明確遷移至相同官方版本，保留原安裝。其他自訂配置仍須使用原安裝方式。目前沒有特權背景輔助程式、關閉應用程式後的排程、遠端主機管理、內嵌終端機、完整資源編輯器、略過版本偏好或獨立客體核心更新器。

自動化測試已整合為單一入口：`python3 scripts/qa.py --live --ui`，產生 JSON、JUnit、日誌與資源前後比對，涵蓋真實引擎測試及原生介面回歸。詳見[自動化指南](docs/AUTOMATED_QA.md)與[本次測試結果](docs/QA_RESULTS.md)。第二台 Mac 的乾淨安裝、真實升級、私人倉庫登入成功、完整無障礙／視覺驗收及 60 分鐘穩定性門檻仍待完成。AI 模型部署延後，下一階段先以輕量本機模型試驗。既有下載檔維持先前限制。

## 建置與測試

建置現在使用 Swift Package Manager 與固定版本 Yams 6.2.2，首次建置會下載此相依套件。必要授權聲明隨 App 與 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) 一併提供。

安裝 Apple Xcode 26 或 Command Line Tools 26（含 macOS 26 SDK），以及 Python 3。Yams 是固定版本的 Swift 套件相依項目。

```sh
bash scripts/test.sh
bash scripts/build.sh
bash scripts/package.sh
```

應用程式輸出至 `../work/build/Container Desk.app`，DMG 輸出至 `../outputs`。`Package.swift` 可供 Xcode 瀏覽原始碼；完整 `.app`（含 Info.plist 與在地化資源）請使用建置腳本。`Resources/Localizable.xcstrings` 由 `scripts/make_catalog.py` 產生，打包時轉為 `.strings` 資源；修改翻譯後須重新產生。

若要自行重跑整合基本流程測試，一起編譯 `Sources/Models.swift`、`Sources/ProcessRunner.swift` 與 `Tests/IntegrationSmoke.swift`，再傳入 CLI 路徑及**既有且含 `/bin/sh` 的本機映像檔**。測試只建立及移除 UUID 命名的測試容器。

如需 Developer ID 簽署與公證版本，將 `SIGNING_IDENTITY` 設為已安裝的 Developer ID Application 憑證身分，並將 `NOTARY_PROFILE` 設為既有的 notarytool 鑰匙圈設定名稱，再執行 `bash scripts/release.sh`。不要把密碼、私鑰或 API 密鑰寫入原始碼。腳本僅在公證通過、附加票證、DMG 驗證及 Gatekeeper 檢查成功後回報完成。發行前仍須完成乾淨安裝、更新、無障礙與視覺驗收。

## 引用

- [Apple Container](https://github.com/apple/container)
