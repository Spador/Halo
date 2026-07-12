import AppKit
import ApplicationServices

/// The media keys Halo intercepts. Raw values are Apple's NX_KEYTYPE_*
/// codes carried inside system-defined events.
enum MediaKey: Int32 {
    case volumeUp = 0        // NX_KEYTYPE_SOUND_UP
    case volumeDown = 1      // NX_KEYTYPE_SOUND_DOWN
    case brightnessUp = 2    // NX_KEYTYPE_BRIGHTNESS_UP
    case brightnessDown = 3  // NX_KEYTYPE_BRIGHTNESS_DOWN
    case mute = 7            // NX_KEYTYPE_MUTE
}

/// A CGEventTap scoped to exactly one event type: `.systemDefined` (14),
/// the channel media/aux keys travel on. Regular keystrokes are a different
/// event type and are never delivered to this tap — that's the entire
/// privacy story of our Accessibility permission, verifiable right here.
///
/// Swallowing an event (returning nil from the callback) means macOS never
/// processes the key — which is what suppresses the system HUD.
final class MediaKeyTap {
    /// Return true to swallow the key. Called for both key-down and key-up.
    var handler: (MediaKey, _ isKeyDown: Bool) -> Bool = { _, _ in false }

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    var isRunning: Bool { tap != nil }

    /// Fails (returns false) when Accessibility permission is missing.
    @discardableResult
    func start() -> Bool {
        guard tap == nil else { return true }
        let mask = CGEventMask(1 << NSEvent.EventType.systemDefined.rawValue)
        // HID level, not session level: on Apple Silicon the system
        // consumes brightness keys before session taps see them, but they
        // are still visible (and swallowable) at the HID stage.
        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: mediaKeyTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }

        self.tap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    func stop() {
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        runLoopSource = nil
        tap = nil
    }

    /// Decides whether to swallow the event. Returning the decision as a
    /// Bool (instead of the CGEvent) keeps the actor boundary in the
    /// callback below happy — only Sendable values may cross it.
    fileprivate func shouldSwallow(type: CGEventType, event: CGEvent) -> Bool {
        // macOS disables taps it considers stalled; re-enable and pass through.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return false
        }

        // data1 packs the key code and state into bit fields; subtype 8
        // means "aux control key" (other subtypes exist on this event type).
        guard let nsEvent = NSEvent(cgEvent: event),
              nsEvent.subtype.rawValue == 8,
              let key = MediaKey(rawValue: Int32((nsEvent.data1 & 0xFFFF_0000) >> 16))
        else { return false }

        let keyFlags = nsEvent.data1 & 0x0000_FFFF
        let isKeyDown = ((keyFlags & 0xFF00) >> 8) == 0x0A

        return handler(key, isKeyDown)
    }
}

/// C-convention trampoline for the tap. The tap's run-loop source is on the
/// main run loop, so this always executes on the main thread — the
/// `assumeIsolated` below states that fact to the compiler.
private let mediaKeyTapCallback: CGEventTapCallBack = { _, type, event, refcon in
    guard let refcon else { return Unmanaged.passUnretained(event) }
    // Safe: we are on the main thread (see above); these markers tell the
    // compiler not to worry about the pointers crossing into MainActor.
    nonisolated(unsafe) let unsafeEvent = event
    nonisolated(unsafe) let unsafeRefcon = refcon
    let swallow = MainActor.assumeIsolated {
        Unmanaged<MediaKeyTap>.fromOpaque(unsafeRefcon)
            .takeUnretainedValue()
            .shouldSwallow(type: type, event: unsafeEvent)
    }
    return swallow ? nil : Unmanaged.passUnretained(event)
}
