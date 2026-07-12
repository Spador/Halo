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

    /// Triggers the system permission prompt (first time only).
    func connect() {
        Task { [weak self] in
            _ = try? await self?.store.requestFullAccessToEvents()
            guard let self else { return }
            self.authState = Self.currentAuthState()
            self.revision += 1
        }
    }

    @objc private func storeChanged() {
        revision += 1
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

    private static func currentAuthState() -> AuthState {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess: return .authorized
        case .notDetermined: return .notDetermined
        default: return .denied
        }
    }
}
