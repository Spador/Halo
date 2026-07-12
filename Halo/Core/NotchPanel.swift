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

    // Refusing key/main status guarantees a click on the overlay never
    // deactivates whatever app the user is working in.
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
