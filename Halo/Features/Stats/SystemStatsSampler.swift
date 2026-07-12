import Darwin
import Foundation
import IOKit

/// One reading of the system's vitals.
struct StatsSnapshot {
    var cpuUsage: Double?        // 0...1; nil until a delta is available
    var gpuUsage: Double?        // 0...1; nil when the IORegistry offers none
    var ramUsedBytes: UInt64
    var ramTotalBytes: UInt64
    var downloadBps: Double?     // bytes/second; nil until a delta is available
    var uploadBps: Double?
    var accessories: [AccessoryBattery]
}

/// A Bluetooth accessory (AirPods, keyboard…) reporting battery over HID.
struct AccessoryBattery: Identifiable, Equatable {
    let name: String
    let percent: Int
    var id: String { name }
}

/// Reads system vitals from public kernel and IORegistry interfaces.
/// CPU and network are rates, so they need two samples: the first call
/// after a reset only records a baseline.
final class SystemStatsSampler {
    private var previousCPUTicks: (UInt32, UInt32, UInt32, UInt32)?
    private var previousNetwork: (rx: UInt64, tx: UInt64, at: Date)?

    /// Forget baselines (call when sampling stops, so a stale baseline
    /// doesn't skew the first rate after the card reopens).
    func reset() {
        previousCPUTicks = nil
        previousNetwork = nil
    }

    func sample() -> StatsSnapshot {
        let ram = ramUsage()
        let net = networkRates()
        return StatsSnapshot(
            cpuUsage: cpuUsage(),
            gpuUsage: gpuUsage(),
            ramUsedBytes: ram.used,
            ramTotalBytes: ram.total,
            downloadBps: net?.down,
            uploadBps: net?.up,
            accessories: accessoryBatteries()
        )
    }

    // MARK: - CPU

    /// Kernel tick counters per state (user/system/idle/nice); usage is
    /// the busy share of ticks since the previous sample.
    private func cpuUsage() -> Double? {
        var info = host_cpu_load_info()
        var count = mach_msg_type_number_t(
            MemoryLayout<host_cpu_load_info>.stride / MemoryLayout<integer_t>.stride
        )
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }

        let ticks = info.cpu_ticks
        defer { previousCPUTicks = (ticks.0, ticks.1, ticks.2, ticks.3) }
        guard let previous = previousCPUTicks else { return nil }

        // &- : the counters are 32-bit and wrap; wrapping subtraction
        // still yields the correct delta across a single wrap.
        let user = Double(ticks.0 &- previous.0)
        let system = Double(ticks.1 &- previous.1)
        let idle = Double(ticks.2 &- previous.2)
        let nice = Double(ticks.3 &- previous.3)
        let total = user + system + idle + nice
        guard total > 0 else { return nil }
        return (user + system + nice) / total
    }

    // MARK: - RAM

    /// Approximates Activity Monitor's "memory used":
    /// active + wired + compressed pages.
    private func ramUsage() -> (used: UInt64, total: UInt64) {
        let total = ProcessInfo.processInfo.physicalMemory
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64>.stride / MemoryLayout<integer_t>.stride
        )
        let result = withUnsafeMutablePointer(to: &stats) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return (0, total) }
        let pageSize = UInt64(sysconf(_SC_PAGESIZE))
        let used = (UInt64(stats.active_count)
            + UInt64(stats.wire_count)
            + UInt64(stats.compressor_page_count)) * pageSize
        return (used, total)
    }

    // MARK: - Network

    private func networkRates() -> (down: Double, up: Double)? {
        guard let counters = interfaceByteCounts() else { return nil }
        let now = Date()
        defer { previousNetwork = (counters.rx, counters.tx, now) }
        guard let previous = previousNetwork else { return nil }
        let seconds = now.timeIntervalSince(previous.at)
        guard seconds > 0 else { return nil }
        return (
            down: Double(counters.rx &- previous.rx) / seconds,
            up: Double(counters.tx &- previous.tx) / seconds
        )
    }

    /// Total bytes in/out across all non-loopback interfaces since boot.
    private func interfaceByteCounts() -> (rx: UInt64, tx: UInt64)? {
        var addrList: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&addrList) == 0, let first = addrList else { return nil }
        defer { freeifaddrs(addrList) }

        var rx: UInt64 = 0
        var tx: UInt64 = 0
        var cursor: UnsafeMutablePointer<ifaddrs>? = first
        while let interface = cursor {
            defer { cursor = interface.pointee.ifa_next }
            guard let address = interface.pointee.ifa_addr,
                  address.pointee.sa_family == UInt8(AF_LINK),
                  let dataPointer = interface.pointee.ifa_data,
                  !String(cString: interface.pointee.ifa_name).hasPrefix("lo")
            else { continue }
            let data = dataPointer.assumingMemoryBound(to: if_data.self).pointee
            rx &+= UInt64(data.ifi_ibytes)
            tx &+= UInt64(data.ifi_obytes)
        }
        return (rx, tx)
    }

    // MARK: - GPU

    /// Apple Silicon's GPU driver publishes utilization in the IORegistry.
    /// Public interface, undocumented key — if it disappears, the GPU row
    /// simply hides.
    private func gpuUsage() -> Double? {
        var iterator = io_iterator_t()
        guard IOServiceGetMatchingServices(
            0, IOServiceMatching("IOAccelerator"), &iterator
        ) == KERN_SUCCESS else { return nil }
        defer { IOObjectRelease(iterator) }

        while case let entry = IOIteratorNext(iterator), entry != 0 {
            defer { IOObjectRelease(entry) }
            guard let stats = IORegistryEntryCreateCFProperty(
                entry, "PerformanceStatistics" as CFString, nil, 0
            )?.takeRetainedValue() as? [String: Any],
                let utilization = stats["Device Utilization %"] as? Int
            else { continue }
            return Double(utilization) / 100
        }
        return nil
    }

    // MARK: - Bluetooth accessory batteries

    /// AirPods and friends surface battery percent via HID registry
    /// entries — readable without any Bluetooth permission prompt.
    private func accessoryBatteries() -> [AccessoryBattery] {
        var iterator = io_iterator_t()
        guard IOServiceGetMatchingServices(
            0, IOServiceMatching("AppleDeviceManagementHIDEventService"), &iterator
        ) == KERN_SUCCESS else { return [] }
        defer { IOObjectRelease(iterator) }

        // One physical device can appear as several HID services; keep the
        // lowest percent per name (for AirPods that's the emptier bud).
        var byName: [String: Int] = [:]
        while case let entry = IOIteratorNext(iterator), entry != 0 {
            defer { IOObjectRelease(entry) }
            func property(_ key: String) -> Any? {
                IORegistryEntryCreateCFProperty(entry, key as CFString, nil, 0)?
                    .takeRetainedValue()
            }
            let buds = [
                property("BatteryPercentLeft") as? Int,
                property("BatteryPercentRight") as? Int,
            ].compactMap { $0 }.filter { $0 > 0 }
            let percent = buds.min() ?? property("BatteryPercent") as? Int
            guard let percent, percent > 0,
                  let name = property("Product") as? String
            else { continue }
            byName[name] = min(byName[name] ?? 100, percent)
        }
        return byName
            .map { AccessoryBattery(name: $0.key, percent: $0.value) }
            .sorted { $0.name < $1.name }
    }
}
