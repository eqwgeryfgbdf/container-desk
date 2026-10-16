# README media

Use actual app captures. No AI-generated mockups or fabricated runtime data as product evidence.

## Captured

| File | Provenance | What it proves / does not prove |
| --- | --- | --- |
| `images/overview-en.png` | 0.1.2 QA bundle, macOS 26.7.1, 2026-10-16; native window capture using the macOS CLI. | Actual hardware and live totals. Computer name covered by an explicit redaction; all other displayed values retained. |
| `images/containers-en.jpg` | Same QA bundle/date; native screenshot, sidebar hidden and search filter applied. | Actual stopped `cd-qa-readme-01933495` container created through the official CLI with 2 CPUs/768 MiB and a locally downloaded Python image. No mounts/ports/secrets. Removed after capture; all 8 pre-existing container states verified unchanged. |
| `images/settings-en.jpg` | Container Desk 0.1.2 QA bundle (`local.containerdesk.qa`), macOS 26.7.1, captured 2026-10-16; native sidebar hidden before capture. | Real English Settings rendering and preview disclosure. QA build capture, not a certification of the downloadable DMG or complete UI acceptance. |

The Settings and management images are unmodified native-window screenshots. The overview has only its computer-name value visibly covered for privacy. Sidebar visibility and management search use normal app controls. No runtime values were replaced with sample data. Overview and management are the README's primary images; Settings remains a secondary reference.

## Remaining captures

1. Creation form after the layout hang is fixed: downloaded-image menu, CPU menu, memory slider and editable number.
2. Dark appearance and one Chinese-language view, following the same privacy and provenance rules.

The original app's window capture is intermittent. A process sample after the QA creation-sheet failure showed the main thread in SwiftUI sheet layout throughout the sample. This is tracked as a suspected major app defect, not dismissed as an automation problem. Restarting only the QA app restored management access; the overview was captured through the CLI. Creation-form acceptance remains blocked; no replacement mockup is published.

## Optional 30–45 second walkthrough

Record actual operation after G02–G06 pass on the test Mac. Suggested sequence:

| Time | Shot |
| --- | --- |
| 0–5 s | App title and actual overview |
| 5–15 s | Choose local image/CPU; type 768 MiB and show slider synchronization |
| 15–25 s | Create one disposable container, start it, show its logs/status |
| 25–35 s | Stop/delete that test container, show clean result |
| 35–45 s | Language/appearance choices and official engine update page |

Publish as a linked MP4 with a real poster screenshot and captions; never expose authorization dialogs, passwords, unrelated workloads or personal paths. If editing out waits, label the cuts; do not imply instantaneous installation. A short video is optional and does not replace test evidence. Screenshots alone satisfy the media gate once the required views are captured.
