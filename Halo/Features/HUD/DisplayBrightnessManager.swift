import AppKit
import CoreGraphics
import os

extension Logger {
    /// One shared category for the HUD feature's diagnostics. Read with:
    /// `log show --last 5m --predicate 'subsystem == "com.spador.Halo"'`
    static let hud = Logger(subsystem: "com.spador.Halo", category: "hud")
}

/// Routes a brightness key press to the right display: the one the pointer
/// is on. Built-in panel → DisplayServices; external monitor → DDC/CI.
///
/// External monitors can't reliably report their level, so after seeding
/// from one DDC read at discovery we track the level ourselves.
final class DisplayBrightnessManager: NSObject {
    /// KNOWN LIMITATION: external-monitor brightness is disabled. The LG
    /// this was built against accepts DDC audio commands (speaker volume
    /// works) but its backlight never responds to DDC brightness writes,
    /// and its brightness keys are unreliable through the tap. Flip this
    /// on to resume debugging; DDC *audio* is unaffected by the flag.
    private static let externalBrightnessEnabled = false

    private let builtin = BrightnessControl()
    private let ddc = ExternalDisplayDDC()

    /// Display ID → its DDC service, rebuilt when screens change.
    private var externalServices: [CGDirectDisplayID: CFTypeRef] = [:]
    /// Display ID → last level we set (0...1).
    private var externalLevels: [CGDirectDisplayID: Double] = [:]

    private static let step = 1.0 / 16.0

    override init() {
        super.init()
        rebuild()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screensDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    /// True when a brightness key press right now would be handled by us —
    /// checked for both key-down and key-up so swallowing stays consistent.
    func canControlDisplayUnderPointer() -> Bool {
        let display = Self.displayUnderPointer()
        if CGDisplayIsBuiltin(display) != 0 { return builtin.isAvailable }
        return Self.externalBrightnessEnabled && externalServices[display] != nil
    }

    /// Applies one step to the pointer's display; returns the new level
    /// for the HUD, or nil if that display can't be controlled.
    func stepBrightness(up: Bool) -> Double? {
        let display = Self.displayUnderPointer()

        if CGDisplayIsBuiltin(display) != 0 {
            Logger.hud.notice("step: builtin display \(display), available: \(self.builtin.isAvailable)")
            return builtin.stepBrightness(up: up)
        }

        guard Self.externalBrightnessEnabled,
              let service = externalServices[display] else {
            Logger.hud.notice("step: external display \(display) brightness disabled or unpaired")
            return nil
        }
        Logger.hud.notice("step: external display \(display) via DDC")
        let current = externalLevels[display] ?? 0.5
        let stepped = current + (up ? Self.step : -Self.step)
        let snapped = (stepped * 16).rounded() / 16
        let clamped = min(max(snapped, 0), 1)
        ddc.write(.brightness, value: UInt16(clamped * 100), to: service)
        externalLevels[display] = clamped
        return clamped
    }

    // MARK: - External speaker volume (DDC)

    /// DisplayPort/HDMI audio has no system volume control — the monitor
    /// itself must change it, via DDC VCP 0x62. Levels are tracked locally
    /// after seeding, like brightness. Targets the first external monitor
    /// (correct for single-external setups).
    private var externalAudioLevels: [CGDirectDisplayID: Double] = [:]
    private var externalAudioMuted: Set<CGDirectDisplayID> = []

    private var primaryExternal: (display: CGDirectDisplayID, service: CFTypeRef)? {
        externalServices.sorted { $0.key < $1.key }.first
            .map { (display: $0.key, service: $0.value) }
    }

    func stepExternalAudioVolume(up: Bool) -> Double? {
        guard let (display, service) = primaryExternal else { return nil }
        if externalAudioMuted.contains(display) {
            ddc.write(.audioMute, value: 2, to: service) // 2 = unmute
            externalAudioMuted.remove(display)
        }
        let current = externalAudioLevels[display]
            ?? ddc.readPercent(.audioVolume, from: service).map { Double($0) / 100 }
            ?? 0.25
        let stepped = current + (up ? Self.step : -Self.step)
        let snapped = (stepped * 16).rounded() / 16
        let clamped = min(max(snapped, 0), 1)
        ddc.write(.audioVolume, value: UInt16(clamped * 100), to: service)
        externalAudioLevels[display] = clamped
        Logger.hud.notice("external audio volume via DDC: \(clamped)")
        return clamped
    }

    func toggleExternalAudioMute() -> HUDState? {
        guard let (display, service) = primaryExternal else { return nil }
        let nowMuted = !externalAudioMuted.contains(display)
        ddc.write(.audioMute, value: nowMuted ? 1 : 2, to: service)
        if nowMuted {
            externalAudioMuted.insert(display)
        } else {
            externalAudioMuted.remove(display)
        }
        Logger.hud.notice("external audio mute via DDC: \(nowMuted)")
        return HUDState(
            kind: .volume,
            level: externalAudioLevels[display] ?? 0.25,
            muted: nowMuted
        )
    }

    // MARK: - Discovery

    @objc private func screensDidChange() {
        rebuild()
    }

    /// Pairs external display IDs with DDC services. With several external
    /// monitors the pairing is by order, which can mismatch on exotic
    /// multi-monitor setups — fine for the common one-external case.
    private func rebuild() {
        ddc.rescan()
        externalServices = [:]

        var ids = [CGDirectDisplayID](repeating: 0, count: 8)
        var count: UInt32 = 0
        guard CGGetOnlineDisplayList(UInt32(ids.count), &ids, &count) == .success
        else { return }

        let externals = ids.prefix(Int(count))
            .filter { CGDisplayIsBuiltin($0) == 0 }
            .sorted()

        for (index, display) in externals.enumerated() {
            guard let service = ddc.service(at: index) else { continue }
            externalServices[display] = service
            if externalLevels[display] == nil {
                let seeded = ddc.readPercent(.brightness, from: service)
                    .map { Double($0) / 100 }
                externalLevels[display] = seeded ?? 0.5
            }
        }
        Logger.hud.notice("rebuild: \(externals.count) external display(s), \(self.ddc.serviceCount) DDC service(s), paired: \(self.externalServices.count)")
    }

    private static func displayUnderPointer() -> CGDirectDisplayID {
        let point = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(point, $0.frame, false) }
            ?? NSScreen.main
        let number = screen?.deviceDescription[
            NSDeviceDescriptionKey("NSScreenNumber")
        ] as? NSNumber
        return number.map { CGDirectDisplayID($0.uint32Value) } ?? CGMainDisplayID()
    }
}
