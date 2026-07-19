import EventKit
import Foundation
import Observation

/// A calendar event trimmed to what the pages show. We copy out of EKEvent
/// immediately so the UI never holds live EventKit objects.
struct AgendaEvent: Identifiable, Equatable {
    let id: String
    let title: String
    let start: Date
    let isAllDay: Bool
}

/// The next timed event, with any video-call link found in its fields.
struct UpcomingMeeting: Equatable {
    let title: String
    let start: Date
    let joinURL: URL?
}

/// Calendar data via EventKit. Access is requested only when the user
/// clicks "Connect Calendar" — never at launch — and views re-query when
/// EventKit announces that any calendar changed (`revision` bumps).
@Observable
final class CalendarService: NSObject {
    enum AuthState {
        case notDetermined
        case denied
        case authorized
    }

    private(set) var authState: AuthState = .notDetermined
    /// Bumped on every calendar-database change; views observe it and
    /// re-run their queries.
    private(set) var revision = 0

    /// Non-view listeners (the meeting countdown) that must react to
    /// database changes outside SwiftUI's observation.
    @ObservationIgnored var onChanged: (() -> Void)?

    @ObservationIgnored private let store = EKEventStore()

    override init() {
        super.init()
        authState = Self.currentAuthState()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(storeChanged),
            name: .EKEventStoreChanged,
            object: store
        )
    }

    /// Triggers the system permission prompt (first time only), routed
    /// through the central permissions manager.
    func connect() {
        PermissionsManager.shared.request(.calendar) { [weak self] _ in
            guard let self else { return }
            self.authState = Self.currentAuthState()
            self.revision += 1
            self.onChanged?()
        }
    }

    @objc private func storeChanged() {
        revision += 1
        onChanged?()
    }

    /// All events on the given day, all-day events first.
    func events(on day: Date) -> [AgendaEvent] {
        let calendar = Foundation.Calendar.current
        let start = calendar.startOfDay(for: day)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return [] }
        return fetch(from: start, to: end)
    }

    /// Which day numbers in the given month have at least one event —
    /// drives the dots under the month grid's dates.
    func daysWithEvents(inMonthOf month: Date) -> Set<Int> {
        let calendar = Foundation.Calendar.current
        guard let interval = calendar.dateInterval(of: .month, for: month) else { return [] }
        return Set(fetch(from: interval.start, to: interval.end)
            .map { calendar.component(.day, from: $0.start) })
    }

    private func fetch(from start: Date, to end: Date) -> [AgendaEvent] {
        guard authState == .authorized else { return [] }
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        return store.events(matching: predicate)
            .sorted { ($0.isAllDay ? 0 : 1, $0.startDate) < ($1.isAllDay ? 0 : 1, $1.startDate) }
            .map { event in
                AgendaEvent(
                    // Recurring events share an identifier; the start date
                    // makes each occurrence unique for SwiftUI.
                    id: (event.eventIdentifier ?? "?") + "@\(event.startDate.timeIntervalSince1970)",
                    title: event.title ?? "Untitled",
                    start: event.startDate,
                    isAllDay: event.isAllDay
                )
            }
    }

    /// The next timed event starting within the window — or started less
    /// than five minutes ago, so a just-begun meeting still counts.
    func nextMeeting(withinHours hours: Double = 12) -> UpcomingMeeting? {
        guard authState == .authorized else { return nil }
        let now = Date()
        let windowStart = now.addingTimeInterval(-5 * 60)
        let predicate = store.predicateForEvents(
            withStart: windowStart,
            end: now.addingTimeInterval(hours * 3600),
            calendars: nil
        )
        let next = store.events(matching: predicate)
            .filter { !$0.isAllDay && $0.startDate > windowStart }
            .min { $0.startDate < $1.startDate }
        guard let next else { return nil }
        return UpcomingMeeting(
            title: next.title ?? String(localized: "Meeting"),
            start: next.startDate,
            joinURL: Self.joinLink(in: next)
        )
    }

    /// Zoom and Meet links hide in different fields depending on who
    /// created the invite; check them all.
    private static func joinLink(in event: EKEvent) -> URL? {
        var haystacks: [String] = []
        if let url = event.url?.absoluteString { haystacks.append(url) }
        if let location = event.location { haystacks.append(location) }
        if let notes = event.notes { haystacks.append(notes) }

        let pattern = #"https://[^\s<>"']*(zoom\.us|meet\.google\.com)[^\s<>"']*"#
        for text in haystacks {
            if let range = text.range(of: pattern, options: .regularExpression),
               let url = URL(string: String(text[range])) {
                return url
            }
        }
        return nil
    }

    private static func currentAuthState() -> AuthState {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess: return .authorized
        case .notDetermined: return .notDetermined
        default: return .denied
        }
    }
}
