import Observation
import CoreGraphics

/// State shared between the panel controller (AppKit side) and the SwiftUI
/// views rendered inside the panel.
@Observable
final class NotchViewModel {
    /// Whether the overlay is open. The controller flips this from hover
    /// events; the SwiftUI shape animates whenever it changes.
    var isExpanded = false

    /// Size of the physical notch, so the collapsed shape matches it
    /// exactly. Updated by the controller when screens change.
    var notchSize = CGSize(width: 200, height: 32)

    /// Size of the opened overlay — one constant shared by the SwiftUI
    /// shape and the window-frame math in the controller, so the two can
    /// never disagree.
    static let expandedSize = CGSize(width: 440, height: 175)
}
