# Interface motion

Design references: Apple's [Motion HIG](https://developer.apple.com/design/human-interface-guidelines/motion), [Reduce Motion environment value](https://developer.apple.com/documentation/swiftui/environmentvalues/accessibilityreducemotion), and [Reduced Motion evaluation criteria](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/reduced-motion-evaluation-criteria).

The app uses motion to explain a change of context. Timings below are app-specific choices, not fixed durations mandated by Apple.

| Interaction | Treatment | Reduce Motion |
| --- | --- | --- |
| Sidebar page choice | 180 ms crossfade | Immediate |
| Container detail expand / back | 180 ms content fade, 240 ms smooth native split-layout change | Immediate custom transition |
| Info / Logs tab | 180 ms crossfade | Immediate |
| Content zoom | 240 ms smooth interpolation, no extra bounce | Immediate |
| Periodic metrics, charts and log samples | No added animation | Same |
| Native menus, sheets and standard controls | System behavior | System accessibility behavior |

Changes remain interruptible. There is no completion delay, input lock, autoplay decoration, parallax or oscillation. Layout is derived from a single interpolated zoom factor to keep scaled content and its scrollable extent aligned. The view tree remains stable while zooming; navigation/tab identity changes only when the destination changes, never on a poll.

`ReducedInterfaceMotion` reads the live SwiftUI accessibility environment. A host can additionally suppress custom motion; it cannot force animation when the system preference requests reduced motion. Both fades and layout transactions disable custom animation when suppressed.

## Verification

Run `bash scripts/test-motion.sh` in a logged-in macOS graphical session. It opens a temporary native window with the production motion and zoom components, then closes it automatically. It does not call the container engine or modify system accessibility preferences.

The test observes actual intermediate layout widths, verifies final layout after rapidly interrupted zoom changes, checks page-transition transactions, and verifies ordinary live-value changes are not animated. It runs normally and with additional motion suppression. On a host that already requests Reduce Motion, both runs respect that setting.

The harness validates the custom motion policy. Full VoiceOver, production chart/log interaction, and system-setting toggle acceptance remain separate manual release checks.
