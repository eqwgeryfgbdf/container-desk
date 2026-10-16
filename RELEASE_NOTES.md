# Container Desk 0.1.2 — Developer Preview

A native SwiftUI app for managing local Apple Container workloads on Apple Silicon Macs running macOS 26 or later.

## Included

- Actual Mac hardware information and live container status, metrics and logs.
- Create, start, stop and delete containers.
- CPU dropdown, synchronized memory slider and numeric input, and a downloaded-image dropdown.
- English, Simplified Chinese and Traditional Chinese.
- Official engine installation/update workflow, workload protection, and explicit same-version migration for the recognized per-user installation.
- Read-only image, network and volume inventories.

## Verification

29 core checks and 13 isolated installer workflow tests passed. Real container creation with selected CPU/memory limits and the full lifecycle smoke test passed. Official package validation and live migration preflight were checked. Installer failure tests simulate external operations; they are not proof of a completed clean system install.

## Known limitations

- **Ad hoc signed, without Developer ID or Apple notarization.** GitHub does not sign or notarize the app. macOS may block it after download. Source and local build instructions are included in the repository.
- Final interactive UI, accessibility, clean-install and upgrade acceptance remain pending.
- Only Apple Container 1.5.0 is currently on the tested compatibility list. Unsupported updates are deferred.
- Resource inventories are read-only. There is no remote-host management, interactive terminal, closed-app updater or independent guest-kernel updater.

Mark this GitHub release as **pre-release**, not a verified stable release. This app is independently developed and is not an Apple product.

## Assets

- `Container-Desk-0.1.2-arm64-preview.dmg`
- `SHA256SUMS.txt`

GitHub supplies source archives for the source tag. Current source is licensed under Apache-2.0. Newly packaged versions also include a matching source ZIP, source-commit manifest and checksums; older uploaded assets are not silently replaced.

## 中文摘要

原生 SwiftUI Apple Container 管理工具，支援 Apple Silicon、macOS 26 以上與三語介面。CPU 配額、記憶體及本機映像檔選擇已實作，示範模式已移除。

此版本為尚未公證的開發預覽版，下載後可能被 macOS 阻擋。乾淨安裝、升級及完整介面互動驗收尚未完成，請以 GitHub Pre-release 發佈。
