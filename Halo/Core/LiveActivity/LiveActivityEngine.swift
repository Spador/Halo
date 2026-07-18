import Foundation

/// Everything that can hold the collapsed notch's wings. Raw value order is
/// display priority: lower wins the first slot. Sources without a publisher
/// yet are claimed by upcoming v2 features (recording and transfer in v2.3,
/// media in v2.0).
enum LiveActivitySource: Int, CaseIterable {
    case recording
    case quickTimer
    case pomodoro
    case transfer
    case media
}

/// One source's current activity, tagged so the wings can tell them apart.
struct LiveActivityItem: Equatable, Identifiable {
    let source: LiveActivitySource
    var activity: LiveActivity

    var id: LiveActivitySource { source }
}

/// Collects live activities from every feature and decides what the wings
/// show. One active source displays alone in the classic wide layout; two
/// split the wings, one each; more than two keeps the most urgent pinned
/// left while the right slot rotates through the rest.
///
/// Pure push: features call `publish` when their state changes, and the
/// rotation timer only exists while three or more sources are active.
final class LiveActivityEngine {
    /// Fired with the (at most two) items to display whenever they change.
    /// Per-second countdown text flows through here too; the subscriber
    /// decides whether a change needs a window re-frame.
    var onDisplayChanged: (([LiveActivityItem]) -> Void)?

    private var bySource: [LiveActivitySource: LiveActivity] = [:]
    private var displayed: [LiveActivityItem] = []
    private var rotationIndex = 0
    private var rotationTask: Task<Void, Never>?

    private static let rotationInterval: Duration = .seconds(4)

    /// Sets (or with nil, clears) a source's activity.
    func publish(_ activity: LiveActivity?, from source: LiveActivitySource) {
        if let activity {
            bySource[source] = activity
        } else {
            bySource.removeValue(forKey: source)
        }
        recompute()
    }

    private func recompute() {
        let ranked = bySource
            .map { LiveActivityItem(source: $0.key, activity: $0.value) }
            .sorted { $0.source.rawValue < $1.source.rawValue }

        let newDisplay: [LiveActivityItem]
        if ranked.count <= 2 {
            stopRotation()
            newDisplay = ranked
        } else {
            let rest = Array(ranked.dropFirst())
            newDisplay = [ranked[0], rest[rotationIndex % rest.count]]
            startRotationIfNeeded()
        }

        guard newDisplay != displayed else { return }
        displayed = newDisplay
        onDisplayChanged?(newDisplay)
    }

    private func startRotationIfNeeded() {
        guard rotationTask == nil else { return }
        rotationTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.rotationInterval)
                guard !Task.isCancelled, let self else { return }
                self.rotationIndex += 1
                self.recompute()
            }
        }
    }

    private func stopRotation() {
        rotationTask?.cancel()
        rotationTask = nil
        rotationIndex = 0
    }
}
