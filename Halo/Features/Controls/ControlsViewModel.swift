import CoreAudio
import Observation

/// State for the control sliders card. Routes volume to whichever backend
/// currently works — CoreAudio for normal outputs, DDC for monitor speakers
/// over DisplayPort/HDMI — and brightness to the built-in panel.
///
/// Shares its backends with the HUD so key presses and slider drags always
/// agree on the current level.
@Observable
final class ControlsViewModel {
    private(set) var volumeLevel: Double = 0
    private(set) var brightnessLevel: Double = 0
    private(set) var volumeAvailable = false
    private(set) var brightnessAvailable = false
    /// External monitor brightness over DDC — the only way to control it,
    /// since current macOS hides brightness keys from event taps.
    private(set) var externalBrightnessLevel: Double = 0
    private(set) var externalBrightnessAvailable = false
    private(set) var outputDevices: [AudioOutputDevice] = []
    private(set) var currentOutputID: AudioDeviceID?

    /// Observable itself, so views track its state directly.
    let keepAwake = KeepAwake()

    @ObservationIgnored private let volume: VolumeControl
    @ObservationIgnored private let displays: DisplayBrightnessManager
    @ObservationIgnored private let audioDevices = AudioOutputDevices()

    init(volume: VolumeControl, displays: DisplayBrightnessManager) {
        self.volume = volume
        self.displays = displays
    }

    /// Re-reads hardware state. Called when the card appears and after any
    /// HUD key press, so the sliders track the keys live.
    func refresh() {
        if volume.canControlDefaultOutput {
            volumeAvailable = true
            volumeLevel = volume.isMuted ? 0 : volume.volume
        } else if let level = displays.externalAudioVolume() {
            volumeAvailable = true
            volumeLevel = level
        } else {
            volumeAvailable = false
        }

        if let level = displays.builtinBrightness() {
            brightnessAvailable = true
            brightnessLevel = level
        } else {
            brightnessAvailable = false
        }

        if let level = displays.externalBrightness() {
            externalBrightnessAvailable = true
            externalBrightnessLevel = level
        } else {
            externalBrightnessAvailable = false
        }

        outputDevices = audioDevices.list()
        currentOutputID = audioDevices.defaultDeviceID()
    }

    func setExternalBrightness(_ level: Double) {
        let clamped = min(max(level, 0), 1)
        externalBrightnessLevel = clamped
        _ = displays.setExternalBrightness(clamped)
    }

    /// Makes the device the system default output, like the Sound menu.
    /// Volume routing may change with it, so re-read everything.
    func selectOutput(_ device: AudioOutputDevice) {
        audioDevices.setDefault(device.id)
        refresh()
    }

    func setVolume(_ level: Double) {
        let clamped = min(max(level, 0), 1)
        volumeLevel = clamped
        if volume.canControlDefaultOutput {
            if volume.isMuted, clamped > 0 { volume.setMuted(false) }
            volume.setVolume(clamped)
        } else {
            _ = displays.setExternalAudioVolume(clamped)
        }
    }

    func setBrightness(_ level: Double) {
        let clamped = min(max(level, 0), 1)
        brightnessLevel = clamped
        _ = displays.setBuiltinBrightness(clamped)
    }
}
