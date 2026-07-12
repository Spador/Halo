import AppKit
import ApplicationServices
import os

/// Glues the HUD feature together: media key arrives → apply the change →
/// flash the notch HUD. Also owns the Accessibility permission flow the
/// event tap requires.
final class HUDCoordinator: NSObject {
    private let tap = MediaKeyTap()
    private let volume = VolumeControl()
    private let brightness = DisplayBrightnessManager()
    private let showHUD: (HUDState) -> Void

    init(showHUD: @escaping (HUDState) -> Void) {
        self.showHUD = showHUD
        super.init()
    }

    func start() {
        tap.handler = { [weak self] key, isKeyDown in
            self?.handle(key, isKeyDown: isKeyDown) ?? false
        }

        if AXIsProcessTrusted() {
            let started = tap.start()
            Logger.hud.notice("accessibility trusted; tap started: \(started)")
        } else {
            Logger.hud.notice("accessibility NOT trusted; prompting")
            // Shows the system's "Halo would like to control this computer
            // using accessibility features" dialog, pointing the user to
            // System Settings. We then wait for the grant notification
            // instead of polling.
            // Literal instead of kAXTrustedCheckOptionPrompt: that C global
            // isn't concurrency-safe to reference under Swift 6, but its
            // value is stable and documented.
            let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
            AXIsProcessTrustedWithOptions(options)

            DistributedNotificationCenter.default().addObserver(
                self,
                selector: #selector(accessibilityPermissionsDidChange),
                name: NSNotification.Name("com.apple.accessibility.api"),
                object: nil
            )
        }
    }

    @objc private func accessibilityPermissionsDidChange() {
        // The notification can arrive a beat before TCC reports the new
        // state, hence the short delay before rechecking.
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard let self, !self.tap.isRunning, AXIsProcessTrusted() else { return }
            let started = self.tap.start()
            Logger.hud.notice("accessibility granted while running; tap started: \(started)")
        }
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
                Logger.hud.notice("brightness key: cannot control display under pointer; passing to system")
                return false
            }
            if isKeyDown {
                let level = brightness.stepBrightness(up: key == .brightnessUp)
                Logger.hud.notice("brightness key handled; new level: \(level.map { "\($0)" } ?? "nil")")
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
                    Logger.hud.notice("volume key: output not controllable, no DDC audio; passing to system")
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
