import SwiftUI

/// Halo's entry point. There is no main window: the app is a menu bar item
/// (for Quit, and later a settings panel) plus the notch overlay, which is
/// created in `AppDelegate` because it needs AppKit facilities that SwiftUI
/// does not expose (a borderless, non-activating panel above the menu bar).
@main
struct HaloApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("Halo", systemImage: "circle.dashed") {
            Button("Quit Halo") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }
}
