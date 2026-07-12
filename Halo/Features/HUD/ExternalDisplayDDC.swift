import CoreGraphics
import IOKit

/// DDC/CI brightness for external monitors on Apple Silicon.
///
/// DDC/CI is a standard command channel that rides the display cable; VCP
/// code 0x10 is brightness. On Apple Silicon the I2C bus is reached through
/// the private IOAVService interface (the same technique MonitorControl and
/// Lunar use). Everything is loaded dynamically: if Apple removes these
/// symbols, discovery finds nothing and external brightness keys simply
/// fall through to the system.
final class ExternalDisplayDDC {
    private typealias CreateServiceFn =
        @convention(c) (CFAllocator?, io_service_t) -> CFTypeRef?
    private typealias I2CFn =
        @convention(c) (CFTypeRef?, UInt32, UInt32, UnsafeMutablePointer<UInt8>?, UInt32) -> IOReturn

    private let createService: CreateServiceFn?
    private let writeI2C: I2CFn?
    private let readI2C: I2CFn?

    /// AV services for external displays, in IORegistry discovery order.
    private var services: [CFTypeRef] = []

    private static let i2cAddress: UInt32 = 0x37  // DDC/CI device on the bus
    private static let dataOffset: UInt32 = 0x51  // host-to-display sub-address

    /// Standard VCP (Virtual Control Panel) codes from the MCCS spec.
    enum VCP: UInt8 {
        case brightness = 0x10
        case audioVolume = 0x62
        case audioMute = 0x8D
    }

    init() {
        let rtldDefault = UnsafeMutableRawPointer(bitPattern: -2) // RTLD_DEFAULT
        createService = dlsym(rtldDefault, "IOAVServiceCreateWithService").map {
            unsafeBitCast($0, to: CreateServiceFn.self)
        }
        writeI2C = dlsym(rtldDefault, "IOAVServiceWriteI2C").map {
            unsafeBitCast($0, to: I2CFn.self)
        }
        readI2C = dlsym(rtldDefault, "IOAVServiceReadI2C").map {
            unsafeBitCast($0, to: I2CFn.self)
        }
    }

    var isAvailable: Bool { createService != nil && writeI2C != nil }

    var serviceCount: Int { services.count }

    func service(at index: Int) -> CFTypeRef? {
        index < services.count ? services[index] : nil
    }

    /// Finds the I2C endpoints of currently connected external displays.
    /// Call again when displays are plugged/unplugged.
    func rescan() {
        services = []
        guard let createService else { return }

        var iterator = io_iterator_t()
        // Port 0 = the default IOKit port (avoids the kIOMainPortDefault
        // global, which Swift 6 flags as concurrency-unsafe).
        guard IOServiceGetMatchingServices(
            0, IOServiceMatching("DCPAVServiceProxy"), &iterator
        ) == KERN_SUCCESS else { return }
        defer { IOObjectRelease(iterator) }

        while case let entry = IOIteratorNext(iterator), entry != 0 {
            defer { IOObjectRelease(entry) }
            let location = IORegistryEntryCreateCFProperty(
                entry, "Location" as CFString, nil, 0
            )?.takeRetainedValue() as? String
            guard location == "External" else { continue }
            if let service = createService(nil, entry) {
                services.append(service)
            }
        }
    }

    /// Sets a VCP control's value. Fire-and-forget: most monitors apply it
    /// immediately; there is no reliable acknowledgment.
    func write(_ vcp: VCP, value: UInt16, to service: CFTypeRef) {
        guard let writeI2C else { return }
        var packet: [UInt8] = [
            0x84, 0x03, vcp.rawValue, UInt8(value >> 8), UInt8(value & 0xFF), 0,
        ]
        packet[5] = 0x6E ^ 0x51 ^ packet[0] ^ packet[1] ^ packet[2] ^ packet[3] ^ packet[4]
        _ = packet.withUnsafeMutableBufferPointer {
            writeI2C(service, Self.i2cAddress, Self.dataOffset, $0.baseAddress, UInt32($0.count))
        }
    }

    /// Reads a VCP control as a 0...100 percent of its maximum, or nil if
    /// the monitor doesn't answer (some don't). Used to seed our tracking.
    func readPercent(_ vcp: VCP, from service: CFTypeRef) -> Int? {
        guard let writeI2C, let readI2C else { return nil }

        var request: [UInt8] = [0x82, 0x01, vcp.rawValue, 0]
        request[3] = 0x6E ^ 0x51 ^ request[0] ^ request[1] ^ request[2]

        for _ in 0..<3 {
            let writeResult = request.withUnsafeMutableBufferPointer {
                writeI2C(service, Self.i2cAddress, Self.dataOffset, $0.baseAddress, UInt32($0.count))
            }
            guard writeResult == KERN_SUCCESS else { continue }
            usleep(10_000) // give the monitor a beat to prepare the reply

            var reply = [UInt8](repeating: 0, count: 12)
            let readResult = reply.withUnsafeMutableBufferPointer {
                readI2C(service, Self.i2cAddress, Self.dataOffset, $0.baseAddress, UInt32($0.count))
            }
            // Reply layout: [.., result, vcp, .., maxHi, maxLo, curHi, curLo, ..]
            if readResult == KERN_SUCCESS, reply[4] == vcp.rawValue {
                let max = Int(reply[6]) << 8 | Int(reply[7])
                let current = Int(reply[8]) << 8 | Int(reply[9])
                if max > 0, current <= max {
                    return current * 100 / max
                }
            }
            usleep(10_000)
        }
        return nil
    }
}
