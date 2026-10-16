# Native design QA — Container Desk 0.1.0

Status: **partial; final visual acceptance pending**.

## Latest capture update — 2026-10-16

The 0.1.2 QA bundle yielded actual English Overview, container-management and Settings screenshots. Overview and management are now the README's primary images; only the overview's computer name is visibly redacted. See [capture provenance](docs/MEDIA.md). After the creation-sheet failure, a fresh process sample showed the main thread in SwiftUI sheet layout throughout the sample; this is tracked as suspected major defect UI-001. Restarting only the QA app restored management access. These captures are not full visual acceptance or verification of the downloadable DMG. Earlier entries below are historical evidence. Acceptance criteria and results live in [PUBLIC_RELEASE_GATE.md](docs/PUBLIC_RELEASE_GATE.md) and [TEST_REPORT.md](docs/TEST_REPORT.md).

## Visual contract

The chosen design direction is the previously generated Finder-like container table and right inspector, with the grouped-settings reference and restrained Activity Monitor treatment for metrics. The explicit SwiftUI/macOS 26 request takes precedence over matching generated, non-native window chrome pixel for pixel.

Native adaptation: NavigationSplitView/List sidebar, Table, grouped Form, segmented Picker, native toolbar, system typography, semantic colors and system-controlled window/control radii. No app-wide hardcoded radius, rounded-card wrapper around every row, or custom window mask is used. Main window minimum width is 1100 points to accommodate sidebar, table and inspector. GroupBox uses its native shape for hardware information.

## Observed checks

- Native app launched on macOS 26.7.1 with SDK 26.5 and Swift 6.3.3.
- Traditional Chinese container view and Simplified Chinese settings were captured at 1320 × 860. English and both Chinese choices updated app content; system-owned menus remain controlled by macOS.
- Sidebar, toolbar, separators, grouped settings, selected states and content hierarchy visibly follow the native system.
- The first container screenshot exposed excess alternating empty table stripes and tight row density. Source was corrected to disable alternating row backgrounds, add a 38-point row minimum and hide the redundant segmented-control label. This correction compiled; final screenshot verification remains pending.
- Latest accessibility snapshot confirmed live 8-container inventory, 1 running container, actual hostname and detected macmini icon after hardware detection was added.
- System UI automation then disconnected with `Sky Computer Use native pipe closed before response`. Reconnection and session reset did not restore it.

## Pending checks

- Final overview hardware block screenshot and long-name wrapping.
- Dark appearance, minimum window size and 1×/2× displays.
- Create-sheet keyboard traversal, VoiceOver, increased contrast and reduced transparency.
- Full screenshot comparison of the final table polish against the selected reference.
- Icon Composer layered production asset; the preview uses a standard SF Symbol in an ICNS asset.

Earlier screenshots are evidence of intermediate layouts, not images of the final binary. They are deliberately not presented as a final screenshot. No comprehensive visual-pass claim is made.


## 0.1.1 form revision

Native menu Pickers replace CPU Stepper and free-text image reference. Memory has a Slider and an integer field with a shared MiB allocation, validation and actual-host maximum. The grouped Form remains scrollable in a 620 × 780 sheet. Demo mode and sample data are removed. 29 automated checks and 171 three-language entries pass. Computer Use still reports a closed native pipe, so interactive dropdown/slider checks and final screenshots are pending; no visual-pass claim is made.


## 0.1.2 verification and blockers

Retried original app by path/bundle ID, reset the UI session, reopened it through Finder, and launched a separately identified QA bundle. Finder accessibility responds, but target-app capture reports `cgWindowNotFound` and then a closed native pipe. A process sample shows the app main thread in its normal event loop; this does not prove its visible rendering is correct. No screenshot, interaction, dark-mode or VoiceOver pass is claimed.

Backend and installation workflow evidence: 29 core checks, 13 isolated sequencing/recovery checks, real Store.create allocation validation, full CLI lifecycle test, and live migration preflight protection passed. Existing workloads were unchanged. Signing tools exist, but zero valid signing identities are installed. The owner has a second test Mac and will run the supplied test kit manually; its results have not yet been received. Clean macOS installation and real migration remain unverified. The development host has an active workload and is not used for disruptive installation tests.
