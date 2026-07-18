import AppKit
import ApplicationServices
import os

/// Glues the HUD feature together: media key arrives → apply the change →
/// flash the notch HUD. Also owns the Accessibility permission flow the
/// event tap requires.
final class HUDCoordinator: NSObject {
    private let tap = MediaKeyTap()
    private let volume: VolumeControl
    private let brightness: DisplayBrightnessManager
    private let showHUD: (HUDState) -> Void

    /// The volume and display backends are shared with the control sliders
    /// so both paths see one consistent (DDC-tracked) state.
    init(
        volume: VolumeControl,
        brightness: DisplayBrightnessManager,
        showHUD: @escaping (HUDState) -> Void
    ) {
        self.volume = volume
        self.brightness = brightness
        self.showHUD = showHUD
        super.init()
    }

    func start() {
        tap.handler = { [weak self] key, isKeyDown in
            self?.handle(key, isKeyDown: isKeyDown) ?? false
        }

        let permissions = PermissionsManager.shared
        if permissions.status(of: .accessibility) == .granted {
            let started = tap.start()
            Logger.hud.notice("accessibility trusted; tap started: \(started)")
        } else {
            // Prompts now; the completion fires whenever the grant lands,
            // even after a detour through System Settings.
            Logger.hud.notice("accessibility NOT trusted; requesting")
            permissions.request(.accessibility) { [weak self] status in
                guard let self, status == .granted, !self.tap.isRunning else { return }
                let started = self.tap.start()
                Logger.hud.notice("accessibility granted while running; tap started: \(started)")
            }
        }
    }

    /// Continuous volume change from the scroll wheel, using the same
    /// output routing as the keys (CoreAudio, else DDC monitor speakers)
    /// and the same HUD flash. Needs no event tap, so it works even while
    /// the HUD key feature is off or unpermitted.
    func adjustVolume(by delta: Double) {
        guard delta != 0 else { return }
        if volume.canControlDefaultOutput {
            if volume.isMuted, delta > 0 { volume.setMuted(false) }
            let level = min(max(volume.volume + delta, 0), 1)
            volume.setVolume(level)
            showHUD(HUDState(kind: .volume, level: level))
        } else if let current = brightness.externalAudioVolume() {
            let level = min(max(current + delta, 0), 1)
            _ = brightness.setExternalAudioVolume(level)
            showHUD(HUDState(kind: .volume, level: level))
        }
    }

    /// Feature toggled off: release the event tap so the stock system
    /// HUDs come back instantly. The Accessibility grant itself stays.
    func stop() {
        tap.stop()
        Logger.hud.notice("HUD feature disabled; tap stopped")
    }

    /// Returns true to swallow the key press (suppressing the system HUD).
    /// Changes apply on key-down (including autorepeat while held); the
    /// matching key-ups are swallowed too so the system never reacts.
    private func handle(_ key: MediaKey, isKeyDown: Bool) -> Bool {
        switch key {
        case .brightnessUp, .brightnessDown:
            // Can't control the display the pointer is on? Pass the key to
            // the system (checked on down AND up so both are consistent).
            guard brightness.canControlDisplayUnderPointer() else {
                Logger.hud.debug("brightness key: cannot control display under pointer; passing to system")
                return false
            }
            if isKeyDown {
                let level = brightness.stepBrightness(up: key == .brightnessUp)
                Logger.hud.debug("brightness key handled; new level: \(level.map { "\($0)" } ?? "nil")")
                if let level {
                    showHUD(HUDState(kind: .brightness, level: level))
                }
            }
            return true

        case .volumeUp, .volumeDown:
            if isKeyDown {
                if volume.canControlDefaultOutput {
                    if volume.isMuted { volume.setMuted(false) }
                    let level = volume.stepVolume(up: key == .volumeUp)
                    showHUD(HUDState(kind: .volume, level: level))
                } else if let level = brightness.stepExternalAudioVolume(up: key == .volumeUp) {
                    // Monitor speakers over DisplayPort/HDMI: only DDC works.
                    showHUD(HUDState(kind: .volume, level: level))
                } else {
                    Logger.hud.debug("volume key: output not controllable, no DDC audio; passing to system")
                    return false
                }
            }
            return true

        case .mute:
            if isKeyDown {
                if volume.canControlDefaultOutput {
                    let muted = !volume.isMuted
                    volume.setMuted(muted)
                    showHUD(HUDState(kind: .volume, level: volume.volume, muted: muted))
                } else if let state = brightness.toggleExternalAudioMute() {
                    showHUD(state)
                } else {
                    return false
                }
            }
            return true
        }
    }
}
