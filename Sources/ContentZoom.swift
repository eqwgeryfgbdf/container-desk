import SwiftUI
import AppKit

@MainActor final class ContentZoom: ObservableObject {
    static let levels = [80, 90, 100, 110, 125, 150]
    @Published private(set) var percent: Int
    private let defaults: UserDefaults
    private var equalsShortcut: Any?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let saved = defaults.integer(forKey: "contentZoomPercent")
        percent = Self.levels.contains(saved) ? saved : 100
        // Accept Command-= on keyboards where + requires Shift. The visible
        // menu shortcuts handle Command-+, Command-- and Command-0 natively.
        equalsShortcut = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let modifiers = event.modifierFlags.intersection([.command, .shift, .control, .option])
            guard modifiers == .command, event.charactersIgnoringModifiers == "=" else { return event }
            let consumed = MainActor.assumeIsolated {
                guard NSApp.keyWindow != nil, NSApp.keyWindow?.attachedSheet == nil,
                      let self else { return false }
                self.increase()
                return true
            }
            return consumed ? nil : event
        }
    }

    deinit { if let equalsShortcut { NSEvent.removeMonitor(equalsShortcut) } }
    var scale: CGFloat { CGFloat(percent) / 100 }
    var canIncrease: Bool { percent < Self.levels.last! }
    var canDecrease: Bool { percent > Self.levels.first! }
    func set(_ value: Int) {
        guard Self.levels.contains(value) else { return }
        percent = value
        defaults.set(value, forKey: "contentZoomPercent")
    }
    func increase() { if let next = Self.levels.first(where: { $0 > percent }) { set(next) } }
    func decrease() { if let next = Self.levels.last(where: { $0 < percent }) { set(next) } }
    func reset() { set(100) }
}

/// Lay out at the unscaled size, then reserve the transformed size. Keeping the
/// same view tree preserves selection, logs and scroll state while zooming.
struct ZoomableContent<Content: View>: View {
    @ReducedInterfaceMotion private var reduceMotion
    @EnvironmentObject private var zoom: ContentZoom
    var minimumWidth: CGFloat = 860
    @ViewBuilder var content: Content

    var body: some View {
        ZoomViewport(scale:zoom.scale, minimumWidth:minimumWidth, content:content)
            .animation(InterfaceMotion.layout(reduceMotion:reduceMotion), value:zoom.percent)
            .transaction { transaction in
                if reduceMotion { transaction.animation=nil; transaction.disablesAnimations=true }
            }
    }
}

/// Interpolate the scale once and derive both frames from it on every frame.
/// Animating inverse layout widths and scale independently would cause drift.
private struct ZoomViewport<Content: View>: View, Animatable {
    var scale: CGFloat
    let minimumWidth: CGFloat
    let content: Content
    var animatableData: CGFloat {
        get { scale }
        set { scale = newValue }
    }

    var body: some View {
        GeometryReader { geometry in
            let width = max(minimumWidth, geometry.size.width / scale)
            let viewportHeight = max(1, geometry.size.height - geometry.safeAreaInsets.top)
            let height = viewportHeight / scale
            ScrollView(.horizontal) {
                content
                    .transaction { $0.animation=nil }
                    .ignoresSafeArea(.container, edges: .top)
                    .frame(width: width, height: height, alignment: .topLeading)
                    .scaleEffect(scale, anchor: .topLeading)
                    .frame(width: width * scale, height: viewportHeight, alignment: .topLeading)
            }
            .contentMargins(.top, geometry.safeAreaInsets.top, for: .scrollContent)
            .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
        }
        .clipped()
    }
}
