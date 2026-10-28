#!/usr/bin/env python3
"""Write portable installer instructions; complete tutorials stay at the matching source tag."""
from pathlib import Path
import sys
stage,version=Path(sys.argv[1]),sys.argv[2]
base=f'https://github.com/eqwgeryfgbdf/container-desk/blob/v{version}'
text=f'''# Container Desk {version}

English · 繁體中文 · 简体中文

## English
Quit the old app, then drag Container Desk into Applications and confirm replacement. Apple Silicon and macOS 26+ are required. The Apple Container engine is a separate installation. Existing engine workloads and storage are not removed by replacing the app.

This public build is ad hoc signed and not Apple-notarized. If macOS blocks opening, verify the release source, then use the per-app Open Anyway option in System Settings → Privacy & Security. Do not disable Gatekeeper globally. Only the developer's own Mac was used for testing.

[Quick start]({base}/docs/QUICK_START.md) · [Local AI and MCP]({base}/docs/AI_QUICK_START.md) · [Verification and limits]({base}/docs/RELEASE_1.0.0_VALIDATION.md)

## 繁體中文
先結束舊 App，再把 Container Desk 拖入「應用程式」並確認取代。需要 Apple Silicon、macOS 26 以上；Apple Container 引擎另外安裝。替換 App 不會刪除引擎的容器或資料。

本版為 ad hoc 簽章，尚未經 Apple 公證。若被阻擋，先確認發布來源，再使用「系統設定 → 隱私權與安全性」的單一 App「強制打開／仍要打開」。不要全域停用 Gatekeeper。僅在開發者自己的設備上測試。

[快速上手]({base}/docs/QUICK_START.zh-Hant.md) · [本機 AI 與 MCP]({base}/docs/AI_QUICK_START.zh-Hant.md) · [驗證與限制]({base}/docs/RELEASE_1.0.0_VALIDATION.md)

## 简体中文
退出旧 App，将 Container Desk 拖入“应用程序”并确认替换。需要 Apple Silicon、macOS 26 及以上；Apple Container 引擎单独安装。替换 App 不会删除引擎的容器或数据。

本版仅 ad hoc 签名，尚未经过 Apple 公证。若被阻止，请先确认发布来源，再使用“系统设置 → 隐私与安全性”的单个 App“仍要打开”选项。不要全局关闭 Gatekeeper。仅在开发者自己的设备上测试。

[快速上手]({base}/docs/QUICK_START.zh-Hans.md) · [本地 AI 与 MCP]({base}/docs/AI_QUICK_START.zh-Hans.md) · [验证与限制]({base}/docs/RELEASE_1.0.0_VALIDATION.md)

## Upgrade / 升級 / 升级
The 0.3 preview stored preferences under a different app identifier. 1.0 uses `local.containerdesk.app`; reselect preview preferences and existing local AI models as needed. Engine data stays shared.

0.3 預覽版的偏好設定使用不同 App 識別；1.0 使用 `local.containerdesk.app`，必要時重新選擇偏好與既有模型。引擎資料仍共用。

0.3 预览版的偏好设置使用不同 App 标识；1.0 使用 `local.containerdesk.app`，必要时重新选择偏好与已有模型。引擎数据仍共享。

[Apache-2.0 license](LICENSE.txt). Independent application, not an Apple product. [Official engine](https://github.com/apple/container).
'''
(stage/'Read Me.md').write_text(text)
