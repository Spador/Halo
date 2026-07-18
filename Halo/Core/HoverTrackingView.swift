import AppKit

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

    // MARK: - File drops

    private func fileURLs(from info: NSDraggingInfo) -> [URL] {
        let objects = info.draggingPasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        )
        return objects as? [URL] ?? []
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard !fileURLs(from: sender).isEmpty else { return [] }
        dropCompleted = false
        onDragEntered()
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        onDragExited()
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let urls = fileURLs(from: sender)
        guard !urls.isEmpty else { return false }
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
