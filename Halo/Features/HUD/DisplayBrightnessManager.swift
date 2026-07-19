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
    private let builtin = BrightnessControl()
    private let ddc = ExternalDisplayDDC()

    /// Display ID → its DDC service, rebuilt when screens change.
    private var externalServices: [CGDirectDisplayID: CFTypeRef] = [:]
    /// Display ID → last level we set (0...1).
    private var externalLevels: [CGDirectDisplayID: Double] = [:]
    /// Displays that PROVABLY apply DDC brightness writes. Verified per
    /// monitor at discovery with a write-and-read-back probe, because some
    /// panels accept audio commands yet silently ignore brightness (the
    /// LG this was built against did exactly that for a while). Unverified
    /// displays fail closed: their brightness keys pass to the system.
    private var externalBrightnessCapable: Set<CGDirectDisplayID> = []
    /// Throttles the second-chance probe fired from a key press.
    private var reprobeInFlight = false

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
        if CGDisplayIsBuiltin(display) != 0 {
            Logger.hud.notice("brightness routing: pointer on builtin display \(display)")
            return builtin.isAvailable
        }
        let capable = externalBrightnessCapable.contains(display)
        let paired = externalServices[display] != nil
        // Notice level on purpose: fires only on brightness key presses,
        // and routing failures here are invisible at debug level.
        Logger.hud.notice("brightness routing: pointer on display \(display), capable: \(capable), paired: \(paired), capable set: \(self.externalBrightnessCapable.map(String.init).joined(separator: ","))")

        // Second chance: the launch-time probe can catch the monitor's
        // DDC bus at a bad moment. An unverified display re-probes on the
        // first key press aimed at it, so the next press can work.
        if !capable, paired, !reprobeInFlight, let service = externalServices[display] {
            reprobeInFlight = true
            Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(150))
                guard let self else { return }
                self.probeBrightness(display: display, service: service)
                self.reprobeInFlight = false
            }
        }
        return capable && paired
    }

    /// Applies one step to the pointer's display; returns the new level
    /// for the HUD, or nil if that display can't be controlled.
    func stepBrightness(up: Bool) -> Double? {
        let display = Self.displayUnderPointer()

        if CGDisplayIsBuiltin(display) != 0 {
            Logger.hud.debug("step: builtin display \(display), available: \(self.builtin.isAvailable)")
            return builtin.stepBrightness(up: up)
        }

        guard externalBrightnessCapable.contains(display),
              let service = externalServices[display] else {
            Logger.hud.debug("step: external display \(display) not brightness-capable or unpaired")
            return nil
        }
        let current = externalLevels[display] ?? 0.5
        let stepped = current + (up ? Self.step : -Self.step)
        let snapped = (stepped * 16).rounded() / 16
        let clamped = min(max(snapped, 0), 1)
        ddc.write(.brightness, value: UInt16(clamped * 100), to: service)
        externalLevels[display] = clamped
        Logger.hud.notice("step: external display \(display) via DDC -> \(Int(clamped * 100))%")
        return clamped
    }

    // MARK: - Absolute levels (control sliders)

    /// Built-in panel brightness for the sliders, bypassing the pointer
    /// routing the keys use.
    func builtinBrightness() -> Double? {
        builtin.currentBrightness()
    }

    func setBuiltinBrightness(_ level: Double) -> Double? {
        builtin.setBrightness(level)
    }

    /// The first external display that provably applies DDC brightness,
    /// for the slider. Nil when there is none (or the probe failed).
    func externalBrightness() -> Double? {
        guard let display = externalBrightnessCapable.sorted().first else { return nil }
        return externalLevels[display]
    }

    func setExternalBrightness(_ level: Double) -> Double? {
        guard let display = externalBrightnessCapable.sorted().first,
              let service = externalServices[display]
        else { return nil }
        let clamped = min(max(level, 0), 1)
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
        Logger.hud.debug("external audio volume via DDC: \(clamped)")
        return clamped
    }

    /// Current monitor-speaker level for the sliders: last tracked value,
    /// else one seed read over DDC. Nil when no external target exists.
    func externalAudioVolume() -> Double? {
        guard let (display, service) = primaryExternal else { return nil }
        return externalAudioLevels[display]
            ?? ddc.readPercent(.audioVolume, from: service).map { Double($0) / 100 }
            ?? 0.25
    }

    /// Absolute setter for the sliders; mirrors the step path including
    /// auto-unmute. Returns the clamped applied level.
    func setExternalAudioVolume(_ level: Double) -> Double? {
        guard let (display, service) = primaryExternal else { return nil }
        if externalAudioMuted.contains(display) {
            ddc.write(.audioMute, value: 2, to: service)
            externalAudioMuted.remove(display)
        }
        let clamped = min(max(level, 0), 1)
        ddc.write(.audioVolume, value: UInt16(clamped * 100), to: service)
        externalAudioLevels[display] = clamped
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
        Logger.hud.debug("external audio mute via DDC: \(nowMuted)")
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

        externalBrightnessCapable = []
        for (index, display) in externals.enumerated() {
            guard let service = ddc.service(at: index) else { continue }
            externalServices[display] = service
            probeBrightness(display: display, service: service)
        }
        Logger.hud.notice("rebuild: \(externals.count) external display(s), \(self.ddc.serviceCount) DDC service(s), paired: \(self.externalServices.count), brightness-capable: \(self.externalBrightnessCapable.count)")
    }

    /// Proves whether the panel applies brightness writes: nudge the level
    /// by one percent, read it back, restore. Imperceptible, runs once per
    /// discovery. A panel that ignores the write (or won't answer reads)
    /// stays out of `externalBrightnessCapable`.
    private func probeBrightness(
        display: CGDirectDisplayID,
        service: CFTypeRef,
        attempt: Int = 1
    ) {
        guard let current = ddc.readPercent(.brightness, from: service) else {
            Logger.hud.notice("probe attempt \(attempt): display \(display) gave no brightness reply")
            // The DDC bus can be busy right after launch or a display
            // change; try again a moment later before giving up.
            if attempt < 3 {
                Task { [weak self] in
                    try? await Task.sleep(for: .seconds(2))
                    guard let self, self.externalServices[display] != nil else { return }
                    self.probeBrightness(
                        display: display, service: service, attempt: attempt + 1
                    )
                }
            }
            return
        }
        let nudge = current >= 100 ? current - 1 : current + 1
        ddc.write(.brightness, value: UInt16(nudge), to: service)
        usleep(100_000)
        let after = ddc.readPercent(.brightness, from: service)
        ddc.write(.brightness, value: UInt16(current), to: service)

        if after == nudge {
            externalBrightnessCapable.insert(display)
            externalLevels[display] = Double(current) / 100
            Logger.hud.notice("probe: display \(display) applies DDC brightness (at \(current)%)")
        } else {
            Logger.hud.notice("probe: display \(display) IGNORES DDC brightness writes")
        }
    }

    /// Which display the pointer is on, asked entirely in CoreGraphics
    /// terms: CGEvent's location and CGGetDisplaysWithPoint share the same
    /// global coordinate space (top-left origin), so there is no AppKit
    /// coordinate conversion to get wrong. The previous NSScreen-based
    /// version silently fell back to the primary display and misrouted
    /// brightness keys pressed over the external monitor.
    private static func displayUnderPointer() -> CGDirectDisplayID {
        guard let point = CGEvent(source: nil)?.location else {
            return CGMainDisplayID()
        }
        var display: CGDirectDisplayID = 0
        var count: UInt32 = 0
        guard CGGetDisplaysWithPoint(point, 1, &display, &count) == .success,
              count > 0
        else { return CGMainDisplayID() }
        return display
    }
}
