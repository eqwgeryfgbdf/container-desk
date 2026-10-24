# 本機 AI 與 MCP：0.3.0 開發預覽版

[English](AI_QUICK_START.md) · [简体中文](AI_QUICK_START.zh-Hans.md)

下載 [0.3.0 預覽版 DMG](https://github.com/eqwgeryfgbdf/container-desk/releases/download/v0.3.0-preview/Container-Desk-0.3.0-arm64-preview.dmg)。本機已通過原生搜尋介面自動化測試，詳見[驗證範圍](AI_VALIDATION.md)。本版只有 ad hoc 簽章，沒有 Apple 公證，仍為預覽版；0.2.0 不包含這些功能。

## 啟動模型

1. 啟動 Apple Container 引擎，開啟左側 AI 頁面。
2. 選擇目錄中最小的 **Qwen2.5 0.5B Instruct Q4_K_M** 並下載，或挑選自己的單檔 `.gguf`。下載量 491,400,032 bytes（約 491 MB），會檢查固定版本、大小與 SHA-256；DMG 不包含模型。
3. 建議測試用 2 CPU、2 GiB 記憶體、2,048 token 上下文及未使用的主機連接埠（預設 18090）。建立並啟動後按測試模型。官方 llama.cpp Linux ARM64 映像檔另行下載，固定 digest。
4. 輸入訊息即可測試。更換部署前，先到容器頁停止、刪除原部署。取消或失敗可能留下容器供檢查，不會自動刪除工作負載。

推論使用 Linux VM 的 **CPU，不支援 Apple Metal**。僅掛載選中的單一模型檔，且為唯讀；服務只發布在 `127.0.0.1`。一般下載保留在 `~/Library/Application Support/Container Desk/Models`，可自行刪除。小模型適合驗證連線，不代表具備可靠推理或任意工具使用能力。

## 搜尋 Hugging Face 模型

在 **本機 AI → 搜尋 Hugging Face** 輸入模型名稱或發布者，也可點輕量模型快捷鍵。結果依下載量排序；選擇倉庫後，挑選單檔 GGUF 量化版本（由小到大），查看容量、授權／模型說明及估計記憶體，再按 **選擇並下載**。空白搜尋會顯示熱門 GGUF 候選模型。

輕量試用可搜尋 `SmolLM2-135M-Instruct`，選 `bartowski/SmolLM2-135M-Instruct-GGUF` 的 `SmolLM2-135M-Instruct-Q4_K_M.gguf`（受測版本為 105,454,432 bytes）。基本文字測試可用 2 CPU、1 GiB、1,024 上下文。工具呼叫需另做相容性測試，小模型可能無法通過。

下載固定至倉庫 commit，驗證檔案大小、GGUF 標頭與 SHA-256。不同內容分開快取，不覆蓋原有同名模型。下載不會部署或執行倉庫程式碼。GGUF 只是格式篩選，不代表目前 llama.cpp 引擎支援每種架構；部署後請按「測試模型」。記憶體估計會隨上下文變化，不保證能啟動。

目前提供公開、單檔的文字模型候選；隱藏分割檔、投影器、轉接器與缺少校驗資訊的檔案。受限制模型需自行在 Hugging Face 取得權限、下載後選擇本機檔案。未知授權會明確標示，使用前請查看模型說明。搜尋只會傳送搜尋文字到 Hugging Face，不會傳送對話或本機檔案。

腳本測試：`bash scripts/test-huggingface.sh`；加 `--live` 查詢真實 API，加 `--download` 下載小於 128 MiB 的測試模型並清除。加 `--inference --allow-image-pull` 做實機推論，使用連接埠 19893、2 CPU／1 GiB 暫時容器；另需約 296 MB 壓縮的官方 ARM64 伺服器映像，測後刪除本次新增的映像與容器。既有容器保持原狀；強制終止腳本時請檢查 `cd-hf-test-*` 殘留資源。

## 下載疑難排解

| 狀況 | 處理方式 |
| --- | --- |
| 找不到模型 | 用較短名稱或發布者搜尋。最多顯示 40 個熱門公開 GGUF 候選；清空搜尋可查看熱門模型。 |
| 量化版本太多 | 在檔案篩選輸入 `Q4_K_M`。清單由小到大排序，選擇完整單檔 GGUF，不要選轉接器或投影器。 |
| 要求授權或登入 | 點模型說明連結，在 Hugging Face 取得權限，手動下載單檔 GGUF，再按「挑選本機 GGUF…」。App 不收集 Hugging Face Token。 |
| 請求限制／網路錯誤 | 稍後重新搜尋。錯誤不代表下載成功或相容性通過。 |
| 空間不足／校驗失敗 | 清出空間或重新下載。失敗檔案不會設為已選模型，不要改名或修改損壞檔案來繞過驗證。 |
| 容器未就緒 | 檢查容器日誌與記憶體配置，先使用受測的小模型；固定版本引擎可能不支援較新的模型架構。 |
| 工具呼叫不相容 | 能回答文字不代表支援 MCP。受測 SmolLM2 135M 未通過工具測試；改用合適的指令模型並重新測試。 |

下載中可按進度旁的「取消」。完成的模型保留於 `~/Library/Application Support/Container Desk/Models`；腳本實機測試使用暫存模型並自行清理。要移除模型檔案，請先停止／刪除掛載它的容器。

## 連接已安裝的 MCP 工具

匯入含 `mcpServers` 的 JSON，選擇伺服器、檢查命令或網址後連接。例如將以下佔位路徑改成已安裝的伺服器：

```json
{"mcpServers":{"local-tools":{"command":"/absolute/path/to/server","args":["--stdio"],"env":{}}}}
```

也可手動加入 Streamable HTTP 網址，例如 `http://127.0.0.1:3000/mcp`；遠端必須使用 HTTPS，可填寫 Bearer token。匯入 HTTP 設定可使用 `url` 與 `Authorization: Bearer …` 標頭。設定、憑證與對話只放在記憶體，重新開啟 App 後需重新連接；不要將憑證提交至 Git。

連接只列出工具，不會呼叫工具。Stdio 會以你的 Mac 帳號啟動程式，請檢查命令與參數；App 不會自動安裝套件。預設不勾選任何工具，請自行選取並測試模型相容性。相容性測試使用虛構 echo 工具宣告，不執行 MCP 工具。

實際使用時，先檢查模型提出的工具名稱與完整 JSON 參數，再批准該批次。拒絕不會執行；批准後將結果交回模型整理，不會自動繼續呼叫其他工具。呼叫失敗仍可能已產生效果，重試前請確認伺服器狀態。

模型未通過結構化工具呼叫測試會出現相容性提示；連線與認證錯誤另外顯示。通過一次測試不代表所有工具結構都支援，亦不保證模型回答正確。

支援 stdio、Streamable HTTP JSON/SSE 回應、現代 discovery 與舊版初始化、分頁工具清單及工具呼叫，每段對話連接一個伺服器。目前不支援 OAuth、舊式 HTTP+SSE transport、sampling、tasks、input requests 或 schema-to-header projection；這些路徑會明確報錯。

## 腳本測試

需要 Xcode／Command Line Tools 26、Python 3 與 Apple Container，在儲存庫內執行：

```sh
bash scripts/test.sh
bash scripts/test-ai.sh --live
CONTAINERDESK_BUNDLE_ID=local.containerdesk.ai-development bash scripts/build.sh ../work/ai-build
open '../work/ai-build/Container Desk.app'
# 候選版選 English、Light；Mac 解鎖並授予測試程式輔助使用權限後：
python3 scripts/test-ai-ui.py
```

一般迴歸不下載模型。`--live` 需要網路與空閒的 19891 連接埠，只使用上述小模型；正常結束會清除臨時模型、容器及本次新增映像，保留既有工作負載。若強制終止，請檢查 `cd-ai-test-*` 與系統暫存目錄再清理。結果在 `../work/ai-tests`。介面腳本不下載、不連 MCP、不改動容器；三語 × 深淺色 × 兩種尺寸共 12 組，截圖留在 `../work/ai-ui-tests`，公開前需檢查並遮蔽主機資訊。`--generate-only` 僅產生腳本，不能算測試通過。

[驗收紀錄](AI_VALIDATION.md)。之後 Releases 只附 `.dmg`；教學、測試腳本留在儲存庫，原始碼使用 GitHub 對 release tag 自動提供的下載。上游文件與授權見 [英文版](AI_QUICK_START.md#upstream-references)。
