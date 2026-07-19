import CoreAudio
import CoreMediaIO
import Foundation
import SwiftUI

/// Watches whether ANY app is using the microphone or camera, publishing
/// an iPhone-style privacy indicator to the wings: orange mic or green
/// camera, with elapsed time.
///
/// Both signals are public API: CoreAudio and CoreMediaIO expose a
/// "device is running somewhere" property per device, with real property
/// listeners — macOS pushes changes, nothing is polled. The per-second
/// elapsed tick only runs while a sensor is actually in use.
///
/// True screen-recording detection has no public API (that state lives in
/// a private framework), so recordings are caught only indirectly, via
/// the microphone most of them capture. Documented in the README.
final class SensorInUseMonitor {
    var onLiveActivityChanged: ((LiveActivity?) -> Void)?

    private(set) var micInUse = false
    private(set) var cameraInUse = false

    private var micDevices: [AudioDeviceID] = []
    private var cameraDevices: [CMIOObjectID] = []
    private var audioListeners: [(AudioObjectID, AudioObjectPropertyListenerBlock)] = []
    private var cameraListeners: [(CMIOObjectID, CMIOObjectPropertyListenerBlock)] = []
    private var activeSince: Date?
    private var tickTask: Task<Void, Never>?
    private var started = false

    func start() {
        guard !started else { return }
        started = true
        rebuildDevices()
        refresh()
    }

    func stop() {
        guard started else { return }
        started = false
        removeListeners()
        tickTask?.cancel()
        tickTask = nil
        activeSince = nil
        micInUse = false
        cameraInUse = false
        onLiveActivityChanged?(nil)
    }

    // MARK: - State

    fileprivate func refresh() {
        guard started else { return }
        let mic = micDevices.contains { audioRunningSomewhere($0) }
        let camera = cameraDevices.contains { cameraRunningSomewhere($0) }
        let wasActive = micInUse || cameraInUse
        micInUse = mic
        cameraInUse = camera
        let isActive = mic || camera

        if isActive, !wasActive {
            activeSince = Date()
            startTicking()
        } else if !isActive, wasActive {
            activeSince = nil
            tickTask?.cancel()
            tickTask = nil
        }
        publish()
    }

    private func startTicking() {
        tickTask?.cancel()
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                self?.publish()
            }
        }
    }

    private func publish() {
        guard micInUse || cameraInUse, let activeSince else {
            onLiveActivityChanged?(nil)
            return
        }
        let elapsed = Int(Date().timeIntervalSince(activeSince))
        onLiveActivityChanged?(
            LiveActivity(
                iconName: cameraInUse ? "video.fill" : "mic.fill",
                text: String(format: "%d:%02d", elapsed / 60, elapsed % 60),
                emphasized: false,
                color: cameraInUse ? .green : .orange
            )
        )
    }

    // MARK: - Device discovery and listeners

    fileprivate func rebuildDevices() {
        removeListeners()
        micDevices = Self.audioInputDevices()
        cameraDevices = Self.cmioCameraDevices()

        // The raw pointer trampoline used by every C callback in Halo:
        // the blocks run on the main queue, so hopping back into MainActor
        // isolation is a statement of fact.
        nonisolated(unsafe) let opaque = Unmanaged.passUnretained(self).toOpaque()

        var audioAddress = Self.audioRunningAddress
        for device in micDevices {
            let block: AudioObjectPropertyListenerBlock = { _, _ in
                MainActor.assumeIsolated {
                    Unmanaged<SensorInUseMonitor>.fromOpaque(opaque)
                        .takeUnretainedValue().refresh()
                }
            }
            AudioObjectAddPropertyListenerBlock(device, &audioAddress, .main, block)
            audioListeners.append((device, block))
        }

        var cameraAddress = Self.cameraRunningAddress
        for device in cameraDevices {
            let block: CMIOObjectPropertyListenerBlock = { _, _ in
                MainActor.assumeIsolated {
                    Unmanaged<SensorInUseMonitor>.fromOpaque(opaque)
                        .takeUnretainedValue().refresh()
                }
            }
            CMIOObjectAddPropertyListenerBlock(device, &cameraAddress, .main, block)
            cameraListeners.append((device, block))
        }

        // Device plug/unplug rebuilds everything.
        var audioDevicesAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let audioListBlock: AudioObjectPropertyListenerBlock = { _, _ in
            MainActor.assumeIsolated {
                let monitor = Unmanaged<SensorInUseMonitor>.fromOpaque(opaque)
                    .takeUnretainedValue()
                monitor.rebuildDevices()
                monitor.refresh()
            }
        }
        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject), &audioDevicesAddress, .main, audioListBlock
        )
        audioListeners.append((AudioObjectID(kAudioObjectSystemObject), audioListBlock))
    }

    private func removeListeners() {
        var audioAddress = Self.audioRunningAddress
        var audioDevicesAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        for (device, block) in audioListeners {
            if device == AudioObjectID(kAudioObjectSystemObject) {
                AudioObjectRemovePropertyListenerBlock(device, &audioDevicesAddress, .main, block)
            } else {
                AudioObjectRemovePropertyListenerBlock(device, &audioAddress, .main, block)
            }
        }
        audioListeners = []

        var cameraAddress = Self.cameraRunningAddress
        for (device, block) in cameraListeners {
            CMIOObjectRemovePropertyListenerBlock(device, &cameraAddress, .main, block)
        }
        cameraListeners = []
    }

    // MARK: - CoreAudio plumbing

    private static var audioRunningAddress: AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
    }

    private func audioRunningSomewhere(_ device: AudioDeviceID) -> Bool {
        var address = Self.audioRunningAddress
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value) == noErr
        else { return false }
        return value != 0
    }

    private static func audioInputDevices() -> [AudioDeviceID] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let system = AudioObjectID(kAudioObjectSystemObject)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr,
              size > 0
        else { return [] }
        var ids = [AudioDeviceID](
            repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size
        )
        guard AudioObjectGetPropertyData(system, &address, 0, nil, &size, &ids) == noErr
        else { return [] }

        return ids.filter { id in
            var streams = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyStreams,
                mScope: kAudioObjectPropertyScopeInput,
                mElement: kAudioObjectPropertyElementMain
            )
            var streamsSize: UInt32 = 0
            return AudioObjectGetPropertyDataSize(id, &streams, 0, nil, &streamsSize) == noErr
                && streamsSize > 0
        }
    }

    // MARK: - CoreMediaIO plumbing

    private static var cameraRunningAddress: CMIOObjectPropertyAddress {
        CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIODevicePropertyDeviceIsRunningSomewhere),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
        )
    }

    private func cameraRunningSomewhere(_ device: CMIOObjectID) -> Bool {
        var address = Self.cameraRunningAddress
        var value: UInt32 = 0
        var used: UInt32 = 0
        guard CMIOObjectGetPropertyData(
            device, &address, 0, nil,
            UInt32(MemoryLayout<UInt32>.size), &used, &value
        ) == noErr else { return false }
        return value != 0
    }

    private static func cmioCameraDevices() -> [CMIOObjectID] {
        var address = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyDevices),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
        )
        let system = CMIOObjectID(kCMIOObjectSystemObject)
        var size: UInt32 = 0
        guard CMIOObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr,
              size > 0
        else { return [] }
        var ids = [CMIOObjectID](
            repeating: 0, count: Int(size) / MemoryLayout<CMIOObjectID>.size
        )
        var used: UInt32 = 0
        guard CMIOObjectGetPropertyData(system, &address, 0, nil, size, &used, &ids) == noErr
        else { return [] }
        return ids
    }
}
