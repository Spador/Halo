import AppKit

enum SwipeDirection {
    case left
    case right
}

/// An invisible AppKit view that reports pointer hover and file drags over
/// the panel. AppKit tracking areas are more reliable at the screen edge
/// than SwiftUI's `onHover` — and the notch sits at the very edge.
///
/// Drag handling lives here too because hover tracking is suspended during
/// a drag session: the drag callbacks must drive expand/collapse themselves.
final class HoverTrackingView: NSView {
    var onPointerEntered: () -> Void = {}
    var onPointerExited: () -> Void = {}
    var onClicked: () -> Void = {}
    var onScrolled: (Double) -> Void = { _ in }
    /// A completed horizontal two-finger swipe (one event per gesture).
    var onSwiped: (SwipeDirection) -> Void = { _ in }
    /// A completed pinch; true means pinch-out (fingers spreading).
    var onPinched: (Bool) -> Void = { _ in }
    /// Consulted before accepting a drag, so the shelf feature flag can
    /// refuse drops without the view knowing about settings.
    var isDropAllowed: () -> Bool = { true }
    var onDragEntered: () -> Void = {}
    var onDragExited: () -> Void = {}
    var onDropped: ([URL]) -> Void = { _ in }

    private var dropCompleted = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        // Announce to AppKit that file drags may be dropped on this view.
        registerForDraggedTypes([.fileURL])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not used") }

    // MARK: - Hover

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

    /// Clicks on SwiftUI controls are consumed by the hosting view; only
    /// clicks on inert areas (like the collapsed notch shape) bubble up the
    /// responder chain to land here.
    override func mouseDown(with event: NSEvent) { onClicked() }

    // MARK: - Scrolls and swipes

    /// Which way the current trackpad gesture committed. Decided once per
    /// gesture from its first dominant axis: vertical scrolls adjust the
    /// volume, horizontal ones are track-skip swipes.
    private enum ScrollAxis {
        case undecided
        case vertical
        case horizontal
    }

    private var scrollAxis: ScrollAxis = .undecided
    private var swipeDistance: CGFloat = 0
    private var swipeFired = false

    /// One trackpad gesture must not both change volume and skip a track.
    /// Mouse wheels have no gesture phases and stay pure volume: one notch
    /// equals one key-press step. Momentum events are dropped so a flicked
    /// scroll doesn't keep adjusting after the fingers lift.
    override func scrollWheel(with event: NSEvent) {
        guard event.momentumPhase == [] else { return }

        if event.phase == [] {
            if event.scrollingDeltaY != 0 {
                onScrolled(event.scrollingDeltaY > 0 ? 1.0 / 16 : -1.0 / 16)
            }
            return
        }

        if event.phase.contains(.began) {
            scrollAxis = .undecided
            swipeDistance = 0
            swipeFired = false
        }

        if scrollAxis == .undecided {
            let dx = abs(event.scrollingDeltaX)
            let dy = abs(event.scrollingDeltaY)
            if dx != 0 || dy != 0 {
                scrollAxis = dx > dy ? .horizontal : .vertical
            }
        }

        switch scrollAxis {
        case .vertical:
            onScrolled(event.scrollingDeltaY * 0.004)
        case .horizontal:
            swipeDistance += event.scrollingDeltaX
            if !swipeFired, abs(swipeDistance) > 60 {
                swipeFired = true
                onSwiped(swipeDistance < 0 ? .left : .right)
            }
        case .undecided:
            break
        }
    }

    // MARK: - Pinch

    private var pinchMagnification: CGFloat = 0
    private var pinchFired = false

    /// Fires once when the accumulated pinch passes the threshold; further
    /// movement in the same gesture is ignored.
    override func magnify(with event: NSEvent) {
        if event.phase.contains(.began) {
            pinchMagnification = 0
            pinchFired = false
        }
        pinchMagnification += event.magnification
        if !pinchFired, abs(pinchMagnification) > 0.15 {
            pinchFired = true
            onPinched(pinchMagnification > 0)
        }
    }

    // MARK: - File drops

    private func fileURLs(from info: NSDraggingInfo) -> [URL] {
        let objects = info.draggingPasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        )
        return objects as? [URL] ?? []
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard isDropAllowed(), !fileURLs(from: sender).isEmpty else { return [] }
        dropCompleted = false
        onDragEntered()
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        onDragExited()
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let urls = fileURLs(from: sender)
        guard isDropAllowed(), !urls.isEmpty else { return false }
        dropCompleted = true
        onDropped(urls)
        return true
    }

    override func draggingEnded(_ sender: NSDraggingInfo) {
        // Fires when the session ends anywhere; if the user dropped
        // elsewhere (no performDragOperation here), make sure we un-target.
        if !dropCompleted { onDragExited() }
    }
}
