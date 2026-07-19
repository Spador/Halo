import Foundation
import Observation

/// Runs the next-meeting countdown in the wings: appears ten minutes
/// before the start, turns green in the last minute, reads "now" once the
/// meeting begins, and clears five minutes in. Clicking the wing (or the
/// calendar banner's Join button) opens the event's Zoom or Meet link.
///
/// Event driven: between meetings a single sleeping task waits for the
/// next show time; the per-second tick only runs while the countdown is
/// actually visible.
@Observable
final class MeetingCountdown {
    /// The meeting the calendar banner shows; nil when none is upcoming.
    private(set) var current: UpcomingMeeting?

    @ObservationIgnored var onLiveActivityChanged: ((LiveActivity?) -> Void)?

    @ObservationIgnored private let calendar: CalendarService
    @ObservationIgnored private let settings: SettingsStore
    @ObservationIgnored private var waitTask: Task<Void, Never>?
    @ObservationIgnored private var tickTask: Task<Void, Never>?

    /// The countdown appears this long before the start.
    private static let lead: TimeInterval = 10 * 60
    /// And lingers this long after it, reading "now".
    private static let grace: TimeInterval = 5 * 60

    init(calendar: CalendarService, settings: SettingsStore = .shared) {
        self.calendar = calendar
        self.settings = settings
    }

    /// Recomputes the next meeting and repositions the countdown. Called
    /// at launch, on every calendar-database change, and on flag flips.
    func refresh() {
        waitTask?.cancel()
        tickTask?.cancel()
        waitTask = nil
        tickTask = nil

        guard settings.isEnabled(.meetings),
              let meeting = calendar.nextMeeting()
        else {
            current = nil
            onLiveActivityChanged?(nil)
            return
        }
        current = meeting

        let untilShow = meeting.start.addingTimeInterval(-Self.lead).timeIntervalSinceNow
        if untilShow > 0 {
            onLiveActivityChanged?(nil)
            waitTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(untilShow + 0.5))
                guard !Task.isCancelled else { return }
                self?.refresh()
            }
        } else {
            startTicking(meeting)
        }
    }

    func stop() {
        waitTask?.cancel()
        tickTask?.cancel()
        waitTask = nil
        tickTask = nil
        current = nil
        onLiveActivityChanged?(nil)
    }

    private func startTicking(_ meeting: UpcomingMeeting) {
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let remaining = meeting.start.timeIntervalSinceNow
                if remaining < -Self.grace {
                    self.refresh()
                    return
                }
                self.onLiveActivityChanged?(
                    Self.activity(for: meeting, remaining: remaining)
                )
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private static func activity(
        for meeting: UpcomingMeeting,
        remaining: TimeInterval
    ) -> LiveActivity {
        let text: String
        if remaining <= 0 {
            text = String(localized: "now")
        } else {
            let total = Int(remaining)
            text = String(format: "%d:%02d", total / 60, total % 60)
        }
        return LiveActivity(
            iconName: "video.fill",
            text: text,
            emphasized: remaining <= 60,
            url: meeting.joinURL
        )
    }
}
