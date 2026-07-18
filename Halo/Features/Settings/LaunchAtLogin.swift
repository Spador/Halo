import Observation
import ServiceManagement

/// Wraps `SMAppService`, the supported launch-at-login API since macOS 13.
///
/// Registration is user-visible: the app appears under System Settings >
/// General > Login Items, where the user can always override us. The system
/// owns the real state, so this type re-reads `status` after every change
/// instead of trusting its own bookkeeping.
@Observable
final class LaunchAtLogin {
    private(set) var isEnabled: Bool
    private(set) var lastError: String?

    init() {
        isEnabled = SMAppService.mainApp.status == .enabled
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
        isEnabled = SMAppService.mainApp.status == .enabled
    }
}
