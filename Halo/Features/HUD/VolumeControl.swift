import AudioToolbox
import CoreAudio

/// System output volume via CoreAudio — fully supported public API.
/// Reads and writes go to the current default output device, so switching
/// to AirPods or external speakers is handled automatically.
final class VolumeControl {
    /// 1/16 steps, matching the system's volume-key behavior.
    private static let step = 1.0 / 16.0

    private var deviceID: AudioDeviceID? {
        var id = kAudioObjectUnknown
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &id
        )
        return (status == noErr && id != kAudioObjectUnknown) ? id : nil
    }

    private var volumeAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
        mScope: kAudioObjectPropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain
    )

    private var muteAddress = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyMute,
        mScope: kAudioObjectPropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain
    )

    /// False when the default output's volume can't be set through
    /// CoreAudio — true of DisplayPort/HDMI monitor audio, which streams at
    /// fixed level and needs DDC commands to the monitor instead.
    var canControlDefaultOutput: Bool {
        guard let deviceID else { return false }
        var settable = DarwinBoolean(false)
        let status = AudioObjectIsPropertySettable(deviceID, &volumeAddress, &settable)
        return status == noErr && settable.boolValue
    }

    var volume: Double {
        guard let deviceID else { return 0 }
        var value: Float32 = 0
        var size = UInt32(MemoryLayout<Float32>.size)
        let status = AudioObjectGetPropertyData(deviceID, &volumeAddress, 0, nil, &size, &value)
        return status == noErr ? Double(value) : 0
    }

    var isMuted: Bool {
        guard let deviceID else { return false }
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        let status = AudioObjectGetPropertyData(deviceID, &muteAddress, 0, nil, &size, &value)
        return status == noErr && value == 1
    }

    func setVolume(_ newValue: Double) {
        guard let deviceID else { return }
        var value = Float32(min(max(newValue, 0), 1))
        let size = UInt32(MemoryLayout<Float32>.size)
        AudioObjectSetPropertyData(deviceID, &volumeAddress, 0, nil, size, &value)
    }

    func setMuted(_ muted: Bool) {
        guard let deviceID else { return }
        var value: UInt32 = muted ? 1 : 0
        let size = UInt32(MemoryLayout<UInt32>.size)
        AudioObjectSetPropertyData(deviceID, &muteAddress, 0, nil, size, &value)
    }

    /// Applies one key-press step and returns the new level for the HUD.
    func stepVolume(up: Bool) -> Double {
        let stepped = volume + (up ? Self.step : -Self.step)
        // Snap to the 1/16 grid so repeated presses land on clean values.
        let snapped = (stepped * 16).rounded() / 16
        let clamped = min(max(snapped, 0), 1)
        setVolume(clamped)
        return clamped
    }
}
