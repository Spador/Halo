import EventKit
import Foundation
import Observation

/// One incomplete reminder, copied out of EventKit for the view.
struct TodoItem: Identifiable, Equatable {
    let id: String
    let title: String
    let due: Date?

    var isOverdue: Bool {
        guard let due else { return false }
        return due < Date()
    }
}

/// Reminders via EventKit: shows incomplete ones, completes them, and
/// quick-adds to the default list. Access is requested only when the user
/// clicks Connect Reminders. Re-fetches when EventKit announces changes,
/// so edits made in the Reminders app appear on their own.
@Observable
final class RemindersService: NSObject {
    enum AuthState {
        case notDetermined
        case denied
        case authorized
    }

    private(set) var authState: AuthState = .notDetermined
    private(set) var items: [TodoItem] = []

    @ObservationIgnored private let store = EKEventStore()
    /// The live EKReminder objects behind `items`, needed to complete
    /// them. Keyed by calendarItemIdentifier.
    @ObservationIgnored private var reminders: [String: EKReminder] = [:]

    override init() {
        super.init()
        authState = Self.currentAuthState()
        if authState == .authorized { reload() }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(storeChanged),
            name: .EKEventStoreChanged,
            object: store
        )
    }

    func connect() {
        PermissionsManager.shared.request(.reminders) { [weak self] _ in
            guard let self else { return }
            self.authState = Self.currentAuthState()
            if self.authState == .authorized { self.reload() }
        }
    }

    func complete(_ item: TodoItem) {
        guard let reminder = reminders[item.id] else { return }
        reminder.isCompleted = true
        try? store.save(reminder, commit: true)
        // Optimistic: EKEventStoreChanged confirms shortly.
        items.removeAll { $0.id == item.id }
    }

    /// Quick entry into the default reminders list.
    func add(_ title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty,
              let calendar = store.defaultCalendarForNewReminders()
        else { return }
        let reminder = EKReminder(eventStore: store)
        reminder.title = trimmed
        reminder.calendar = calendar
        try? store.save(reminder, commit: true)
        reload()
    }

    @objc private func storeChanged() {
        guard authState == .authorized else { return }
        reload()
    }

    private func reload() {
        let predicate = store.predicateForIncompleteReminders(
            withDueDateStarting: nil, ending: nil, calendars: nil
        )
        store.fetchReminders(matching: predicate) { fetched in
            // EventKit calls back off the main thread with its own
            // objects; hand them to the main actor in one hop.
            nonisolated(unsafe) let transfer = fetched ?? []
            Task { @MainActor [weak self] in
                self?.apply(transfer)
            }
        }
    }

    private func apply(_ fetched: [EKReminder]) {
        var byID: [String: EKReminder] = [:]
        var list: [TodoItem] = []
        for reminder in fetched {
            let id = reminder.calendarItemIdentifier
            byID[id] = reminder
            list.append(
                TodoItem(
                    id: id,
                    title: reminder.title ?? "",
                    due: reminder.dueDateComponents?.date
                )
            )
        }
        // Due ones first (earliest at top), then the dateless in list order.
        items = list.sorted {
            switch ($0.due, $1.due) {
            case let (a?, b?): a < b
            case (_?, nil): true
            case (nil, _?): false
            case (nil, nil): false
            }
        }
        reminders = byID
    }

    private static func currentAuthState() -> AuthState {
        switch EKEventStore.authorizationStatus(for: .reminder) {
        case .fullAccess: .authorized
        case .notDetermined: .notDetermined
        default: .denied
        }
    }
}
