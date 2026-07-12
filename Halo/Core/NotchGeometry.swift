import AppKit

/// Where the physical notch is on a given screen, in screen coordinates.
/// All values are read from AppKit at runtime, so any notched Mac (Air or
/// Pro, any size) gets correct dimensions without hardcoding.
struct NotchGeometry {
    /// The rectangle the physical notch occupies. macOS screen coordinates
    /// have their origin at the *bottom-left*, with y growing upward.
    let notchRect: CGRect

    let screen: NSScreen

    init(screen: NSScreen) {
        self.screen = screen
        let frame = screen.frame
        let topInset = screen.safeAreaInsets.top

        if topInset > 0,
           let leftArea = screen.auxiliaryTopLeftArea,
           let rightArea = screen.auxiliaryTopRightArea {
            // Real notch: its width is whatever the two usable top areas
            // (left and right of the camera housing) leave in the middle.
            let width = frame.width - leftArea.width - rightArea.width
            notchRect = CGRect(
                x: frame.minX + leftArea.width,
                y: frame.maxY - topInset,
                width: width,
                height: topInset
            )
        } else {
            // No notch on this screen (e.g. an external display): pretend
            // there is one, centered at the top, so the overlay still has a
            // home and development is possible on any monitor.
            let width: CGFloat = 200
            let height: CGFloat = 32
            notchRect = CGRect(
                x: frame.midX - width / 2,
                y: frame.maxY - height,
                width: width,
                height: height
            )
        }
    }

    /// The screen that should host the overlay: prefer one with a real
    /// notch, fall back to the main screen.
    static func preferredScreen() -> NSScreen? {
        NSScreen.screens.first { $0.safeAreaInsets.top > 0 } ?? NSScreen.main
    }
}
