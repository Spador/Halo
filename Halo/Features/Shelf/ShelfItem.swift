import AppKit

/// A file temporarily held on the shelf. Halo stores a *reference* to the
/// file (its URL), never a copy — dragging out or AirDropping always uses
/// the original file on disk.
struct ShelfItem: Identifiable, Equatable {
    let url: URL
    var isPinned: Bool
    let icon: NSImage

    var id: String { url.path }
    var name: String { url.lastPathComponent }

    init(url: URL, isPinned: Bool = false) {
        self.url = url
        self.isPinned = isPinned
        self.icon = NSWorkspace.shared.icon(forFile: url.path)
    }
}
