# Container Desk 1.0 — 快速上手

[English](QUICK_START.md) · [繁體中文](QUICK_START.zh-Hant.md) · [简体中文](QUICK_START.zh-Hans.md)

## 1. 系統需求

Apple Silicon、macOS 26 以上，並另外安裝 [Apple 官方 Container](https://github.com/apple/container)。目前僅在開發者的 M4 Mac mini／macOS 26.7.1／引擎 1.5.0 測試。[驗證範圍](RELEASE_1.0.0_VALIDATION.md)。

## 2. 安裝與連接

1. 從 [v1.0.0](https://github.com/eqwgeryfgbdf/container-desk/releases/tag/v1.0.0) 下載 `Container-Desk-1.0.0-arm64.dmg`。手動上傳附件只有 DMG，原始碼封存由 GitHub 另外產生。
2. 可執行 `shasum -a 256 Container-Desk-1.0.0-arm64.dmg`，與 Release 正文的完整校驗碼比對。
3. 先結束舊 App，再開啟 DMG、拖入「應用程式」並確認取代；想保留降版選項可先備份舊 App。不要刪除引擎資料或容器。
4. 本版只有 ad hoc 簽章，尚未公證。若 macOS 阻擋，確認來源後到「系統設定 → 隱私權與安全性 → 強制打開／仍要打開」，依單一 App 提示確認。不要全域停用 Gatekeeper。
5. 在「容器引擎」連接既有引擎，或從支援的 Apple 官方來源安裝；系統安裝可能需要管理員授權。運行中的工作負載會延後引擎更新，不要為了安裝 App 停止其他服務。

0.3 預覽版使用不同的偏好設定識別；1.0 回到正式 App 識別。必要時重新選擇介面偏好與既有 AI 模型。替換 App 不搬移或刪除引擎資料。

## 3. 建立網頁容器

1. 「映像檔 → 下載與部署 → 搜尋 Docker Hub」，選官方 `nginx`、`alpine` 標籤、ARM64。
2. 下載後設定名稱 `my-web`、1 CPU、256 MiB；主機空閒連接埠 `18080` 對應容器 `80`，TCP，其餘保留預設。
3. 建立後按「啟動」，點擊 `127.0.0.1:18080` 開啟服務；若連接埠已被占用，改用另一個空閒主機連接埠。
4. 雙擊容器展開資訊／日誌，使用 ⌘+／⌘−／⌘0 縮放與還原。
5. 完成後只停止、刪除自己的測試容器；刪除容器不等於備份掛載資料。

## 4. 選用腳本測試

先下載並閱讀相同版本的腳本：

```sh
curl -fL https://raw.githubusercontent.com/eqwgeryfgbdf/container-desk/v1.0.0/scripts/quick-test.sh -o quick-test.sh
bash quick-test.sh --check
bash quick-test.sh --run
```

`--check` 唯讀；`--run` 建立唯一命名的 localhost HTTP 服務，驗證後清除自身資源。加上 `--keep` 會保留測試容器並列出清理方式。不需額外測試 ZIP，也不下載 AI 模型。

## 5. 更多操作

- [Hugging Face／llama.cpp／MCP](AI_QUICK_START.zh-Hant.md)：先用約 105 MB 小模型，文字推論不等於支援工具調用。
- [映像更新與回復](IMAGE_UPDATES.md)：先了解停機及掛載資料限制。
- [檔案、倉庫與 Compose](COMPOSE_AND_FILES.md)、[Docker 轉換](DOCKER_CONVERSION.md)：僅支援明列範圍，持久資料需另外搬移。
- [回報問題](TEST_REPORT.md)：附 App／引擎／macOS 版本與錯誤，不要附密碼、Token 或私人環境變數。
