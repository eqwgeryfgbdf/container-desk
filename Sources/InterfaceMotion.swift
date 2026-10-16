import SwiftUI

private struct SuppressInterfaceMotionKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    // Allows a host or the graphical test harness to suppress custom motion.
    // It can never override the user's system Reduce Motion preference.
    var suppressInterfaceMotion: Bool {
        get { self[SuppressInterfaceMotionKey.self] }
        set { self[SuppressInterfaceMotionKey.self] = newValue }
    }
}

@propertyWrapper struct ReducedInterfaceMotion: DynamicProperty {
    @Environment(\.accessibilityReduceMotion) private var systemReduced
    @Environment(\.suppressInterfaceMotion) private var suppressed
    var wrappedValue: Bool { systemReduced || suppressed }
}

/// App-specific timing, following HIG Motion's brief, purposeful feedback.
/// These are not Apple-mandated durations. Never animate polling updates.
enum InterfaceMotion {
    static func fade(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .easeInOut(duration: 0.18)
    }

    static func layout(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .smooth(duration: 0.24, extraBounce: 0)
    }
}

/// Identity changes only for navigation/tab choices, never for live data.
/// SwiftUI can interrupt a transition immediately when another choice arrives.
struct InterfaceFade<Value: Equatable & Hashable>: ViewModifier {
    @ReducedInterfaceMotion private var reduceMotion
    let value: Value

    func body(content: Content) -> some View {
        ZStack {
            content.id(value).transition(.opacity)
        }
        .animation(InterfaceMotion.fade(reduceMotion: reduceMotion), value: value)
        .transaction { transaction in
            if reduceMotion {
                transaction.animation = nil
                transaction.disablesAnimations = true
            }
        }
    }
}
