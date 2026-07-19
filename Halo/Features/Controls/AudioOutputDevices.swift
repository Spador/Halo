import CoreAudio
import Foundation

/// One selectable output destination.
struct AudioOutputDevice: Identifiable, Equatable {
    let id: AudioDeviceID
    let name: String
    let transportType: UInt32

    var iconName: String {
        switch transportType {
        case kAudioDeviceTransportTypeBluetooth,
            kAudioDeviceTransportTypeBluetoothLE:
            "airpods"
        case kAudioDeviceTransportTypeBuiltIn:
            "laptopcomputer"
        case kAudioDeviceTransportTypeDisplayPort,
            kAudioDeviceTransportTypeHDMI:
            "display"
        case kAudioDeviceTransportTypeUSB:
            "hifispeaker.fill"
        case kAudioDeviceTransportTypeAirPlay:
            "airplayaudio"
        default:
            "speaker.wave.2.fill"
        }
    }
}

/// Lists output-capable audio devices and switches the system default —
/// exactly what the menu bar Sound picker does, all public CoreAudio API.
final class AudioOutputDevices {
    /// Every device with at least one output stream, in system order.
    func list() -> [AudioOutputDevice] {
        var address = Self.address(kAudioHardwarePropertyDevices)
        var size: UInt32 = 0
        let system = AudioObjectID(kAudioObjectSystemObject)
        guard AudioObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr,
              size > 0
        else { return [] }

        var ids = [AudioDeviceID](
            repeating: 0,
            count: Int(size) / MemoryLayout<AudioDeviceID>.size
        )
        guard AudioObjectGetPropertyData(system, &address, 0, nil, &size, &ids) == noErr
        else { return [] }

        return ids.compactMap { id in
            guard hasOutputStreams(id), let name = name(of: id) else { return nil }
            return AudioOutputDevice(
                id: id,
                name: name,
                transportType: transportType(of: id)
            )
        }
    }

    func defaultDeviceID() -> AudioDeviceID? {
        var address = Self.address(kAudioHardwarePropertyDefaultOutputDevice)
        var id = kAudioObjectUnknown
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &id
        )
        return status == noErr && id != kAudioObjectUnknown ? id : nil
    }

    func setDefault(_ id: AudioDeviceID) {
        var address = Self.address(kAudioHardwarePropertyDefaultOutputDevice)
        var deviceID = id
        AudioObjectSetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            UInt32(MemoryLayout<AudioDeviceID>.size),
            &deviceID
        )
    }

    // MARK: - Per-device properties

    private func hasOutputStreams(_ id: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(id, &address, 0, nil, &size) == noErr
        else { return false }
        return size > 0
    }

    private func name(of id: AudioDeviceID) -> String? {
        var address = Self.address(kAudioObjectPropertyName)
        var value: CFString?
        var size = UInt32(MemoryLayout<CFString?>.size)
        let status = withUnsafeMutablePointer(to: &value) { pointer in
            AudioObjectGetPropertyData(id, &address, 0, nil, &size, pointer)
        }
        return status == noErr ? value as String? : nil
    }

    private func transportType(of id: AudioDeviceID) -> UInt32 {
        var address = Self.address(kAudioDevicePropertyTransportType)
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, &value) == noErr
        else { return 0 }
        return value
    }

    private static func address(
        _ selector: AudioObjectPropertySelector
    ) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
    }
}
