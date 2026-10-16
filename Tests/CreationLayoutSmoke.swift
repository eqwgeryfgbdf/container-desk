import SwiftUI
import AppKit

/// Opt-in native layout regression test. Synthetic host capacities are confined
/// to this test executable; it never detects or calls a container engine.
@main enum CreationLayoutSmoke {
    @MainActor static func main() {
        let app=NSApplication.shared
        app.setActivationPolicy(.accessory)
        DispatchQueue.global().asyncAfter(deadline:.now()+12) {
            fputs("FAIL: creation sheet blocked the main run loop\n",stderr)
            exit(1)
        }
        let window=NSWindow(contentRect:NSRect(x:100,y:100,width:620,height:640),styleMask:[.titled],backing:.buffered,defer:false)
        window.title="Container Desk — isolated creation layout check"
        Task { @MainActor in
            for capacity:UInt64 in [16,1024] {
                let store=Store();store.host.memory=capacity*1024*1024*1024
                let start=Date()
                let host=NSHostingView(rootView:CreateView().environmentObject(store))
                window.contentView=host
                window.orderFront(nil)
                host.layoutSubtreeIfNeeded()
                let size=host.fittingSize
                try? await Task.sleep(for:.milliseconds(250))
                precondition(Date().timeIntervalSince(start)<2,"Creation layout took too long")
                precondition(size.width.isFinite && size.height.isFinite && size.width<=640 && size.height<=680,"Unbounded sheet geometry")
                print("PASS: \(capacity) GiB host, bounded creation view, responsive main loop (\(String(format:"%.3f",Date().timeIntervalSince(start))) s)")
            }
            window.orderOut(nil)
            app.terminate(nil)
        }
        app.run()
    }
}
