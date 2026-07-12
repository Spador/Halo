import AppKit

/// An invisible AppKit view that reports when the pointer enters or leaves
/// the panel. AppKit tracking areas are more reliable at the screen edge
/// than SwiftUI's `onHover` — and the notch sits at the very edge.
final class HoverTrackingView: NSView {
    var onPointerEntered: () -> Void = {}
    var onPointerExited: () -> Void = {}

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        // `.inVisibleRect` keeps the tracked rect glued to the view's bounds
        // even as the panel is resized, so we never track a stale area.
        addTrackingArea(
            NSTrackingArea(
                rect: .zero,
                options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                owner: self,
                userInfo: nil
            )
        )
    }

    override func mouseEntered(with event: NSEvent) { onPointerEntered() }
    override func mouseExited(with event: NSEvent) { onPointerExited() }
}
