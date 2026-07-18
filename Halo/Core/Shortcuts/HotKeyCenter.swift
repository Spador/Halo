import AppKit
import Carbon.HIToolbox
import os

/// Registers global hotkeys through Carbon's `RegisterEventHotKey` — the
/// supported, permission-free way to own a key combination system-wide.
/// macOS delivers only the registered combos to Halo (no other keystroke is
/// ever seen) and swallows them so they don't also type into the focused
/// app. Event-driven: zero cost until a combo is pressed.
final class HotKeyCenter {
    var onAction: ((HotKeyAction) -> Void)?

    private var registrations: [UInt32: (ref: EventHotKeyRef, action: HotKeyAction)] = [:]
    private var currentBindings: [HotKeyAction: KeyCombo] = [:]
    private var eventHandler: EventHandlerRef?
    private var nextID: UInt32 = 1

    /// 'HALO' — distinguishes our hotkey events from other apps'.
    private static let signature: OSType = 0x48414C4F

    /// Replaces all registrations with the given bindings. Called at launch
    /// and whenever the user re-records a shortcut in Settings.
    func apply(_ bindings: [HotKeyAction: KeyCombo]) {
        currentBindings = bindings
        unregisterAll()
        registerAll()
    }

    /// While the Settings recorder is armed, all hotkeys let go of their
    /// combos — otherwise pressing an assigned combo would trigger its
    /// action instead of reaching the recorder.
    func suspend() {
        unregisterAll()
    }

    func resume() {
        unregisterAll()
        registerAll()
    }

    private func registerAll() {
        guard !currentBindings.isEmpty else { return }
        installHandlerIfNeeded()

        for (action, combo) in currentBindings {
            let id = nextID
            nextID += 1
            let hotKeyID = EventHotKeyID(signature: Self.signature, id: id)
            var ref: EventHotKeyRef?
            let status = RegisterEventHotKey(
                UInt32(combo.keyCode),
                combo.carbonModifiers,
                hotKeyID,
                GetApplicationEventTarget(),
                0,
                &ref
            )
            if status == noErr, let ref {
                registrations[id] = (ref, action)
            } else {
                // Usually means another app already owns the combo.
                Logger.hud.notice("hotkey \(combo.display) failed to register: \(status)")
            }
        }
    }

    fileprivate func handlePress(id: UInt32) {
        guard let registration = registrations[id] else { return }
        onAction?(registration.action)
    }

    private func installHandlerIfNeeded() {
        guard eventHandler == nil else { return }
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(
            GetApplicationEventTarget(),
            hotKeyEventCallback,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )
    }

    private func unregisterAll() {
        for (_, registration) in registrations {
            UnregisterEventHotKey(registration.ref)
        }
        registrations = [:]
    }
}

/// C trampoline for the Carbon event handler. Carbon dispatches application
/// target events on the main thread, so hopping back into MainActor
/// isolation is safe — the same pattern as the media key tap.
private let hotKeyEventCallback: EventHandlerUPP = { _, event, userData in
    guard let event, let userData else { return noErr }
    var hotKeyID = EventHotKeyID()
    GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )
    let id = hotKeyID.id
    nonisolated(unsafe) let opaqueCenter = userData
    MainActor.assumeIsolated {
        let center = Unmanaged<HotKeyCenter>.fromOpaque(opaqueCenter).takeUnretainedValue()
        center.handlePress(id: id)
    }
    return noErr
}
