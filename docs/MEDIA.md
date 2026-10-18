# Actual app media — 0.2.0

README screenshots and the current release video were captured from Container Desk **0.2.0, build 5**, on the developer's own M4 Mac mini (16 GiB, macOS 26.7.1, Apple Container 1.5.0), on 2026-10-18. No second Mac was used. These are real native SwiftUI windows and disposable engine containers, not mockups or sample-mode data.

| Asset | What it shows |
|---|---|
| `images/overview-en.png` | Real host specifications and one running / one stopped disposable container. |
| `images/containers-en.jpg` | Actual search, batch controls, states and resource measurements. |
| `images/create-en.png` | Downloaded-image selector, image metadata disclosure, CPU menu and memory slider/numeric input set to 768 MiB. Creation is cancelled after this capture. |
| `Container-Desk-Overview-zh-Hant.mp4` in the release | Native scripted navigation, selection/filtering, expanded details, zoom, logs, file browsing, clone review, disk-usage review and download-to-configuration. 67.3 seconds, 1280×800, Traditional Chinese captions. |

Host-name pixels are explicitly masked in screenshots and recording. Other runtime values are retained. The macOS recording indicator may appear in the title bar. The clip is actual captured app output with caption overlays; only trailing idle footage is trimmed. It does not claim to demonstrate actual clone creation, cleanup deletion, installation, updates or registry publishing end to end. Those operations have separate tests or explicit remaining acceptance limits.

Recording uses `scripts/test-ui.sh --matrix --record`; the annotator refuses a failed scenario and adds conservative privacy masks around transitions. Raw footage, raw language/theme screenshots and UI logs remain private local evidence. Only reviewed, masked screenshots and the annotated video are published.

The three-language, light/dark, two-size matrix captures real creation sheets at 1320×860 and 1100×692. Its 170 AX/keyboard steps check navigation and reachable creation controls; visual review checks these captures for obvious clipping. It is not a full VoiceOver/contrast certification. The older `images/settings-en.jpg` is historical 0.1.2 QA evidence and is not a primary README screenshot.

The video and screenshots demonstrate app workflows on this one device. They do not establish downloaded-DMG Gatekeeper, clean-install, engine-upgrade or second-device acceptance. See [current validation](RELEASE_0.2.0_VALIDATION.md).
