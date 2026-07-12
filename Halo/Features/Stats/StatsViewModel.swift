import Foundation
import Observation

/// Drives the stats card. Sampling runs only while the card is visible —
/// the view calls start/stop from onAppear/onDisappear — so a collapsed
/// notch costs zero CPU.
@Observable
final class StatsViewModel {
    private(set) var snapshot: StatsSnapshot?
    let battery: BatteryMonitor

    @ObservationIgnored private let sampler = SystemStatsSampler()
    @ObservationIgnored private var samplingTask: Task<Void, Never>?

    private static let interval: Duration = .seconds(2)
    /// Short gap between the baseline sample and the first real one, so
    /// rates appear quickly after opening instead of two seconds later.
    private static let baselineInterval: Duration = .milliseconds(350)

    init(battery: BatteryMonitor) {
        self.battery = battery
    }

    func startSampling() {
        guard samplingTask == nil else { return }
        samplingTask = Task { [weak self] in
            var isBaseline = true
            while !Task.isCancelled {
                guard let self else { return }
                self.snapshot = self.sampler.sample()
                try? await Task.sleep(
                    for: isBaseline ? Self.baselineInterval : Self.interval
                )
                isBaseline = false
            }
        }
    }

    func stopSampling() {
        samplingTask?.cancel()
        samplingTask = nil
        sampler.reset()
    }
}
