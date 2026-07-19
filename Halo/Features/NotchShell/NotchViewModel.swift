import AppKit
import Observation
import CoreGraphics

/// The cards that can occupy the expanded notch. Each feature module
/// contributes one; the shell decides which is visible.
enum NotchCard {
    case nowPlaying
    case shelf
    case controls
    case clipboard
    case calendar
    case timer
    case pomodoro
    case stats
}

/// A persistent mini-display in the collapsed notch's wings (unlike the
/// HUD, which auto-hides): a running timer, a Pomodoro phase, etc.
struct LiveActivity: Equatable {
    var iconName: String
    var text: String
    /// Emphasized activities render green (Pomodoro breaks, completion).
    var emphasized: Bool
    /// Media activities show artwork and an equalizer instead of icon and
    /// text. Nil artwork falls back to the icon.
    var artwork: NSImage?
    var isMedia: Bool = false
    /// When set, clicking the wing opens this (meeting join links).
    var url: URL?
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

    /// Persistent wing displays (at most two), chosen by the live activity
    /// engine. Outlives HUD flashes; a HUD briefly covers them, then they
    /// return.
    var liveActivities: [LiveActivityItem] = []

    /// Size of the physical notch, so the collapsed shape matches it
    /// exactly. Updated by the controller when screens change.
    var notchSize = CGSize(width: 200, height: 32)

    /// Size of the opened overlay — one constant shared by the SwiftUI
    /// shape and the window-frame math in the controller, so the two can
    /// never disagree.
    static let expandedSize = CGSize(width: 500, height: 250)

    /// Width of each HUD "wing" flanking the notch, and the extra height
    /// below it — again shared between shape and window-frame math.
    static let hudWingWidth: CGFloat = 90
    static let hudExtraHeight: CGFloat = 10
}
