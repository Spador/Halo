import Foundation
import IOKit.ps
import Observation

struct BatteryStatus: Equatable {
    var percent: Int
    var isCharging: Bool
}

/// Battery state, fully event-driven: macOS invokes our callback whenever
/// power conditions change (plug/unplug, charge ticks). No polling, ever.
@Observable
final class BatteryMonitor {
    private(set) var status: BatteryStatus?

    /// Fires on the transition into charging — the "cable plugged in"
    /// moment the notch celebrates with a flash.
    @ObservationIgnored var onChargingBegan: (BatteryStatus) -> Void = { _ in }

    @ObservationIgnored private var runLoopSource: CFRunLoopSource?

    init() {
        status = Self.read()
        let context = Unmanaged.passUnretained(self).toOpaque()
        if let source = IOPSNotificationCreateRunLoopSource(
            batteryChangeCallback, context
        )?.takeRetainedValue() {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
            runLoopSource = source
        }
    }

    fileprivate func refresh() {
        let previous = status
        status = Self.read()
        if let status, status.isCharging, previous?.isCharging != true {
            onChargingBegan(status)
        }
    }

    private static func read() -> BatteryStatus? {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue()
                as? [CFTypeRef]
        else { return nil }

        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(info, source)?
                .takeUnretainedValue() as? [String: Any],
                let current = description[kIOPSCurrentCapacityKey] as? Int,
                let max = description[kIOPSMaxCapacityKey] as? Int, max > 0
            else { continue }
            return BatteryStatus(
                percent: current * 100 / max,
                isCharging: description[kIOPSIsChargingKey] as? Bool ?? false
            )
        }
        return nil
    }
}

/// C callback from IOKit; registered on the main run loop (see init).
private let batteryChangeCallback: IOPowerSourceCallbackType = { context in
    guard let context else { return }
    nonisolated(unsafe) let ctx = context
    MainActor.assumeIsolated {
        Unmanaged<BatteryMonitor>.fromOpaque(ctx).takeUnretainedValue().refresh()
    }
}
