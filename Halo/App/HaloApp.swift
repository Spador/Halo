import SwiftUI

/// Halo's entry point. There is no main window: the app is a menu bar item
/// plus the notch overlay, which is created in `AppDelegate` because it needs
/// AppKit facilities that SwiftUI does not expose (a borderless,
/// non-activating panel above the menu bar). The `Settings` scene provides
/// the standard macOS Settings window.
@main
struct HaloApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.openSettings) private var openSettings

    var body: some Scene {
        MenuBarExtra("Halo", systemImage: "circle.dashed") {
            Button("Settings...") {
                // Agent apps (LSUIElement) are never active, so activate
                // first or the window opens behind whatever is frontmost.
                NSApplication.shared.activate()
                openSettings()
            }
            .keyboardShortcut(",")
            Divider()
            Button("Quit Halo") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }

        Settings {
            SettingsView(settings: .shared)
        }
    }
}
