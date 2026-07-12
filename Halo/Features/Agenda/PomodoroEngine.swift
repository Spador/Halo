import AppKit
import Foundation
import Observation

/// The Pomodoro cycle: focus rounds separated by short breaks, with a
/// long break after every full set. Settings persist across launches.
/// Independent of the quick timer so both can run at once.
@Observable
final class PomodoroEngine {
    struct Settings: Codable, Equatable {
        var workMinutes = 25
        var breakMinutes = 5
        var longBreakMinutes = 15
        var roundsPerSet = 4
    }

    enum Phase: Equatable {
        case work
        case shortBreak
        case longBreak

        var label: String {
            switch self {
            case .work: return "Focus"
            case .shortBreak: return "Break"
            case .longBreak: return "Long break"
            }
        }

        var iconName: String {
            switch self {
            case .work: return "brain.head.profile"
            case .shortBreak: return "cup.and.saucer.fill"
            case .longBreak: return "moon.zzz.fill"
            }
        }
    }

    struct Session: Equatable {
        var phase: Phase
        /// 1-based focus round within the current set.
        var round: Int
        var phaseTotal: TimeInterval
        var endDate: Date
        var pausedRemaining: TimeInterval?

        var isPaused: Bool { pausedRemaining != nil }

        func remaining(at date: Date) -> TimeInterval {
            pausedRemaining ?? max(endDate.timeIntervalSince(date), 0)
        }

        func progress(at date: Date) -> Double {
            guard phaseTotal > 0 else { return 0 }
            return 1 - remaining(at: date) / phaseTotal
        }
    }

    var settings = Settings() {
        didSet { persistSettings() }
    }
    private(set) var session: Session?

    @ObservationIgnored var onLiveActivityChanged: (LiveActivity?) -> Void = { _ in }
    @ObservationIgnored private var tickTask: Task<Void, Never>?

    private static let settingsKey = "pomodoro.settings"

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.settingsKey),
           let saved = try? JSONDecoder().decode(Settings.self, from: data) {
            settings = saved
        }
    }

    // MARK: - Controls

    func start() {
        session = makeSession(phase: .work, round: 1)
        startTicking()
    }

    func pause() {
        guard var current = session, !current.isPaused else { return }
        current.pausedRemaining = current.remaining(at: Date())
        session = current
        publishLiveActivity()
    }

    func resume() {
        guard var current = session, let remaining = current.pausedRemaining else { return }
        current.endDate = Date().addingTimeInterval(remaining)
        current.pausedRemaining = nil
        session = current
        publishLiveActivity()
    }

    /// Jump to the next phase immediately (no chime).
    func skip() {
        advancePhase(chime: false)
    }

    func reset() {
        session = nil
        stopTicking()
        onLiveActivityChanged(nil)
    }

    // MARK: - Cycle

    private func makeSession(phase: Phase, round: Int) -> Session {
        let minutes: Int
        switch phase {
        case .work: minutes = settings.workMinutes
        case .shortBreak: minutes = settings.breakMinutes
        case .longBreak: minutes = settings.longBreakMinutes
        }
        let total = TimeInterval(minutes * 60)
        return Session(
            phase: phase,
            round: round,
            phaseTotal: total,
            endDate: Date().addingTimeInterval(total),
            pausedRemaining: nil
        )
    }

    private func advancePhase(chime: Bool) {
        guard let finished = session else { return }
        if chime { NSSound(named: "Glass")?.play() }

        switch finished.phase {
        case .work:
            // Long break closes a full set; short break otherwise.
            let isSetComplete = finished.round >= settings.roundsPerSet
            session = makeSession(
                phase: isSetComplete ? .longBreak : .shortBreak,
                round: finished.round
            )
        case .shortBreak:
            session = makeSession(phase: .work, round: finished.round + 1)
        case .longBreak:
            session = makeSession(phase: .work, round: 1)
        }
        publishLiveActivity()
    }

    // MARK: - Ticking

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
        guard let current = session else {
            stopTicking()
            return
        }
        guard !current.isPaused else { return }
        if current.remaining(at: Date()) <= 0 {
            advancePhase(chime: true)
        } else {
            publishLiveActivity()
        }
    }

    private func publishLiveActivity() {
        guard let current = session else {
            onLiveActivityChanged(nil)
            return
        }
        onLiveActivityChanged(
            LiveActivity(
                iconName: current.isPaused ? "pause.fill" : current.phase.iconName,
                text: TimeText.string(current.remaining(at: Date())),
                emphasized: current.phase != .work
            )
        )
    }

    private func persistSettings() {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: Self.settingsKey)
        }
    }
}
