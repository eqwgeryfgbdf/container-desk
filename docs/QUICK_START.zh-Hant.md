# 快速上手 — Container Desk 0.1.3 預覽版

[English](QUICK_START.md) · **中文（繁體）** · [中文（简体）](QUICK_START.zh-Hans.md)

不必編譯，就能試用真正的本機容器服務。目前儲存庫仍為私人；測試者需要先取得儲存庫存取權，並登入 GitHub。下載頁顯示 404 時，請先確認登入帳號與權限。

## 1. 下載哪個檔案？

前往 [v0.1.3-preview](https://github.com/eqwgeryfgbdf/container-desk/releases/tag/v0.1.3-preview)。

| 檔案 | 用途 |
|---|---|
| `Container-Desk-0.1.3-arm64-preview.dmg` | 安裝 Mac App，不需要 Xcode。 |
| `Container-Desk-0.1.3-Quick-Start.zip` | 選用的入門包：三語教學、快速測試腳本、兩個 `.command` 啟動器及範例專案，不重複包含 DMG。 |
| `Container-Desk-0.1.3-preview-source.zip` | 同版 Apache-2.0 原始碼、建置腳本和完整自動化測試。 |
| `Container-Desk-0.1.3-preview-manifest.json` | 原始碼提交、檔案樹與主要產物雜湊。 |
| `SHA256SUMS.txt` | 所有附件的 SHA-256（不包含校驗檔自己）。 |
| `Container-Desk-Overview-zh-Hant.mp4` | 58.5 秒實機操作影片、繁體字幕；來自前一個 QA 建置，不代表安裝／升級驗收。 |

需求：Apple Silicon、macOS 26 以上、可下載映像檔的網路，以及 **Apple Container 1.5.0**。不支援 Intel Mac。只有原始碼建置／完整 QA 需要 Xcode 或 Command Line Tools 26 與 Python 3；快速測試只用內建 Bash、curl 和已安裝的引擎。

全部附件放同一資料夾後，可執行 `shasum -a 256 -c SHA256SUMS.txt`。若只下載 DMG，請執行 `shasum -a 256 Container-Desk-0.1.3-arm64-preview.dmg`，比對校驗檔內相應的完整雜湊；缺少選用附件不代表 DMG 損壞。

## 2. 安裝與連線

1. 開啟 DMG，把 **Container Desk** 拖到 **應用程式**，再從應用程式啟動。更新舊版前先結束舊 App；完成後退出 DMG。
2. 此預覽版只有 ad hoc 簽章，尚無 Developer ID 或 Apple 公證，首次啟動可能被 macOS 阻擋。確認信任這份下載後，依 [Apple 的單一 App 開啟說明](https://support.apple.com/en-nz/102445)檢查「系統設定 → 隱私權與安全性 → 強制打開／仍要打開」。不要全域關閉 Gatekeeper。若沒有單一 App 允許選項，請回報完整提示。
3. 開啟左側 **容器引擎**。若尚未安裝引擎，可使用 App 的官方來源安裝流程，或從 [Apple Container](https://github.com/apple/container)安裝支援版本；macOS 管理員授權由你本人確認。App 與引擎是分開安裝的。
4. 視需要啟動引擎，等狀態變成「已連線」。在總覽核對真實 CPU、記憶體及系統版本。遇到無法識別的自訂安裝，先閱讀提示，不要覆寫既有設定。
5. 到設定選擇英文／繁體／簡體介面；CPU 與記憶體範圍取自主機規格。

## 3. 五分鐘快速測試，免編譯

解壓入門包，在該資料夾開啟終端機。先閱讀腳本，再執行：

```sh
bash quick-test.sh --check
bash quick-test.sh --run
```

`--check` 只讀取環境。`--run` 僅在映像不存在時下載官方 `busybox:1.37`，建立 UUID 名稱的測試容器（1 CPU／256 MiB），只將 HTTP 發布至 `127.0.0.1:18080`，驗證網頁回應、exec／日誌存取、停止再啟動及檔案保留，最後刪除該容器和由這次新下載的映像參照。原本已有的映像與其他容器會保留；不安裝／升級引擎、不使用 sudo、不掛載主機資料夾、不全域清除資源、不上傳報告。

預期看到 `PASS:` 且結束代碼為 0。`BLOCKED`／`FAIL` 或非零代碼代表未滿足條件或失敗，不算通過。18080 已被占用時，可加上 `--port 18081`。

想保留服務，在 App 裡操作看看：

```sh
bash quick-test.sh --run --keep
```

腳本會印出精確容器名稱、網址與清理命令。回到 Container Desk 重新整理容器，選取 `cd-quick-…`；雙擊展開資訊、點擊連接埠網址、查看日誌，再從「更多操作 → 檔案」檢視 `/www/index.html`。完成後執行腳本印出的停止／刪除命令；映像沒有其他用途才刪除。`--keep` 會刻意留下運行中的測試服務。

也可在 Finder 開啟 `Check-Mac.command`（唯讀）或 `Run-Quick-Test.command`（實際測試）。啟動器會停留讓你閱讀結果；下載的腳本可能需要 macOS 允許，亦可使用上述明確的終端機命令。此測試驗證引擎基本流程，不等於完整 UI、乾淨安裝或升級驗收。

## 4. 全部透過 App 建立網頁服務

1. **映像檔 → 下載與快速部署**。搜尋 `python`，選官方 `library/python`、標籤 `3.13-slim`、Linux ARM64；或在「映像名稱或網址」直接輸入 `docker.io/library/python:3.13-slim`。
2. 按「下載並設定」。名稱 `my-python-web`、CPU `1`、記憶體 `512 MiB`；主機連接埠 `18081`、容器連接埠 `8080`、TCP。確認主機埠未占用，保留預設網路，不加入主機掛載或密鑰。
3. 進階設定的入口程式填 `python3`。命令參數**一行一個**，不要加 Shell 引號：

```text
-u
-m
http.server
8080
--bind
0.0.0.0
```

4. 建立後容器保持**已停止**；選取後按啟動。
5. 點擊連接埠連結，或開啟 `http://127.0.0.1:18081/`。看到目錄列表表示實際服務可連線，日誌應出現請求。失敗時先看容器狀態與日誌。
6. 雙擊容器進入完整資訊；Command `+`／`-` 調整介面大小，查看 CPU／記憶體、日誌及檔案。核取方塊可批次選取，執行前先核對目標清單。
7. 完成後停止並刪除 **my-python-web**。映像是獨立資源，確認沒有其他容器需要才移除 Python 映像。

## 5. 專案、倉庫與檔案

- **專案**：匯入入門包的 `docs/examples/quick-web.yaml`（或[這份範例](examples/quick-web.yaml)），閱讀驗證／相容性報告後啟動。使用本機 `18082` 埠、小型 BusyBox 網頁服務，沒有主機掛載。開啟 `http://127.0.0.1:18082/`，應顯示 `Container Desk project works`。完成後停止／移除專案並檢查保留資源。Docker 轉換只涵蓋已支援的設定，不支援的欄位會列出；詳見[轉換指南](DOCKER_CONVERSION.md)。
- **映像倉庫**：先使用自己有權限的測試倉庫；登入透過官方 CLI 儲存憑證，標記／推送都是明確操作。可搜尋公開映像，不代表有 Docker Hub 推送權限。私人 HTTPS 倉庫登入成功仍須依帳號環境驗收。
- **檔案**：先用測試容器試傳輸至空白目的地。限制為 4 GiB／10,000 個項目及一般未壓縮 tar；特殊壓縮、稀疏檔案或不支援的中繼資料會拒絕。既有目的地檔案受保護。詳見[檔案與專案指南](COMPOSE_AND_FILES.md)。

## 排除問題與回報

| 狀況 | 處理方式 |
|---|---|
| GitHub 404 | 確認使用已獲此私人儲存庫邀請的帳號登入。 |
| App 無法開啟 | 核對 Apple Silicon、macOS 26、DMG 完整校驗碼，記錄系統提示。 |
| 未連線／找不到 CLI | 在容器引擎頁確認官方引擎的安裝與啟動狀態，不要刪除引擎資料。 |
| 連接埠已占用 | 改用 18081 或其他空閒埠，不要停止不相關的服務。 |
| 搜尋／下載失敗 | 檢查網路、DNS、倉庫限制與認證，排除原因後重試。 |
| 只有 AMD64 映像 | 優先選 ARM64；AMD64 需相容的 Rosetta 設定，改標籤不是二進位轉換。 |
| 專案欄位不支援 | 查看驗證報告及[支援範圍](COMPOSE_AND_FILES.md)，不可假設所有 Docker 專案原樣可用。 |
| 測試清理失敗 | 依腳本列出的 UUID 名稱只檢查該測試資源，不要全域 prune。 |

回報 App 版本、macOS／晶片、引擎版本、操作步驟、預期／實際結果及 `PASS`／`FAIL` 輸出即可。分享前移除電腦名稱、私人路徑、環境變數內容、密碼與 Token。腳本不會自動傳送報告。

開發者可先 `bash scripts/build.sh`，再 `python3 scripts/qa.py --live --ui`，請先讀[完整自動化說明](AUTOMATED_QA.md)。它會下載測試映像並操作前景 App，執行期間不要操作桌面。既有基線為 17 組通過／0 失敗、56 步 UI 通過；第二台 Mac 的安裝／升級、完整無障礙／視覺檢查及 60 分鐘穩定性仍待驗收。AI 模型延後。
