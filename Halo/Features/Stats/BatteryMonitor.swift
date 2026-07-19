import Foundation
import IOKit.ps
import Observation

struct BatteryStatus: Equatable {
    var percent: Int
    var isCharging: Bool
    /// Minutes until full while charging; nil when discharging or while
    /// macOS is still calculating.
    var timeToFullMinutes: Int?
}

/// Battery state, fully event-driven: macOS invokes our callback whenever
/// power conditions change (plug/unplug, charge ticks). No polling, ever.
@Observable
final class BatteryMonitor {
    private(set) var status: BatteryStatus?
    /// Maximum capacity as a percent of design capacity — the number
    /// System Settings calls battery health. Read once; it moves on the
    /// scale of months.
    private(set) var healthPercent: Int?
    private(set) var cycleCount: Int?

    /// Fires on the transition into charging — the "cable plugged in"
    /// moment the notch celebrates with a flash.
    @ObservationIgnored var onChargingBegan: (BatteryStatus) -> Void = { _ in }

    /// Fires once when the battery sinks through 20 percent, and again at
    /// 10, while discharging. Re-arms when the level recovers or charging
    /// starts — so it warns per crossing, not per percent tick.
    @ObservationIgnored var onLowBattery: (BatteryStatus) -> Void = { _ in }

    @ObservationIgnored private var runLoopSource: CFRunLoopSource?
    @ObservationIgnored private var warnedThresholds: Set<Int> = []

    private static let warningThresholds = [20, 10]

    init() {
        status = Self.read()
        readHealth()
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
        guard let status else { return }

        if status.isCharging, previous?.isCharging != true {
            onChargingBegan(status)
        }

        if status.isCharging {
            warnedThresholds = []
        } else {
            for threshold in Self.warningThresholds
            where status.percent <= threshold && !warnedThresholds.contains(threshold) {
                // Only warn on an actual downward crossing, not because
                // the app launched with an already-low battery reading
                // followed by the first callback.
                if let previous, previous.percent > threshold || previous.isCharging {
                    warnedThresholds.insert(threshold)
                    onLowBattery(status)
                } else if previous == nil {
                    warnedThresholds.insert(threshold)
                }
            }
            // Re-arm thresholds the level has climbed back above.
            warnedThresholds = warnedThresholds.filter { status.percent <= $0 }
        }
    }

    /// Health comes from the battery's IORegistry entry — the same data
    /// System Settings shows, no permissions involved.
    private func readHealth() {
        let entry = IOServiceGetMatchingService(
            0, IOServiceMatching("AppleSmartBattery")
        )
        guard entry != 0 else { return }
        defer { IOObjectRelease(entry) }

        func property(_ key: String) -> Int? {
            IORegistryEntryCreateCFProperty(entry, key as CFString, nil, 0)?
                .takeRetainedValue() as? Int
        }

        cycleCount = property("CycleCount")
        if let raw = property("AppleRawMaxCapacity"),
           let design = property("DesignCapacity"),
           design > 0 {
            healthPercent = min(raw * 100 / design, 100)
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
            let charging = description[kIOPSIsChargingKey] as? Bool ?? false
            let timeToFull = description[kIOPSTimeToFullChargeKey] as? Int
            return BatteryStatus(
                percent: current * 100 / max,
                isCharging: charging,
                // -1 means macOS is still estimating.
                timeToFullMinutes: charging && (timeToFull ?? -1) > 0 ? timeToFull : nil
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
