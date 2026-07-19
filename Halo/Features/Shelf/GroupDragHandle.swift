import AppKit
import SwiftUI

/// An invisible AppKit layer that starts a real multi-item dragging
/// session. SwiftUI's `onDrag` can only offer a single item to the system,
/// so dragging a group of files out of the shelf has to drop down to
/// `beginDraggingSession`, which takes one dragging item per file — that
/// is what lets Finder receive them as separate files.
struct GroupDragHandle: NSViewRepresentable {
    var urls: [URL]
    var onDragEnded: () -> Void = {}

    func makeNSView(context: Context) -> DragSourceView {
        DragSourceView()
    }

    func updateNSView(_ view: DragSourceView, context: Context) {
        view.urls = urls
        view.onDragEnded = onDragEnded
    }

    final class DragSourceView: NSView, NSDraggingSource {
        var urls: [URL] = []
        var onDragEnded: () -> Void = {}
        private var sessionStarted = false

        override func mouseDown(with event: NSEvent) {
            sessionStarted = false
        }

        override func mouseDragged(with event: NSEvent) {
            guard !sessionStarted, !urls.isEmpty else { return }
            sessionStarted = true
            let origin = convert(event.locationInWindow, from: nil)
            let items = urls.enumerated().map { index, url in
                let item = NSDraggingItem(pasteboardWriter: url as NSURL)
                // Fan the icons out a little so the drag reads as a stack.
                item.setDraggingFrame(
                    NSRect(
                        x: origin.x - 16 + CGFloat(index) * 8,
                        y: origin.y - 16,
                        width: 32,
                        height: 32
                    ),
                    contents: NSWorkspace.shared.icon(forFile: url.path)
                )
                return item
            }
            beginDraggingSession(with: items, event: event, source: self)
        }

        func draggingSession(
            _ session: NSDraggingSession,
            sourceOperationMaskFor context: NSDraggingContext
        ) -> NSDragOperation {
            context == .outsideApplication ? .copy : .generic
        }

        func draggingSession(
            _ session: NSDraggingSession,
            endedAt screenPoint: NSPoint,
            operation: NSDragOperation
        ) {
            onDragEnded()
        }
    }
}
