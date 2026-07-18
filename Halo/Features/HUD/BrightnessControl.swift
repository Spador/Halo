import CoreGraphics
import Foundation

/// Display brightness via Apple's private DisplayServices framework —
/// there is no public API for this (every HUD-replacement app does the
/// same). Loaded dynamically at runtime: if a future macOS removes these
/// functions, `isAvailable` turns false and the HUD feature leaves the
/// brightness keys to the system instead of breaking.
final class BrightnessControl {
    private typealias GetBrightnessFn =
        @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    private typealias SetBrightnessFn =
        @convention(c) (CGDirectDisplayID, Float) -> Int32

    private static let step: Float = 1.0 / 16.0

    private let getFn: GetBrightnessFn?
    private let setFn: SetBrightnessFn?

    var isAvailable: Bool { getFn != nil && setFn != nil }

    init() {
        let path = "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices"
        guard let handle = dlopen(path, RTLD_LAZY) else {
            getFn = nil
            setFn = nil
            return
        }
        getFn = dlsym(handle, "DisplayServicesGetBrightness").map {
            unsafeBitCast($0, to: GetBrightnessFn.self)
        }
        setFn = dlsym(handle, "DisplayServicesSetBrightness").map {
            unsafeBitCast($0, to: SetBrightnessFn.self)
        }
    }

    /// DisplayServices only controls the built-in panel, so always target
    /// that display explicitly — the *main* display might be an external
    /// monitor, on which these calls silently fail.
    private var builtinDisplayID: CGDirectDisplayID? {
        var ids = [CGDirectDisplayID](repeating: 0, count: 8)
        var count: UInt32 = 0
        guard CGGetOnlineDisplayList(UInt32(ids.count), &ids, &count) == .success
        else { return nil }
        return ids.prefix(Int(count)).first { CGDisplayIsBuiltin($0) != 0 }
    }

    var brightness: Float {
        guard let getFn, let display = builtinDisplayID else { return 0 }
        var value: Float = 0
        return getFn(display, &value) == 0 ? value : 0
    }

    /// Current level for the sliders, or nil when there is no controllable
    /// built-in display (lid closed, or DisplayServices unavailable).
    func currentBrightness() -> Double? {
        guard let getFn, let display = builtinDisplayID else { return nil }
        var value: Float = 0
        guard getFn(display, &value) == 0 else { return nil }
        return Double(value)
    }

    /// Absolute setter for the sliders; returns the clamped applied level.
    func setBrightness(_ level: Double) -> Double? {
        guard let setFn, let display = builtinDisplayID else { return nil }
        let clamped = min(max(Float(level), 0), 1)
        _ = setFn(display, clamped)
        return Double(clamped)
    }

    /// Applies one key-press step and returns the new level for the HUD,
    /// or nil when there is no controllable built-in display (lid closed).
    func stepBrightness(up: Bool) -> Double? {
        guard let setFn, let display = builtinDisplayID else { return nil }
        let stepped = brightness + (up ? Self.step : -Self.step)
        let snapped = (stepped * 16).rounded() / 16
        let clamped = min(max(snapped, 0), 1)
        _ = setFn(display, clamped)
        return Double(clamped)
    }
}
