import Observation
import CoreGraphics

/// The cards that can occupy the expanded notch. Each feature module
/// contributes one; the shell decides which is visible.
enum NotchCard {
    case nowPlaying
    case shelf
}

/// State shared between the panel controller (AppKit side) and the SwiftUI
/// views rendered inside the panel.
@Observable
final class NotchViewModel {
    /// Whether the overlay is open. The controller flips this from hover
    /// events; the SwiftUI shape animates whenever it changes.
    var isExpanded = false

    /// The card the user explicitly picked with the switcher, if any.
    /// `nil` means "automatic": the shell picks based on what has content.
    var selectedCard: NotchCard?

    /// True while a file drag hovers over the panel; forces the shelf card
    /// and its highlight.
    var isDropTargeted = false

    /// Volume/brightness HUD currently flashing in the notch wings, if any.
    /// Set by the panel controller, cleared by its auto-hide timer.
    var hud: HUDState?

    /// Size of the physical notch, so the collapsed shape matches it
    /// exactly. Updated by the controller when screens change.
    var notchSize = CGSize(width: 200, height: 32)

    /// Size of the opened overlay — one constant shared by the SwiftUI
    /// shape and the window-frame math in the controller, so the two can
    /// never disagree.
    static let expandedSize = CGSize(width: 440, height: 175)

    /// Width of each HUD "wing" flanking the notch, and the extra height
    /// below it — again shared between shape and window-frame math.
    static let hudWingWidth: CGFloat = 90
    static let hudExtraHeight: CGFloat = 10
}
