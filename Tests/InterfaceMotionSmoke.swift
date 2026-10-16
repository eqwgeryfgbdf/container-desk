import SwiftUI
import AppKit

@MainActor private final class MotionProbe: ObservableObject {
    @Published var page = 0
    @Published var liveValue = 0
    var widths: [Double] = []
    var animatedTransactions: [Bool] = []
}

private struct MotionHarness: View {
    @ObservedObject var probe: MotionProbe
    var body: some View {
        VStack(spacing: 0) {
            ZoomableContent(minimumWidth: 200) {
                Color.blue.opacity(0.1)
                    .onGeometryChange(for: Double.self) { Double($0.size.width) } action: { probe.widths.append($0) }
            }
            Text("Page \(probe.page), sample \(probe.liveValue)")
                .frame(height: 60)
                .transaction { probe.animatedTransactions.append($0.animation != nil) }
                .modifier(InterfaceFade(value: probe.page))
        }
    }
}

/// Opt-in graphical smoke test: real NSHostingView frames, no engine calls and
/// no changes to the user's macOS accessibility preferences.
@main private enum InterfaceMotionSmoke {
    @MainActor static func main() {
        let reduced = CommandLine.arguments.contains("--reduced") || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let suite = "ContainerDesk.MotionSmoke.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let zoom = ContentZoom(defaults: defaults)
        let probe = MotionProbe()
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        let window = NSWindow(contentRect: NSRect(x: 100, y: 100, width: 960, height: 640),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Container Desk — isolated motion check"
        window.contentView = NSHostingView(rootView: MotionHarness(probe: probe)
            .environmentObject(zoom).environment(\.suppressInterfaceMotion, reduced))
        window.makeKeyAndOrderFront(nil)
        app.activate()
        Task { @MainActor in
            func settle() async { try? await Task.sleep(for: .milliseconds(500)) }
            await settle()
            let initial = probe.widths.last!
            probe.widths.removeAll()
            zoom.set(150)
            await settle()
            let final = probe.widths.last!
            precondition(abs(final - initial / 1.5) < 1, "Zoom did not reach requested layout")
            let intermediate = probe.widths.filter { $0 > final + 1 && $0 < initial - 1 }
            precondition(reduced ? intermediate.isEmpty : !intermediate.isEmpty,
                         "Reduce Motion or interpolation failed: \(probe.widths)")
            let count = intermediate.count
            zoom.set(80)
            try? await Task.sleep(for: .milliseconds(60))
            zoom.set(125)
            try? await Task.sleep(for: .milliseconds(60))
            zoom.reset()
            await settle()
            precondition(abs(probe.widths.last! - initial) < 1, "Interrupted zoom did not settle")
            probe.animatedTransactions.removeAll()
            probe.page = 1
            await settle()
            precondition(!probe.animatedTransactions.isEmpty, "Page transaction not observed")
            precondition(reduced ? !probe.animatedTransactions.contains(true) : probe.animatedTransactions.contains(true),
                         "Page transition does not follow Reduce Motion")
            probe.animatedTransactions.removeAll()
            probe.liveValue += 1
            await settle()
            precondition(!probe.animatedTransactions.contains(true), "Live data update unexpectedly animated")
            defaults.removePersistentDomain(forName: suite)
            print("PASS: reduced=\(reduced), intermediate zoom frames=\(count), interruption, page fade, quiet live updates")
            app.terminate(nil)
        }
        app.run()
    }
}
