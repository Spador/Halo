import SwiftUI

/// The stats card: live CPU/GPU/RAM bars, network rates, battery, and
/// Bluetooth accessory batteries.
struct StatsView: View {
    let viewModel: StatsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            if let snapshot = viewModel.snapshot {
                barRow("CPU", fraction: snapshot.cpuUsage)
                if let gpu = snapshot.gpuUsage {
                    barRow("GPU", fraction: gpu)
                }
                ramRow(snapshot)
                networkRow(snapshot)
                batteryRow(accessories: snapshot.accessories)
            } else {
                Text("Measuring…")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .padding(.horizontal, 26)
        .onAppear { viewModel.startSampling() }
        .onDisappear { viewModel.stopSampling() }
    }

    // MARK: - Rows

    private func barRow(_ label: String, fraction: Double?) -> some View {
        HStack(spacing: 8) {
            rowLabel(label)
            levelBar(fraction ?? 0)
            rowValue(fraction.map { "\(Int($0 * 100))%" } ?? "–")
        }
    }

    private func ramRow(_ snapshot: StatsSnapshot) -> some View {
        let fraction = snapshot.ramTotalBytes > 0
            ? Double(snapshot.ramUsedBytes) / Double(snapshot.ramTotalBytes)
            : 0
        return HStack(spacing: 8) {
            rowLabel("RAM")
            levelBar(fraction)
            rowValue("\(gigabytes(snapshot.ramUsedBytes)) / \(gigabytes(snapshot.ramTotalBytes)) GB")
        }
    }

    private func networkRow(_ snapshot: StatsSnapshot) -> some View {
        HStack(spacing: 8) {
            rowLabel("NET")
            Text("↓ \(rate(snapshot.downloadBps))   ↑ \(rate(snapshot.uploadBps))")
                .font(.system(size: 10).monospacedDigit())
                .foregroundStyle(.white.opacity(0.8))
            Spacer(minLength: 0)
        }
    }

    private func batteryRow(accessories: [AccessoryBattery]) -> some View {
        HStack(spacing: 8) {
            rowLabel("BAT")
            if let battery = viewModel.battery.status {
                Image(systemName: battery.isCharging ? "bolt.fill" : "battery.75percent")
                    .font(.system(size: 9))
                    .foregroundStyle(battery.isCharging ? .green : .white.opacity(0.8))
                Text("\(battery.percent)%")
                    .font(.system(size: 10).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.8))
            } else {
                Text("–")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.5))
            }
            ForEach(accessories.prefix(2)) { accessory in
                Text("· \(accessory.name) \(accessory.percent)%")
                    .font(.system(size: 10).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - Pieces

    private func rowLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(.white.opacity(0.45))
            .frame(width: 28, alignment: .leading)
    }

    private func rowValue(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10).monospacedDigit())
            .foregroundStyle(.white.opacity(0.8))
            .frame(width: 84, alignment: .trailing)
    }

    private func levelBar(_ fraction: Double) -> some View {
        Capsule()
            .fill(.white.opacity(0.15))
            .frame(height: 4)
            .overlay(alignment: .leading) {
                GeometryReader { geometry in
                    Capsule()
                        .fill(.white.opacity(0.85))
                        .frame(width: geometry.size.width * min(max(fraction, 0), 1))
                }
            }
            .animation(.easeOut(duration: 0.4), value: fraction)
    }

    // MARK: - Formatting

    private func gigabytes(_ bytes: UInt64) -> String {
        String(format: "%.1f", Double(bytes) / 1_073_741_824)
    }

    private func rate(_ bytesPerSecond: Double?) -> String {
        guard let bytesPerSecond else { return "–" }
        switch bytesPerSecond {
        case ..<1024: return "\(Int(bytesPerSecond)) B/s"
        case ..<1_048_576: return String(format: "%.0f KB/s", bytesPerSecond / 1024)
        default: return String(format: "%.1f MB/s", bytesPerSecond / 1_048_576)
        }
    }
}
