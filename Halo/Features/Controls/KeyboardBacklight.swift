import Foundation

/// Keyboard backlight level via the private CoreBrightness framework —
/// macOS offers no public API (the control lives only in Control Center).
///
/// Everything is resolved at runtime: dlopen the framework, look up
/// KeyboardBrightnessClient by name, and call its methods through C
/// function pointers. If any step fails on a future macOS, `isAvailable`
/// turns false and the slider simply never appears.
final class KeyboardBacklight {
    private typealias BrightnessFn =
        @convention(c) (AnyObject, Selector, UInt64) -> Float
    private typealias SetBrightnessFn =
        @convention(c) (AnyObject, Selector, Float, UInt64) -> ObjCBool

    private let client: NSObject?
    private let keyboardID: UInt64

    private static let getSelector = NSSelectorFromString("brightnessForKeyboard:")
    private static let setSelector = NSSelectorFromString("setBrightness:forKeyboard:")

    init() {
        dlopen(
            "/System/Library/PrivateFrameworks/CoreBrightness.framework/CoreBrightness",
            RTLD_LAZY
        )
        guard let type = NSClassFromString("KeyboardBrightnessClient") as? NSObject.Type
        else {
            client = nil
            keyboardID = 0
            return
        }
        let instance = type.init()
        client = instance

        // "copy" in the name means the result comes back retained.
        let idsSelector = NSSelectorFromString("copyKeyboardBacklightIDs")
        if instance.responds(to: idsSelector),
           let ids = instance.perform(idsSelector)?.takeRetainedValue() as? [NSNumber],
           let first = ids.first {
            keyboardID = first.uint64Value
        } else {
            keyboardID = 1  // the built-in keyboard on every laptop tested
        }
    }

    var isAvailable: Bool {
        guard let client else { return false }
        return client.responds(to: Self.getSelector)
            && client.responds(to: Self.setSelector)
    }

    func brightness() -> Double? {
        guard isAvailable, let client,
              let implementation = client.method(for: Self.getSelector)
        else { return nil }
        let call = unsafeBitCast(implementation, to: BrightnessFn.self)
        let value = call(client, Self.getSelector, keyboardID)
        guard value.isFinite, value >= 0 else { return nil }
        return Double(min(value, 1))
    }

    func setBrightness(_ level: Double) {
        guard isAvailable, let client,
              let implementation = client.method(for: Self.setSelector)
        else { return }
        let call = unsafeBitCast(implementation, to: SetBrightnessFn.self)
        _ = call(client, Self.setSelector, Float(min(max(level, 0), 1)), keyboardID)
    }
}
