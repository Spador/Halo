import AppKit
import Foundation
import Observation

/// Formats countdown seconds as "m:ss" (or "h:mm:ss" past an hour).
enum TimeText {
    static func string(_ interval: TimeInterval) -> String {
        let total = Int(interval.rounded())
        if total >= 3600 {
            return String(format: "%d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60)
        }
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

/// A single quick countdown timer. Independent of the Pomodoro engine so
/// both can run at once. The one-second tick task exists only while the
/// timer runs — idle Halo keeps zero timers.
@Observable
final class QuickTimerEngine {
    struct Countdown: Equatable {
        var totalSeconds: TimeInterval
        var endDate: Date
        /// Non-nil while paused: the frozen remaining seconds.
        var pausedRemaining: TimeInterval?

        var isPaused: Bool { pausedRemaining != nil }

        func remaining(at date: Date) -> TimeInterval {
            pausedRemaining ?? max(endDate.timeIntervalSince(date), 0)
        }

        /// 0 → just started, 1 → done. Drives the completion ring.
        func progress(at date: Date) -> Double {
            guard totalSeconds > 0 else { return 0 }
            return 1 - remaining(at: date) / totalSeconds
        }
    }

    private(set) var countdown: Countdown?

    @ObservationIgnored var onLiveActivityChanged: (LiveActivity?) -> Void = { _ in }
    @ObservationIgnored private var tickTask: Task<Void, Never>?

    func start(minutes: Int) {
        let seconds = TimeInterval(minutes * 60)
        countdown = Countdown(
            totalSeconds: seconds,
            endDate: Date().addingTimeInterval(seconds),
            pausedRemaining: nil
        )
        startTicking()
    }

    func pause() {
        guard var current = countdown, !current.isPaused else { return }
        current.pausedRemaining = current.remaining(at: Date())
        countdown = current
        publishLiveActivity()
    }

    func resume() {
        guard var current = countdown, let remaining = current.pausedRemaining else { return }
        current.endDate = Date().addingTimeInterval(remaining)
        current.pausedRemaining = nil
        countdown = current
        publishLiveActivity()
    }

    func cancel() {
        countdown = nil
        stopTicking()
        onLiveActivityChanged(nil)
    }

    private func startTicking() {
        publishLiveActivity()
        guard tickTask == nil else { return }
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                self?.tick()
            }
        }
    }

    private func stopTicking() {
        tickTask?.cancel()
        tickTask = nil
    }

    private func tick() {
        guard let current = countdown else {
            stopTicking()
            return
        }
        guard !current.isPaused else { return }
        if current.remaining(at: Date()) <= 0 {
            complete()
        } else {
            publishLiveActivity()
        }
    }

    private func complete() {
        countdown = nil
        stopTicking()
        NSSound(named: "Glass")?.play()
        // Brief "done" flash in the wings, then clear.
        onLiveActivityChanged(
            LiveActivity(
                iconName: "checkmark.circle.fill",
                text: String(localized: "Done"),
                emphasized: true
            )
        )
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard let self, self.countdown == nil else { return }
            self.onLiveActivityChanged(nil)
        }
    }

    private func publishLiveActivity() {
        guard let current = countdown else {
            onLiveActivityChanged(nil)
            return
        }
        onLiveActivityChanged(
            LiveActivity(
                iconName: current.isPaused ? "pause.fill" : "timer",
                text: TimeText.string(current.remaining(at: Date())),
                emphasized: false
            )
        )
    }
}
