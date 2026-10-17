# README media

Use actual app captures. No AI-generated mockups or fabricated runtime data as product evidence.

## Captured

| File | Provenance | What it proves / does not prove |
| --- | --- | --- |
| `images/overview-en.png` | 0.1.2 QA bundle, macOS 26.7.1, 2026-10-16; native window capture using the macOS CLI. | Actual hardware and live totals. Computer name covered by an explicit redaction; all other displayed values retained. |
| `images/containers-en.jpg` | Same QA bundle/date; native screenshot, sidebar hidden and search filter applied. | Actual stopped `cd-qa-readme-01933495` container created through the official CLI with 2 CPUs/768 MiB and a locally downloaded Python image. No mounts/ports/secrets. Removed after capture; all 8 pre-existing container states verified unchanged. |
| `images/settings-en.jpg` | Container Desk 0.1.2 QA bundle (`local.containerdesk.qa`), macOS 26.7.1, captured 2026-10-16; native sidebar hidden before capture. | Real English Settings rendering and preview disclosure. QA build capture, not a certification of the downloadable DMG or complete UI acceptance. |

The Settings and management images are unmodified native-window screenshots. The overview has only its computer-name value visibly covered for privacy. Sidebar visibility and management search use normal app controls. No runtime values were replaced with sample data. Overview and management are the README's primary images; Settings remains a secondary reference.

## Current recording workflow

The current source has scripted native UI regression and actual window recording. See [AUTOMATED_QA.md](AUTOMATED_QA.md) for the commands and [QA_RESULTS.md](QA_RESULTS.md) for the latest evidence. The original macOS 26 creation-sheet layout problem (UI-001, discrete slider marks) was fixed earlier; the current native creation form is exercised at both 16 GiB and 1 TiB host ranges. A later automation-only input issue was separately fixed by sending real keyboard input instead of only assigning AX text values.

The walkthrough uses disposable, real Python containers and the official Python image. It shows selection/filtering, expanded details, logs, file browsing, download-to-configuration, and navigation. Configuration is canceled after entering values; the video does not claim to demonstrate creation, installation, registry publishing or project conversion end to end. Those paths have separate backend tests and acceptance requirements.

Only the annotated MP4 is suitable for sharing after review. Host-name regions are covered, Traditional Chinese chapter captions identify each step, and a persistent footer identifies development-preview footage. Only trailing idle footage is trimmed. The recording contains real operation timing; no generated UI or invented runtime values are inserted. Raw footage remains local private evidence. Repository visibility and GitHub release assets are not changed by recording.

## Remaining media acceptance

- Dark appearance and representative Simplified/Traditional Chinese views at supported sizes.
- Candidate creation screenshot and second-Mac release verification.
- Review the full exported video, captions and privacy masking before public publication.

The earlier screenshots remain historical QA evidence; they do not certify the newest downloadable DMG. A video does not replace the public release gates.
