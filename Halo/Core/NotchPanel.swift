import AppKit

/// The borderless floating window that hosts the notch UI.
///
/// Why NSPanel instead of a SwiftUI window: the overlay must float above
/// the menu bar (`.statusBar` level), must never steal focus from the app
/// you are using (`.nonactivatingPanel`), and must stay put across Spaces
/// and full-screen apps. SwiftUI windows expose none of that.
final class NotchPanel: NSPanel {
    init(contentRect: CGRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        level = .statusBar
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        isMovable = false
        animationBehavior = .none
        collectionBehavior = [
            .canJoinAllSpaces,      // visible on every desktop/Space
            .stationary,            // Mission Control leaves it alone
            .fullScreenAuxiliary,   // allowed to appear over full-screen apps
            .ignoresCycle,          // excluded from Cmd-backtick window cycling
        ]
    }

    // Key status is allowed so text fields (clipboard search) can take
    // typing focus — but because the panel is nonactivating, that never
    // activates Halo or deactivates the app the user is working in, and
    // AppKit only hands a panel key status for views that need typing.
    // Main status stays refused.
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
