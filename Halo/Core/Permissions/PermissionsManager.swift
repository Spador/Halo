import AppKit
import ApplicationServices
import AVFoundation
import EventKit
import Observation

/// The macOS permissions Halo can need. Each is requested only when the
/// feature that needs it is first used, never at install. Camera and
/// Reminders join this list in v2.4.
enum Permission: String, CaseIterable, Identifiable {
    case accessibility
    case calendar
    case camera
    case reminders

    var id: String { rawValue }

    var label: String {
        switch self {
        case .accessibility: String(localized: "Accessibility")
        case .calendar: String(localized: "Calendar")
        case .camera: String(localized: "Camera")
        case .reminders: String(localized: "Reminders")
        }
    }

    var symbol: String {
        switch self {
        case .accessibility: "accessibility"
        case .calendar: "calendar"
        case .camera: "camera"
        case .reminders: "checklist"
        }
    }

    /// Plain-language reason shown in the Settings Permissions tab.
    var explanation: String {
        switch self {
        case .accessibility:
            String(localized: "Lets Halo intercept the volume and brightness keys to replace the system pop ups. Ordinary typing travels on a different event type and never reaches Halo.")
        case .calendar:
            String(localized: "Lets the calendar page show your events. Read only, and asked the first time you click Connect Calendar.")
        case .camera:
            String(localized: "Powers the mirror page. The camera runs only while that page is open, and nothing is ever recorded.")
        case .reminders:
            String(localized: "Lets the to-do page show, add, and complete your reminders. Asked the first time you click Connect Reminders.")
        }
    }

    /// Deep link to this permission's pane in System Settings.
    var settingsPaneURL: URL? {
        let base = "x-apple.systempreferences:com.apple.preference.security"
        switch self {
        case .accessibility: return URL(string: "\(base)?Privacy_Accessibility")
        case .calendar: return URL(string: "\(base)?Privacy_Calendars")
        case .camera: return URL(string: "\(base)?Privacy_Camera")
        case .reminders: return URL(string: "\(base)?Privacy_Reminders")
        }
    }
}

enum PermissionStatus {
    case notDetermined
    case granted
    case denied
}

/// The one place that answers "may Halo do X?". Features check `status(of:)`
/// and call `request` the first time they actually need the capability; the
/// Settings window shows the observable statuses.
///
/// The two permissions behave very differently under the hood, which is
/// exactly why this type exists: Calendar has an async request API that
/// returns the answer, while Accessibility can only be prompted — the grant
/// happens in System Settings whenever the user gets around to it, announced
/// by a distributed notification.
@Observable
final class PermissionsManager: NSObject {
    static let shared = PermissionsManager()

    private(set) var statuses: [Permission: PermissionStatus] = [:]

    /// Completions parked until an Accessibility grant arrives.
    @ObservationIgnored private var pendingAccessibility: [(PermissionStatus) -> Void] = []
    /// Used solely for permission requests; features own their own stores.
    @ObservationIgnored private let eventStore = EKEventStore()

    override private init() {
        super.init()
        refresh()
        // TCC posts this whenever any app's accessibility grant changes —
        // our cue that the user flipped the switch in System Settings.
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(accessibilityDidChange),
            name: NSNotification.Name("com.apple.accessibility.api"),
            object: nil
        )
    }

    func status(of permission: Permission) -> PermissionStatus {
        statuses[permission] ?? .notDetermined
    }

    func refresh() {
        // TCC never reveals whether Accessibility was asked before, only
        // whether it is granted right now — so there is no notDetermined.
        statuses[.accessibility] = AXIsProcessTrusted() ? .granted : .denied
        statuses[.calendar] =
            switch EKEventStore.authorizationStatus(for: .event) {
            case .fullAccess: .granted
            case .notDetermined: .notDetermined
            default: .denied
            }
        statuses[.camera] =
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized: .granted
            case .notDetermined: .notDetermined
            default: .denied
            }
        statuses[.reminders] =
            switch EKEventStore.authorizationStatus(for: .reminder) {
            case .fullAccess: .granted
            case .notDetermined: .notDetermined
            default: .denied
            }
    }

    /// Shows the system prompt. The completion runs when the user answers —
    /// for Accessibility that can be minutes later, after a trip through
    /// System Settings, and a denial there produces no callback at all
    /// because macOS sends no signal for it.
    func request(_ permission: Permission, completion: @escaping (PermissionStatus) -> Void) {
        switch permission {
        case .accessibility:
            if AXIsProcessTrusted() {
                refresh()
                completion(.granted)
                return
            }
            pendingAccessibility.append(completion)
            // Literal instead of kAXTrustedCheckOptionPrompt: the C global
            // is not concurrency-safe to reference under Swift 6, but its
            // value is stable and documented.
            let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
            AXIsProcessTrustedWithOptions(options)

        case .calendar:
            Task { [weak self] in
                _ = try? await self?.eventStore.requestFullAccessToEvents()
                guard let self else { return }
                self.refresh()
                completion(self.status(of: .calendar))
            }

        case .camera:
            Task { [weak self] in
                _ = await AVCaptureDevice.requestAccess(for: .video)
                guard let self else { return }
                self.refresh()
                completion(self.status(of: .camera))
            }

        case .reminders:
            Task { [weak self] in
                _ = try? await self?.eventStore.requestFullAccessToReminders()
                guard let self else { return }
                self.refresh()
                completion(self.status(of: .reminders))
            }
        }
    }

    func openSystemSettings(for permission: Permission) {
        guard let url = permission.settingsPaneURL else { return }
        NSWorkspace.shared.open(url)
    }

    @objc private func accessibilityDidChange() {
        // The notification can arrive a beat before TCC reports the new
        // state, hence the short delay before rechecking.
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard let self else { return }
            self.refresh()
            guard self.status(of: .accessibility) == .granted,
                  !self.pendingAccessibility.isEmpty
            else { return }
            let parked = self.pendingAccessibility
            self.pendingAccessibility = []
            parked.forEach { $0(.granted) }
        }
    }
}
